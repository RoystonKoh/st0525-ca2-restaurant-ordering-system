-- ST0525 DBS CA2: Cart management, checkout transaction, and indexing.
-- Run this ONCE after restoring restaurant_db_restore.sql and before starting the application.
-- The script is idempotent where PostgreSQL supports IF NOT EXISTS.

BEGIN;

CREATE TABLE IF NOT EXISTS public.cart (
    cart_id SERIAL PRIMARY KEY,
    member_id INTEGER NOT NULL REFERENCES public.member(member_id) ON DELETE CASCADE,
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT cart_status_check CHECK (status IN ('ACTIVE', 'CHECKED_OUT', 'ABANDONED'))
);

CREATE TABLE IF NOT EXISTS public.cart_item (
    cart_item_id SERIAL PRIMARY KEY,
    cart_id INTEGER NOT NULL REFERENCES public.cart(cart_id) ON DELETE CASCADE,
    product_id INTEGER NOT NULL REFERENCES public.product(product_id),
    quantity INTEGER NOT NULL DEFAULT 1,
    created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT cart_item_quantity_check CHECK (quantity > 0),
    CONSTRAINT cart_item_cart_id_product_id_key UNIQUE (cart_id, product_id)
);

-- A member can have many historical carts, but only one active cart.
CREATE UNIQUE INDEX IF NOT EXISTS uq_cart_one_active_per_member
    ON public.cart (member_id)
    WHERE status = 'ACTIVE';

-- Index 1: supports loading a member's active cart.
CREATE INDEX IF NOT EXISTS idx_cart_member_status
    ON public.cart (member_id, status);

-- Index 2: supports product-centric cart-item checks and reporting.
CREATE INDEX IF NOT EXISTS idx_cart_item_product_id
    ON public.cart_item (product_id);

-- Index 3: supports order-history pages for a logged-in member.
CREATE INDEX IF NOT EXISTS idx_sale_order_member_order_date
    ON public.sale_order (member_id, order_date DESC);

-- Index 4: supports the administrator dashboard filtering/sorting by status and recency.
CREATE INDEX IF NOT EXISTS idx_sale_order_status_order_date
    ON public.sale_order (status, order_date DESC);

-- Index 5: supports the available-products page filtered by category.
CREATE INDEX IF NOT EXISTS idx_product_available_category
    ON public.product (is_available, category);

-- Index 6: supports product-based order history and aggregation.
CREATE INDEX IF NOT EXISTS idx_sale_order_item_product_order
    ON public.sale_order_item (product_id, order_id);

-- The procedure is atomic: an exception prevents the order, its items, and the cart status
-- from being committed. Row locks prevent a concurrent checkout from consuming the same cart.
DROP PROCEDURE IF EXISTS public.place_order_from_cart(INTEGER);
DROP PROCEDURE IF EXISTS public.place_order_from_cart(INTEGER, INTEGER);

CREATE OR REPLACE PROCEDURE public.place_order_from_cart(
    IN p_member_id INTEGER,
    OUT p_order_id INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_cart_id INTEGER;
    v_total_amount NUMERIC(10, 2);
    v_item_count INTEGER;
    v_unavailable_count INTEGER;
BEGIN
    IF p_member_id IS NULL THEN
        RAISE EXCEPTION 'Member is required.';
    END IF;

    SELECT cart_id
      INTO v_cart_id
      FROM public.cart
     WHERE member_id = p_member_id
       AND status = 'ACTIVE'
     ORDER BY cart_id DESC
     LIMIT 1
     FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'No active cart was found.';
    END IF;

    -- Lock both cart items and products before validating price/availability.
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
        RAISE EXCEPTION 'One or more cart products are no longer available.';
    END IF;

    SELECT ROUND(SUM(ci.quantity * p.price), 2)
      INTO v_total_amount
      FROM public.cart_item ci
      JOIN public.product p ON p.product_id = ci.product_id
     WHERE ci.cart_id = v_cart_id;

    INSERT INTO public.sale_order (member_id, order_date, total_amount, status)
    VALUES (p_member_id, CURRENT_TIMESTAMP, v_total_amount, 'PACKING')
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

-- Smoke-test queries (run separately after logging in with a valid member_id):
-- CALL public.place_order_from_cart(<member_id>, NULL);
-- SELECT * FROM public.sale_order ORDER BY order_id DESC;
-- SELECT * FROM public.sale_order_item ORDER BY order_item_id DESC;
