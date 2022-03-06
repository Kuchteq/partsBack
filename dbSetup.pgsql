--
-- PostgreSQL database dump
--

-- Dumped from database version 14.1 (Ubuntu 14.1-1.pgdg21.04+1)
-- Dumped by pg_dump version 14.1 (Ubuntu 14.1-2.pgdg20.04+1)

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

                SELECT SUM(parts.price*computer_pieces.quantity) computer_price into computer_price FROM computer_pieces JOIN parts on parts.id = computer_pieces.part_id WHERE computer_pieces.belonging_computer_id = temprow.id;

                INSERT INTO temp_computer_table VALUES (temprow.id, temprow.name, processor_name, motherboard_name, graphics_card_name, computer_price, temprow.short_note, temprow.assembled_at, 0);
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

                SELECT SUM(parts.price*computer_pieces.quantity) computer_price into computer_price FROM computer_pieces JOIN parts on parts.id = computer_pieces.part_id WHERE computer_pieces.belonging_computer_id = temprow.id;
                SELECT DISTINCT ON (temprow.id) order_chunks.belonging_order_id into in_order FROM order_chunks WHERE order_chunks.computer_id = temprow.id;                
                INSERT INTO temp_computer_table VALUES (temprow.id, temprow.name, processor_name,  motherboard_name,graphics_card_name, computer_price, temprow.short_note, temprow.assembled_at, in_order);
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
-- Name: sum_func(double precision, anyelement, double precision); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.sum_func(double precision, anyelement, double precision) RETURNS double precision
    LANGUAGE sql
    AS $_$
SELECT case when $3 is not null then COALESCE($1, 0) + $3 else $1 end
$_$;


ALTER FUNCTION public.sum_func(double precision, anyelement, double precision) OWNER TO postgres;

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

--
-- Name: dist_sum("any", double precision); Type: AGGREGATE; Schema: public; Owner: postgres
--

CREATE AGGREGATE public.dist_sum("any", double precision) (
    SFUNC = public.sum_func,
    STYPE = double precision
);


ALTER AGGREGATE public.dist_sum("any", double precision) OWNER TO postgres;

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
    sell_price numeric(18,2) NOT NULL,
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
0	Added part	'ad':1A 'part':2A
1	Modified part	'modifi':1A 'part':2A
2	Deleted part	'delet':1A 'part':2A
3	Added order	'ad':1A 'order':2A
4	Deleted order	'delet':1A 'order':2A
5	Assembled computer	'assembl':1A 'comput':2A
6	Modified computer	'comput':2A 'modifi':1A
7	Dismantled computer	'comput':2A 'dismantl':1A
8	Added problem	'ad':1A 'problem':2A
9	Modified problem	'modifi':1A 'problem':2A
10	Resolved problem	'problem':2A 'resolv':1A
11	Deleted problem	'delet':1A 'problem':2A
12	Added client	'ad':1A 'client':2A
13	Modified client	'client':2A 'modifi':1A
14	Deleted client	'client':2A 'delet':1A
15	Added supplier	'ad':1A 'supplier':2A
16	Modified supplier	'modifi':1A 'supplier':2A
17	Deleted supplier	'delet':1A 'supplier':2A
\.


--
-- Data for Name: clients; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.clients (id, name, join_date, phone, email, adress, nip, short_note, document_with_weights) FROM stdin;
1	Ozzy Osbourne	2022-03-04 23:01:00	48602412641	\N	\N	\N	\N	'04/03/2022':4 '48602412641':3B 'osbourn':2A 'ozzi':1A
4	Mordo Muzik	2022-03-04 23:01:00	48603412464	\N	\N	\N	\N	'04/03/2022':4 '48603412464':3B 'mordo':1A 'muzik':2A
3	Michael Jackson	2022-03-01 08:01:00	\N	\N	\N	\N	The guy can heal the world	'01/03/2022':9 'guy':4B 'heal':6B 'jackson':2A 'michael':1A 'world':8B
5	Mac Quayle	2022-03-01 05:01:00	\N	macquayle@robot.com	\N	\N	\N	'01/03/2022':4 'mac':1A 'macquayle@robot.com':3B 'quayl':2A
6	Jeff Beck	2022-03-04 23:01:00	44421451314	\N	\N	\N	\N	'04/03/2022':4 '44421451314':3B 'beck':2A 'jeff':1A
7	Franek Kimono	2022-03-04 23:01:00	\N	karatemistrz@franek.pl	\N	\N	\N	'04/03/2022':4 'franek':1A 'karatemistrz@franek.pl':3B 'kimono':2A
10	Frederic Chopin	2022-03-04 23:01:00	\N	\N	\N	\N	\N	'04/03/2022':3 'chopin':2A 'freder':1A
11	Kenny Loggins	2022-03-04 23:01:00	1503164123	\N	\N	\N	\N	'04/03/2022':4 '1503164123':3B 'kenni':1A 'loggin':2A
12	Frank Zappa	2022-02-18 19:01:00	\N	contact@muffinman.com	\N	\N	\N	'18/02/2022':4 'contact@muffinman.com':3B 'frank':1A 'zappa':2A
9	Ritchie Blackmore	2022-02-16 23:01:00	\N	ritchie@blackmore.com	Rainbow St.	\N	\N	'16/02/2022':6 'blackmor':2A 'rainbow':4C 'ritchi':1A 'ritchie@blackmore.com':3B 'st':5C
8	Hulk Hogan	2022-02-20 13:01:00	\N	hogan@hulkhogan.com	\N	\N	A real American!	'20/02/2022':7 'american':5B 'hogan':2A 'hogan@hulkhogan.com':6B 'hulk':1A 'real':4B
13	David Bowie	2022-02-17 13:01:00	\N	bowie@david.com	\N	\N	\N	'17/02/2022':4 'bowi':2A 'bowie@david.com':3B 'david':1A
14	Judas Priest	2022-03-04 23:01:00	1602532153	\N	Love Bites St.	\N	\N	'04/03/2022':7 '1602532153':3B 'bite':5C 'juda':1A 'love':4C 'priest':2A 'st':6C
16	Motley Crue	2022-03-04 23:01:00	1745532132	\N	Kickstart my Heart st.	\N	\N	'04/03/2022':8 '1745532132':3B 'crue':2A 'heart':6C 'kickstart':4C 'motley':1A 'st':7C
15	Agata Sp. Z.O.O	2022-01-23 23:01:00	\N	kontakt@agata.pl	\N	6340197476	\N	'23/01/2022':6 '6340197476':5B 'agata':1A 'kontakt@agata.pl':4B 'sp':2A 'z.o.o':3A
17	Oingo Boingo	2022-03-04 23:01:00	\N	oingo@boingo.com	\N	\N	\N	'04/03/2022':4 'boingo':2A 'oingo':1A 'oingo@boingo.com':3B
18	Uriah Heep	2022-03-04 23:01:00	\N	uriaheep@gmail.com	\N	\N	\N	'04/03/2022':4 'heep':2A 'uriah':1A 'uriaheep@gmail.com':3B
2	Mariusz Janewski	2022-03-02 23:01:00	48612054124	\N	\N	\N	\N	'02/03/2022':4 '48612054124':3B 'janewski':2A 'mariusz':1A
19	Robert Lewandowski	2022-03-04 23:01:00	48533235332	\N	\N	\N	\N	'04/03/2022':4 '48533235332':3B 'lewandowski':2A 'robert':1A
20	Iron Maiden	2022-03-04 23:01:00	\N	\N	Prisoner St.	5315315131	\N	'04/03/2022':6 '5315315131':3B 'iron':1A 'maiden':2A 'prison':4C 'st':5C
21	Pink Floyd	2022-01-09 23:01:00	1777123321	\N	\N	5421542552	\N	'09/01/2022':5 '1777123321':3B '5421542552':4B 'floyd':2A 'pink':1A
22	Mike Oldfield	2022-03-04 23:01:00	374513513514	mikeoldfield@gmail.com	\N	\N	\N	'04/03/2022':5 '374513513514':3B 'mike':1A 'mikeoldfield@gmail.com':4B 'oldfield':2A
23	Alex Kommt	2022-03-04 23:01:00	49771353112	\N	\N	\N	\N	'04/03/2022':4 '49771353112':3B 'alex':1A 'kommt':2A
24	The Bill	2022-03-04 23:01:00	\N	thebill@gmail.com	\N	\N	Historie prawdziwe	'04/03/2022':6 'bill':2A 'histori':3B 'prawdziw':4B 'thebill@gmail.com':5B
25	Joe Satriani	2022-03-04 23:01:00	42642462463	\N	\N	\N	The Guy's surfing with the Alien	'04/03/2022':11 '42642462463':10B 'alien':9B 'guy':4B 'joe':1A 'satriani':2A 'surf':6B
26	John Lennon	2022-03-04 23:01:00	\N	johnlennon@gmail.com	\N	6234623623	\N	'04/03/2022':5 '6234623623':4B 'john':1A 'johnlennon@gmail.com':3B 'lennon':2A
27	Billy Joel	2022-03-04 23:01:00	\N	billy@joelbilly.com	\N	\N	He didn't start the fire at the company!	'04/03/2022':13 'billi':1A 'billy@joelbilly.com':12B 'compani':11B 'didn':4B 'fire':8B 'joel':2A 'start':6B
28	Tadeusz Wozniak	2021-12-26 16:01:00	48603099124	\N	\N	\N	\N	'26/12/2021':4 '48603099124':3B 'tadeusz':1A 'wozniak':2A
29	Sonic Youth	2022-03-04 23:01:00	\N	\N	Tenn Age Riot St. US	\N	\N	'04/03/2022':8 'age':4C 'riot':5C 'sonic':1A 'st':6C 'tenn':3C 'us':7C 'youth':2A
30	Fugazi	2022-03-04 23:01:00	\N	fugazi@gmail.com	\N	\N	Made him wait in the room	'04/03/2022':9 'fugazi':1A 'fugazi@gmail.com':8B 'made':2B 'room':7B 'wait':4B
31	Peter Schilling	2022-03-04 23:01:00	\N	peter@fehlerimsystem.ge	Major Tom St.	\N	\N	'04/03/2022':7 'major':4C 'peter':1A 'peter@fehlerimsystem.ge':3B 'schill':2A 'st':6C 'tom':5C
32	Billy Idol	2021-11-13 16:01:00	1701225324	\N	\N	\N	\N	'13/11/2021':4 '1701225324':3B 'billi':1A 'idol':2A
33	Gary Moore	2022-03-04 23:01:00	\N	\N	Loner St.	\N	\N	'04/03/2022':5 'gari':1A 'loner':3C 'moor':2A 'st':4C
34	Van Halen	2021-11-27 03:01:00	\N	vanhalen@gmail.com	Panama	6436346346	\N	'27/11/2021':6 '6436346346':4B 'halen':2A 'panama':5C 'van':1A 'vanhalen@gmail.com':3B
36	Weather Report	2021-11-28 23:01:00	\N	\N	\N	6324563465	\N	'28/11/2021':4 '6324563465':3B 'report':2A 'weather':1A
35	Herbie Hancock	2021-08-21 23:01:00	42745742346	\N	\N	\N	\N	'21/08/2021':4 '42745742346':3B 'hancock':2A 'herbi':1A
37	Tina Turner	2022-03-04 23:01:00	49735512521	\N	\N	\N	\N	'04/03/2022':4 '49735512521':3B 'tina':1A 'turner':2A
39	Sinead O'Connor	2021-07-13 23:01:00	48673124124	\N	\N	\N	\N	'13/07/2021':5 '48673124124':4B 'connor':3A 'o':2A 'sinead':1A
38	Led Zeppelin	2021-04-08 23:01:00	\N	ledzeppelin@gmail.com	Kashmir St.	\N	\N	'08/04/2021':6 'kashmir':4C 'led':1A 'ledzeppelin@gmail.com':3B 'st':5C 'zeppelin':2A
41	Mariusz Timm	2022-03-05 06:37:00	48603088135	manseba@gmail.com	\N	\N	\N	'05/03/2022':5 '48603088135':3B 'manseba@gmail.com':4B 'mariusz':1A 'timm':2A
40	Emilka Love	2022-03-02 23:01:00	43665565250	emi@dumnymodrzew.pl	Wienna	\N	Greatest Client! Nothing compares to her	'02/03/2022':10 '43665565250':7B 'client':4B 'compar':6B 'emi@dumnymodrzew.pl':8B 'emilka':1A 'greatest':3B 'love':2A 'noth':5B 'wienna':9C
43	Robert Kubica	2022-03-05 22:59:00	\N	\N	\N	\N	Drajwer błyskawica	'05/03/2022':5 'błyskawica':4B 'drajwer':3B 'kubica':2A 'robert':1A
44	John Smith	2022-03-05 23:31:00	48603214202	johnsmith@gmail.com	\N	0135813213	\N	'0135813213':5B '05/03/2022':6 '48603214202':3B 'john':1A 'johnsmith@gmail.com':4B 'smith':2A
\.


--
-- Data for Name: computer_pieces; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.computer_pieces (id, part_id, belonging_computer_id, quantity) FROM stdin;
2	7	2	1
3	32	2	1
4	23	2	1
5	67	2	1
7	45	2	1
6	70	2	1
8	26	3	1
9	32	3	1
10	8	3	1
11	15	3	1
12	61	3	1
13	6	3	1
14	22	3	1
15	69	4	1
16	32	4	1
17	53	4	1
18	9	4	1
19	17	4	1
20	23	4	1
21	21	4	1
22	69	5	1
23	72	5	1
24	25	5	1
25	10	5	1
26	71	5	1
27	61	5	1
28	9	5	1
29	18	6	1
30	32	6	1
31	11	6	1
32	59	6	1
33	45	6	1
34	22	6	1
35	3	6	1
36	20	6	1
37	76	7	1
38	74	7	1
39	15	7	1
40	78	7	1
41	17	7	1
42	8	7	1
43	77	7	1
44	69	8	1
45	73	8	1
46	59	8	1
47	20	8	1
48	63	8	1
49	53	8	1
50	8	8	1
51	13	8	1
52	77	8	1
53	57	9	1
54	31	9	1
55	60	9	1
56	81	9	1
58	79	9	1
59	80	9	1
60	85	9	1
61	83	9	1
62	38	9	1
57	19	9	1
63	30	9	1
64	2	10	1
65	73	10	1
66	61	10	1
67	70	10	1
68	67	10	1
69	22	10	1
70	86	11	1
71	74	11	1
72	91	11	1
73	21	11	1
74	88	11	1
75	45	11	1
76	89	11	1
77	87	11	1
78	98	12	1
79	97	12	1
80	20	12	1
81	99	12	1
82	95	12	1
83	96	12	1
84	94	12	1
85	92	13	1
86	97	13	1
87	93	13	1
88	95	13	1
89	96	13	1
90	94	13	1
91	86	14	1
92	73	14	1
93	20	14	1
94	59	14	1
95	87	14	1
96	89	14	1
97	88	14	1
98	61	14	1
99	98	15	1
100	97	15	1
101	99	15	1
102	95	15	1
103	96	15	1
104	94	15	1
105	69	16	1
106	72	16	1
107	35	16	1
108	14	16	1
109	40	16	1
110	24	16	1
111	29	16	1
112	101	16	1
113	98	17	1
114	73	17	1
115	95	17	1
116	89	17	1
117	99	17	1
118	13	17	1
119	18	18	1
120	74	18	1
121	63	18	1
122	67	18	1
123	71	18	1
124	64	18	1
125	24	18	1
126	33	9	1
127	86	19	1
128	73	19	1
129	4	19	1
130	96	19	1
131	67	19	1
132	71	19	1
133	6	19	1
135	97	20	1
136	70	20	1
137	26	20	1
134	96	20	1
138	94	20	1
139	95	20	1
140	7	21	1
141	72	21	1
142	34	21	1
143	33	21	1
144	103	21	1
145	68	21	1
146	24	21	1
147	23	21	1
148	25	21	1
149	7	22	1
150	74	22	1
151	25	22	1
152	68	22	1
153	17	22	1
154	103	22	1
155	29	22	1
156	86	23	1
157	31	23	1
158	100	23	1
159	28	23	1
160	14	23	1
161	17	23	1
162	103	23	1
163	83	23	1
164	91	23	2
165	104	24	1
166	74	24	1
167	66	24	1
168	95	24	1
169	102	24	1
170	77	24	1
171	78	24	1
172	105	25	1
173	72	25	1
174	36	25	1
175	71	25	1
176	85	25	1
177	88	25	1
178	64	25	1
179	91	23	1
\.


--
-- Data for Name: computers; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.computers (id, name, assembled_at, short_note, document_with_weights) FROM stdin;
2	kIntelCoGigabyte033801xmkv5bd1lp-05	2022-03-05 01:38:00	\N	'-05':2A '05/03/2022':3C 'kintelcogigabyte033801xmkv5bd1lp':1A
3	kIntelCoGigabyte032603e32phh09wp-05	2022-03-05 03:26:00	\N	'-05':2A '05/03/2022':3C 'kintelcogigabyte032603e32phh09wp':1A
4	kIntelCoGigabyte034513umx6ijifgf-02	2022-03-01 14:04:00	\N	'-02':2A '01/03/2022':3C 'kintelcogigabyte034513umx6ijifgf':1A
5	kIntelCoGigabyte030104e77yohsw63h-05	2022-03-05 04:01:00	\N	'-05':2A '05/03/2022':3C 'kintelcogigabyte030104e77yohsw63h':1A
13	Budget Total	2022-02-09 09:47:00	\N	'09/02/2022':3C 'budget':1A 'total':2A
12	kProcesorASRockB034705zy9kc2dgzp-05	2022-03-03 08:47:00	\N	'-05':2A '03/03/2022':3C 'kprocesorasrockb034705zy9kc2dgzp':1A
11	kProcesorAsusPRI034705th627eop6e-05	2022-02-19 09:52:00	\N	'-05':2A '19/02/2022':3C 'kprocesorasuspri034705th627eop6e':1A
10	kIntelCoGigabyte034705guqvtg4zae-05	2022-02-18 09:51:00	\N	'-05':2A '18/02/2022':3C 'kintelcogigabyte034705guqvtg4zae':1A
6	kAMDRyzeMSIB560031704dnv7mcwh3v-05	2022-01-21 09:51:00	\N	'-05':2A '21/01/2022':3C 'kamdryzemsib560031704dnv7mcwh3v':1A
8	kIntelCoASRockB0346044usp0cdglqg-05	2022-01-29 09:52:00	\N	'-05':2A '29/01/2022':3C 'kintelcoasrockb0346044usp0cdglqg':1A
7	kIntelCoGigabyte032104w8ztxu2cgf-05	2022-02-09 17:53:00	\N	'-05':2A '09/02/2022':3C 'kintelcogigabyte032104w8ztxu2cgf':1A
14	kProcesorAsusPRI024709347eghigym-09	2022-02-09 09:47:00	\N	'-09':2A '09/02/2022':3C 'kprocesorasuspri024709347eghigym':1A
15	kProcesorASRockB014713qalfbvzr05-20	2022-01-20 13:47:00	\N	'-20':2A '20/01/2022':3C 'kprocesorasrockb014713qalfbvzr05':1A
16	Gaming Comp	2022-01-20 12:01:00	\N	'20/01/2022':3C 'comp':2A 'game':1A
17	kProcesorASRockB014713a1m7kinbms-20	2022-01-20 13:47:00	\N	'-20':2A '20/01/2022':3C 'kprocesorasrockb014713a1m7kinbms':1A
18	kAMDRyzeGigabyte014713v5qq3vjm7zk-20	2022-01-20 13:47:00	\N	'-20':2A '20/01/2022':3C 'kamdryzegigabyte014713v5qq3vjm7zk':1A
19	kAMDRyzeGigabyte014713i4jnnygqrr-20	2022-01-20 13:47:00	\N	'-20':2A '20/01/2022':3C 'kamdryzegigabyte014713i4jnnygqrr':1A
9	THE BEAST	2022-02-14 12:02:00	\N	'14/02/2022':3C 'beast':2A
20	CompTest	2022-03-05 12:03:00	\N	'05/03/2022':2C 'comptest':1A
21	Nothing compares to this PC	2022-03-05 09:38:00	Best for gaming, productivity and finishing your homework!	'05/03/2022':14C 'best':6B 'compar':2A 'finish':11B 'game':8B 'homework':13B 'noth':1A 'pc':5A 'product':9B
22	kIntelCoGigabyte12331695cg9726mw-17	2021-12-17 16:33:00	\N	'-17':2A '17/12/2021':3C 'kintelcogigabyte12331695cg9726mw':1A
24	kIntelCoGigabyte031122mohrcdq61mf-03	2022-03-03 22:11:00	\N	'-03':2A '03/03/2022':3C 'kintelcogigabyte031122mohrcdq61mf':1A
25	kIntelCoGigabyte0318029dhghkhnxg-02	2022-03-02 02:18:00	\N	'-02':2A '02/03/2022':3C 'kintelcogigabyte0318029dhghkhnxg':1A
23	kAMDRyzeGigabyte1233204oycrfjtetg-16	2021-12-16 12:12:00	\N	'-16':2A '16/12/2021':3C 'kamdryzegigabyte1233204oycrfjtetg':1A
\.


--
-- Data for Name: history; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.history (id, action_id, part_id, computer_id, problem_id, client_id, supplier_id, at_time, order_id, details, target_id, document_with_weights) FROM stdin;
1	15	\N	\N	\N	\N	\N	2022-03-04 21:59:50.453587	\N	Mariusz J Kuchta	1	'04/03/2022':4C 'j':2A 'kuchta':3A 'mariusz':1A
2	0	\N	\N	\N	\N	\N	2022-03-04 22:00:06.042354	\N	dsfg3	1	'04/03/2022':2C 'dsfg3':1A
3	5	\N	\N	\N	\N	\N	2022-03-04 22:00:14.954364	\N	kdsfg3035922y12k9nvzkf-04	1	'-04':2A '04/03/2022':3C 'kdsfg3035922y12k9nvzkf':1A
4	16	\N	\N	\N	\N	\N	2022-03-04 22:08:42.757832	\N	BNS	1	'04/03/2022':2C 'bns':1A
5	16	\N	\N	\N	\N	\N	2022-03-04 22:08:50.603226	\N	BNS	1	'04/03/2022':2C 'bns':1A
6	15	\N	\N	\N	\N	\N	2022-03-04 22:10:08.604257	\N	G.D. International Poland	2	'04/03/2022':4C 'g.d':1A 'intern':2A 'poland':3A
7	16	\N	\N	\N	\N	\N	2022-03-04 22:10:23.24901	\N	G.D. International Poland	2	'04/03/2022':4C 'g.d':1A 'intern':2A 'poland':3A
8	15	\N	\N	\N	\N	\N	2022-03-04 22:11:15.825938	\N	Micros 	3	'04/03/2022':2C 'micro':1A
9	15	\N	\N	\N	\N	\N	2022-03-04 22:12:22.82608	\N	Aptel	4	'04/03/2022':2C 'aptel':1A
10	15	\N	\N	\N	\N	\N	2022-03-04 22:14:10.796312	\N	AVT Electronic Shop	5	'04/03/2022':4C 'avt':1A 'electron':2A 'shop':3A
11	15	\N	\N	\N	\N	\N	2022-03-04 22:16:23.367585	\N	Kuki Delivery	6	'04/03/2022':3C 'deliveri':2A 'kuki':1A
12	15	\N	\N	\N	\N	\N	2022-03-04 22:17:18.317722	\N	Arctic Monkeys	7	'04/03/2022':3C 'arctic':1A 'monkey':2A
13	15	\N	\N	\N	\N	\N	2022-03-04 22:17:53.751862	\N	Botland	8	'04/03/2022':2C 'botland':1A
14	15	\N	\N	\N	\N	\N	2022-03-04 22:18:55.252085	\N	Nowy Elektronik	9	'04/03/2022':3C 'elektronik':2A 'nowi':1A
15	16	\N	\N	\N	\N	\N	2022-03-04 22:19:21.233206	\N	Botland	8	'04/03/2022':2C 'botland':1A
16	15	\N	\N	\N	\N	\N	2022-03-04 22:19:57.702021	\N	Meta	10	'04/03/2022':2C 'meta':1A
17	15	\N	\N	\N	\N	\N	2022-03-04 22:20:44.315159	\N	Bodex	11	'04/03/2022':2C 'bodex':1A
18	15	\N	\N	\N	\N	\N	2022-03-04 22:21:31.199692	\N	Elektroklik	12	'04/03/2022':2C 'elektroklik':1A
19	15	\N	\N	\N	\N	\N	2022-03-04 22:22:37.795907	\N	Gotel	13	'04/03/2022':2C 'gotel':1A
20	15	\N	\N	\N	\N	\N	2022-03-04 22:25:33.740055	\N	GTS SP. Z O.O.	14	'04/03/2022':5C 'gts':1A 'o.o':4A 'sp':2A 'z':3A
21	16	\N	\N	\N	\N	\N	2022-03-04 22:25:58.160398	\N	Kuki Delivery	6	'04/03/2022':3C 'deliveri':2A 'kuki':1A
22	16	\N	\N	\N	\N	\N	2022-03-04 22:26:19.679728	\N	Nowy Elektronik	9	'04/03/2022':3C 'elektronik':2A 'nowi':1A
23	15	\N	\N	\N	\N	\N	2022-03-04 22:29:25.477972	\N	AB Hurt	15	'04/03/2022':3C 'ab':1A 'hurt':2A
24	15	\N	\N	\N	\N	\N	2022-03-04 22:30:04.892166	\N	Action	16	'04/03/2022':2C 'action':1A
25	15	\N	\N	\N	\N	\N	2022-03-04 22:31:34.373359	\N	AVG Hurt	17	'04/03/2022':3C 'avg':1A 'hurt':2A
26	16	\N	\N	\N	\N	\N	2022-03-04 22:31:44.338461	\N	AVG Hurt	17	'04/03/2022':3C 'avg':1A 'hurt':2A
27	15	\N	\N	\N	\N	\N	2022-03-04 22:33:39.490455	\N	Toyota Supra Sales	18	'04/03/2022':4C 'sale':3A 'supra':2A 'toyota':1A
28	15	\N	\N	\N	\N	\N	2022-03-04 22:34:06.36792	\N	The Doors	19	'04/03/2022':3C 'door':2A
29	15	\N	\N	\N	\N	\N	2022-03-04 22:34:52.481181	\N	Deep Purple Hurt	20	'04/03/2022':4C 'deep':1A 'hurt':3A 'purpl':2A
30	15	\N	\N	\N	\N	\N	2022-03-04 22:35:43.390597	\N	Figo Fagot Sales	21	'04/03/2022':4C 'fagot':2A 'figo':1A 'sale':3A
31	15	\N	\N	\N	\N	\N	2022-03-04 22:36:43.741943	\N	MGMT	22	'04/03/2022':2C 'mgmt':1A
32	15	\N	\N	\N	\N	\N	2022-03-04 22:37:17.685502	\N	BGC Hurt	23	'04/03/2022':3C 'bgc':1A 'hurt':2A
33	16	\N	\N	\N	\N	\N	2022-03-04 22:37:25.46897	\N	MGMT	22	'04/03/2022':2C 'mgmt':1A
34	15	\N	\N	\N	\N	\N	2022-03-04 22:38:15.800981	\N	Ramones	24	'04/03/2022':2C 'ramon':1A
35	15	\N	\N	\N	\N	\N	2022-03-04 22:39:38.031209	\N	Alphaville	25	'04/03/2022':2C 'alphavill':1A
36	16	\N	\N	\N	\N	\N	2022-03-04 22:40:11.196209	\N	Deep Purple Hurt	20	'04/03/2022':4C 'deep':1A 'hurt':3A 'purpl':2A
37	15	\N	\N	\N	\N	\N	2022-03-04 22:40:45.947109	\N	Nightwish EURO/AGD	26	'04/03/2022':3C 'euro/agd':2A 'nightwish':1A
38	16	\N	\N	\N	\N	\N	2022-03-04 22:41:06.388374	\N	Nightwish EURO/AGD	26	'04/03/2022':3C 'euro/agd':2A 'nightwish':1A
39	16	\N	\N	\N	\N	\N	2022-03-04 22:41:32.514863	\N	Nightwish EURO/AGD	26	'04/03/2022':3C 'euro/agd':2A 'nightwish':1A
40	16	\N	\N	\N	\N	\N	2022-03-04 22:41:38.733484	\N	Nightwish EURO/AGD	26	'04/03/2022':3C 'euro/agd':2A 'nightwish':1A
41	16	\N	\N	\N	\N	\N	2022-03-04 22:42:17.814834	\N	Alphaville	25	'04/03/2022':2C 'alphavill':1A
42	16	\N	\N	\N	\N	\N	2022-03-04 22:42:37.29187	\N	Ramones	24	'04/03/2022':2C 'ramon':1A
43	16	\N	\N	\N	\N	\N	2022-03-04 22:42:45.957419	\N	BGC Hurt	23	'04/03/2022':3C 'bgc':1A 'hurt':2A
44	16	\N	\N	\N	\N	\N	2022-03-04 22:43:06.126877	\N	MGMT	22	'04/03/2022':2C 'mgmt':1A
45	16	\N	\N	\N	\N	\N	2022-03-04 22:43:24.715215	\N	Figo Fagot Sales	21	'04/03/2022':4C 'fagot':2A 'figo':1A 'sale':3A
46	16	\N	\N	\N	\N	\N	2022-03-04 22:43:40.154821	\N	Deep Purple Hurt	20	'04/03/2022':4C 'deep':1A 'hurt':3A 'purpl':2A
47	16	\N	\N	\N	\N	\N	2022-03-04 22:43:55.142943	\N	The Doors	19	'04/03/2022':3C 'door':2A
48	16	\N	\N	\N	\N	\N	2022-03-04 22:44:06.445696	\N	Toyota Supra Sales	18	'04/03/2022':4C 'sale':3A 'supra':2A 'toyota':1A
49	16	\N	\N	\N	\N	\N	2022-03-04 22:44:24.975503	\N	AVG Hurt	17	'04/03/2022':3C 'avg':1A 'hurt':2A
50	16	\N	\N	\N	\N	\N	2022-03-04 22:44:39.054276	\N	Action	16	'04/03/2022':2C 'action':1A
51	16	\N	\N	\N	\N	\N	2022-03-04 22:44:55.721356	\N	AB Hurt	15	'04/03/2022':3C 'ab':1A 'hurt':2A
52	16	\N	\N	\N	\N	\N	2022-03-04 22:45:20.398468	\N	GTS SP. Z O.O.	14	'04/03/2022':5C 'gts':1A 'o.o':4A 'sp':2A 'z':3A
53	16	\N	\N	\N	\N	\N	2022-03-04 22:45:38.558562	\N	Gotel	13	'04/03/2022':2C 'gotel':1A
54	16	\N	\N	\N	\N	\N	2022-03-04 22:45:51.678414	\N	Elektroklik	12	'04/03/2022':2C 'elektroklik':1A
55	16	\N	\N	\N	\N	\N	2022-03-04 22:46:12.073982	\N	Bodex	11	'04/03/2022':2C 'bodex':1A
56	16	\N	\N	\N	\N	\N	2022-03-04 22:46:25.521368	\N	Meta	10	'04/03/2022':2C 'meta':1A
57	16	\N	\N	\N	\N	\N	2022-03-04 22:46:27.585522	\N	Meta	10	'04/03/2022':2C 'meta':1A
58	16	\N	\N	\N	\N	\N	2022-03-04 22:46:46.092022	\N	Nowy Elektronik	9	'04/03/2022':3C 'elektronik':2A 'nowi':1A
59	16	\N	\N	\N	\N	\N	2022-03-04 22:47:00.099805	\N	Botland	8	'04/03/2022':2C 'botland':1A
60	16	\N	\N	\N	\N	\N	2022-03-04 22:47:12.638252	\N	Arctic Monkeys	7	'04/03/2022':3C 'arctic':1A 'monkey':2A
61	16	\N	\N	\N	\N	\N	2022-03-04 22:47:30.072512	\N	Kuki Delivery	6	'04/03/2022':3C 'deliveri':2A 'kuki':1A
62	16	\N	\N	\N	\N	\N	2022-03-04 22:47:43.06247	\N	AVT Electronic Shop	5	'04/03/2022':4C 'avt':1A 'electron':2A 'shop':3A
63	16	\N	\N	\N	\N	\N	2022-03-04 22:47:58.669243	\N	Aptel	4	'04/03/2022':2C 'aptel':1A
64	16	\N	\N	\N	\N	\N	2022-03-04 22:48:17.582416	\N	Micros 	3	'04/03/2022':2C 'micro':1A
65	12	\N	\N	\N	\N	\N	2022-03-04 22:49:44.537204	\N	Ozzy Osbourne	1	'04/03/2022':3C 'osbourn':2A 'ozzi':1A
66	12	\N	\N	\N	\N	\N	2022-03-04 22:50:16.917661	\N	Mariusz Janewski	2	'04/03/2022':3C 'janewski':2A 'mariusz':1A
67	12	\N	\N	\N	\N	\N	2022-03-04 22:51:39.113901	\N	Michael Jackson	3	'04/03/2022':3C 'jackson':2A 'michael':1A
68	12	\N	\N	\N	\N	\N	2022-03-04 22:51:53.739346	\N	Mordo Muzik	4	'04/03/2022':3C 'mordo':1A 'muzik':2A
69	13	\N	\N	\N	\N	\N	2022-03-04 22:52:01.920048	\N	Michael Jackson	3	'04/03/2022':3C 'jackson':2A 'michael':1A
70	12	\N	\N	\N	\N	\N	2022-03-04 22:52:33.967361	\N	Mac Quayle	5	'04/03/2022':3C 'mac':1A 'quayl':2A
71	12	\N	\N	\N	\N	\N	2022-03-04 22:52:53.830548	\N	Jeff Beck	6	'04/03/2022':3C 'beck':2A 'jeff':1A
72	12	\N	\N	\N	\N	\N	2022-03-04 22:53:08.543572	\N	Franek Kimono	7	'04/03/2022':3C 'franek':1A 'kimono':2A
73	12	\N	\N	\N	\N	\N	2022-03-04 22:53:29.260358	\N	Hulk Hogan	8	'04/03/2022':3C 'hogan':2A 'hulk':1A
74	12	\N	\N	\N	\N	\N	2022-03-04 22:53:56.119918	\N	Ritchie Blackmore	9	'04/03/2022':3C 'blackmor':2A 'ritchi':1A
75	12	\N	\N	\N	\N	\N	2022-03-04 22:54:28.770294	\N	Frederic Chopin	10	'04/03/2022':3C 'chopin':2A 'freder':1A
76	12	\N	\N	\N	\N	\N	2022-03-04 22:54:50.444399	\N	Kenny Loggins	11	'04/03/2022':3C 'kenni':1A 'loggin':2A
77	12	\N	\N	\N	\N	\N	2022-03-04 22:55:29.798215	\N	Frank Zappa	12	'04/03/2022':3C 'frank':1A 'zappa':2A
78	13	\N	\N	\N	\N	\N	2022-03-04 22:55:38.964979	\N	Ritchie Blackmore	9	'04/03/2022':3C 'blackmor':2A 'ritchi':1A
79	13	\N	\N	\N	\N	\N	2022-03-04 22:55:49.553307	\N	Hulk Hogan	8	'04/03/2022':3C 'hogan':2A 'hulk':1A
80	12	\N	\N	\N	\N	\N	2022-03-04 22:56:17.70409	\N	David Bowie	13	'04/03/2022':3C 'bowi':2A 'david':1A
81	12	\N	\N	\N	\N	\N	2022-03-04 22:57:07.219117	\N	Judas Priest	14	'04/03/2022':3C 'juda':1A 'priest':2A
82	12	\N	\N	\N	\N	\N	2022-03-04 22:57:37.826199	\N	Agata Sp. Z.O.O	15	'04/03/2022':4C 'agata':1A 'sp':2A 'z.o.o':3A
83	12	\N	\N	\N	\N	\N	2022-03-04 22:58:24.173817	\N	Motley Crue	16	'04/03/2022':3C 'crue':2A 'motley':1A
84	13	\N	\N	\N	\N	\N	2022-03-04 22:58:34.685904	\N	Agata Sp. Z.O.O	15	'04/03/2022':4C 'agata':1A 'sp':2A 'z.o.o':3A
85	12	\N	\N	\N	\N	\N	2022-03-04 22:59:02.441873	\N	Oingo Boingo	17	'04/03/2022':3C 'boingo':2A 'oingo':1A
86	12	\N	\N	\N	\N	\N	2022-03-04 22:59:27.90851	\N	Uriah Heep	18	'04/03/2022':3C 'heep':2A 'uriah':1A
87	13	\N	\N	\N	\N	\N	2022-03-04 22:59:48.377531	\N	Mariusz Janewski	2	'04/03/2022':3C 'janewski':2A 'mariusz':1A
88	12	\N	\N	\N	\N	\N	2022-03-04 23:00:03.245412	\N	Robert Lewandowski	19	'04/03/2022':3C 'lewandowski':2A 'robert':1A
89	12	\N	\N	\N	\N	\N	2022-03-04 23:00:25.483677	\N	Iron Maiden	20	'04/03/2022':3C 'iron':1A 'maiden':2A
90	12	\N	\N	\N	\N	\N	2022-03-04 23:01:11.807799	\N	Pink Floyd	21	'04/03/2022':3C 'floyd':2A 'pink':1A
91	12	\N	\N	\N	\N	\N	2022-03-04 23:01:37.654531	\N	Mike Oldfield	22	'04/03/2022':3C 'mike':1A 'oldfield':2A
92	12	\N	\N	\N	\N	\N	2022-03-04 23:02:40.41666	\N	Alex Kommt	23	'04/03/2022':3C 'alex':1A 'kommt':2A
93	12	\N	\N	\N	\N	\N	2022-03-04 23:03:37.888359	\N	The Bill	24	'04/03/2022':3C 'bill':2A
94	12	\N	\N	\N	\N	\N	2022-03-04 23:04:23.087844	\N	Joe Satriani	25	'04/03/2022':3C 'joe':1A 'satriani':2A
95	12	\N	\N	\N	\N	\N	2022-03-04 23:04:50.558039	\N	John Lennon	26	'04/03/2022':3C 'john':1A 'lennon':2A
96	12	\N	\N	\N	\N	\N	2022-03-04 23:05:22.014337	\N	Billy Joel	27	'04/03/2022':3C 'billi':1A 'joel':2A
97	12	\N	\N	\N	\N	\N	2022-03-04 23:05:57.456626	\N	Tadeusz Wozniak	28	'04/03/2022':3C 'tadeusz':1A 'wozniak':2A
98	12	\N	\N	\N	\N	\N	2022-03-04 23:06:19.285817	\N	Sonic Youth	29	'04/03/2022':3C 'sonic':1A 'youth':2A
99	12	\N	\N	\N	\N	\N	2022-03-04 23:06:38.992668	\N	Fugazi	30	'04/03/2022':2C 'fugazi':1A
100	12	\N	\N	\N	\N	\N	2022-03-04 23:07:18.226884	\N	Peter Schilling	31	'04/03/2022':3C 'peter':1A 'schill':2A
101	12	\N	\N	\N	\N	\N	2022-03-04 23:07:37.434774	\N	Billy Idol	32	'04/03/2022':3C 'billi':1A 'idol':2A
102	12	\N	\N	\N	\N	\N	2022-03-04 23:07:50.528404	\N	Gary Moore	33	'04/03/2022':3C 'gari':1A 'moor':2A
103	12	\N	\N	\N	\N	\N	2022-03-04 23:08:35.954263	\N	Van Halen	34	'04/03/2022':3C 'halen':2A 'van':1A
104	12	\N	\N	\N	\N	\N	2022-03-04 23:08:58.369877	\N	Herbie Hancock	35	'04/03/2022':3C 'hancock':2A 'herbi':1A
105	12	\N	\N	\N	\N	\N	2022-03-04 23:09:09.829321	\N	Weather Report	36	'04/03/2022':3C 'report':2A 'weather':1A
106	13	\N	\N	\N	\N	\N	2022-03-04 23:10:01.4145	\N	Weather Report	36	'04/03/2022':3C 'report':2A 'weather':1A
107	13	\N	\N	\N	\N	\N	2022-03-04 23:10:08.590362	\N	Herbie Hancock	35	'04/03/2022':3C 'hancock':2A 'herbi':1A
108	12	\N	\N	\N	\N	\N	2022-03-04 23:10:41.977494	\N	Tina Turner	37	'04/03/2022':3C 'tina':1A 'turner':2A
109	12	\N	\N	\N	\N	\N	2022-03-04 23:11:20.149099	\N	Led Zeppelin	38	'04/03/2022':3C 'led':1A 'zeppelin':2A
110	12	\N	\N	\N	\N	\N	2022-03-04 23:12:05.116215	\N	Sinead O'Connor	39	'04/03/2022':4C 'connor':3A 'o':2A 'sinead':1A
111	13	\N	\N	\N	\N	\N	2022-03-04 23:12:25.598573	\N	Led Zeppelin	38	'04/03/2022':3C 'led':1A 'zeppelin':2A
112	12	\N	\N	\N	\N	\N	2022-03-04 23:14:35.581834	\N	Emilka Love	40	'04/03/2022':3C 'emilka':1A 'love':2A
113	13	\N	\N	\N	\N	\N	2022-03-04 23:15:27.571934	\N	Emilka Love	40	'04/03/2022':3C 'emilka':1A 'love':2A
114	1	\N	\N	\N	\N	\N	2022-03-04 23:19:23.943749	\N	\N	1	\N
115	0	\N	\N	\N	\N	\N	2022-03-04 23:22:11.046962	\N	Intel Core i5‑11400F	2	'04/03/2022':5C '11400f':4A 'core':2A 'i5':3A 'intel':1A
116	0	\N	\N	\N	\N	\N	2022-03-04 23:22:42.74329	\N	MSI B560‑A PRO	3	'04/03/2022':5C 'b560':2A 'msi':1A 'pro':4A
117	0	\N	\N	\N	\N	\N	2022-03-04 23:23:28.629501	\N	KFA2 GeForce GTX 1660 Ti 1‑Click OC 6GB GDDR6	4	'04/03/2022':11C '1':6A '1660':4A '6gb':9A 'click':7A 'gddr6':10A 'geforc':2A 'gtx':3A 'kfa2':1A 'oc':8A 'ti':5A
118	0	\N	\N	\N	\N	\N	2022-03-04 23:24:13.609643	\N	ASUS Radeon RX 6600 Dual 8GB GDDR6	5	'04/03/2022':8C '6600':4A '8gb':6A 'asus':1A 'dual':5A 'gddr6':7A 'radeon':2A 'rx':3A
119	0	\N	\N	\N	\N	\N	2022-03-04 23:24:49.93186	\N	Gigabyte B560M DS3H V2	6	'04/03/2022':5C 'b560m':2A 'ds3h':3A 'gigabyt':1A 'v2':4A
120	0	\N	\N	\N	\N	\N	2022-03-04 23:25:53.543652	\N	Intel Core i7‑12700KF	7	'04/03/2022':5C '12700kf':4A 'core':2A 'i7':3A 'intel':1A
121	1	\N	\N	\N	\N	\N	2022-03-04 23:26:09.088098	\N	\N	7	\N
122	1	\N	\N	\N	\N	\N	2022-03-04 23:26:18.255528	\N	\N	6	\N
296	0	\N	\N	\N	\N	\N	2022-03-05 08:38:36.168251	\N	Gigabyte Z690 UD DDR4	103	'05/03/2022':5C 'ddr4':4A 'gigabyt':1A 'ud':3A 'z690':2A
123	0	\N	\N	\N	\N	\N	2022-03-04 23:27:08.184579	\N	Kingston FURY 16GB (2x8GB) 3200MHz CL16 Beast RGB	8	'04/03/2022':9C '16gb':3A '2x8gb':4A '3200mhz':5A 'beast':7A 'cl16':6A 'furi':2A 'kingston':1A 'rgb':8A
124	0	\N	\N	\N	\N	\N	2022-03-04 23:27:45.365589	\N	Crucial 16GB (2x8GB) 3600MHz CL16 Ballistix Black RGB	9	'04/03/2022':9C '16gb':2A '2x8gb':3A '3600mhz':4A 'ballistix':6A 'black':7A 'cl16':5A 'crucial':1A 'rgb':8A
125	0	\N	\N	\N	\N	\N	2022-03-04 23:28:45.702989	\N	Gigabyte Z590 AORUS MASTER	10	'04/03/2022':5C 'aorus':3A 'gigabyt':1A 'master':4A 'z590':2A
126	7	\N	\N	\N	\N	\N	2022-03-04 23:29:14.282078	\N	kdsfg3035922y12k9nvzkf-04	1	'-04':2A '04/03/2022':3C 'kdsfg3035922y12k9nvzkf':1A
127	0	\N	\N	\N	\N	\N	2022-03-04 23:31:07.933027	\N	Patriot 16GB (2x8GB) 3600MHz CL18 Viper Steel	11	'04/03/2022':8C '16gb':2A '2x8gb':3A '3600mhz':4A 'cl18':5A 'patriot':1A 'steel':7A 'viper':6A
128	0	\N	\N	\N	\N	\N	2022-03-04 23:32:36.241427	\N	Intel Celeron G5905	12	'04/03/2022':4C 'celeron':2A 'g5905':3A 'intel':1A
129	0	\N	\N	\N	\N	\N	2022-03-04 23:44:41.609472	\N	Crucial 500GB 2,5" SATA SSD MX500	13	'04/03/2022':8C '2':3A '5':4A '500gb':2A 'crucial':1A 'mx500':7A 'sata':5A 'ssd':6A
130	0	\N	\N	\N	\N	\N	2022-03-04 23:47:40.750011	\N	Kingston FURY 32GB (2x16GB) 3200MHz CL16 Renegade Black	14	'04/03/2022':9C '2x16gb':4A '3200mhz':5A '32gb':3A 'black':8A 'cl16':6A 'furi':2A 'kingston':1A 'renegad':7A
131	1	\N	\N	\N	\N	\N	2022-03-04 23:47:51.733946	\N	\N	14	\N
132	0	\N	\N	\N	\N	\N	2022-03-04 23:48:28.762914	\N	Gigabyte GeForce GTX 1050 Ti 4GB GDDR5	15	'04/03/2022':8C '1050':4A '4gb':6A 'gddr5':7A 'geforc':2A 'gigabyt':1A 'gtx':3A 'ti':5A
133	0	\N	\N	\N	\N	\N	2022-03-04 23:49:36.61336	\N	ASUS TUF GAMING Z590‑PLUS	16	'04/03/2022':6C 'asus':1A 'game':3A 'plus':5A 'tuf':2A 'z590':4A
134	0	\N	\N	\N	\N	\N	2022-03-04 23:50:23.207916	\N	Samsung 1TB M.2 PCIe NVMe 970 EVO Plus	17	'04/03/2022':9C '1tb':2A '970':6A 'evo':7A 'm.2':3A 'nvme':5A 'pcie':4A 'plus':8A 'samsung':1A
135	0	\N	\N	\N	\N	\N	2022-03-04 23:51:10.730485	\N	AMD Ryzen 5 Pro 4650G OEM	18	'04/03/2022':7C '4650g':5A '5':3A 'amd':1A 'oem':6A 'pro':4A 'ryzen':2A
136	0	\N	\N	\N	\N	\N	2022-03-04 23:52:01.147256	\N	Seagate BARRACUDA 2TB 7200rot. 256MB	19	'04/03/2022':6C '256mb':5A '2tb':3A '7200rot':4A 'barracuda':2A 'seagat':1A
137	0	\N	\N	\N	\N	\N	2022-03-04 23:52:44.33653	\N	Toshiba P300 1TB 7200rot. 64MB OEM	20	'04/03/2022':7C '1tb':3A '64mb':5A '7200rot':4A 'oem':6A 'p300':2A 'toshiba':1A
138	0	\N	\N	\N	\N	\N	2022-03-04 23:54:18.525709	\N	KFA2 GeForce RTX 2060 SUPER 1‑Click OC 8GB GDDR6	21	'04/03/2022':11C '1':6A '2060':4A '8gb':9A 'click':7A 'gddr6':10A 'geforc':2A 'kfa2':1A 'oc':8A 'rtx':3A 'super':5A
139	1	\N	\N	\N	\N	\N	2022-03-04 23:54:26.223285	\N	\N	21	\N
140	0	\N	\N	\N	\N	\N	2022-03-04 23:55:31.845631	\N	SilentiumPC Vero L3 700W 80 Plus Bronze	22	'04/03/2022':8C '700w':4A '80':5A 'bronz':7A 'l3':3A 'plus':6A 'silentiumpc':1A 'vero':2A
141	0	\N	\N	\N	\N	\N	2022-03-04 23:55:59.14913	\N	EVGA SuperNOVA GA 750W 80 Plus Gold	23	'04/03/2022':8C '750w':4A '80':5A 'evga':1A 'ga':3A 'gold':7A 'plus':6A 'supernova':2A
142	0	\N	\N	\N	\N	\N	2022-03-04 23:56:38.512009	\N	Crucial 1TB M.2 PCIe Gen4 NVMe P5 Plus	24	'04/03/2022':9C '1tb':2A 'crucial':1A 'gen4':5A 'm.2':3A 'nvme':6A 'p5':7A 'pcie':4A 'plus':8A
143	0	\N	\N	\N	\N	\N	2022-03-04 23:57:07.8951	\N	Gigabyte GeForce RTX 3060 AORUS ELITE LHR 12GB GDDR6	25	'04/03/2022':10C '12gb':8A '3060':4A 'aorus':5A 'elit':6A 'gddr6':9A 'geforc':2A 'gigabyt':1A 'lhr':7A 'rtx':3A
144	0	\N	\N	\N	\N	\N	2022-03-04 23:58:56.098383	\N	Intel Core i3‑10320	26	'04/03/2022':5C '10320':4A 'core':2A 'i3':3A 'intel':1A
145	0	\N	\N	\N	\N	\N	2022-03-04 23:59:51.323606	\N	SilentiumPC Fera 5 120mm	27	'04/03/2022':5C '120mm':4A '5':3A 'fera':2A 'silentiumpc':1A
146	0	\N	\N	\N	\N	\N	2022-03-05 00:00:25.239338	\N	be quiet! Dark Rock Pro 4 120/135mm	28	'05/03/2022':8C '120/135mm':7A '4':6A 'dark':3A 'pro':5A 'quiet':2A 'rock':4A
147	0	\N	\N	\N	\N	\N	2022-03-05 00:00:51.268296	\N	ASUS ROG Strix 750W 80 Plus Gold	29	'05/03/2022':8C '750w':4A '80':5A 'asus':1A 'gold':7A 'plus':6A 'rog':2A 'strix':3A
148	0	\N	\N	\N	\N	\N	2022-03-05 00:01:36.776043	\N	Creative Sound Blaster X AE‑5 Plus (PCI‑E)	30	'05/03/2022':10C '5':6A 'ae':5A 'blaster':3A 'creativ':1A 'e':9A 'pci':8A 'plus':7A 'sound':2A 'x':4A
149	0	\N	\N	\N	\N	\N	2022-03-05 00:02:33.93171	\N	Corsair iCUE 5000T RGB Tempered Glass Black	31	'05/03/2022':8C '5000t':3A 'black':7A 'corsair':1A 'glass':6A 'icu':2A 'rgb':4A 'temper':5A
150	0	\N	\N	\N	\N	\N	2022-03-05 00:03:07.577907	\N	be quiet! Pure Base 500DX Black	32	'05/03/2022':7C '500dx':5A 'base':4A 'black':6A 'pure':3A 'quiet':2A
151	0	\N	\N	\N	\N	\N	2022-03-05 00:03:38.329459	\N	MSI MAG Core Liquid 280R 2x140mm	33	'05/03/2022':7C '280r':5A '2x140mm':6A 'core':3A 'liquid':4A 'mag':2A 'msi':1A
152	0	\N	\N	\N	\N	\N	2022-03-05 00:04:07.330334	\N	Creative Sound BlasterX G5	34	'05/03/2022':5C 'blasterx':3A 'creativ':1A 'g5':4A 'sound':2A
153	0	\N	\N	\N	\N	\N	2022-03-05 00:05:25.137879	\N	Dell S2721DGFA nanoIPS HDR	35	'05/03/2022':5C 'dell':1A 'hdr':4A 'nanoip':3A 's2721dgfa':2A
154	0	\N	\N	\N	\N	\N	2022-03-05 00:07:19.581745	\N	LG Ultragear 27GP850 NanoIPS HDR	36	'05/03/2022':6C '27gp850':3A 'hdr':5A 'lg':1A 'nanoip':4A 'ultragear':2A
155	0	\N	\N	\N	\N	\N	2022-03-05 00:08:20.845858	\N	TP‑Link Archer T4U (1300Mb/s a/b/g/n/ac) DualBand	37	'05/03/2022':8C '1300mb/s':5A 'a/b/g/n/ac':6A 'archer':3A 'dualband':7A 'link':2A 't4u':4A 'tp':1A
156	0	\N	\N	\N	\N	\N	2022-03-05 00:08:52.849951	\N	ASUS PCE‑AX58BT (3000Mb/s a/b/g/n/ax) BT 5.0	38	'05/03/2022':8C '3000mb/s':4A '5.0':7A 'a/b/g/n/ax':5A 'asus':1A 'ax58bt':3A 'bt':6A 'pce':2A
157	0	\N	\N	\N	\N	\N	2022-03-05 00:09:34.38245	\N	Intel Core i9‑10980XE	39	'05/03/2022':5C '10980xe':4A 'core':2A 'i9':3A 'intel':1A
158	0	\N	\N	\N	\N	\N	2022-03-05 00:10:00.800453	\N	ASUS TUF GAMING Z690‑PLUS DDR4	40	'05/03/2022':7C 'asus':1A 'ddr4':6A 'game':3A 'plus':5A 'tuf':2A 'z690':4A
159	0	\N	\N	\N	\N	\N	2022-03-05 00:10:43.272287	\N	SteelSeries Rival 3 Wireless	41	'05/03/2022':5C '3':3A 'rival':2A 'steelseri':1A 'wireless':4A
160	0	\N	\N	\N	\N	\N	2022-03-05 00:11:16.752056	\N	Logitech G PRO X SUPERLIGHT Czarny	42	'05/03/2022':7C 'czarni':6A 'g':2A 'logitech':1A 'pro':3A 'superlight':5A 'x':4A
161	0	\N	\N	\N	\N	\N	2022-03-05 00:12:06.23456	\N	Dell KB216‑B QuietKey USB (black)	43	'05/03/2022':7C 'b':3A 'black':6A 'dell':1A 'kb216':2A 'quietkey':4A 'usb':5A
162	0	\N	\N	\N	\N	\N	2022-03-05 00:13:15.284856	\N	SteelSeries Apex 5	44	'05/03/2022':4C '5':3A 'apex':2A 'steelseri':1A
163	0	\N	\N	\N	\N	\N	2022-03-05 00:13:52.79577	\N	Kingston 1TB M.2 PCIe NVMe A2000	45	'05/03/2022':7C '1tb':2A 'a2000':6A 'kingston':1A 'm.2':3A 'nvme':5A 'pcie':4A
164	0	\N	\N	\N	\N	\N	2022-03-05 00:14:38.512531	\N	Apple Magic Keyboard (US Int.)	46	'05/03/2022':6C 'appl':1A 'int':5A 'keyboard':3A 'magic':2A 'us':4A
165	0	\N	\N	\N	\N	\N	2022-03-05 00:15:46.062295	\N	Samsung MLT‑D111S black 1000 str.	47	'05/03/2022':7C '1000':5A 'black':4A 'd111s':3A 'mlt':2A 'samsung':1A 'str':6A
166	0	\N	\N	\N	\N	\N	2022-03-05 00:16:32.609079	\N	HP 103AD dual pack	48	'05/03/2022':5C '103ad':2A 'dual':3A 'hp':1A 'pack':4A
167	0	\N	\N	\N	\N	\N	2022-03-05 00:30:29.02782	\N	Canon Pixma TS3451	49	'05/03/2022':4C 'canon':1A 'pixma':2A 'ts3451':3A
168	0	\N	\N	\N	\N	\N	2022-03-05 00:30:54.151392	\N	HP OfficeJet 8012e, ADF, Instant Ink, HP+	50	'05/03/2022':8C '8012e':3A 'adf':4A 'hp':1A,7A 'ink':6A 'instant':5A 'officejet':2A
169	0	\N	\N	\N	\N	\N	2022-03-05 00:31:45.4075	\N	Logitech 2.1 Z333	51	'05/03/2022':4C '2.1':2A 'logitech':1A 'z333':3A
170	0	\N	\N	\N	\N	\N	2022-03-05 00:32:30.58937	\N	Creative T60	52	'05/03/2022':3C 'creativ':1A 't60':2A
171	0	\N	\N	\N	\N	\N	2022-03-05 00:33:04.951524	\N	ASRock B560M Steel Legend	53	'05/03/2022':5C 'asrock':1A 'b560m':2A 'legend':4A 'steel':3A
172	0	\N	\N	\N	\N	\N	2022-03-05 00:33:56.563509	\N	Mozos MKIT‑700PRO V2	54	'05/03/2022':5C '700pro':3A 'mkit':2A 'mozo':1A 'v2':4A
173	0	\N	\N	\N	\N	\N	2022-03-05 00:34:44.75736	\N	TP-Link Archer C6 (1200Mb/s a/b/g/n/ac) DualBand	55	'05/03/2022':9C '1200mb/s':6A 'a/b/g/n/ac':7A 'archer':4A 'c6':5A 'dualband':8A 'link':3A 'tp':2A 'tp-link':1A
174	0	\N	\N	\N	\N	\N	2022-03-05 00:35:27.178974	\N	ASUS RT‑N12+ PLUS (300Mb/s b/g/n, 4xSSID, repeater)	56	'05/03/2022':9C '300mb/s':5A '4xssid':7A 'asus':1A 'b/g/n':6A 'n12':3A 'plus':4A 'repeat':8A 'rt':2A
175	0	\N	\N	\N	\N	\N	2022-03-05 00:36:54.33093	\N	AMD Ryzen Threadripper 3970X	57	'05/03/2022':5C '3970x':4A 'amd':1A 'ryzen':2A 'threadripp':3A
176	0	\N	\N	\N	\N	\N	2022-03-05 00:38:02.538632	\N	Logitech C920 Pro Full HD	58	'05/03/2022':6C 'c920':2A 'full':4A 'hd':5A 'logitech':1A 'pro':3A
177	0	\N	\N	\N	\N	\N	2022-03-05 00:40:02.458546	\N	Microsoft Windows 11 PRO PL 64bit OEM DVD	59	'05/03/2022':9C '11':3A '64bit':6A 'dvd':8A 'microsoft':1A 'oem':7A 'pl':5A 'pro':4A 'window':2A
178	0	\N	\N	\N	\N	\N	2022-03-05 00:40:38.537051	\N	Microsoft Office Home & Business 2021 ESD	60	'05/03/2022':7C '2021':5A 'busi':4A 'esd':6A 'home':3A 'microsoft':1A 'offic':2A
179	0	\N	\N	\N	\N	\N	2022-03-05 00:41:16.250709	\N	WD 500GB M.2 PCIe NVMe Blue SN570	61	'05/03/2022':8C '500gb':2A 'blue':6A 'm.2':3A 'nvme':5A 'pcie':4A 'sn570':7A 'wd':1A
180	0	\N	\N	\N	\N	\N	2022-03-05 00:42:34.162038	\N	Huion H640P	62	'05/03/2022':3C 'h640p':2A 'huion':1A
181	0	\N	\N	\N	\N	\N	2022-03-05 00:44:08.902517	\N	MSI Radeon RX 6600 MECH 2X 8GB GDDR6	63	'05/03/2022':9C '2x':6A '6600':4A '8gb':7A 'gddr6':8A 'mech':5A 'msi':1A 'radeon':2A 'rx':3A
182	0	\N	\N	\N	\N	\N	2022-03-05 00:44:52.416071	\N	Gigabyte B550 GAMING X V2	64	'05/03/2022':6C 'b550':2A 'game':3A 'gigabyt':1A 'v2':5A 'x':4A
183	0	\N	\N	\N	\N	\N	2022-03-05 00:46:34.449951	\N	Silver Monkey X SMGK1000 Kailh Brown RGB	65	'05/03/2022':8C 'brown':6A 'kailh':5A 'monkey':2A 'rgb':7A 'silver':1A 'smgk1000':4A 'x':3A
184	0	\N	\N	\N	\N	\N	2022-03-05 00:47:26.835664	\N	Acer Nitro VG271USBMIIPX czarny HDR 165Hz	66	'05/03/2022':7C '165hz':6A 'acer':1A 'czarni':4A 'hdr':5A 'nitro':2A 'vg271usbmiipx':3A
185	0	\N	\N	\N	\N	\N	2022-03-05 00:47:58.639085	\N	Gigabyte 16GB (2x8GB) 3333Mhz CL18 Aorus RGB	67	'05/03/2022':8C '16gb':2A '2x8gb':3A '3333mhz':4A 'aorus':6A 'cl18':5A 'gigabyt':1A 'rgb':7A
186	0	\N	\N	\N	\N	\N	2022-03-05 00:48:26.780577	\N	G.SKILL 32GB (2x16GB) 3600MHz CL16 TridentZ RGB Neo	68	'05/03/2022':9C '2x16gb':3A '32gb':2A '3600mhz':4A 'cl16':5A 'g.skill':1A 'neo':8A 'rgb':7A 'tridentz':6A
187	0	\N	\N	\N	\N	\N	2022-03-05 00:49:44.756757	\N	Intel Core i9‑11900KF	69	'05/03/2022':5C '11900kf':4A 'core':2A 'i9':3A 'intel':1A
188	0	\N	\N	\N	\N	\N	2022-03-05 00:52:32.270182	\N	Gigabyte Z590 D	70	'05/03/2022':4C 'd':3A 'gigabyt':1A 'z590':2A
189	5	\N	\N	\N	\N	\N	2022-03-05 00:53:44.067776	\N	kIntelCoGigabyte033801xmkv5bd1lp-05	2	'-05':2A '05/03/2022':3C 'kintelcogigabyte033801xmkv5bd1lp':1A
190	5	\N	\N	\N	\N	\N	2022-03-05 02:31:25.675464	\N	kIntelCoGigabyte032603e32phh09wp-05	3	'-05':2A '05/03/2022':3C 'kintelcogigabyte032603e32phh09wp':1A
191	1	\N	\N	\N	\N	\N	2022-03-05 03:10:58.217152	\N	\N	39	\N
192	0	\N	\N	\N	\N	\N	2022-03-05 03:13:51.905198	\N	Corsair TX850M 850W 80 Plus Gold	71	'05/03/2022':7C '80':4A '850w':3A 'corsair':1A 'gold':6A 'plus':5A 'tx850m':2A
193	0	\N	\N	\N	\N	\N	2022-03-05 03:15:39.37792	\N	Phanteks Eclipse P500A DRGB Czarna	72	'05/03/2022':6C 'czarna':5A 'drgb':4A 'eclips':2A 'p500a':3A 'phantek':1A
194	5	\N	\N	\N	\N	\N	2022-03-05 03:16:55.064771	\N	kIntelCoGigabyte030104e77yohsw63h-05	5	'-05':2A '05/03/2022':3C 'kintelcogigabyte030104e77yohsw63h':1A
195	5	\N	\N	\N	\N	\N	2022-03-05 03:19:37.788585	\N	kAMDRyzeMSIB560031704dnv7mcwh3v-05	6	'-05':2A '05/03/2022':3C 'kamdryzemsib560031704dnv7mcwh3v':1A
196	0	\N	\N	\N	\N	\N	2022-03-05 03:28:41.296028	\N	SilentiumPC Armis AR6 TG	73	'05/03/2022':5C 'ar6':3A 'armi':2A 'silentiumpc':1A 'tg':4A
197	0	\N	\N	\N	\N	\N	2022-03-05 03:29:32.983234	\N	NZXT H510 Flow White	74	'05/03/2022':5C 'flow':3A 'h510':2A 'nzxt':1A 'white':4A
198	0	\N	\N	\N	\N	\N	2022-03-05 03:30:51.9578	\N	Intel Core i9‑11900F	75	'05/03/2022':5C '11900f':4A 'core':2A 'i9':3A 'intel':1A
199	0	\N	\N	\N	\N	\N	2022-03-05 03:31:31.949052	\N	Intel Core i5‑12600KF	76	'05/03/2022':5C '12600kf':4A 'core':2A 'i5':3A 'intel':1A
200	0	\N	\N	\N	\N	\N	2022-03-05 03:32:17.712349	\N	be quiet! System Power 9 600W 80 Plus Bronze	77	'05/03/2022':10C '600w':6A '80':7A '9':5A 'bronz':9A 'plus':8A 'power':4A 'quiet':2A 'system':3A
201	0	\N	\N	\N	\N	\N	2022-03-05 03:35:27.030932	\N	Gigabyte Z590 UD AC	78	'05/03/2022':5C 'ac':4A 'gigabyt':1A 'ud':3A 'z590':2A
202	5	\N	\N	\N	\N	\N	2022-03-05 03:36:16.958487	\N	kIntelCoGigabyte032104w8ztxu2cgf-05	7	'-05':2A '05/03/2022':3C 'kintelcogigabyte032104w8ztxu2cgf':1A
203	1	\N	\N	\N	\N	\N	2022-03-05 03:37:23.261151	\N	\N	57	\N
204	0	\N	\N	\N	\N	\N	2022-03-05 03:37:58.694502	\N	ASUS ROG Zenith II Extreme	79	'05/03/2022':6C 'asus':1A 'extrem':5A 'ii':4A 'rog':2A 'zenith':3A
205	1	\N	\N	\N	\N	\N	2022-03-05 03:38:32.684229	\N	\N	79	\N
206	15	\N	\N	\N	\N	\N	2022-03-05 03:39:36.947897	\N	Proline	27	'05/03/2022':2C 'prolin':1A
297	5	\N	\N	\N	\N	\N	2022-03-05 08:41:24.864944	\N	Nothing compares to this PC	21	'05/03/2022':6C 'compar':2A 'noth':1A 'pc':5A
207	0	\N	\N	\N	\N	\N	2022-03-05 03:40:46.341486	\N	Kingston FURY 128GB (4x32GB) 3200MHz CL16 Beast Black	80	'05/03/2022':9C '128gb':3A '3200mhz':5A '4x32gb':4A 'beast':7A 'black':8A 'cl16':6A 'furi':2A 'kingston':1A
208	0	\N	\N	\N	\N	\N	2022-03-05 03:42:05.099076	\N	AMD Radeon PRO W6800 32GB GDDR6	81	'05/03/2022':7C '32gb':5A 'amd':1A 'gddr6':6A 'pro':3A 'radeon':2A 'w6800':4A
209	16	\N	\N	\N	\N	\N	2022-03-05 03:42:14.258799	\N	Proline	27	'05/03/2022':2C 'prolin':1A
210	0	\N	\N	\N	\N	\N	2022-03-05 03:44:25.045579	\N	Corsair Obsidian 1000D	82	'05/03/2022':4C '1000d':3A 'corsair':1A 'obsidian':2A
211	5	\N	\N	\N	\N	\N	2022-03-05 03:50:16.878015	\N	kIntelCoASRockB0346044usp0cdglqg-05	8	'-05':2A '05/03/2022':3C 'kintelcoasrockb0346044usp0cdglqg':1A
212	0	\N	\N	\N	\N	\N	2022-03-05 03:52:55.072743	\N	be quiet! Dark Power PRO 12 1500W (BN312)	83	'05/03/2022':9C '12':6A '1500w':7A 'bn312':8A 'dark':3A 'power':4A 'pro':5A 'quiet':2A
213	0	\N	\N	\N	\N	\N	2022-03-05 03:54:10.607931	\N	SanDisk Ultra 3D SSD 4TB 560/530 Sata III 2,5	84	'05/03/2022':11C '2':9A '3d':3A '4tb':5A '5':10A '560/530':6A 'iii':8A 'sandisk':1A 'sata':7A 'ssd':4A 'ultra':2A
214	0	\N	\N	\N	\N	\N	2022-03-05 03:55:38.427159	\N	Seagate FireCuda 510 2 TB M.2 2280 PCI-E x4 Gen3 NVMe	85	'05/03/2022':14C '2':4A '2280':7A '510':3A 'e':10A 'firecuda':2A 'gen3':12A 'm.2':6A 'nvme':13A 'pci':9A 'pci-e':8A 'seagat':1A 'tb':5A 'x4':11A
215	5	\N	\N	\N	\N	\N	2022-03-05 03:56:40.119736	\N	THE BEST	9	'05/03/2022':3C 'best':2A
216	1	\N	\N	\N	\N	\N	2022-03-05 04:48:58.66453	\N	\N	61	\N
217	5	\N	\N	\N	\N	\N	2022-03-05 04:49:37.554356	\N	kIntelCoGigabyte034705guqvtg4zae-05	10	'-05':2A '05/03/2022':3C 'kintelcogigabyte034705guqvtg4zae':1A
218	0	\N	\N	\N	\N	\N	2022-03-05 04:54:07.706273	\N	Procesor AMD Ryzen 9 3900X, 3.8GHz, 64 MB, BOX	86	'05/03/2022':11C '3.8':6A '3900x':5A '64':8A '9':4A 'amd':2A 'box':10A 'ghz':7A 'mb':9A 'procesor':1A 'ryzen':3A
219	0	\N	\N	\N	\N	\N	2022-03-05 04:55:05.214501	\N	Asus PRIME B550M-A WI-FI	87	'05/03/2022':9C 'asus':1A 'b550m':4A 'b550m-a':3A 'fi':8A 'prime':2A 'wi':7A 'wi-fi':6A
220	0	\N	\N	\N	\N	\N	2022-03-05 04:56:04.757552	\N	Patriot 16GB (2x8GB) 3600MHz CL18 Viper Steel	88	'05/03/2022':8C '16gb':2A '2x8gb':3A '3600mhz':4A 'cl18':5A 'patriot':1A 'steel':7A 'viper':6A
221	0	\N	\N	\N	\N	\N	2022-03-05 04:57:06.021184	\N	be quiet! Pure Power 11 CM 600W 80 Plus Gold	89	'05/03/2022':11C '11':5A '600w':7A '80':8A 'cm':6A 'gold':10A 'plus':9A 'power':4A 'pure':3A 'quiet':2A
222	0	\N	\N	\N	\N	\N	2022-03-05 04:57:58.962548	\N	Logitech B100 Black USB	90	'05/03/2022':5C 'b100':2A 'black':3A 'logitech':1A 'usb':4A
223	0	\N	\N	\N	\N	\N	2022-03-05 04:58:49.574876	\N	Dysk WD Black 2 TB 3.5" SATA III (WD2003FZEX)	91	'05/03/2022':10C '2':4A '3.5':6A 'black':3A 'dysk':1A 'iii':8A 'sata':7A 'tb':5A 'wd':2A 'wd2003fzex':9A
224	5	\N	\N	\N	\N	\N	2022-03-05 05:00:17.292718	\N	kProcesorAsusPRI034705th627eop6e-05	11	'-05':2A '05/03/2022':3C 'kprocesorasuspri034705th627eop6e':1A
225	0	\N	\N	\N	\N	\N	2022-03-05 05:02:26.589155	\N	AMD Athlon 200GE, 3.2GHz, 4 MB, BOX	92	'05/03/2022':9C '200ge':3A '3.2':4A '4':6A 'amd':1A 'athlon':2A 'box':8A 'ghz':5A 'mb':7A
226	1	\N	\N	\N	\N	\N	2022-03-05 05:02:36.118925	\N	\N	92	\N
227	0	\N	\N	\N	\N	\N	2022-03-05 05:03:31.307951	\N	MSI A320M-A Pro	93	'05/03/2022':6C 'a320m':3A 'a320m-a':2A 'msi':1A 'pro':5A
228	0	\N	\N	\N	\N	\N	2022-03-05 05:05:16.442137	\N	Corsair CV 550W 80 Plus Bronze	94	'05/03/2022':7C '550w':3A '80':4A 'bronz':6A 'corsair':1A 'cv':2A 'plus':5A
229	0	\N	\N	\N	\N	\N	2022-03-05 05:06:04.690436	\N	GOODRAM 8GB (1x8GB) 2666MHz CL16 IRDM X Black	95	'05/03/2022':9C '1x8gb':3A '2666mhz':4A '8gb':2A 'black':8A 'cl16':5A 'goodram':1A 'irdm':6A 'x':7A
230	0	\N	\N	\N	\N	\N	2022-03-05 05:07:10.038972	\N	SSD Samsung 970 EVO Plus 250 GB M.2 2280 PCI-E x4 Gen3 NVMe	96	'05/03/2022':16C '2280':9A '250':6A '970':3A 'e':12A 'evo':4A 'gb':7A 'gen3':14A 'm.2':8A 'nvme':15A 'pci':11A 'pci-e':10A 'plus':5A 'samsung':2A 'ssd':1A 'x4':13A
231	0	\N	\N	\N	\N	\N	2022-03-05 05:09:06.266823	\N	SilentiumPC Signum SG1	97	'05/03/2022':4C 'sg1':3A 'signum':2A 'silentiumpc':1A
232	0	\N	\N	\N	\N	\N	2022-03-05 05:09:55.37777	\N	Procesor AMD Athlon 3000G, 3.5GHz, 4 MB, BOX	98	'05/03/2022':10C '3.5':5A '3000g':4A '4':7A 'amd':2A 'athlon':3A 'box':9A 'ghz':6A 'mb':8A 'procesor':1A
233	0	\N	\N	\N	\N	\N	2022-03-05 05:10:52.459178	\N	ASRock B450M-HDV R4.0	99	'05/03/2022':6C 'asrock':1A 'b450m':3A 'b450m-hdv':2A 'hdv':4A 'r4.0':5A
234	5	\N	\N	\N	\N	\N	2022-03-05 05:11:31.345109	\N	kProcesorASRockB034705zy9kc2dgzp-05	12	'-05':2A '05/03/2022':3C 'kprocesorasrockb034705zy9kc2dgzp':1A
235	5	\N	\N	\N	\N	\N	2022-03-05 05:12:03.532145	\N	Budget Total	13	'05/03/2022':3C 'budget':1A 'total':2A
236	5	\N	\N	\N	\N	\N	2022-03-05 05:14:26.018023	\N	kProcesorAsusPRI024709347eghigym-09	14	'-09':2A '05/03/2022':3C 'kprocesorasuspri024709347eghigym':1A
237	5	\N	\N	\N	\N	\N	2022-03-05 05:15:04.917277	\N	kProcesorASRockB014713qalfbvzr05-20	15	'-20':2A '05/03/2022':3C 'kprocesorasrockb014713qalfbvzr05':1A
238	5	\N	\N	\N	\N	\N	2022-03-05 05:16:43.498261	\N	Gaming Comp	16	'05/03/2022':3C 'comp':2A 'game':1A
239	0	\N	\N	\N	\N	\N	2022-03-05 05:17:57.800157	\N	Gigabyte Radeon RX 6800 XT GAMING OC 16GB GDDR6	100	'05/03/2022':10C '16gb':8A '6800':4A 'game':6A 'gddr6':9A 'gigabyt':1A 'oc':7A 'radeon':2A 'rx':3A 'xt':5A
240	0	\N	\N	\N	\N	\N	2022-03-05 05:18:23.322641	\N	ASUS GeForce RTX 3070 Ti ROG STRIX OC 8GB GDDR6X	101	'05/03/2022':11C '3070':4A '8gb':9A 'asus':1A 'gddr6x':10A 'geforc':2A 'oc':8A 'rog':6A 'rtx':3A 'strix':7A 'ti':5A
241	5	\N	\N	\N	\N	\N	2022-03-05 05:19:30.279237	\N	kProcesorASRockB014713a1m7kinbms-20	17	'-20':2A '05/03/2022':3C 'kprocesorasrockb014713a1m7kinbms':1A
242	1	\N	\N	\N	\N	\N	2022-03-05 05:19:51.81362	\N	\N	98	\N
243	1	\N	\N	\N	\N	\N	2022-03-05 05:19:55.191704	\N	\N	86	\N
244	5	\N	\N	\N	\N	\N	2022-03-05 05:20:48.810137	\N	kAMDRyzeGigabyte014713v5qq3vjm7zk-20	18	'-20':2A '05/03/2022':3C 'kamdryzegigabyte014713v5qq3vjm7zk':1A
245	5	\N	\N	\N	\N	\N	2022-03-05 05:22:01.092522	\N	kAMDRyzeGigabyte014713i4jnnygqrr-20	19	'-20':2A '05/03/2022':3C 'kamdryzegigabyte014713i4jnnygqrr':1A
246	0	\N	\N	\N	\N	\N	2022-03-05 05:23:20.351903	\N	LC-Power Phenom Pro 512 GB M.2 2280 PCI-E x4 Gen3 NVMe	102	'05/03/2022':16C '2280':9A '512':6A 'e':12A 'gb':7A 'gen3':14A 'lc':2A 'lc-power':1A 'm.2':8A 'nvme':15A 'pci':11A 'pci-e':10A 'phenom':4A 'power':3A 'pro':5A 'x4':13A
247	8	\N	\N	\N	\N	\N	2022-03-05 05:30:37.190073	\N	Goes into a bootloop, after a while, it shows the information on lack of processor	1	'05/03/2022':16C 'bootloop':4A 'goe':1A 'inform':11A 'lack':13A 'processor':15A 'show':9A
248	8	\N	\N	\N	\N	\N	2022-03-05 05:31:57.205712	\N	The motherboard pins are slightly bent, probably happened during the transport	5	'05/03/2022':12C 'bent':6A 'happen':8A 'motherboard':2A 'pin':3A 'probabl':7A 'slight':5A 'transport':11A
249	8	\N	\N	\N	\N	\N	2022-03-05 05:33:31.923123	\N	Doesn't want to start :(	9	'05/03/2022':6C 'doesn':1A 'start':5A 'want':3A
250	8	\N	\N	\N	\N	\N	2022-03-05 05:34:06.546733	\N	Very high processor temperatures! Needs to be checked out	10	'05/03/2022':9C 'check':8A 'high':2A 'need':5A 'processor':3A 'temperatur':4A
251	8	\N	\N	\N	\N	\N	2022-03-05 05:37:59.220092	\N	The Client is not satisfied with cable management	11	'05/03/2022':9C 'cabl':7A 'client':2A 'manag':8A 'satisfi':5A
252	3	\N	\N	\N	\N	\N	2022-03-05 05:39:15.393127	\N	Sale for Robert Lewandowski on 2022-03-04 11:37 	1	'-03':7A '-04':8A '05/03/2022':11C '11':9A '2022':6A '37':10A 'lewandowski':4A 'robert':3A 'sale':1A
253	3	\N	\N	\N	\N	\N	2022-03-05 05:39:35.897403	\N	Sale for Weather Report on 2022-03-05 06:37 	2	'-03':7A '-05':8A '05/03/2022':11C '06':9A '2022':6A '37':10A 'report':4A 'sale':1A 'weather':3A
254	3	\N	\N	\N	\N	\N	2022-03-05 05:39:57.698515	\N	Sale for Ritchie Blackmore on 2022-03-05 06:37 	3	'-03':7A '-05':8A '05/03/2022':11C '06':9A '2022':6A '37':10A 'blackmor':4A 'ritchi':3A 'sale':1A
255	3	\N	\N	\N	\N	\N	2022-03-05 05:41:02.973512	\N	Sale for David Bowie on 2022-03-02 12:37 	4	'-02':8A '-03':7A '05/03/2022':11C '12':9A '2022':6A '37':10A 'bowi':4A 'david':3A 'sale':1A
256	3	\N	\N	\N	\N	\N	2022-03-05 05:41:30.295688	\N	Sale for Billy Idol on 2022-03-05 06:37 	5	'-03':7A '-05':8A '05/03/2022':11C '06':9A '2022':6A '37':10A 'billi':3A 'idol':4A 'sale':1A
257	3	\N	\N	\N	\N	\N	2022-03-05 05:41:44.991031	\N	Sale for Alex Kommt on 2022-03-05 06:37 	6	'-03':7A '-05':8A '05/03/2022':11C '06':9A '2022':6A '37':10A 'alex':3A 'kommt':4A 'sale':1A
258	3	\N	\N	\N	\N	\N	2022-03-05 05:42:11.785796	\N	Sale for Herbie Hancock on 2022-03-05 06:37 	7	'-03':7A '-05':8A '05/03/2022':11C '06':9A '2022':6A '37':10A 'hancock':4A 'herbi':3A 'sale':1A
259	3	\N	\N	\N	\N	\N	2022-03-05 05:42:31.248495	\N	Sale for Agata Sp. Z.O.O on 2022-03-03 12:42 	8	'-03':8A,9A '05/03/2022':12C '12':10A '2022':7A '42':11A 'agata':3A 'sale':1A 'sp':4A 'z.o.o':5A
260	3	\N	\N	\N	\N	\N	2022-03-05 05:42:53.513778	\N	Sale for Sinead O'Connor on 2022-03-05 06:37 	9	'-03':8A '-05':9A '05/03/2022':12C '06':10A '2022':7A '37':11A 'connor':5A 'o':4A 'sale':1A 'sinead':3A
261	3	\N	\N	\N	\N	\N	2022-03-05 05:43:11.332613	\N	Sale for Tadeusz Wozniak on 2022-03-05 06:37 	10	'-03':7A '-05':8A '05/03/2022':11C '06':9A '2022':6A '37':10A 'sale':1A 'tadeusz':3A 'wozniak':4A
262	12	\N	\N	\N	\N	\N	2022-03-05 05:43:57.935062	\N	Mariusz Timm	41	'05/03/2022':3C 'mariusz':1A 'timm':2A
263	3	\N	\N	\N	\N	\N	2022-03-05 05:44:25.49727	\N	Sale for Mariusz Timm on 2022-03-05 06:44 	11	'-03':7A '-05':8A '05/03/2022':11C '06':9A '2022':6A '44':10A 'mariusz':3A 'sale':1A 'timm':4A
264	3	\N	\N	\N	\N	\N	2022-03-05 05:45:21.18222	\N	Sale for Mariusz Janewski on 2022-03-01 18:47 	12	'-01':8A '-03':7A '05/03/2022':11C '18':9A '2022':6A '47':10A 'janewski':4A 'mariusz':3A 'sale':1A
265	1	\N	\N	\N	\N	\N	2022-03-05 05:45:31.489544	\N	\N	41	\N
266	3	\N	\N	\N	\N	\N	2022-03-05 05:45:44.79618	\N	Sale for Hulk Hogan on 2022-02-25 11:49 	13	'-02':7A '-25':8A '05/03/2022':11C '11':9A '2022':6A '49':10A 'hogan':4A 'hulk':3A 'sale':1A
267	3	\N	\N	\N	\N	\N	2022-03-05 05:46:07.045733	\N	Sale for Mac Quayle on 2022-02-24 12:50 	14	'-02':7A '-24':8A '05/03/2022':11C '12':9A '2022':6A '50':10A 'mac':3A 'quayl':4A 'sale':1A
268	3	\N	\N	\N	\N	\N	2022-03-05 05:46:38.514555	\N	Sale for Sonic Youth on 2022-02-25 11:49 	15	'-02':7A '-25':8A '05/03/2022':11C '11':9A '2022':6A '49':10A 'sale':1A 'sonic':3A 'youth':4A
269	1	\N	\N	\N	\N	\N	2022-03-05 05:46:50.625924	\N	\N	42	\N
270	3	\N	\N	\N	\N	\N	2022-03-05 05:47:29.945965	\N	Sale for Hulk Hogan on 2022-03-05 06:47 	16	'-03':7A '-05':8A '05/03/2022':11C '06':9A '2022':6A '47':10A 'hogan':4A 'hulk':3A 'sale':1A
271	3	\N	\N	\N	\N	\N	2022-03-05 05:47:38.146643	\N	Sale for Gary Moore on 2022-03-05 06:47 	17	'-03':7A '-05':8A '05/03/2022':11C '06':9A '2022':6A '47':10A 'gari':3A 'moor':4A 'sale':1A
272	3	\N	\N	\N	\N	\N	2022-03-05 05:47:52.643277	\N	Sale for Uriah Heep on 2022-03-05 06:47 	18	'-03':7A '-05':8A '05/03/2022':11C '06':9A '2022':6A '47':10A 'heep':4A 'sale':1A 'uriah':3A
273	3	\N	\N	\N	\N	\N	2022-03-05 06:03:03.034212	\N	Sale for Billy Idol on 2022-03-05 07:02 	19	'-03':7A '-05':8A '02':10A '05/03/2022':11C '07':9A '2022':6A 'billi':3A 'idol':4A 'sale':1A
274	1	\N	\N	\N	\N	\N	2022-03-05 06:07:31.52086	\N	\N	87	\N
275	1	\N	\N	\N	\N	\N	2022-03-05 06:07:40.510751	\N	\N	77	\N
276	1	\N	\N	\N	\N	\N	2022-03-05 06:07:45.568791	\N	\N	74	\N
277	1	\N	\N	\N	\N	\N	2022-03-05 06:07:50.197984	\N	\N	70	\N
278	1	\N	\N	\N	\N	\N	2022-03-05 06:07:54.173819	\N	\N	64	\N
279	1	\N	\N	\N	\N	\N	2022-03-05 06:08:09.744029	\N	\N	23	\N
280	1	\N	\N	\N	\N	\N	2022-03-05 06:08:18.238431	\N	\N	38	\N
281	1	\N	\N	\N	\N	\N	2022-03-05 06:08:22.648242	\N	\N	63	\N
282	1	\N	\N	\N	\N	\N	2022-03-05 06:08:28.038456	\N	\N	102	\N
283	1	\N	\N	\N	\N	\N	2022-03-05 06:08:34.684282	\N	\N	86	\N
284	1	\N	\N	\N	\N	\N	2022-03-05 06:08:41.141557	\N	\N	60	\N
285	1	\N	\N	\N	\N	\N	2022-03-05 06:08:51.321622	\N	\N	45	\N
286	1	\N	\N	\N	\N	\N	2022-03-05 06:09:00.561967	\N	\N	32	\N
287	1	\N	\N	\N	\N	\N	2022-03-05 06:09:10.390433	\N	\N	7	\N
288	3	\N	\N	\N	\N	\N	2022-03-05 06:09:51.914161	\N	Sale for Mac Quayle on 2022-03-05 07:07 	20	'-03':7A '-05':8A '05/03/2022':11C '07':9A,10A '2022':6A 'mac':3A 'quayl':4A 'sale':1A
289	3	\N	\N	\N	\N	\N	2022-03-05 06:12:56.997011	\N	Sale for Sinead O'Connor on 2022-03-05 07:12 	21	'-03':8A '-05':9A '05/03/2022':12C '07':10A '12':11A '2022':7A 'connor':5A 'o':4A 'sale':1A 'sinead':3A
290	3	\N	\N	\N	\N	\N	2022-03-05 06:14:25.327932	\N	Sale for Led Zeppelin on 2022-03-05 07:14 	22	'-03':7A '-05':8A '05/03/2022':11C '07':9A '14':10A '2022':6A 'led':3A 'sale':1A 'zeppelin':4A
291	3	\N	\N	\N	\N	\N	2022-03-05 06:16:16.323171	\N	Sale for Hulk Hogan on 2022-03-05 07:16 	23	'-03':7A '-05':8A '05/03/2022':11C '07':9A '16':10A '2022':6A 'hogan':4A 'hulk':3A 'sale':1A
292	3	\N	\N	\N	\N	\N	2022-03-05 06:16:44.499501	\N	Sale for Frank Zappa on 2022-03-05 07:16 	24	'-03':7A '-05':8A '05/03/2022':11C '07':9A '16':10A '2022':6A 'frank':3A 'sale':1A 'zappa':4A
293	5	\N	\N	\N	\N	\N	2022-03-05 06:49:08.828575	\N	CompTest	20	'05/03/2022':2C 'comptest':1A
294	3	\N	\N	\N	\N	\N	2022-03-05 06:49:35.713118	\N	Sale for Billy Idol on 2022-03-05 07:22 	25	'-03':7A '-05':8A '05/03/2022':11C '07':9A '2022':6A '22':10A 'billi':3A 'idol':4A 'sale':1A
295	13	\N	\N	\N	\N	\N	2022-03-05 08:36:14.477577	\N	Emilka Love	40	'05/03/2022':3C 'emilka':1A 'love':2A
298	3	\N	\N	\N	\N	\N	2022-03-05 08:43:45.866348	\N	Order Made by the Special One	26	'05/03/2022':7C 'made':2A 'one':6A 'order':1A 'special':5A
299	3	\N	\N	\N	\N	\N	2022-03-05 08:46:24.414652	\N	Sale for Mariusz Timm on 2022-03-05 09:38 	27	'-03':7A '-05':8A '05/03/2022':11C '09':9A '2022':6A '38':10A 'mariusz':3A 'sale':1A 'timm':4A
300	3	\N	\N	\N	\N	\N	2022-03-05 08:46:42.508134	\N	Sale for Sonic Youth on 2022-03-05 09:38 	28	'-03':7A '-05':8A '05/03/2022':11C '09':9A '2022':6A '38':10A 'sale':1A 'sonic':3A 'youth':4A
301	3	\N	\N	\N	\N	\N	2022-03-05 08:47:01.67169	\N	Sale for Peter Schilling on 2022-03-03 13:38 	29	'-03':7A,8A '05/03/2022':11C '13':9A '2022':6A '38':10A 'peter':3A 'sale':1A 'schill':4A
302	3	\N	\N	\N	\N	\N	2022-03-05 08:47:18.783262	\N	Sale for Fugazi on 2022-03-05 09:38 	30	'-03':6A '-05':7A '05/03/2022':10C '09':8A '2022':5A '38':9A 'fugazi':3A 'sale':1A
303	3	\N	\N	\N	\N	\N	2022-03-05 08:47:32.162385	\N	Sale for Alex Kommt on 2022-03-05 09:38 	31	'-03':7A '-05':8A '05/03/2022':11C '09':9A '2022':6A '38':10A 'alex':3A 'kommt':4A 'sale':1A
304	3	\N	\N	\N	\N	\N	2022-03-05 08:48:39.356306	\N	Sale for Sinead O'Connor on 2022-03-03 15:48 	32	'-03':8A,9A '05/03/2022':12C '15':10A '2022':7A '48':11A 'connor':5A 'o':4A 'sale':1A 'sinead':3A
305	3	\N	\N	\N	\N	\N	2022-03-05 08:49:00.111396	\N	Sale for Weather Report on 2022-03-02 13:50 	33	'-02':8A '-03':7A '05/03/2022':11C '13':9A '2022':6A '50':10A 'report':4A 'sale':1A 'weather':3A
306	3	\N	\N	\N	\N	\N	2022-03-05 08:50:52.111587	\N	Sale for Agata Sp. Z.O.O on 2022-03-05 09:48 	34	'-03':8A '-05':9A '05/03/2022':12C '09':10A '2022':7A '48':11A 'agata':3A 'sale':1A 'sp':4A 'z.o.o':5A
307	3	\N	\N	\N	\N	\N	2022-03-05 09:01:15.397243	\N	Sale for Sonic Youth on 2022-02-28 14:03 	35	'-02':7A '-28':8A '03':10A '05/03/2022':11C '14':9A '2022':6A 'sale':1A 'sonic':3A 'youth':4A
308	3	\N	\N	\N	\N	\N	2022-03-05 09:02:09.37499	\N	Sale for Alex Kommt on 2022-02-25 16:59 	36	'-02':7A '-25':8A '05/03/2022':11C '16':9A '2022':6A '59':10A 'alex':3A 'kommt':4A 'sale':1A
309	3	\N	\N	\N	\N	\N	2022-03-05 09:03:24.855037	\N	Sale for Gary Moore on 2022-02-24 13:57 	37	'-02':7A '-24':8A '05/03/2022':11C '13':9A '2022':6A '57':10A 'gari':3A 'moor':4A 'sale':1A
310	3	\N	\N	\N	\N	\N	2022-03-05 09:09:49.843604	\N	Sale for Pink Floyd on 2022-03-05 10:08 	38	'-03':7A '-05':8A '05/03/2022':11C '08':10A '10':9A '2022':6A 'floyd':4A 'pink':3A 'sale':1A
311	3	\N	\N	\N	\N	\N	2022-03-05 09:13:51.496404	\N	Sale for Robert Lewandowski on 2022-02-19 14:08 	39	'-02':7A '-19':8A '05/03/2022':11C '08':10A '14':9A '2022':6A 'lewandowski':4A 'robert':3A 'sale':1A
312	3	\N	\N	\N	\N	\N	2022-03-05 09:14:53.117729	\N	Sale for Mac Quayle on 2022-02-17 14:14 	40	'-02':7A '-17':8A '05/03/2022':11C '14':9A,10A '2022':6A 'mac':3A 'quayl':4A 'sale':1A
313	3	\N	\N	\N	\N	\N	2022-03-05 09:15:33.902203	\N	Sale for Mordo Muzik on 2022-03-05 10:14 	41	'-03':7A '-05':8A '05/03/2022':11C '10':9A '14':10A '2022':6A 'mordo':3A 'muzik':4A 'sale':1A
314	3	\N	\N	\N	\N	\N	2022-03-05 09:16:06.642527	\N	Sale for Ozzy Osbourne on 2022-02-12 14:14 	42	'-02':7A '-12':8A '05/03/2022':11C '14':9A,10A '2022':6A 'osbourn':4A 'ozzi':3A 'sale':1A
315	3	\N	\N	\N	\N	\N	2022-03-05 09:16:54.026102	\N	Sale for The Bill on 2022-02-19 15:14 	43	'-02':7A '-19':8A '05/03/2022':11C '14':10A '15':9A '2022':6A 'bill':4A 'sale':1A
316	3	\N	\N	\N	\N	\N	2022-03-05 09:17:18.809779	\N	Sale for Joe Satriani on 2022-02-10 04:19 	44	'-02':7A '-10':8A '04':9A '05/03/2022':11C '19':10A '2022':6A 'joe':3A 'sale':1A 'satriani':4A
317	3	\N	\N	\N	\N	\N	2022-03-05 09:17:41.346171	\N	Sale for Mariusz Timm on 2022-02-04 13:19 	45	'-02':7A '-04':8A '05/03/2022':11C '13':9A '19':10A '2022':6A 'mariusz':3A 'sale':1A 'timm':4A
318	3	\N	\N	\N	\N	\N	2022-03-05 09:18:12.062911	\N	Sale for Iron Maiden on 2022-02-06 15:30 	46	'-02':7A '-06':8A '05/03/2022':11C '15':9A '2022':6A '30':10A 'iron':3A 'maiden':4A 'sale':1A
319	3	\N	\N	\N	\N	\N	2022-03-05 09:18:58.072586	\N	Sale for Agata Sp. Z.O.O on 2022-02-02 12:19 	47	'-02':8A,9A '05/03/2022':12C '12':10A '19':11A '2022':7A 'agata':3A 'sale':1A 'sp':4A 'z.o.o':5A
320	3	\N	\N	\N	\N	\N	2022-03-05 09:21:02.925733	\N	Sale for Motley Crue on 2022-01-25 16:23 	48	'-01':7A '-25':8A '05/03/2022':11C '16':9A '2022':6A '23':10A 'crue':4A 'motley':3A 'sale':1A
321	3	\N	\N	\N	\N	\N	2022-03-05 09:36:17.098464	\N	Sale for Mike Oldfield on 2022-01-30 15:38 	49	'-01':7A '-30':8A '05/03/2022':11C '15':9A '2022':6A '38':10A 'mike':3A 'oldfield':4A 'sale':1A
322	3	\N	\N	\N	\N	\N	2022-03-05 09:37:00.101154	\N	Sale for Uriah Heep on 2022-01-28 15:39 	50	'-01':7A '-28':8A '05/03/2022':11C '15':9A '2022':6A '39':10A 'heep':4A 'sale':1A 'uriah':3A
323	3	\N	\N	\N	\N	\N	2022-03-05 09:38:52.704853	\N	Sale for Mariusz Janewski on 2022-01-27 15:43 	51	'-01':7A '-27':8A '05/03/2022':11C '15':9A '2022':6A '43':10A 'janewski':4A 'mariusz':3A 'sale':1A
324	3	\N	\N	\N	\N	\N	2022-03-05 09:53:29.596547	\N	Sale for Hulk Hogan on 2022-01-27 16:43 	52	'-01':7A '-27':8A '05/03/2022':11C '16':9A '2022':6A '43':10A 'hogan':4A 'hulk':3A 'sale':1A
325	3	\N	\N	\N	\N	\N	2022-03-05 09:53:50.226719	\N	Sale for Oingo Boingo on 2022-03-05 10:38 	53	'-03':7A '-05':8A '05/03/2022':11C '10':9A '2022':6A '38':10A 'boingo':4A 'oingo':3A 'sale':1A
326	3	\N	\N	\N	\N	\N	2022-03-05 10:11:57.00156	\N	Sale for Jeff Beck on 2022-01-19 15:13 	54	'-01':7A '-19':8A '05/03/2022':11C '13':10A '15':9A '2022':6A 'beck':4A 'jeff':3A 'sale':1A
327	3	\N	\N	\N	\N	\N	2022-03-05 10:19:43.030139	\N	Sale for John Lennon on 2022-01-20 15:15 	55	'-01':7A '-20':8A '05/03/2022':11C '15':9A,10A '2022':6A 'john':3A 'lennon':4A 'sale':1A
328	3	\N	\N	\N	\N	\N	2022-03-05 10:20:52.55576	\N	Sale for Billy Joel on 2022-01-14 14:18 	56	'-01':7A '-14':8A '05/03/2022':11C '14':9A '18':10A '2022':6A 'billi':3A 'joel':4A 'sale':1A
329	3	\N	\N	\N	\N	\N	2022-03-05 10:21:34.426041	\N	Sale for Judas Priest on 2022-01-08 15:16 	57	'-01':7A '-08':8A '05/03/2022':11C '15':9A '16':10A '2022':6A 'juda':3A 'priest':4A 'sale':1A
330	3	\N	\N	\N	\N	\N	2022-03-05 10:22:02.294034	\N	Sale for Michael Jackson on 2022-01-01 16:16 	58	'-01':7A,8A '05/03/2022':11C '16':9A,10A '2022':6A 'jackson':4A 'michael':3A 'sale':1A
331	3	\N	\N	\N	\N	\N	2022-03-05 10:23:01.402318	\N	Sale for Oingo Boingo on 2022-01-07 14:14 	59	'-01':7A '-07':8A '05/03/2022':11C '14':9A,10A '2022':6A 'boingo':4A 'oingo':3A 'sale':1A
332	5	\N	\N	\N	\N	\N	2022-03-05 10:33:24.322124	\N	kIntelCoGigabyte12331695cg9726mw-17	22	'-17':2A '05/03/2022':3C 'kintelcogigabyte12331695cg9726mw':1A
333	3	\N	\N	\N	\N	\N	2022-03-05 10:34:13.413778	\N	Sale for Franek Kimono on 2022-01-08 16:36 	60	'-01':7A '-08':8A '05/03/2022':11C '16':9A '2022':6A '36':10A 'franek':3A 'kimono':4A 'sale':1A
334	3	\N	\N	\N	\N	\N	2022-03-05 10:35:26.853138	\N	Sale for Frederic Chopin on 2022-01-02 16:35 	61	'-01':7A '-02':8A '05/03/2022':11C '16':9A '2022':6A '35':10A 'chopin':4A 'freder':3A 'sale':1A
335	3	\N	\N	\N	\N	\N	2022-03-05 11:08:36.716714	\N	Sale for Pink Floyd on 2021-12-15 15:34 	62	'-12':7A '-15':8A '05/03/2022':11C '15':9A '2021':6A '34':10A 'floyd':4A 'pink':3A 'sale':1A
336	3	\N	\N	\N	\N	\N	2022-03-05 11:08:55.525295	\N	Sale for Agata Sp. Z.O.O on 2021-12-23 15:34 	63	'-12':8A '-23':9A '05/03/2022':12C '15':10A '2021':7A '34':11A 'agata':3A 'sale':1A 'sp':4A 'z.o.o':5A
337	3	\N	\N	\N	\N	\N	2022-03-05 11:10:38.377194	\N	Sale for Iron Maiden on 2021-12-16 13:37 	64	'-12':7A '-16':8A '05/03/2022':11C '13':9A '2021':6A '37':10A 'iron':3A 'maiden':4A 'sale':1A
338	3	\N	\N	\N	\N	\N	2022-03-05 11:11:11.442094	\N	Sale for Tina Turner on 2021-12-22 12:37 	65	'-12':7A '-22':8A '05/03/2022':11C '12':9A '2021':6A '37':10A 'sale':1A 'tina':3A 'turner':4A
339	5	\N	\N	\N	\N	\N	2022-03-05 11:12:39.129733	\N	kAMDRyzeGigabyte1233204oycrfjtetg-16	23	'-16':2A '05/03/2022':3C 'kamdryzegigabyte1233204oycrfjtetg':1A
340	1	\N	\N	\N	\N	\N	2022-03-05 18:44:50.985078	\N	\N	5	\N
341	1	\N	\N	\N	\N	\N	2022-03-05 18:45:40.364245	\N	\N	63	\N
342	1	\N	\N	\N	\N	\N	2022-03-05 18:45:51.661527	\N	\N	63	\N
343	0	\N	\N	\N	\N	\N	2022-03-05 20:55:11.787361	\N	Intel Core i7-11700K	104	'05/03/2022':6C '11700k':5A 'core':2A 'i7':4A 'i7-11700k':3A 'intel':1A
344	0	\N	\N	\N	\N	\N	2022-03-05 21:02:26.654638	\N	Intel Core i7-11700K	105	'05/03/2022':6C '11700k':5A 'core':2A 'i7':4A 'i7-11700k':3A 'intel':1A
345	1	\N	\N	\N	\N	\N	2022-03-05 21:12:01.469139	\N	\N	86	\N
346	5	\N	\N	\N	\N	\N	2022-03-05 21:16:22.553869	\N	kIntelCoGigabyte031122mohrcdq61mf-03	24	'-03':2A '05/03/2022':3C 'kintelcogigabyte031122mohrcdq61mf':1A
347	5	\N	\N	\N	\N	\N	2022-03-05 21:19:46.513104	\N	kIntelCoGigabyte0318029dhghkhnxg-02	25	'-02':2A '05/03/2022':3C 'kintelcogigabyte0318029dhghkhnxg':1A
348	12	\N	\N	\N	\N	\N	2022-03-05 21:58:48.958478	\N	John Smith	42	'05/03/2022':3C 'john':1A 'smith':2A
349	2	\N	\N	\N	\N	\N	2022-03-05 21:59:38.481985	\N	John Smith	42	'05/03/2022':3C 'john':1A 'smith':2A
350	12	\N	\N	\N	\N	\N	2022-03-05 22:00:37.901963	\N	John Smith	43	'05/03/2022':3C 'john':1A 'smith':2A
351	13	\N	\N	\N	\N	\N	2022-03-05 22:03:51.513755	\N	Robert Kubica	43	'05/03/2022':3C 'kubica':2A 'robert':1A
352	12	\N	\N	\N	\N	\N	2022-03-05 22:33:16.901168	\N	John Smith	44	'05/03/2022':3C 'john':1A 'smith':2A
353	13	\N	\N	\N	\N	\N	2022-03-05 22:37:42.407814	\N	John Smith	44	'05/03/2022':3C 'john':1A 'smith':2A
354	13	\N	\N	\N	\N	\N	2022-03-05 22:38:08.020326	\N	John Smith	44	'05/03/2022':3C 'john':1A 'smith':2A
355	13	\N	\N	\N	\N	\N	2022-03-05 22:39:30.976546	\N	John Smith	44	'05/03/2022':3C 'john':1A 'smith':2A
356	15	\N	\N	\N	\N	\N	2022-03-05 22:50:02.840224	\N	Supplior	28	'05/03/2022':2C 'supplior':1A
357	16	\N	\N	\N	\N	\N	2022-03-05 22:51:56.794143	\N	Supplior	28	'05/03/2022':2C 'supplior':1A
358	3	\N	\N	\N	\N	\N	2022-03-05 23:49:42.412596	\N	Sale for John Smith on 2022-03-03 00:45 	66	'-03':7A,8A '00':9A '05/03/2022':11C '2022':6A '45':10A 'john':3A 'sale':1A 'smith':4A
359	3	\N	\N	\N	\N	\N	2022-03-06 01:06:28.493773	\N	Sale for John Smith on 2022-03-06 02:03 	67	'-03':7A '-06':8A '02':9A '03':10A '06/03/2022':11C '2022':6A 'john':3A 'sale':1A 'smith':4A
360	8	\N	\N	\N	\N	\N	2022-03-06 03:50:47.226271	\N	There's something wrong with the power supply	12	'06/03/2022':9C 'power':7A 'someth':3A 'suppli':8A 'wrong':4A
361	8	\N	\N	\N	\N	\N	2022-03-06 04:06:46.374529	\N	There's something wrong with the power supply	13	'06/03/2022':9C 'power':7A 'someth':3A 'suppli':8A 'wrong':4A
362	9	\N	\N	\N	\N	\N	2022-03-06 04:06:53.165054	\N	There's something wrong with the power supply	13	'06/03/2022':9C 'power':7A 'someth':3A 'suppli':8A 'wrong':4A
\.


--
-- Data for Name: order_chunks; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.order_chunks (id, part_id, sell_price, quantity, belonging_order_id, computer_id) FROM stdin;
9	90	50.00	1	23	\N
10	90	50.00	1	24	\N
11	\N	2300.00	1	24	17
16	58	370.00	1	26	\N
17	\N	10520.00	1	26	21
18	52	350.00	1	26	\N
19	62	199.00	1	26	\N
20	101	6199.00	1	27	\N
21	85	2499.00	1	28	\N
22	77	329.00	1	29	\N
23	82	3369.00	1	30	\N
25	59	739.00	1	31	\N
26	98	689.00	1	32	\N
27	99	349.00	1	32	\N
28	69	2399.00	1	33	\N
29	70	619.00	1	33	\N
30	66	1619.00	3	34	\N
31	\N	1599.00	1	34	13
32	\N	2190.00	1	34	15
33	77	329.00	1	35	\N
34	77	329.00	1	36	\N
35	101	6199.00	1	36	\N
36	98	689.00	1	36	\N
37	76	1410.00	1	37	\N
38	5	2800.00	2	38	\N
39	68	1120.00	1	38	\N
40	35	2120.00	3	39	\N
41	\N	8800.00	1	39	4
42	60	1320.00	1	39	\N
43	96	349.00	1	40	\N
44	93	139.00	1	41	\N
45	70	619.00	1	42	\N
46	72	816.00	1	42	\N
47	68	1120.00	1	43	\N
48	91	639.00	1	43	\N
49	82	3369.00	1	44	\N
50	62	211.00	1	45	\N
51	36	2169.00	3	46	\N
52	79	5999.00	1	47	\N
53	57	11299.00	1	47	\N
54	88	419.00	1	48	\N
55	\N	4600.00	1	48	2
56	98	689.00	1	49	\N
57	91	639.00	1	50	\N
58	78	819.00	1	50	\N
59	66	1499.00	1	50	\N
60	28	420.00	1	51	\N
61	27	144.00	1	51	\N
62	48	119.00	3	52	\N
63	24	970.00	1	53	\N
64	50	580.00	1	54	\N
65	46	566.00	1	55	\N
66	\N	5600.00	1	55	14
67	41	260.00	1	55	\N
68	81	13100.00	1	56	\N
69	1	1720.00	1	57	\N
70	62	211.00	1	58	\N
71	29	800.00	1	59	\N
72	103	1230.00	1	60	\N
73	7	2200.00	1	60	\N
74	42	599.99	1	61	\N
75	\N	9220.00	1	61	5
76	44	619.00	1	61	\N
77	42	599.99	1	62	\N
78	55	199.00	2	63	\N
79	10	960.00	1	64	\N
80	9	520.00	1	64	\N
81	7	2200.00	1	64	\N
82	86	2819.00	1	65	\N
87	5	2899.00	2	67	\N
88	53	700.00	1	67	\N
89	48	119.00	2	67	\N
90	\N	15999.00	1	67	16
91	42	599.99	1	25	\N
92	\N	2260.00	1	25	20
\.


--
-- Data for Name: orders; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.orders (id, client_id, sell_date, name, document_with_weights) FROM stdin;
19	32	2022-03-05 07:02:00	Sale for Billy Idol on 2022-03-05 07:02 	'-03':7B '-05':8B '02':10B '07':9B '2022':6B 'billi':3B 'idol':4B 'sale':1B
20	5	2022-03-05 07:07:00	Sale for Mac Quayle on 2022-03-05 07:07 	'-03':7B '-05':8B '07':9B,10B '2022':6B 'mac':3B 'quayl':4B 'sale':1B
21	39	2022-03-05 07:12:00	Sale for Sinead O'Connor on 2022-03-05 07:12 	'-03':8B '-05':9B '07':10B '12':11B '2022':7B 'connor':5B 'o':4B 'sale':1B 'sinead':3B
22	38	2022-03-05 07:14:00	Sale for Led Zeppelin on 2022-03-05 07:14 	'-03':7B '-05':8B '07':9B '14':10B '2022':6B 'led':3B 'sale':1B 'zeppelin':4B
23	8	2022-03-05 07:16:00	Sale for Hulk Hogan on 2022-03-05 07:16 	'-03':7B '-05':8B '07':9B '16':10B '2022':6B 'hogan':4B 'hulk':3B 'sale':1B
24	12	2022-03-05 07:16:00	Sale for Frank Zappa on 2022-03-05 07:16 	'-03':7B '-05':8B '07':9B '16':10B '2022':6B 'frank':3B 'sale':1B 'zappa':4B
25	32	2022-03-05 07:22:00	Sale for Billy Idol on 2022-03-05 07:22 	'-03':7B '-05':8B '07':9B '2022':6B '22':10B 'billi':3B 'idol':4B 'sale':1B
26	40	2022-03-05 09:38:00	Order Made by the Special One	'made':2B 'one':6B 'order':1B 'special':5B
27	41	2022-03-05 09:38:00	Sale for Mariusz Timm on 2022-03-05 09:38 	'-03':7B '-05':8B '09':9B '2022':6B '38':10B 'mariusz':3B 'sale':1B 'timm':4B
28	29	2022-03-05 09:38:00	Sale for Sonic Youth on 2022-03-05 09:38 	'-03':7B '-05':8B '09':9B '2022':6B '38':10B 'sale':1B 'sonic':3B 'youth':4B
29	31	2022-03-03 13:38:00	Sale for Peter Schilling on 2022-03-03 13:38 	'-03':7B,8B '13':9B '2022':6B '38':10B 'peter':3B 'sale':1B 'schill':4B
30	30	2022-03-05 09:38:00	Sale for Fugazi on 2022-03-05 09:38 	'-03':6B '-05':7B '09':8B '2022':5B '38':9B 'fugazi':3B 'sale':1B
31	23	2022-03-05 09:38:00	Sale for Alex Kommt on 2022-03-05 09:38 	'-03':7B '-05':8B '09':9B '2022':6B '38':10B 'alex':3B 'kommt':4B 'sale':1B
32	39	2022-03-03 15:48:00	Sale for Sinead O'Connor on 2022-03-03 15:48 	'-03':8B,9B '15':10B '2022':7B '48':11B 'connor':5B 'o':4B 'sale':1B 'sinead':3B
33	36	2022-03-02 13:50:00	Sale for Weather Report on 2022-03-02 13:50 	'-02':8B '-03':7B '13':9B '2022':6B '50':10B 'report':4B 'sale':1B 'weather':3B
34	15	2022-03-05 09:48:00	Sale for Agata Sp. Z.O.O on 2022-03-05 09:48 	'-03':8B '-05':9B '09':10B '2022':7B '48':11B 'agata':3B 'sale':1B 'sp':4B 'z.o.o':5B
35	29	2022-02-28 14:03:00	Sale for Sonic Youth on 2022-02-28 14:03 	'-02':7B '-28':8B '03':10B '14':9B '2022':6B 'sale':1B 'sonic':3B 'youth':4B
36	23	2022-02-25 16:59:00	Sale for Alex Kommt on 2022-02-25 16:59 	'-02':7B '-25':8B '16':9B '2022':6B '59':10B 'alex':3B 'kommt':4B 'sale':1B
37	33	2022-02-24 13:57:00	Sale for Gary Moore on 2022-02-24 13:57 	'-02':7B '-24':8B '13':9B '2022':6B '57':10B 'gari':3B 'moor':4B 'sale':1B
38	21	2022-03-05 10:08:00	Sale for Pink Floyd on 2022-03-05 10:08 	'-03':7B '-05':8B '08':10B '10':9B '2022':6B 'floyd':4B 'pink':3B 'sale':1B
39	19	2022-02-19 14:08:00	Sale for Robert Lewandowski on 2022-02-19 14:08 	'-02':7B '-19':8B '08':10B '14':9B '2022':6B 'lewandowski':4B 'robert':3B 'sale':1B
40	5	2022-02-17 14:14:00	Sale for Mac Quayle on 2022-02-17 14:14 	'-02':7B '-17':8B '14':9B,10B '2022':6B 'mac':3B 'quayl':4B 'sale':1B
41	4	2022-03-05 10:14:00	Sale for Mordo Muzik on 2022-03-05 10:14 	'-03':7B '-05':8B '10':9B '14':10B '2022':6B 'mordo':3B 'muzik':4B 'sale':1B
42	1	2022-02-12 14:14:00	Sale for Ozzy Osbourne on 2022-02-12 14:14 	'-02':7B '-12':8B '14':9B,10B '2022':6B 'osbourn':4B 'ozzi':3B 'sale':1B
43	24	2022-02-19 15:14:00	Sale for The Bill on 2022-02-19 15:14 	'-02':7B '-19':8B '14':10B '15':9B '2022':6B 'bill':4B 'sale':1B
44	25	2022-02-10 04:19:00	Sale for Joe Satriani on 2022-02-10 04:19 	'-02':7B '-10':8B '04':9B '19':10B '2022':6B 'joe':3B 'sale':1B 'satriani':4B
45	41	2022-02-04 13:19:00	Sale for Mariusz Timm on 2022-02-04 13:19 	'-02':7B '-04':8B '13':9B '19':10B '2022':6B 'mariusz':3B 'sale':1B 'timm':4B
46	20	2022-02-06 15:30:00	Sale for Iron Maiden on 2022-02-06 15:30 	'-02':7B '-06':8B '15':9B '2022':6B '30':10B 'iron':3B 'maiden':4B 'sale':1B
47	15	2022-02-02 12:19:00	Sale for Agata Sp. Z.O.O on 2022-02-02 12:19 	'-02':8B,9B '12':10B '19':11B '2022':7B 'agata':3B 'sale':1B 'sp':4B 'z.o.o':5B
48	16	2022-01-25 16:23:00	Sale for Motley Crue on 2022-01-25 16:23 	'-01':7B '-25':8B '16':9B '2022':6B '23':10B 'crue':4B 'motley':3B 'sale':1B
49	22	2022-01-30 15:38:00	Sale for Mike Oldfield on 2022-01-30 15:38 	'-01':7B '-30':8B '15':9B '2022':6B '38':10B 'mike':3B 'oldfield':4B 'sale':1B
50	18	2022-01-28 15:39:00	Sale for Uriah Heep on 2022-01-28 15:39 	'-01':7B '-28':8B '15':9B '2022':6B '39':10B 'heep':4B 'sale':1B 'uriah':3B
51	2	2022-01-27 15:43:00	Sale for Mariusz Janewski on 2022-01-27 15:43 	'-01':7B '-27':8B '15':9B '2022':6B '43':10B 'janewski':4B 'mariusz':3B 'sale':1B
52	8	2022-01-27 16:43:00	Sale for Hulk Hogan on 2022-01-27 16:43 	'-01':7B '-27':8B '16':9B '2022':6B '43':10B 'hogan':4B 'hulk':3B 'sale':1B
53	17	2022-03-05 10:38:00	Sale for Oingo Boingo on 2022-03-05 10:38 	'-03':7B '-05':8B '10':9B '2022':6B '38':10B 'boingo':4B 'oingo':3B 'sale':1B
54	6	2022-01-19 15:13:00	Sale for Jeff Beck on 2022-01-19 15:13 	'-01':7B '-19':8B '13':10B '15':9B '2022':6B 'beck':4B 'jeff':3B 'sale':1B
55	26	2022-01-20 15:15:00	Sale for John Lennon on 2022-01-20 15:15 	'-01':7B '-20':8B '15':9B,10B '2022':6B 'john':3B 'lennon':4B 'sale':1B
56	27	2022-01-14 14:18:00	Sale for Billy Joel on 2022-01-14 14:18 	'-01':7B '-14':8B '14':9B '18':10B '2022':6B 'billi':3B 'joel':4B 'sale':1B
57	14	2022-01-08 15:16:00	Sale for Judas Priest on 2022-01-08 15:16 	'-01':7B '-08':8B '15':9B '16':10B '2022':6B 'juda':3B 'priest':4B 'sale':1B
58	3	2022-01-01 16:16:00	Sale for Michael Jackson on 2022-01-01 16:16 	'-01':7B,8B '16':9B,10B '2022':6B 'jackson':4B 'michael':3B 'sale':1B
59	17	2022-01-07 14:14:00	Sale for Oingo Boingo on 2022-01-07 14:14 	'-01':7B '-07':8B '14':9B,10B '2022':6B 'boingo':4B 'oingo':3B 'sale':1B
60	7	2022-01-08 16:36:00	Sale for Franek Kimono on 2022-01-08 16:36 	'-01':7B '-08':8B '16':9B '2022':6B '36':10B 'franek':3B 'kimono':4B 'sale':1B
61	10	2022-01-02 16:35:00	Sale for Frederic Chopin on 2022-01-02 16:35 	'-01':7B '-02':8B '16':9B '2022':6B '35':10B 'chopin':4B 'freder':3B 'sale':1B
62	21	2021-12-15 15:34:00	Sale for Pink Floyd on 2021-12-15 15:34 	'-12':7B '-15':8B '15':9B '2021':6B '34':10B 'floyd':4B 'pink':3B 'sale':1B
63	15	2021-12-23 15:34:00	Sale for Agata Sp. Z.O.O on 2021-12-23 15:34 	'-12':8B '-23':9B '15':10B '2021':7B '34':11B 'agata':3B 'sale':1B 'sp':4B 'z.o.o':5B
64	20	2021-12-16 13:37:00	Sale for Iron Maiden on 2021-12-16 13:37 	'-12':7B '-16':8B '13':9B '2021':6B '37':10B 'iron':3B 'maiden':4B 'sale':1B
65	37	2021-12-22 12:37:00	Sale for Tina Turner on 2021-12-22 12:37 	'-12':7B '-22':8B '12':9B '2021':6B '37':10B 'sale':1B 'tina':3B 'turner':4B
67	44	2022-03-06 02:03:00	Sale for John Smith on 2022-03-06 02:03 	'-03':7B '-06':8B '02':9B '03':10B '2022':6B 'john':3B 'sale':1B 'smith':4B
\.


--
-- Data for Name: parts; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.parts (id, name, stock, price, purchase_date, short_note, supplier_id, segment_id, document_with_weights, suggested_price) FROM stdin;
5	ASUS Radeon RX 6600 Dual 8GB GDDR6	1	2420.00	2022-02-26 17:20:00	\N	13	3	'26/02/2022':11 '6600':4A '8gb':6A 'asus':1A 'card':10 'dual':5A 'gddr6':7A 'gotel':8C 'graphic':9 'radeon':2A 'rx':3A	2800.00
79	ASUS ROG Zenith II Extreme	5	5172.48	2022-02-24 17:27:00	\N	12	2	'24/02/2022':8 'asus':1A 'elektroklik':6C 'extrem':5A 'ii':4A 'motherboard':7 'rog':2A 'zenith':3A	5999.00
1	AMD Ryzen 7 5700G	18	1620.00	2022-03-04 22:59:00	\N	1	1	'04/03/2022':7 '5700g':4A '7':3A 'amd':1A 'bns':5C 'processor':6 'ryzen':2A	1720.00
38	ASUS PCE‑AX58BT (3000Mb/s a/b/g/n/ax) BT 5.0	9	349.00	2021-12-23 16:56:00	\N	2	12	'23/12/2021':13 '3000mb/s':4A '5.0':7A 'a/b/g/n/ax':5A 'asus':1A 'ax58bt':3A 'bt':6A 'card':12 'g.d':8C 'intern':9C 'network':11 'pce':2A 'poland':10C	390.00
103	Gigabyte Z690 UD DDR4	3	1079.00	2022-02-05 15:37:00	\N	27	2	'05/02/2022':7 'ddr4':4A 'gigabyt':1A 'motherboard':6 'prolin':5C 'ud':3A 'z690':2A	1230.00
104	Intel Core i7-11700K	4	1649.00	2022-03-05 21:52:00	\N	6	1	'05/03/2022':9 '11700k':5A 'core':2A 'deliveri':7C 'i7':4A 'i7-11700k':3A 'intel':1A 'kuki':6C 'processor':8	1999.00
77	be quiet! System Power 9 600W 80 Plus Bronze	25	289.00	2021-12-31 04:21:00	\N	18	7	'31/12/2021':15 '600w':6A '80':7A '9':5A 'bronz':9A 'plus':8A 'power':4A,13 'quiet':2A 'sale':12C 'suppli':14 'supra':11C 'system':3A 'toyota':10C	329.00
96	SSD Samsung 970 EVO Plus 250 GB M.2 2280 PCI-E x4 Gen3 NVMe	11	279.00	2021-11-20 13:53:00	\N	9	6	'20/11/2021':20 '2280':9A '250':6A '970':3A 'e':12A 'elektronik':17C 'evo':4A 'gb':7A 'gen3':14A 'm.2':8A 'nowi':16C 'nvme':15A 'pci':11A 'pci-e':10A 'plus':5A 'samsung':2A 'ssd':1A,18 'storag':19 'x4':13A	349.00
70	Gigabyte Z590 D	6	559.00	2022-03-05 01:36:00	\N	20	2	'05/03/2022':8 'd':3A 'deep':4C 'gigabyt':1A 'hurt':6C 'motherboard':7 'purpl':5C 'z590':2A	619.00
85	Seagate FireCuda 510 2 TB M.2 2280 PCI-E x4 Gen3 NVMe	5	2276.00	2022-01-02 12:50:00	\N	27	6	'02/01/2022':17 '2':4A '2280':7A '510':3A 'e':10A 'firecuda':2A 'gen3':12A 'm.2':6A 'nvme':13A 'pci':9A 'pci-e':8A 'prolin':14C 'seagat':1A 'ssd':15 'storag':16 'tb':5A 'x4':11A	2499.00
55	TP-Link Archer C6 (1200Mb/s a/b/g/n/ac) DualBand	6	159.00	2021-10-12 17:36:00	\N	26	19	'12/10/2021':12 '1200mb/s':6A 'a/b/g/n/ac':7A 'archer':4A 'c6':5A 'dualband':8A 'euro/agd':10C 'link':3A 'nightwish':9C 'router':11 'tp':2A 'tp-link':1A	199.00
66	Acer Nitro VG271USBMIIPX czarny HDR 165Hz	3	1399.00	2022-01-21 11:51:00	\N	6	11	'165hz':6A '21/01/2022':10 'acer':1A 'czarni':4A 'deliveri':8C 'hdr':5A 'kuki':7C 'monitor':9 'nitro':2A 'vg271usbmiipx':3A	1499.00
65	Silver Monkey X SMGK1000 Kailh Brown RGB	9	269.00	2022-01-14 06:38:00	\N	7	14	'14/01/2022':11 'arctic':8C 'brown':6A 'kailh':5A 'keyboard':10 'monkey':2A,9C 'rgb':7A 'silver':1A 'smgk1000':4A 'x':3A	299.00
59	Microsoft Windows 11 PRO PL 64bit OEM DVD	6	649.00	2021-09-10 13:51:00	\N	6	21	'10/09/2021':12 '11':3A '64bit':6A 'deliveri':10C 'dvd':8A 'kuki':9C 'licens':11 'microsoft':1A 'oem':7A 'pl':5A 'pro':4A 'window':2A	739.00
28	be quiet! Dark Rock Pro 4 120/135mm	10	379.00	2022-01-11 13:53:00	\N	13	8	'11/01/2022':10 '120/135mm':7A '4':6A 'cool':9 'dark':3A 'gotel':8C 'pro':5A 'quiet':2A 'rock':4A	420.00
81	AMD Radeon PRO W6800 32GB GDDR6	5	11799.00	2022-02-10 02:21:00	\N	27	3	'10/02/2022':10 '32gb':5A 'amd':1A 'card':9 'gddr6':6A 'graphic':8 'pro':3A 'prolin':7C 'radeon':2A 'w6800':4A	13100.00
53	ASRock B560M Steel Legend	4	559.00	2021-10-21 14:33:00	\N	1	2	'21/10/2021':7 'asrock':1A 'b560m':2A 'bns':5C 'legend':4A 'motherboard':6 'steel':3A	626.00
25	Gigabyte GeForce RTX 3060 AORUS ELITE LHR 12GB GDDR6	4	3399.00	2022-01-17 20:53:00	\N	9	3	'12gb':8A '17/01/2022':14 '3060':4A 'aorus':5A 'card':13 'elektronik':11C 'elit':6A 'gddr6':9A 'geforc':2A 'gigabyt':1A 'graphic':12 'lhr':7A 'nowi':10C 'rtx':3A	3800.00
105	Intel Core i7-11700K	4	1699.00	2022-03-05 21:52:00	\N	6	1	'05/03/2022':9 '11700k':5A 'core':2A 'deliveri':7C 'i7':4A 'i7-11700k':3A 'intel':1A 'kuki':6C 'processor':8	1899.00
3	MSI B560‑A PRO	7	560.00	2022-03-04 23:01:00	\N	7	2	'04/03/2022':8 'arctic':5C 'b560':2A 'monkey':6C 'motherboard':7 'msi':1A 'pro':4A	620.00
57	AMD Ryzen Threadripper 3970X	6	9899.00	2021-10-03 01:36:00	\N	1	1	'03/10/2021':7 '3970x':4A 'amd':1A 'bns':5C 'processor':6 'ryzen':2A 'threadripp':3A	11299.00
72	Phanteks Eclipse P500A DRGB Czarna	5	729.00	2022-02-20 16:07:00	\N	19	9	'20/02/2022':10 'case':9 'comput':8 'czarna':5A 'door':7C 'drgb':4A 'eclips':2A 'p500a':3A 'phantek':1A	816.00
62	Huion H640P	9	179.00	2021-08-21 18:58:00	\N	2	27	'21/08/2021':8 'draw':6 'g.d':3C 'h640p':2A 'huion':1A 'intern':4C 'poland':5C 'tablet':7	211.00
44	SteelSeries Apex 5	6	558.99	2021-11-26 17:56:00	\N	16	14	'26/11/2021':6 '5':3A 'action':4C 'apex':2A 'keyboard':5 'steelseri':1A	619.00
83	be quiet! Dark Power PRO 12 1500W (BN312)	6	1999.00	2022-02-20 16:50:00	\N	15	7	'12':6A '1500w':7A '20/02/2022':13 'ab':9C 'bn312':8A 'dark':3A 'hurt':10C 'power':4A,11 'pro':5A 'quiet':2A 'suppli':12	2290.00
100	Gigabyte Radeon RX 6800 XT GAMING OC 16GB GDDR6	7	5699.00	2021-11-17 09:47:00	\N	27	3	'16gb':8A '17/11/2021':13 '6800':4A 'card':12 'game':6A 'gddr6':9A 'gigabyt':1A 'graphic':11 'oc':7A 'prolin':10C 'radeon':2A 'rx':3A 'xt':5A	6000.00
74	NZXT H510 Flow White	6	439.00	2022-02-17 14:31:00	\N	15	9	'17/02/2022':9 'ab':5C 'case':8 'comput':7 'flow':3A 'h510':2A 'hurt':6C 'nzxt':1A 'white':4A	499.00
78	Gigabyte Z590 UD AC	5	719.00	2022-03-05 04:21:00	A rocket lake motherboard (for 11th gen procs)	8	2	'05/03/2022':15 '11th':10B 'ac':4A 'botland':13C 'gen':11B 'gigabyt':1A 'lake':7B 'motherboard':8B,14 'proc':12B 'rocket':6B 'ud':3A 'z590':2A	819.00
71	Corsair TX850M 850W 80 Plus Gold	6	459.00	2022-02-17 13:15:00	\N	4	7	'17/02/2022':10 '80':4A '850w':3A 'aptel':7C 'corsair':1A 'gold':6A 'plus':5A 'power':8 'suppli':9 'tx850m':2A	519.00
88	Patriot 16GB (2x8GB) 3600MHz CL18 Viper Steel	8	359.00	2021-12-10 16:52:00	\N	10	4	'10/12/2021':10 '16gb':2A '2x8gb':3A '3600mhz':4A 'cl18':5A 'meta':8C 'patriot':1A 'ram':9 'steel':7A 'viper':6A	419.00
91	Dysk WD Black 2 TB 3.5" SATA III (WD2003FZEX)	12	579.00	2021-11-16 16:52:00	\N	27	5	'16/11/2021':13 '2':4A '3.5':6A 'black':3A 'dysk':1A 'hdd':11 'iii':8A 'prolin':10C 'sata':7A 'storag':12 'tb':5A 'wd':2A 'wd2003fzex':9A	639.00
48	HP 103AD dual pack	8	99.00	2021-11-17 13:58:00	\N	11	16	'103ad':2A '17/11/2021':8 'bodex':5C 'dual':3A 'hp':1A 'ink':7 'pack':4A 'printer':6	119.00
68	G.SKILL 32GB (2x16GB) 3600MHz CL16 TridentZ RGB Neo	5	979.00	2022-03-05 01:38:00	\N	16	4	'05/03/2022':11 '2x16gb':3A '32gb':2A '3600mhz':4A 'action':9C 'cl16':5A 'g.skill':1A 'neo':8A 'ram':10 'rgb':7A 'tridentz':6A	1120.00
9	Crucial 16GB (2x8GB) 3600MHz CL16 Ballistix Black RGB	5	449.00	2022-02-13 16:19:00	\N	10	4	'13/02/2022':11 '16gb':2A '2x8gb':3A '3600mhz':4A 'ballistix':6A 'black':7A 'cl16':5A 'crucial':1A 'meta':9C 'ram':10 'rgb':8A	520.00
17	Samsung 1TB M.2 PCIe NVMe 970 EVO Plus	4	599.00	2022-02-15 18:43:00	\N	22	6	'15/02/2022':12 '1tb':2A '970':6A 'evo':7A 'm.2':3A 'mgmt':9C 'nvme':5A 'pcie':4A 'plus':8A 'samsung':1A 'ssd':10 'storag':11	720.00
36	LG Ultragear 27GP850 NanoIPS HDR	3	1919.00	2021-12-31 12:53:00	\N	2	11	'27gp850':3A '31/12/2021':10 'g.d':6C 'hdr':5A 'intern':7C 'lg':1A 'monitor':9 'nanoip':4A 'poland':8C 'ultragear':2A	2169.00
15	Gigabyte GeForce GTX 1050 Ti 4GB GDDR5	6	1049.00	2022-02-19 17:43:00	\N	11	3	'1050':4A '19/02/2022':11 '4gb':6A 'bodex':8C 'card':10 'gddr5':7A 'geforc':2A 'gigabyt':1A 'graphic':9 'gtx':3A 'ti':5A	1090.00
12	Intel Celeron G5905	16	179.00	2022-03-04 23:01:00	Weak processor	9	1	'04/03/2022':9 'celeron':2A 'elektronik':7C 'g5905':3A 'intel':1A 'nowi':6C 'processor':5B,8 'weak':4B	240.00
29	ASUS ROG Strix 750W 80 Plus Gold	4	749.00	2022-01-08 14:53:00	\N	11	7	'08/01/2022':11 '750w':4A '80':5A 'asus':1A 'bodex':8C 'gold':7A 'plus':6A 'power':9 'rog':2A 'strix':3A 'suppli':10	800.00
13	Crucial 500GB 2,5" SATA SSD MX500	6	259.00	2022-03-04 00:43:00	\N	16	6	'04/03/2022':11 '2':3A '5':4A '500gb':2A 'action':8C 'crucial':1A 'mx500':7A 'sata':5A 'ssd':6A,9 'storag':10	320.00
6	Gigabyte B560M DS3H V2	7	399.00	2022-02-25 20:15:00	\N	10	2	'25/02/2022':7 'b560m':2A 'ds3h':3A 'gigabyt':1A 'meta':5C 'motherboard':6 'v2':4A	520.00
37	TP‑Link Archer T4U (1300Mb/s a/b/g/n/ac) DualBand	12	99.90	2021-12-28 13:53:00	\N	15	12	'1300mb/s':5A '28/12/2021':12 'a/b/g/n/ac':6A 'ab':8C 'archer':3A 'card':11 'dualband':7A 'hurt':9C 'link':2A 'network':10 't4u':4A 'tp':1A	110.00
43	Dell KB216‑B QuietKey USB (black)	22	43.99	2021-12-01 16:56:00	\N	2	14	'01/12/2021':11 'b':3A 'black':6A 'dell':1A 'g.d':7C 'intern':8C 'kb216':2A 'keyboard':10 'poland':9C 'quietkey':4A 'usb':5A	52.00
26	Intel Core i3‑10320	7	799.00	2022-01-14 13:53:00	\N	5	1	'10320':4A '14/01/2022':9 'avt':5C 'core':2A 'electron':6C 'i3':3A 'intel':1A 'processor':8 'shop':7C	845.00
34	Creative Sound BlasterX G5	6	539.00	2022-03-04 00:53:00	\N	7	10	'04/03/2022':9 'arctic':5C 'blasterx':3A 'card':8 'creativ':1A 'g5':4A 'monkey':6C 'sound':2A,7	600.00
33	MSI MAG Core Liquid 280R 2x140mm	5	489.00	2022-03-04 00:53:00	\N	26	8	'04/03/2022':10 '280r':5A '2x140mm':6A 'cool':9 'core':3A 'euro/agd':8C 'liquid':4A 'mag':2A 'msi':1A 'nightwish':7C	560.00
7	Intel Core i7‑12700KF	5	1949.00	2022-02-24 16:44:00	This came in fractured packaging	15	1	'12700kf':4A '24/02/2022':13 'ab':10C 'came':6B 'core':2A 'fractur':8B 'hurt':11C 'i7':3A 'intel':1A 'packag':9B 'processor':12	2200.00
10	Gigabyte Z590 AORUS MASTER	5	899.00	2022-02-19 18:19:00	\N	17	2	'19/02/2022':8 'aorus':3A 'avg':5C 'gigabyt':1A 'hurt':6C 'master':4A 'motherboard':7 'z590':2A	960.00
51	Logitech 2.1 Z333	9	239.00	2022-03-05 01:27:00	\N	4	17	'05/03/2022':6 '2.1':2A 'aptel':4C 'logitech':1A 'speaker':5 'z333':3A	270.00
14	Kingston FURY 32GB (2x16GB) 3200MHz CL16 Renegade Black	7	579.00	2022-01-22 15:43:00	\N	19	4	'22/01/2022':12 '2x16gb':4A '3200mhz':5A '32gb':3A 'black':8A 'cl16':6A 'door':10C 'furi':2A 'kingston':1A 'ram':11 'renegad':7A	660.00
18	AMD Ryzen 5 Pro 4650G OEM	10	879.00	2022-02-13 17:47:00	\N	5	1	'13/02/2022':11 '4650g':5A '5':3A 'amd':1A 'avt':7C 'electron':8C 'oem':6A 'pro':4A 'processor':10 'ryzen':2A 'shop':9C	960.00
4	KFA2 GeForce GTX 1660 Ti 1‑Click OC 6GB GDDR6	9	1999.00	2022-02-28 12:20:00	\N	12	3	'1':6A '1660':4A '28/02/2022':14 '6gb':9A 'card':13 'click':7A 'elektroklik':11C 'gddr6':10A 'geforc':2A 'graphic':12 'gtx':3A 'kfa2':1A 'oc':8A 'ti':5A	2240.00
11	Patriot 16GB (2x8GB) 3600MHz CL18 Viper Steel	8	359.00	2022-01-21 16:35:00	\N	18	4	'16gb':2A '21/01/2022':12 '2x8gb':3A '3600mhz':4A 'cl18':5A 'patriot':1A 'ram':11 'sale':10C 'steel':7A 'supra':9C 'toyota':8C 'viper':6A	420.00
19	Seagate BARRACUDA 2TB 7200rot. 256MB	21	255.00	2022-02-18 11:52:00	\N	4	5	'18/02/2022':9 '256mb':5A '2tb':3A '7200rot':4A 'aptel':6C 'barracuda':2A 'hdd':7 'seagat':1A 'storag':8	299.00
94	Corsair CV 550W 80 Plus Bronze	10	239.00	2022-02-10 09:47:00	\N	15	7	'10/02/2022':11 '550w':3A '80':4A 'ab':7C 'bronz':6A 'corsair':1A 'cv':2A 'hurt':8C 'plus':5A 'power':9 'suppli':10	277.00
49	Canon Pixma TS3451	9	269.00	2021-11-26 03:27:00	\N	17	15	'26/11/2021':7 'avg':4C 'canon':1A 'hurt':5C 'pixma':2A 'printer':6 'ts3451':3A	310.00
31	Corsair iCUE 5000T RGB Tempered Glass Black	5	1819.00	2022-01-07 16:10:00	\N	1	9	'07/01/2022':11 '5000t':3A 'black':7A 'bns':8C 'case':10 'comput':9 'corsair':1A 'glass':6A 'icu':2A 'rgb':4A 'temper':5A	2030.00
102	LC-Power Phenom Pro 512 GB M.2 2280 PCI-E x4 Gen3 NVMe	8	375.02	2021-09-24 18:52:00	\N	22	6	'2280':9A '24/09/2021':19 '512':6A 'e':12A 'gb':7A 'gen3':14A 'lc':2A 'lc-power':1A 'm.2':8A 'mgmt':16C 'nvme':15A 'pci':11A 'pci-e':10A 'phenom':4A 'power':3A 'pro':5A 'ssd':17 'storag':18 'x4':13A	419.00
54	Mozos MKIT‑700PRO V2	8	199.00	2022-03-05 01:27:00	Great voice recording!	23	18	'05/03/2022':11 '700pro':3A 'bgc':8C 'great':5B 'hurt':9C 'microphon':10 'mkit':2A 'mozo':1A 'record':7B 'v2':4A 'voic':6B	249.00
56	ASUS RT‑N12+ PLUS (300Mb/s b/g/n, 4xSSID, repeater)	8	69.99	2021-10-09 19:36:00	\N	12	19	'09/10/2021':11 '300mb/s':5A '4xssid':7A 'asus':1A 'b/g/n':6A 'elektroklik':9C 'n12':3A 'plus':4A 'repeat':8A 'router':10 'rt':2A	88.00
30	Creative Sound Blaster X AE‑5 Plus (PCI‑E)	7	619.00	2022-01-05 14:58:00	\N	21	10	'05/01/2022':15 '5':6A 'ae':5A 'blaster':3A 'card':14 'creativ':1A 'e':9A 'fagot':11C 'figo':10C 'pci':8A 'plus':7A 'sale':12C 'sound':2A,13 'x':4A	690.00
40	ASUS TUF GAMING Z690‑PLUS DDR4	6	1319.00	2021-12-17 14:56:00	\N	12	2	'17/12/2021':9 'asus':1A 'ddr4':6A 'elektroklik':7C 'game':3A 'motherboard':8 'plus':5A 'tuf':2A 'z690':4A	1420.00
47	Samsung MLT‑D111S black 1000 str.	10	249.00	2021-11-19 13:58:00	\N	24	16	'1000':5A '19/11/2021':10 'black':4A 'd111s':3A 'ink':9 'mlt':2A 'printer':8 'ramon':7C 'samsung':1A 'str':6A	299.00
75	Intel Core i9‑11900F	9	1699.00	2022-02-15 13:31:00	\N	11	1	'11900f':4A '15/02/2022':7 'bodex':5C 'core':2A 'i9':3A 'intel':1A 'processor':6	1899.00
58	Logitech C920 Pro Full HD	12	369.00	2021-09-29 03:36:00	\N	21	20	'29/09/2021':10 'c920':2A 'fagot':7C 'figo':6C 'full':4A 'hd':5A 'logitech':1A 'pro':3A 'sale':8C 'webcam':9	399.00
52	Creative T60	6	329.00	2021-10-28 13:27:00	\N	19	17	'28/10/2021':6 'creativ':1A 'door':4C 'speaker':5 't60':2A	379.00
82	Corsair Obsidian 1000D	6	2849.00	2021-11-11 14:27:00	\N	27	9	'1000d':3A '11/11/2021':7 'case':6 'comput':5 'corsair':1A 'obsidian':2A 'prolin':4C	3369.00
101	ASUS GeForce RTX 3070 Ti ROG STRIX OC 8GB GDDR6X	5	5799.00	2022-03-05 05:47:00	\N	19	3	'05/03/2022':15 '3070':4A '8gb':9A 'asus':1A 'card':14 'door':12C 'gddr6x':10A 'geforc':2A 'graphic':13 'oc':8A 'rog':6A 'rtx':3A 'strix':7A 'ti':5A	6199.00
27	SilentiumPC Fera 5 120mm	30	125.00	2022-03-04 00:53:00	\N	3	8	'04/03/2022':7 '120mm':4A '5':3A 'cool':6 'fera':2A 'micro':5C 'silentiumpc':1A	144.00
24	Crucial 1TB M.2 PCIe Gen4 NVMe P5 Plus	4	848.00	2022-01-19 20:53:00	\N	11	6	'19/01/2022':12 '1tb':2A 'bodex':9C 'crucial':1A 'gen4':5A 'm.2':3A 'nvme':6A 'p5':7A 'pcie':4A 'plus':8A 'ssd':10 'storag':11	970.00
46	Apple Magic Keyboard (US Int.)	8	499.00	2021-11-20 11:56:00	\N	21	14	'20/11/2021':10 'appl':1A 'fagot':7C 'figo':6C 'int':5A 'keyboard':3A,9 'magic':2A 'sale':8C 'us':4A	566.00
22	SilentiumPC Vero L3 700W 80 Plus Bronze	10	289.00	2022-01-22 13:53:00	\N	25	7	'22/01/2022':11 '700w':4A '80':5A 'alphavill':8C 'bronz':7A 'l3':3A 'plus':6A 'power':9 'silentiumpc':1A 'suppli':10 'vero':2A	330.00
2	Intel Core i5‑11400F	8	769.00	2022-03-02 12:20:00	\N	6	1	'02/03/2022':8 '11400f':4A 'core':2A 'deliveri':6C 'i5':3A 'intel':1A 'kuki':5C 'processor':7	880.00
41	SteelSeries Rival 3 Wireless	8	219.00	2021-12-14 14:56:00	\N	16	13	'14/12/2021':7 '3':3A 'action':5C 'mous':6 'rival':2A 'steelseri':1A 'wireless':4A	260.00
69	Intel Core i9‑11900KF	7	2199.00	2021-12-18 12:42:00	\N	18	1	'11900kf':4A '18/12/2021':9 'core':2A 'i9':3A 'intel':1A 'processor':8 'sale':7C 'supra':6C 'toyota':5C	2399.00
39	Intel Core i9‑10980XE	8	5299.00	2021-12-16 14:56:00	\N	26	1	'10980xe':4A '16/12/2021':8 'core':2A 'euro/agd':6C 'i9':3A 'intel':1A 'nightwish':5C 'processor':7	5640.00
60	Microsoft Office Home & Business 2021 ESD	6	1199.90	2022-03-05 01:38:00	\N	10	21	'05/03/2022':9 '2021':5A 'busi':4A 'esd':6A 'home':3A 'licens':8 'meta':7C 'microsoft':1A 'offic':2A	1320.00
95	GOODRAM 8GB (1x8GB) 2666MHz CL16 IRDM X Black	7	155.00	2021-12-31 13:47:00	\N	17	4	'1x8gb':3A '2666mhz':4A '31/12/2021':12 '8gb':2A 'avg':9C 'black':8A 'cl16':5A 'goodram':1A 'hurt':10C 'irdm':6A 'ram':11 'x':7A	189.00
64	Gigabyte B550 GAMING X V2	7	419.00	2022-02-23 14:43:00	\N	6	2	'23/02/2022':9 'b550':2A 'deliveri':7C 'game':3A 'gigabyt':1A 'kuki':6C 'motherboard':8 'v2':5A 'x':4A	489.00
42	Logitech G PRO X SUPERLIGHT Czarny	7	549.00	2021-12-03 16:56:00	\N	10	13	'03/12/2021':9 'czarni':6A 'g':2A 'logitech':1A 'meta':7C 'mous':8 'pro':3A 'superlight':5A 'x':4A	599.99
84	SanDisk Ultra 3D SSD 4TB 560/530 Sata III 2,5	7	1749.00	2022-01-14 12:46:00	\N	11	6	'14/01/2022':14 '2':9A '3d':3A '4tb':5A '5':10A '560/530':6A 'bodex':11C 'iii':8A 'sandisk':1A 'sata':7A 'ssd':4A,12 'storag':13 'ultra':2A	1999.00
80	Kingston FURY 128GB (4x32GB) 3200MHz CL16 Beast Black	7	3799.00	2022-03-03 13:26:00	\N	27	4	'03/03/2022':11 '128gb':3A '3200mhz':5A '4x32gb':4A 'beast':7A 'black':8A 'cl16':6A 'furi':2A 'kingston':1A 'prolin':9C 'ram':10	4199.00
67	Gigabyte 16GB (2x8GB) 3333Mhz CL18 Aorus RGB	8	359.00	2022-03-05 01:38:00	\N	11	4	'05/03/2022':10 '16gb':2A '2x8gb':3A '3333mhz':4A 'aorus':6A 'bodex':8C 'cl18':5A 'gigabyt':1A 'ram':9 'rgb':7A	420.00
16	ASUS TUF GAMING Z590‑PLUS	7	699.00	2022-02-17 20:43:00	Nice TUF motherboard	21	2	'17/02/2022':13 'asus':1A 'fagot':10C 'figo':9C 'game':3A 'motherboard':8B,12 'nice':6B 'plus':5A 'sale':11C 'tuf':2A,7B 'z590':4A	780.00
20	Toshiba P300 1TB 7200rot. 64MB OEM	12	169.00	2022-02-03 14:52:00	\N	3	5	'03/02/2022':10 '1tb':3A '64mb':5A '7200rot':4A 'hdd':8 'micro':7C 'oem':6A 'p300':2A 'storag':9 'toshiba':1A	189.00
21	KFA2 GeForce RTX 2060 SUPER 1‑Click OC 8GB GDDR6	7	2899.00	2022-01-29 00:53:00	\N	23	3	'1':6A '2060':4A '29/01/2022':15 '8gb':9A 'bgc':11C 'card':14 'click':7A 'gddr6':10A 'geforc':2A 'graphic':13 'hurt':12C 'kfa2':1A 'oc':8A 'rtx':3A 'super':5A	3200.00
90	Logitech B100 Black USB	12	39.99	2021-11-19 16:52:00	\N	16	13	'19/11/2021':7 'action':5C 'b100':2A 'black':3A 'logitech':1A 'mous':6 'usb':4A	50.00
92	AMD Athlon 200GE, 3.2GHz, 4 MB, BOX	15	336.99	2022-03-02 05:47:00	\N	15	1	'02/03/2022':12 '200ge':3A '3.2':4A '4':6A 'ab':9C 'amd':1A 'athlon':2A 'box':8A 'ghz':5A 'hurt':10C 'mb':7A 'processor':11	376.00
73	SilentiumPC Armis AR6 TG	7	269.00	2022-03-05 04:21:00	\N	17	9	'05/03/2022':9 'ar6':3A 'armi':2A 'avg':5C 'case':8 'comput':7 'hurt':6C 'silentiumpc':1A 'tg':4A	319.00
8	Kingston FURY 16GB (2x8GB) 3200MHz CL16 Beast RGB	7	379.00	2022-03-04 23:01:00	\N	8	4	'04/03/2022':11 '16gb':3A '2x8gb':4A '3200mhz':5A 'beast':7A 'botland':9C 'cl16':6A 'furi':2A 'kingston':1A 'ram':10 'rgb':8A	420.00
61	WD 500GB M.2 PCIe NVMe Blue SN570	6	269.00	2021-09-08 15:54:00	\N	8	6	'08/09/2021':11 '500gb':2A 'blue':6A 'botland':8C 'm.2':3A 'nvme':5A 'pcie':4A 'sn570':7A 'ssd':9 'storag':10 'wd':1A	299.00
76	Intel Core i5‑12600KF	7	1299.00	2022-02-12 11:31:00	\N	15	1	'12/02/2022':8 '12600kf':4A 'ab':5C 'core':2A 'hurt':6C 'i5':3A 'intel':1A 'processor':7	1410.00
99	ASRock B450M-HDV R4.0	10	285.00	2021-12-09 17:53:00	\N	20	2	'09/12/2021':10 'asrock':1A 'b450m':3A 'b450m-hdv':2A 'deep':6C 'hdv':4A 'hurt':8C 'motherboard':9 'purpl':7C 'r4.0':5A	349.00
93	MSI A320M-A Pro	11	112.00	2022-02-19 05:47:00	Burdget motherboard 	27	2	'19/02/2022':10 'a320m':3A 'a320m-a':2A 'burdget':6B 'motherboard':7B,9 'msi':1A 'pro':5A 'prolin':8C	139.00
98	AMD Athlon 3000G, 3.5GHz, 4 MB, BOX	12	629.00	2021-12-07 17:53:00	\N	16	1	'07/12/2021':11 '3.5':4A '3000g':3A '4':6A 'action':9C 'amd':1A 'athlon':2A 'box':8A 'ghz':5A 'mb':7A 'processor':10	689.00
63	MSI Radeon RX6700 MECH 2X 8GB GDDR6	8	2599.00	2022-02-25 13:43:00	\N	9	3	'25/02/2022':12 '2x':5A '8gb':6A 'card':11 'elektronik':9C 'gddr6':7A 'graphic':10 'mech':4A 'msi':1A 'nowi':8C 'radeon':2A 'rx6700':3A	2499.00
86	AMD Ryzen 9 3900X, 3.8GHz, 64 MB, BOX	5	2349.00	2021-12-24 07:52:00	This one came in a fractured packaging	14	1	'24/12/2021':22 '3.8':5A '3900x':4A '64':7A '9':3A 'amd':1A 'box':9A 'came':12B 'fractur':15B 'ghz':6A 'gts':17C 'mb':8A 'o.o':20C 'one':11B 'packag':16B 'processor':21 'ryzen':2A 'sp':18C 'z':19C	2619.00
45	Kingston 1TB M.2 PCIe NVMe A2000	8	449.00	2021-11-23 09:56:00	\N	8	6	'1tb':2A '23/11/2021':10 'a2000':6A 'botland':7C 'kingston':1A 'm.2':3A 'nvme':5A 'pcie':4A 'ssd':8 'storag':9	490.00
32	be quiet! Pure Base 500DX Black	9	479.00	2022-03-04 00:53:00	\N	9	9	'04/03/2022':11 '500dx':5A 'base':4A 'black':6A 'case':10 'comput':9 'elektronik':8C 'nowi':7C 'pure':3A 'quiet':2A	550.00
89	be quiet! Pure Power 11 CM 600W 80 Plus Gold	8	399.00	2021-12-08 16:52:00	\N	15	7	'08/12/2021':15 '11':5A '600w':7A '80':8A 'ab':11C 'cm':6A 'gold':10A 'hurt':12C 'plus':9A 'power':4A,13 'pure':3A 'quiet':2A 'suppli':14	469.00
87	Asus PRIME B550M-A WI-FI	8	559.00	2021-12-15 11:52:00	\N	6	2	'15/12/2021':12 'asus':1A 'b550m':4A 'b550m-a':3A 'deliveri':10C 'fi':8A 'kuki':9C 'motherboard':11 'prime':2A 'wi':7A 'wi-fi':6A	619.00
97	SilentiumPC Signum SG1	15	209.00	2021-12-02 17:53:00	\N	5	9	'02/12/2021':9 'avt':4C 'case':8 'comput':7 'electron':5C 'sg1':3A 'shop':6C 'signum':2A 'silentiumpc':1A	249.00
23	EVGA SuperNOVA GA 750W 80 Plus Gold	6	499.00	2022-01-21 16:53:00	\N	9	7	'21/01/2022':12 '750w':4A '80':5A 'elektronik':9C 'evga':1A 'ga':3A 'gold':7A 'nowi':8C 'plus':6A 'power':10 'supernova':2A 'suppli':11	549.00
50	HP OfficeJet 8012e, ADF, Instant Ink, HP+	6	539.00	2021-11-10 03:27:00	\N	26	15	'10/11/2021':11 '8012e':3A 'adf':4A 'euro/agd':9C 'hp':1A,7A 'ink':6A 'instant':5A 'nightwish':8C 'officejet':2A 'printer':10	580.00
35	Dell S2721DGFA nanoIPS HDR	5	1919.00	2021-12-17 19:14:00	\N	20	11	'17/12/2021':9 'deep':5C 'dell':1A 'hdr':4A 'hurt':7C 'monitor':8 'nanoip':3A 'purpl':6C 's2721dgfa':2A	2120.00
\.


--
-- Data for Name: problems; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.problems (id, computer_id, problem_note, hand_in_date, deadline_date, finished, document_with_weights) FROM stdin;
1	9	Goes into a bootloop, after a while, it shows the information on lack of processor	2022-02-25 10:29:00	\N	f	'25/02/2022':16B 'bootloop':4A 'goe':1A 'inform':11A 'lack':13A 'processor':15A 'show':9A
5	17	The motherboard pins are slightly bent, probably happened during the transport	2022-02-17 06:31:00	\N	f	'17/02/2022':12B 'bent':6A 'happen':8A 'motherboard':2A 'pin':3A 'probabl':7A 'slight':5A 'transport':11A
9	13	Doesn't want to start :(	2022-03-03 13:33:00	\N	f	'03/03/2022':6B 'doesn':1A 'start':5A 'want':3A
10	5	Very high processor temperatures! Needs to be checked out	2022-02-16 11:33:00	2022-03-12 10:34:00	t	'12/03/2022':10B '16/02/2022':9B 'check':8A 'high':2A 'need':5A 'processor':3A 'temperatur':4A
11	19	The Client is not satisfied with cable management	2022-02-14 11:37:00	2022-03-11 10:37:00	t	'11/03/2022':10B '14/02/2022':9B 'cabl':7A 'client':2A 'manag':8A 'satisfi':5A
13	16	There's something wrong with the power supply	2022-03-06 05:06:00	2022-03-13 10:06:00	t	'06/03/2022':9B '13/03/2022':10B 'power':7A 'someth':3A 'suppli':8A 'wrong':4A
\.


--
-- Data for Name: segments; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.segments (id, name) FROM stdin;
1	Processor
2	Motherboard
3	Graphics Card
4	RAM
5	HDD Storage
6	SSD Storage
7	Power Supply
8	Cooling
9	Computer case
10	Sound card
11	Monitor
12	Network card
13	Mouse
14	Keyboard
15	Printer
16	Printer Ink
17	Speakers
18	Microphone
19	Router
20	Webcam
21	License
22	Bluetooth Module
23	Tablet
25	TV
26	Projectors
27	Drawing Tablet
28	Misc
24	Laptop
\.


--
-- Data for Name: suppliers; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.suppliers (id, name, join_date, website, email, phone, adress, nip, short_note, document_with_weights) FROM stdin;
1	BNS	2022-03-04 22:59:00	https://bns.com.pl/	biuro@bns.com.pl	48603088160	Tysiąclecia 31, 40-873 Katowice	5260215349	\N	'-873':9C '04/03/2022':11 '31':7C '40':8C '48603088160':2C '5260215349':5B 'biuro@bns.com.pl':3B 'bns':1A 'bns.com.pl':4B 'katowic':10C 'tysiąclecia':6C
2	G.D. International Poland	2022-02-16 23:01:00	https://gdpoland.pl/	office@gdpoland.pl	\N	Nadrzeczna 16, 05-552 Wólka Kosowska	\N	\N	'-552':9C '05':8C '16':7C '16/02/2022':12 'g.d':1A 'gdpoland.pl':5B 'intern':2A 'kosowska':11C 'nadrzeczna':6C 'office@gdpoland.pl':4B 'poland':3A 'wólka':10C
5	AVT Electronic Shop	2022-01-16 10:07:00	https://sklep.avt.pl/	\N	48222578449	ul. Leszczynowa 11 03-197 Warszawa	5242883738	\N	'-197':11C '03':10C '11':9C '16/01/2022':13 '48222578449':4C '5242883738':6B 'avt':1A 'electron':2A 'leszczynowa':8C 'shop':3A 'sklep.avt.pl':5B 'ul':7C 'warszawa':12C
4	Aptel	2022-02-13 14:59:00	http://www.aptel.pl/	\N	48730300467	\N	9662086519	\N	'13/02/2022':5 '48730300467':2C '9662086519':4B 'aptel':1A 'www.aptel.pl':3B
3	Micros 	2022-02-05 04:15:00	https://www.micros.com.pl/	\N	48126369566	Emila Godlewskiego 38, 30-198 Kraków	\N	\N	'-198':8C '05/02/2022':10 '30':7C '38':6C '48126369566':2C 'emila':4C 'godlewskiego':5C 'kraków':9C 'micro':1A 'www.micros.com.pl':3B
14	GTS SP. Z O.O.	2020-05-17 15:33:00	\N	gts@charlgts.pl	48564432324	\N	\N	Not great prices but fast shipping	'17/05/2020':13 '48564432324':11C 'fast':9C 'great':6C 'gts':1A 'gts@charlgts.pl':12B 'o.o':4A 'price':7C 'ship':10C 'sp':2A 'z':3A
19	The Doors	2021-10-22 03:01:00	\N	\N	\N	ul. Jimmiego Morrsona	5341643632	\N	'22/10/2021':7 '5341643632':3B 'door':2A 'jimmiego':5C 'morrsona':6C 'ul':4C
18	Toyota Supra Sales	2021-10-02 04:01:00	https://supra.com	\N	44565124652	\N	\N	\N	'02/10/2021':6 '44565124652':4C 'sale':3A 'supra':2A 'supra.com':5B 'toyota':1A
24	Ramones	2022-01-14 23:12:00	https://bop.pl	blitzkrieg@bop.pl	\N	\N	5315513513	\N	'14/01/2022':5 '5315513513':4B 'blitzkrieg@bop.pl':2B 'bop.pl':3B 'ramon':1A
23	BGC Hurt	2021-12-08 19:01:00	https://lufabgc.pl	bonus@lufabgc.pl	48564124465	\N	\N	\N	'08/12/2021':6 '48564124465':3C 'bgc':1A 'bonus@lufabgc.pl':4B 'hurt':2A 'lufabgc.pl':5B
26	Nightwish EURO/AGD	2022-03-04 23:01:00	phantomoftheopera.com	\N	48601200243	\N	\N	\N	'04/03/2022':5 '48601200243':3C 'euro/agd':2A 'nightwish':1A 'phantomoftheopera.com':4B
25	Alphaville	2022-02-08 05:01:00	https://alphaville.com	\N	\N	Tokyo 532, Japan	\N	\N	'08/02/2022':6 '532':4C 'alphavill':1A 'alphaville.com':2B 'japan':5C 'tokyo':3C
22	MGMT	2021-11-25 23:01:00	https://mgmt.com	contact@mgmt.com	\N	Bass Street 51, Connecticut	\N	\N	'25/11/2021':8 '51':6C 'bass':4C 'connecticut':7C 'contact@mgmt.com':2B 'mgmt':1A 'mgmt.com':3B 'street':5C
21	Figo Fagot Sales	2021-11-05 03:01:00	\N	\N	48609123609	Disco Street 53	\N	\N	'05/11/2021':8 '48609123609':4C '53':7C 'disco':5C 'fagot':2A 'figo':1A 'sale':3A 'street':6C
20	Deep Purple Hurt	2021-11-14 04:01:00	\N	\N	48531653653	\N	\N	Perfect Strangers!	'14/11/2021':7 '48531653653':6C 'deep':1A 'hurt':3A 'perfect':4C 'purpl':2A 'stranger':5C
17	AVG Hurt	2021-09-18 02:08:00	\N	hurt@avghaller.com	\N	\N	\N	\N	'18/09/2021':4 'avg':1A 'hurt':2A 'hurt@avghaller.com':3B
16	Action	2021-08-29 17:05:00	\N	\N	48223321600	ul. Dawidowska 10, 05-500 Piaseczno, Polska	\N	\N	'-500':7C '05':6C '10':5C '29/08/2021':10 '48223321600':2C 'action':1A 'dawidowska':4C 'piaseczno':8C 'polska':9C 'ul':3C
15	AB Hurt	2021-07-01 17:47:00	https://www.ab.pl/	sekretariat@ab.pl	48713937600	\N	\N	\N	'01/07/2021':6 '48713937600':3C 'ab':1A 'hurt':2A 'sekretariat@ab.pl':4B 'www.ab.pl':5B
13	Gotel	2021-06-26 12:01:00	\N	\N	48856777444	\N	9662101035	\N	'26/06/2021':4 '48856777444':2C '9662101035':3B 'gotel':1A
12	Elektroklik	2021-05-01 23:01:00	\N	\N	\N	ul.  Reymond 56	\N	\N	'01/05/2021':5 '56':4C 'elektroklik':1A 'reymond':3C 'ul':2C
11	Bodex	2021-07-23 23:01:00	https://bodex.pl	\N	48503131421	\N	\N	\N	'23/07/2021':4 '48503131421':2C 'bodex':1A 'bodex.pl':3B
9	Nowy Elektronik	2021-10-16 18:20:00	https://nowyelektronik.pl/	\N	48327193133	\N	\N	Terrible customer service but good localisation	'16/10/2021':11 '48327193133':9C 'custom':4C 'elektronik':2A 'good':7C 'localis':8C 'nowi':1A 'nowyelektronik.pl':10B 'servic':5C 'terribl':3C
10	Meta	2021-05-21 23:06:00	https://metaparts.com	parts@metaparts.com	\N	\N	\N	\N	'21/05/2021':4 'meta':1A 'metaparts.com':3B 'parts@metaparts.com':2B
8	Botland	2021-07-23 18:29:00	https://botland.com.pl/	\N	48625931054	Gola 25A, 63-640 Gola	\N	\N	'-640':7C '23/07/2021':9 '25a':5C '48625931054':2C '63':6C 'botland':1A 'botland.com.pl':3B 'gola':4C,8C
7	Arctic Monkeys	2021-03-05 20:06:00	\N	monkeys@arctic.com	\N	\N	5426242312	\N	'05/03/2021':5 '5426242312':4B 'arctic':1A 'monkey':2A 'monkeys@arctic.com':3B
6	Kuki Delivery	2021-04-03 18:28:00	\N	kuki@kukdelivery.pl	47603088420	\N	\N	Very fast shipping and great prices!	'03/04/2021':11 '47603088420':9C 'deliveri':2A 'fast':4C 'great':7C 'kuki':1A 'kuki@kukdelivery.pl':10B 'price':8C 'ship':5C
27	Proline	2021-11-27 04:21:00	https://proline.pl/	pomoc@proline.pl	48664999930	ul. Brzozowa 5 55-095 Mirków	\N	\N	'-095':9C '27/11/2021':11 '48664999930':2C '5':7C '55':8C 'brzozowa':6C 'mirków':10C 'pomoc@proline.pl':3B 'prolin':1A 'proline.pl':4B 'ul':5C
28	Supplior	2022-03-05 23:38:00	https://supplior.com	\N	\N	Big Supply St. 51/512, Warasw	\N	He's got some good prices!	'05/03/2022':14 '51/512':12C 'big':9C 'good':6C 'got':4C 'price':7C 'st':11C 'suppli':10C 'supplior':1A 'supplior.com':8B 'warasw':13C
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

SELECT pg_catalog.setval('public.clients_id_seq', 44, true);


--
-- Name: computer_pieces_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.computer_pieces_id_seq', 179, true);


--
-- Name: computers_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.computers_id_seq', 25, true);


--
-- Name: history_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.history_id_seq', 362, true);


--
-- Name: orderChunk_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."orderChunk_id_seq"', 92, true);


--
-- Name: orders_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.orders_id_seq', 67, true);


--
-- Name: parts_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.parts_id_seq', 105, true);


--
-- Name: problems_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.problems_id_seq', 13, true);


--
-- Name: segments_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.segments_id_seq', 1, false);


--
-- Name: suppliers_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.suppliers_id_seq', 28, true);


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
-- Name: parts tsvectorupdate; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER tsvectorupdate BEFORE INSERT OR UPDATE ON public.parts FOR EACH ROW EXECUTE FUNCTION public.parts_tsvector_trigger();


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

