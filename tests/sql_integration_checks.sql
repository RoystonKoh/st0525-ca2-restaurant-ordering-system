-- Real integration checks for the CA2 cart, unavailable-item rule, and discount types.
-- This runs against tests/sql_integration_base.sql in the sandbox test database.

INSERT INTO public.cart (member_id, status)
VALUES (1, 'ACTIVE');

INSERT INTO public.cart_item (cart_id, product_id, quantity)
SELECT c.cart_id, v.product_id, v.quantity
FROM public.cart c
CROSS JOIN (VALUES (1, 2), (2, 1), (3, 1)) AS v(product_id, quantity)
WHERE c.member_id = 1 AND c.status = 'ACTIVE';

-- The cart includes 2 available products and 1 unavailable product.
SELECT ci.cart_id, p.name, p.is_available, ci.quantity, p.price
FROM public.cart_item ci
JOIN public.product p ON p.product_id = ci.product_id
ORDER BY ci.cart_item_id;

-- Confirm every discount type calculates deterministically.
SELECT 'SAVE10' AS scenario, *
FROM public.calculate_cart_discount((SELECT cart_id FROM public.cart WHERE member_id = 1 AND status = 'ACTIVE'), 'SAVE10');
SELECT 'LESS5' AS scenario, *
FROM public.calculate_cart_discount((SELECT cart_id FROM public.cart WHERE member_id = 1 AND status = 'ACTIVE'), 'LESS5');
SELECT 'BUY2GET1' AS scenario, *
FROM public.calculate_cart_discount((SELECT cart_id FROM public.cart WHERE member_id = 1 AND status = 'ACTIVE'), 'BUY2GET1');

-- The procedure must reject the unavailable item and must not create a partial order.
DO $$
DECLARE
    v_order_id INTEGER;
    v_orders_before INTEGER;
    v_orders_after INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_orders_before FROM public.sale_order;
    BEGIN
        CALL public.place_order_from_cart(1, v_order_id);
        RAISE EXCEPTION 'The unavailable-item business rule did not block checkout.';
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM NOT LIKE 'Checkout blocked:%' THEN
            RAISE;
        END IF;
        RAISE NOTICE 'Expected unavailable-item rejection: %', SQLERRM;
    END;
    SELECT COUNT(*) INTO v_orders_after FROM public.sale_order;
    IF v_orders_after <> v_orders_before THEN
        RAISE EXCEPTION 'A partial order was created after rejected checkout.';
    END IF;
END;
$$;

-- Remove only the unavailable product, then apply Buy-2-Get-1 to the remaining 3 available units.
DELETE FROM public.cart_item
WHERE cart_id = (SELECT cart_id FROM public.cart WHERE member_id = 1 AND status = 'ACTIVE')
  AND product_id = 3;

UPDATE public.cart
SET discount_code = 'BUY2GET1'
WHERE member_id = 1 AND status = 'ACTIVE';

SELECT 'CHECKOUT_PREVIEW' AS scenario, *
FROM public.calculate_cart_discount((SELECT cart_id FROM public.cart WHERE member_id = 1 AND status = 'ACTIVE'), 'BUY2GET1');

-- Complete a discounted multi-item checkout.
CALL public.place_order_from_cart(1, NULL);

SELECT so.order_id, so.original_amount, so.discount_code, so.discount_amount, so.total_amount,
       so.status, COUNT(soi.order_item_id) AS line_count
FROM public.sale_order so
JOIN public.sale_order_item soi ON soi.order_id = so.order_id
GROUP BY so.order_id, so.original_amount, so.discount_code, so.discount_amount, so.total_amount, so.status;

SELECT member_id, status, discount_code
FROM public.cart
WHERE member_id = 1;
