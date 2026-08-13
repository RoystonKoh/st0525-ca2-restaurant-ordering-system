-- ST0525 DBS CA2 Deliverable #005: Manufacturer query and index proposals.
-- Run this script in the separate manufacturer database only.
-- The table is not integrated into the application.
-- Run database/manufacturer_benchmark.sql before and after this script to capture actual EXPLAIN ANALYSE evidence.

BEGIN;

-- Q1: Find a manufacturer contact record by email. Functional index supports case-insensitive lookup.
CREATE INDEX IF NOT EXISTS manufacturer_support_email_lower_idx
    ON public.manufacturer (LOWER(support_email));

-- Q2: Find operating manufacturers for a country/category combination.
CREATE INDEX IF NOT EXISTS manufacturer_origin_category_operational_idx
    ON public.manufacturer (origin, product_category, is_operational);

-- Q3: Filter one product category by a founded-date range.
CREATE INDEX IF NOT EXISTS manufacturer_category_founded_since_idx
    ON public.manufacturer (product_category, founded_since);

-- Q4: Filter a country and high employee-count range.
CREATE INDEX IF NOT EXISTS manufacturer_origin_employee_count_idx
    ON public.manufacturer (origin, employee_count);

-- Q5: Filter by an extracted founded year. This matches the expression used by the query.
CREATE INDEX IF NOT EXISTS manufacturer_founded_year_idx
    ON public.manufacturer (EXTRACT(YEAR FROM founded_since));

-- Q6: Cover an aggregate that filters by category and operating status then sums employee_count.
CREATE INDEX IF NOT EXISTS manufacturer_category_operational_employee_idx
    ON public.manufacturer (product_category, is_operational, employee_count);

COMMIT;

SELECT indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename = 'manufacturer'
ORDER BY indexname;
