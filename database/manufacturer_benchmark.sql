-- ST0525 DBS CA2 Deliverable #005: Manufacturer performance evidence.
-- Use the separate manufacturer database.
-- Step 1: Run this script BEFORE database/manufacturer_indexing.sql and save the EXPLAIN ANALYSE output.
-- Step 2: Run database/manufacturer_indexing.sql.
-- Step 3: Run this script again and save the new output.
-- Do not invent results: record the planner node and actual execution time returned by your database.

-- Q1: Case-insensitive support-contact lookup (functional index).
EXPLAIN ANALYSE
SELECT id, firm_name, support_email, website
FROM public.manufacturer
WHERE LOWER(support_email) = LOWER('Joany.Wolf@hotmail.com');

-- Q2: Operating manufacturers by origin and category (composite index).
EXPLAIN ANALYSE
SELECT id, firm_name, location, support_email
FROM public.manufacturer
WHERE origin = 'Singapore'
  AND product_category = 'Electronics'
  AND is_operational = TRUE;

-- Q3: Manufacturers in one category founded in a date range (composite index).
EXPLAIN ANALYSE
SELECT id, firm_name, founded_since, employee_count
FROM public.manufacturer
WHERE product_category = 'Electronics'
  AND founded_since BETWEEN DATE '2015-01-01' AND DATE '2020-12-31';

-- Q4: Large Singapore manufacturers (composite index with a range predicate).
EXPLAIN ANALYSE
SELECT id, firm_name, origin, employee_count
FROM public.manufacturer
WHERE origin = 'Singapore'
  AND employee_count >= 2900;

-- Q5: Manufacturers founded in a chosen year (functional index).
EXPLAIN ANALYSE
SELECT id, firm_name, founded_since, origin
FROM public.manufacturer
WHERE EXTRACT(YEAR FROM founded_since) = 2020;

-- Q6: Aggregate employee count for active category members (covering index).
EXPLAIN ANALYSE
SELECT SUM(employee_count) AS total_employees
FROM public.manufacturer
WHERE product_category = 'Electronics'
  AND is_operational = TRUE;
