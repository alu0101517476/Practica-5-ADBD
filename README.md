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




# 7.

- Identifique alguna tabla donde se utilice una solución similar:
  
La tabla que utiliza una solución similar es la tabla actor
