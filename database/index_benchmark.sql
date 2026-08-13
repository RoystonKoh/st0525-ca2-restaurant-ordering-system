-- ST0525 DBS CA2: Indexing evidence script.
-- Run ca2_cart_checkout_indexes.sql first. Open Query Tool > Explain Analyze for each query,
-- then capture the plan showing the index name and execution statistics.
-- Use real IDs/categories from the restored database; do not invent benchmark timings in the report.

-- Confirm that all six indexes exist before benchmarking.
SELECT indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND indexname IN (
    'idx_cart_member_status',
    'idx_cart_item_product_id',
    'idx_sale_order_member_order_date',
    'idx_sale_order_status_order_date',
    'idx_product_available_category',
    'idx_sale_order_item_product_order'
  )
ORDER BY indexname;

-- Q1: Load an active cart for a member (Index 1: idx_cart_member_status).
EXPLAIN (ANALYZE, BUFFERS)
SELECT cart_id, member_id, status, updated_at
FROM public.cart
WHERE member_id = 2 AND status = 'ACTIVE'
ORDER BY cart_id DESC
LIMIT 1;

-- Q2: Locate cart records containing a product (Index 2: idx_cart_item_product_id).
EXPLAIN (ANALYZE, BUFFERS)
SELECT ci.cart_item_id, ci.cart_id, ci.quantity
FROM public.cart_item ci
WHERE ci.product_id = 1;

-- Q3: Display an individual member's recent order history (Index 3: idx_sale_order_member_order_date).
EXPLAIN (ANALYZE, BUFFERS)
SELECT so.order_id, so.order_date, so.status, so.total_amount
FROM public.sale_order so
WHERE so.member_id = 2
ORDER BY so.order_date DESC
LIMIT 20;

-- Q4: Administrator dashboard status filter ordered by recency (Index 4: idx_sale_order_status_order_date).
EXPLAIN (ANALYZE, BUFFERS)
SELECT so.order_id, so.member_id, so.order_date, so.total_amount
FROM public.sale_order so
WHERE so.status = 'PACKING'
ORDER BY so.order_date DESC
LIMIT 50;

-- Q5: Products page filtered to available products in a category (Index 5: idx_product_available_category).
EXPLAIN (ANALYZE, BUFFERS)
SELECT product_id, name, price
FROM public.product
WHERE is_available = TRUE
  AND category = 'Main Course'
ORDER BY name;

-- Q6: Product-centric order-item history/reporting (Index 6: idx_sale_order_item_product_order).
EXPLAIN (ANALYZE, BUFFERS)
SELECT soi.order_id, soi.product_id, soi.quantity, soi.subtotal
FROM public.sale_order_item soi
WHERE soi.product_id = 1
ORDER BY soi.order_id DESC;

-- Optional statistics maintenance before re-running a benchmark after realistic test data is inserted.
ANALYZE public.cart;
ANALYZE public.cart_item;
ANALYZE public.sale_order;
ANALYZE public.sale_order_item;
ANALYZE public.product;
