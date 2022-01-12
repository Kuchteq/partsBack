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
	motherboard_name text,
	graphics_card_name text,
	computer_value integer,
	short_note text,
	assembled_at timestamp without time zone
);


ALTER TYPE public.temp_comp_table OWNER TO postgres;

--
-- Name: computers_tsvector_trigger(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.computers_tsvector_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
new.document :=
setweight(to_tsvector(computers.name), 'A') ||
  setweight(to_tsvector(coalesce(computers.short_note, '')), 'B') ||
  setweight(to_tsvector(coalesce(TO_CHAR(computers.assembled_at :: DATE, 'dd/mm/yyyy'), '')), 'C');
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

                INSERT INTO temp_computer_table VALUES (temprow.id, temprow.name, processor_name, graphics_card_name, motherboard_name, computer_price, temprow.short_note, temprow.assembled_at);
        END LOOP;



        RETURN QUERY SELECT * FROM temp_computer_table;

        DELETE FROM temp_computer_table;
RETURN;

END;
$$;


ALTER FUNCTION public.get_computers() OWNER TO postgres;

--
-- Name: get_computers(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_computers(search_query text) RETURNS SETOF public.temp_comp_table
    LANGUAGE plpgsql
    AS $$
declare
        temprow RECORD;
        processor_name text;
        graphics_card_name text;
        motherboard_name text;
        computer_price int;
BEGIN


        FOR temprow in SELECT DISTINCT ON (computers.id) * FROM computers 
		LEFT JOIN computer_pieces ON computer_pieces.belonging_computer_id = computers.id
		LEFT JOIN parts on parts.id = computer_pieces.part_id  
		WHERE NOT EXISTS (SELECT computer_id FROM order_chunks WHERE computers.id = computer_id)
		AND (computers.document_with_weights @@ to_tsquery('"'||search_query||'":*') OR 
			 parts.document_with_weights @@ to_tsquery('"'||search_query||'":*'))

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

                INSERT INTO temp_computer_table VALUES (temprow.id, temprow.name, processor_name, graphics_card_name, motherboard_name, computer_price, temprow.short_note, temprow.assembled_at);
        END LOOP;



        RETURN QUERY SELECT * FROM temp_computer_table;

        DELETE FROM temp_computer_table;
RETURN;

END;
$$;


ALTER FUNCTION public.get_computers(search_query text) OWNER TO postgres;

--
-- Name: get_computers(text, text, integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_computers(_sort_by text, _sort_dir text, _start_index integer, _items_limit integer) RETURNS SETOF public.temp_comp_table
    LANGUAGE plpgsql
    AS $$
declare
	temprow RECORD;
	firstRows RECORD;
	processor_name text;
	graphics_card_name text;
	motherboard_name text;
	computer_price int;
BEGIN


--     RETURN QUERY SELECT parts.name as part_name
-- 	FROM computer_pieces WHERE computer_pieces.id = 1 JOIN parts on parts.id = computer_pieces.part_id;

	
	RETURN QUERY EXECUTE 'SELECT * FROM computers ORDER BY ' || quote_ident( _sort_by )  || ' OFFSET ' 
	|| _start_index || ' LIMIT ' || _items_limit || 
	' WHERE id IN (SELECT computer_id FROM order_chunks) ISNULL';
	
	FOR temprow in SELECT * FROM firstRows 
	LOOP
		WITH parts_preview AS (SELECT parts.name as part_name, parts.segment_id as segment_id
		FROM computer_pieces JOIN parts on parts.id = computer_pieces.part_id JOIN computers 
		on computers.id = computer_pieces.belonging_computer_id
		 WHERE computer_pieces.belonging_computer_id = temprow.id) 
		 
		 SELECT INTO processor_name, motherboard_name, graphics_card_name (
			SELECT  DISTINCT ON (temprow.id) part_name  FROM parts_preview WHERE segment_id = 1
		),
		(
			SELECT  DISTINCT ON (temprow.id) part_name  FROM parts_preview WHERE segment_id = 2
		),
		(
			SELECT  DISTINCT ON (temprow.id) part_name  FROM parts_preview WHERE segment_id = 3
		);
		
		SELECT SUM(parts.price) computer_price into computer_price FROM computer_pieces JOIN parts on parts.id = computer_pieces.part_id WHERE computer_pieces.belonging_computer_id = 1;
		
		INSERT INTO temp_computer_table VALUES (temprow.id, temprow.name, temprow.assembled_at, processor_name, graphics_card_name, motherboard_name, computer_price);
	END LOOP;
	

	
	RETURN QUERY SELECT * FROM temp_computer_table;
	
	DELETE FROM temp_computer_table;
RETURN;
-- 	FOREACH i IN ARRAY ids
-- 	LOOP
-- 		SELECT stock INTO locstock FROM parts WHERE id = i;
		
-- 		IF locstock - quantity[i] < 0 OR locstock IS NULL THEN
-- 			RETURN false;
-- 		END IF;
-- 	END LOOP;
-- 	RAISE NOTICE '%', locstock;
   
END;

$$;


ALTER FUNCTION public.get_computers(_sort_by text, _sort_dir text, _start_index integer, _items_limit integer) OWNER TO postgres;

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
update parts
set document_with_weights = setweight(to_tsvector(parts.name), 'A') ||
  setweight(to_tsvector(coalesce(parts.short_note, '')), 'B') ||
  setweight(to_tsvector(coalesce(suppliers.name, '')), 'C') ||
  setweight(to_tsvector(coalesce(segments.name, '')), 'D') ||
  setweight(to_tsvector(coalesce(TO_CHAR(parts.purchase_date :: DATE, 'dd/mm/yyyy'), '')), 'D')
FROM suppliers, segments WHERE parts.supplier_id = suppliers.id AND parts.segment_id = segments.id;
end
  
$$;


ALTER FUNCTION public.parts_tsvector_trigger() OWNER TO postgres;

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
0	Dodano część	'część':2A 'dodano':1A
1	Zmodyfikowano część	'część':2A 'zmodyfikowano':1A
2	Usunięto część	'część':2A 'usunięto':1A
3	Stworzono zamówienie	'stworzono':1A 'zamówienie':2A
4	Usunięto zamówienie	'usunięto':1A 'zamówienie':2A
5	Złożono komputer	'komputer':2A 'złożono':1A
6	Zmodyfikowano komputer	'komputer':2A 'zmodyfikowano':1A
7	Rozłożono komputer	'komputer':2A 'rozłożono':1A
8	Dodano problem	'dodano':1A 'problem':2A
9	Zmodyfikowano problem	'problem':2A 'zmodyfikowano':1A
10	Rozwiązano problem	'problem':2A 'rozwiązano':1A
11	Usunięto problem	'problem':2A 'usunięto':1A
12	Dodano klienta	'dodano':1A 'klienta':2A
13	Zmodyfikowano klienta	'klienta':2A 'zmodyfikowano':1A
14	Usunięto klienta	'klienta':2A 'usunięto':1A
15	Dodano dostawcę	'dodano':1A 'dostawcę':2A
16	Zmodyfikowano dostawcę	'dostawcę':2A 'zmodyfikowano':1A
17	Usunięto dostawcę	'dostawcę':2A 'usunięto':1A
\.


--
-- Data for Name: clients; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.clients (id, name, join_date, phone, email, adress, nip, short_note, document_with_weights) FROM stdin;
13	James Smith	2021-08-24 18:14:00	48481241264	james@gmail.com	4124	1242141241	Fajny gość	'1242141241':7B '24/08/2021':9 '4124':8C '48481241264':5B 'fajny':3B 'gość':4B 'james':1A 'james@gmail.com':6B 'smith':2A
21	tescior	2021-12-24 11:24:22	\N	\N	\N	\N	\N	\N
1	John Black	2021-09-17 20:13:00	48603088160	john@black.com	ul. Damrow 214	1234563218	Ladny facet	'1234563218':7B '17/09/2021':11 '214':10C '48603088160':5B 'black':2A 'damrow':9C 'facet':4B 'john':1A 'john@black.com':6B 'ladny':3B 'ul':8C
11	Wojciech Juliusz	2021-09-03 13:43:00	48603081211	w.zych@strona.agency	Jadachy 22	\N	\N	'03/09/2021':7 '22':6C '48603081211':3B 'jadachy':5C 'juliusz':2A 'w.zych@strona.agency':4B 'wojciech':1A
10	Marusz Nalepa	2021-08-23 23:01:00	48603088169	\N	\N	2424214212	\N	'23/08/2021':5 '2424214212':4B '48603088169':3B 'marusz':1A 'nalepa':2A
8	Amadeusz Wajcheprzełóż	2021-08-23 22:59:00	\N	\N	\N	\N	\N	'23/08/2021':3 'amadeusz':1A 'wajcheprzełóż':2A
6	Dariusz Palacz	2021-08-23 22:19:00	\N	\N	\N	\N	\N	'23/08/2021':3 'dariusz':1A 'palacz':2A
2	Michał Kuluts	2021-08-27 19:53:00	4851012512	michał@gmail.com	\N	1241221419	Ładny, niski blondyn	'1241221419':9B '27/08/2021':10 '4851012512':6B 'blondyn':5B 'gmail.com':8B 'kuluts':2A 'michał':1A,7B 'niski':4B 'ładny':3B
5	Amelia Chorożny	2021-08-23 20:14:00	\N	\N	\N	\N	\N	'23/08/2021':3 'amelia':1A 'chorożny':2A
16	Adrian Smith	2021-10-28 17:50:00	48503214203	\N	\N	1234215231	\N	\N
\.


--
-- Data for Name: computer_pieces; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.computer_pieces (id, part_id, belonging_computer_id, quantity) FROM stdin;
13	1	5	1
14	2	5	1
15	3	5	1
35	5	10	1
36	6	10	1
37	7	10	1
38	5	11	1
39	6	11	1
40	7	11	1
41	65	12	1
42	64	12	1
43	62	12	1
44	65	13	1
45	62	13	1
46	64	13	1
51	50	16	1
52	59	16	1
54	48	17	1
55	59	17	1
57	66	19	9
58	58	19	3
113	66	30	2
114	70	30	1
115	81	30	1
116	72	30	1
117	77	30	1
59	50	20	1
61	64	20	1
66	66	21	1
67	69	21	1
68	65	21	1
69	55	22	1
72	24	22	1
73	49	22	1
74	45	16	1
64	49	20	1
76	59	23	1
77	70	23	1
75	48	23	1
78	66	24	1
79	5	24	1
80	70	24	1
83	75	25	1
82	48	25	1
85	51	25	1
87	76	25	1
89	79	24	1
90	43	26	1
91	65	26	1
92	79	26	1
93	75	26	1
94	7	17	1
95	81	17	1
96	78	24	1
97	76	23	1
118	81	30	1
119	66	31	1
120	76	31	1
121	70	31	1
122	71	31	1
65	60	20	3
63	59	20	2
128	85	34	1
129	85	35	1
\.


--
-- Data for Name: computers; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.computers (id, name, assembled_at, short_note, document_with_weights) FROM stdin;
23	kAMDRyzeMSIMPG101514pypiptgfghg-27	2021-10-27 12:10:00	\N	'-27':2A '27/10/2021':3C 'kamdryzemsimpg101514pypiptgfghg':1A
31	ForGamersComputer	2021-12-01 21:11:00	\N	\N
5	Złapdejtowany	2021-08-08 12:08:00	\N	'08/08/2021':2C 'złapdejtowany':1A
19	kProcesss4214095201tj1wg9ps4i-02	2021-09-02 12:09:00	\N	'-02':2A '02/09/2021':3C 'kprocesss4214095201tj1wg9ps4i':1A
24	kIntelCoMSIMPG103014c5ud30wjan-27	2021-10-27 12:10:00	To jest ten komputer dla tego superowego Przemysława	'-27':2A '27/10/2021':11C 'dla':7B 'jest':4B 'kintelcomsimpg103014c5ud30wjan':1A 'komputer':6B 'przemysława':10B 'superowego':9B 'tego':8B 'ten':5B 'to':3B
20	Pod fajny gaming	2021-09-03 12:09:00	\N	'03/09/2021':4C 'fajny':2A 'gaming':3A 'pod':1A
25	kInteli5103214a60ik2favqj-27	2021-10-27 12:10:00	\N	'-27':2A '27/10/2021':3C 'kinteli5103214a60ik2favqj':1A
34	kAMDAthl1256229kb90173dc-23	2021-12-23 22:56:00	\N	\N
26	kAMDRyzeASRockB101515xqo6aeqskg-27	2021-10-27 12:10:00	\N	'-27':2A '27/10/2021':3C 'kamdryzeasrockb101515xqo6aeqskg':1A
30	Office computer	2021-10-27 12:10:00	Great one	\N
35	kAMDAthl125822x5bqoq452v-23	2021-12-23 12:12:00	\N	\N
21	Komputronix 3000	2021-09-02 00:19:00	Dla gracza mega fajny jest	'02/09/2021':8C '3000':2A 'dla':3B 'fajny':6B 'gracza':4B 'jest':7B 'komputronix':1A 'mega':5B
22	kMariuzFana104318ubow2vhb8t-13	2021-10-13 12:10:00	\N	'-13':2A '13/10/2021':3C 'kmariuzfana104318ubow2vhb8t':1A
11	SuperHiperFajowy	2021-08-08 12:08:00	\N	'08/08/2021':2C 'superhiperfajowy':1A
17	Fajen komputronik	2021-09-02 12:09:00	\N	'02/09/2021':3C 'fajen':1A 'komputronik':2A
12	kInteli5ASRockB/20812xqie3gfjv4021	2021-08-08 12:08:00	\N	'08/08/2021':2C 'kinteli5asrockb/20812xqie3gfjv4021':1A
10	Łoo panoie mega	2021-08-08 12:10:11	\N	'08/08/2021':4C 'mega':3A 'panoie':2A 'łoo':1A
13	kInteli5ASRockB/20812ek7gbs6etq021	2021-08-08 12:08:00	Mega fajny	'08/08/2021':4C 'fajny':3B 'kinteli5asrockb/20812ek7gbs6etq021':1A 'mega':2B
16	SuperKomp	2021-09-02 12:09:00	\N	'02/09/2021':2C 'superkomp':1A
\.


--
-- Data for Name: history; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.history (id, action_id, part_id, computer_id, problem_id, client_id, supplier_id, at_time, order_id, details, target_id, document_with_weights) FROM stdin;
331	0	\N	\N	\N	\N	\N	2021-12-23 13:56:37.564309	\N	Dell P2720D	91	\N
338	1	\N	\N	\N	\N	\N	2021-12-23 14:06:34.502089	\N	\N	91	\N
343	13	\N	\N	\N	\N	\N	2021-12-23 14:12:20.84113	\N	Mariusz Kuchtae	17	\N
348	5	\N	\N	\N	\N	\N	2021-12-23 22:56:19.105546	\N	kAMDAthl1256229kb90173dc-23	34	\N
353	5	\N	\N	\N	\N	\N	2021-12-23 23:01:37.156539	\N	kAMDAthl120123ux8ez5v049-23	39	\N
358	5	\N	\N	\N	\N	\N	2021-12-23 23:13:49.934538	\N	kIntelCo121323wy73y2dbca-23	44	\N
363	7	\N	\N	\N	\N	\N	2021-12-23 23:21:37.503725	\N	kQualcom1205230jmiwfwlw8-23	40	\N
368	7	\N	\N	\N	\N	\N	2021-12-23 23:34:20.023519	\N	k	38	\N
378	15	\N	\N	\N	\N	\N	2021-12-23 23:39:56.638516	\N	istrnieje	12	\N
379	17	\N	\N	\N	\N	\N	2021-12-23 23:40:00.809974	\N	istrnieje	12	\N
386	0	\N	\N	\N	\N	\N	2021-12-24 05:12:57.305434	\N	kurczee	97	\N
393	3	\N	\N	\N	\N	\N	\N	\N	sadjggjsd	\N	\N
402	3	\N	\N	\N	\N	\N	2022-01-02 22:37:04.169411	\N	Sprzedaż dla Amadeusz Wajcheprzełóż w dniu i godzinie 2022-01-02 22:36 	19	\N
407	3	\N	\N	\N	\N	\N	2022-01-02 22:56:44.474774	\N	Sprzedaż dla Amadeusz Wajcheprzełóż w dniu i godzinie 2022-01-02 22:56 	24	\N
416	3	\N	\N	\N	\N	\N	2022-01-04 20:56:28.896233	\N	Sprzedaż dla Wojciech Juliusz w dniu i godzinie 2022-01-04 20:49 	27	\N
426	3	\N	\N	\N	\N	\N	2022-01-10 19:42:52.096497	\N	Sprzedaż dla Adrian Smith w dniu i godzinie 2022-01-10 19:42 	40	\N
332	0	\N	\N	\N	\N	\N	2021-12-23 14:03:46.854475	\N	Testowy	92	\N
333	2	\N	\N	\N	\N	\N	2021-12-23 14:03:54.283933	\N	Testowy	92	\N
339	5	\N	\N	\N	\N	\N	2021-12-23 14:07:27.886306	\N	kAMDAthlMSIMAG123513wgq4b3znw7-23	33	\N
344	2	\N	\N	\N	\N	\N	2021-12-23 14:13:31.700443	\N	Mariusz Kuchtae	17	\N
349	5	\N	\N	\N	\N	\N	2021-12-23 22:58:08.375576	\N	kAMDAthl125822x5bqoq452v-23	35	\N
354	5	\N	\N	\N	\N	\N	2021-12-23 23:05:34.512862	\N	kQualcom1205230jmiwfwlw8-23	40	\N
359	7	\N	\N	\N	\N	\N	2021-12-23 23:18:21.179913	\N	kIntelCo121323wy73y2dbca-23	44	\N
364	13	\N	\N	\N	\N	\N	2021-12-23 23:24:33.74101	\N	James Smith	13	\N
369	7	\N	\N	\N	\N	\N	2021-12-23 23:35:10.023458	\N	k	37	\N
380	8	\N	\N	\N	\N	\N	2021-12-23 23:46:55.676957	\N	Coś się popsuło	22	\N
387	0	\N	\N	\N	\N	\N	2021-12-24 11:26:54.28846	\N	testsa	98	\N
388	0	\N	\N	\N	\N	\N	2022-01-01 21:01:35.920719	\N	tutsa	99	\N
389	0	\N	\N	\N	\N	\N	2022-01-01 21:01:52.17759	\N	Heloł	100	\N
398	3	\N	\N	\N	\N	\N	2022-01-02 22:18:57.155909	\N	Sprzedaż dla Wojciech Juliusz w dniu i godzinie 2021-10-28 19:11 	6	\N
403	3	\N	\N	\N	\N	\N	2022-01-02 22:37:14.694014	\N	Sprzedaż dla Dariusz Palacz w dniu i godzinie 2022-01-02 22:36 	20	\N
408	3	\N	\N	\N	\N	\N	2022-01-02 23:03:37.823326	\N	Sprzedaż dla Marusz Nalepa w dniu i godzinie 2022-01-02 23:03 	25	\N
409	2	\N	\N	\N	\N	\N	2022-01-04 20:50:17.79846	\N	tutsa	99	\N
417	3	\N	\N	\N	\N	\N	2022-01-04 20:57:08.671178	\N	Sprzedaż dla Adrian Smith w dniu i godzinie 2022-01-04 20:49 	29	\N
418	3	\N	\N	\N	\N	\N	2022-01-09 12:33:17.103506	\N	Sprzedaż dla James Smith w dniu i godzinie 2022-01-09 12:32 	30	\N
422	3	\N	\N	\N	\N	\N	2022-01-10 19:35:00.107566	\N	Sprzedaż dla Dariusz Palacz w dniu i godzinie 2022-01-10 19:34 	35	\N
427	3	\N	\N	\N	\N	\N	2022-01-10 19:46:17.62079	\N	Sprzedaż dla Marusz Nalepa w dniu i godzinie 2022-01-10 19:46 	41	\N
430	15	\N	\N	\N	\N	\N	2022-01-12 17:18:54.766748	\N	KFD	13	\N
116	1	\N	\N	\N	\N	\N	\N	\N	\N	68	\N
334	0	\N	\N	\N	\N	\N	2021-12-23 14:04:37.406111	\N	214	93	\N
340	7	\N	\N	\N	\N	\N	2021-12-23 14:10:21.407118	\N	kAMDAthlMSIMAG123513wgq4b3znw7-23	33	\N
345	9	\N	\N	\N	\N	\N	2021-12-23 14:13:59.577417	\N	Tam się popsuł dysk najprawdopodobniej, nie mogę odtwarzać piosenek Franka Kimono	12	\N
350	5	\N	\N	\N	\N	\N	2021-12-23 22:59:21.654481	\N	kAMDAthl125922sya44lefaw-23	36	\N
355	5	\N	\N	\N	\N	\N	2021-12-23 23:06:25.025401	\N	kAMDRyze1206233zjlyeg2fw-23	41	\N
360	7	\N	\N	\N	\N	\N	2021-12-23 23:19:04.845667	\N	proszę działaj	43	\N
365	5	\N	\N	\N	\N	\N	2021-12-23 23:28:11.260007	\N	kRamior2122623iv9x47edqnj-23	45	\N
370	12	\N	\N	\N	\N	\N	2021-12-23 23:37:19.929182	\N	nazwa	18	\N
381	9	\N	\N	\N	\N	\N	2021-12-23 23:47:56.926888	\N	Coś się popsuło	22	\N
382	9	\N	\N	\N	\N	\N	2021-12-23 23:47:58.859819	\N	Coś się popsuło	22	\N
399	3	\N	\N	\N	\N	\N	2022-01-02 22:20:37.074993	\N	Sprzedaż dla Adrian Smith w dniu i godzinie 2021-09-30 23:10 	15	\N
404	3	\N	\N	\N	\N	\N	2022-01-02 22:50:20.886225	\N	Sprzedaż dla Marusz Nalepa w dniu i godzinie 2022-01-02 22:50 	21	\N
410	2	\N	\N	\N	\N	\N	2022-01-04 20:50:36.638501	\N	Heloł	100	\N
412	2	\N	\N	\N	\N	\N	2022-01-04 20:50:40.912931	\N	testsa	98	\N
414	2	\N	\N	\N	\N	\N	2022-01-04 20:50:47.110001	\N	Modirbird 124	95	\N
419	3	\N	\N	\N	\N	\N	2022-01-09 12:39:08.682321	\N	Sprzedaż dla tescior w dniu i godzinie 2022-01-09 12:35 	31	\N
423	1	\N	\N	\N	\N	\N	2022-01-10 19:40:56.0209	\N	\N	91	\N
428	3	\N	\N	\N	\N	\N	2022-01-10 19:48:58.549075	\N	Sprzedaż dla John Black w dniu i godzinie 2022-01-10 19:48 	42	\N
431	0	\N	\N	\N	\N	\N	2022-01-12 17:20:31.996513	\N	KRX BETA320 Ultra gamer	117	\N
335	2	\N	\N	\N	\N	\N	2021-12-23 14:04:48.624962	\N	214	93	\N
341	12	\N	\N	\N	\N	\N	2021-12-23 14:11:36.675425	\N	Mariusz Kuchta	17	\N
346	0	\N	\N	\N	\N	\N	2021-12-23 21:13:09.691272	\N	Modirbird 124	95	\N
351	5	\N	\N	\N	\N	\N	2021-12-23 23:01:18.499726	\N	k	37	\N
356	5	\N	\N	\N	\N	\N	2021-12-23 23:10:24.407162	\N	kAPPLEA1121023nv2q0h81ri-23	42	\N
361	7	\N	\N	\N	\N	\N	2021-12-23 23:19:30.641739	\N	kAPPLEA1121023nv2q0h81ri-23	42	\N
366	7	\N	\N	\N	\N	\N	2021-12-23 23:28:20.057482	\N	kRamior2122623iv9x47edqnj-23	45	\N
371	2	\N	\N	\N	\N	\N	2021-12-23 23:38:04.614692	\N	nazwa	18	\N
372	12	\N	\N	\N	\N	\N	2021-12-23 23:38:13.627657	\N	kiiirea	19	\N
373	13	\N	\N	\N	\N	\N	2021-12-23 23:38:21.58496	\N	kiiirea	19	\N
374	2	\N	\N	\N	\N	\N	2021-12-23 23:38:24.203384	\N	kiiirea	19	\N
375	16	\N	\N	\N	\N	\N	2021-12-23 23:38:42.45315	\N	BestSupply	10	\N
376	15	\N	\N	\N	\N	\N	2021-12-23 23:38:51.845978	\N	punk's not dead	11	\N
383	7	\N	\N	\N	\N	\N	2021-12-24 00:56:23.817234	\N	kAMDAthl125922sya44lefaw-23	36	\N
400	3	\N	\N	\N	\N	\N	2022-01-02 22:21:03.834758	\N	Sprzedaż dla John Black w dniu i godzinie 2021-08-27 01:20 	2	\N
405	3	\N	\N	\N	\N	\N	2022-01-02 22:56:33.781686	\N	Sprzedaż dla Marusz Nalepa w dniu i godzinie 2022-01-02 22:56 	22	\N
411	2	\N	\N	\N	\N	\N	2022-01-04 20:50:38.696376	\N	kurczee	97	\N
413	2	\N	\N	\N	\N	\N	2022-01-04 20:50:44.468314	\N	Ramior 2137	96	\N
420	3	\N	\N	\N	\N	\N	2022-01-09 12:48:25.068984	\N	Sprzedaż dla Marusz Nalepa w dniu i godzinie 2022-01-09 12:48 	32	\N
1	0	\N	\N	\N	\N	\N	\N	\N	Arra 420	39	'420':2A 'arra':1A
2	2	\N	\N	\N	\N	\N	\N	\N	No to to co robiłem sprzedałem	3	'co':4A 'no':1A 'robiłem':5A 'sprzedałem':6A 'to':2A,3A
3	7	\N	\N	\N	\N	\N	\N	\N	Fajny mega	7	'fajny':1A 'mega':2A
4	7	\N	\N	\N	\N	\N	\N	\N	Łoo panoie mega	9	'mega':3A 'panoie':2A 'łoo':1A
5	5	\N	\N	\N	\N	\N	\N	\N	Łoo panoie mega	10	'mega':3A 'panoie':2A 'łoo':1A
6	8	\N	\N	\N	\N	\N	\N	\N	Twój  się zepsuło, nie było mnie słychać	17	'było':5A 'mnie':6A 'nie':4A 'się':2A 'słychać':7A 'twój':1A 'zepsuło':3A
7	9	\N	\N	\N	\N	\N	\N	\N	Jednak coś innego szczeliło	6	'coś':2A 'innego':3A 'jednak':1A 'szczeliło':4A
8	0	\N	\N	\N	\N	\N	\N	\N	BSDAS 420	40	'420':2A 'bsdas':1A
9	0	\N	\N	\N	\N	\N	\N	\N	BSDAS 420	41	'420':2A 'bsdas':1A
10	5	\N	\N	\N	\N	\N	\N	\N	Łoo panoie mega	11	'mega':3A 'panoie':2A 'łoo':1A
11	0	\N	\N	\N	\N	\N	\N	\N	Fajny produkt	42	'fajny':1A 'produkt':2A
12	0	\N	\N	\N	\N	\N	\N	\N	Rateix 2410	43	'2410':2A 'rateix':1A
13	0	\N	\N	\N	\N	\N	\N	\N	Super Produkt	45	'produkt':2A 'super':1A
14	0	\N	\N	\N	\N	\N	\N	\N	Nie wiem	46	'nie':1A 'wiem':2A
15	0	\N	\N	\N	\N	\N	\N	\N	Nie wiem	47	'nie':1A 'wiem':2A
16	0	\N	\N	\N	\N	\N	\N	\N	Kintel Prol I7	48	'i7':3A 'kintel':1A 'prol':2A
17	0	\N	\N	\N	\N	\N	\N	\N	Gigabyt 1240 px GAMING EDITION	49	'1240':2A 'edition':5A 'gaming':4A 'gigabyt':1A 'px':3A
18	0	\N	\N	\N	\N	\N	\N	\N	Ultra drut	50	'drut':2A 'ultra':1A
19	0	\N	\N	\N	\N	\N	\N	\N	Nowa płytka	51	'nowa':1A 'płytka':2A
20	0	\N	\N	\N	\N	\N	\N	\N	e 3	52	'3':2A 'e':1A
21	0	\N	\N	\N	\N	\N	\N	\N	e 3	53	'3':2A 'e':1A
22	0	\N	\N	\N	\N	\N	\N	\N	e 3	54	'3':2A 'e':1A
23	0	\N	\N	\N	\N	\N	\N	\N	Mariuz	55	'mariuz':1A
24	0	\N	\N	\N	\N	\N	\N	\N	Fana	56	'fana':1A
25	0	\N	\N	\N	\N	\N	\N	\N	Fjanafsa 	57	'fjanafsa':1A
26	0	\N	\N	\N	\N	\N	\N	\N	4214	58	'4214':1A
27	0	\N	\N	\N	\N	\N	\N	\N	4124	59	'4124':1A
28	12	\N	\N	\N	\N	\N	\N	\N	Mariusz	3	'mariusz':1A
29	12	\N	\N	\N	\N	\N	\N	\N	dReaw	4	'dreaw':1A
30	12	\N	\N	\N	\N	\N	\N	\N	Mariusz	5	'mariusz':1A
31	12	\N	\N	\N	\N	\N	\N	\N	Dariuesz	6	'dariuesz':1A
32	12	\N	\N	\N	\N	\N	\N	\N	Belzariusz	7	'belzariusz':1A
33	12	\N	\N	\N	\N	\N	\N	\N	Ileneusz	8	'ileneusz':1A
34	12	\N	\N	\N	\N	\N	\N	\N	Bierniasz	9	'bierniasz':1A
35	12	\N	\N	\N	\N	\N	\N	\N	Maruszz	10	'maruszz':1A
36	0	\N	\N	\N	\N	\N	\N	\N	Mariuszex123	60	'mariuszex123':1A
37	0	\N	\N	\N	\N	\N	\N	\N	Printexa	61	'printexa':1A
38	0	\N	\N	\N	\N	\N	\N	\N	Płytex	62	'płytex':1A
39	0	\N	\N	\N	\N	\N	\N	\N	StillWorking?	63	'stillworking':1A
40	1	\N	\N	\N	\N	\N	\N	\N	\N	63	\N
41	1	\N	\N	\N	\N	\N	\N	\N	\N	43	\N
42	1	\N	\N	\N	\N	\N	\N	\N	\N	63	\N
43	1	\N	\N	\N	\N	\N	\N	\N	\N	63	\N
44	1	\N	\N	\N	\N	\N	\N	\N	\N	63	\N
45	1	\N	\N	\N	\N	\N	\N	\N	\N	63	\N
46	1	\N	\N	\N	\N	\N	\N	\N	\N	63	\N
47	1	\N	\N	\N	\N	\N	\N	\N	\N	63	\N
48	1	\N	\N	\N	\N	\N	\N	\N	\N	63	\N
49	1	\N	\N	\N	\N	\N	\N	\N	\N	63	\N
50	1	\N	\N	\N	\N	\N	\N	\N	\N	62	\N
51	1	\N	\N	\N	\N	\N	\N	\N	\N	62	\N
52	1	\N	\N	\N	\N	\N	\N	\N	\N	59	\N
53	1	\N	\N	\N	\N	\N	\N	\N	\N	46	\N
54	1	\N	\N	\N	\N	\N	\N	\N	\N	25	\N
55	1	\N	\N	\N	\N	\N	\N	\N	\N	62	\N
56	1	\N	\N	\N	\N	\N	\N	\N	\N	61	\N
57	0	\N	\N	\N	\N	\N	\N	\N	Artuditu	64	'artuditu':1A
58	0	\N	\N	\N	\N	\N	\N	\N	Dziurexx	65	'dziurexx':1A
59	1	\N	\N	\N	\N	\N	\N	\N	\N	26	\N
60	1	\N	\N	\N	\N	\N	\N	\N	\N	65	\N
61	1	\N	\N	\N	\N	\N	\N	\N	\N	65	\N
62	1	\N	\N	\N	\N	\N	\N	\N	\N	65	\N
63	1	\N	\N	\N	\N	\N	\N	\N	\N	65	\N
64	1	\N	\N	\N	\N	\N	\N	\N	\N	65	\N
65	0	\N	\N	\N	\N	\N	\N	\N	Processsor	66	'processsor':1A
66	1	\N	\N	\N	\N	\N	\N	\N	\N	10	\N
67	1	\N	\N	\N	\N	\N	\N	\N	\N	64	\N
68	1	\N	\N	\N	\N	\N	\N	\N	\N	64	\N
69	1	\N	\N	\N	\N	\N	\N	\N	\N	58	\N
70	1	\N	\N	\N	\N	\N	\N	\N	\N	64	\N
71	1	\N	\N	\N	\N	\N	\N	\N	\N	64	\N
315	1	\N	\N	\N	\N	\N	2021-12-22 10:52:23.594532	\N	\N	83	\N
424	3	\N	\N	\N	\N	\N	2022-01-10 19:41:30.37065	\N	Sprzedaż dla Dariusz Palacz w dniu i godzinie 2022-01-10 19:40 	38	\N
429	3	\N	\N	\N	\N	\N	2022-01-10 19:49:41.001394	\N	Sprzedaż dla John Black w dniu i godzinie 2022-01-10 19:49 	49	\N
432	0	\N	\N	\N	\N	\N	2022-01-12 17:23:50.550527	\N	Steat 3200MHZ 8GB	119	\N
72	3	\N	\N	\N	\N	\N	\N	\N	No to to co robiłem sprzedałem	4	'co':4A 'no':1A 'robiłem':5A 'sprzedałem':6A 'to':2A,3A
73	3	\N	\N	\N	\N	\N	\N	\N	Sprzedaż dla Mariusz w dniu i godzinie 2021-08-29 13:34 	7	'-08':9A '-29':10A '13':11A '2021':8A '34':12A 'dla':2A 'dniu':5A 'godzinie':7A 'i':6A 'mariusz':3A 'sprzedaż':1A 'w':4A
74	3	\N	\N	\N	\N	\N	\N	\N	Sprzedaż dla Mariusz w dniu i godzinie 2021-08-29 13:34 	6	'-08':9A '-29':10A '13':11A '2021':8A '34':12A 'dla':2A 'dniu':5A 'godzinie':7A 'i':6A 'mariusz':3A 'sprzedaż':1A 'w':4A
75	3	\N	\N	\N	\N	\N	\N	\N	Sprzedaż dla Mariusz w dniu i godzinie 2021-08-29 13:34 	5	'-08':9A '-29':10A '13':11A '2021':8A '34':12A 'dla':2A 'dniu':5A 'godzinie':7A 'i':6A 'mariusz':3A 'sprzedaż':1A 'w':4A
76	3	\N	\N	\N	\N	\N	\N	\N	Sprzedaż dla Mariusz w dniu i godzinie 2021-08-29 13:34 	8	'-08':9A '-29':10A '13':11A '2021':8A '34':12A 'dla':2A 'dniu':5A 'godzinie':7A 'i':6A 'mariusz':3A 'sprzedaż':1A 'w':4A
77	3	\N	\N	\N	\N	\N	\N	\N	Sprzedaż dla Mariusz w dniu i godzinie 2021-08-29 13:34 	9	'-08':9A '-29':10A '13':11A '2021':8A '34':12A 'dla':2A 'dniu':5A 'godzinie':7A 'i':6A 'mariusz':3A 'sprzedaż':1A 'w':4A
78	3	\N	\N	\N	\N	\N	\N	\N	Sprzedaż dla Mariusz w dniu i godzinie 2021-08-29 13:34 	10	'-08':9A '-29':10A '13':11A '2021':8A '34':12A 'dla':2A 'dniu':5A 'godzinie':7A 'i':6A 'mariusz':3A 'sprzedaż':1A 'w':4A
79	3	\N	\N	\N	\N	\N	\N	\N	Sprzedaż dla Mariusz w dniu i godzinie 2021-08-29 13:34 	11	'-08':9A '-29':10A '13':11A '2021':8A '34':12A 'dla':2A 'dniu':5A 'godzinie':7A 'i':6A 'mariusz':3A 'sprzedaż':1A 'w':4A
80	3	\N	\N	\N	\N	\N	\N	\N	Sprzedaż dla Mariusz w dniu i godzinie 2021-08-29 13:34 	12	'-08':9A '-29':10A '13':11A '2021':8A '34':12A 'dla':2A 'dniu':5A 'godzinie':7A 'i':6A 'mariusz':3A 'sprzedaż':1A 'w':4A
81	3	\N	\N	\N	\N	\N	\N	\N	Sprzedaż dla Dariuesz w dniu i godzinie 2021-08-29 13:55 	14	'-08':9A '-29':10A '13':11A '2021':8A '55':12A 'dariuesz':3A 'dla':2A 'dniu':5A 'godzinie':7A 'i':6A 'sprzedaż':1A 'w':4A
82	3	\N	\N	\N	\N	\N	\N	\N	Sprzedaż dla Dariuesz w dniu i godzinie 2021-08-29 13:55 	13	'-08':9A '-29':10A '13':11A '2021':8A '55':12A 'dariuesz':3A 'dla':2A 'dniu':5A 'godzinie':7A 'i':6A 'sprzedaż':1A 'w':4A
83	3	\N	\N	\N	\N	\N	\N	\N	Sprzedaż dla Belzariusz w dniu i godzinie 2021-08-29 15:29 	16	'-08':9A '-29':10A '15':11A '2021':8A '29':12A 'belzariusz':3A 'dla':2A 'dniu':5A 'godzinie':7A 'i':6A 'sprzedaż':1A 'w':4A
84	3	\N	\N	\N	\N	\N	\N	\N	Sprzedaż dla Belzariusz w dniu i godzinie 2021-08-29 15:29 	17	'-08':9A '-29':10A '15':11A '2021':8A '29':12A 'belzariusz':3A 'dla':2A 'dniu':5A 'godzinie':7A 'i':6A 'sprzedaż':1A 'w':4A
85	3	\N	\N	\N	\N	\N	\N	\N	Sprzedaż dla Belzariusz w dniu i godzinie 2021-08-29 15:29 	18	'-08':9A '-29':10A '15':11A '2021':8A '29':12A 'belzariusz':3A 'dla':2A 'dniu':5A 'godzinie':7A 'i':6A 'sprzedaż':1A 'w':4A
86	3	\N	\N	\N	\N	\N	\N	\N	Sprzedaż dla Belzariusz w dniu i godzinie 2021-08-29 15:29 	19	'-08':9A '-29':10A '15':11A '2021':8A '29':12A 'belzariusz':3A 'dla':2A 'dniu':5A 'godzinie':7A 'i':6A 'sprzedaż':1A 'w':4A
87	3	\N	\N	\N	\N	\N	\N	\N	Sprzedaż dla Belzariusz w dniu i godzinie 2021-08-29 15:29 	20	'-08':9A '-29':10A '15':11A '2021':8A '29':12A 'belzariusz':3A 'dla':2A 'dniu':5A 'godzinie':7A 'i':6A 'sprzedaż':1A 'w':4A
88	3	\N	\N	\N	\N	\N	\N	\N	Sprzedaż dla Belzariusz w dniu i godzinie 2021-08-29 15:29 	15	'-08':9A '-29':10A '15':11A '2021':8A '29':12A 'belzariusz':3A 'dla':2A 'dniu':5A 'godzinie':7A 'i':6A 'sprzedaż':1A 'w':4A
89	3	\N	\N	\N	\N	\N	\N	\N	Sprzedaż dla Belzariusz w dniu i godzinie 2021-08-29 15:29 	21	'-08':9A '-29':10A '15':11A '2021':8A '29':12A 'belzariusz':3A 'dla':2A 'dniu':5A 'godzinie':7A 'i':6A 'sprzedaż':1A 'w':4A
90	3	\N	\N	\N	\N	\N	\N	\N	Sprzedaż dla Belzariusz w dniu i godzinie 2021-08-29 15:29 	22	'-08':9A '-29':10A '15':11A '2021':8A '29':12A 'belzariusz':3A 'dla':2A 'dniu':5A 'godzinie':7A 'i':6A 'sprzedaż':1A 'w':4A
91	3	\N	\N	\N	\N	\N	\N	\N	Sprzedaż dla Maruszz w dniu i godzinie 2021-08-29 15:34 	24	'-08':9A '-29':10A '15':11A '2021':8A '34':12A 'dla':2A 'dniu':5A 'godzinie':7A 'i':6A 'maruszz':3A 'sprzedaż':1A 'w':4A
92	3	\N	\N	\N	\N	\N	\N	\N	Sprzedaż dla Maruszz w dniu i godzinie 2021-08-29 15:34 	23	'-08':9A '-29':10A '15':11A '2021':8A '34':12A 'dla':2A 'dniu':5A 'godzinie':7A 'i':6A 'maruszz':3A 'sprzedaż':1A 'w':4A
93	3	\N	\N	\N	\N	\N	\N	\N	Sprzedaż dla Mariusz w dniu i godzinie 2021-08-29 15:39 	2	'-08':9A '-29':10A '15':11A '2021':8A '39':12A 'dla':2A 'dniu':5A 'godzinie':7A 'i':6A 'mariusz':3A 'sprzedaż':1A 'w':4A
94	3	\N	\N	\N	\N	\N	\N	\N	Sprzedaż dla Mariusz w dniu i godzinie 2021-08-29 15:39 	1	'-08':9A '-29':10A '15':11A '2021':8A '39':12A 'dla':2A 'dniu':5A 'godzinie':7A 'i':6A 'mariusz':3A 'sprzedaż':1A 'w':4A
95	3	\N	\N	\N	\N	\N	\N	\N	Sprzedaż dla Mariusz w dniu i godzinie 2021-08-29 15:42 	4	'-08':9A '-29':10A '15':11A '2021':8A '42':12A 'dla':2A 'dniu':5A 'godzinie':7A 'i':6A 'mariusz':3A 'sprzedaż':1A 'w':4A
96	3	\N	\N	\N	\N	\N	\N	\N	Sprzedaż dla Mariusz w dniu i godzinie 2021-08-29 15:42 	3	'-08':9A '-29':10A '15':11A '2021':8A '42':12A 'dla':2A 'dniu':5A 'godzinie':7A 'i':6A 'mariusz':3A 'sprzedaż':1A 'w':4A
97	3	\N	\N	\N	\N	\N	\N	\N	5	5	'5':1A
98	3	\N	\N	\N	\N	\N	\N	\N	Sprzedaż dla Dariuesz w dniu i godzinie 2021-08-29 15:54 	1	'-08':9A '-29':10A '15':11A '2021':8A '54':12A 'dariuesz':3A 'dla':2A 'dniu':5A 'godzinie':7A 'i':6A 'sprzedaż':1A 'w':4A
99	3	\N	\N	\N	\N	\N	\N	\N	Dla fajnego pana	1	'dla':1A 'fajnego':2A 'pana':3A
100	15	\N	\N	\N	\N	\N	\N	\N	Gieniek	7	'gieniek':1A
101	15	\N	\N	\N	\N	\N	\N	\N	MariuszPol	8	'mariuszpol':1A
102	15	\N	\N	\N	\N	\N	\N	\N	Dobry typ	9	'dobry':1A 'typ':2A
103	1	\N	\N	\N	\N	\N	\N	\N	\N	66	\N
104	16	\N	\N	\N	\N	\N	\N	\N	Gieniek2	7	'gieniek2':1A
105	16	\N	\N	\N	\N	\N	\N	\N	Gieniek28	7	'gieniek28':1A
106	16	\N	\N	\N	\N	\N	\N	\N	Gieniek28	7	'gieniek28':1A
107	1	\N	\N	\N	\N	\N	\N	\N	\N	66	\N
108	1	\N	\N	\N	\N	\N	\N	\N	\N	7	\N
220	1	\N	\N	\N	\N	\N	2021-10-24 16:30:42.987066	\N	\N	41	\N
336	0	\N	\N	\N	\N	\N	2021-12-23 14:05:52.425745	\N	DASFafasd fsda	94	\N
109	3	\N	\N	\N	\N	\N	\N	\N	Sprzedaż dla John Black w dniu i godzinie 2021-08-27 01:20 	2	'-08':10A '-27':11A '01':12A '20':13A '2021':9A 'black':4A 'dla':2A 'dniu':6A 'godzinie':8A 'i':7A 'john':3A 'sprzedaż':1A 'w':5A
110	16	\N	\N	\N	\N	\N	\N	\N	Gieniek28	7	'gieniek28':1A
111	13	\N	\N	\N	\N	\N	\N	\N	Mariusz	373	'mariusz':1A
112	13	\N	\N	\N	\N	\N	\N	\N	Mariusz	373	'mariusz':1A
113	0	\N	\N	\N	\N	\N	\N	\N	Płytex RX 420	67	'420':3A 'płytex':1A 'rx':2A
114	0	\N	\N	\N	\N	\N	\N	\N	Kartexx RX 4210	68	'4210':3A 'kartexx':1A 'rx':2A
115	17	\N	\N	\N	\N	\N	\N	\N	Dobry typ	9	'dobry':1A 'typ':2A
117	2	\N	\N	\N	\N	\N	\N	\N	Kartexx RX 4210	68	'4210':3A 'kartexx':1A 'rx':2A
118	2	\N	\N	\N	\N	\N	\N	\N	StillWorking1?21	63	'21':2A 'stillworking1':1A
119	2	\N	\N	\N	\N	\N	\N	\N	Bierniasz	9	'bierniasz':1A
120	2	\N	\N	\N	\N	\N	\N	\N	Belzariusz	7	'belzariusz':1A
121	1	\N	\N	\N	\N	\N	\N	\N	\N	61	\N
122	1	\N	\N	\N	\N	\N	\N	\N	\N	66	\N
123	1	\N	\N	\N	\N	\N	\N	\N	\N	61	\N
124	1	\N	\N	\N	\N	\N	\N	\N	\N	47	\N
125	16	\N	\N	\N	\N	\N	\N	\N	Gieniek28	7	'gieniek28':1A
126	16	\N	\N	\N	\N	\N	\N	\N	Gieniek28	7	'gieniek28':1A
127	16	\N	\N	\N	\N	\N	\N	\N	Gieniek28	7	'gieniek28':1A
128	16	\N	\N	\N	\N	\N	\N	\N	AB Polska	1	'ab':1A 'polska':2A
129	16	\N	\N	\N	\N	\N	\N	\N	Proline pl	6	'pl':2A 'proline':1A
130	16	\N	\N	\N	\N	\N	\N	\N	Proline pl	6	'pl':2A 'proline':1A
131	16	\N	\N	\N	\N	\N	\N	\N	PolHur	5	'polhur':1A
132	5	\N	\N	\N	\N	\N	\N	\N	Łoo panoie mega	12	'mega':3A 'panoie':2A 'łoo':1A
133	2	\N	\N	\N	\N	\N	\N	\N	Mariusz	373	'mariusz':1A
134	5	\N	\N	\N	\N	\N	\N	\N	Łoo panoie mega	13	'mega':3A 'panoie':2A 'łoo':1A
135	1	\N	\N	\N	\N	\N	\N	\N	\N	26	\N
136	5	\N	\N	\N	\N	\N	\N	\N	kRateix2Fajnypr092723u11zizpfyp-02	14	'-02':2A 'krateix2fajnypr092723u11zizpfyp':1A
137	5	\N	\N	\N	\N	\N	\N	\N	kUltradr093100qdv9c6i1bs-02	15	'-02':2A 'kultradr093100qdv9c6i1bs':1A
138	1	\N	\N	\N	\N	\N	\N	\N	\N	5	\N
139	5	\N	\N	\N	\N	\N	\N	\N	kUltradrqa093100ww8blv6lg9-02	16	'-02':2A 'kultradrqa093100ww8blv6lg9':1A
140	5	\N	\N	\N	\N	\N	\N	\N	Fajen komputronik	17	'fajen':1A 'komputronik':2A
141	5	\N	\N	\N	\N	\N	\N	\N	kUltradr093800odplh61ou1-02	18	'-02':2A 'kultradr093800odplh61ou1':1A
142	6	\N	\N	\N	\N	\N	\N	\N	Łoo panoie mega	5	'mega':3A 'panoie':2A 'łoo':1A
143	6	\N	\N	\N	\N	\N	\N	\N	Złapdejtowany	5	'złapdejtowany':1A
144	5	\N	\N	\N	\N	\N	\N	\N	kProcesss4214095201tj1wg9ps4i-02	19	'-02':2A 'kprocesss4214095201tj1wg9ps4i':1A
145	5	\N	\N	\N	\N	\N	\N	\N	Cycccaaee	20	'cycccaaee':1A
146	1	\N	\N	\N	\N	\N	\N	\N	\N	51	\N
147	7	\N	\N	\N	\N	\N	\N	\N	kRateix2Fajnypr092723u11zizpfyp-02	14	'-02':2A 'krateix2fajnypr092723u11zizpfyp':1A
148	8	\N	\N	\N	\N	\N	\N	\N	4124	18	'4124':1A
149	8	\N	\N	\N	\N	\N	\N	\N	No niestety się popsuł	19	'niestety':2A 'no':1A 'popsuł':4A 'się':3A
150	8	\N	\N	\N	\N	\N	\N	\N	Tam się płyta główna mogła skiepścić	20	'główna':4A 'mogła':5A 'płyta':3A 'się':2A 'skiepścić':6A 'tam':1A
151	12	\N	\N	\N	\N	\N	\N	\N	Wojciech Zych	11	'wojciech':1A 'zych':2A
152	13	\N	\N	\N	\N	\N	\N	\N	Wojciech Zych	11	'wojciech':1A 'zych':2A
153	1	\N	\N	\N	\N	\N	\N	\N	\N	66	\N
154	13	\N	\N	\N	\N	\N	\N	\N	John Black	1	'black':2A 'john':1A
155	9	\N	\N	\N	\N	\N	\N	\N	4124	18	'4124':1A
156	9	\N	\N	\N	\N	\N	\N	\N	Tam się płyta główna mogła skiepścić	20	'główna':4A 'mogła':5A 'płyta':3A 'się':2A 'skiepścić':6A 'tam':1A
157	9	\N	\N	\N	\N	\N	\N	\N	Tam się płyta główna mogła skiepścić	20	'główna':4A 'mogła':5A 'płyta':3A 'się':2A 'skiepścić':6A 'tam':1A
158	9	\N	\N	\N	\N	\N	\N	\N	Tam się płyta główna mogła skiepścić	20	'główna':4A 'mogła':5A 'płyta':3A 'się':2A 'skiepścić':6A 'tam':1A
159	9	\N	\N	\N	\N	\N	\N	\N	Tam się płyta główna mogła skiepścić	20	'główna':4A 'mogła':5A 'płyta':3A 'się':2A 'skiepścić':6A 'tam':1A
160	9	\N	\N	\N	\N	\N	\N	\N	Tam się płyta główna mogła skiepścić	20	'główna':4A 'mogła':5A 'płyta':3A 'się':2A 'skiepścić':6A 'tam':1A
161	1	\N	\N	\N	\N	\N	\N	\N	\N	66	\N
162	9	\N	\N	\N	\N	\N	\N	\N	Tam się płyta główna mogła skiepścić	20	'główna':4A 'mogła':5A 'płyta':3A 'się':2A 'skiepścić':6A 'tam':1A
163	0	\N	\N	\N	\N	\N	2021-09-03 23:34:58.812071	\N	Karta graficzna	69	'03/09/2021':3C 'graficzna':2A 'karta':1A
164	5	\N	\N	\N	\N	\N	2021-09-03 23:44:58.3732	\N	Komputronix 3000	21	'03/09/2021':3C '3000':2A 'komputronix':1A
165	1	\N	\N	\N	\N	\N	2021-09-11 18:32:09.003862	\N	\N	69	\N
166	1	\N	\N	\N	\N	\N	2021-10-07 19:56:13.628969	\N	\N	69	\N
167	1	\N	\N	\N	\N	\N	2021-10-07 19:56:27.516313	\N	\N	64	\N
168	9	\N	\N	\N	\N	\N	2021-10-07 19:58:57.217393	\N	Tam się płyta główna mogła skiepścić	20	'07/10/2021':7C 'główna':4A 'mogła':5A 'płyta':3A 'się':2A 'skiepścić':6A 'tam':1A
169	1	\N	\N	\N	\N	\N	2021-10-07 20:06:36.215173	\N	\N	46	\N
170	1	\N	\N	\N	\N	\N	2021-10-07 20:08:31.311256	\N	\N	69	\N
171	1	\N	\N	\N	\N	\N	2021-10-07 20:08:33.356112	\N	\N	69	\N
172	1	\N	\N	\N	\N	\N	2021-10-07 20:08:33.659017	\N	\N	69	\N
173	1	\N	\N	\N	\N	\N	2021-10-07 20:08:34.155888	\N	\N	69	\N
174	1	\N	\N	\N	\N	\N	2021-10-07 20:08:36.151552	\N	\N	69	\N
175	1	\N	\N	\N	\N	\N	2021-10-07 20:08:40.993021	\N	\N	69	\N
176	16	\N	\N	\N	\N	\N	2021-10-07 20:25:58.649006	\N	MariuszPol	8	'07/10/2021':2C 'mariuszpol':1A
177	16	\N	\N	\N	\N	\N	2021-10-07 20:26:01.117198	\N	MariuszPol	8	'07/10/2021':2C 'mariuszpol':1A
178	0	\N	\N	\N	\N	\N	2021-10-07 20:34:14.146474	\N	Płycia	70	'07/10/2021':2C 'płycia':1A
179	1	\N	\N	\N	\N	\N	2021-10-13 18:44:08.413305	\N	\N	70	\N
180	5	\N	\N	\N	\N	\N	2021-10-13 18:55:41.312526	\N	kMariuzFana104318ubow2vhb8t-13	22	'-13':2A '13/10/2021':3C 'kmariuzfana104318ubow2vhb8t':1A
181	1	\N	\N	\N	\N	\N	2021-10-15 15:13:00.4525	\N	\N	70	\N
182	13	\N	\N	\N	\N	\N	2021-10-16 22:05:29.821218	\N	Wojciech Zych	11	'16/10/2021':3C 'wojciech':1A 'zych':2A
183	1	\N	\N	\N	\N	\N	2021-10-17 00:02:21.941373	\N	\N	62	\N
184	1	\N	\N	\N	\N	\N	2021-10-17 00:02:29.195316	\N	\N	54	\N
185	0	\N	\N	\N	\N	\N	2021-10-17 20:44:13.919953	\N	Gigabyt	71	'17/10/2021':2C 'gigabyt':1A
186	0	\N	\N	\N	\N	\N	2021-10-24 14:00:11.858335	\N	 ASUS Tuf GeForce RTX 3080Ti Gaming LHR 12GB	72	'12gb':8A '24/10/2021':9C '3080ti':5A 'asus':1A 'gaming':6A 'geforce':3A 'lhr':7A 'rtx':4A 'tuf':2A
187	0	\N	\N	\N	\N	\N	2021-10-24 14:01:08.589291	\N	Gigabyte GeForce RTX 3070 VISION OC LHR 8GB GDDR6	73	'24/10/2021':10C '3070':4A '8gb':8A 'gddr6':9A 'geforce':2A 'gigabyte':1A 'lhr':7A 'oc':6A 'rtx':3A 'vision':5A
188	0	\N	\N	\N	\N	\N	2021-10-24 14:04:03.845254	\N	AMD Radeon Pro W5700 8GB GDDR6	74	'24/10/2021':7C '8gb':5A 'amd':1A 'gddr6':6A 'pro':3A 'radeon':2A 'w5700':4A
189	0	\N	\N	\N	\N	\N	2021-10-24 14:04:22.929177	\N	MSI Radeon RX 6700 XT MECH 2X OC 12GB GDDR6	75	'12gb':9A '24/10/2021':11C '2x':7A '6700':4A 'gddr6':10A 'mech':6A 'msi':1A 'oc':8A 'radeon':2A 'rx':3A 'xt':5A
190	1	\N	\N	\N	\N	\N	2021-10-24 15:35:38.960091	\N	\N	61	\N
191	1	\N	\N	\N	\N	\N	2021-10-24 15:38:01.150704	\N	\N	58	\N
192	1	\N	\N	\N	\N	\N	2021-10-24 15:39:37.669638	\N	\N	39	\N
193	1	\N	\N	\N	\N	\N	2021-10-24 15:54:37.446912	\N	\N	38	\N
194	1	\N	\N	\N	\N	\N	2021-10-24 16:07:04.347025	\N	\N	71	\N
195	1	\N	\N	\N	\N	\N	2021-10-24 16:07:39.750254	\N	\N	70	\N
196	1	\N	\N	\N	\N	\N	2021-10-24 16:07:43.128463	\N	\N	70	\N
197	1	\N	\N	\N	\N	\N	2021-10-24 16:08:14.631951	\N	\N	66	\N
198	1	\N	\N	\N	\N	\N	2021-10-24 16:08:16.597111	\N	\N	66	\N
199	1	\N	\N	\N	\N	\N	2021-10-24 16:14:46.414926	\N	\N	69	\N
200	1	\N	\N	\N	\N	\N	2021-10-24 16:15:23.812224	\N	\N	65	\N
201	1	\N	\N	\N	\N	\N	2021-10-24 16:16:15.978445	\N	\N	64	\N
202	1	\N	\N	\N	\N	\N	2021-10-24 16:17:06.690752	\N	\N	62	\N
203	1	\N	\N	\N	\N	\N	2021-10-24 16:17:45.944602	\N	\N	60	\N
204	1	\N	\N	\N	\N	\N	2021-10-24 16:18:09.802734	\N	\N	59	\N
205	1	\N	\N	\N	\N	\N	2021-10-24 16:18:49.245141	\N	\N	57	\N
206	1	\N	\N	\N	\N	\N	2021-10-24 16:19:31.557641	\N	\N	56	\N
207	1	\N	\N	\N	\N	\N	2021-10-24 16:20:11.014534	\N	\N	55	\N
208	1	\N	\N	\N	\N	\N	2021-10-24 16:20:48.617027	\N	\N	54	\N
209	1	\N	\N	\N	\N	\N	2021-10-24 16:21:35.425063	\N	\N	53	\N
210	1	\N	\N	\N	\N	\N	2021-10-24 16:25:12.365815	\N	\N	52	\N
211	1	\N	\N	\N	\N	\N	2021-10-24 16:25:40.225194	\N	\N	51	\N
212	1	\N	\N	\N	\N	\N	2021-10-24 16:25:59.564938	\N	\N	50	\N
213	1	\N	\N	\N	\N	\N	2021-10-24 16:26:55.195107	\N	\N	48	\N
214	1	\N	\N	\N	\N	\N	2021-10-24 16:27:33.099436	\N	\N	47	\N
215	1	\N	\N	\N	\N	\N	2021-10-24 16:28:06.041384	\N	\N	46	\N
216	1	\N	\N	\N	\N	\N	2021-10-24 16:28:29.221449	\N	\N	45	\N
217	1	\N	\N	\N	\N	\N	2021-10-24 16:28:56.080359	\N	\N	44	\N
218	1	\N	\N	\N	\N	\N	2021-10-24 16:29:25.228875	\N	\N	43	\N
219	1	\N	\N	\N	\N	\N	2021-10-24 16:30:12.343996	\N	\N	42	\N
221	1	\N	\N	\N	\N	\N	2021-10-24 16:31:07.342326	\N	\N	40	\N
222	1	\N	\N	\N	\N	\N	2021-10-24 16:31:29.741007	\N	\N	25	\N
223	1	\N	\N	\N	\N	\N	2021-10-24 16:32:13.276192	\N	\N	2	\N
224	1	\N	\N	\N	\N	\N	2021-10-24 16:32:40.07988	\N	\N	5	\N
225	1	\N	\N	\N	\N	\N	2021-10-24 16:34:29.636351	\N	\N	56	\N
226	13	\N	\N	\N	\N	\N	2021-10-24 16:35:41.965699	\N	James Smith	13	'24/10/2021':3C 'james':1A 'smith':2A
227	13	\N	\N	\N	\N	\N	2021-10-24 16:35:57.174052	\N	James Smith	13	'24/10/2021':3C 'james':1A 'smith':2A
228	13	\N	\N	\N	\N	\N	2021-10-24 16:36:04.84857	\N	Wojciech Juliusz	11	'24/10/2021':3C 'juliusz':2A 'wojciech':1A
229	13	\N	\N	\N	\N	\N	2021-10-24 16:36:23.056864	\N	Marusz Nalepa	10	'24/10/2021':3C 'marusz':1A 'nalepa':2A
230	13	\N	\N	\N	\N	\N	2021-10-24 16:36:37.032806	\N	Amadeusz Wajcheprzełóż	8	'24/10/2021':3C 'amadeusz':1A 'wajcheprzełóż':2A
231	13	\N	\N	\N	\N	\N	2021-10-24 16:36:46.096052	\N	Dariusz Palacz	6	'24/10/2021':3C 'dariusz':1A 'palacz':2A
232	13	\N	\N	\N	\N	\N	2021-10-24 16:37:05.272218	\N	Amelia Chorożnyf	5	'24/10/2021':3C 'amelia':1A 'chorożnyf':2A
233	13	\N	\N	\N	\N	\N	2021-10-24 16:37:29.300682	\N	Mariusz	2	'24/10/2021':2C 'mariusz':1A
234	13	\N	\N	\N	\N	\N	2021-10-24 16:37:59.697044	\N	Michał Kuluts	2	'24/10/2021':3C 'kuluts':2A 'michał':1A
235	13	\N	\N	\N	\N	\N	2021-10-24 16:38:05.95442	\N	Amelia Chorożny	5	'24/10/2021':3C 'amelia':1A 'chorożny':2A
236	16	\N	\N	\N	\N	\N	2021-10-24 16:38:26.883718	\N	MariuszPol	8	'24/10/2021':2C 'mariuszpol':1A
237	9	\N	\N	\N	\N	\N	2021-10-24 18:00:41.166065	\N	Tam się płyta główna mogła skiepścić	20	'24/10/2021':7C 'główna':4A 'mogła':5A 'płyta':3A 'się':2A 'skiepścić':6A 'tam':1A
238	9	\N	\N	\N	\N	\N	2021-10-24 18:00:52.938308	\N	No niestety się popsuł	19	'24/10/2021':5C 'niestety':2A 'no':1A 'popsuł':4A 'się':3A
239	9	\N	\N	\N	\N	\N	2021-10-24 18:01:04.349612	\N	Nie no tam musiało coś paść	18	'24/10/2021':7C 'coś':5A 'musiało':4A 'nie':1A 'no':2A 'paść':6A 'tam':3A
240	9	\N	\N	\N	\N	\N	2021-10-24 18:01:12.200651	\N	Tets tego	14	'24/10/2021':3C 'tego':2A 'tets':1A
241	9	\N	\N	\N	\N	\N	2021-10-24 18:01:21.170016	\N	Twój  się zepsuło, nie było mnie słychać	17	'24/10/2021':8C 'było':5A 'mnie':6A 'nie':4A 'się':2A 'słychać':7A 'twój':1A 'zepsuło':3A
242	9	\N	\N	\N	\N	\N	2021-10-24 18:01:28.551631	\N	Twój  się zepsuło, nie było mnie słychać	16	'24/10/2021':8C 'było':5A 'mnie':6A 'nie':4A 'się':2A 'słychać':7A 'twój':1A 'zepsuło':3A
243	1	\N	\N	\N	\N	\N	2021-10-25 22:06:56.156764	\N	\N	75	\N
244	3	\N	\N	\N	\N	\N	2021-10-27 13:39:23.902712	\N	Sprzedaż dla Marusz Nalepa w dniu i godzinie 2021-10-27 13:26 	4	'-10':10A '-27':11A '13':12A '2021':9A '26':13A '27/10/2021':14C 'dla':2A 'dniu':6A 'godzinie':8A 'i':7A 'marusz':3A 'nalepa':4A 'sprzedaż':1A 'w':5A
245	5	\N	\N	\N	\N	\N	2021-10-27 14:15:15.661634	\N	kAMDRyzeMSIMPG101514pypiptgfghg-27	23	'-27':2A '27/10/2021':3C 'kamdryzemsimpg101514pypiptgfghg':1A
246	5	\N	\N	\N	\N	\N	2021-10-27 14:32:07.396751	\N	kIntelCoMSIMPG103014c5ud30wjan-27	24	'-27':2A '27/10/2021':3C 'kintelcomsimpg103014c5ud30wjan':1A
247	1	\N	\N	\N	\N	\N	2021-10-27 14:33:03.335684	\N	\N	75	\N
248	1	\N	\N	\N	\N	\N	2021-10-27 14:33:09.300905	\N	\N	74	\N
249	1	\N	\N	\N	\N	\N	2021-10-27 14:33:16.959526	\N	\N	75	\N
250	5	\N	\N	\N	\N	\N	2021-10-27 14:33:30.478566	\N	kInteli5103214a60ik2favqj-27	25	'-27':2A '27/10/2021':3C 'kinteli5103214a60ik2favqj':1A
251	0	\N	\N	\N	\N	\N	2021-10-27 15:10:00.98469	\N	Crucial 16GB (2x8GB) 3200MHz CL16 Ballistix Black RGB	76	'16gb':2A '27/10/2021':9C '2x8gb':3A '3200mhz':4A 'ballistix':6A 'black':7A 'cl16':5A 'crucial':1A 'rgb':8A
252	0	\N	\N	\N	\N	\N	2021-10-27 15:10:41.902173	\N	Dell S2721DGFA nanoIPS HDR	77	'27/10/2021':5C 'dell':1A 'hdr':4A 'nanoips':3A 's2721dgfa':2A
253	0	\N	\N	\N	\N	\N	2021-10-27 15:11:11.410186	\N	Acer SB241Y	78	'27/10/2021':3C 'acer':1A 'sb241y':2A
254	0	\N	\N	\N	\N	\N	2021-10-27 15:11:40.154586	\N	G.SKILL 16GB (2x8GB) 3200MHz CL16 Aegis	79	'16gb':2A '27/10/2021':7C '2x8gb':3A '3200mhz':4A 'aegis':6A 'cl16':5A 'g.skill':1A
255	1	\N	\N	\N	\N	\N	2021-10-27 15:19:02.507365	\N	\N	61	\N
256	5	\N	\N	\N	\N	\N	2021-10-27 15:23:04.872163	\N	kAMDRyzeASRockB101515xqo6aeqskg-27	26	'-27':2A '27/10/2021':3C 'kamdryzeasrockb101515xqo6aeqskg':1A
257	0	\N	\N	\N	\N	\N	2021-10-27 15:49:37.277484	\N	Patriot 16GB (2x8GB) 3200MHz CL16 Viper Steel	80	'16gb':2A '27/10/2021':8C '2x8gb':3A '3200mhz':4A 'cl16':5A 'patriot':1A 'steel':7A 'viper':6A
258	0	\N	\N	\N	\N	\N	2021-10-27 15:50:04.527287	\N	Corsair 16GB(2x8GB) 3600MHz CL18 Vengeance RGB Pro	81	'16gb':2A '27/10/2021':9C '2x8gb':3A '3600mhz':4A 'cl18':5A 'corsair':1A 'pro':8A 'rgb':7A 'vengeance':6A
259	0	\N	\N	\N	\N	\N	2021-10-27 15:50:45.394198	\N	Crucial 8GB (1x8GB) 2666MHz CL19	82	'1x8gb':3A '2666mhz':4A '27/10/2021':6C '8gb':2A 'cl19':5A 'crucial':1A
260	0	\N	\N	\N	\N	\N	2021-10-27 15:51:38.495596	\N	Samsung Odyssey F24G35TFWUX	83	'27/10/2021':4C 'f24g35tfwux':3A 'odyssey':2A 'samsung':1A
261	0	\N	\N	\N	\N	\N	2021-10-27 15:52:03.883912	\N	Acer Nitro QG241YBII czarny	84	'27/10/2021':5C 'acer':1A 'czarny':4A 'nitro':2A 'qg241ybii':3A
262	0	\N	\N	\N	\N	\N	2021-10-27 15:52:54.289304	\N	AMD Athlon 3000G	85	'27/10/2021':4C '3000g':3A 'amd':1A 'athlon':2A
263	16	\N	\N	\N	\N	\N	2021-10-27 16:12:45.362139	\N	X-Kom	4	'27/10/2021':4C 'kom':3A 'x':2A 'x-kom':1A
264	16	\N	\N	\N	\N	\N	2021-10-27 16:12:49.792676	\N	X-Kom	4	'27/10/2021':4C 'kom':3A 'x':2A 'x-kom':1A
265	16	\N	\N	\N	\N	\N	2021-10-27 16:12:51.996631	\N	X-Kom	4	'27/10/2021':4C 'kom':3A 'x':2A 'x-kom':1A
266	16	\N	\N	\N	\N	\N	2021-10-27 16:12:55.456821	\N	X-Kom	4	'27/10/2021':4C 'kom':3A 'x':2A 'x-kom':1A
267	9	\N	\N	\N	\N	\N	2021-10-27 16:32:34.88434	\N	Zepsuł się na amen, chyba, płyta główna raczej	17	'27/10/2021':9C 'amen':4A 'chyba':5A 'główna':7A 'na':3A 'płyta':6A 'raczej':8A 'się':2A 'zepsuł':1A
268	9	\N	\N	\N	\N	\N	2021-10-27 16:33:19.165173	\N	Tam się popsuł dysk najprawdopodobniej, nie mogę odtwarzać piosenek Franka Kimono	12	'27/10/2021':12C 'dysk':4A 'franka':10A 'kimono':11A 'mogę':7A 'najprawdopodobniej':5A 'nie':6A 'odtwarzać':8A 'piosenek':9A 'popsuł':3A 'się':2A 'tam':1A
269	9	\N	\N	\N	\N	\N	2021-10-27 16:34:11.968154	\N	Po pierwsze primo, procek się przegrzewa, po drugie primo PSU jest niestabilne	19	'27/10/2021':13C 'drugie':8A 'jest':11A 'niestabilne':12A 'pierwsze':2A 'po':1A,7A 'primo':3A,9A 'procek':4A 'przegrzewa':6A 'psu':10A 'się':5A
270	9	\N	\N	\N	\N	\N	2021-10-27 16:34:22.883741	\N	Psuja	2	'27/10/2021':2C 'psuja':1A
271	9	\N	\N	\N	\N	\N	2021-10-27 16:34:53.689796	\N	Problem z wentylatorem	4	'27/10/2021':4C 'problem':1A 'wentylatorem':3A 'z':2A
272	9	\N	\N	\N	\N	\N	2021-10-27 16:35:04.532116	\N	Problem z PSU	13	'27/10/2021':4C 'problem':1A 'psu':3A 'z':2A
273	1	\N	\N	\N	\N	\N	2021-10-27 17:35:27.348772	\N	\N	76	\N
274	0	\N	\N	\N	\N	\N	2021-10-28 19:02:53.181198	\N	Gigabyte A520 Aorus	86	'28/10/2021':4C 'a520':2A 'aorus':3A 'gigabyte':1A
275	0	\N	\N	\N	\N	\N	2021-10-28 19:02:53.190171	\N	Gigabyte A520 Aorus	87	'28/10/2021':4C 'a520':2A 'aorus':3A 'gigabyte':1A
276	2	\N	\N	\N	\N	\N	2021-10-28 19:03:16.609458	\N	Gigabyte A520 Aorus	86	'28/10/2021':4C 'a520':2A 'aorus':3A 'gigabyte':1A
277	2	\N	\N	\N	\N	\N	2021-10-28 19:03:26.062638	\N	Gigabyte A520 Aorus	87	'28/10/2021':4C 'a520':2A 'aorus':3A 'gigabyte':1A
278	0	\N	\N	\N	\N	\N	2021-10-28 19:03:46.411433	\N	Gigabyte A520 Aorus Elite	88	'28/10/2021':5C 'a520':2A 'aorus':3A 'elite':4A 'gigabyte':1A
279	2	\N	\N	\N	\N	\N	2021-10-28 19:03:59.32564	\N	Gigabyte A520 Aorus Elite	88	'28/10/2021':5C 'a520':2A 'aorus':3A 'elite':4A 'gigabyte':1A
280	0	\N	\N	\N	\N	\N	2021-10-28 19:04:46.880659	\N	Gigabyte A520 Aorus Elite	89	'28/10/2021':5C 'a520':2A 'aorus':3A 'elite':4A 'gigabyte':1A
281	2	\N	\N	\N	\N	\N	2021-10-28 19:05:27.541765	\N	Gigabyte A520 Aorus Elite	89	'28/10/2021':5C 'a520':2A 'aorus':3A 'elite':4A 'gigabyte':1A
282	0	\N	\N	\N	\N	\N	2021-10-28 19:06:24.821489	\N	Gigabyte A520 Aorus elite	90	'28/10/2021':5C 'a520':2A 'aorus':3A 'elite':4A 'gigabyte':1A
283	3	\N	\N	\N	\N	\N	2021-10-28 19:11:03.778156	\N	Sprzedaż dla James Smith w dniu i godzinie 2021-10-28 19:04 	5	'-10':10A '-28':11A '04':13A '19':12A '2021':9A '28/10/2021':14C 'dla':2A 'dniu':6A 'godzinie':8A 'i':7A 'james':3A 'smith':4A 'sprzedaż':1A 'w':5A
284	3	\N	\N	\N	\N	\N	2021-10-28 19:18:07.090265	\N	Sprzedaż dla Wojciech Juliusz w dniu i godzinie 2021-10-28 19:11 	6	'-10':10A '-28':11A '11':13A '19':12A '2021':9A '28/10/2021':14C 'dla':2A 'dniu':6A 'godzinie':8A 'i':7A 'juliusz':4A 'sprzedaż':1A 'w':5A 'wojciech':3A
285	3	\N	\N	\N	\N	\N	2021-10-28 19:19:02.521896	\N	Sprzedaż dla Amadeusz Wajcheprzełóż w dniu i godzinie 2021-10-28 19:18 	7	'-10':10A '-28':11A '18':13A '19':12A '2021':9A '28/10/2021':14C 'amadeusz':3A 'dla':2A 'dniu':6A 'godzinie':8A 'i':7A 'sprzedaż':1A 'w':5A 'wajcheprzełóż':4A
286	1	\N	\N	\N	\N	\N	2021-10-28 19:20:04.426606	\N	\N	74	\N
287	3	\N	\N	\N	\N	\N	2021-10-28 19:22:13.935391	\N	Sprzedaż dla James Smith w dniu i godzinie 2021-10-28 19:20 	8	'-10':10A '-28':11A '19':12A '20':13A '2021':9A '28/10/2021':14C 'dla':2A 'dniu':6A 'godzinie':8A 'i':7A 'james':3A 'smith':4A 'sprzedaż':1A 'w':5A
288	5	\N	\N	\N	\N	\N	2021-10-28 19:28:33.909014	\N	Office Computer	27	'28/10/2021':3C 'computer':2A 'office':1A
289	7	\N	\N	\N	\N	\N	2021-10-28 19:31:01.441778	\N	Office Computer	27	'28/10/2021':3C 'computer':2A 'office':1A
290	5	\N	\N	\N	\N	\N	2021-10-28 19:35:35.434029	\N	Office Computer	28	'28/10/2021':3C 'computer':2A 'office':1A
291	7	\N	\N	\N	\N	\N	2021-10-28 19:37:17.547775	\N	Office Computer	28	'28/10/2021':3C 'computer':2A 'office':1A
292	5	\N	\N	\N	\N	\N	2021-10-28 19:40:12.629269	\N	Office Computer	29	'28/10/2021':3C 'computer':2A 'office':1A
293	7	\N	\N	\N	\N	\N	2021-10-28 19:41:13.241578	\N	Office Computer	29	'28/10/2021':3C 'computer':2A 'office':1A
294	5	\N	\N	\N	\N	\N	2021-10-28 19:44:28.798595	\N	Office computer	30	'28/10/2021':3C 'computer':2A 'office':1A
295	12	\N	\N	\N	\N	\N	2021-10-28 19:47:16.69585	\N	Adrian Smith	12	'28/10/2021':3C 'adrian':1A 'smith':2A
296	13	\N	\N	\N	\N	\N	2021-10-28 19:47:38.28007	\N	Adrian Smith	12	'28/10/2021':3C 'adrian':1A 'smith':2A
297	2	\N	\N	\N	\N	\N	2021-10-28 19:48:16.370843	\N	Adrian Smith	12	'28/10/2021':3C 'adrian':1A 'smith':2A
298	12	\N	\N	\N	\N	\N	2021-10-28 19:49:47.993257	\N	test	14	'28/10/2021':2C 'test':1A
299	2	\N	\N	\N	\N	\N	2021-10-28 19:50:03.022955	\N	test	14	'28/10/2021':2C 'test':1A
300	12	\N	\N	\N	\N	\N	2021-10-28 19:50:33.866913	\N	Adrian Smith	15	'28/10/2021':3C 'adrian':1A 'smith':2A
301	2	\N	\N	\N	\N	\N	2021-10-28 19:50:37.75048	\N	Adrian Smith	15	'28/10/2021':3C 'adrian':1A 'smith':2A
302	12	\N	\N	\N	\N	\N	2021-10-28 19:51:04.211727	\N	Adrian Smith	16	'28/10/2021':3C 'adrian':1A 'smith':2A
303	13	\N	\N	\N	\N	\N	2021-10-28 19:51:23.985189	\N	Adrian Smith	16	'28/10/2021':3C 'adrian':1A 'smith':2A
304	15	\N	\N	\N	\N	\N	2021-10-28 19:53:21.621265	\N	BestSupply	10	'28/10/2021':2C 'bestsupply':1A
305	16	\N	\N	\N	\N	\N	2021-10-28 19:53:32.657065	\N	BestSupply	10	'28/10/2021':2C 'bestsupply':1A
306	8	\N	\N	\N	\N	\N	2021-10-28 19:57:40.322859	\N	There's something wrong with the power supply	21	'28/10/2021':9C 'power':7A 's':2A 'something':3A 'supply':8A 'the':6A 'there':1A 'with':5A 'wrong':4A
307	3	\N	\N	\N	\N	\N	2021-10-31 23:13:53.460813	\N	Sprzedaż dla Amelia Chorożny w dniu i godzinie 2021-10-31 23:10 	9	'-10':10A '-31':11A '10':13A '2021':9A '23':12A '31/10/2021':14C 'amelia':3A 'chorożny':4A 'dla':2A 'dniu':6A 'godzinie':8A 'i':7A 'sprzedaż':1A 'w':5A
308	3	\N	\N	\N	\N	\N	2021-10-31 23:14:17.373191	\N	Sprzedaż dla Adrian Smith w dniu i godzinie 2021-10-31 23:10 	11	'-10':10A '-31':11A '10':13A '2021':9A '23':12A '31/10/2021':14C 'adrian':3A 'dla':2A 'dniu':6A 'godzinie':8A 'i':7A 'smith':4A 'sprzedaż':1A 'w':5A
309	3	\N	\N	\N	\N	\N	2021-10-31 23:14:36.276862	\N	Sprzedaż dla Amadeusz Wajcheprzełóż w dniu i godzinie 2021-10-31 23:10 	12	'-10':10A '-31':11A '10':13A '2021':9A '23':12A '31/10/2021':14C 'amadeusz':3A 'dla':2A 'dniu':6A 'godzinie':8A 'i':7A 'sprzedaż':1A 'w':5A 'wajcheprzełóż':4A
310	3	\N	\N	\N	\N	\N	2021-10-31 23:15:26.843747	\N	Sprzedaż dla Marusz Nalepa w dniu i godzinie 2021-10-31 23:10 	13	'-10':10A '-31':11A '10':13A '2021':9A '23':12A '31/10/2021':14C 'dla':2A 'dniu':6A 'godzinie':8A 'i':7A 'marusz':3A 'nalepa':4A 'sprzedaż':1A 'w':5A
311	3	\N	\N	\N	\N	\N	2021-10-31 23:16:59.76125	\N	Sprzedaż dla Wojciech Juliusz w dniu i godzinie 2021-10-31 23:10 	14	'-10':10A '-31':11A '10':13A '2021':9A '23':12A '31/10/2021':14C 'dla':2A 'dniu':6A 'godzinie':8A 'i':7A 'juliusz':4A 'sprzedaż':1A 'w':5A 'wojciech':3A
312	3	\N	\N	\N	\N	\N	2021-10-31 23:17:27.340916	\N	Sprzedaż dla Adrian Smith w dniu i godzinie 2021-09-30 23:10 	15	'-09':10A '-30':11A '10':13A '2021':9A '23':12A '31/10/2021':14C 'adrian':3A 'dla':2A 'dniu':6A 'godzinie':8A 'i':7A 'smith':4A 'sprzedaż':1A 'w':5A
313	3	\N	\N	\N	\N	\N	2021-10-31 23:18:06.639304	\N	Sprzedaż dla Adrian Smith w dniu i godzinie 2021-08-28 23:10 	16	'-08':10A '-28':11A '10':13A '2021':9A '23':12A '31/10/2021':14C 'adrian':3A 'dla':2A 'dniu':6A 'godzinie':8A 'i':7A 'smith':4A 'sprzedaż':1A 'w':5A
314	5	\N	\N	\N	\N	\N	2021-12-01 21:12:24.696647	\N	ForGamersComputer	31	'01/12/2021':2C 'forgamerscomputer':1A
316	1	\N	\N	\N	\N	\N	2021-12-22 10:52:27.943402	\N	\N	83	\N
317	3	\N	\N	\N	\N	\N	2021-12-22 18:55:40.118985	\N	Sprzedaż dla Dariusz Palacz w dniu i godzinie 2021-12-22 18:54 	17	'-12':10A '-22':11A '18':12A '2021':9A '22/12/2021':14C '54':13A 'dariusz':3A 'dla':2A 'dniu':6A 'godzinie':8A 'i':7A 'palacz':4A 'sprzedaż':1A 'w':5A
318	7	\N	\N	\N	\N	\N	2021-12-22 20:44:36.986662	\N	kUdas00odplh61ou1-02	18	'-02':2A '22/12/2021':3C 'kudas00odplh61ou1':1A
319	7	\N	\N	\N	\N	\N	2021-12-22 20:45:53.212695	\N	kUltradr093100qdv9c6i1bs-02	15	'-02':2A '22/12/2021':3C 'kultradr093100qdv9c6i1bs':1A
320	5	\N	\N	\N	\N	\N	2021-12-22 20:46:37.318109	\N	kAMDAthl12462016mdibzvfm-22	32	'-22':2A '22/12/2021':3C 'kamdathl12462016mdibzvfm':1A
321	7	\N	\N	\N	\N	\N	2021-12-22 20:46:42.776688	\N	kAMDAthl12462016mdibzvfm-22	32	'-22':2A '22/12/2021':3C 'kamdathl12462016mdibzvfm':1A
322	9	\N	\N	\N	\N	\N	2021-12-22 21:50:51.274573	\N	Psuja	2	'22/12/2021':2C 'psuja':1A
323	9	\N	\N	\N	\N	\N	2021-12-22 21:51:00.756152	\N	Problem z PSU	13	'22/12/2021':4C 'problem':1A 'psu':3A 'z':2A
324	9	\N	\N	\N	\N	\N	2021-12-22 22:31:33.549708	\N	Tam się popsuł dysk najprawdopodobniej, nie mogę odtwarzać piosenek Franka Kimono	12	'22/12/2021':12C 'dysk':4A 'franka':10A 'kimono':11A 'mogę':7A 'najprawdopodobniej':5A 'nie':6A 'odtwarzać':8A 'piosenek':9A 'popsuł':3A 'się':2A 'tam':1A
325	9	\N	\N	\N	\N	\N	2021-12-22 22:33:14.000625	\N	Tam się popsuł dysk najprawdopodobniej, nie mogę odtwarzać piosenek Franka Kimono	12	'22/12/2021':12C 'dysk':4A 'franka':10A 'kimono':11A 'mogę':7A 'najprawdopodobniej':5A 'nie':6A 'odtwarzać':8A 'piosenek':9A 'popsuł':3A 'się':2A 'tam':1A
326	9	\N	\N	\N	\N	\N	2021-12-22 22:33:31.175869	\N	Tam się popsuł dysk najprawdopodobniej, nie mogę odtwarzać piosenek Franka Kimono	12	'22/12/2021':12C 'dysk':4A 'franka':10A 'kimono':11A 'mogę':7A 'najprawdopodobniej':5A 'nie':6A 'odtwarzać':8A 'piosenek':9A 'popsuł':3A 'się':2A 'tam':1A
327	9	\N	\N	\N	\N	\N	2021-12-22 22:39:01.680835	\N	Problem z wentylatorem	4	'22/12/2021':4C 'problem':1A 'wentylatorem':3A 'z':2A
328	9	\N	\N	\N	\N	\N	2021-12-22 22:39:05.685682	\N	Problem z wentylatorem	4	'22/12/2021':4C 'problem':1A 'wentylatorem':3A 'z':2A
329	9	\N	\N	\N	\N	\N	2021-12-22 22:39:12.451865	\N	Problem z PSU	13	'22/12/2021':4C 'problem':1A 'psu':3A 'z':2A
330	9	\N	\N	\N	\N	\N	2021-12-22 22:39:16.002219	\N	Problem z wentylatorem	4	'22/12/2021':4C 'problem':1A 'wentylatorem':3A 'z':2A
337	2	\N	\N	\N	\N	\N	2021-12-23 14:06:01.621237	\N	DASFafasd fsda	94	\N
342	13	\N	\N	\N	\N	\N	2021-12-23 14:12:07.142212	\N	Mariusz Kuchta	17	\N
347	0	\N	\N	\N	\N	\N	2021-12-23 21:17:09.35991	\N	Ramior 2137	96	\N
352	5	\N	\N	\N	\N	\N	2021-12-23 23:01:34.020989	\N	k	38	\N
357	5	\N	\N	\N	\N	\N	2021-12-23 23:12:49.697662	\N	proszę działaj	43	\N
362	7	\N	\N	\N	\N	\N	2021-12-23 23:20:40.257335	\N	kAMDRyze1206233zjlyeg2fw-23	41	\N
367	7	\N	\N	\N	\N	\N	2021-12-23 23:33:11.2437	\N	kAMDAthl120123ux8ez5v049-23	39	\N
377	17	\N	\N	\N	\N	\N	2021-12-23 23:39:11.03233	\N	punk's not dead	11	\N
384	1	\N	\N	\N	\N	\N	2021-12-24 04:19:02.492341	\N	\N	96	\N
385	1	\N	\N	\N	\N	\N	2021-12-24 04:19:08.296298	\N	\N	96	\N
392	3	\N	\N	\N	\N	\N	\N	\N	teststsase	\N	\N
397	3	\N	\N	\N	\N	\N	\N	\N	fasfsgdas	\N	\N
401	3	\N	\N	\N	\N	\N	2022-01-02 22:29:17.150637	\N	Sprzedaż dla Marusz Nalepa w dniu i godzinie 2022-01-02 22:29 	18	\N
406	3	\N	\N	\N	\N	\N	2022-01-02 22:56:40.413407	\N	Sprzedaż dla Amadeusz Wajcheprzełóż w dniu i godzinie 2022-01-02 22:56 	23	\N
415	3	\N	\N	\N	\N	\N	2022-01-04 20:52:05.054546	\N	Sprzedaż dla Amelia Chorożny w dniu i godzinie 2022-01-04 20:49 	26	\N
421	3	\N	\N	\N	\N	\N	2022-01-09 12:48:38.670504	\N	Sprzedaż dla James Smith w dniu i godzinie 2021-09-17 12:48 	33	\N
425	3	\N	\N	\N	\N	\N	2022-01-10 19:42:35.02062	\N	Sprzedaż dla Dariusz Palacz w dniu i godzinie 2022-01-10 19:42 	39	\N
\.


--
-- Data for Name: order_chunks; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.order_chunks (id, part_id, sell_price, quantity, belonging_order_id, computer_id) FROM stdin;
123	90	4520	1	31	\N
124	83	800	1	31	\N
125	84	680	1	31	\N
126	85	480	1	31	\N
127	83	800	1	32	\N
132	81	606	1	33	\N
133	82	800	1	33	\N
134	91	2550	17	35	\N
135	91	18	18	36	\N
136	91	5654	10	38	\N
137	85	14	1	39	\N
138	91	1800	8	40	\N
139	91	10	2	41	\N
140	91	250	9	42	\N
141	91	0	1	49	\N
114	91	1405	1	26	\N
\.


--
-- Data for Name: orders; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.orders (id, client_id, sell_date, name, document_with_weights) FROM stdin;
31	21	2022-01-09 12:35:00	Sprzedaż dla tescior w dniu i godzinie 2022-01-09 12:35 	\N
32	10	2022-01-09 12:48:00	Sprzedaż dla Marusz Nalepa w dniu i godzinie 2022-01-09 12:48 	\N
33	13	2021-09-17 12:48:00	Sprzedaż dla James Smith w dniu i godzinie 2021-09-17 12:48 	\N
35	6	2022-01-10 19:34:00	Sprzedaż dla Dariusz Palacz w dniu i godzinie 2022-01-10 19:34 	\N
36	16	2022-01-10 19:35:00	Sprzedaż dla Adrian Smith w dniu i godzinie 2022-01-10 19:35 	\N
38	6	2022-01-10 19:40:00	Sprzedaż dla Dariusz Palacz w dniu i godzinie 2022-01-10 19:40 	\N
39	6	2022-01-10 19:42:00	Sprzedaż dla Dariusz Palacz w dniu i godzinie 2022-01-10 19:42 	\N
40	16	2022-01-10 19:42:00	Sprzedaż dla Adrian Smith w dniu i godzinie 2022-01-10 19:42 	\N
12	8	2021-10-31 23:10:00	Sprzedaż dla Amadeusz Wajcheprzełóż w dniu i godzinie 2021-10-31 23:10 	'-10':10B '-31':11B '10':13B '2021':9B '23':12B 'amadeusz':3B 'dla':2B 'dniu':6B 'godzinie':8B 'i':7B 'sprzedaż':1B 'w':5B 'wajcheprzełóż':4B
41	10	2022-01-10 19:46:00	Sprzedaż dla Marusz Nalepa w dniu i godzinie 2022-01-10 19:46 	\N
42	1	2022-01-10 19:48:00	Sprzedaż dla John Black w dniu i godzinie 2022-01-10 19:48 	\N
49	1	2022-01-10 19:49:00	Sprzedaż dla John Black w dniu i godzinie 2022-01-10 19:49 	\N
21	10	2022-01-02 22:50:00	Sprzedaż dla Marusz Nalepa w dniu i godzinie 2022-01-02 22:50 	\N
26	5	2022-01-04 20:49:00	Sprzedaż dla Amelia Chorożny w dniu i godzinie 2022-01-04 20:49 	\N
27	11	2022-01-04 20:49:00	Sprzedaż dla Wojciech Juliusz w dniu i godzinie 2022-01-04 20:49 	\N
\.


--
-- Data for Name: parts; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.parts (id, name, stock, price, purchase_date, short_note, supplier_id, segment_id, document_with_weights) FROM stdin;
42	Gigabyte GeForce RTX 3060 EAGLE OC LHR 12GB GDDR6	23	3399.00	2021-08-20 04:06:00	Dobry produkt	1	2	'12gb':8A '20/08/2021':16 '3060':4A 'ab':12C 'dobry':10B 'eagle':5A 'gddr6':9A 'geforce':2A 'gigabyte':1A 'graficzne':15 'karty':14 'lhr':7A 'oc':6A 'polska':13C 'produkt':11B 'rtx':3A
24	APPLE A12 BIDONIC CHIP	40	760.00	2021-08-07 07:10:11	Nowy procek apple	1	1	'07/08/2021':11 'a12':2A 'ab':8C 'apple':1A,7B 'bidonic':3A 'chip':4A 'nowy':5B 'polska':9C 'procek':6B 'procesory':10
57	MSEKKO NVIDIA GTX 550 Ti Pci-e 2.0	25	421.00	2021-08-24 15:13:00	\N	1	2	'2.0':9A '24/08/2021':14 '550':4A 'ab':10C 'e':8A 'graficzne':13 'gtx':3A 'karty':12 'msekko':1A 'nvidia':2A 'pci':7A 'pci-e':6A 'polska':11C 'ti':5A
59	 ASUS GeForce GTX 1650 TUF OC - 4GB GDDR5 RAM	27	990.00	2021-08-24 13:14:00	\N	1	2	'1650':4A '24/08/2021':14 '4gb':7A 'ab':10C 'asus':1A 'gddr5':8A 'geforce':2A 'graficzne':13 'gtx':3A 'karty':12 'oc':6A 'polska':11C 'ram':9A 'tuf':5A
71	MSI GTX 970 Gaming 4GB	26	1229.00	2021-10-17 18:42:00	\N	3	2	'17/10/2021':10 '4gb':5A '970':3A 'delivery':7C 'gaming':4A 'graficzne':9 'gtx':2A 'karty':8 'kuki':6C 'msi':1A
53	AMD Radeon Pro W5500 8GB GDDR6	28	2419.00	2021-08-24 14:56:00	\N	1	2	'24/08/2021':11 '8gb':5A 'ab':7C 'amd':1A 'gddr6':6A 'graficzne':10 'karty':9 'polska':8C 'pro':3A 'radeon':2A 'w5500':4A
3	AMD Ryzen 7 3700X	53	1200.00	2021-06-14 00:23:04	\N	4	1	'14/06/2021':9 '3700x':4A '7':3A 'amd':1A 'kom':7C 'procesory':8 'ryzen':2A 'x':6C 'x-kom':5C
73	Gigabyte GeForce RTX 3070 VISION OC LHR 8GB GDDR6	28	4799.00	2021-10-24 13:58:00	\N	7	2	'24/10/2021':13 '3070':4A '8gb':8A 'gddr6':9A 'geforce':2A 'gieniek28':10C 'gigabyte':1A 'graficzne':12 'karty':11 'lhr':7A 'oc':6A 'rtx':3A 'vision':5A
62	Gigabyte GeForce GT 730 2GB DDR3	32	359.00	2021-08-24 18:20:00	\N	1	2	'24/08/2021':11 '2gb':5A '730':4A 'ab':7C 'ddr3':6A 'geforce':2A 'gigabyte':1A 'graficzne':10 'gt':3A 'karty':9 'polska':8C
90	Gigabyte A520 Aorus elite	23	349.00	2021-10-28 19:04:00	\N	3	2	'28/10/2021':9 'a520':2A 'aorus':3A 'delivery':6C 'elite':4A 'gigabyte':1A 'graficzne':8 'karty':7 'kuki':5C
74	AMD Radeon Pro W5700 8GB GDDR6	28	4349.00	2021-10-24 10:03:00	\N	3	2	'24/10/2021':11 '8gb':5A 'amd':1A 'delivery':8C 'gddr6':6A 'graficzne':10 'karty':9 'kuki':7C 'pro':3A 'radeon':2A 'w5700':4A
49	Gigabyt 1240 px GAMING EDITION	65	1242.00	2021-08-24 03:13:00	Fajny ten	4	3	'1240':2A '24/08/2021':14 'edition':5A 'fajny':6B 'gaming':4A 'gigabyt':1A 'gl':12 'kom':10C 'plyty':11 'px':3A 'ten':7B 'wne':13 'x':9C 'x-kom':8C
47	 3Dfx Voodoo 2 (BMG312) 12 MB EDO RAM PCI 	29	130.00	2021-08-19 02:42:00	Notatka fajna	3	2	'12':5A '19/08/2021':16 '2':3A '3dfx':1A 'bmg312':4A 'delivery':13C 'edo':7A 'fajna':11B 'graficzne':15 'karty':14 'kuki':12C 'mb':6A 'notatka':10B 'pci':9A 'ram':8A 'voodoo':2A
79	G.SKILL 16GB (2x8GB) 3200MHz CL16 Aegis	25	309.00	2021-10-27 15:08:00	\N	6	4	'16gb':2A '27/10/2021':10 '2x8gb':3A '3200mhz':4A 'aegis':6A 'cl16':5A 'g.skill':1A 'pl':8C 'proline':7C 'ram':9
66	Intel Core i9-9900KF, 3.6GHz, 16 MB, BOX	30	1544.34	2021-08-26 11:37:00	\N	1	1	'16':8A '26/08/2021':14 '3.6':6A '9900kf':5A 'ab':11C 'box':10A 'core':2A 'ghz':7A 'i9':4A 'i9-9900kf':3A 'intel':1A 'mb':9A 'polska':12C 'procesory':13
2	ASUS GeForce RTX 3060 Ti DUAL OC V2 LHR 8GB GDDR6	37	3899.00	2021-08-07 20:10:11	\N	6	3	'07/08/2021':17 '3060':4A '8gb':10A 'asus':1A 'dual':6A 'gddr6':11A 'geforce':2A 'gl':15 'lhr':9A 'oc':7A 'pl':13C 'plyty':14 'proline':12C 'rtx':3A 'ti':5A 'v2':8A 'wne':16
69	XFX RX 5500 XT Thicc II Pro 4 GB GDDR6	29	1876.00	2021-09-03 13:34:00	\N	3	2	'03/09/2021':15 '4':8A '5500':3A 'delivery':12C 'gb':9A 'gddr6':10A 'graficzne':14 'ii':6A 'karty':13 'kuki':11C 'pro':7A 'rx':2A 'thicc':5A 'xfx':1A 'xt':4A
77	Dell S2721DGFA nanoIPS HDR	29	1869.00	2021-10-27 15:08:00	\N	8	5	'27/10/2021':7 'dell':1A 'hdr':4A 'mariuszpol':5C 'monitor':6 'nanoips':3A 's2721dgfa':2A
7	NZXT Z370 Workload Mod	33	1000.00	2021-08-08 11:11:01	mudirbord fajny	1	3	'08/08/2021':12 'ab':7C 'fajny':6B 'gl':10 'mod':4A 'mudirbord':5B 'nzxt':1A 'plyty':9 'polska':8C 'wne':11 'workload':3A 'z370':2A
26	ZOTAC RTX 2060 TI DDR6 8GB Ray tracing4	41	2240.00	2021-08-02 18:10:11	\N	5	2	'02/08/2021':12 '2060':3A '8gb':6A 'ddr6':5A 'graficzne':11 'karty':10 'polhur':9C 'ray':7A 'rtx':2A 'ti':4A 'tracing4':8A 'zotac':1A
25	Qualcom Snapdragon 845	51	760.00	2021-08-07 18:10:11	\N	4	1	'07/08/2021':8 '845':3A 'kom':6C 'procesory':7 'qualcom':1A 'snapdragon':2A 'x':5C 'x-kom':4C
45	Gigabyte B450 AORUS PRO	31	449.00	2021-08-26 02:18:00	Duży fajny produkt	3	3	'26/08/2021':13 'aorus':3A 'b450':2A 'delivery':9C 'duży':5B 'fajny':6B 'gigabyte':1A 'gl':11 'kuki':8C 'plyty':10 'pro':4A 'produkt':7B 'wne':12
85	AMD Athlon 3000G	24	469.00	2021-10-27 15:37:00	\N	3	1	'27/10/2021':7 '3000g':3A 'amd':1A 'athlon':2A 'delivery':5C 'kuki':4C 'procesory':6
84	Acer Nitro QG241YBII czarny	23	599.00	2021-10-27 15:37:00	\N	8	5	'27/10/2021':7 'acer':1A 'czarny':4A 'mariuszpol':5C 'monitor':6 'nitro':2A 'qg241ybii':3A
51	Gigabyte B560M D3H	31	399.00	2021-08-24 00:04:00	\N	4	3	'24/08/2021':10 'b560m':2A 'd3h':3A 'gigabyte':1A 'gl':8 'kom':6C 'plyty':7 'wne':9 'x':5C 'x-kom':4C
50	MSI MPG Z490 GAMING PLUS	38	699.00	2021-08-24 01:39:00	\N	3	1	'24/08/2021':9 'delivery':7C 'gaming':4A 'kuki':6C 'mpg':2A 'msi':1A 'plus':5A 'procesory':8 'z490':3A
78	Acer SB241Y	27	549.00	2021-10-27 15:08:00	\N	3	5	'27/10/2021':6 'acer':1A 'delivery':4C 'kuki':3C 'monitor':5 'sb241y':2A
60	Gigabyte GeForce GT 730 2GB DDR3	39	479.00	2021-08-25 00:13:00	\N	1	2	'25/08/2021':11 '2gb':5A '730':4A 'ab':7C 'ddr3':6A 'geforce':2A 'gigabyte':1A 'graficzne':10 'gt':3A 'karty':9 'polska':8C
70	MSI MPG X570 Gaming Plus	28	823.90	2021-10-07 14:33:00	2321	3	3	'07/10/2021':12 '2321':6B 'delivery':8C 'gaming':4A 'gl':10 'kuki':7C 'mpg':2A 'msi':1A 'plus':5A 'plyty':9 'wne':11 'x570':3A
76	Crucial 16GB (2x8GB) 3200MHz CL16 Ballistix Black RGB	27	429.00	2021-10-27 13:08:00	\N	5	4	'16gb':2A '27/10/2021':11 '2x8gb':3A '3200mhz':4A 'ballistix':6A 'black':7A 'cl16':5A 'crucial':1A 'polhur':9C 'ram':10 'rgb':8A
10	APPLE A11 BIONIC CHIP	41	600.00	2021-07-08 10:11:01	FAST	6	1	'08/07/2021':9 'a11':2A 'apple':1A 'bionic':3A 'chip':4A 'fast':5B 'pl':7C 'procesory':8 'proline':6C
43	AMD Ryzen 3 1200 AF	27	399.00	2020-08-20 00:06:00	Dobry produkt	1	1	'1200':4A '20/08/2020':11 '3':3A 'ab':8C 'af':5A 'amd':1A 'dobry':6B 'polska':9C 'procesory':10 'produkt':7B 'ryzen':2A
75	MSI Radeon RX 6700 XT MECH 2X OC 12GB GDDR6	28	4499.00	2021-10-24 08:03:00	This one came in a fractured packaging	3	2	'12gb':9A '24/10/2021':22 '2x':7A '6700':4A 'a':15B 'came':13B 'delivery':19C 'fractured':16B 'gddr6':10A 'graficzne':21 'in':14B 'karty':20 'kuki':18C 'mech':6A 'msi':1A 'oc':8A 'one':12B 'packaging':17B 'radeon':2A 'rx':3A 'this':11B 'xt':5A
64	Intel i5-6500 3.20GHz 6MB BOX	30	1242.00	2021-08-26 11:19:00	\N	3	1	'-6500':3A '26/08/2021':11 '3.20':4A '6mb':6A 'box':7A 'delivery':9C 'ghz':5A 'i5':2A 'intel':1A 'kuki':8C 'procesory':10
61	Intel Core i5-10400F	37	699.00	2021-08-26 16:16:00	\N	4	1	'10400f':5A '26/08/2021':10 'core':2A 'i5':4A 'i5-10400f':3A 'intel':1A 'kom':8C 'procesory':9 'x':7C 'x-kom':6C
52	MSI Geforce RTX 2070 SUPER GAMING X 8GB GDDR6	28	2599.00	2021-08-24 14:56:00	\N	1	2	'2070':4A '24/08/2021':14 '8gb':8A 'ab':10C 'gaming':6A 'gddr6':9A 'geforce':2A 'graficzne':13 'karty':12 'msi':1A 'polska':11C 'rtx':3A 'super':5A 'x':7A
48	Intel Core i7-9800X	27	1649.00	2020-12-18 06:50:00	Fajny Procek generalnie	5	1	'18/12/2020':11 '9800x':5A 'core':2A 'fajny':6B 'generalnie':8B 'i7':4A 'i7-9800x':3A 'intel':1A 'polhur':9C 'procek':7B 'procesory':10
40	MSI GeForce RTX 3080 Ti GAMING X TRIO LHR 12GB GDDR6X	27	8999.00	2021-08-07 20:10:11	\N	1	2	'07/08/2021':16 '12gb':10A '3080':4A 'ab':12C 'gaming':6A 'gddr6x':11A 'geforce':2A 'graficzne':15 'karty':14 'lhr':9A 'msi':1A 'polska':13C 'rtx':3A 'ti':5A 'trio':8A 'x':7A
117	KRX BETA320 Ultra gamer	2	1521.00	2022-01-12 17:20:00	\N	5	2	\N
55	Gigabyte Radeon RX 5500 XT OC 4GB GDDR6	22	2199.00	2021-08-24 15:04:00	\N	3	2	'24/08/2021':13 '4gb':7A '5500':4A 'delivery':10C 'gddr6':8A 'gigabyte':1A 'graficzne':12 'karty':11 'kuki':9C 'oc':6A 'radeon':2A 'rx':3A 'xt':5A
119	Steat 3200MHZ 8GB	2	521.00	2022-01-12 17:22:00	\N	5	4	\N
46	MSI MAG Z590 TORPEDO	30	1099.00	2021-08-19 00:42:00	Notatka fajna2	5	3	'19/08/2021':11 'fajna2':6B 'gl':9 'mag':2A 'msi':1A 'notatka':5B 'plyty':8 'polhur':7C 'torpedo':4A 'wne':10 'z590':3A
56	Gigabyte Geforce GTX 750Ti OC 2GB DDR5	144	330.00	2021-08-24 13:10:00	\N	1	2	'24/08/2021':12 '2gb':6A '750ti':4A 'ab':8C 'ddr5':7A 'geforce':2A 'gigabyte':1A 'graficzne':11 'gtx':3A 'karty':10 'oc':5A 'polska':9C
83	Samsung Odyssey F24G35TFWUX	21	799.00	2021-10-27 11:37:00	\N	4	5	'27/10/2021':8 'f24g35tfwux':3A 'kom':6C 'monitor':7 'odyssey':2A 'samsung':1A 'x':5C 'x-kom':4C
81	Corsair 16GB(2x8GB) 3600MHz CL18 Vengeance RGB Pro	20	459.00	2021-10-27 15:37:00	\N	7	4	'16gb':2A '27/10/2021':11 '2x8gb':3A '3600mhz':4A 'cl18':5A 'corsair':1A 'gieniek28':9C 'pro':8A 'ram':10 'rgb':7A 'vengeance':6A
1	Intel Core i5-1155G7	125	2400.00	2021-06-14 00:15:05	no fajny procek	1	1	'1155g7':5A '14/06/2021':12 'ab':9C 'core':2A 'fajny':7B 'i5':4A 'i5-1155g7':3A 'intel':1A 'no':6B 'polska':10C 'procek':8B 'procesory':11
38	3DFX VOODOO4 4500 32MB PCI	80	2548.00	2021-08-07 20:10:11	\N	1	2	'07/08/2021':10 '32mb':4A '3dfx':1A '4500':3A 'ab':6C 'graficzne':9 'karty':8 'pci':5A 'polska':7C 'voodoo4':2A
44	AMD Ryzen 5 5600X	24	1449.00	2021-08-26 02:18:00	\N	1	1	'26/08/2021':8 '5':3A '5600x':4A 'ab':5C 'amd':1A 'polska':6C 'procesory':7 'ryzen':2A
82	Crucial 8GB (1x8GB) 2666MHz CL19	27	169.00	2021-10-27 15:49:00	\N	5	4	'1x8gb':3A '2666mhz':4A '27/10/2021':8 '8gb':2A 'cl19':5A 'crucial':1A 'polhur':6C 'ram':7
54	MSI Radeon RX 470 Gaming X 4GB GDDR5	30	929.00	2021-08-24 12:56:00	\N	3	2	'24/08/2021':13 '470':4A '4gb':7A 'delivery':10C 'gaming':5A 'gddr5':8A 'graficzne':12 'karty':11 'kuki':9C 'msi':1A 'radeon':2A 'rx':3A 'x':6A
5	Gigabyte GeForce RTX 3080 Ti GAMING OC 12GB GDDR6X 384bit	37	4600.00	2021-06-13 20:25:32	\N	3	2	'12gb':8A '13/06/2021':15 '3080':4A '384bit':10A 'delivery':12C 'gaming':6A 'gddr6x':9A 'geforce':2A 'gigabyte':1A 'graficzne':14 'karty':13 'kuki':11C 'oc':7A 'rtx':3A 'ti':5A
65	ASRock B460M PRO4	29	419.00	2021-08-26 15:22:00	\N	6	3	'26/08/2021':9 'asrock':1A 'b460m':2A 'gl':7 'pl':5C 'plyty':6 'pro4':3A 'proline':4C 'wne':8
58	Inno3D GeForce RTX 2060 Twin X2 6GB GDDR6	31	2799.00	2021-08-24 13:14:00	\N	1	2	'2060':4A '24/08/2021':13 '6gb':7A 'ab':9C 'gddr6':8A 'geforce':2A 'graficzne':12 'inno3d':1A 'karty':11 'polska':10C 'rtx':3A 'twin':5A 'x2':6A
72	 ASUS Tuf GeForce RTX 3080Ti Gaming LHR 12GB	26	8600.00	2021-10-24 13:58:00	\N	7	2	'12gb':8A '24/10/2021':12 '3080ti':5A 'asus':1A 'gaming':6A 'geforce':3A 'gieniek28':9C 'graficzne':11 'karty':10 'lhr':7A 'rtx':4A 'tuf':2A
80	Patriot 16GB (2x8GB) 3200MHz CL16 Viper Steel	29	379.00	2021-10-27 15:37:00	\N	8	4	'16gb':2A '27/10/2021':10 '2x8gb':3A '3200mhz':4A 'cl16':5A 'mariuszpol':8C 'patriot':1A 'ram':9 'steel':7A 'viper':6A
6	ASRock Z270 PRO GAMER	37	2600.00	2021-08-08 13:11:01	mudirbord fajny	5	3	'08/08/2021':11 'asrock':1A 'fajny':6B 'gamer':4A 'gl':9 'mudirbord':5B 'plyty':8 'polhur':7C 'pro':3A 'wne':10 'z270':2A
39	MSI GeForce GTX 1650 D6 Ventus XS OC 4GB GDDR6	29	1899.00	2021-08-07 20:10:11	\N	1	2	'07/08/2021':15 '1650':4A '4gb':9A 'ab':11C 'd6':5A 'gddr6':10A 'geforce':2A 'graficzne':14 'gtx':3A 'karty':13 'msi':1A 'oc':8A 'polska':12C 'ventus':6A 'xs':7A
41	MSI GeForce RTX 3070 SUPRIM X LHR 8GB GDDR6	29	4899.00	2021-08-07 20:10:11	\N	1	2	'07/08/2021':14 '3070':4A '8gb':8A 'ab':10C 'gddr6':9A 'geforce':2A 'graficzne':13 'karty':12 'lhr':7A 'msi':1A 'polska':11C 'rtx':3A 'suprim':5A 'x':6A
91	Dell P2720DD	3	1719.00	2021-12-23 11:35:00	Great colors!	1	5	'23/12/2021':8 'ab':5C 'colors':4B 'dell':1A 'great':3B 'monitor':7 'p2720dd':2A 'polska':6C
\.


--
-- Data for Name: problems; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.problems (id, computer_id, problem_note, hand_in_date, deadline_date, finished, document_with_weights) FROM stdin;
21	20	There's something wrong with the power supply	2021-10-27 19:56:00	2021-11-04 15:57:00	f	\N
2	5	Psuja	2021-08-07 18:10:11	2021-08-07 18:10:11	t	'07/08/2021':3B,4B '125fsaf':1A 'adf':2A
13	5	Problem z PSU	2021-08-07 16:10:11	2021-08-07 16:10:11	f	'07/08/2021':4B,5B 'ad':3A 'asfasf':1A 'asgeadg':2A
4	5	Problem z wentylatorem	2021-08-07 14:10:11	2021-08-07 14:10:11	f	'07/08/2021':3B,4B '125fsaf':1A 'adf':2A
12	5	Tam się popsuł dysk najprawdopodobniej, nie mogę odtwarzać piosenek Franka Kimono	2021-08-07 14:10:11	2021-08-07 14:10:11	f	'07/08/2021':4B,5B 'ad':3A 'asfasf':1A 'asgeadg':2A
3	5	125fsaf adf	2021-08-07 22:10:11	2021-08-07 22:10:11	t	'07/08/2021':3B,4B '125fsaf':1A 'adf':2A
22	5	Coś się popsuło	2021-12-23 22:46:00	\N	t	\N
20	21	Tam się płyta główna mogła skiepścić	2021-09-03 05:35:00	\N	f	'03/09/2021':7B 'główna':4A 'mogła':5A 'płyta':3A 'się':2A 'skiepścić':6A 'tam':1A
18	17	Nie no tam musiało coś paść	2021-09-03 15:32:00	\N	f	'03/09/2021':2B '4124':1A
14	5	Tets tego	2021-08-07 20:10:11	2021-08-07 20:10:11	f	'07/08/2021':4B,5B 'ad':3A 'asfasf':1A 'asgeadg':2A
16	22	Twój  się zepsuło, nie było mnie słychać	2021-08-07 20:10:11	2021-08-07 20:10:11	f	'07/08/2021':8B,9B 'było':5A 'mnie':6A 'nie':4A 'się':2A 'słychać':7A 'twój':1A 'zepsuło':3A
17	19	Zepsuł się na amen, chyba, płyta główna raczej	2021-08-07 18:10:11	2021-08-07 18:10:11	f	'07/08/2021':8B,9B 'było':5A 'mnie':6A 'nie':4A 'się':2A 'słychać':7A 'twój':1A 'zepsuło':3A
\.


--
-- Data for Name: segments; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.segments (id, name) FROM stdin;
1	procesory
2	karty graficzne
3	plyty gl¢wne
4	RAM
5	Monitor
\.


--
-- Data for Name: suppliers; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.suppliers (id, name, join_date, website, email, phone, adress, nip, short_note, document_with_weights) FROM stdin;
10	BestSupply	2021-10-28 15:50:00	www.bestsupply.com	\N	\N	ul. Beksińskiego 26, Warszawa	\N	He's got some good prices	\N
13	KFD	2022-01-12 17:17:00	\N	\N	\N	\N	\N	\N	\N
3	Kuki Delivery	2021-06-14 00:20:26	\N	kuki@oboz.pl	666124623	\N	\N	\N	'14/06/2021':5 '666124623':3C 'delivery':2A 'kuki':1A 'kuki@oboz.pl':4B
7	Gieniek28	2021-08-25 17:20:00	https://strona.agency	421@gasd.dfds	48231421424	\N	5315353412	\N	'25/08/2021':6 '421@gasd.dfds':3B '48231421424':2C '5315353412':5B 'gieniek28':1A 'strona.agency':4B
1	AB Polska	2021-06-13 22:10:18	ww.strona.agency	ab@polska.pl	603088160	\N	\N	\N	'13/06/2021':6 '603088160':3C 'ab':1A 'ab@polska.pl':4B 'polska':2A 'ww.strona.agency':5B
6	Proline pl	2020-06-02 12:10:11	http://proline.pl	hello@proline.pl	48605124122	Katowice Katowicka	2241241224	\N	'02/06/2020':9 '2241241224':6B '48605124122':3C 'hello@proline.pl':4B 'katowice':7C 'katowicka':8C 'pl':2A 'proline':1A 'proline.pl':5B
5	PolHur	2021-08-08 10:39:34	polhurt.pl	czesc@polhurt.pl	48603099160	ul magnoliowa 13	1251532542	fajna firma	'08/08/2021':11 '1251532542':7B '13':10C '48603099160':4C 'czesc@polhurt.pl':5B 'fajna':2C 'firma':3C 'magnoliowa':9C 'polhur':1A 'polhurt.pl':6B 'ul':8C
8	MariuszPol	2021-08-26 12:43:00	https://strona.agency	maniuchta3@gmail.com	48609420123	ul. Rudna 20	6124214215	Dobra, fajna hurtownia	'20':11C '26/08/2021':12 '48609420123':5C '6124214215':8B 'dobra':2C 'fajna':3C 'hurtownia':4C 'maniuchta3@gmail.com':6B 'mariuszpol':1A 'rudna':10C 'strona.agency':7B 'ul':9C
4	X-Kom	2021-06-13 20:21:15	xkom.pl	\N	\N	\N	\N	\N	'13/06/2021':5 'kom':3A 'x':2A 'x-kom':1A 'xkom.pl':4B
\.


--
-- Data for Name: temp_computer_table; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.temp_computer_table (computer_id, computer_name, processor_name, motherboard_name, graphics_card_name, computer_value, short_note, assembled_at) FROM stdin;
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.users (id, email, password, username) FROM stdin;
7	maniuchta3@gmail.com	$2b$10$UkugGsmRTTCulASiwdkDPeqCy.ySPnopdKf5Fvu6MYimOzpOhV0AW	mariusz
\.


--
-- Name: actionTypes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."actionTypes_id_seq"', 1, true);


--
-- Name: clients_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.clients_id_seq', 21, true);


--
-- Name: computer_pieces_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.computer_pieces_id_seq', 139, true);


--
-- Name: computers_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.computers_id_seq', 45, true);


--
-- Name: history_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.history_id_seq', 432, true);


--
-- Name: orderChunk_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."orderChunk_id_seq"', 141, true);


--
-- Name: orders_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.orders_id_seq', 49, true);


--
-- Name: parts_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.parts_id_seq', 119, true);


--
-- Name: problems_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.problems_id_seq', 22, true);


--
-- Name: segments_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.segments_id_seq', 3, true);


--
-- Name: suppliers_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.suppliers_id_seq', 13, true);


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

