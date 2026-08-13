-- ST0525 DBS CA2 transaction evidence guide.
-- The authoritative repeatable appendix scenarios are in tests/official_ca2_transaction_checks.sql.
-- Run that script only against the controlled test fixture in tests/sql_integration_base.sql.
-- For your restored restaurant_db, demonstrate the same outcomes through the application, then use the queries below.

-- 1. Find a customer with an ACTIVE cart and inspect each cart item.
SELECT c.cart_id, c.member_id, ci.cart_item_id, ci.product_id, p.name, p.is_available, ci.quantity
FROM public.cart c
JOIN public.cart_item ci ON ci.cart_id = c.cart_id
JOIN public.product p ON p.product_id = ci.product_id
WHERE c.status = 'ACTIVE'
ORDER BY c.cart_id, ci.cart_item_id;

-- 2. After you identify a member with an active cart, call the required procedure in pgAdmin.
-- Replace YOUR_MEMBER_ID before running this statement.
-- CALL public.place_orders(YOUR_MEMBER_ID, NULL, NULL, NULL);

-- 3. Verify that available lines created sale_order/sale_order_item rows.
SELECT so.order_id, so.member_id, so.order_date, so.total_amount, so.status,
       soi.product_id, soi.quantity, soi.unit_price, soi.subtotal
FROM public.sale_order so
JOIN public.sale_order_item soi ON soi.order_id = so.order_id
ORDER BY so.order_id DESC, soi.order_item_id DESC
LIMIT 30;

-- 4. Verify that unavailable products remain in an ACTIVE cart.
SELECT c.cart_id, c.member_id, ci.cart_item_id, p.name, p.is_available, ci.quantity
FROM public.cart c
JOIN public.cart_item ci ON ci.cart_id = c.cart_id
JOIN public.product p ON p.product_id = ci.product_id
WHERE c.status = 'ACTIVE'
ORDER BY c.cart_id, ci.cart_item_id;

-- 5. Verify a new pricing record exists only when an order was created through the application.
SELECT *
FROM public.order_pricing
ORDER BY created_at DESC
LIMIT 20;
