-- Business Problem: Cinema Box is a video rental company specializing in providing affordable DVD rentals with a 
-- streamline process - allowing customers to order DVDs from its website through the convenience of their home, 
-- or by visiting one of its two locations. Business seems to be doing well; however, a recent study from the 
-- American Customer Satisfaction Index shows customer satisfaction plunged by 15% from since the previous half 
-- with the top reason being lack of selection.


-- Business Question 1: What is the total number of rentals missing a return date or missing customer information?

-- Business Question 2: What are the total number of films, total number of rentals, and total number of sales 
-- per category per store_id?

-- CREATE CUSTOM FUNCTIONS WITH DATA TRANSFORMATIONS

-- Function to concatenate first and last name into full name
CREATE OR REPLACE FUNCTION full_name(first_name varchar(45), last_name varchar(45))
RETURNS varchar AS $full_name$
DECLARE full_name varchar;
BEGIN
		RETURN first_name || ' ' || last_name;
END; $full_name$ LANGUAGE PLPGSQL;

-- CREATE DETAILED AND SUMMARY TABLES

DROP TABLE IF EXISTS dvdstore_detailed;
CREATE TABLE dvdstore_detailed (
	store_id integer,
	inventory_id varchar(45),
	film_id integer,
	film_title varchar(45),
	rental_rate numeric(3,2),
	rental_duration varchar (15),
	category_id integer,
	category_name varchar(45),
	rental_id integer,
	rental_inventory_id integer,
	return_date date,
	full_name varchar(90),
	payment_amount numeric (5,2),
	payment_date date
);

-- To View Empty Detailed Table 
SELECT * FROM dvdstore_detailed;

-- Create summary table for business question 1
DROP TABLE IF EXISTS dvdstore_summary_rentals;
CREATE TABLE dvdstore_summary_rentals (
	store_id integer,
	category_name varchar(45),
	missing_return_date integer
);

-- To View Empty Summary Table 1 
SELECT * FROM dvdstore_summary_rentals;

-- Create summary table for business question 2
DROP TABLE IF EXISTS dvdstore_summary_categories;
CREATE TABLE dvdstore_summary_categories (
	store_id integer,
	category_name varchar(45),
	inventory_count integer,
	rental_count integer,
	average_rental_rate numeric (3,2),
	total_sales numeric (8,2)
);

-- To View Empty Summary Table 2 
SELECT * FROM dvdstore_summary_categories;

-- EXTRACT RAW DATA NEEDED FOR THE DETAILED SECTION OF THE REPORT FROM THE SOURCE DATABASE

DELETE FROM dvdstore_detailed;
INSERT INTO dvdstore_detailed (
	store_id,
	inventory_id,
	film_id,
	film_title,
	rental_rate,
	rental_duration,
	category_id,
	category_name,
	rental_id,
	rental_inventory_id,
	return_date,
	full_name,
	payment_amount,
	payment_date
)
SELECT
	i.store_id,
	i.inventory_id,
	i.film_id,
	f.title,
	f.rental_rate,
	f.rental_duration,
	fc.category_id,
	ca.name,
	r.rental_id,
	r.inventory_id,
    r.return_date,
	full_name (cu.first_name, cu.last_name),
	pa.amount,
	pa.payment_date
FROM inventory AS i
INNER JOIN film AS f ON f.film_id = i.film_id
INNER JOIN film_category AS fc ON fc.film_id = f.film_id
INNER JOIN category AS ca ON ca.category_id = fc.category_id
INNER JOIN rental AS r ON r.inventory_id = i.inventory_id
INNER JOIN customer AS cu ON cu.customer_id = r.customer_id
INNER JOIN payment AS pa ON pa.customer_id = cu.customer_id AND pa.rental_id = r.rental_id;

-- To Verify Detailed Table
SELECT * FROM dvdstore_detailed;

-- CREATE TRIGGER AND TRIGGER FUNCTION FOR EACH BUSINESS QUESTION TO CONTINUALLY UPDATE THE SUMMARY TABLES 
-- TRIGGER FUNCTION - BUSINESS QUESTION 1 
-- What is the total number of rentals missing a return date or customer information?
CREATE OR REPLACE FUNCTION summary_rental_count()
RETURNS TRIGGER 
LANGUAGE PLPGSQL
AS $$
BEGIN 
DELETE FROM dvdstore_summary_rentals;
INSERT INTO dvdstore_summary_rentals (
	SELECT  
			store_id, category_name,
			COUNT(*) AS missing_return_date
	FROM dvdstore_detailed
	WHERE return_date IS NULL
	GROUP BY store_id, category_name);
RETURN NEW;
END; $$;

-- TRIGGER FUNCTION - BUSINESS QUESTION 2
-- What is the total number of films, total number of rentals, and total number of sales per category per store_id?
CREATE OR REPLACE FUNCTION summary_inventory_count()
RETURNS TRIGGER 
LANGUAGE PLPGSQL
AS $$
BEGIN
DELETE FROM dvdstore_summary_categories;
INSERT INTO dvdstore_summary_categories (
	SELECT
			store_id, category_name,
			COUNT(inventory_id) AS inventory_count,
			COUNT(rental_inventory_id) AS rental_count,
			AVG(rental_rate) AS average_rental_rate,
			SUM(payment_amount) AS total_sales
	FROM dvdstore_detailed
	GROUP BY store_id, category_name
	ORDER BY total_sales DESC); 	
RETURN NEW;
END; $$;

-- To Verify Detailed Tables Match Summary Table 1
SELECT COUNT (*) FROM dvdstore_detailed WHERE return_date IS NULL;
SELECT SUM (missing_return_date) FROM dvdstore_summary_rentals;
-- Equals 183

-- To Verify Detailed Tables Match Summary Table 2
SELECT COUNT (DISTINCT category_name) FROM dvdstore_detailed;
SELECT COUNT (DISTINCT category_name) FROM dvdstore_summary_rentals;
-- Equals 16

-- TRIGGER FUNCTIONS TO REFRESH SUMMARY TABLES WHEN DETAILED TABLE UPDATED

-- Business Question 1 Trigger
-- DROP TRIGGER summary_refresh_dvdrentals ON dvdstore_detailed;
CREATE TRIGGER summary_refresh_dvdrentals
AFTER INSERT ON dvdstore_detailed
FOR EACH STATEMENT
EXECUTE PROCEDURE summary_rental_count();

-- Business Question 2 Trigger
-- DROP TRIGGER summary_refresh_dvdcategories ON dvdstore_detailed;
CREATE TRIGGER summary_refresh_dvdcategories
AFTER INSERT ON dvdstore_detailed
FOR EACH STATEMENT 
EXECUTE PROCEDURE summary_inventory_count();

-- VERIFY TRIGGERS
INSERT INTO dvdstore_detailed (category_id, category_name, rental_id)
VALUES (154, 'Anime', 1257);

--Trigger 1
SELECT COUNT (*) FROM dvdstore_detailed WHERE return_date IS NULL;
SELECT SUM (missing_return_date) FROM dvdstore_summary_rentals;
--Equals 184

-- Trigger 2
SELECT COUNT (DISTINCT category_name) FROM dvdstore_detailed;
SELECT COUNT (DISTINCT category_name) FROM dvdstore_summary_rentals;
-- Equals 17

-- STORED PROCEDURE TO REFRESH DETAILED TABLE AND SUMMARY TABLES (AUTOMATED TO RUN EVERY 60 DAYS)
CREATE OR REPLACE PROCEDURE refresh_reports()
LANGUAGE PLPGSQL
AS $$
BEGIN
DELETE FROM dvdstore_detailed;
INSERT INTO dvdstore_detailed (
	store_id,
	inventory_id,
	film_id,
	film_title,
	rental_rate,
	rental_duration,
	category_id,
	category_name,
	rental_id,
	rental_inventory_id,
	return_date,
	full_name,
	payment_amount,
	payment_date
)
SELECT
	i.store_id,
	i.inventory_id,
	i.film_id,
	f.title,
	f.rental_rate,
	f.rental_duration,
	fc.category_id,
	ca.name,
	r.rental_id,
	r.inventory_id,
	r.return_date,
	full_name (cu.first_name, cu.last_name),
	pa.amount,
	pa.payment_date
FROM inventory AS i
INNER JOIN film AS f ON f.film_id = i.film_id
INNER JOIN film_category AS fc ON fc.film_id = f.film_id
INNER JOIN category AS ca ON ca.category_id = fc.category_id
INNER JOIN rental AS r ON r.inventory_id = i.inventory_id
INNER JOIN customer AS cu ON cu.customer_id = r.customer_id
INNER JOIN payment AS pa ON pa.customer_id = cu.customer_id AND pa.rental_id = r.rental_id;
END; $$;

SELECT COUNT (*) FROM dvdstore_detailed WHERE return_date IS NULL;
SELECT SUM (missing_return_date) FROM dvdstore_summary_rentals;
SELECT * FROM dvdstore_summary_rentals;
CALL refresh_reports();