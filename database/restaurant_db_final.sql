--
-- PostgreSQL database dump
--

\restrict iUbU91Vjbpz0A5pI4PYcLmw9etmiUqywtLqhh86kyx2XANQu2vMfDMJdL8dI3EF

-- Dumped from database version 18.4
-- Dumped by pg_dump version 18.4

-- Started on 2026-08-14 14:05:21

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 255 (class 1255 OID 26470)
-- Name: create_feedback(integer, integer, integer, text); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public.create_feedback(IN p_member_id integer, IN p_product_id integer, IN p_rating integer, IN p_comments text)
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


--
-- TOC entry 259 (class 1255 OID 26474)
-- Name: create_response(integer, integer, text, integer); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public.create_response(IN p_feedback_id integer, IN p_member_id integer, IN p_response_text text, IN p_parent_response_id integer DEFAULT NULL::integer)
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


--
-- TOC entry 257 (class 1255 OID 26472)
-- Name: delete_feedback(integer, integer); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public.delete_feedback(IN p_feedback_id integer, IN p_member_id integer)
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


--
-- TOC entry 243 (class 1255 OID 26476)
-- Name: delete_response(integer, integer); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public.delete_response(IN p_response_id integer, IN p_member_id integer)
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


--
-- TOC entry 258 (class 1255 OID 26473)
-- Name: get_feedback(integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_feedback(p_member_id integer DEFAULT NULL::integer, p_product_id integer DEFAULT NULL::integer) RETURNS TABLE(feedback_id integer, member_id integer, product_id integer, product_name character varying, username character varying, rating integer, comments text, created_at timestamp without time zone, updated_at timestamp without time zone)
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


--
-- TOC entry 242 (class 1255 OID 26475)
-- Name: get_response(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_response(p_feedback_id integer) RETURNS TABLE(response_id integer, feedback_id integer, member_id integer, parent_response_id integer, username character varying, response_text text, created_at timestamp without time zone)
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


--
-- TOC entry 260 (class 1255 OID 26477)
-- Name: get_sale_order_summary(timestamp without time zone, timestamp without time zone, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_sale_order_summary(p_start_date timestamp without time zone DEFAULT NULL::timestamp without time zone, p_end_date timestamp without time zone DEFAULT NULL::timestamp without time zone, p_category character varying DEFAULT NULL::character varying, p_sort_by character varying DEFAULT 'order_date'::character varying, p_sort_order character varying DEFAULT 'DESC'::character varying) RETURNS TABLE(order_id integer, customer_name text, order_date timestamp without time zone, total_amount numeric, status character varying, total_items bigint, products text)
    LANGUAGE plpgsql
    AS $_$
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
$_$;


--
-- TOC entry 261 (class 1255 OID 26478)
-- Name: place_orders(integer); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public.place_orders(IN p_member_id integer, OUT p_order_id integer, OUT p_processed_item_count integer, OUT p_skipped_item_count integer)
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


--
-- TOC entry 256 (class 1255 OID 26471)
-- Name: update_feedback(integer, integer, integer, text); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public.update_feedback(IN p_feedback_id integer, IN p_member_id integer, IN p_rating integer, IN p_comments text)
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


--
-- TOC entry 229 (class 1259 OID 26246)
-- Name: cart; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cart (
    cart_id integer NOT NULL,
    member_id integer NOT NULL,
    status character varying(20) DEFAULT 'ACTIVE'::character varying NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT cart_status_check CHECK (((status)::text = ANY ((ARRAY['ACTIVE'::character varying, 'CHECKED_OUT'::character varying, 'ABANDONED'::character varying])::text[])))
);


--
-- TOC entry 228 (class 1259 OID 26245)
-- Name: cart_cart_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.cart_cart_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 5189 (class 0 OID 0)
-- Dependencies: 228
-- Name: cart_cart_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.cart_cart_id_seq OWNED BY public.cart.cart_id;


--
-- TOC entry 231 (class 1259 OID 26267)
-- Name: cart_item; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cart_item (
    cart_item_id integer NOT NULL,
    cart_id integer NOT NULL,
    product_id integer NOT NULL,
    quantity integer DEFAULT 1 NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT cart_item_quantity_check CHECK ((quantity > 0))
);


--
-- TOC entry 230 (class 1259 OID 26266)
-- Name: cart_item_cart_item_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.cart_item_cart_item_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 5190 (class 0 OID 0)
-- Dependencies: 230
-- Name: cart_item_cart_item_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.cart_item_cart_item_id_seq OWNED BY public.cart_item.cart_item_id;


--
-- TOC entry 236 (class 1259 OID 26355)
-- Name: cart_voucher; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cart_voucher (
    cart_id integer NOT NULL,
    voucher_id integer NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- TOC entry 239 (class 1259 OID 26413)
-- Name: dining_feedback; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.dining_feedback (
    feedback_id integer NOT NULL,
    member_id integer NOT NULL,
    product_id integer NOT NULL,
    rating integer NOT NULL,
    comments text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT dining_feedback_rating_check CHECK (((rating >= 1) AND (rating <= 5)))
);


--
-- TOC entry 238 (class 1259 OID 26412)
-- Name: dining_feedback_feedback_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.dining_feedback_feedback_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 5191 (class 0 OID 0)
-- Dependencies: 238
-- Name: dining_feedback_feedback_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.dining_feedback_feedback_id_seq OWNED BY public.dining_feedback.feedback_id;


--
-- TOC entry 241 (class 1259 OID 26441)
-- Name: feedback_response; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.feedback_response (
    response_id integer NOT NULL,
    feedback_id integer NOT NULL,
    member_id integer NOT NULL,
    parent_response_id integer,
    response_text text NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT feedback_response_text_check CHECK ((length(TRIM(BOTH FROM response_text)) > 0))
);


--
-- TOC entry 240 (class 1259 OID 26440)
-- Name: feedback_response_response_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.feedback_response_response_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 5192 (class 0 OID 0)
-- Dependencies: 240
-- Name: feedback_response_response_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.feedback_response_response_id_seq OWNED BY public.feedback_response.response_id;


--
-- TOC entry 219 (class 1259 OID 26157)
-- Name: member; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.member (
    member_id integer NOT NULL,
    username character varying(50) NOT NULL,
    email character varying(100) NOT NULL,
    password_hash character varying(255) NOT NULL,
    first_name character varying(50) NOT NULL,
    last_name character varying(50) NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- TOC entry 220 (class 1259 OID 26169)
-- Name: member_member_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.member_member_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 5193 (class 0 OID 0)
-- Dependencies: 220
-- Name: member_member_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.member_member_id_seq OWNED BY public.member.member_id;


--
-- TOC entry 221 (class 1259 OID 26170)
-- Name: member_role; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.member_role (
    member_id integer NOT NULL,
    role character varying(20) NOT NULL,
    CONSTRAINT member_role_role_check CHECK (((role)::text = ANY (ARRAY[('ADMIN'::character varying)::text, ('USER'::character varying)::text])))
);


--
-- TOC entry 237 (class 1259 OID 26376)
-- Name: order_pricing; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.order_pricing (
    order_id integer NOT NULL,
    items_subtotal numeric(10,2) NOT NULL,
    product_discount_amount numeric(10,2) DEFAULT 0 NOT NULL,
    cart_discount_amount numeric(10,2) DEFAULT 0 NOT NULL,
    delivery_fee numeric(10,2) DEFAULT 0 NOT NULL,
    delivery_discount_amount numeric(10,2) DEFAULT 0 NOT NULL,
    voucher_code character varying(30),
    voucher_discount_amount numeric(10,2) DEFAULT 0 NOT NULL,
    voucher_delivery_saving numeric(10,2) DEFAULT 0 NOT NULL,
    final_total numeric(10,2) NOT NULL,
    pricing_snapshot jsonb NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT order_pricing_non_negative_check CHECK (((items_subtotal >= (0)::numeric) AND (product_discount_amount >= (0)::numeric) AND (cart_discount_amount >= (0)::numeric) AND (delivery_fee >= (0)::numeric) AND (delivery_discount_amount >= (0)::numeric) AND (voucher_discount_amount >= (0)::numeric) AND (voucher_delivery_saving >= (0)::numeric) AND (final_total >= (0)::numeric)))
);


--
-- TOC entry 233 (class 1259 OID 26299)
-- Name: pricing_rule; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pricing_rule (
    pricing_rule_id integer NOT NULL,
    name character varying(120) NOT NULL,
    rule_scope character varying(20) NOT NULL,
    rule_type character varying(40) NOT NULL,
    product_id integer,
    minimum_quantity integer,
    minimum_cart_value numeric(10,2),
    maximum_cart_value numeric(10,2),
    discount_percent numeric(5,2),
    delivery_fee numeric(10,2),
    priority integer DEFAULT 0 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT pricing_rule_scope_check CHECK (((rule_scope)::text = ANY ((ARRAY['PRODUCT'::character varying, 'CART'::character varying, 'DELIVERY'::character varying])::text[]))),
    CONSTRAINT pricing_rule_shape_check CHECK (((((rule_type)::text = 'PRODUCT_QUANTITY_PERCENT'::text) AND ((rule_scope)::text = 'PRODUCT'::text) AND (product_id IS NOT NULL) AND (minimum_quantity IS NOT NULL) AND (discount_percent IS NOT NULL)) OR (((rule_type)::text = 'CART_VALUE_PERCENT'::text) AND ((rule_scope)::text = 'CART'::text) AND (minimum_cart_value IS NOT NULL) AND (discount_percent IS NOT NULL)) OR (((rule_type)::text = 'DELIVERY_TIER'::text) AND ((rule_scope)::text = 'DELIVERY'::text) AND (minimum_cart_value IS NOT NULL) AND (delivery_fee IS NOT NULL)))),
    CONSTRAINT pricing_rule_type_check CHECK (((rule_type)::text = ANY ((ARRAY['PRODUCT_QUANTITY_PERCENT'::character varying, 'CART_VALUE_PERCENT'::character varying, 'DELIVERY_TIER'::character varying])::text[]))),
    CONSTRAINT pricing_rule_value_check CHECK ((((discount_percent IS NULL) OR ((discount_percent >= (0)::numeric) AND (discount_percent <= (100)::numeric))) AND ((delivery_fee IS NULL) OR (delivery_fee >= (0)::numeric)) AND ((minimum_quantity IS NULL) OR (minimum_quantity > 0)) AND ((minimum_cart_value IS NULL) OR (minimum_cart_value >= (0)::numeric)) AND ((maximum_cart_value IS NULL) OR (maximum_cart_value >= (0)::numeric))))
);


--
-- TOC entry 232 (class 1259 OID 26298)
-- Name: pricing_rule_pricing_rule_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.pricing_rule_pricing_rule_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 5194 (class 0 OID 0)
-- Dependencies: 232
-- Name: pricing_rule_pricing_rule_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.pricing_rule_pricing_rule_id_seq OWNED BY public.pricing_rule.pricing_rule_id;


--
-- TOC entry 222 (class 1259 OID 26176)
-- Name: product; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.product (
    product_id integer NOT NULL,
    name character varying(100) NOT NULL,
    description text,
    price numeric(10,2) NOT NULL,
    category character varying(50),
    is_available boolean DEFAULT true,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- TOC entry 223 (class 1259 OID 26186)
-- Name: product_product_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.product_product_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 5195 (class 0 OID 0)
-- Dependencies: 223
-- Name: product_product_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.product_product_id_seq OWNED BY public.product.product_id;


--
-- TOC entry 224 (class 1259 OID 26187)
-- Name: sale_order; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sale_order (
    order_id integer NOT NULL,
    member_id integer,
    order_date timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    total_amount numeric(10,2) NOT NULL,
    status character varying(20) NOT NULL,
    delivery_address text,
    CONSTRAINT sale_order_status_check CHECK (((status)::text = ANY (ARRAY[('COMPLETED'::character varying)::text, ('CANCELLED'::character varying)::text, ('PACKING'::character varying)::text])))
);


--
-- TOC entry 225 (class 1259 OID 26197)
-- Name: sale_order_item; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sale_order_item (
    order_item_id integer NOT NULL,
    order_id integer,
    product_id integer,
    quantity integer NOT NULL,
    unit_price numeric(10,2) NOT NULL,
    subtotal numeric(10,2) NOT NULL,
    CONSTRAINT sale_order_item_quantity_check CHECK ((quantity > 0))
);


--
-- TOC entry 226 (class 1259 OID 26205)
-- Name: sale_order_item_order_item_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sale_order_item_order_item_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 5196 (class 0 OID 0)
-- Dependencies: 226
-- Name: sale_order_item_order_item_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sale_order_item_order_item_id_seq OWNED BY public.sale_order_item.order_item_id;


--
-- TOC entry 227 (class 1259 OID 26206)
-- Name: sale_order_order_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sale_order_order_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 5197 (class 0 OID 0)
-- Dependencies: 227
-- Name: sale_order_order_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sale_order_order_id_seq OWNED BY public.sale_order.order_id;


--
-- TOC entry 235 (class 1259 OID 26329)
-- Name: voucher; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.voucher (
    voucher_id integer NOT NULL,
    code character varying(30) NOT NULL,
    name character varying(120) NOT NULL,
    voucher_type character varying(30) NOT NULL,
    voucher_value numeric(10,2) NOT NULL,
    minimum_cart_value numeric(10,2) DEFAULT 0 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    description text NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT voucher_type_check CHECK (((voucher_type)::text = ANY ((ARRAY['PERCENT'::character varying, 'FIXED'::character varying, 'FREE_DELIVERY'::character varying])::text[]))),
    CONSTRAINT voucher_value_check CHECK (((voucher_value >= (0)::numeric) AND (minimum_cart_value >= (0)::numeric)))
);


--
-- TOC entry 234 (class 1259 OID 26328)
-- Name: voucher_voucher_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.voucher_voucher_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 5198 (class 0 OID 0)
-- Dependencies: 234
-- Name: voucher_voucher_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.voucher_voucher_id_seq OWNED BY public.voucher.voucher_id;


--
-- TOC entry 4930 (class 2604 OID 26249)
-- Name: cart cart_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cart ALTER COLUMN cart_id SET DEFAULT nextval('public.cart_cart_id_seq'::regclass);


--
-- TOC entry 4934 (class 2604 OID 26270)
-- Name: cart_item cart_item_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cart_item ALTER COLUMN cart_item_id SET DEFAULT nextval('public.cart_item_cart_item_id_seq'::regclass);


--
-- TOC entry 4957 (class 2604 OID 26416)
-- Name: dining_feedback feedback_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dining_feedback ALTER COLUMN feedback_id SET DEFAULT nextval('public.dining_feedback_feedback_id_seq'::regclass);


--
-- TOC entry 4960 (class 2604 OID 26444)
-- Name: feedback_response response_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.feedback_response ALTER COLUMN response_id SET DEFAULT nextval('public.feedback_response_response_id_seq'::regclass);


--
-- TOC entry 4922 (class 2604 OID 26207)
-- Name: member member_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.member ALTER COLUMN member_id SET DEFAULT nextval('public.member_member_id_seq'::regclass);


--
-- TOC entry 4938 (class 2604 OID 26302)
-- Name: pricing_rule pricing_rule_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pricing_rule ALTER COLUMN pricing_rule_id SET DEFAULT nextval('public.pricing_rule_pricing_rule_id_seq'::regclass);


--
-- TOC entry 4924 (class 2604 OID 26208)
-- Name: product product_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product ALTER COLUMN product_id SET DEFAULT nextval('public.product_product_id_seq'::regclass);


--
-- TOC entry 4927 (class 2604 OID 26209)
-- Name: sale_order order_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sale_order ALTER COLUMN order_id SET DEFAULT nextval('public.sale_order_order_id_seq'::regclass);


--
-- TOC entry 4929 (class 2604 OID 26210)
-- Name: sale_order_item order_item_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sale_order_item ALTER COLUMN order_item_id SET DEFAULT nextval('public.sale_order_item_order_item_id_seq'::regclass);


--
-- TOC entry 4943 (class 2604 OID 26332)
-- Name: voucher voucher_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.voucher ALTER COLUMN voucher_id SET DEFAULT nextval('public.voucher_voucher_id_seq'::regclass);


--
-- TOC entry 4995 (class 2606 OID 26284)
-- Name: cart_item cart_item_cart_id_product_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cart_item
    ADD CONSTRAINT cart_item_cart_id_product_id_key UNIQUE (cart_id, product_id);


--
-- TOC entry 4997 (class 2606 OID 26282)
-- Name: cart_item cart_item_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cart_item
    ADD CONSTRAINT cart_item_pkey PRIMARY KEY (cart_item_id);


--
-- TOC entry 4991 (class 2606 OID 26260)
-- Name: cart cart_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cart
    ADD CONSTRAINT cart_pkey PRIMARY KEY (cart_id);


--
-- TOC entry 5011 (class 2606 OID 26365)
-- Name: cart_voucher cart_voucher_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cart_voucher
    ADD CONSTRAINT cart_voucher_pkey PRIMARY KEY (cart_id);


--
-- TOC entry 5016 (class 2606 OID 26429)
-- Name: dining_feedback dining_feedback_member_product_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dining_feedback
    ADD CONSTRAINT dining_feedback_member_product_key UNIQUE (member_id, product_id);


--
-- TOC entry 5018 (class 2606 OID 26427)
-- Name: dining_feedback dining_feedback_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dining_feedback
    ADD CONSTRAINT dining_feedback_pkey PRIMARY KEY (feedback_id);


--
-- TOC entry 5020 (class 2606 OID 26454)
-- Name: feedback_response feedback_response_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.feedback_response
    ADD CONSTRAINT feedback_response_pkey PRIMARY KEY (response_id);


--
-- TOC entry 4977 (class 2606 OID 26212)
-- Name: member member_email_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.member
    ADD CONSTRAINT member_email_key UNIQUE (email);


--
-- TOC entry 4979 (class 2606 OID 26214)
-- Name: member member_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.member
    ADD CONSTRAINT member_pkey PRIMARY KEY (member_id);


--
-- TOC entry 4983 (class 2606 OID 26216)
-- Name: member_role member_role_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.member_role
    ADD CONSTRAINT member_role_pkey PRIMARY KEY (member_id, role);


--
-- TOC entry 4981 (class 2606 OID 26218)
-- Name: member member_username_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.member
    ADD CONSTRAINT member_username_key UNIQUE (username);


--
-- TOC entry 5014 (class 2606 OID 26401)
-- Name: order_pricing order_pricing_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_pricing
    ADD CONSTRAINT order_pricing_pkey PRIMARY KEY (order_id);


--
-- TOC entry 5002 (class 2606 OID 26322)
-- Name: pricing_rule pricing_rule_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pricing_rule
    ADD CONSTRAINT pricing_rule_name_key UNIQUE (name);


--
-- TOC entry 5004 (class 2606 OID 26320)
-- Name: pricing_rule pricing_rule_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pricing_rule
    ADD CONSTRAINT pricing_rule_pkey PRIMARY KEY (pricing_rule_id);


--
-- TOC entry 4985 (class 2606 OID 26220)
-- Name: product product_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product
    ADD CONSTRAINT product_pkey PRIMARY KEY (product_id);


--
-- TOC entry 4989 (class 2606 OID 26222)
-- Name: sale_order_item sale_order_item_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sale_order_item
    ADD CONSTRAINT sale_order_item_pkey PRIMARY KEY (order_item_id);


--
-- TOC entry 4987 (class 2606 OID 26224)
-- Name: sale_order sale_order_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sale_order
    ADD CONSTRAINT sale_order_pkey PRIMARY KEY (order_id);


--
-- TOC entry 5007 (class 2606 OID 26354)
-- Name: voucher voucher_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.voucher
    ADD CONSTRAINT voucher_code_key UNIQUE (code);


--
-- TOC entry 5009 (class 2606 OID 26352)
-- Name: voucher voucher_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.voucher
    ADD CONSTRAINT voucher_pkey PRIMARY KEY (voucher_id);


--
-- TOC entry 4998 (class 1259 OID 26297)
-- Name: idx_cart_item_product_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_cart_item_product_id ON public.cart_item USING btree (product_id);


--
-- TOC entry 4992 (class 1259 OID 26296)
-- Name: idx_cart_member_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_cart_member_status ON public.cart USING btree (member_id, status);


--
-- TOC entry 5012 (class 1259 OID 26408)
-- Name: idx_cart_voucher_voucher_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_cart_voucher_voucher_id ON public.cart_voucher USING btree (voucher_id);


--
-- TOC entry 4999 (class 1259 OID 26410)
-- Name: idx_pricing_rule_product_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pricing_rule_product_active ON public.pricing_rule USING btree (product_id, is_active);


--
-- TOC entry 5000 (class 1259 OID 26409)
-- Name: idx_pricing_rule_scope_active_priority; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pricing_rule_scope_active_priority ON public.pricing_rule USING btree (rule_scope, is_active, priority);


--
-- TOC entry 5005 (class 1259 OID 26407)
-- Name: idx_voucher_active_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_voucher_active_code ON public.voucher USING btree (is_active, code);


--
-- TOC entry 4993 (class 1259 OID 26295)
-- Name: uq_cart_one_active_per_member; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_cart_one_active_per_member ON public.cart USING btree (member_id) WHERE ((status)::text = 'ACTIVE'::text);


--
-- TOC entry 5026 (class 2606 OID 26285)
-- Name: cart_item cart_item_cart_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cart_item
    ADD CONSTRAINT cart_item_cart_id_fkey FOREIGN KEY (cart_id) REFERENCES public.cart(cart_id) ON DELETE CASCADE;


--
-- TOC entry 5027 (class 2606 OID 26290)
-- Name: cart_item cart_item_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cart_item
    ADD CONSTRAINT cart_item_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.product(product_id);


--
-- TOC entry 5025 (class 2606 OID 26261)
-- Name: cart cart_member_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cart
    ADD CONSTRAINT cart_member_id_fkey FOREIGN KEY (member_id) REFERENCES public.member(member_id) ON DELETE CASCADE;


--
-- TOC entry 5029 (class 2606 OID 26366)
-- Name: cart_voucher cart_voucher_cart_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cart_voucher
    ADD CONSTRAINT cart_voucher_cart_id_fkey FOREIGN KEY (cart_id) REFERENCES public.cart(cart_id) ON DELETE CASCADE;


--
-- TOC entry 5030 (class 2606 OID 26371)
-- Name: cart_voucher cart_voucher_voucher_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cart_voucher
    ADD CONSTRAINT cart_voucher_voucher_id_fkey FOREIGN KEY (voucher_id) REFERENCES public.voucher(voucher_id);


--
-- TOC entry 5032 (class 2606 OID 26430)
-- Name: dining_feedback dining_feedback_member_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dining_feedback
    ADD CONSTRAINT dining_feedback_member_fkey FOREIGN KEY (member_id) REFERENCES public.member(member_id) ON DELETE CASCADE;


--
-- TOC entry 5033 (class 2606 OID 26435)
-- Name: dining_feedback dining_feedback_product_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dining_feedback
    ADD CONSTRAINT dining_feedback_product_fkey FOREIGN KEY (product_id) REFERENCES public.product(product_id) ON DELETE CASCADE;


--
-- TOC entry 5034 (class 2606 OID 26455)
-- Name: feedback_response feedback_response_feedback_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.feedback_response
    ADD CONSTRAINT feedback_response_feedback_fkey FOREIGN KEY (feedback_id) REFERENCES public.dining_feedback(feedback_id) ON DELETE CASCADE;


--
-- TOC entry 5035 (class 2606 OID 26460)
-- Name: feedback_response feedback_response_member_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.feedback_response
    ADD CONSTRAINT feedback_response_member_fkey FOREIGN KEY (member_id) REFERENCES public.member(member_id) ON DELETE CASCADE;


--
-- TOC entry 5036 (class 2606 OID 26465)
-- Name: feedback_response feedback_response_parent_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.feedback_response
    ADD CONSTRAINT feedback_response_parent_fkey FOREIGN KEY (parent_response_id) REFERENCES public.feedback_response(response_id) ON DELETE CASCADE;


--
-- TOC entry 5021 (class 2606 OID 26225)
-- Name: member_role member_role_member_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.member_role
    ADD CONSTRAINT member_role_member_id_fkey FOREIGN KEY (member_id) REFERENCES public.member(member_id);


--
-- TOC entry 5031 (class 2606 OID 26402)
-- Name: order_pricing order_pricing_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_pricing
    ADD CONSTRAINT order_pricing_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.sale_order(order_id) ON DELETE CASCADE;


--
-- TOC entry 5028 (class 2606 OID 26323)
-- Name: pricing_rule pricing_rule_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pricing_rule
    ADD CONSTRAINT pricing_rule_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.product(product_id) ON DELETE CASCADE;


--
-- TOC entry 5023 (class 2606 OID 26230)
-- Name: sale_order_item sale_order_item_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sale_order_item
    ADD CONSTRAINT sale_order_item_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.sale_order(order_id);


--
-- TOC entry 5024 (class 2606 OID 26235)
-- Name: sale_order_item sale_order_item_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sale_order_item
    ADD CONSTRAINT sale_order_item_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.product(product_id);


--
-- TOC entry 5022 (class 2606 OID 26240)
-- Name: sale_order sale_order_member_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sale_order
    ADD CONSTRAINT sale_order_member_id_fkey FOREIGN KEY (member_id) REFERENCES public.member(member_id);


-- Completed on 2026-08-14 14:05:21

--
-- PostgreSQL database dump complete
--

\unrestrict iUbU91Vjbpz0A5pI4PYcLmw9etmiUqywtLqhh86kyx2XANQu2vMfDMJdL8dI3EF

