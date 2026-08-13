-- ST0525 DBS CA2: Cart and CartItem database design.
-- Run this first after restoring restaurant_db. Then run ca2_official_pricing_and_transactions.sql.
-- Cart CRUD is implemented through Prisma ORM; this SQL defines the new entities and database constraints.

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

-- One active cart per member, while checked-out/abandoned cart history remains valid.
CREATE UNIQUE INDEX IF NOT EXISTS uq_cart_one_active_per_member
    ON public.cart (member_id)
    WHERE status = 'ACTIVE';

-- Supports Prisma lookups of a member's active cart and product/cart-item relationships.
CREATE INDEX IF NOT EXISTS idx_cart_member_status
    ON public.cart (member_id, status);
CREATE INDEX IF NOT EXISTS idx_cart_item_product_id
    ON public.cart_item (product_id);

COMMIT;
