-- ST0525 DBS CA2 official pricing and transaction implementation.
-- Run AFTER database/ca2_cart_checkout_indexes.sql.
-- The five original restaurant tables are not altered structurally; new tables are added for rules and order pricing.

BEGIN;

-- The original restaurant tables are not altered. CA2 pricing is stored only in the new pricing_rule and order_pricing tables below.

CREATE TABLE IF NOT EXISTS public.pricing_rule (
    pricing_rule_id SERIAL PRIMARY KEY,
    name VARCHAR(120) NOT NULL UNIQUE,
    rule_scope VARCHAR(20) NOT NULL,
    rule_type VARCHAR(40) NOT NULL,
    product_id INTEGER REFERENCES public.product(product_id) ON DELETE CASCADE,
    minimum_quantity INTEGER,
    minimum_cart_value NUMERIC(10, 2),
    maximum_cart_value NUMERIC(10, 2),
    discount_percent NUMERIC(5, 2),
    delivery_fee NUMERIC(10, 2),
    priority INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pricing_rule_scope_check CHECK (rule_scope IN ('PRODUCT', 'CART', 'DELIVERY')),
    CONSTRAINT pricing_rule_type_check CHECK (rule_type IN ('PRODUCT_QUANTITY_PERCENT', 'CART_VALUE_PERCENT', 'DELIVERY_TIER')),
    CONSTRAINT pricing_rule_value_check CHECK (
        (discount_percent IS NULL OR (discount_percent >= 0 AND discount_percent <= 100))
        AND (delivery_fee IS NULL OR delivery_fee >= 0)
        AND (minimum_quantity IS NULL OR minimum_quantity > 0)
        AND (minimum_cart_value IS NULL OR minimum_cart_value >= 0)
        AND (maximum_cart_value IS NULL OR maximum_cart_value >= 0)
    ),
    CONSTRAINT pricing_rule_shape_check CHECK (
        (rule_type = 'PRODUCT_QUANTITY_PERCENT' AND rule_scope = 'PRODUCT' AND product_id IS NOT NULL AND minimum_quantity IS NOT NULL AND discount_percent IS NOT NULL)
        OR (rule_type = 'CART_VALUE_PERCENT' AND rule_scope = 'CART' AND minimum_cart_value IS NOT NULL AND discount_percent IS NOT NULL)
        OR (rule_type = 'DELIVERY_TIER' AND rule_scope = 'DELIVERY' AND minimum_cart_value IS NOT NULL AND delivery_fee IS NOT NULL)
    )
);

CREATE TABLE IF NOT EXISTS public.voucher (
    voucher_id SERIAL PRIMARY KEY,
    code VARCHAR(30) NOT NULL UNIQUE,
    name VARCHAR(120) NOT NULL,
    voucher_type VARCHAR(30) NOT NULL,
    voucher_value NUMERIC(10, 2) NOT NULL,
    minimum_cart_value NUMERIC(10, 2) NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    description TEXT NOT NULL,
    created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT voucher_type_check CHECK (voucher_type IN ('PERCENT', 'FIXED', 'FREE_DELIVERY')),
    CONSTRAINT voucher_value_check CHECK (voucher_value >= 0 AND minimum_cart_value >= 0)
);

CREATE TABLE IF NOT EXISTS public.cart_voucher (
    cart_id INTEGER PRIMARY KEY REFERENCES public.cart(cart_id) ON DELETE CASCADE,
    voucher_id INTEGER NOT NULL REFERENCES public.voucher(voucher_id),
    created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS public.order_pricing (
    order_id INTEGER PRIMARY KEY REFERENCES public.sale_order(order_id) ON DELETE CASCADE,
    items_subtotal NUMERIC(10, 2) NOT NULL,
    product_discount_amount NUMERIC(10, 2) NOT NULL DEFAULT 0,
    cart_discount_amount NUMERIC(10, 2) NOT NULL DEFAULT 0,
    delivery_fee NUMERIC(10, 2) NOT NULL DEFAULT 0,
    delivery_discount_amount NUMERIC(10, 2) NOT NULL DEFAULT 0,
    voucher_code VARCHAR(30),
    voucher_discount_amount NUMERIC(10, 2) NOT NULL DEFAULT 0,
    voucher_delivery_saving NUMERIC(10, 2) NOT NULL DEFAULT 0,
    final_total NUMERIC(10, 2) NOT NULL,
    pricing_snapshot JSONB NOT NULL,
    created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT order_pricing_non_negative_check CHECK (
        items_subtotal >= 0 AND product_discount_amount >= 0 AND cart_discount_amount >= 0
        AND delivery_fee >= 0 AND delivery_discount_amount >= 0
        AND voucher_discount_amount >= 0 AND voucher_delivery_saving >= 0 AND final_total >= 0
    )
);

-- These ALTER statements affect only the new CA2 order_pricing table and make the enhancement repeatable for earlier CA2 installs.
ALTER TABLE public.order_pricing
    ADD COLUMN IF NOT EXISTS voucher_code VARCHAR(30),
    ADD COLUMN IF NOT EXISTS voucher_discount_amount NUMERIC(10, 2) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS voucher_delivery_saving NUMERIC(10, 2) NOT NULL DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_voucher_active_code
    ON public.voucher (is_active, code);
CREATE INDEX IF NOT EXISTS idx_cart_voucher_voucher_id
    ON public.cart_voucher (voucher_id);

CREATE INDEX IF NOT EXISTS idx_pricing_rule_scope_active_priority
    ON public.pricing_rule (rule_scope, is_active, priority);
CREATE INDEX IF NOT EXISTS idx_pricing_rule_product_active
    ON public.pricing_rule (product_id, is_active);

-- Seed policy rows. Product tiers target the first available menu item, making the setup portable across seeded databases.
DO $$
DECLARE
    v_product_id INTEGER;
BEGIN
    SELECT product_id INTO v_product_id
      FROM public.product
     WHERE is_available = TRUE
     ORDER BY product_id
     LIMIT 1;

    IF v_product_id IS NOT NULL THEN
        INSERT INTO public.pricing_rule (name, rule_scope, rule_type, product_id, minimum_quantity, discount_percent, priority, is_active)
        VALUES
            ('Buy 3 product tier - 10 percent', 'PRODUCT', 'PRODUCT_QUANTITY_PERCENT', v_product_id, 3, 10.00, 10, TRUE),
            ('Buy 5 product tier - 15 percent', 'PRODUCT', 'PRODUCT_QUANTITY_PERCENT', v_product_id, 5, 15.00, 20, TRUE)
        ON CONFLICT (name) DO UPDATE
        SET product_id = EXCLUDED.product_id,
            minimum_quantity = EXCLUDED.minimum_quantity,
            discount_percent = EXCLUDED.discount_percent,
            priority = EXCLUDED.priority,
            is_active = EXCLUDED.is_active,
            updated_at = CURRENT_TIMESTAMP;
    END IF;

    INSERT INTO public.pricing_rule (name, rule_scope, rule_type, minimum_cart_value, discount_percent, priority, is_active)
    VALUES ('Spend 100 get 5 percent', 'CART', 'CART_VALUE_PERCENT', 100.00, 5.00, 10, TRUE)
    ON CONFLICT (name) DO UPDATE
    SET minimum_cart_value = EXCLUDED.minimum_cart_value,
        discount_percent = EXCLUDED.discount_percent,
        priority = EXCLUDED.priority,
        is_active = EXCLUDED.is_active,
        updated_at = CURRENT_TIMESTAMP;

    INSERT INTO public.pricing_rule (name, rule_scope, rule_type, minimum_cart_value, maximum_cart_value, delivery_fee, priority, is_active)
    VALUES
        ('Delivery under 50', 'DELIVERY', 'DELIVERY_TIER', 0.00, 49.99, 8.00, 10, TRUE),
        ('Delivery 50 to 99.99', 'DELIVERY', 'DELIVERY_TIER', 50.00, 99.99, 5.00, 20, TRUE),
        ('Free delivery from 100', 'DELIVERY', 'DELIVERY_TIER', 100.00, NULL, 0.00, 30, TRUE)
    ON CONFLICT (name) DO UPDATE
    SET minimum_cart_value = EXCLUDED.minimum_cart_value,
        maximum_cart_value = EXCLUDED.maximum_cart_value,
        delivery_fee = EXCLUDED.delivery_fee,
        priority = EXCLUDED.priority,
        is_active = EXCLUDED.is_active,
        updated_at = CURRENT_TIMESTAMP;
END;
$$;

-- Optional customer-selectable vouchers. Automatic CA2 rules still apply without a voucher selection.
INSERT INTO public.voucher (code, name, voucher_type, voucher_value, minimum_cart_value, is_active, description)
VALUES
    ('WELCOME10', 'Welcome 10% Off', 'PERCENT', 10.00, 20.00, TRUE, '10% off eligible orderable items when the subtotal is at least $20.'),
    ('SAVE5', 'Save $5', 'FIXED', 5.00, 30.00, TRUE, '$5 off eligible orderable items when the subtotal is at least $30.'),
    ('FREEDELIVERY', 'Free Delivery', 'FREE_DELIVERY', 0.00, 0.00, TRUE, 'Waives the delivery fee after automatic delivery-tier pricing.')
ON CONFLICT (code) DO UPDATE
SET name = EXCLUDED.name,
    voucher_type = EXCLUDED.voucher_type,
    voucher_value = EXCLUDED.voucher_value,
    minimum_cart_value = EXCLUDED.minimum_cart_value,
    is_active = EXCLUDED.is_active,
    description = EXCLUDED.description,
    updated_at = CURRENT_TIMESTAMP;

-- Required CA2 transaction procedure. It intentionally does not calculate discounts or delivery pricing.
-- Available items are processed and deleted from the cart; unavailable items are skipped and remain in the cart.
DROP PROCEDURE IF EXISTS public.place_orders(INTEGER);
DROP PROCEDURE IF EXISTS public.place_orders(INTEGER, INTEGER, INTEGER, INTEGER);

CREATE OR REPLACE PROCEDURE public.place_orders(
    IN p_member_id INTEGER,
    OUT p_order_id INTEGER,
    OUT p_processed_item_count INTEGER,
    OUT p_skipped_item_count INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_cart_id INTEGER;
    v_item RECORD;
    v_running_amount NUMERIC(10, 2) := 0;
BEGIN
    p_order_id := NULL;
    p_processed_item_count := 0;
    p_skipped_item_count := 0;

    SELECT cart_id
      INTO v_cart_id
      FROM public.cart
     WHERE member_id = p_member_id
       AND status = 'ACTIVE'
     ORDER BY cart_id DESC
     LIMIT 1
     FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'No active cart was found for this member.';
    END IF;

    FOR v_item IN
        SELECT ci.cart_item_id, ci.product_id, ci.quantity, p.price, p.is_available
          FROM public.cart_item ci
          JOIN public.product p ON p.product_id = ci.product_id
         WHERE ci.cart_id = v_cart_id
         ORDER BY ci.cart_item_id
         FOR UPDATE OF ci, p
    LOOP
        IF v_item.is_available THEN
            IF p_order_id IS NULL THEN
                INSERT INTO public.sale_order (member_id, order_date, total_amount, status)
                VALUES (p_member_id, CURRENT_TIMESTAMP, 0, 'PACKING')
                RETURNING order_id INTO p_order_id;
            END IF;

            INSERT INTO public.sale_order_item (order_id, product_id, quantity, unit_price, subtotal)
            VALUES (
                p_order_id,
                v_item.product_id,
                v_item.quantity,
                v_item.price,
                ROUND(v_item.quantity * v_item.price, 2)
            );

            v_running_amount := v_running_amount + ROUND(v_item.quantity * v_item.price, 2);
            DELETE FROM public.cart_item WHERE cart_item_id = v_item.cart_item_id;
            p_processed_item_count := p_processed_item_count + 1;
        ELSE
            p_skipped_item_count := p_skipped_item_count + 1;
        END IF;
    END LOOP;

    IF p_order_id IS NOT NULL THEN
        UPDATE public.sale_order
           SET total_amount = v_running_amount
         WHERE order_id = p_order_id;
    END IF;
END;
$$;

COMMIT;

-- Required code-repository evidence: copy the procedure definition from this file to functions_&_stored_procedures.sql.
