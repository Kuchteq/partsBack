--
-- PostgreSQL database dump
--

-- Dumped from database version 13.3
-- Dumped by pg_dump version 13.3

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: temp_comp_table; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.temp_comp_table AS (
	computer_id integer,
	computer_name text,
	processor_name text,
	graphics_card_name text,
	motherboard_name text,
	computer_value integer,
	short_note text,
	assembled_at timestamp without time zone,
	in_order integer
);


ALTER TYPE public.temp_comp_table OWNER TO postgres;

--
-- Name: clients_tsvector_trigger(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.clients_tsvector_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
 new.document_with_weights := setweight(to_tsvector(new.name), 'A') ||
  setweight(to_tsvector(coalesce(new.short_note, '')), 'B') ||
  setweight(to_tsvector(coalesce(CAST(new.phone as varchar(128)), '')), 'B') ||
  setweight(to_tsvector(coalesce(new.email, '')), 'B') ||
  setweight(to_tsvector(coalesce(new.nip, '')), 'B') ||
  setweight(to_tsvector(coalesce(new.adress, '')), 'C') ||
  setweight(to_tsvector(coalesce(TO_CHAR(new.join_date :: DATE, 'dd/mm/yyyy'), '')), 'D');
  return new;
end
  
$$;


ALTER FUNCTION public.clients_tsvector_trigger() OWNER TO postgres;

--
-- Name: computers_tsvector_trigger(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.computers_tsvector_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
 new.document_with_weights := setweight(to_tsvector(new.name), 'A') ||
  setweight(to_tsvector(coalesce(new.short_note, '')), 'B') ||
  setweight(to_tsvector(coalesce(TO_CHAR(new.assembled_at :: DATE, 'dd/mm/yyyy'), '')), 'C');
  return new;
end
  
$$;


ALTER FUNCTION public.computers_tsvector_trigger() OWNER TO postgres;

--
-- Name: get_computers(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_computers() RETURNS SETOF public.temp_comp_table
    LANGUAGE plpgsql
    AS $$
declare
        temprow RECORD;
        processor_name text;
        graphics_card_name text;
        motherboard_name text;
        computer_price int;
BEGIN


        FOR temprow in SELECT * FROM computers WHERE NOT EXISTS (SELECT computer_id FROM order_chunks WHERE computers.id = computer_id)

        LOOP
                WITH parts_preview AS (SELECT parts.name as part_name, parts.segment_id as segment_id
                FROM computer_pieces JOIN parts on parts.id = computer_pieces.part_id JOIN computers on computers.id = computer_pieces.belonging_computer_id
                 WHERE computer_pieces.belonging_computer_id = temprow.id) SELECT INTO processor_name, motherboard_name, graphics_card_name (
                        SELECT  DISTINCT ON (temprow.id) part_name  FROM parts_preview WHERE segment_id = 1
                ),
                (
                        SELECT  DISTINCT ON (temprow.id) part_name  FROM parts_preview WHERE segment_id = 2
                ),
                (
                        SELECT  DISTINCT ON (temprow.id) part_name  FROM parts_preview WHERE segment_id = 3
                );

                SELECT SUM(parts.price) computer_price into computer_price FROM computer_pieces JOIN parts on parts.id = computer_pieces.part_id WHERE computer_pieces.belonging_computer_id = temprow.id;

                INSERT INTO temp_computer_table VALUES (temprow.id, temprow.name, processor_name, graphics_card_name, motherboard_name, computer_price, temprow.short_note, temprow.assembled_at, 0);
        END LOOP;



        RETURN QUERY SELECT * FROM temp_computer_table;

        DELETE FROM temp_computer_table;
RETURN;

END;
$$;


ALTER FUNCTION public.get_computers() OWNER TO postgres;

--
-- Name: get_computers_all(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_computers_all() RETURNS SETOF public.temp_comp_table
    LANGUAGE plpgsql
    AS $$
declare
        temprow RECORD;
        processor_name text;
        graphics_card_name text;
        motherboard_name text;
        computer_price int;
        in_order int;
BEGIN
        FOR temprow in SELECT * FROM computers
        LOOP
                WITH parts_preview AS (SELECT parts.name as part_name, parts.segment_id as segment_id
                FROM computer_pieces JOIN parts on parts.id = computer_pieces.part_id JOIN computers on computers.id = computer_pieces.belonging_computer_id
                 WHERE computer_pieces.belonging_computer_id = temprow.id) SELECT INTO processor_name, motherboard_name, graphics_card_name (
                        SELECT  DISTINCT ON (temprow.id) part_name  FROM parts_preview WHERE segment_id = 1
                ),
                (
                        SELECT  DISTINCT ON (temprow.id) part_name  FROM parts_preview WHERE segment_id = 2
                ),
                (
                        SELECT  DISTINCT ON (temprow.id) part_name  FROM parts_preview WHERE segment_id = 3
                );
                SELECT SUM(parts.price) computer_price into computer_price FROM computer_pieces JOIN parts on parts.id = computer_pieces.part_id WHERE computer_pieces.belonging_computer_id = temprow.id;
                SELECT DISTINCT ON (temprow.id) order_chunks.belonging_order_id into in_order FROM order_chunks WHERE order_chunks.computer_id = temprow.id;
                INSERT INTO temp_computer_table VALUES (temprow.id, temprow.name, processor_name, graphics_card_name, motherboard_name, computer_price, temprow.short_note, temprow.assembled_at, in_order);
        END LOOP;
        RETURN QUERY SELECT * FROM temp_computer_table;
        DELETE FROM temp_computer_table;
RETURN;

END;
$$;


ALTER FUNCTION public.get_computers_all() OWNER TO postgres;

--
-- Name: history_tsvector_trigger(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.history_tsvector_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
 new.document_with_weights := setweight(to_tsvector(new.details), 'A') ||
setweight(to_tsvector(coalesce(TO_CHAR(new.at_time :: DATE, 'dd/mm/yyyy'), '')), 'C');
  return new;
end
  
$$;


ALTER FUNCTION public.history_tsvector_trigger() OWNER TO postgres;

--
-- Name: orders_tsvector_trigger(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.orders_tsvector_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
 new.document_with_weights := setweight(to_tsvector(new.name), 'B');
  return new;
end
  
$$;


ALTER FUNCTION public.orders_tsvector_trigger() OWNER TO postgres;

--
-- Name: part_tsvector_trigger(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.part_tsvector_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
new.document :=
setweight(to_tsvector(parts.name), 'A') ||
  setweight(to_tsvector(coalesce(parts.short_note, '')), 'B') ||
  setweight(to_tsvector(coalesce(suppliers.name, '')), 'C') ||
  setweight(to_tsvector(coalesce(segments.name, '')), 'D') ||
  setweight(to_tsvector(coalesce(TO_CHAR(parts.purchase_date :: DATE, 'dd/mm/yyyy'), '')), 'D');
  return new;
end
  
$$;


ALTER FUNCTION public.part_tsvector_trigger() OWNER TO postgres;

--
-- Name: parts_tsvector_trigger(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.parts_tsvector_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
 new.document_with_weights :=
  setweight(to_tsvector(new.name), 'A') ||
  setweight(to_tsvector(coalesce(new.short_note, '')), 'B') ||
  setweight(to_tsvector(coalesce(suppliers.name, '')), 'C') ||
  setweight(to_tsvector(coalesce(segments.name, '')), 'D') ||
  setweight(to_tsvector(coalesce(TO_CHAR(new.purchase_date :: DATE, 'dd/mm/yyyy'), '')), 'D')
  FROM suppliers, segments WHERE new.supplier_id = suppliers.id AND new.segment_id = segments.id;
  return new;
end
  
$$;


ALTER FUNCTION public.parts_tsvector_trigger() OWNER TO postgres;

--
-- Name: problems_tsvector_trigger(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.problems_tsvector_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
 new.document_with_weights := setweight(to_tsvector(new.problem_note), 'A') ||
  setweight(to_tsvector(coalesce(TO_CHAR(new.hand_in_date :: DATE, 'dd/mm/yyyy'), '')), 'B') ||
  setweight(to_tsvector(coalesce(TO_CHAR(new.deadline_date :: DATE, 'dd/mm/yyyy'), '')), 'B');
  return new;
end
  
$$;


ALTER FUNCTION public.problems_tsvector_trigger() OWNER TO postgres;

--
-- Name: stock_checker(integer[]); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.stock_checker(a integer[]) RETURNS boolean
    LANGUAGE plpgsql
    AS $_$
declare
	available bool;
	i integer;
BEGIN
	FOREACH i IN ARRAY $1
	LOOP
		RAISE NOTICE '%',i;
	END LOOP;
	
	available = 42;
   RETURN available;
END;
$_$;


ALTER FUNCTION public.stock_checker(a integer[]) OWNER TO postgres;

--
-- Name: stock_checker(integer[], integer[]); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.stock_checker(ids integer[], quantity integer[]) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
declare
	available bool;
	locstock integer;
	i integer;
BEGIN
	FOREACH i IN ARRAY ids
	LOOP
		SELECT stock INTO locstock FROM parts WHERE id = i;
		
		IF locstock - quantity[i] < 0 OR locstock IS NULL THEN
			RETURN false;
		END IF;
	END LOOP;
	RAISE NOTICE '%', locstock;
   RETURN true;
END;
$$;


ALTER FUNCTION public.stock_checker(ids integer[], quantity integer[]) OWNER TO postgres;

--
-- Name: stockchecker(integer[]); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.stockchecker(a integer[]) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
declare
	available bool;
BEGIN

   RETURN available;
END;
$$;


ALTER FUNCTION public.stockchecker(a integer[]) OWNER TO postgres;

--
-- Name: suppliers_tsvector_trigger(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.suppliers_tsvector_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
 new.document_with_weights := setweight(to_tsvector(new.name), 'A') ||
  setweight(to_tsvector(coalesce(new.short_note, '')), 'C') ||
  setweight(to_tsvector(coalesce(CAST(new.phone as varchar(128)), '')), 'C') ||
  setweight(to_tsvector(coalesce(new.email, '')), 'B') ||
  setweight(to_tsvector(coalesce(new.website, '')), 'B') ||
  setweight(to_tsvector(coalesce(new.nip, '')), 'B') ||
  setweight(to_tsvector(coalesce(new.adress, '')), 'C') ||
  setweight(to_tsvector(coalesce(TO_CHAR(new.join_date :: DATE, 'dd/mm/yyyy'), '')), 'D');
  return new;
end
  
$$;


ALTER FUNCTION public.suppliers_tsvector_trigger() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: action_types; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.action_types (
    id bigint NOT NULL,
    type_name text NOT NULL,
    document_with_weights tsvector
);


ALTER TABLE public.action_types OWNER TO postgres;

--
-- Name: actionTypes_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public."actionTypes_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public."actionTypes_id_seq" OWNER TO postgres;

--
-- Name: actionTypes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public."actionTypes_id_seq" OWNED BY public.action_types.id;


--
-- Name: clients; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.clients (
    id bigint NOT NULL,
    name text NOT NULL,
    join_date timestamp(0) without time zone NOT NULL,
    phone bigint,
    email text,
    adress text,
    nip text,
    short_note text,
    document_with_weights tsvector
);


ALTER TABLE public.clients OWNER TO postgres;

--
-- Name: clients_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.clients_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.clients_id_seq OWNER TO postgres;

--
-- Name: clients_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.clients_id_seq OWNED BY public.clients.id;


--
-- Name: computer_pieces; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.computer_pieces (
    id bigint NOT NULL,
    part_id bigint NOT NULL,
    belonging_computer_id bigint NOT NULL,
    quantity bigint NOT NULL
);


ALTER TABLE public.computer_pieces OWNER TO postgres;

--
-- Name: computer_pieces_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.computer_pieces_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.computer_pieces_id_seq OWNER TO postgres;

--
-- Name: computer_pieces_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.computer_pieces_id_seq OWNED BY public.computer_pieces.id;


--
-- Name: computers; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.computers (
    id bigint NOT NULL,
    name text NOT NULL,
    assembled_at timestamp(0) without time zone NOT NULL,
    short_note text,
    document_with_weights tsvector
);


ALTER TABLE public.computers OWNER TO postgres;

--
-- Name: computers_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.computers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.computers_id_seq OWNER TO postgres;

--
-- Name: computers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.computers_id_seq OWNED BY public.computers.id;


--
-- Name: history; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.history (
    id bigint NOT NULL,
    action_id integer NOT NULL,
    part_id integer,
    computer_id integer,
    problem_id integer,
    client_id integer,
    supplier_id integer,
    at_time timestamp without time zone,
    order_id integer,
    details text,
    target_id integer,
    document_with_weights tsvector
);


ALTER TABLE public.history OWNER TO postgres;

--
-- Name: history_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.history_id_seq OWNER TO postgres;

--
-- Name: history_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.history_id_seq OWNED BY public.history.id;


--
-- Name: order_chunks; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.order_chunks (
    id bigint NOT NULL,
    part_id integer,
    sell_price integer NOT NULL,
    quantity integer NOT NULL,
    belonging_order_id integer NOT NULL,
    computer_id integer
);


ALTER TABLE public.order_chunks OWNER TO postgres;

--
-- Name: orderChunk_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public."orderChunk_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public."orderChunk_id_seq" OWNER TO postgres;

--
-- Name: orderChunk_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public."orderChunk_id_seq" OWNED BY public.order_chunks.id;


--
-- Name: orders; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.orders (
    id bigint NOT NULL,
    client_id integer NOT NULL,
    sell_date timestamp(0) without time zone NOT NULL,
    name text,
    document_with_weights tsvector
);


ALTER TABLE public.orders OWNER TO postgres;

--
-- Name: orders_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.orders_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.orders_id_seq OWNER TO postgres;

--
-- Name: orders_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.orders_id_seq OWNED BY public.orders.id;


--
-- Name: parts; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.parts (
    id bigint NOT NULL,
    name text NOT NULL,
    stock integer NOT NULL,
    price numeric(18,2) NOT NULL,
    purchase_date timestamp(0) without time zone NOT NULL,
    short_note text,
    supplier_id integer,
    segment_id integer NOT NULL,
    document_with_weights tsvector,
    suggested_price numeric(18,2),
    CONSTRAINT stock_nonegative CHECK ((stock >= 0))
);


ALTER TABLE public.parts OWNER TO postgres;

--
-- Name: parts_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.parts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.parts_id_seq OWNER TO postgres;

--
-- Name: parts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.parts_id_seq OWNED BY public.parts.id;


--
-- Name: problems; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.problems (
    id bigint NOT NULL,
    computer_id bigint NOT NULL,
    problem_note text NOT NULL,
    hand_in_date timestamp(0) without time zone,
    deadline_date timestamp(0) without time zone,
    finished boolean DEFAULT false NOT NULL,
    document_with_weights tsvector
);


ALTER TABLE public.problems OWNER TO postgres;

--
-- Name: problems_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.problems_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.problems_id_seq OWNER TO postgres;

--
-- Name: problems_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.problems_id_seq OWNED BY public.problems.id;


--
-- Name: segments; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.segments (
    id bigint NOT NULL,
    name text NOT NULL
);


ALTER TABLE public.segments OWNER TO postgres;

--
-- Name: segments_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.segments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.segments_id_seq OWNER TO postgres;

--
-- Name: segments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.segments_id_seq OWNED BY public.segments.id;


--
-- Name: suppliers; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.suppliers (
    id bigint NOT NULL,
    name text NOT NULL,
    join_date timestamp(0) without time zone NOT NULL,
    website text,
    email text,
    phone bigint,
    adress text,
    nip character varying,
    short_note text,
    document_with_weights tsvector
);


ALTER TABLE public.suppliers OWNER TO postgres;

--
-- Name: suppliers_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.suppliers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.suppliers_id_seq OWNER TO postgres;

--
-- Name: suppliers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.suppliers_id_seq OWNED BY public.suppliers.id;


--
-- Name: temp_computer_table; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.temp_computer_table OF public.temp_comp_table;


ALTER TABLE public.temp_computer_table OWNER TO postgres;

--
-- Name: users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.users (
    id bigint NOT NULL,
    email text NOT NULL,
    password text NOT NULL,
    username text NOT NULL
);


ALTER TABLE public.users OWNER TO postgres;

--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.users_id_seq OWNER TO postgres;

--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: action_types id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.action_types ALTER COLUMN id SET DEFAULT nextval('public."actionTypes_id_seq"'::regclass);


--
-- Name: clients id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.clients ALTER COLUMN id SET DEFAULT nextval('public.clients_id_seq'::regclass);


--
-- Name: computer_pieces id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.computer_pieces ALTER COLUMN id SET DEFAULT nextval('public.computer_pieces_id_seq'::regclass);


--
-- Name: computers id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.computers ALTER COLUMN id SET DEFAULT nextval('public.computers_id_seq'::regclass);


--
-- Name: history id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.history ALTER COLUMN id SET DEFAULT nextval('public.history_id_seq'::regclass);


--
-- Name: order_chunks id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.order_chunks ALTER COLUMN id SET DEFAULT nextval('public."orderChunk_id_seq"'::regclass);


--
-- Name: orders id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.orders ALTER COLUMN id SET DEFAULT nextval('public.orders_id_seq'::regclass);


--
-- Name: parts id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.parts ALTER COLUMN id SET DEFAULT nextval('public.parts_id_seq'::regclass);


--
-- Name: problems id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.problems ALTER COLUMN id SET DEFAULT nextval('public.problems_id_seq'::regclass);


--
-- Name: segments id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.segments ALTER COLUMN id SET DEFAULT nextval('public.segments_id_seq'::regclass);


--
-- Name: suppliers id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.suppliers ALTER COLUMN id SET DEFAULT nextval('public.suppliers_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Data for Name: action_types; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.action_types (id, type_name, document_with_weights) FROM stdin;
0	Added part	'część':2A 'dodano':1A
1	Modified part	'część':2A 'zmodyfikowano':1A
2	Deleted part	'część':2A 'usunięto':1A
3	Added order	'stworzono':1A 'zamówienie':2A
4	Deleted order	'usunięto':1A 'zamówienie':2A
5	Assembled computer	'komputer':2A 'złożono':1A
6	Modified computer	'komputer':2A 'zmodyfikowano':1A
7	Dismantled computer	'komputer':2A 'rozłożono':1A
8	Added problem	'dodano':1A 'problem':2A
9	Modified problem	'problem':2A 'zmodyfikowano':1A
10	Resolved problem	'problem':2A 'rozwiązano':1A
11	Deleted problem	'problem':2A 'usunięto':1A
12	Added client	'dodano':1A 'klienta':2A
13	Modified client	'klienta':2A 'zmodyfikowano':1A
14	Deleted client	'klienta':2A 'usunięto':1A
15	Added supplier	'dodano':1A 'dostawcę':2A
16	Modified supplier	'dostawcę':2A 'zmodyfikowano':1A
17	Deleted supplier	'dostawcę':2A 'usunięto':1A
\.


--
-- Data for Name: clients; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.clients (id, name, join_date, phone, email, adress, nip, short_note, document_with_weights) FROM stdin;
\.


--
-- Data for Name: computer_pieces; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.computer_pieces (id, part_id, belonging_computer_id, quantity) FROM stdin;
\.


--
-- Data for Name: computers; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.computers (id, name, assembled_at, short_note, document_with_weights) FROM stdin;
\.


--
-- Data for Name: history; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.history (id, action_id, part_id, computer_id, problem_id, client_id, supplier_id, at_time, order_id, details, target_id, document_with_weights) FROM stdin;
\.


--
-- Data for Name: order_chunks; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.order_chunks (id, part_id, sell_price, quantity, belonging_order_id, computer_id) FROM stdin;
\.


--
-- Data for Name: orders; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.orders (id, client_id, sell_date, name, document_with_weights) FROM stdin;
\.


--
-- Data for Name: parts; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.parts (id, name, stock, price, purchase_date, short_note, supplier_id, segment_id, document_with_weights, suggested_price) FROM stdin;
\.


--
-- Data for Name: problems; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.problems (id, computer_id, problem_note, hand_in_date, deadline_date, finished, document_with_weights) FROM stdin;
\.


--
-- Data for Name: segments; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.segments (id, name) FROM stdin;
\.


--
-- Data for Name: suppliers; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.suppliers (id, name, join_date, website, email, phone, adress, nip, short_note, document_with_weights) FROM stdin;
\.


--
-- Data for Name: temp_computer_table; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.temp_computer_table (computer_id, computer_name, processor_name, graphics_card_name, motherboard_name, computer_value, short_note, assembled_at, in_order) FROM stdin;
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.users (id, email, password, username) FROM stdin;
7	myia@2022csia.com	$2b$10$PtS11CYygWKGtdlvzIxe1uDaMiw9OHw/Nt4jk4J93kg3L04o02Xae	examiner
\.


--
-- Name: actionTypes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."actionTypes_id_seq"', 1, true);


--
-- Name: clients_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.clients_id_seq', 1, false);


--
-- Name: computer_pieces_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.computer_pieces_id_seq', 1, false);


--
-- Name: computers_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.computers_id_seq', 1, false);


--
-- Name: history_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.history_id_seq', 1, false);


--
-- Name: orderChunk_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."orderChunk_id_seq"', 1, false);


--
-- Name: orders_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.orders_id_seq', 1, false);


--
-- Name: parts_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.parts_id_seq', 1, false);


--
-- Name: problems_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.problems_id_seq', 1, false);


--
-- Name: segments_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.segments_id_seq', 1, false);


--
-- Name: suppliers_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.suppliers_id_seq', 1, false);


--
-- Name: users_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.users_id_seq', 7, true);


--
-- Name: action_types actionTypes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.action_types
    ADD CONSTRAINT "actionTypes_pkey" PRIMARY KEY (id);


--
-- Name: clients clients_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.clients
    ADD CONSTRAINT clients_pkey PRIMARY KEY (id);


--
-- Name: computer_pieces computer_pieces_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.computer_pieces
    ADD CONSTRAINT computer_pieces_pkey PRIMARY KEY (id);


--
-- Name: computers computers_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.computers
    ADD CONSTRAINT computers_pkey PRIMARY KEY (id);


--
-- Name: history history_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.history
    ADD CONSTRAINT history_pkey PRIMARY KEY (id);


--
-- Name: order_chunks orderChunk_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.order_chunks
    ADD CONSTRAINT "orderChunk_pkey" PRIMARY KEY (id);


--
-- Name: orders orders_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_pkey PRIMARY KEY (id);


--
-- Name: parts parts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.parts
    ADD CONSTRAINT parts_pkey PRIMARY KEY (id);


--
-- Name: problems problems_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.problems
    ADD CONSTRAINT problems_pkey PRIMARY KEY (id);


--
-- Name: segments segments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.segments
    ADD CONSTRAINT segments_pkey PRIMARY KEY (id);


--
-- Name: suppliers suppliers_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.suppliers
    ADD CONSTRAINT suppliers_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: document_weights_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX document_weights_idx ON public.parts USING gin (document_with_weights);


--
-- Name: clients tsvectorupdate; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tsvectorupdate BEFORE INSERT OR UPDATE ON public.clients FOR EACH ROW EXECUTE FUNCTION public.clients_tsvector_trigger();


--
-- Name: computers tsvectorupdate; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tsvectorupdate BEFORE INSERT OR UPDATE ON public.computers FOR EACH ROW EXECUTE FUNCTION public.computers_tsvector_trigger();


--
-- Name: history tsvectorupdate; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tsvectorupdate BEFORE INSERT OR UPDATE ON public.history FOR EACH ROW EXECUTE FUNCTION public.history_tsvector_trigger();


--
-- Name: orders tsvectorupdate; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tsvectorupdate BEFORE INSERT OR UPDATE ON public.orders FOR EACH ROW EXECUTE FUNCTION public.orders_tsvector_trigger();


--
-- Name: problems tsvectorupdate; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tsvectorupdate BEFORE INSERT OR UPDATE ON public.problems FOR EACH ROW EXECUTE FUNCTION public.problems_tsvector_trigger();


--
-- Name: suppliers tsvectorupdate; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tsvectorupdate BEFORE INSERT OR UPDATE ON public.suppliers FOR EACH ROW EXECUTE FUNCTION public.suppliers_tsvector_trigger();


--
-- Name: order_chunks belonging_order_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.order_chunks
    ADD CONSTRAINT belonging_order_id FOREIGN KEY (belonging_order_id) REFERENCES public.orders(id) NOT VALID;


--
-- Name: order_chunks computer_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.order_chunks
    ADD CONSTRAINT computer_id FOREIGN KEY (computer_id) REFERENCES public.computers(id) NOT VALID;


--
-- Name: computer_pieces computer_pieces_belonging_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.computer_pieces
    ADD CONSTRAINT computer_pieces_belonging_id_foreign FOREIGN KEY (belonging_computer_id) REFERENCES public.computers(id) NOT VALID;


--
-- Name: history history_action_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.history
    ADD CONSTRAINT history_action_id_foreign FOREIGN KEY (action_id) REFERENCES public.action_types(id) NOT VALID;


--
-- Name: order_chunks item_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.order_chunks
    ADD CONSTRAINT item_id FOREIGN KEY (part_id) REFERENCES public.parts(id) NOT VALID;


--
-- Name: orders orders_client_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_client_id_foreign FOREIGN KEY (client_id) REFERENCES public.clients(id);


--
-- Name: parts parts_segment_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.parts
    ADD CONSTRAINT parts_segment_id_foreign FOREIGN KEY (segment_id) REFERENCES public.segments(id) ON DELETE SET NULL NOT VALID;


--
-- Name: parts parts_supplier_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.parts
    ADD CONSTRAINT parts_supplier_id_foreign FOREIGN KEY (supplier_id) REFERENCES public.suppliers(id) ON DELETE SET NULL NOT VALID;


--
-- Name: problems problems_computer_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.problems
    ADD CONSTRAINT problems_computer_id_foreign FOREIGN KEY (computer_id) REFERENCES public.computers(id) ON DELETE CASCADE NOT VALID;


--
-- PostgreSQL database dump complete
--

