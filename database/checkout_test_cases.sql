-- ST0525 DBS CA2: Transaction-management test cases.
-- Run after ca2_cart_checkout_indexes.sql. Replace the values below with valid IDs from your restored database.
-- Capture one screenshot for each case showing the SQL and the Messages/Data Output panel.

-- 0. Identify a valid member and available products for the following tests.
SELECT member_id, username, email FROM public.member ORDER BY member_id;
SELECT product_id, name, price, is_available FROM public.product ORDER BY product_id;

-- 1. SUCCESS CASE: create a cart with two items and check out.
-- Replace 2 with a real member ID; replace 1 and 2 with real available product IDs.
DO $$
DECLARE
    v_member_id INTEGER := 2;
    v_product_one INTEGER := 1;
    v_product_two INTEGER := 2;
    v_cart_id INTEGER;
    v_order_id INTEGER;
BEGIN
    INSERT INTO public.cart (member_id, status)
    VALUES (v_member_id, 'ACTIVE')
    ON CONFLICT DO NOTHING;

    SELECT cart_id INTO v_cart_id
    FROM public.cart
    WHERE member_id = v_member_id AND status = 'ACTIVE'
    ORDER BY cart_id DESC
    LIMIT 1;

    INSERT INTO public.cart_item (cart_id, product_id, quantity)
    VALUES (v_cart_id, v_product_one, 2)
    ON CONFLICT (cart_id, product_id)
    DO UPDATE SET quantity = EXCLUDED.quantity;

    INSERT INTO public.cart_item (cart_id, product_id, quantity)
    VALUES (v_cart_id, v_product_two, 1)
    ON CONFLICT (cart_id, product_id)
    DO UPDATE SET quantity = EXCLUDED.quantity;

    CALL public.place_order_from_cart(v_member_id, v_order_id);
    RAISE NOTICE 'SUCCESS: created order %', v_order_id;
END;
$$;

-- Verify the success case: exactly one multi-item order is present and its cart is CHECKED_OUT.
SELECT so.order_id, so.member_id, so.status, so.total_amount,
       COUNT(soi.order_item_id) AS line_count,
       SUM(soi.subtotal) AS calculated_total
FROM public.sale_order so
JOIN public.sale_order_item soi ON soi.order_id = so.order_id
GROUP BY so.order_id, so.member_id, so.status, so.total_amount
ORDER BY so.order_id DESC
LIMIT 5;

SELECT cart_id, member_id, status, updated_at
FROM public.cart
ORDER BY cart_id DESC
LIMIT 5;

-- 2. FAILURE CASE: empty cart. This must raise "Cannot check out an empty cart."
-- Confirm after the error that no new sale_order row has been created.
-- Replace 2 with a real member ID.
DO $$
DECLARE
    v_member_id INTEGER := 2;
    v_order_count_before INTEGER;
    v_order_count_after INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_order_count_before FROM public.sale_order WHERE member_id = v_member_id;
    INSERT INTO public.cart (member_id, status) VALUES (v_member_id, 'ACTIVE');
    BEGIN
        CALL public.place_order_from_cart(v_member_id, NULL);
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'EXPECTED FAILURE: %', SQLERRM;
    END;
    SELECT COUNT(*) INTO v_order_count_after FROM public.sale_order WHERE member_id = v_member_id;
    RAISE NOTICE 'ORDER COUNT BEFORE: %, AFTER: %', v_order_count_before, v_order_count_after;
END;
$$;

-- 3. FAILURE CASE: unavailable product. Mark a non-critical test product unavailable first.
-- The procedure must reject the checkout before creating an order.
-- Replace 2 with a real member ID and 3 with a real product ID.
DO $$
DECLARE
    v_member_id INTEGER := 2;
    v_product_id INTEGER := 3;
    v_cart_id INTEGER;
BEGIN
    UPDATE public.product SET is_available = FALSE WHERE product_id = v_product_id;
    INSERT INTO public.cart (member_id, status)
    VALUES (v_member_id, 'ACTIVE')
    ON CONFLICT DO NOTHING;

    SELECT cart_id INTO v_cart_id
    FROM public.cart
    WHERE member_id = v_member_id AND status = 'ACTIVE'
    ORDER BY cart_id DESC LIMIT 1;

    INSERT INTO public.cart_item (cart_id, product_id, quantity)
    VALUES (v_cart_id, v_product_id, 1)
    ON CONFLICT (cart_id, product_id) DO UPDATE SET quantity = 1;

    BEGIN
        CALL public.place_order_from_cart(v_member_id, NULL);
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'EXPECTED FAILURE: %', SQLERRM;
    END;

    UPDATE public.product SET is_available = TRUE WHERE product_id = v_product_id;
END;
$$;
