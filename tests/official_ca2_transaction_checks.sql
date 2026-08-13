-- Official CA2 transaction checks for public.place_orders.
-- Run after tests/sql_integration_base.sql, ca2_cart_checkout_indexes.sql, and ca2_official_pricing_and_transactions.sql.

INSERT INTO public.cart (member_id, status) VALUES (1, 'ACTIVE');
INSERT INTO public.cart_item (cart_id, product_id, quantity)
SELECT c.cart_id, v.product_id, v.quantity
FROM public.cart c
CROSS JOIN (VALUES (1, 3), (3, 1)) AS v(product_id, quantity)
WHERE c.member_id = 1 AND c.status = 'ACTIVE';

DO $$
DECLARE
    v_order_id INTEGER;
    v_processed INTEGER;
    v_skipped INTEGER;
    v_remaining_count INTEGER;
    v_order_item_count INTEGER;
    v_order_total NUMERIC(10, 2);
BEGIN
    CALL public.place_orders(1, v_order_id, v_processed, v_skipped);

    IF v_order_id IS NULL OR v_processed <> 1 OR v_skipped <> 1 THEN
        RAISE EXCEPTION 'Partial-processing scenario failed: order %, processed %, skipped %.', v_order_id, v_processed, v_skipped;
    END IF;

    SELECT COUNT(*) INTO v_order_item_count FROM public.sale_order_item WHERE order_id = v_order_id;
    SELECT total_amount INTO v_order_total FROM public.sale_order WHERE order_id = v_order_id;
    SELECT COUNT(*) INTO v_remaining_count
      FROM public.cart_item ci JOIN public.cart c ON c.cart_id = ci.cart_id
     WHERE c.member_id = 1 AND c.status = 'ACTIVE';

    IF v_order_item_count <> 1 OR v_order_total <> 60.00 OR v_remaining_count <> 1 THEN
        RAISE EXCEPTION 'Partial-processing result is incorrect: lines %, total %, remaining %.', v_order_item_count, v_order_total, v_remaining_count;
    END IF;

    RAISE NOTICE 'Scenario 1 passed: available item ordered, unavailable item remains in cart.';
END;
$$;

DO $$
DECLARE
    v_order_id INTEGER;
    v_processed INTEGER;
    v_skipped INTEGER;
    v_orders_before INTEGER;
    v_orders_after INTEGER;
    v_remaining_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_orders_before FROM public.sale_order;
    CALL public.place_orders(1, v_order_id, v_processed, v_skipped);
    SELECT COUNT(*) INTO v_orders_after FROM public.sale_order;
    SELECT COUNT(*) INTO v_remaining_count
      FROM public.cart_item ci JOIN public.cart c ON c.cart_id = ci.cart_id
     WHERE c.member_id = 1 AND c.status = 'ACTIVE';

    IF v_order_id IS NOT NULL OR v_processed <> 0 OR v_skipped <> 1 OR v_orders_after <> v_orders_before OR v_remaining_count <> 1 THEN
        RAISE EXCEPTION 'All-unavailable scenario failed: order %, processed %, skipped %, before %, after %, remaining %.', v_order_id, v_processed, v_skipped, v_orders_before, v_orders_after, v_remaining_count;
    END IF;

    RAISE NOTICE 'Scenario 2 passed: no order created and unavailable item remains in cart.';
END;
$$;
