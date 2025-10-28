-- ============================================================
-- Script único para DBeaver / PostgreSQL
-- - Recrea la BD alquilerdvd
-- - Se conecta vía dblink
-- - Crea tipos, dominios, funciones, tablas de log y triggers
--   (sin metacomandos \ ni transaction_timeout)
-- ============================================================

-- 1) Ejecutar conectado a la BD 'postgres' (no a 'alquilerdvd')
--    Terminar conexiones abiertas a 'alquilerdvd'
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE datname = 'alquilerdvd';

-- 2) Recrear la base de datos
DROP DATABASE IF EXISTS alquilerdvd;

CREATE DATABASE alquilerdvd
  WITH TEMPLATE = template0
       ENCODING = 'UTF8'
       LC_COLLATE = 'C.UTF-8'
       LC_CTYPE   = 'C.UTF-8';

-- (Opcional) propietario
ALTER DATABASE alquilerdvd OWNER TO postgres;

-- 3) Habilitar dblink en 'postgres' para poder ejecutar SQL dentro de 'alquilerdvd'
CREATE EXTENSION IF NOT EXISTS dblink;

-- 4) Abrir conexión dblink hacia la nueva BD
SELECT dblink_connect('alquilerdvd_conn', 'dbname=alquilerdvd');

-- 5) Ajustes de sesión y creación de objetos dentro de 'alquilerdvd'
SELECT dblink_exec('alquilerdvd_conn', $SQL$
  -- ========= Ajustes de sesión seguros (sin transaction_timeout) =========
  SET statement_timeout = 0;
  SET lock_timeout = 0;
  SET idle_in_transaction_session_timeout = 0;
  SET client_encoding = 'UTF8';
  SET standard_conforming_strings = on;
  SELECT pg_catalog.set_config('search_path', '', false);
  SET check_function_bodies = false;
  SET xmloption = content;
  SET client_min_messages = warning;
  SET row_security = off;

  -- ================== Tipos y dominios ==================
  DO $$BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'mpaa_rating') THEN
      CREATE TYPE public.mpaa_rating AS ENUM ('G','PG','PG-13','R','NC-17');
      ALTER TYPE public.mpaa_rating OWNER TO postgres;
    END IF;
  END$$;

  DO $$BEGIN
    IF NOT EXISTS (
      SELECT 1 FROM pg_type t
      JOIN pg_namespace n ON n.oid = t.typnamespace
      WHERE t.typname = 'year' AND n.nspname = 'public'
    ) THEN
      CREATE DOMAIN public.year AS integer
        CONSTRAINT year_check CHECK (VALUE >= 1901 AND VALUE <= 2155);
      ALTER DOMAIN public.year OWNER TO postgres;
    END IF;
  END$$;

  -- ================== Funciones auxiliares ==================
  CREATE OR REPLACE FUNCTION public._group_concat(text, text)
  RETURNS text
  LANGUAGE sql IMMUTABLE AS $$
    SELECT CASE
             WHEN $2 IS NULL THEN $1
             WHEN $1 IS NULL THEN $2
             ELSE $1 || ', ' || $2
           END;
  $$;
  ALTER FUNCTION public._group_concat(text, text) OWNER TO postgres;

  -- ¿Inventario en stock?
  CREATE OR REPLACE FUNCTION public.inventory_in_stock(p_inventory_id integer)
  RETURNS boolean
  LANGUAGE plpgsql AS $$
  DECLARE
    v_rentals INTEGER;
    v_out     INTEGER;
  BEGIN
    SELECT COUNT(*) INTO v_rentals
    FROM rental
    WHERE inventory_id = p_inventory_id;

    IF v_rentals = 0 THEN
      RETURN TRUE;
    END IF;

    SELECT COUNT(rental_id) INTO v_out
    FROM inventory LEFT JOIN rental USING (inventory_id)
    WHERE inventory.inventory_id = p_inventory_id
      AND rental.return_date IS NULL;

    IF v_out > 0 THEN
      RETURN FALSE;
    ELSE
      RETURN TRUE;
    END IF;
  END$$;
  ALTER FUNCTION public.inventory_in_stock(p_inventory_id integer) OWNER TO postgres;

  -- Películas en/no en stock
  CREATE OR REPLACE FUNCTION public.film_in_stock(p_film_id integer, p_store_id integer, OUT p_film_count integer)
  RETURNS SETOF integer
  LANGUAGE sql AS $$
    SELECT inventory_id
    FROM inventory
    WHERE film_id = $1
      AND store_id = $2
      AND inventory_in_stock(inventory_id);
  $$;
  ALTER FUNCTION public.film_in_stock(p_film_id integer, p_store_id integer, OUT p_film_count integer) OWNER TO postgres;

  CREATE OR REPLACE FUNCTION public.film_not_in_stock(p_film_id integer, p_store_id integer, OUT p_film_count integer)
  RETURNS SETOF integer
  LANGUAGE sql AS $$
    SELECT inventory_id
    FROM inventory
    WHERE film_id = $1
      AND store_id = $2
      AND NOT inventory_in_stock(inventory_id);
  $$;
  ALTER FUNCTION public.film_not_in_stock(p_film_id integer, p_store_id integer, OUT p_film_count integer) OWNER TO postgres;

  -- Marca de última actualización
  CREATE OR REPLACE FUNCTION public.last_updated()
  RETURNS trigger
  LANGUAGE plpgsql AS $$
  BEGIN
    NEW.last_update = CURRENT_TIMESTAMP;
    RETURN NEW;
  END$$;
  ALTER FUNCTION public.last_updated() OWNER TO postgres;

  -- Log inserciones en film
  CREATE OR REPLACE FUNCTION public.film_report()
  RETURNS trigger
  LANGUAGE plpgsql AS $$
  BEGIN
    INSERT INTO film_log (film_id, fecha_insercion)
    VALUES (NEW.film_id, NOW());
    RETURN NEW;
  END$$;
  ALTER FUNCTION public.film_report() OWNER TO postgres;

  -- Log eliminaciones en film
  CREATE OR REPLACE FUNCTION public.registrar_eliminacion_film()
  RETURNS trigger
  LANGUAGE plpgsql AS $$
  BEGIN
    INSERT INTO film_delete_log (film_id, fecha_eliminacion)
    VALUES (OLD.film_id, NOW());
    RETURN OLD;
  END$$;
  ALTER FUNCTION public.registrar_eliminacion_film() OWNER TO postgres;

  -- Saldo del cliente (sin IF() de MySQL; usamos cálculo/CASE nativo PG)
  CREATE OR REPLACE FUNCTION public.get_customer_balance(p_customer_id integer, p_effective_date timestamp without time zone)
  RETURNS numeric
  LANGUAGE plpgsql AS $$
  DECLARE
    v_rentfees  DECIMAL(5,2);
    v_overfees  INTEGER;
    v_payments  DECIMAL(5,2);
  BEGIN
    -- Tasas de alquiler
    SELECT COALESCE(SUM(f.rental_rate), 0)
      INTO v_rentfees
    FROM film f
    JOIN inventory i ON i.film_id = f.film_id
    JOIN rental   r ON r.inventory_id = i.inventory_id
    WHERE r.rental_date <= p_effective_date
      AND r.customer_id = p_customer_id;

    -- Días de retraso acumulados (>=0)
    SELECT COALESCE(
             SUM(
               GREATEST(
                 (
                   EXTRACT(EPOCH FROM (r.return_date - r.rental_date - f.rental_duration * INTERVAL '1 day')) / 86400
                 )::int,
                 0
               )
             ), 0)
      INTO v_overfees
    FROM rental r
    JOIN inventory i ON i.inventory_id = r.inventory_id
    JOIN film     f ON f.film_id = i.film_id
    WHERE r.rental_date <= p_effective_date
      AND r.customer_id = p_customer_id;

    -- Pagos
    SELECT COALESCE(SUM(p.amount), 0)
      INTO v_payments
    FROM payment p
    WHERE p.payment_date <= p_effective_date
      AND p.customer_id = p_customer_id;

    RETURN v_rentfees + v_overfees - v_payments;
  END
  $$;
  ALTER FUNCTION public.get_customer_balance(p_customer_id integer, p_effective_date timestamp without time zone) OWNER TO postgres;

  -- Último día del mes
  CREATE OR REPLACE FUNCTION public.last_day(timestamp without time zone)
  RETURNS date
  LANGUAGE sql IMMUTABLE STRICT AS $$
    SELECT CASE
      WHEN EXTRACT(MONTH FROM $1) = 12 THEN
        (((EXTRACT(YEAR FROM $1) + 1) || '-01-01')::date - INTERVAL '1 day')::date
      ELSE
        ((EXTRACT(YEAR FROM $1) || '-' || (EXTRACT(MONTH FROM $1) + 1) || '-01')::date - INTERVAL '1 day')::date
    END;
  $$;
  ALTER FUNCTION public.last_day(timestamp without time zone) OWNER TO postgres;

  -- ================== Tablas de log (ejemplo) ==================
  DO $$BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_class WHERE relname='film_log' AND relkind='r') THEN
      CREATE SEQUENCE public.film_log_log_id_seq START 1 INCREMENT 1;
      CREATE TABLE public.film_log (
        log_id integer NOT NULL DEFAULT nextval('public.film_log_log_id_seq'::regclass),
        film_id integer NOT NULL,
        fecha_insercion timestamp without time zone NOT NULL
      );
    END IF;
  END$$;

  DO $$BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_class WHERE relname='film_delete_log' AND relkind='r') THEN
      CREATE SEQUENCE public.film_delete_log_log_id_seq START 1 INCREMENT 1;
      CREATE TABLE public.film_delete_log (
        log_id integer NOT NULL DEFAULT nextval('public.film_delete_log_log_id_seq'::regclass),
        film_id integer NOT NULL,
        fecha_eliminacion timestamp without time zone NOT NULL
      );
    END IF;
  END$$;

  -- ================== Triggers condicionales ==================
  -- Se crean solo si existen las tablas destino, así el script no falla.
  DO $$DECLARE v_exists boolean; BEGIN
    -- Trigger last_updated en customer
    SELECT EXISTS (SELECT 1 FROM pg_class WHERE relname='customer' AND relkind='r') INTO v_exists;
    IF v_exists THEN
      PERFORM 1 FROM pg_trigger WHERE tgname='trg_customer_last_updated';
      IF NOT FOUND THEN
        EXECUTE $tg$
          CREATE TRIGGER trg_customer_last_updated
          BEFORE UPDATE ON public.customer
          FOR EACH ROW EXECUTE FUNCTION public.last_updated();
        $tg$;
      END IF;
    END IF;

    -- Trigger last_updated en actor
    SELECT EXISTS (SELECT 1 FROM pg_class WHERE relname='actor' AND relkind='r') INTO v_exists;
    IF v_exists THEN
      PERFORM 1 FROM pg_trigger WHERE tgname='trg_actor_last_updated';
      IF NOT FOUND THEN
        EXECUTE $tg$
          CREATE TRIGGER trg_actor_last_updated
          BEFORE UPDATE ON public.actor
          FOR EACH ROW EXECUTE FUNCTION public.last_updated();
        $tg$;
      END IF;
    END IF;

    -- Triggers en film (insert y delete)
    SELECT EXISTS (SELECT 1 FROM pg_class WHERE relname='film' AND relkind='r') INTO v_exists;
    IF v_exists THEN
      PERFORM 1 FROM pg_trigger WHERE tgname='trg_film_insert_log';
      IF NOT FOUND THEN
        EXECUTE $tg$
          CREATE TRIGGER trg_film_insert_log
          AFTER INSERT ON public.film
          FOR EACH ROW EXECUTE FUNCTION public.film_report();
        $tg$;
      END IF;

      PERFORM 1 FROM pg_trigger WHERE tgname='trg_film_delete_log';
      IF NOT FOUND THEN
        EXECUTE $tg$
          CREATE TRIGGER trg_film_delete_log
          AFTER DELETE ON public.film
          FOR EACH ROW EXECUTE FUNCTION public.registrar_eliminacion_film();
        $tg$;
      END IF;
    END IF;
  END$$;
$SQL$);

-- 6) Cerrar la conexión dblink
SELECT dblink_disconnect('alquilerdvd_conn');

-- ============================================================
-- Fin del script único
-- ============================================================
