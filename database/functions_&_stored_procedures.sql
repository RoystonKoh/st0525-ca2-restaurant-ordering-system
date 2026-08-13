-- ST0525 Database Systems CA1
-- Run this file in pgAdmin 4 after restoring restaurant_db_restore.sql.

CREATE TABLE IF NOT EXISTS public.dining_feedback (
    feedback_id SERIAL PRIMARY KEY,
    member_id INTEGER NOT NULL,
    product_id INTEGER NOT NULL,
    rating INTEGER NOT NULL,
    comments TEXT,
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT dining_feedback_rating_check CHECK (rating BETWEEN 1 AND 5),
    CONSTRAINT dining_feedback_member_fkey
        FOREIGN KEY (member_id) REFERENCES public.member(member_id) ON DELETE CASCADE,
    CONSTRAINT dining_feedback_product_fkey
        FOREIGN KEY (product_id) REFERENCES public.product(product_id) ON DELETE CASCADE,
    CONSTRAINT dining_feedback_member_product_key UNIQUE (member_id, product_id)
);

CREATE TABLE IF NOT EXISTS public.feedback_response (
    response_id SERIAL PRIMARY KEY,
    feedback_id INTEGER NOT NULL,
    member_id INTEGER NOT NULL,
    parent_response_id INTEGER,
    response_text TEXT NOT NULL,
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT feedback_response_feedback_fkey
        FOREIGN KEY (feedback_id) REFERENCES public.dining_feedback(feedback_id) ON DELETE CASCADE,
    CONSTRAINT feedback_response_member_fkey
        FOREIGN KEY (member_id) REFERENCES public.member(member_id) ON DELETE CASCADE,
    CONSTRAINT feedback_response_parent_fkey
        FOREIGN KEY (parent_response_id) REFERENCES public.feedback_response(response_id) ON DELETE CASCADE,
    CONSTRAINT feedback_response_text_check CHECK (length(trim(response_text)) > 0)
);

ALTER TABLE public.feedback_response
    ADD COLUMN IF NOT EXISTS parent_response_id INTEGER;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'feedback_response_parent_fkey'
    ) THEN
        ALTER TABLE public.feedback_response
            ADD CONSTRAINT feedback_response_parent_fkey
            FOREIGN KEY (parent_response_id)
            REFERENCES public.feedback_response(response_id)
            ON DELETE CASCADE;
    END IF;
END;
$$;

CREATE OR REPLACE PROCEDURE public.create_feedback(
    p_member_id INTEGER,
    p_product_id INTEGER,
    p_rating INTEGER,
    p_comments TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_has_completed_order BOOLEAN;
BEGIN
    IF p_rating IS NULL OR p_rating < 1 OR p_rating > 5 THEN
        RAISE EXCEPTION 'Rating must be between 1 and 5.';
    END IF;

    SELECT EXISTS (
        SELECT 1
        FROM public.sale_order so
        JOIN public.sale_order_item soi ON soi.order_id = so.order_id
        WHERE so.member_id = p_member_id
          AND soi.product_id = p_product_id
          AND so.status = 'COMPLETED'
    ) INTO v_has_completed_order;

    IF NOT v_has_completed_order THEN
        RAISE EXCEPTION 'You can only submit feedback for products in a completed order.';
    END IF;

    INSERT INTO public.dining_feedback (member_id, product_id, rating, comments)
    VALUES (p_member_id, p_product_id, p_rating, nullif(trim(coalesce(p_comments, '')), ''));

EXCEPTION
    WHEN unique_violation THEN
        RAISE EXCEPTION 'You have already submitted feedback for this product.';
END;
$$;

CREATE OR REPLACE PROCEDURE public.update_feedback(
    p_feedback_id INTEGER,
    p_member_id INTEGER,
    p_rating INTEGER,
    p_comments TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_owner_id INTEGER;
BEGIN
    IF p_rating IS NULL OR p_rating < 1 OR p_rating > 5 THEN
        RAISE EXCEPTION 'Rating must be between 1 and 5.';
    END IF;

    SELECT member_id INTO v_owner_id
    FROM public.dining_feedback
    WHERE feedback_id = p_feedback_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Feedback not found.';
    END IF;

    IF v_owner_id <> p_member_id THEN
        RAISE EXCEPTION 'You can only update your own feedback.';
    END IF;

    UPDATE public.dining_feedback
    SET rating = p_rating,
        comments = nullif(trim(coalesce(p_comments, '')), ''),
        updated_at = CURRENT_TIMESTAMP
    WHERE feedback_id = p_feedback_id;
END;
$$;

CREATE OR REPLACE PROCEDURE public.delete_feedback(
    p_feedback_id INTEGER,
    p_member_id INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_owner_id INTEGER;
BEGIN
    SELECT member_id INTO v_owner_id
    FROM public.dining_feedback
    WHERE feedback_id = p_feedback_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Feedback not found.';
    END IF;

    IF v_owner_id <> p_member_id THEN
        RAISE EXCEPTION 'You can only delete your own feedback.';
    END IF;

    DELETE FROM public.dining_feedback
    WHERE feedback_id = p_feedback_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_feedback(
    p_member_id INTEGER DEFAULT NULL,
    p_product_id INTEGER DEFAULT NULL
)
RETURNS TABLE (
    feedback_id INTEGER,
    member_id INTEGER,
    product_id INTEGER,
    product_name VARCHAR,
    username VARCHAR,
    rating INTEGER,
    comments TEXT,
    created_at TIMESTAMP WITHOUT TIME ZONE,
    updated_at TIMESTAMP WITHOUT TIME ZONE
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        df.feedback_id,
        df.member_id,
        df.product_id,
        p.name AS product_name,
        m.username,
        df.rating,
        df.comments,
        df.created_at,
        df.updated_at
    FROM public.dining_feedback df
    JOIN public.member m ON m.member_id = df.member_id
    JOIN public.product p ON p.product_id = df.product_id
    WHERE (p_member_id IS NULL OR df.member_id = p_member_id)
      AND (p_product_id IS NULL OR df.product_id = p_product_id)
    ORDER BY df.updated_at DESC, df.created_at DESC;
END;
$$;

DROP PROCEDURE IF EXISTS public.create_response(INTEGER, INTEGER, TEXT);

CREATE OR REPLACE PROCEDURE public.create_response(
    p_feedback_id INTEGER,
    p_member_id INTEGER,
    p_response_text TEXT,
    p_parent_response_id INTEGER DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_feedback_owner_id INTEGER;
    v_parent_owner_id INTEGER;
    v_parent_feedback_id INTEGER;
BEGIN
    IF p_response_text IS NULL OR length(trim(p_response_text)) = 0 THEN
        RAISE EXCEPTION 'Response text cannot be empty.';
    END IF;

    SELECT member_id INTO v_feedback_owner_id
    FROM public.dining_feedback
    WHERE feedback_id = p_feedback_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Feedback not found.';
    END IF;

    IF p_parent_response_id IS NULL AND v_feedback_owner_id = p_member_id THEN
        RAISE EXCEPTION 'You cannot respond to your own feedback.';
    END IF;

    IF p_parent_response_id IS NOT NULL THEN
        SELECT member_id, feedback_id
        INTO v_parent_owner_id, v_parent_feedback_id
        FROM public.feedback_response
        WHERE response_id = p_parent_response_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Parent response not found.';
        END IF;

        IF v_parent_feedback_id <> p_feedback_id THEN
            RAISE EXCEPTION 'Parent response does not belong to this feedback.';
        END IF;

        IF v_parent_owner_id = p_member_id THEN
            RAISE EXCEPTION 'You cannot reply to your own response.';
        END IF;
    END IF;

    INSERT INTO public.feedback_response (feedback_id, member_id, parent_response_id, response_text)
    VALUES (p_feedback_id, p_member_id, p_parent_response_id, trim(p_response_text));
END;
$$;

DROP FUNCTION IF EXISTS public.get_response(INTEGER);

CREATE OR REPLACE FUNCTION public.get_response(
    p_feedback_id INTEGER
)
RETURNS TABLE (
    response_id INTEGER,
    feedback_id INTEGER,
    member_id INTEGER,
    parent_response_id INTEGER,
    username VARCHAR,
    response_text TEXT,
    created_at TIMESTAMP WITHOUT TIME ZONE
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        fr.response_id,
        fr.feedback_id,
        fr.member_id,
        fr.parent_response_id,
        m.username,
        fr.response_text,
        fr.created_at
    FROM public.feedback_response fr
    JOIN public.member m ON m.member_id = fr.member_id
    WHERE fr.feedback_id = p_feedback_id
    ORDER BY fr.created_at ASC;
END;
$$;

CREATE OR REPLACE PROCEDURE public.delete_response(
    p_response_id INTEGER,
    p_member_id INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_owner_id INTEGER;
BEGIN
    SELECT member_id INTO v_owner_id
    FROM public.feedback_response
    WHERE response_id = p_response_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Response not found.';
    END IF;

    IF v_owner_id <> p_member_id THEN
        RAISE EXCEPTION 'You can only delete your own responses.';
    END IF;

    DELETE FROM public.feedback_response
    WHERE response_id = p_response_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_sale_order_summary(
    p_start_date TIMESTAMP WITHOUT TIME ZONE DEFAULT NULL,
    p_end_date TIMESTAMP WITHOUT TIME ZONE DEFAULT NULL,
    p_category VARCHAR DEFAULT NULL,
    p_sort_by VARCHAR DEFAULT 'order_date',
    p_sort_order VARCHAR DEFAULT 'DESC'
)
RETURNS TABLE (
    order_id INTEGER,
    customer_name TEXT,
    order_date TIMESTAMP WITHOUT TIME ZONE,
    total_amount NUMERIC,
    status VARCHAR,
    total_items BIGINT,
    products TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF upper(p_sort_order) NOT IN ('ASC', 'DESC') THEN
        RAISE EXCEPTION 'sort_order must be ASC or DESC.';
    END IF;

    IF p_sort_by NOT IN ('order_date', 'total_amount', 'customer_name', 'status', 'total_items') THEN
        RAISE EXCEPTION 'Invalid sort_by column.';
    END IF;

    RETURN QUERY EXECUTE format(
        'SELECT
            so.order_id,
            (m.first_name || '' '' || m.last_name)::TEXT AS customer_name,
            so.order_date,
            so.total_amount,
            so.status,
            SUM(soi.quantity)::BIGINT AS total_items,
            STRING_AGG(p.name || '' x'' || soi.quantity, '', '' ORDER BY p.name)::TEXT AS products
         FROM public.sale_order so
         JOIN public.member m ON m.member_id = so.member_id
         JOIN public.sale_order_item soi ON soi.order_id = so.order_id
         JOIN public.product p ON p.product_id = soi.product_id
         WHERE ($1 IS NULL OR so.order_date >= $1)
           AND ($2 IS NULL OR so.order_date <= $2)
           AND ($3 IS NULL OR p.category = $3)
         GROUP BY so.order_id, m.first_name, m.last_name, so.order_date, so.total_amount, so.status
         ORDER BY %I %s',
        p_sort_by,
        upper(p_sort_order)
    )
    USING p_start_date, p_end_date, p_category;
END;
$$;


-- ST0525 Database Systems CA2: required per-item cart processing procedure.
-- Discount and delivery calculation deliberately remain outside this procedure, as required by the CA2 brief.
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

    SELECT cart_id INTO v_cart_id
    FROM public.cart
    WHERE member_id = p_member_id AND status = 'ACTIVE'
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
            VALUES (p_order_id, v_item.product_id, v_item.quantity, v_item.price, ROUND(v_item.quantity * v_item.price, 2));

            v_running_amount := v_running_amount + ROUND(v_item.quantity * v_item.price, 2);
            DELETE FROM public.cart_item WHERE cart_item_id = v_item.cart_item_id;
            p_processed_item_count := p_processed_item_count + 1;
        ELSE
            p_skipped_item_count := p_skipped_item_count + 1;
        END IF;
    END LOOP;

    IF p_order_id IS NOT NULL THEN
        UPDATE public.sale_order SET total_amount = v_running_amount WHERE order_id = p_order_id;
    END IF;
END;
$$;
