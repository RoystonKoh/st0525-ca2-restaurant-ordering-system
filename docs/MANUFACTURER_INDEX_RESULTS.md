# Manufacturer Indexing — Measured `EXPLAIN ANALYSE` Results

The supplied manufacturer backup was restored to an isolated PostgreSQL test database. It contained **818,244 rows**. Each query was run with `EXPLAIN ANALYSE` before and after the corresponding index was created. The results below are actual output from that database; execution times can vary on another machine or PostgreSQL configuration.

| Query | Query purpose | Index created | Before plan / time | After plan / time | Measured change |
| --- | --- | --- | --- | --- | --- |
| Q1 | Case-insensitive support-email lookup | `manufacturer_support_email_lower_idx` on `LOWER(support_email)` | Parallel sequential scan; **146.236 ms** | Bitmap index scan + bitmap heap scan; **0.080 ms** | Approximately **99.95% lower** execution time. |
| Q2 | Operating manufacturers by origin and category | `manufacturer_origin_category_operational_idx` on `(origin, product_category, is_operational)` | Parallel sequential scan; **50.823 ms** | Bitmap index scan + bitmap heap scan; **44.842 ms** | Approximately **11.77% lower** execution time. |
| Q3 | Manufacturers in a category founded within a date range | `manufacturer_category_founded_since_idx` on `(product_category, founded_since)` | Parallel sequential scan; **47.819 ms** | Bitmap index scan + bitmap heap scan; **26.441 ms** | Approximately **44.70% lower** execution time. |
| Q4 | Large manufacturers in one country | `manufacturer_origin_employee_count_idx` on `(origin, employee_count)` | Parallel sequential scan; **43.875 ms** | Bitmap index scan + bitmap heap scan; **24.875 ms** | Approximately **43.30% lower** execution time. |
| Q5 | Manufacturers founded in a specific year | `manufacturer_founded_year_idx` on `EXTRACT(YEAR FROM founded_since)` | Parallel sequential scan; **76.168 ms** | Bitmap index scan + bitmap heap scan; **22.274 ms** | Approximately **70.76% lower** execution time. |
| Q6 | Aggregate employee count for operating manufacturers in one category | `manufacturer_category_operational_employee_idx` on `(product_category, is_operational, employee_count)` | Parallel sequential scan; **50.403 ms** | Index-only scan; **5.632 ms** | Approximately **88.83% lower** execution time. |

> The index types and proof method follow the supplied indexing practical: create a B-tree, composite, function, or covering index that matches the predicate and selected columns, then use `EXPLAIN ANALYSE` to observe the actual planner node and execution time.

## Files for report evidence

| File | Use |
| --- | --- |
| `database/manufacturer_benchmark.sql` | Runs Q1–Q6 with `EXPLAIN ANALYSE`. |
| `database/manufacturer_indexing.sql` | Creates the six indexes and lists them from `pg_indexes`. |
| `manufacturer_before_explain.txt` | Saved raw pre-index plans from the restored 818,244-row backup. |
| `manufacturer_after_explain.txt` | Saved raw post-index plans from the restored 818,244-row backup. |
