# 📘 Práctica 5: Modelo Relacional. Vistas y disparadores
---

## 🏫 Información Académica

| **Universidad**        | Universidad de La Laguna |
|------------------------|--------------------------|
| **Facultad**           | Escuela Superior de Ingeniería |
| **Asignatura**         | Administración de Bases de Datos |
| **Curso académico**    | 2025 / 2026 |
| **Práctica**           | Nº 5 – Modelo Relacional. Vistas y disparadores |

---

## 👥 Miembros del Grupo

| **Nombre**                 | **Correo**                    |
|---------------------------|-------------------------------|
| Alba Pérez Rodríguez      | alu0101513768@ull.edu.es      |
| Eric Bermúdez Hernández   | alu0101517476@ull.edu.es      |

---

# 1. Restauración de la base de datos

Mediante comandos de plsql realizados en la sesión de prácticas, restauramos la base de datos. En la siguiente imagen se puede apreciar como a raíz de la restauración aparece en la interfaz de dbeaver

![Comprobación existe bbdd](Img/Restauración%20bbdd%20(Ej.%201).png)

# 2. Identifique las tablas, vistas y secuencias.

En la siguiente imagen se pueden apreciar tanto las tablas, como las visgtas y las secuencias gracias a la interfaz gráfica del dbeaver. En la base de datos existen tanto tablas como secuencias pero no vistas

![Ejercicio 2](Img/Tablas,%20Vistas,%20Secuencias.png)

# 3.  Identifique las tablas principales y sus principales elementos.

A continuación se describen las tablas con sus principales elementos:

**category(category_id: int, name: varchar(25))**

	PK: category_id

**film_category(category_id: int, film_id: int)**

	FK: category_id
	FK: film_id

**language(language_id: int, name: varchar(20))**

	PK: language_id

**film(language_id: int, film_id: int, description: text, fulltext: vector, length: int, rating: function, release_year: year, rental_duration: int, rental_rate: numeric(4, 2), replacement_cost: numeric(5, 2), special_features: text[], title: varchar(255))**

	PK: film_id
	FK: languaje_id

**film_actor(actor_id: int, film_id: int)**

	PK: actor_id
	PK: film_id

**actor(actor_id: int, first_name: varchar(45), last_name: varchar(45))**

	PK: actor_id

**inventory(film_id: int, store_id: int, inventory_id: int)**

	PK: inventory_id
	FK: film_id

**rental(customer_id: int, inventory_id: int, staff_id: int, rental_id: int, rental_date: timestamp, return_date: timestamp)**

	PK: rental_id
	FK: staff_id
	FK: inventory_id
	FK: customer_id

**payment(customer_id: int, rental_id: int, staff_id: int, payment_id: int, amount: numeric, payment_date: timestamp)**

	PK: payment_id
	FK: staff_id
	FK: rental_id
	FK: customer_id

**customer(address_id: int, store_id: int, customer_id: int, active: int, activebool: bool, create_date: timestamp, email: varchar(50), first_name: varchar(45), last_name: varchar(45))**

	PK: customer_id
	FK: address_id

**staff(address_id: int, store_id: int, staff_id: int, active: bool, email: varchar(50), first_name: varchar(45), last_name: varchar(45), password: varchar(40), picture: bytes, username: varchar(16))**

	PK: staff_id
	FK: address_id

**store(address_id: int, manager_staff_id: int, store_id: int)**

	PK: store_id
	FK: manager_staff_id
	FK: address_id

**address(city_id: int, address_id: int, address: varchar(50), address2: varchar(50), district: varchar(20), phone: varchar(20), postal_code: varchar(10))**

	PK: address_id
	FK: city_id

**city(city_id: int, country_id: int, city: varchar(50))**

	PK: city_id
	FK: country_id

**country(country_id: int, country: varchar(50))**

	PK: country_id

# 4. Realice las siguientes consultas.

- **a. Obtenga las ventas totales por categoría de películas ordenadas
descendentemente**

  ```SQL
  SELECT
    SUM(payment.amount) AS total_sales,
    category.name AS category
  FROM payment
  INNER JOIN rental
      ON rental.rental_id = payment.rental_id
  INNER JOIN inventory
      ON inventory.inventory_id = rental.inventory_id
  INNER JOIN film
      ON film.film_id = inventory.film_id
  INNER JOIN film_category
      ON film_category.film_id = film.film_id
  INNER JOIN category
      ON category.category_id = film_category.category_id
  GROUP BY category
  ORDER BY total_sales DESC;

  ```

  La consulta suma todos los pagos realizados por los clientes (payment.amount), los relaciona con qué película se alquiló y a qué categoría pertenece esa película, y luego agrupa esas sumas por categoría de película. Finalmente, ordena los resultados de mayor a menor para mostrar qué categorías han generado más ingresos.

- **b. Obtenga las ventas totales por tienda, donde se refleje la ciudad, el país
(concatenar la ciudad y el país empleando como separador la “,”), y el
encargado. Pudiera emplear *GROUP BY*, *ORDER BY***

```sql
SELECT 
    s.store_id,
    (c.city || ', ' || a.country) AS ciudad_pais,
    CONCAT(st.first_name, ' ', st.last_name) AS encargado,
    SUM(p.amount) AS ventas_totales
FROM store s
    INNER JOIN staff st ON s.manager_staff_id = st.staff_id
    INNER JOIN address ad ON s.address_id = ad.address_id
    INNER JOIN city c ON ad.city_id = c.city_id
    INNER JOIN country a ON c.country_id = a.country_id
    INNER JOIN customer cu ON s.store_id = cu.store_id
    INNER JOIN payment p ON cu.customer_id = p.customer_id
GROUP BY s.store_id, c.city, a.country, st.first_name, st.last_name
ORDER BY ventas_totales DESC;
```
Esta consulta obtiene las ventas totales por cada tienda, mostrando:
- El identificador de la tienda (`store_id`).
- La ciudad y el país concatenados en una sola columna (`ciudad_pais`), utilizando el operador `||` para unir texto.
- El nombre completo del encargado (`encargado`), concatenando el nombre y apellido del empleado.
- El total de ventas (`ventas_totales`), calculado con `SUM(p.amount)`.

Las tablas `store`, `staff`, `address`, `city`, `country`, `customer` y `payment` se relacionan mediante `INNER JOIN` para obtener toda la información necesaria.  
Se utiliza `GROUP BY` para agrupar las ventas por tienda y evitar duplicados.  
Finalmente, `ORDER BY ventas_totales DESC` ordena los resultados de mayor a menor total de ventas.

- **c. Obtenga una lista de películas, donde se reflejen el identificador, el título, descripción, categoría, el precio, la duración de la película, clasificación, nombre y apellidos de los actores (puede realizar una concatenación de ambos). Pudiera emplear GROUP BY**

	```sql
	SELECT 
    f.film_id AS id_pelicula,
    f.title AS titulo,
    f.description AS descripcion,
    c.name AS categoria,
    f.rental_rate AS precio,
    f.length AS duracion,
    f.rating AS clasificacion,
    STRING_AGG(a.first_name || ' ' || a.last_name, ', ') AS actores
	FROM film f
	INNER JOIN film_category fc ON f.film_id = fc.film_id
	INNER JOIN category c ON fc.category_id = c.category_id
	INNER JOIN film_actor fa ON f.film_id = fa.film_id
	INNER JOIN actor a ON fa.actor_id = a.actor_id
	GROUP BY f.film_id, f.title, f.description, c.name, f.rental_rate, f.length, f.rating
	ORDER BY f.title;
	```

Esta consulta lista todas las películas, mostrando:
- El identificador, título, descripción, categoría, precio de alquiler, duración y clasificación de cada película.
- Los actores que participan en cada una, concatenados en una sola columna usando `STRING_AGG`.

Las tablas `film`, `film_category`, `category`, `film_actor` y `actor` se combinan con `INNER JOIN` para unir la información de películas, categorías y actores.  
`STRING_AGG(a.first_name || ' ' || a.last_name, ', ')` concatena los nombres y apellidos de los actores separados por comas.  
Se emplea `GROUP BY` para agrupar la información por película y evitar repeticiones, y `ORDER BY f.title` para ordenar las películas alfabéticamente.

- **d. Obtenga la información de los actores, donde se incluya sus nombres y apellidos, las categorías y sus películas. Los actores deben de estar agrupados y, las categorías y las películas deben estar concatenados por “:”**

```sql
	SELECT 
    a.actor_id,
    a.first_name || ' ' || a.last_name AS actor,
    STRING_AGG(c.name || ': ' || f.title, ', ') AS categorias_peliculas
	FROM actor a
	INNER JOIN film_actor fa ON a.actor_id = fa.actor_id
	INNER JOIN film f ON fa.film_id = f.film_id
	INNER JOIN film_category fc ON f.film_id = fc.film_id
	INNER JOIN category c ON fc.category_id = c.category_id
	GROUP BY a.actor_id, a.first_name, a.last_name
	ORDER BY a.last_name, a.first_name;
```
Esta consulta obtiene información de cada actor, incluyendo:
- Su nombre y apellido concatenados.
- Las categorías y títulos de películas en las que participa, concatenados con “:” dentro de una misma cadena.

`STRING_AGG(c.name || ': ' || f.title, ', ')` une la categoría y el título de cada película en un formato legible, separando cada par con comas.  
Las tablas `actor`, `film_actor`, `film`, `film_category` y `category` se combinan para obtener la relación entre actores, películas y categorías.  
El `GROUP BY` agrupa los resultados por actor, y `ORDER BY a.last_name, a.first_name` ordena los nombres alfabéticamente.

# 7.

- Identifique alguna tabla donde se utilice una solución similar:
  
La tabla que utiliza una solución similar es la tabla actor
