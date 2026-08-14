--
-- PostgreSQL database dump
--

\restrict L5g9nNdzbmMDe3PJ2LxwB1cMbr4IhMM78EzgIsLNmkZHuL5lnymLUKPcgiQGdoa

-- Dumped from database version 18.4
-- Dumped by pg_dump version 18.4

-- Started on 2026-08-14 14:05:48

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
-- TOC entry 219 (class 1259 OID 26051)
-- Name: manufacturer; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.manufacturer (
    id integer NOT NULL,
    firm_name character varying(255) NOT NULL,
    origin character varying(100) NOT NULL,
    description text,
    location character varying(255),
    website character varying(255),
    support_email character varying(50) NOT NULL,
    employee_count integer,
    founded_since date,
    is_operational boolean,
    product_category character varying(100)
);


--
-- TOC entry 220 (class 1259 OID 26060)
-- Name: manufacturer_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.manufacturer_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 5011 (class 0 OID 0)
-- Dependencies: 220
-- Name: manufacturer_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.manufacturer_id_seq OWNED BY public.manufacturer.id;


--
-- TOC entry 4856 (class 2604 OID 26061)
-- Name: manufacturer id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.manufacturer ALTER COLUMN id SET DEFAULT nextval('public.manufacturer_id_seq'::regclass);


--
-- TOC entry 4858 (class 2606 OID 26063)
-- Name: manufacturer manufacturer_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.manufacturer
    ADD CONSTRAINT manufacturer_pkey PRIMARY KEY (id);


-- Completed on 2026-08-14 14:05:48

--
-- PostgreSQL database dump complete
--

\unrestrict L5g9nNdzbmMDe3PJ2LxwB1cMbr4IhMM78EzgIsLNmkZHuL5lnymLUKPcgiQGdoa

