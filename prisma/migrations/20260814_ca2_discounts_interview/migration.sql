-- ST0525 DBS CA2 interview enhancement: discount types and unavailable-product demonstration.
-- Run this AFTER database/ca2_cart_checkout_indexes.sql.
-- It is safe to run more than once.

BEGIN;

CREATE TABLE IF NOT EXISTS public.discount (
    discount_id SERIAL PRIMARY KEY,
    code VARCHAR(30) NOT NULL UNIQUE,
    discount_type VARCHAR(20) NOT NULL,
    discount_value NUMERIC(10, 2) NOT NULL,
    minimum_subtotal NUMERIC(10, 2) NOT NULL DEFAULT 0,
    buy_quantity INTEGER,
    get_quantity INTEGER,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    description TEXT NOT NULL,
    CONSTRAINT discount_type_check CHECK (discount_type IN ('PERCENTAGE', 'FIXED', 'BUY_X_GET_Y')),
    CONSTRAINT discount_value_check CHECK (discount_value >= 0),
    CONSTRAINT discount_minimum_subtotal_check CHECK (minimum_subtotal >= 0),
    CONSTRAINT discount_buy_get_check CHECK (
        (discount_type <> 'BUY_X_GET_Y')
        OR (buy_quantity IS NOT NULL AND buy_quantity > 0 AND get_quantity IS NOT NULL AND get_quantity > 0)
    )
);

ALTER TABLE public.cart
    ADD COLUMN IF NOT EXISTS discount_code VARCHAR(30);

ALTER TABLE public.sale_order
    ADD COLUMN IF NOT EXISTS original_amount NUMERIC(10, 2),
    ADD COLUMN IF NOT EXISTS discount_code VARCHAR(30),
    ADD COLUMN IF NOT EXISTS discount_amount NUMERIC(10, 2) NOT NULL DEFAULT 0;

-- Three demonstrable discount types. Apply one code at a time from the cart screen.
INSERT INTO public.discount (code, discount_type, discount_value, minimum_subtotal, buy_quantity, get_quantity, is_active, description)
VALUES
    ('SAVE10', 'PERCENTAGE', 10.00, 20.00, NULL, NULL, TRUE, '10% off when the cart subtotal is at least $20.00.'),
    ('LESS5', 'FIXED', 5.00, 30.00, NULL, NULL, TRUE, '$5.00 off when the cart subtotal is at least $30.00.'),
    ('BUY2GET1', 'BUY_X_GET_Y', 0.00, 0.00, 2, 1, TRUE, 'Buy any 2 items and get the cheapest eligible item free for every group of 3 items.')
ON CONFLICT (code) DO UPDATE
SET discount_type = EXCLUDED.discount_type,
    discount_value = EXCLUDED.discount_value,
    minimum_subtotal = EXCLUDED.minimum_subtotal,
    buy_quantity = EXCLUDED.buy_quantity,
    get_quantity = EXCLUDED.get_quantity,
    is_active = EXCLUDED.is_active,
    description = EXCLUDED.description;

CREATE INDEX IF NOT EXISTS idx_discount_active_code
    ON public.discount (is_active, code);

-- The function is used by both cart preview and final checkout, so the discount calculation is consistent.
CREATE OR REPLACE FUNCTION public.calculate_cart_discount(
    p_cart_id INTEGER,
    p_discount_code VARCHAR DEFAULT NULL
)
RETURNS TABLE (
    subtotal NUMERIC(10, 2),
    discount_code VARCHAR,
    discount_type VARCHAR,
    discount_description TEXT,
    discount_amount NUMERIC(10, 2),
    final_total NUMERIC(10, 2)
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_code VARCHAR(30);
    v_type VARCHAR(20);
    v_value NUMERIC(10, 2);
    v_minimum NUMERIC(10, 2);
    v_buy_quantity INTEGER;
    v_get_quantity INTEGER;
    v_description TEXT;
    v_item_count INTEGER;
    v_free_item_count INTEGER;
    v_amount NUMERIC(10, 2) := 0;
BEGIN
    SELECT COALESCE(ROUND(SUM(ci.quantity * p.price), 2), 0)
      INTO subtotal
      FROM public.cart_item ci
      JOIN public.product p ON p.product_id = ci.product_id
     WHERE ci.cart_id = p_cart_id;

    v_code := NULLIF(UPPER(TRIM(p_discount_code)), '');

    IF v_code IS NULL THEN
        discount_code := NULL;
        discount_type := NULL;
        discount_description := 'No discount applied.';
        discount_amount := 0;
        final_total := subtotal;
        RETURN NEXT;
        RETURN;
    END IF;

    SELECT d.code, d.discount_type, d.discount_value, d.minimum_subtotal,
           d.buy_quantity, d.get_quantity, d.description
      INTO v_code, v_type, v_value, v_minimum, v_buy_quantity, v_get_quantity, v_description
      FROM public.discount d
     WHERE d.code = v_code
       AND d.is_active = TRUE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Discount code % is invalid or inactive.', p_discount_code;
    END IF;

    IF subtotal < v_minimum THEN
        RAISE EXCEPTION 'Discount code % requires a subtotal of at least $%.', v_code, v_minimum;
    END IF;

    IF v_type = 'PERCENTAGE' THEN
        v_amount := ROUND(subtotal * (v_value / 100), 2);
    ELSIF v_type = 'FIXED' THEN
        v_amount := LEAST(v_value, subtotal);
    ELSIF v_type = 'BUY_X_GET_Y' THEN
        SELECT COALESCE(SUM(ci.quantity), 0)
          INTO v_item_count
          FROM public.cart_item ci
         WHERE ci.cart_id = p_cart_id;

        v_free_item_count := FLOOR(v_item_count / (v_buy_quantity + v_get_quantity)) * v_get_quantity;

        IF v_free_item_count > 0 THEN
            SELECT COALESCE(ROUND(SUM(x.price), 2), 0)
              INTO v_amount
              FROM (
                  SELECT p.price
                    FROM public.cart_item ci
                    JOIN public.product p ON p.product_id = ci.product_id
                    CROSS JOIN LATERAL generate_series(1, ci.quantity)
                   WHERE ci.cart_id = p_cart_id
                   ORDER BY p.price ASC
                   LIMIT v_free_item_count
              ) x;
        END IF;
    END IF;

    discount_code := v_code;
    discount_type := v_type;
    discount_description := v_description;
    discount_amount := LEAST(v_amount, subtotal);
    final_total := ROUND(subtotal - discount_amount, 2);
    RETURN NEXT;
END;
$$;

-- Replace the checkout procedure so it stores the computed discount on the completed order.
CREATE OR REPLACE PROCEDURE public.place_order_from_cart(
    IN p_member_id INTEGER,
    OUT p_order_id INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_cart_id INTEGER;
    v_discount_code VARCHAR(30);
    v_subtotal NUMERIC(10, 2);
    v_discount_amount NUMERIC(10, 2);
    v_final_total NUMERIC(10, 2);
    v_item_count INTEGER;
    v_unavailable_count INTEGER;
BEGIN
    IF p_member_id IS NULL THEN
        RAISE EXCEPTION 'Member is required.';
    END IF;

    SELECT cart_id, discount_code
      INTO v_cart_id, v_discount_code
      FROM public.cart
     WHERE member_id = p_member_id
       AND status = 'ACTIVE'
     ORDER BY cart_id DESC
     LIMIT 1
     FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'No active cart was found.';
    END IF;

    PERFORM 1
      FROM public.cart_item ci
      JOIN public.product p ON p.product_id = ci.product_id
     WHERE ci.cart_id = v_cart_id
     FOR UPDATE OF ci, p;

    SELECT COUNT(*)
      INTO v_item_count
      FROM public.cart_item
     WHERE cart_id = v_cart_id;

    IF v_item_count = 0 THEN
        RAISE EXCEPTION 'Cannot check out an empty cart.';
    END IF;

    SELECT COUNT(*)
      INTO v_unavailable_count
      FROM public.cart_item ci
      JOIN public.product p ON p.product_id = ci.product_id
     WHERE ci.cart_id = v_cart_id
       AND p.is_available = FALSE;

    IF v_unavailable_count > 0 THEN
        RAISE EXCEPTION 'Checkout blocked: remove unavailable product(s) from the cart before placing the order.';
    END IF;

    SELECT c.subtotal, c.discount_amount, c.final_total
      INTO v_subtotal, v_discount_amount, v_final_total
      FROM public.calculate_cart_discount(v_cart_id, v_discount_code) c;

    INSERT INTO public.sale_order (
        member_id, order_date, total_amount, status,
        original_amount, discount_code, discount_amount
    )
    VALUES (
        p_member_id, CURRENT_TIMESTAMP, v_final_total, 'PACKING',
        v_subtotal, v_discount_code, v_discount_amount
    )
    RETURNING order_id INTO p_order_id;

    INSERT INTO public.sale_order_item (order_id, product_id, quantity, unit_price, subtotal)
    SELECT
        p_order_id,
        ci.product_id,
        ci.quantity,
        p.price,
        ROUND(ci.quantity * p.price, 2)
    FROM public.cart_item ci
    JOIN public.product p ON p.product_id = ci.product_id
    WHERE ci.cart_id = v_cart_id;

    UPDATE public.cart
       SET status = 'CHECKED_OUT',
           updated_at = CURRENT_TIMESTAMP
     WHERE cart_id = v_cart_id;
END;
$$;

COMMIT;

-- Verify the seeded interview discount types.
SELECT code, discount_type, discount_value, minimum_subtotal, buy_quantity, get_quantity, description
FROM public.discount
ORDER BY code;
