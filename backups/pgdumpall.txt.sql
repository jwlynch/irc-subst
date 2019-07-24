--
-- PostgreSQL database cluster dump
--

SET default_transaction_read_only = off;

SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;

--
-- Roles
--

CREATE ROLE jim;
ALTER ROLE jim WITH SUPERUSER INHERIT CREATEROLE CREATEDB LOGIN NOREPLICATION NOBYPASSRLS PASSWORD 'md5c949e46d8dc0a3a39bbbe20a77f77ec0';
CREATE ROLE odoo;
ALTER ROLE odoo WITH NOSUPERUSER INHERIT NOCREATEROLE CREATEDB LOGIN NOREPLICATION NOBYPASSRLS;
CREATE ROLE postgres;
ALTER ROLE postgres WITH SUPERUSER INHERIT CREATEROLE CREATEDB LOGIN REPLICATION BYPASSRLS;






--
-- Database creation
--

CREATE DATABASE jim WITH TEMPLATE = template0 OWNER = jim;
CREATE DATABASE odoo WITH TEMPLATE = template0 OWNER = jim;
REVOKE CONNECT,TEMPORARY ON DATABASE template1 FROM PUBLIC;
GRANT CONNECT ON DATABASE template1 TO PUBLIC;


\connect jim

SET default_transaction_read_only = off;

--
-- PostgreSQL database dump
--

-- Dumped from database version 9.6.14
-- Dumped by pg_dump version 9.6.14

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
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


--
-- Name: acs_datatype__date_output_function(text); Type: FUNCTION; Schema: public; Owner: jim
--

CREATE FUNCTION public.acs_datatype__date_output_function(p_attribute_name text) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
BEGIN
  return 'to_char(' || p_attribute_name || ', ''YYYY-MM-DD'')';
END;
$$;


ALTER FUNCTION public.acs_datatype__date_output_function(p_attribute_name text) OWNER TO jim;

--
-- Name: acs_datatype__timestamp_output_function(text); Type: FUNCTION; Schema: public; Owner: jim
--

CREATE FUNCTION public.acs_datatype__timestamp_output_function(p_attribute_name text) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
BEGIN
  return 'to_char(' || p_attribute_name || ', ''YYYY-MM-DD HH24:MI:SS'')';
END;
$$;


ALTER FUNCTION public.acs_datatype__timestamp_output_function(p_attribute_name text) OWNER TO jim;

--
-- Name: array_reverse(anyarray); Type: FUNCTION; Schema: public; Owner: jim
--

CREATE FUNCTION public.array_reverse(anyarray) RETURNS anyarray
    LANGUAGE sql IMMUTABLE STRICT
    AS $_$
SELECT ARRAY(
    SELECT $1[i]
        FROM generate_subscripts($1,1) AS s(i)
	    ORDER BY i DESC
	    );
$_$;


ALTER FUNCTION public.array_reverse(anyarray) OWNER TO jim;

--
-- Name: attribute__delete(character varying, character varying, boolean); Type: FUNCTION; Schema: public; Owner: jim
--

CREATE FUNCTION public.attribute__delete(p_object_type character varying, p_attribute_name character varying, p_drop_column_p boolean DEFAULT false) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_table_name             object_types.table_name%TYPE;
BEGIN

  -- Check that attribute exists and simultaneously grab the type's table name
  select t.table_name into v_table_name
  from object_types t, attributes a
  where a.object_type = p_object_type
    and a.attribute_name = p_attribute_name
    and t.object_type = p_object_type;

  if not found then
    raise exception 'Attribute "%":"%" does not exist', p_object_type, p_attribute_name;
  end if;
--
--   -- first remove possible values for the enumeration
--   delete from acs_enum_values
--   where attribute_id in (select a.attribute_id
--                          from acs_attributes a
--                          where a.object_type = p_object_type
--                          and a.attribute_name = p_attribute_name);

  -- Drop the column if one were specified for the type and we're asked to
  if p_drop_column_p and v_table_name is not null then
      execute 'alter table ' || v_table_name || ' drop column ' ||
        p_attribute_name || ' cascade';
  end if;

  -- Finally, get rid of the attribute
  delete from attributes
  where object_type = p_object_type
  and attribute_name = p_attribute_name;

  return 0;
END;
$$;


ALTER FUNCTION public.attribute__delete(p_object_type character varying, p_attribute_name character varying, p_drop_column_p boolean) OWNER TO jim;

--
-- Name: attribute__new(character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, integer, integer, integer, character varying, boolean, boolean, character varying, character varying, boolean, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: jim
--

CREATE FUNCTION public.attribute__new(p_object_type character varying, p_attribute_name character varying, p_datatype character varying, p_pretty_name character varying, p_pretty_plural character varying DEFAULT NULL::character varying, p_table_name character varying DEFAULT NULL::character varying, p_column_name character varying DEFAULT NULL::character varying, p_default_value character varying DEFAULT NULL::character varying, p_min_n_values integer DEFAULT 1, p_max_n_values integer DEFAULT 1, p_sort_order integer DEFAULT NULL::integer, p_storage character varying DEFAULT 'type_specific'::character varying, p_static_p boolean DEFAULT false, p_create_column_p boolean DEFAULT false, p_database_type character varying DEFAULT NULL::character varying, p_size character varying DEFAULT NULL::character varying, p_null_p boolean DEFAULT true, p_references character varying DEFAULT NULL::character varying, p_check_expr character varying DEFAULT NULL::character varying, p_column_spec character varying DEFAULT NULL::character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE

  v_sort_order            attributes.sort_order%TYPE;
  v_attribute_id          attributes.attribute_id%TYPE;
  v_column_spec           text;
  v_table_name            text;
  v_constraint_stub       text;
  v_column_name           text;
  v_datatype              record;

BEGIN

  v_attribute_id := 0; -- remove me when this gets set properly

  if not exists (select 1
                 from object_types
                 where object_type = p_object_type) then
    raise exception 'Object type "%" does not exist', p_object_type;
  end if;

  if p_sort_order is null then
    select coalesce(max(sort_order), 1) into v_sort_order
    from attributes
    where object_type = p_object_type
    and attribute_name = p_attribute_name;
  else
    v_sort_order := p_sort_order;
  end if;

  select nextval('t_attribute_id_seq') into v_attribute_id;

  insert into attributes
    (attribute_id, object_type, table_name, column_name, attribute_name,
     pretty_name, pretty_plural, sort_order, datatype, default_value,
     min_n_values, max_n_values, storage, static_p)
  values
    (v_attribute_id, p_object_type,
     p_table_name, p_column_name,
     p_attribute_name, p_pretty_name,
     p_pretty_plural, v_sort_order,
     p_datatype, p_default_value,
     p_min_n_values, p_max_n_values,
     p_storage, p_static_p);

  if p_create_column_p then

    select table_name into v_table_name from object_types
    where object_type = p_object_type;

    if not exists (select 1
                   from pg_class
                   where relname = lower(v_table_name)) then
      raise exception 'Table "%" for object type "%" does not exist', v_table_name, p_object_type;
    end if;

    -- Add the appropriate column to the table

    -- We can only create the table column if
    -- 1. the attribute is declared type_specific (generic storage uses an auxillary table)
    -- 2. the attribute is not declared static
    -- 3. it does not already exist in the table

    if p_storage <> 'type_specific' then
      raise exception 'Attribute "%" for object type "%" must be declared with type_specific storage',
        p_attribute_name, p_object_type;
    end if;

    if p_static_p then
      raise exception 'Attribute "%" for object type "%" can not be declared static',
        p_attribute_name, p_object_type;
    end if;

    if p_table_name is not null then
      raise exception 'Attribute "%" for object type "%" can not specify a table for storage', p_attribute_name, p_object_type;
    end if;

    if exists (select 1
               from pg_class c, pg_attribute a
               where c.relname::varchar = v_table_name
                 and c.oid = a.attrelid
                 and a.attname = lower(p_attribute_name)) then
      raise exception 'Column "%" for object type "%" already exists',
        p_attribute_name, p_object_type;
    end if;

    -- all conditions for creating this column have been met, now let's see if the type
    -- spec is OK

    if p_column_spec is not null then
      if p_database_type is not null
        or p_size is not null
        or p_null_p is not null
        or p_references is not null
        or p_check_expr is not null then
      raise exception 'Attribute "%" for object type "%" is being created with an explicit column_spec, but not all of the type modification fields are null',
        p_attribute_name, p_object_type;
      end if;
      v_column_spec := p_column_spec;
    else
      select coalesce(p_database_type, database_type) as database_type,
        coalesce(p_size, column_size) as column_size,
        coalesce(p_check_expr, column_check_expr) as check_expr
      into v_datatype
      from datatypes
      where datatype = p_datatype;

      v_column_spec := v_datatype.database_type;

      if v_datatype.column_size is not null then
        v_column_spec := v_column_spec || '(' || v_datatype.column_size || ')';
      end if;

      v_constraint_stub := ' constraint ' || p_object_type || '_' ||
        p_attribute_name || '_';

      if v_datatype.check_expr is not null then
        v_column_spec := v_column_spec || v_constraint_stub || 'ck check(' ||
          p_attribute_name || v_datatype.check_expr || ')';
      end if;

      if not p_null_p then
        v_column_spec := v_column_spec || v_constraint_stub || 'nn not null';
      end if;

      if p_references is not null then
        v_column_spec := v_column_spec || v_constraint_stub || 'fk references ' ||
          p_references || ' on delete';
        if p_null_p then
          v_column_spec := v_column_spec || ' set null';
        else
          v_column_spec := v_column_spec || ' cascade';
        end if;
      end if;

    end if;

    execute 'alter table ' || v_table_name || ' add ' || p_attribute_name || ' ' ||
            v_column_spec;

  end if;

  return v_attribute_id;

END;
$$;


ALTER FUNCTION public.attribute__new(p_object_type character varying, p_attribute_name character varying, p_datatype character varying, p_pretty_name character varying, p_pretty_plural character varying, p_table_name character varying, p_column_name character varying, p_default_value character varying, p_min_n_values integer, p_max_n_values integer, p_sort_order integer, p_storage character varying, p_static_p boolean, p_create_column_p boolean, p_database_type character varying, p_size character varying, p_null_p boolean, p_references character varying, p_check_expr character varying, p_column_spec character varying) OWNER TO jim;

--
-- Name: failed_login_new(bigint, text, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: jim
--

CREATE FUNCTION public.failed_login_new(failed_login_id bigint DEFAULT NULL::bigint, host_or_ip text DEFAULT NULL::text, creation_date timestamp with time zone DEFAULT NULL::timestamp with time zone) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
  declare
    fl_id int8;
    hoi text;
    cd timestamp with time zone;
  begin
    if failed_login_id is null then
      select nextval('object_id_seq') into fl_id;
    else
      fl_id := failed_login_id;
    end if;

    hoi := host_or_ip;

    if creation_date is null then
      select now() into cd;
    else
      cd := creation_date;
    end if;

    insert into
      failed_logins_sasl
      (
        failed_login_id,
	host_or_ip_addr,
	timestamp
      )
      values
      (
        fl_id,
        hoi,
        cd
      );

    return fl_id;
  end;
$$;


ALTER FUNCTION public.failed_login_new(failed_login_id bigint, host_or_ip text, creation_date timestamp with time zone) OWNER TO jim;

--
-- Name: hostname_split(text); Type: FUNCTION; Schema: public; Owner: jim
--

CREATE FUNCTION public.hostname_split(hostname text) RETURNS text[]
    LANGUAGE plpgsql
    AS $$
  declare
    res text[];
  begin
    res = regexp_split_to_array(hostname, '\.');

    return res;
  end;
$$;


ALTER FUNCTION public.hostname_split(hostname text) OWNER TO jim;

--
-- Name: object_type__delete(); Type: FUNCTION; Schema: public; Owner: jim
--

CREATE FUNCTION public.object_type__delete() RETURNS void
    LANGUAGE plpgsql
    AS $$
  begin
  end;
$$;


ALTER FUNCTION public.object_type__delete() OWNER TO jim;

--
-- Name: object_type__delete(character varying, boolean, boolean); Type: FUNCTION; Schema: public; Owner: jim
--

CREATE FUNCTION public.object_type__delete(p_object_type character varying, p_drop_children_p boolean DEFAULT false, p_drop_table_p boolean DEFAULT false) RETURNS character varying
    LANGUAGE plpgsql
    AS $$
DECLARE
    row                               record;
    object_row                        record;
    v_table_name                      object_types.table_name%TYPE;

    v_test_out                        varchar;
BEGIN
    v_test_out = '';

    select table_name into v_table_name
    from object_types
    where object_type = p_object_type;

    if not found then
        raise exception 'Type "%" does not exist', p_object_type;
    end if;


    -- drop children recursively
    if p_drop_children_p then
      for row in select object_type
                 from object_types
                 where supertype = p_object_type
      loop
        perform object_type__delete(row.object_type, 't', p_drop_table_p);
      end loop;
    end if;

    --
    --   -- drop all the attributes associated with this type
    --   for row in select attribute_name
    --              from acs_attributes
    --              where object_type = p_object_type
    --   loop
    --     perform acs_attribute__drop_attribute (p_object_type, row.attribute_name);
    --   end loop;


    -- Remove the associated table if it exists and p_drop_table_p is true

    if p_drop_table_p then

      select table_name into v_table_name
      from object_types
      where object_type = p_object_type;

      if found then
        if not exists (select 1
                       from pg_class
                       where relname = lower(v_table_name)) then
          raise exception 'Table "%" does not exist', v_table_name;
        end if;

        execute 'drop table ' || v_table_name || ' cascade';
      end if;

    end if;

    delete from object_types
    where object_type = p_object_type;

    return v_test_out;
END;
$$;


ALTER FUNCTION public.object_type__delete(p_object_type character varying, p_drop_children_p boolean, p_drop_table_p boolean) OWNER TO jim;

--
-- Name: object_type__new(character varying, character varying, character varying, character varying, character varying, character varying, character varying, boolean, character varying, character varying, boolean, boolean); Type: FUNCTION; Schema: public; Owner: jim
--

CREATE FUNCTION public.object_type__new(p_object_type character varying, p_pretty_name character varying, p_pretty_plural character varying, p_supertype character varying DEFAULT 'object'::character varying, p_table_name character varying DEFAULT NULL::character varying, p_id_column character varying DEFAULT NULL::character varying, p_package_name character varying DEFAULT NULL::character varying, p_abstract_p boolean DEFAULT false, p_type_extension_table character varying DEFAULT NULL::character varying, p_name_method character varying DEFAULT NULL::character varying, p_create_table_p boolean DEFAULT false, p_dynamic_p boolean DEFAULT false) RETURNS character varying
    LANGUAGE plpgsql
    AS $$
  declare
    v_package_name                      object_types.package_name%TYPE;
    v_supertype                         object_types.supertype%TYPE;
    v_supertype_nn_p                    boolean;
    v_name_method                       varchar;
    v_idx                               integer;
    v_temp_p                            boolean;
    v_supertype_table                   object_types.table_name%TYPE;
    v_id_column                         object_types.id_column%TYPE;
    v_table_name                        object_types.table_name%TYPE;
    v_table_create_string               varchar;

    v_test_out                          varchar;
  begin
      v_idx := position('.' in p_name_method);
      if v_idx <> 0 then
           v_name_method := substr(p_name_method,1,v_idx - 1) ||
                         '__' || substr(p_name_method, v_idx + 1);
      else
           v_name_method := p_name_method;
      end if;

      v_test_out := ''; -- remove me

      -- If we are asked to create the table, provide reasonable default values for the
      -- table name and id column.  Traditionally OpenACS uses the plural form of the type
      -- name.  This code appends "_t" (for "table") because the use of english plural rules
      -- does not work well for all languages.

      if p_create_table_p and (p_table_name is null or p_table_name = '') then
        v_table_name := p_object_type || '_t';
      else
        v_table_name := p_table_name;
      end if;

      if p_create_table_p and (p_id_column is null or p_id_column = '') then
        v_id_column := p_object_type || '_id';
      else
        v_id_column := p_id_column;
      end if;


      if p_package_name is null or p_package_name = '' then
        v_package_name := p_object_type;
      else
        v_package_name := p_package_name;
      end if;

      if p_object_type <> 'object' then
        if p_supertype is null or p_supertype = '' then
          v_supertype := 'object';
        else
          v_supertype := p_supertype;
        -- TODO: define object_type__is_subtype_p()
        --   if not acs_object_type__is_subtype_p('acs_object', p_supertype) then
        --     raise exception '%s is not a valid type', p_supertype;
        --   end if;
        end if;
      end if;


      insert into object_types
        (object_type, pretty_name, pretty_plural, supertype, table_name,
         id_column, abstract_p, type_extension_table, package_name,
         name_method, dynamic_p)
      values
        (p_object_type, p_pretty_name,
         p_pretty_plural, v_supertype,
         v_table_name, v_id_column,
         p_abstract_p, p_type_extension_table,
         v_package_name, v_name_method, p_dynamic_p);

      v_supertype_nn_p = p_supertype is not NULL and p_supertype <> '';

      if p_create_table_p then

           if exists (select 1
                      from pg_class
                      where relname = lower(v_table_name)) then
             raise exception 'Table "%" already exists', v_table_name;
           end if;

           if v_supertype_nn_p then
             loop
               select table_name,object_type into v_supertype_table,v_supertype
               from object_types
               where object_type = v_supertype;
               exit when v_supertype_table is not null;
             end loop;
           end if;

           -- NOTE it's possible for there to be a supertype without a table
           -- maybe I should make sure that's not possible

           v_table_create_string := 'create table ' || v_table_name;

           v_table_create_string := v_table_create_string || ' (';

           v_table_create_string := v_table_create_string ||
             v_id_column || ' integer constraint ' || v_table_name ||
             '_pk primary key ';

           if v_supertype_table is not NULL then
             v_table_create_string := v_table_create_string || ' constraint ' || v_table_name ||
               '_fk references ' || v_supertype_table || ' on delete cascade';
           end if;

           v_table_create_string := v_table_create_string || ')';

           execute v_table_create_string;
      end if;


      return v_test_out; -- should return 0 in final func
  end;
$$;


ALTER FUNCTION public.object_type__new(p_object_type character varying, p_pretty_name character varying, p_pretty_plural character varying, p_supertype character varying, p_table_name character varying, p_id_column character varying, p_package_name character varying, p_abstract_p boolean, p_type_extension_table character varying, p_name_method character varying, p_create_table_p boolean, p_dynamic_p boolean) OWNER TO jim;

--
-- Name: reverse_hostname(text); Type: FUNCTION; Schema: public; Owner: jim
--

CREATE FUNCTION public.reverse_hostname(hostname text) RETURNS text
    LANGUAGE plpgsql
    AS $$
  begin
    return array_to_string(array_reverse(hostname_split(hostname)), '.');
  end;
$$;


ALTER FUNCTION public.reverse_hostname(hostname text) OWNER TO jim;

--
-- Name: t_attribute_id_seq; Type: SEQUENCE; Schema: public; Owner: jim
--

CREATE SEQUENCE public.t_attribute_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.t_attribute_id_seq OWNER TO jim;

--
-- Name: attribute_id_seq; Type: VIEW; Schema: public; Owner: jim
--

CREATE VIEW public.attribute_id_seq AS
 SELECT nextval('public.t_attribute_id_seq'::regclass) AS nextval;


ALTER TABLE public.attribute_id_seq OWNER TO jim;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: attributes; Type: TABLE; Schema: public; Owner: jim
--

CREATE TABLE public.attributes (
    attribute_id integer NOT NULL,
    object_type character varying(100) NOT NULL,
    table_name character varying(30),
    attribute_name character varying(100) NOT NULL,
    pretty_name character varying(100) NOT NULL,
    pretty_plural character varying(100),
    sort_order integer NOT NULL,
    datatype character varying(50) NOT NULL,
    default_value text,
    min_n_values integer DEFAULT 1 NOT NULL,
    max_n_values integer DEFAULT 1 NOT NULL,
    storage character varying(13) DEFAULT 'type_specific'::character varying,
    static_p boolean DEFAULT false,
    column_name character varying(30),
    CONSTRAINT attributes_max_n_values_ck CHECK ((max_n_values >= 0)),
    CONSTRAINT attributes_min_n_values_ck CHECK ((min_n_values >= 0)),
    CONSTRAINT attributes_n_values_ck CHECK ((min_n_values <= max_n_values)),
    CONSTRAINT attributes_storage_ck CHECK (((storage)::text = ANY ((ARRAY['type_specific'::character varying, 'generic'::character varying])::text[])))
);


ALTER TABLE public.attributes OWNER TO jim;

--
-- Name: datatypes; Type: TABLE; Schema: public; Owner: jim
--

CREATE TABLE public.datatypes (
    datatype character varying(50) NOT NULL,
    max_n_values integer DEFAULT 1,
    database_type text,
    column_size text,
    column_check_expr text,
    column_output_function text,
    CONSTRAINT acs_datatypes_max_n_values_ck CHECK ((max_n_values > 0))
);


ALTER TABLE public.datatypes OWNER TO jim;

--
-- Name: TABLE datatypes; Type: COMMENT; Schema: public; Owner: jim
--

COMMENT ON TABLE public.datatypes IS '
 Defines the set of available abstract datatypes for attributes, along with
 an optional default mapping to a database type, size, and constraint to use if the
 attribute is created with create_attribute''s storage_type param set to "type_specific"
 and the create_storage_p param is set to true.  These defaults can be overwritten by
 the caller.

 The set of pre-defined datatypes is inspired by XForms
 (http://www.w3.org/TR/xforms-datamodel/).
';


--
-- Name: COLUMN datatypes.max_n_values; Type: COMMENT; Schema: public; Owner: jim
--

COMMENT ON COLUMN public.datatypes.max_n_values IS '
 The maximum number of values that any attribute with this datatype
 can have. Of the predefined attribute types, only "boolean" specifies
 a non-null max_n_values, because it doesn''t make sense to have a
 boolean attribute with more than one value. There is no
 corresponding min_n_values column, because each attribute may be
 optional, i.e., min_n_values would always be zero.
';


--
-- Name: COLUMN datatypes.database_type; Type: COMMENT; Schema: public; Owner: jim
--

COMMENT ON COLUMN public.datatypes.database_type IS '
  The base database type corresponding to the abstract datatype.  For example "varchar" or
  "integer".
';


--
-- Name: COLUMN datatypes.column_size; Type: COMMENT; Schema: public; Owner: jim
--

COMMENT ON COLUMN public.datatypes.column_size IS '
  Optional default column size specification to append to the base database type.  For
  example "1000" for the "string" abstract datatype, or "10,2" for "number".
';


--
-- Name: COLUMN datatypes.column_check_expr; Type: COMMENT; Schema: public; Owner: jim
--

COMMENT ON COLUMN public.datatypes.column_check_expr IS '
  Optional check constraint expression to declare for the type_specific database column.  In
  Oracle, for instance, the abstract "boolean" type is declared "text", with a column
  check expression to restrict the values to "f" and "t".
';


--
-- Name: COLUMN datatypes.column_output_function; Type: COMMENT; Schema: public; Owner: jim
--

COMMENT ON COLUMN public.datatypes.column_output_function IS '
  Function to call for this datatype when building a select view.  If not null, it will
  be called with an attribute name and is expected to return an expression on that
  attribute.  Example: date attributes will be transformed to calls to "to_char()".
';


--
-- Name: factoids; Type: TABLE; Schema: public; Owner: jim
--

CREATE TABLE public.factoids (
    key character varying NOT NULL,
    value character varying
);


ALTER TABLE public.factoids OWNER TO jim;

--
-- Name: failed_logins_sasl; Type: TABLE; Schema: public; Owner: jim
--

CREATE TABLE public.failed_logins_sasl (
    failed_login_id bigint,
    host_or_ip_addr text,
    "timestamp" timestamp with time zone
);


ALTER TABLE public.failed_logins_sasl OWNER TO jim;

--
-- Name: object_id_seq; Type: SEQUENCE; Schema: public; Owner: jim
--

CREATE SEQUENCE public.object_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.object_id_seq OWNER TO jim;

--
-- Name: object_type_tables; Type: TABLE; Schema: public; Owner: jim
--

CREATE TABLE public.object_type_tables (
    object_type character varying(100) NOT NULL,
    table_name character varying(30) NOT NULL,
    id_column character varying(30)
);


ALTER TABLE public.object_type_tables OWNER TO jim;

--
-- Name: object_types; Type: TABLE; Schema: public; Owner: jim
--

CREATE TABLE public.object_types (
    object_type character varying(100) NOT NULL,
    supertype character varying(100),
    extension_table character varying(100),
    ext_tbl_id_column character varying(100),
    table_name character varying(100),
    id_column character varying(100),
    package_name character varying(100),
    pretty_name character varying(100),
    pretty_plural character varying(100),
    abstract_p boolean,
    type_extension_table character varying(100),
    name_method character varying(100),
    dynamic_p boolean
);


ALTER TABLE public.object_types OWNER TO jim;

--
-- Name: TABLE object_types; Type: COMMENT; Schema: public; Owner: jim
--

COMMENT ON TABLE public.object_types IS '
 Each row in the acs_object_types table represents a distinct class
 of objects. For each instance of any acs_object_type, there is a
 corresponding row in the acs_objects table. Essentially,
 acs_objects.object_id supersedes the on_which_table/on_what_id pair
 that ACS 3.x used as the system-wide identifier for heterogeneous
 objects. The value of having a system-wide identifier for
 heterogeneous objects is that it helps us provide general solutions
 for common problems like access control, workflow, categorppization,
 and search. (Note that this framework is not overly restrictive,
 because it doesn''t force every type of object to be represented in
 the acs_object_types table.) Each acs_object_type has:
 * Attributes (stored in the acs_attributes table)
   Examples:
   * the "user" object_type has "email" and "password" attributes
   * the "content_item" object_type has "title" and "body" attributes
 * Relationship types (stored in the acs_rel_types table)
   Examples:
   * "a team has one team leader who is a user" (in other words,
     instances of the "team" object_type must have one "team leader"
     relationship to an instance of the "user" object_type)
   * "a content item may have zero or authors who are people or
     organizations, i.e., parties" (in other words, instances of
     the "content_item" object_type may have zero or more "author"
     relationships to instances of the "party" object_type)
 Possible extensions include automatic versioning, logical deletion,
 and auditing.
';


--
-- Name: COLUMN object_types.supertype; Type: COMMENT; Schema: public; Owner: jim
--

COMMENT ON COLUMN public.object_types.supertype IS '
 The object_type of which this object_type is a specialization (if
 any). For example, the supertype of the "user" object_type is
 "person". An object_type inherits the attributes and relationship
 rules of its supertype, though it can add constraints to the
 attributes and/or it can override the relationship rules. For
 instance, the "person" object_type has an optional "email" attribute,
 while its "user" subtype makes "email" mandatory.
';


--
-- Name: COLUMN object_types.table_name; Type: COMMENT; Schema: public; Owner: jim
--

COMMENT ON COLUMN public.object_types.table_name IS '
 The name of the type-specific table in which the values of attributes
 specific to this object_type are stored, if any.
';


--
-- Name: COLUMN object_types.id_column; Type: COMMENT; Schema: public; Owner: jim
--

COMMENT ON COLUMN public.object_types.id_column IS '
 The name of the primary key column in the table identified by
 table_name.
';


--
-- Name: COLUMN object_types.abstract_p; Type: COMMENT; Schema: public; Owner: jim
--

COMMENT ON COLUMN public.object_types.abstract_p IS '
 ...
 If the object_type is not abstract, then all of its attributes must
 have a non-null storage specified.
';


--
-- Name: COLUMN object_types.type_extension_table; Type: COMMENT; Schema: public; Owner: jim
--

COMMENT ON COLUMN public.object_types.type_extension_table IS '
 Object types (and their subtypes) that require more type-specific
 data than the fields already existing in object_types may name
 a table in which that data is stored.  The table should be keyed
 by the associated object_type.  For example, a row in the group_types
 table stores a default approval policy for every user group of that type.
 In this example, the group_types table has a primary key named
 group_type that references object_types.  If a subtype of groups
 for example, lab_courses, has its own type-specific data, it could be
 maintained in a table called lab_course_types, with a primary key named
 lab_course_type that references group_types.  This provides the same
 functionality as static class fields in an object-oriented programming language.
';


--
-- Name: COLUMN object_types.name_method; Type: COMMENT; Schema: public; Owner: jim
--

COMMENT ON COLUMN public.object_types.name_method IS '
 The name of a stored function that takes an object_id as an argument
 and returns a varchar2: the corresponding object name. This column is
 required to implement the polymorphic behavior of the acs.object_name()
 function.
';


--
-- Name: COLUMN object_types.dynamic_p; Type: COMMENT; Schema: public; Owner: jim
--

COMMENT ON COLUMN public.object_types.dynamic_p IS '
  This flag is used to identify object types created dynamically
  (e.g. through a web interface). Dynamically created object types can
  be administered differently. For example, the group type admin pages
  only allow users to add attributes or otherwise modify dynamic
  object types. This column is still experimental and may not be supported in the
  future. That is the reason it is not yet part of the API.
';


--
-- Name: objects; Type: TABLE; Schema: public; Owner: jim
--

CREATE TABLE public.objects (
    object_id integer NOT NULL,
    object_type character varying(4000),
    creation_date timestamp without time zone,
    creation_ip character varying(4000),
    last_modified timestamp without time zone,
    modifying_ip character varying(4000),
    modifying_user integer,
    creation_user integer,
    context_id integer,
    package_id integer,
    title character varying(4000)
);


ALTER TABLE public.objects OWNER TO jim;

--
-- Data for Name: attributes; Type: TABLE DATA; Schema: public; Owner: jim
--

COPY public.attributes (attribute_id, object_type, table_name, attribute_name, pretty_name, pretty_plural, sort_order, datatype, default_value, min_n_values, max_n_values, storage, static_p, column_name) FROM stdin;
1	object	\N	object_type	Object Type	Object Types	1	string	\N	1	1	type_specific	f	\N
2	object	\N	creation_date	Created Date	\N	1	date	\N	1	1	type_specific	f	\N
3	object	\N	creation_ip	Creation IP Address	\N	1	string	\N	1	1	type_specific	f	\N
4	object	\N	last_modified	Last Modified On	\N	1	date	\N	1	1	type_specific	f	\N
5	object	\N	modifying_ip	Modifying IP Address	\N	1	string	\N	1	1	type_specific	f	\N
6	object	\N	modifying_user	Modifying User	\N	1	integer	\N	1	1	type_specific	f	\N
7	object	\N	creation_user	Creation user	Creation users	1	integer	\N	1	1	type_specific	f	\N
8	object	\N	context_id	Context ID	Context IDs	1	integer	\N	0	1	type_specific	f	\N
9	object	\N	package_id	Package ID	Package IDs	1	integer	\N	0	1	type_specific	f	\N
10	object	\N	title	Title	Titles	1	string	\N	0	1	type_specific	f	\N
\.


--
-- Data for Name: datatypes; Type: TABLE DATA; Schema: public; Owner: jim
--

COPY public.datatypes (datatype, max_n_values, database_type, column_size, column_check_expr, column_output_function) FROM stdin;
date	\N	timestamp	\N	\N	\N
timestamp	\N	timestamp	\N	\N	\N
time_of_day	\N	timestamp	\N	\N	\N
enumeration	\N	varchar	100	\N	\N
url	\N	varchar	250	\N	\N
email	\N	varchar	200	\N	\N
file	1	varchar	100	\N	\N
filename	\N	varchar	100	\N	\N
string	\N	varchar	4000	\N	\N
number	\N	numeric	10,2	\N	\N
boolean	1	bool	\N	\N	\N
integer	1	integer	\N	\N	\N
currency	\N	money	\N	\N	\N
text	\N	text	\N	\N	\N
richtext	\N	text	\N	\N	\N
float	\N	float8	\N	\N	\N
naturalnum	\N	integer	\N	\N	\N
keyword	1	text	\N	\N	\N
\.


--
-- Data for Name: factoids; Type: TABLE DATA; Schema: public; Owner: jim
--

COPY public.factoids (key, value) FROM stdin;
[[alis]]	there is a bot, alis, that can assist you in finding channels on the freenode irc net. To get started, /msg alis help
[[circuit-sim]]	http://falstad.com/circuit/
[[transistor]]	https://learn.sparkfun.com/tutorials/transistors
[[lvm-intro]]	https://www.digitalocean.com/community/tutorials/an-introduction-to-lvm-concepts-terminology-and-operations
[[lvm-intro-video]]	https://www.youtube.com/watch?v=BysRGDgqtwY
[[trouble-with-windows]]	https://www.youtube.com/watch?v=tpJ9ETCbRMo&t=126s
[[tmuxcheatsheets]]	https://www.cheatography.com/explore/search/?q=tmux
[[begin-linux]]	https://www.tecmint.com/free-online-linux-learning-guide-for-beginners/
[[hexchat-pango-bug]]	hexchat is affected by a bug in pango versions 1.40.8 - 1.42.3, and the first fixed pango is 1.42.4
[[nedbats-talks]]	https://nedbatchelder.com/text/
[[askorig]]	you should ask your original question, and to make high-quality responses more likely, add as many informative details as you can
[[sicp-vid-playlist]]	https://www.youtube.com/watch?v=2Op3QLzMgSY&list=PLE18841CABEA24090
[[py-beg-course]]	https://www.youtube.com/watch?v=rfscVS0vtbw
[[py-zero-to-hero-video]]	https://www.youtube.com/watch?v=3cZsjOclmoM
[[abbr-word]]	please don't abbreviate words into something that's not also an english word, we think that new english speakers would have a hard time understanding
[[git-concepts]]	https://www.youtube.com/watch?v=uR6G2v_WsRA&t=4s
[[git-immersion]]	http://gitimmersion.com/
[[git-branching]]	https://www.youtube.com/watch?v=FyAAIHHClqI
[[russos-doc]]	https://www.youtube.com/watch?v=uNNeVu8wUak
[[py-thinkPython]]	http://greenteapress.com/thinkpython2/html/index.html
[[secure-pastebin]]	cryptobin.co
[[one-grub-repair]]	https://howtoubuntu.org/how-to-repair-restore-reinstall-grub-2-with-a-ubuntu-live-cd
[[termbin]]	if you have nc installed, you can pastebin the output of an arbitrary command, for example ls -CF if you run it like this: ls -CF | nc termbin.com 9999.
[[u]]	Please spell out u as you... it would help folks who are here and are new english speakers, some don't hear u as a rhyme for you (similar for other forms of abbreviations: y for why, 4 for for, 2 for to, r for are, etc)
[[lvm-vs-partns]]	with partitions, you make partitions using a partition tool, format them with a filesystem directly, and mount the partition with the filesystem. with LVM, instead of putting filesystems in partitions directly, you put 'LVM physical volumes' in partitions, then you make a 'volume group' (which is just a list of physical volumes), and put physical volumes in the volume groups, then you can make 'logical volumes', and these are what you would format and mount, and they got allocated from a volume group.
\.


--
-- Data for Name: failed_logins_sasl; Type: TABLE DATA; Schema: public; Owner: jim
--

COPY public.failed_logins_sasl (failed_login_id, host_or_ip_addr, "timestamp") FROM stdin;
1	cpe-69-132-98-0.carolina.res.rr.com	2018-06-11 03:11:57.308217-07
2	cpe-69-132-98-0.carolina.res.rr.com	2018-06-11 04:49:44.092955-07
3	cpe-69-132-98-0.carolina.res.rr.com	2018-06-11 04:55:09.047185-07
4	cpe-69-132-98-0.carolina.res.rr.com	2018-06-11 04:57:22.793792-07
5	cpe-69-132-98-0.carolina.res.rr.com	2018-06-11 05:12:15.517537-07
6	cpe-69-132-98-0.carolina.res.rr.com	2018-06-11 05:19:23.124822-07
7	cpe-69-132-98-0.carolina.res.rr.com	2018-06-11 05:25:43.150699-07
8	cpe-69-132-98-0.carolina.res.rr.com	2018-06-11 05:31:28.147504-07
9	cpe-69-132-98-0.carolina.res.rr.com	2018-06-11 05:44:41.961292-07
10	cpe-69-132-98-0.carolina.res.rr.com	2018-06-11 05:50:56.913542-07
11	cpe-69-132-98-0.carolina.res.rr.com	2018-06-11 05:56:56.99647-07
12	cpe-69-132-98-0.carolina.res.rr.com	2018-06-11 06:17:15.480608-07
13	cpe-69-132-98-0.carolina.res.rr.com	2018-06-11 06:22:40.309576-07
14	cpe-69-132-98-0.carolina.res.rr.com	2018-06-11 06:48:09.214866-07
15	cpe-69-132-98-0.carolina.res.rr.com	2018-06-11 06:57:29.180936-07
16	cpe-69-132-98-0.carolina.res.rr.com	2018-06-11 07:03:07.016382-07
17	cpe-69-132-98-0.carolina.res.rr.com	2018-06-11 07:09:07.114312-07
18	cpe-69-132-98-0.carolina.res.rr.com	2018-06-11 07:15:07.200198-07
19	cpe-69-132-98-0.carolina.res.rr.com	2018-06-11 07:16:30.458417-07
20	cpe-69-132-98-0.carolina.res.rr.com	2018-06-11 07:35:08.783457-07
21	cpe-69-132-98-0.carolina.res.rr.com	2018-06-11 07:40:18.78178-07
22	cpe-69-132-98-0.carolina.res.rr.com	2018-06-11 09:15:20.827006-07
23	cpe-69-132-98-0.carolina.res.rr.com	2018-06-11 09:22:43.310981-07
24	cpe-69-132-98-0.carolina.res.rr.com	2018-06-11 09:28:13.361468-07
25	cpe-69-132-98-0.carolina.res.rr.com	2018-06-11 09:36:37.794948-07
26	cpe-69-132-98-0.carolina.res.rr.com	2018-06-11 09:47:37.817567-07
27	cpe-69-132-98-0.carolina.res.rr.com	2018-06-12 03:02:58.038134-07
28	190.147.153.196	2018-06-12 09:01:34.78905-07
29	190.147.153.196	2018-06-12 12:46:38.875805-07
30	190.147.153.196	2018-06-12 12:55:38.829645-07
31	190.147.153.196	2018-06-12 13:06:15.617063-07
32	190.147.153.196	2018-06-12 13:27:05.192185-07
33	190.147.153.196	2018-06-12 14:28:07.410378-07
34	190.147.153.196	2018-06-12 15:28:42.372096-07
35	190.147.153.196	2018-06-12 15:50:35.684968-07
36	190.147.153.196	2018-06-12 16:04:04.456276-07
37	190.147.153.196	2018-06-12 16:14:44.149125-07
38	190.147.153.196	2018-06-12 16:19:36.303388-07
39	cpe-69-132-98-0.carolina.res.rr.com	2018-06-13 03:45:24.12803-07
40	cpe-69-132-98-0.carolina.res.rr.com	2018-06-13 03:56:30.80609-07
41	cpe-69-132-98-0.carolina.res.rr.com	2018-06-13 03:57:05.769882-07
42	cpe-69-132-98-0.carolina.res.rr.com	2018-06-13 03:57:50.764787-07
43	cpe-69-132-98-0.carolina.res.rr.com	2018-06-13 04:23:38.615215-07
44	cpe-69-132-98-0.carolina.res.rr.com	2018-06-13 04:55:07.619331-07
45	cpe-69-132-98-0.carolina.res.rr.com	2018-06-13 06:21:04.117173-07
46	cpe-69-132-98-0.carolina.res.rr.com	2018-06-13 06:33:13.445814-07
47	cpe-69-132-98-0.carolina.res.rr.com	2018-06-13 07:07:09.854623-07
48	cpe-69-132-98-0.carolina.res.rr.com	2018-06-13 07:16:11.914855-07
49	cpe-69-132-98-0.carolina.res.rr.com	2018-06-13 07:27:06.91388-07
50	cpe-69-132-98-0.carolina.res.rr.com	2018-06-13 07:36:48.810716-07
51	cpe-69-132-98-0.carolina.res.rr.com	2018-06-13 07:50:28.387987-07
52	cpe-69-132-98-0.carolina.res.rr.com	2018-06-13 07:55:43.320947-07
53	cpe-69-132-98-0.carolina.res.rr.com	2018-06-13 08:04:48.424121-07
54	cpe-69-132-98-0.carolina.res.rr.com	2018-06-13 09:34:39.110743-07
55	cpe-69-132-98-0.carolina.res.rr.com	2018-06-13 09:40:04.196821-07
56	cpe-69-132-98-0.carolina.res.rr.com	2018-06-13 09:45:44.086359-07
57	cpe-69-132-98-0.carolina.res.rr.com	2018-06-13 09:50:07.849075-07
58	190.147.153.196	2018-06-13 09:51:31.485742-07
59	cpe-69-132-98-0.carolina.res.rr.com	2018-06-13 10:05:32.900212-07
60	cpe-69-132-98-0.carolina.res.rr.com	2018-06-13 10:25:48.11819-07
61	cpe-69-132-98-0.carolina.res.rr.com	2018-06-13 10:32:58.105915-07
62	cpe-69-132-98-0.carolina.res.rr.com	2018-06-13 10:35:08.524768-07
63	cpe-69-132-98-0.carolina.res.rr.com	2018-06-13 10:42:14.516592-07
64	cpe-69-132-98-0.carolina.res.rr.com	2018-06-13 10:48:29.6845-07
65	cpe-69-132-98-0.carolina.res.rr.com	2018-06-13 10:54:13.440442-07
66	cpe-69-132-98-0.carolina.res.rr.com	2018-06-13 11:07:38.128872-07
67	cpe-69-132-98-0.carolina.res.rr.com	2018-06-13 11:13:43.102422-07
68	cpe-69-132-98-0.carolina.res.rr.com	2018-06-13 11:19:18.12313-07
69	cpe-69-132-98-0.carolina.res.rr.com	2018-06-13 11:25:42.988567-07
70	cpe-69-132-98-0.carolina.res.rr.com	2018-06-13 11:30:47.975169-07
71	cpe-69-132-98-0.carolina.res.rr.com	2018-06-13 11:55:16.621781-07
72	cpe-69-132-98-0.carolina.res.rr.com	2018-06-13 12:04:16.477938-07
73	cpe-69-132-98-0.carolina.res.rr.com	2018-06-13 12:08:51.847556-07
74	190.147.153.196	2018-06-13 12:20:43.522894-07
75	190.147.153.196	2018-06-13 12:23:21.852988-07
76	190.147.153.196	2018-06-13 12:25:56.461015-07
77	190.147.153.196	2018-06-13 12:41:48.904499-07
78	190.147.153.196	2018-06-13 13:02:37.159304-07
79	190.147.153.196	2018-06-13 14:03:34.369293-07
80	190.147.153.196	2018-06-13 14:15:58.831513-07
81	190.147.153.196	2018-06-13 14:25:08.796961-07
82	190.147.153.196	2018-06-13 14:35:53.444065-07
83	190.147.153.196	2018-06-13 14:56:29.772714-07
84	190.147.153.196	2018-06-13 15:34:57.735995-07
85	190.147.153.196	2018-06-13 15:44:35.017957-07
86	cpe-69-132-98-0.carolina.res.rr.com	2018-06-14 02:47:05.817833-07
87	cpe-69-132-98-0.carolina.res.rr.com	2018-06-14 03:45:13.431618-07
88	cpe-69-132-98-0.carolina.res.rr.com	2018-06-14 03:51:14.0496-07
89	cpe-69-132-98-0.carolina.res.rr.com	2018-06-14 03:56:24.075028-07
90	cpe-69-132-98-0.carolina.res.rr.com	2018-06-14 04:01:58.979208-07
91	cpe-69-132-98-0.carolina.res.rr.com	2018-06-14 04:10:44.166982-07
92	cpe-69-132-98-0.carolina.res.rr.com	2018-06-14 04:55:08.920421-07
93	cpe-69-132-98-0.carolina.res.rr.com	2018-06-14 05:02:18.895369-07
94	cpe-69-132-98-0.carolina.res.rr.com	2018-06-14 05:07:48.157393-07
95	cpe-69-132-98-0.carolina.res.rr.com	2018-06-14 05:13:18.211582-07
96	cpe-69-132-98-0.carolina.res.rr.com	2018-06-14 05:19:03.148405-07
97	cpe-69-132-98-0.carolina.res.rr.com	2018-06-14 05:21:33.35487-07
98	cpe-69-132-98-0.carolina.res.rr.com	2018-06-14 05:23:31.407762-07
99	cpe-69-132-98-0.carolina.res.rr.com	2018-06-14 05:29:31.405373-07
100	cpe-69-132-98-0.carolina.res.rr.com	2018-06-14 05:40:33.037089-07
101	190.147.153.196	2018-06-14 08:36:16.369211-07
102	190.147.153.196	2018-06-14 10:25:10.412568-07
103	190.147.153.196	2018-06-14 10:30:09.897491-07
104	190.147.153.196	2018-06-14 10:32:16.857996-07
105	190.147.153.196	2018-06-14 10:39:43.143576-07
106	190.147.153.196	2018-06-14 10:49:37.122106-07
107	190.147.153.196	2018-06-14 10:58:27.46768-07
108	190.147.153.196	2018-06-14 11:04:32.055556-07
109	190.147.153.196	2018-06-14 11:13:38.6659-07
110	190.147.153.196	2018-06-14 11:24:18.815609-07
111	190.147.153.196	2018-06-14 11:45:10.49703-07
112	190.147.153.196	2018-06-14 11:52:59.510003-07
113	190.147.153.196	2018-06-14 12:02:09.607039-07
114	190.147.153.196	2018-06-14 12:13:08.763847-07
115	190.147.153.196	2018-06-14 13:34:02.523975-07
116	190.147.153.196	2018-06-14 13:42:59.87225-07
117	190.147.153.196	2018-06-14 13:54:02.519313-07
118	190.147.153.196	2018-06-14 14:09:06.298558-07
119	190.147.153.196	2018-06-14 14:24:27.762363-07
120	190.147.153.196	2018-06-14 14:30:27.810524-07
121	190.147.153.196	2018-06-14 14:36:12.755048-07
122	190.147.153.196	2018-06-14 14:46:49.177554-07
123	190.147.153.196	2018-06-14 15:07:20.92185-07
124	190.147.153.196	2018-06-14 15:15:45.844812-07
125	190.147.153.196	2018-06-14 15:25:05.939309-07
126	190.147.153.196	2018-06-14 15:27:49.367917-07
127	190.147.153.196	2018-06-14 15:42:10.569366-07
128	190.147.153.196	2018-06-14 15:45:38.014782-07
129	190.147.153.196	2018-06-14 15:53:27.91702-07
130	190.147.153.196	2018-06-14 16:02:11.904336-07
131	190.147.153.196	2018-06-14 16:07:41.883073-07
132	190.147.153.196	2018-06-14 16:13:03.458988-07
133	cpe-69-132-98-0.carolina.res.rr.com	2018-06-15 03:51:20.085405-07
134	cpe-69-132-98-0.carolina.res.rr.com	2018-06-15 04:47:05.046305-07
135	cpe-69-132-98-0.carolina.res.rr.com	2018-06-15 04:49:33.811953-07
136	cpe-69-132-98-0.carolina.res.rr.com	2018-06-15 04:55:38.809485-07
137	cpe-69-132-98-0.carolina.res.rr.com	2018-06-15 05:04:22.942207-07
138	cpe-69-132-98-0.carolina.res.rr.com	2018-06-15 05:15:19.520515-07
139	cpe-69-132-98-0.carolina.res.rr.com	2018-06-15 05:19:53.722737-07
140	cpe-69-132-98-0.carolina.res.rr.com	2018-06-15 07:59:10.127287-07
141	cpe-69-132-98-0.carolina.res.rr.com	2018-06-15 08:27:36.798712-07
142	cpe-69-132-98-0.carolina.res.rr.com	2018-06-15 08:48:23.82891-07
143	cpe-69-132-98-0.carolina.res.rr.com	2018-06-15 08:59:42.51096-07
144	cpe-69-132-98-0.carolina.res.rr.com	2018-06-15 09:00:45.827611-07
145	cpe-69-132-98-0.carolina.res.rr.com	2018-06-15 09:09:59.829385-07
146	cpe-69-132-98-0.carolina.res.rr.com	2018-06-15 09:20:36.748691-07
147	cpe-69-132-98-0.carolina.res.rr.com	2018-06-15 09:41:21.827834-07
148	cpe-69-132-98-0.carolina.res.rr.com	2018-06-15 09:51:15.321218-07
149	cpe-69-132-98-0.carolina.res.rr.com	2018-06-15 09:56:40.316736-07
150	cpe-69-132-98-0.carolina.res.rr.com	2018-06-15 09:59:41.710964-07
151	cpe-69-132-98-0.carolina.res.rr.com	2018-06-15 10:08:31.711394-07
152	cpe-69-132-98-0.carolina.res.rr.com	2018-06-15 10:19:01.858175-07
153	cpe-69-132-98-0.carolina.res.rr.com	2018-06-15 10:39:51.626318-07
154	cpe-69-132-98-0.carolina.res.rr.com	2018-06-15 10:49:15.603738-07
155	cpe-69-132-98-0.carolina.res.rr.com	2018-06-15 10:54:40.534053-07
156	cpe-69-132-98-0.carolina.res.rr.com	2018-06-15 11:03:28.382459-07
157	cpe-69-132-98-0.carolina.res.rr.com	2018-06-15 11:18:47.092544-07
158	cpe-69-132-98-0.carolina.res.rr.com	2018-06-15 11:28:12.116559-07
159	cpe-69-132-98-0.carolina.res.rr.com	2018-06-15 11:37:24.078244-07
160	cpe-69-132-98-0.carolina.res.rr.com	2018-06-15 11:43:34.080355-07
161	cpe-69-132-98-0.carolina.res.rr.com	2018-06-15 11:49:09.812231-07
162	cpe-69-132-98-0.carolina.res.rr.com	2018-06-15 12:12:01.851574-07
163	cpe-69-132-98-0.carolina.res.rr.com	2018-06-15 12:18:19.779188-07
164	cpe-69-132-98-0.carolina.res.rr.com	2018-06-15 12:20:49.106966-07
165	cpe-69-132-98-0.carolina.res.rr.com	2018-06-15 12:38:32.848953-07
166	cpe-69-132-98-0.carolina.res.rr.com	2018-06-15 12:48:22.847846-07
167	cpe-69-132-98-0.carolina.res.rr.com	2018-06-15 13:00:26.427609-07
168	190.147.153.196	2018-06-15 14:15:22.1773-07
169	cpe-69-132-98-0.carolina.res.rr.com	2018-06-18 03:05:48.908885-07
170	cpe-69-132-98-0.carolina.res.rr.com	2018-06-18 03:56:13.406522-07
171	cpe-69-132-98-0.carolina.res.rr.com	2018-06-18 04:55:11.412648-07
172	cpe-69-132-98-0.carolina.res.rr.com	2018-06-18 05:29:46.183746-07
173	cpe-69-132-98-0.carolina.res.rr.com	2018-06-18 05:41:44.461237-07
174	cpe-69-132-98-0.carolina.res.rr.com	2018-06-18 06:16:57.311272-07
175	cpe-69-132-98-0.carolina.res.rr.com	2018-06-18 06:27:39.402188-07
176	cpe-69-132-98-0.carolina.res.rr.com	2018-06-18 06:33:09.402188-07
177	cpe-69-132-98-0.carolina.res.rr.com	2018-06-18 06:41:32.979093-07
178	cpe-69-132-98-0.carolina.res.rr.com	2018-06-18 06:52:08.015996-07
179	cpe-69-132-98-0.carolina.res.rr.com	2018-06-18 07:35:01.751778-07
180	cpe-69-132-98-0.carolina.res.rr.com	2018-06-18 07:45:35.838455-07
181	cpe-69-132-98-0.carolina.res.rr.com	2018-06-18 09:26:13.371577-07
182	cpe-69-132-98-0.carolina.res.rr.com	2018-06-18 09:38:23.810099-07
183	190.147.153.196	2018-06-18 09:57:46.137418-07
184	cpe-69-132-98-0.carolina.res.rr.com	2018-06-18 10:41:32.82411-07
185	cpe-69-132-98-0.carolina.res.rr.com	2018-06-18 10:52:26.039387-07
186	cpe-69-132-98-0.carolina.res.rr.com	2018-06-18 11:13:23.940588-07
187	cpe-69-132-98-0.carolina.res.rr.com	2018-06-18 11:23:18.77417-07
188	cpe-69-132-98-0.carolina.res.rr.com	2018-06-18 11:34:08.767273-07
189	cpe-69-132-98-0.carolina.res.rr.com	2018-06-18 11:44:23.944098-07
190	190.147.153.196	2018-06-18 12:08:53.264239-07
191	cpe-69-132-98-0.carolina.res.rr.com	2018-06-18 12:13:18.966847-07
192	190.147.153.196	2018-06-18 12:28:06.767069-07
193	cpe-69-132-98-0.carolina.res.rr.com	2018-06-18 12:34:02.09718-07
194	190.147.153.196	2018-06-18 12:48:15.079278-07
195	190.147.153.196	2018-06-18 12:57:32.741252-07
196	cpe-69-132-98-0.carolina.res.rr.com	2018-06-18 13:07:59.939487-07
197	190.147.153.196	2018-06-18 13:08:10.93814-07
198	cpe-69-132-98-0.carolina.res.rr.com	2018-06-18 13:10:35.808809-07
199	cpe-69-132-98-0.carolina.res.rr.com	2018-06-18 13:12:52.712816-07
200	cpe-69-132-98-0.carolina.res.rr.com	2018-06-18 13:18:47.739299-07
201	cpe-69-132-98-0.carolina.res.rr.com	2018-06-18 13:27:25.385442-07
202	190.147.153.196	2018-06-18 13:29:11.352682-07
203	cpe-69-132-98-0.carolina.res.rr.com	2018-06-18 13:44:07.840783-07
204	cpe-69-132-98-0.carolina.res.rr.com	2018-06-18 13:53:35.103529-07
205	cpe-69-132-98-0.carolina.res.rr.com	2018-06-18 13:59:34.381794-07
206	cpe-69-132-98-0.carolina.res.rr.com	2018-06-18 14:12:40.470459-07
207	cpe-69-132-98-0.carolina.res.rr.com	2018-06-18 14:18:40.489829-07
208	cpe-69-132-98-0.carolina.res.rr.com	2018-06-18 14:27:25.463819-07
209	190.147.153.196	2018-06-18 14:30:01.492572-07
210	190.147.153.196	2018-06-18 15:05:15.440317-07
211	190.147.153.196	2018-06-18 15:15:30.747276-07
212	190.147.153.196	2018-06-18 15:21:10.742412-07
213	190.147.153.196	2018-06-18 15:26:15.769602-07
214	190.147.153.196	2018-06-18 15:32:10.899127-07
215	190.147.153.196	2018-06-18 15:38:05.741443-07
216	190.147.153.196	2018-06-18 15:45:40.949574-07
217	190.147.153.196	2018-06-18 15:56:46.169096-07
218	190.147.153.196	2018-06-18 16:17:33.743881-07
219	190.147.153.196	2018-06-18 17:18:35.952268-07
220	cpe-69-132-98-0.carolina.res.rr.com	2018-06-19 03:06:01.138584-07
221	cpe-69-132-98-0.carolina.res.rr.com	2018-06-19 03:45:12.981138-07
222	cpe-69-132-98-0.carolina.res.rr.com	2018-06-19 03:59:38.425763-07
223	cpe-69-132-98-0.carolina.res.rr.com	2018-06-19 04:08:28.479511-07
224	cpe-69-132-98-0.carolina.res.rr.com	2018-06-19 04:14:06.594299-07
225	cpe-69-132-98-0.carolina.res.rr.com	2018-06-19 04:22:41.270052-07
226	cpe-69-132-98-0.carolina.res.rr.com	2018-06-19 04:31:35.374807-07
227	cpe-69-132-98-0.carolina.res.rr.com	2018-06-19 04:50:12.419311-07
228	cpe-69-132-98-0.carolina.res.rr.com	2018-06-19 05:03:45.615996-07
229	cpe-69-132-98-0.carolina.res.rr.com	2018-06-19 05:17:59.339249-07
230	cpe-69-132-98-0.carolina.res.rr.com	2018-06-19 06:50:12.067148-07
231	190.147.153.196	2018-06-19 10:14:06.92048-07
232	cpe-69-132-98-0.carolina.res.rr.com	2018-06-19 12:35:42.419916-07
233	cpe-69-132-98-0.carolina.res.rr.com	2018-06-19 12:44:35.507988-07
234	cpe-69-132-98-0.carolina.res.rr.com	2018-06-19 13:24:22.241183-07
235	cpe-69-132-98-0.carolina.res.rr.com	2018-06-19 13:51:36.950377-07
236	cpe-69-132-98-0.carolina.res.rr.com	2018-06-19 14:02:05.573731-07
237	cpe-69-132-98-0.carolina.res.rr.com	2018-06-19 14:05:17.475862-07
238	cpe-69-132-98-0.carolina.res.rr.com	2018-06-19 14:10:17.494147-07
239	cpe-69-132-98-0.carolina.res.rr.com	2018-06-19 14:25:03.987464-07
240	cpe-69-132-98-0.carolina.res.rr.com	2018-06-20 02:51:12.182137-07
241	cpe-69-132-98-0.carolina.res.rr.com	2018-06-20 04:31:56.167158-07
242	cpe-69-132-98-0.carolina.res.rr.com	2018-06-20 04:37:41.058413-07
243	cpe-69-132-98-0.carolina.res.rr.com	2018-06-20 04:55:08.281624-07
244	cpe-69-132-98-0.carolina.res.rr.com	2018-06-20 06:48:38.410799-07
245	cpe-69-132-98-0.carolina.res.rr.com	2018-06-20 07:09:27.015884-07
246	cpe-69-132-98-0.carolina.res.rr.com	2018-06-20 07:19:55.94252-07
247	cpe-69-132-98-0.carolina.res.rr.com	2018-06-20 07:26:10.851155-07
248	cpe-69-132-98-0.carolina.res.rr.com	2018-06-20 07:50:51.447997-07
249	cpe-69-132-98-0.carolina.res.rr.com	2018-06-20 08:03:47.137518-07
250	190.147.153.196	2018-06-20 08:09:21.57855-07
251	cpe-69-132-98-0.carolina.res.rr.com	2018-06-20 09:34:15.972965-07
252	cpe-69-132-98-0.carolina.res.rr.com	2018-06-20 09:58:16.952609-07
253	cpe-69-132-98-0.carolina.res.rr.com	2018-06-20 10:05:17.087864-07
254	cpe-69-132-98-0.carolina.res.rr.com	2018-06-20 10:07:32.879985-07
255	cpe-69-132-98-0.carolina.res.rr.com	2018-06-20 10:13:22.901698-07
256	cpe-69-132-98-0.carolina.res.rr.com	2018-06-20 10:19:27.872005-07
257	cpe-69-132-98-0.carolina.res.rr.com	2018-06-20 10:25:18.262209-07
258	cpe-69-132-98-0.carolina.res.rr.com	2018-06-20 10:42:58.42248-07
259	cpe-69-132-98-0.carolina.res.rr.com	2018-06-20 11:48:25.098013-07
260	cpe-69-132-98-0.carolina.res.rr.com	2018-06-20 12:08:07.723072-07
261	190.147.153.196	2018-06-20 12:10:49.10149-07
262	190.147.153.196	2018-06-20 12:13:04.323826-07
263	cpe-69-132-98-0.carolina.res.rr.com	2018-06-20 12:18:28.024446-07
264	190.147.153.196	2018-06-20 12:20:14.266963-07
265	190.147.153.196	2018-06-20 12:30:45.941387-07
266	cpe-69-132-98-0.carolina.res.rr.com	2018-06-20 12:41:11.537197-07
267	190.147.153.196	2018-06-20 12:51:45.890165-07
268	cpe-69-132-98-0.carolina.res.rr.com	2018-06-20 12:52:01.333248-07
269	cpe-69-132-98-0.carolina.res.rr.com	2018-06-20 13:11:40.723935-07
270	cpe-69-132-98-0.carolina.res.rr.com	2018-06-20 13:14:07.56563-07
271	190.147.153.196	2018-06-20 13:52:22.502994-07
272	190.147.153.196	2018-06-20 14:53:18.267353-07
273	190.147.153.196	2018-06-20 15:19:15.410117-07
274	190.147.153.196	2018-06-20 15:32:13.942282-07
275	190.147.153.196	2018-06-21 10:01:43.030041-07
276	190.147.153.196	2018-06-21 10:41:01.458126-07
277	190.147.153.196	2018-06-21 10:54:35.959515-07
278	190.147.153.196	2018-06-21 11:05:06.129862-07
279	190.147.153.196	2018-06-21 11:53:31.469699-07
280	190.147.153.196	2018-06-21 12:02:47.578579-07
281	190.147.153.196	2018-06-21 12:13:39.824975-07
282	190.147.153.196	2018-06-21 12:34:41.710443-07
283	190.147.153.196	2018-06-21 13:51:51.561442-07
284	190.147.153.196	2018-06-21 17:22:01.375613-07
285	190.147.153.196	2018-06-22 07:52:37.485234-07
286	190.147.153.196	2018-06-22 10:34:46.889045-07
287	190.147.153.196	2018-06-22 10:36:15.311551-07
288	190.147.153.196	2018-06-22 10:44:35.305252-07
289	190.147.153.196	2018-06-22 10:55:21.566952-07
290	190.147.153.196	2018-06-22 11:16:16.140827-07
291	190.147.153.196	2018-06-22 11:36:37.810618-07
292	190.147.153.196	2018-06-22 11:45:22.790782-07
293	190.147.153.196	2018-06-22 11:56:29.137694-07
294	190.147.153.196	2018-06-22 12:17:32.271588-07
295	190.147.153.196	2018-06-22 12:35:36.759622-07
296	190.147.153.196	2018-06-22 12:44:36.717896-07
297	190.147.153.196	2018-06-22 12:55:41.797758-07
298	190.147.153.196	2018-06-22 13:16:36.417025-07
299	190.147.153.196	2018-06-22 13:24:54.713743-07
300	190.147.153.196	2018-06-22 13:31:58.708402-07
301	190.147.153.196	2018-06-22 13:37:17.761326-07
302	190.147.153.196	2018-06-22 13:39:46.947106-07
303	190.147.153.196	2018-06-22 13:45:16.943237-07
304	190.147.153.196	2018-06-22 13:51:07.014729-07
305	190.147.153.196	2018-06-22 14:02:10.385552-07
306	190.147.153.196	2018-06-22 14:18:32.707088-07
307	190.147.153.196	2018-06-22 14:27:36.057874-07
308	190.147.153.196	2018-06-22 14:38:09.149797-07
309	190.147.153.196	2018-06-22 14:55:21.482412-07
310	190.147.153.196	2018-06-22 14:57:51.089704-07
311	190.147.153.196	2018-06-22 15:05:26.090996-07
312	190.147.153.196	2018-06-22 15:10:31.143885-07
313	190.147.153.196	2018-06-22 15:46:12.463067-07
314	190.147.153.196	2018-06-22 16:47:38.806038-07
315	190.147.153.196	2018-06-22 17:17:10.201022-07
316	190.147.153.196	2018-06-22 17:22:50.109914-07
317	190.147.153.196	2018-06-22 17:31:12.10259-07
318	190.147.153.196	2018-06-22 17:33:22.744537-07
319	190.147.153.196	2018-06-22 17:40:39.746635-07
320	190.147.153.196	2018-06-22 17:51:36.5976-07
321	190.147.153.196	2018-06-22 18:12:11.771629-07
322	190.147.153.196	2018-06-22 18:19:03.398521-07
323	cpe-69-132-98-0.carolina.res.rr.com	2018-06-25 02:55:27.381184-07
324	cpe-69-132-98-0.carolina.res.rr.com	2018-06-25 03:53:01.828412-07
325	cpe-69-132-98-0.carolina.res.rr.com	2018-06-25 04:01:04.503102-07
326	cpe-69-132-98-0.carolina.res.rr.com	2018-06-25 04:09:19.523588-07
327	cpe-69-132-98-0.carolina.res.rr.com	2018-06-25 04:11:52.852296-07
328	cpe-69-132-98-0.carolina.res.rr.com	2018-06-25 04:19:12.85168-07
16	190.147.153.196	2018-08-01 08:20:33.910853-07
329	cpe-69-132-98-0.carolina.res.rr.com	2018-06-25 04:47:33.836894-07
330	cpe-69-132-98-0.carolina.res.rr.com	2018-06-25 04:53:43.811452-07
331	cpe-69-132-98-0.carolina.res.rr.com	2018-06-25 05:02:42.942497-07
332	cpe-69-132-98-0.carolina.res.rr.com	2018-06-25 05:07:57.940715-07
333	cpe-69-132-98-0.carolina.res.rr.com	2018-06-25 05:18:31.483644-07
334	cpe-69-132-98-0.carolina.res.rr.com	2018-06-25 05:29:24.748844-07
335	cpe-69-132-98-0.carolina.res.rr.com	2018-06-25 05:50:02.271408-07
336	cpe-69-132-98-0.carolina.res.rr.com	2018-06-25 06:05:53.958711-07
337	cpe-69-132-98-0.carolina.res.rr.com	2018-06-25 06:11:11.00327-07
338	cpe-69-132-98-0.carolina.res.rr.com	2018-06-25 06:19:53.86899-07
339	cpe-69-132-98-0.carolina.res.rr.com	2018-06-25 06:30:25.953555-07
340	cpe-69-132-98-0.carolina.res.rr.com	2018-06-25 06:41:21.903153-07
341	cpe-69-132-98-0.carolina.res.rr.com	2018-06-25 06:50:13.713429-07
342	cpe-69-132-98-0.carolina.res.rr.com	2018-06-25 06:55:23.711421-07
343	cpe-69-132-98-0.carolina.res.rr.com	2018-06-25 07:03:57.078563-07
344	cpe-69-132-98-0.carolina.res.rr.com	2018-06-25 07:18:04.362345-07
345	cpe-69-132-98-0.carolina.res.rr.com	2018-06-25 07:39:41.739339-07
346	cpe-69-132-98-0.carolina.res.rr.com	2018-06-25 07:57:29.3745-07
347	cpe-69-132-98-0.carolina.res.rr.com	2018-06-25 09:14:29.138441-07
348	cpe-69-132-98-0.carolina.res.rr.com	2018-06-25 09:25:30.131858-07
349	cpe-69-132-98-0.carolina.res.rr.com	2018-06-25 09:31:15.133679-07
350	cpe-69-132-98-0.carolina.res.rr.com	2018-06-25 09:38:21.893434-07
351	cpe-69-132-98-0.carolina.res.rr.com	2018-06-25 09:47:31.992777-07
352	cpe-69-132-98-0.carolina.res.rr.com	2018-06-25 09:58:15.384807-07
353	cpe-69-132-98-0.carolina.res.rr.com	2018-06-25 10:08:51.738431-07
354	cpe-69-132-98-0.carolina.res.rr.com	2018-06-25 10:13:51.831894-07
355	cpe-69-132-98-0.carolina.res.rr.com	2018-06-25 10:19:16.750606-07
356	cpe-69-132-98-0.carolina.res.rr.com	2018-06-25 10:29:42.75669-07
357	cpe-69-132-98-0.carolina.res.rr.com	2018-06-25 10:40:39.571166-07
358	cpe-69-132-98-0.carolina.res.rr.com	2018-06-25 10:55:38.050508-07
359	cpe-69-132-98-0.carolina.res.rr.com	2018-06-25 11:06:19.949047-07
360	cpe-69-132-98-0.carolina.res.rr.com	2018-06-25 11:11:29.944785-07
361	cpe-69-132-98-0.carolina.res.rr.com	2018-06-25 11:17:05.993884-07
362	cpe-69-132-98-0.carolina.res.rr.com	2018-06-25 11:22:55.99851-07
363	cpe-69-132-98-0.carolina.res.rr.com	2018-06-25 11:33:57.511978-07
364	cpe-69-132-98-0.carolina.res.rr.com	2018-06-25 12:29:34.927237-07
365	cpe-69-132-98-0.carolina.res.rr.com	2018-06-25 12:34:39.910786-07
366	cpe-69-132-98-0.carolina.res.rr.com	2018-06-25 12:39:49.881074-07
367	cpe-69-132-98-0.carolina.res.rr.com	2018-06-25 12:42:28.08219-07
368	190.147.153.196	2018-06-25 12:43:19.703536-07
369	cpe-69-132-98-0.carolina.res.rr.com	2018-06-25 12:44:39.267972-07
370	cpe-69-132-98-0.carolina.res.rr.com	2018-06-25 12:50:24.327151-07
371	cpe-69-132-98-0.carolina.res.rr.com	2018-06-25 13:01:11.158835-07
372	cpe-69-132-98-0.carolina.res.rr.com	2018-06-25 13:13:16.386144-07
373	cpe-69-132-98-0.carolina.res.rr.com	2018-06-25 13:15:55.909762-07
374	cpe-69-132-98-0.carolina.res.rr.com	2018-06-25 13:24:35.939051-07
375	190.147.153.196	2018-06-26 08:48:07.865363-07
376	190.147.153.196	2018-06-26 11:37:58.1283-07
377	190.147.153.196	2018-06-26 11:40:46.438489-07
378	190.147.153.196	2018-06-26 11:47:34.962374-07
379	190.147.153.196	2018-06-26 11:56:45.781064-07
380	190.147.153.196	2018-06-26 12:04:50.780669-07
381	190.147.153.196	2018-06-26 12:10:27.95155-07
382	190.147.153.196	2018-06-26 12:17:13.251031-07
383	190.147.153.196	2018-06-26 12:25:56.404802-07
384	190.147.153.196	2018-06-26 12:56:36.813298-07
385	190.147.153.196	2018-06-26 13:57:35.237759-07
386	190.147.153.196	2018-06-26 14:02:45.462589-07
387	190.147.153.196	2018-06-26 14:08:55.518118-07
388	190.147.153.196	2018-06-26 14:14:44.316062-07
389	190.147.153.196	2018-06-26 14:25:24.328096-07
390	190.147.153.196	2018-06-26 14:46:12.742818-07
391	190.147.153.196	2018-06-26 15:42:46.381801-07
392	190.147.153.196	2018-06-26 15:45:25.786756-07
393	190.147.153.196	2018-06-26 15:52:30.784845-07
394	190.147.153.196	2018-06-26 16:03:36.083242-07
395	190.147.153.196	2018-06-26 16:58:34.766438-07
396	cpe-69-132-98-0.carolina.res.rr.com	2018-06-27 03:13:12.322325-07
397	cpe-69-132-98-0.carolina.res.rr.com	2018-06-27 03:45:12.842573-07
398	cpe-69-132-98-0.carolina.res.rr.com	2018-06-27 03:57:36.961834-07
399	cpe-69-132-98-0.carolina.res.rr.com	2018-06-27 04:05:47.220504-07
400	cpe-69-132-98-0.carolina.res.rr.com	2018-06-27 04:08:09.381061-07
401	cpe-69-132-98-0.carolina.res.rr.com	2018-06-27 04:10:14.523938-07
402	cpe-69-132-98-0.carolina.res.rr.com	2018-06-27 04:55:11.411584-07
403	cpe-69-132-98-0.carolina.res.rr.com	2018-06-27 09:23:40.746111-07
404	cpe-69-132-98-0.carolina.res.rr.com	2018-06-27 09:44:35.689547-07
405	cpe-69-132-98-0.carolina.res.rr.com	2018-06-27 09:50:25.975752-07
406	cpe-69-132-98-0.carolina.res.rr.com	2018-06-27 09:56:30.953103-07
407	cpe-69-132-98-0.carolina.res.rr.com	2018-06-27 10:01:51.056526-07
408	cpe-69-132-98-0.carolina.res.rr.com	2018-06-27 10:04:29.777871-07
409	cpe-69-132-98-0.carolina.res.rr.com	2018-06-27 10:26:46.137579-07
410	cpe-69-132-98-0.carolina.res.rr.com	2018-06-27 10:32:46.140658-07
411	190.147.153.196	2018-06-27 10:36:38.330086-07
412	cpe-69-132-98-0.carolina.res.rr.com	2018-06-27 10:38:33.777319-07
413	cpe-69-132-98-0.carolina.res.rr.com	2018-06-27 10:52:20.552285-07
414	cpe-69-132-98-0.carolina.res.rr.com	2018-06-27 10:59:45.408401-07
415	cpe-69-132-98-0.carolina.res.rr.com	2018-06-27 11:10:43.744884-07
416	190.147.153.196	2018-06-27 12:34:02.449716-07
417	190.147.153.196	2018-06-27 12:34:36.410749-07
418	190.147.153.196	2018-06-27 12:43:36.741524-07
419	190.147.153.196	2018-06-27 13:14:24.310111-07
420	190.147.153.196	2018-06-27 14:14:58.763141-07
421	190.147.153.196	2018-06-27 14:32:45.308463-07
422	190.147.153.196	2018-06-27 14:41:25.280202-07
423	190.147.153.196	2018-06-27 14:52:00.741582-07
424	190.147.153.196	2018-06-27 15:12:38.70473-07
425	190.147.153.196	2018-06-27 15:47:18.433287-07
426	190.147.153.196	2018-06-27 15:48:31.737944-07
427	190.147.153.196	2018-06-27 15:56:36.789138-07
428	190.147.153.196	2018-06-27 16:07:36.375134-07
429	190.147.153.196	2018-06-27 16:28:33.430658-07
430	190.147.153.196	2018-06-27 17:03:40.594615-07
431	190.147.153.196	2018-06-27 17:22:25.715316-07
432	nc-76-5-172-0.dhcp.embarqhsd.net	2018-06-27 17:32:35.509439-07
433	nc-76-5-172-0.dhcp.embarqhsd.net	2018-06-27 17:39:23.079485-07
434	nc-76-5-172-0.dhcp.embarqhsd.net	2018-06-27 17:39:47.086695-07
435	190.147.153.196	2018-06-27 17:40:40.811434-07
436	190.147.153.196	2018-06-27 17:45:20.001959-07
17	190.147.153.196	2018-08-01 08:55:59.022074-07
437	cpe-69-132-98-0.carolina.res.rr.com	2018-06-28 03:11:37.678847-07
438	cpe-69-132-98-0.carolina.res.rr.com	2018-06-28 03:43:33.08212-07
439	cpe-69-132-98-0.carolina.res.rr.com	2018-06-28 03:52:22.21714-07
440	cpe-69-132-98-0.carolina.res.rr.com	2018-06-28 04:09:41.453601-07
441	cpe-69-132-98-0.carolina.res.rr.com	2018-06-28 04:35:06.707034-07
442	cpe-69-132-98-0.carolina.res.rr.com	2018-06-28 04:51:11.7439-07
443	cpe-69-132-98-0.carolina.res.rr.com	2018-06-28 05:15:00.52902-07
444	cpe-69-132-98-0.carolina.res.rr.com	2018-06-28 05:26:04.764495-07
445	cpe-69-132-98-0.carolina.res.rr.com	2018-06-28 11:48:15.170594-07
446	cpe-69-132-98-0.carolina.res.rr.com	2018-06-28 11:50:53.868205-07
447	cpe-69-132-98-0.carolina.res.rr.com	2018-06-28 11:56:58.824729-07
448	cpe-69-132-98-0.carolina.res.rr.com	2018-06-28 12:28:10.331533-07
449	cpe-69-132-98-0.carolina.res.rr.com	2018-06-28 12:38:49.241085-07
450	cpe-69-132-98-0.carolina.res.rr.com	2018-06-28 12:57:58.670277-07
451	cpe-69-132-98-0.carolina.res.rr.com	2018-06-28 13:03:37.133812-07
452	cpe-69-132-98-0.carolina.res.rr.com	2018-06-28 13:12:17.050782-07
453	cpe-69-132-98-0.carolina.res.rr.com	2018-06-29 03:16:28.218583-07
454	cpe-69-132-98-0.carolina.res.rr.com	2018-06-29 03:45:12.383148-07
455	cpe-69-132-98-0.carolina.res.rr.com	2018-06-29 04:09:46.404747-07
456	cpe-69-132-98-0.carolina.res.rr.com	2018-06-29 04:55:12.673042-07
457	cpe-69-132-98-0.carolina.res.rr.com	2018-06-29 05:02:43.629252-07
458	cpe-69-132-98-0.carolina.res.rr.com	2018-06-29 05:11:26.368574-07
459	cpe-69-132-98-0.carolina.res.rr.com	2018-06-29 05:58:28.741917-07
460	cpe-69-132-98-0.carolina.res.rr.com	2018-06-29 06:05:33.757366-07
461	cpe-69-132-98-0.carolina.res.rr.com	2018-06-29 06:13:10.685817-07
462	cpe-69-132-98-0.carolina.res.rr.com	2018-06-29 06:32:19.939536-07
463	cpe-69-132-98-0.carolina.res.rr.com	2018-06-29 06:52:59.477763-07
464	cpe-69-132-98-0.carolina.res.rr.com	2018-06-29 07:48:51.757085-07
465	cpe-69-132-98-0.carolina.res.rr.com	2018-06-29 07:54:41.778632-07
466	cpe-69-132-98-0.carolina.res.rr.com	2018-06-29 08:13:16.432494-07
467	cpe-69-132-98-0.carolina.res.rr.com	2018-06-29 09:56:45.329671-07
468	cpe-69-132-98-0.carolina.res.rr.com	2018-06-29 10:13:24.603531-07
469	cpe-69-132-98-0.carolina.res.rr.com	2018-06-29 10:43:50.268317-07
470	cpe-69-132-98-0.carolina.res.rr.com	2018-06-29 10:54:35.276609-07
471	cpe-69-132-98-0.carolina.res.rr.com	2018-06-29 11:08:42.6826-07
472	cpe-69-132-98-0.carolina.res.rr.com	2018-06-29 11:13:32.987994-07
473	cpe-69-132-98-0.carolina.res.rr.com	2018-06-29 11:18:52.951715-07
474	cpe-69-132-98-0.carolina.res.rr.com	2018-06-29 11:28:36.753911-07
475	cpe-69-132-98-0.carolina.res.rr.com	2018-06-29 11:59:15.319248-07
476	cpe-69-132-98-0.carolina.res.rr.com	2018-06-29 12:16:00.376414-07
477	cpe-69-132-98-0.carolina.res.rr.com	2018-06-29 12:30:24.538273-07
478	cpe-69-132-98-0.carolina.res.rr.com	2018-06-29 12:37:06.567748-07
479	cpe-69-132-98-0.carolina.res.rr.com	2018-06-29 13:05:13.421086-07
480	190.147.153.196	2018-06-29 13:10:17.27582-07
481	cpe-69-132-98-0.carolina.res.rr.com	2018-07-02 12:42:03.867224-07
482	cpe-69-132-98-0.carolina.res.rr.com	2018-07-03 03:29:18.005672-07
483	cpe-69-132-98-0.carolina.res.rr.com	2018-07-03 04:32:35.644182-07
484	cpe-69-132-98-0.carolina.res.rr.com	2018-07-03 04:41:27.391066-07
485	cpe-69-132-98-0.carolina.res.rr.com	2018-07-03 05:13:50.122999-07
486	cpe-69-132-98-0.carolina.res.rr.com	2018-07-03 05:22:17.04662-07
487	cpe-69-132-98-0.carolina.res.rr.com	2018-07-03 06:51:06.716727-07
488	190.147.153.196	2018-07-03 07:14:56.460045-07
489	190.147.153.196	2018-07-03 07:16:58.697764-07
490	cpe-69-132-98-0.carolina.res.rr.com	2018-07-03 08:00:14.089364-07
491	cpe-69-132-98-0.carolina.res.rr.com	2018-07-03 08:45:00.191265-07
492	cpe-69-132-98-0.carolina.res.rr.com	2018-07-03 08:54:09.640335-07
493	cpe-69-132-98-0.carolina.res.rr.com	2018-07-03 09:01:54.541496-07
494	cpe-69-132-98-0.carolina.res.rr.com	2018-07-03 09:20:59.695707-07
495	cpe-69-132-98-0.carolina.res.rr.com	2018-07-03 09:41:45.210921-07
496	cpe-69-132-98-0.carolina.res.rr.com	2018-07-03 09:49:48.978233-07
497	cpe-69-132-98-0.carolina.res.rr.com	2018-07-03 09:52:11.56719-07
498	cpe-69-132-98-0.carolina.res.rr.com	2018-07-03 10:00:36.57277-07
499	cpe-69-132-98-0.carolina.res.rr.com	2018-07-03 10:10:21.09825-07
500	cpe-69-132-98-0.carolina.res.rr.com	2018-07-03 10:21:58.573848-07
501	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-03 11:21:04.705047-07
502	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-03 11:22:24.677712-07
503	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-03 11:29:50.81311-07
504	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-03 12:00:31.624695-07
505	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-03 12:09:26.925472-07
506	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-03 12:25:14.956751-07
507	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-03 12:33:09.981506-07
508	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-03 12:42:25.830338-07
509	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-03 12:48:15.560296-07
510	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-03 12:57:16.925913-07
511	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-03 13:07:57.682816-07
512	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-03 13:28:46.578245-07
513	190.147.153.196	2018-07-03 13:32:31.940116-07
514	190.147.153.196	2018-07-03 13:43:47.119428-07
515	190.147.153.196	2018-07-03 13:49:17.984861-07
516	190.147.153.196	2018-07-03 13:54:43.309795-07
517	190.147.153.196	2018-07-03 13:57:09.933202-07
518	190.147.153.196	2018-07-03 14:12:44.501648-07
519	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-03 14:29:33.603453-07
520	190.147.153.196	2018-07-03 14:33:18.559762-07
521	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-03 15:30:04.960783-07
522	190.147.153.196	2018-07-03 15:34:17.493365-07
523	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-03 16:31:04.711072-07
524	190.147.153.196	2018-07-03 16:34:52.054029-07
525	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-03 17:32:00.57544-07
526	190.147.153.196	2018-07-03 17:35:49.014146-07
527	190.147.153.196	2018-07-03 17:59:15.188513-07
528	190.147.153.196	2018-07-03 18:06:37.649866-07
529	190.147.153.196	2018-07-03 18:15:19.307236-07
530	190.147.153.196	2018-07-03 18:26:09.628-07
531	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-03 18:32:54.633931-07
532	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-03 19:33:32.571483-07
938	190.147.153.196	2018-08-30 11:24:54.306833-07
533	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-03 20:34:37.94967-07
534	190.147.153.196	2018-07-03 21:33:46.583379-07
535	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-03 21:35:14.994015-07
536	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-03 22:36:17.453016-07
537	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-03 23:37:02.354263-07
538	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-04 00:37:33.642212-07
539	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-04 01:38:22.56491-07
540	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-04 02:39:09.190873-07
541	190.147.153.196	2018-07-04 08:01:09.933928-07
542	190.147.153.196	2018-07-04 08:26:29.504616-07
543	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-04 09:42:13.663479-07
544	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-04 09:45:31.326361-07
545	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-04 09:51:37.244498-07
546	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-04 10:02:45.505193-07
547	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-04 10:08:06.013235-07
548	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-04 10:15:32.195549-07
549	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-04 10:24:44.29529-07
550	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-04 10:30:30.974338-07
551	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-04 10:36:24.965669-07
552	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-04 10:46:57.706206-07
553	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-04 10:59:32.461494-07
554	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-04 11:04:50.17846-07
555	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-04 11:13:57.242106-07
556	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-04 11:24:58.52311-07
557	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-04 11:43:20.255051-07
558	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-04 11:45:39.630649-07
559	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-04 12:01:10.984722-07
560	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-04 12:09:41.054272-07
561	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-04 12:18:39.295688-07
562	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-04 12:29:24.099174-07
563	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-04 12:36:54.292769-07
564	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-04 12:45:44.252005-07
565	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-04 12:54:20.542195-07
566	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-04 13:01:35.76192-07
567	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-04 13:10:30.80066-07
568	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-04 13:21:06.095878-07
569	190.147.153.196	2018-07-04 14:33:08.816494-07
570	190.147.153.196	2018-07-04 17:39:59.860229-07
571	cpe-69-132-98-0.carolina.res.rr.com	2018-07-05 02:55:29.4758-07
572	cpe-69-132-98-0.carolina.res.rr.com	2018-07-05 04:49:47.382519-07
573	cpe-69-132-98-0.carolina.res.rr.com	2018-07-05 04:57:07.336455-07
574	cpe-69-132-98-0.carolina.res.rr.com	2018-07-05 05:02:37.458608-07
575	cpe-69-132-98-0.carolina.res.rr.com	2018-07-05 05:08:39.340122-07
576	cpe-69-132-98-0.carolina.res.rr.com	2018-07-05 05:26:10.087526-07
577	cpe-69-132-98-0.carolina.res.rr.com	2018-07-05 05:45:32.686417-07
578	cpe-69-132-98-0.carolina.res.rr.com	2018-07-05 05:51:44.547514-07
579	cpe-69-132-98-0.carolina.res.rr.com	2018-07-05 06:00:49.81751-07
580	cpe-69-132-98-0.carolina.res.rr.com	2018-07-05 06:06:09.544413-07
581	cpe-69-132-98-0.carolina.res.rr.com	2018-07-05 06:09:35.316034-07
582	cpe-69-132-98-0.carolina.res.rr.com	2018-07-05 06:15:09.99744-07
583	cpe-69-132-98-0.carolina.res.rr.com	2018-07-05 06:26:08.668665-07
584	cpe-69-132-98-0.carolina.res.rr.com	2018-07-05 07:20:32.709249-07
585	cpe-69-132-98-0.carolina.res.rr.com	2018-07-05 07:29:24.806965-07
586	cpe-69-132-98-0.carolina.res.rr.com	2018-07-05 07:36:59.695433-07
587	cpe-69-132-98-0.carolina.res.rr.com	2018-07-05 08:09:27.979208-07
588	cpe-69-132-98-0.carolina.res.rr.com	2018-07-05 08:14:37.161184-07
589	cpe-69-132-98-0.carolina.res.rr.com	2018-07-05 08:45:13.014278-07
590	190.147.153.196	2018-07-05 10:06:16.192446-07
591	cpe-69-132-98-0.carolina.res.rr.com	2018-07-05 11:45:12.404265-07
592	cpe-69-132-98-0.carolina.res.rr.com	2018-07-05 12:59:39.964705-07
593	cpe-69-132-98-0.carolina.res.rr.com	2018-07-05 13:07:08.430953-07
594	cpe-69-132-98-0.carolina.res.rr.com	2018-07-05 13:16:52.432097-07
595	cpe-69-132-98-0.carolina.res.rr.com	2018-07-05 13:27:49.087343-07
596	190.147.153.196	2018-07-06 08:33:15.738957-07
597	cpe-69-132-98-0.carolina.res.rr.com	2018-07-06 10:54:11.651812-07
598	cpe-69-132-98-0.carolina.res.rr.com	2018-07-06 11:28:05.040433-07
599	cpe-69-132-98-0.carolina.res.rr.com	2018-07-06 11:36:45.190121-07
600	cpe-69-132-98-0.carolina.res.rr.com	2018-07-06 11:47:38.862291-07
601	cpe-69-132-98-0.carolina.res.rr.com	2018-07-06 11:56:17.513185-07
602	cpe-69-132-98-0.carolina.res.rr.com	2018-07-06 12:05:47.5045-07
603	cpe-69-132-98-0.carolina.res.rr.com	2018-07-06 12:16:37.876218-07
604	cpe-69-132-98-0.carolina.res.rr.com	2018-07-06 12:26:31.391628-07
605	cpe-69-132-98-0.carolina.res.rr.com	2018-07-06 12:28:53.676569-07
606	cpe-69-132-98-0.carolina.res.rr.com	2018-07-06 12:44:41.191489-07
607	cpe-69-132-98-0.carolina.res.rr.com	2018-07-06 12:51:07.606544-07
608	190.147.153.196	2018-07-06 15:18:37.767968-07
1	cpe-69-132-98-0.carolina.res.rr.com	2018-07-09 07:19:49.24604-07
2	cpe-69-132-98-0.carolina.res.rr.com	2018-07-09 07:20:14.203285-07
3	cpe-69-132-98-0.carolina.res.rr.com	2018-07-09 07:53:33.580385-07
4	cpe-69-132-98-0.carolina.res.rr.com	2018-07-09 08:12:37.791936-07
5	190.147.153.196	2018-07-09 08:24:09.531496-07
6	cpe-69-132-98-0.carolina.res.rr.com	2018-07-09 08:40:58.181564-07
7	cpe-69-132-98-0.carolina.res.rr.com	2018-07-09 08:51:58.114496-07
8	cpe-69-132-98-0.carolina.res.rr.com	2018-07-09 08:58:17.65444-07
9	cpe-69-132-98-0.carolina.res.rr.com	2018-07-09 09:04:07.993499-07
10	cpe-69-132-98-0.carolina.res.rr.com	2018-07-09 09:14:57.964744-07
11	190.147.153.196	2018-07-09 09:24:54.298751-07
12	190.147.153.196	2018-07-09 09:30:13.986204-07
13	cpe-69-132-98-0.carolina.res.rr.com	2018-07-09 09:34:43.847855-07
14	190.147.153.196	2018-07-09 09:35:19.058288-07
15	cpe-69-132-98-0.carolina.res.rr.com	2018-07-09 10:01:30.048589-07
16	cpe-69-132-98-0.carolina.res.rr.com	2018-07-09 10:07:42.220022-07
17	cpe-69-132-98-0.carolina.res.rr.com	2018-07-09 10:16:42.210011-07
18	cpe-69-132-98-0.carolina.res.rr.com	2018-07-09 10:27:21.699183-07
19	cpe-69-132-98-0.carolina.res.rr.com	2018-07-09 10:48:03.259995-07
20	190.147.153.196	2018-07-09 13:20:26.255575-07
21	190.147.153.196	2018-07-09 13:26:47.613083-07
22	190.147.153.196	2018-07-09 13:35:42.243621-07
23	190.147.153.196	2018-07-09 13:46:31.050665-07
24	cpe-69-132-98-0.carolina.res.rr.com	2018-07-10 03:19:35.953173-07
25	cpe-69-132-98-0.carolina.res.rr.com	2018-07-10 04:36:59.599804-07
26	cpe-69-132-98-0.carolina.res.rr.com	2018-07-10 04:53:40.190509-07
27	cpe-69-132-98-0.carolina.res.rr.com	2018-07-10 04:55:55.111753-07
28	cpe-69-132-98-0.carolina.res.rr.com	2018-07-10 04:58:18.082622-07
29	cpe-69-132-98-0.carolina.res.rr.com	2018-07-10 05:12:45.895034-07
30	cpe-69-132-98-0.carolina.res.rr.com	2018-07-10 08:04:42.119088-07
31	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-10 12:24:39.193863-07
32	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-10 13:16:50.250435-07
33	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-11 07:01:36.953082-07
34	cpe-69-132-98-0.carolina.res.rr.com	2018-07-11 09:47:59.307103-07
35	cpe-69-132-98-0.carolina.res.rr.com	2018-07-11 10:08:58.98384-07
36	cpe-69-132-98-0.carolina.res.rr.com	2018-07-11 10:14:49.003692-07
37	cpe-69-132-98-0.carolina.res.rr.com	2018-07-11 10:19:48.992428-07
38	cpe-69-132-98-0.carolina.res.rr.com	2018-07-11 10:27:09.01353-07
39	cpe-69-132-98-0.carolina.res.rr.com	2018-07-11 10:32:14.23364-07
40	cpe-69-132-98-0.carolina.res.rr.com	2018-07-11 10:39:38.640494-07
41	cpe-69-132-98-0.carolina.res.rr.com	2018-07-11 10:44:53.642569-07
42	cpe-69-132-98-0.carolina.res.rr.com	2018-07-11 10:50:29.246093-07
43	cpe-69-132-98-0.carolina.res.rr.com	2018-07-11 10:52:58.95004-07
44	cpe-69-132-98-0.carolina.res.rr.com	2018-07-11 10:58:23.705168-07
45	cpe-69-132-98-0.carolina.res.rr.com	2018-07-11 11:03:58.709816-07
46	cpe-69-132-98-0.carolina.res.rr.com	2018-07-11 11:06:25.23039-07
47	cpe-69-132-98-0.carolina.res.rr.com	2018-07-11 11:23:00.743416-07
48	cpe-69-132-98-0.carolina.res.rr.com	2018-07-11 11:37:22.583041-07
49	cpe-69-132-98-0.carolina.res.rr.com	2018-07-11 12:01:53.103267-07
50	cpe-69-132-98-0.carolina.res.rr.com	2018-07-11 12:12:51.954621-07
51	cpe-69-132-98-0.carolina.res.rr.com	2018-07-11 12:33:54.936974-07
52	cpe-69-132-98-0.carolina.res.rr.com	2018-07-11 12:41:56.009345-07
53	cpe-69-132-98-0.carolina.res.rr.com	2018-07-11 12:47:05.721447-07
54	cpe-69-132-98-0.carolina.res.rr.com	2018-07-11 12:55:16.967858-07
55	cpe-69-132-98-0.carolina.res.rr.com	2018-07-12 03:32:22.998521-07
56	cpe-69-132-98-0.carolina.res.rr.com	2018-07-12 04:00:06.00207-07
57	cpe-69-132-98-0.carolina.res.rr.com	2018-07-12 04:05:53.873528-07
58	cpe-69-132-98-0.carolina.res.rr.com	2018-07-12 04:22:01.001916-07
59	cpe-69-132-98-0.carolina.res.rr.com	2018-07-12 04:27:36.006651-07
60	cpe-69-132-98-0.carolina.res.rr.com	2018-07-12 05:30:28.00293-07
61	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-12 06:15:43.709004-07
62	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-12 06:22:08.973171-07
63	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-12 06:25:17.991076-07
64	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-12 06:31:08.227879-07
65	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-12 06:39:44.216478-07
66	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-12 06:50:36.186505-07
67	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-12 07:11:24.329236-07
68	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-12 07:19:02.25704-07
69	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-12 07:24:09.042527-07
70	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-12 07:29:27.906237-07
71	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-12 07:37:09.285792-07
72	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-12 07:42:49.247109-07
73	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-12 07:51:40.253311-07
74	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-12 08:02:13.987598-07
75	cpe-69-132-98-0.carolina.res.rr.com	2018-07-12 08:22:45.088261-07
76	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-12 08:23:00.188397-07
77	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-12 09:23:48.048567-07
78	190.147.153.196	2018-07-12 09:32:50.279241-07
79	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-12 09:33:38.715562-07
80	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-12 09:38:47.736156-07
81	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-12 09:41:25.062313-07
82	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-12 09:48:25.120247-07
83	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-12 09:59:29.935524-07
84	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-12 10:19:01.252994-07
85	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-12 10:24:02.590278-07
86	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-12 10:49:08.279415-07
87	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-12 11:10:12.679221-07
88	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-12 11:19:11.988939-07
89	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-12 11:24:12.121858-07
90	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-12 11:29:29.211659-07
91	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-12 11:34:15.993064-07
92	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-12 11:40:06.050493-07
93	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-12 11:50:54.017438-07
1	cpe-69-132-98-0.carolina.res.rr.com	2018-07-13 11:41:50.277528-07
2	cpe-69-132-98-0.carolina.res.rr.com	2018-07-13 12:09:37.656653-07
1	cpe-69-132-98-0.carolina.res.rr.com	2018-07-13 12:26:29.7707-07
1	cpe-69-132-98-0.carolina.res.rr.com	2018-07-13 12:42:06.816688-07
2	cpe-69-132-98-0.carolina.res.rr.com	2018-07-13 12:50:24.630791-07
3	cpe-69-132-98-0.carolina.res.rr.com	2018-07-13 13:13:20.578864-07
4	cpe-69-132-98-0.carolina.res.rr.com	2018-07-16 03:36:28.189909-07
5	cpe-69-132-98-0.carolina.res.rr.com	2018-07-16 04:18:44.864054-07
6	cpe-69-132-98-0.carolina.res.rr.com	2018-07-16 04:27:23.21785-07
7	cpe-69-132-98-0.carolina.res.rr.com	2018-07-16 04:33:23.254378-07
939	190.147.153.196	2018-08-30 11:40:07.730117-07
8	cpe-69-132-98-0.carolina.res.rr.com	2018-07-16 04:55:13.54293-07
9	cpe-69-132-98-0.carolina.res.rr.com	2018-07-16 06:26:12.646293-07
10	cpe-69-132-98-0.carolina.res.rr.com	2018-07-16 06:28:50.618523-07
11	cpe-69-132-98-0.carolina.res.rr.com	2018-07-16 06:45:33.337562-07
12	cpe-69-132-98-0.carolina.res.rr.com	2018-07-16 07:02:31.016889-07
13	cpe-69-132-98-0.carolina.res.rr.com	2018-07-16 07:08:30.641367-07
14	cpe-69-132-98-0.carolina.res.rr.com	2018-07-16 07:14:57.137136-07
15	cpe-69-132-98-0.carolina.res.rr.com	2018-07-16 07:20:27.454625-07
16	cpe-69-132-98-0.carolina.res.rr.com	2018-07-16 07:26:32.049946-07
17	cpe-69-132-98-0.carolina.res.rr.com	2018-07-16 07:35:22.198459-07
18	cpe-69-132-98-0.carolina.res.rr.com	2018-07-16 07:46:06.75946-07
19	cpe-69-132-98-0.carolina.res.rr.com	2018-07-16 07:57:01.648614-07
20	cpe-69-132-98-0.carolina.res.rr.com	2018-07-16 07:59:30.889207-07
21	cpe-69-132-98-0.carolina.res.rr.com	2018-07-16 08:04:33.436721-07
22	cpe-69-132-98-0.carolina.res.rr.com	2018-07-16 08:10:53.536466-07
23	cpe-69-132-98-0.carolina.res.rr.com	2018-07-16 08:25:54.885542-07
24	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-16 12:29:03.197375-07
25	cpe-69-132-98-0.carolina.res.rr.com	2018-07-16 13:20:45.795399-07
26	cpe-69-132-98-0.carolina.res.rr.com	2018-07-17 03:33:42.772086-07
27	cpe-69-132-98-0.carolina.res.rr.com	2018-07-17 04:55:13.986281-07
28	cpe-69-132-98-0.carolina.res.rr.com	2018-07-17 05:11:12.871577-07
29	cpe-69-132-98-0.carolina.res.rr.com	2018-07-17 05:19:48.850485-07
30	cpe-69-132-98-0.carolina.res.rr.com	2018-07-17 05:25:38.952708-07
31	cpe-69-132-98-0.carolina.res.rr.com	2018-07-17 05:36:41.982087-07
32	cpe-69-132-98-0.carolina.res.rr.com	2018-07-17 05:42:07.060281-07
33	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-17 12:08:54.36446-07
34	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-17 12:13:43.82807-07
35	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-18 08:58:32.713936-07
1	107.161.19.53	2018-07-22 04:49:49.080064-07
2	23.226.229.209	2018-07-22 04:50:37.553402-07
1	cpe-69-132-98-0.carolina.res.rr.com	2018-07-23 03:21:20.957846-07
2	cpe-69-132-98-0.carolina.res.rr.com	2018-07-23 04:13:48.520897-07
3	cpe-69-132-98-0.carolina.res.rr.com	2018-07-23 04:19:34.072814-07
4	cpe-69-132-98-0.carolina.res.rr.com	2018-07-23 04:55:15.32128-07
5	cpe-69-132-98-0.carolina.res.rr.com	2018-07-23 05:35:38.315887-07
6	cpe-69-132-98-0.carolina.res.rr.com	2018-07-23 05:40:58.504247-07
7	cpe-69-132-98-0.carolina.res.rr.com	2018-07-23 05:46:58.740005-07
8	cpe-69-132-98-0.carolina.res.rr.com	2018-07-23 05:56:54.307022-07
9	cpe-69-132-98-0.carolina.res.rr.com	2018-07-23 06:03:44.358792-07
10	cpe-69-132-98-0.carolina.res.rr.com	2018-07-23 06:09:39.264628-07
11	cpe-69-132-98-0.carolina.res.rr.com	2018-07-23 06:10:45.684457-07
12	cpe-69-132-98-0.carolina.res.rr.com	2018-07-23 07:23:37.819052-07
13	cpe-69-132-98-0.carolina.res.rr.com	2018-07-23 07:34:20.718258-07
14	cpe-69-132-98-0.carolina.res.rr.com	2018-07-23 07:42:30.182454-07
15	cpe-69-132-98-0.carolina.res.rr.com	2018-07-23 07:44:44.959566-07
16	cpe-69-132-98-0.carolina.res.rr.com	2018-07-23 07:51:44.744267-07
17	cpe-69-132-98-0.carolina.res.rr.com	2018-07-23 08:02:46.662104-07
18	cpe-69-132-98-0.carolina.res.rr.com	2018-07-23 08:17:28.842978-07
19	cpe-69-132-98-0.carolina.res.rr.com	2018-07-23 08:28:49.260706-07
20	cpe-69-132-98-0.carolina.res.rr.com	2018-07-23 08:34:47.83497-07
21	cpe-69-132-98-0.carolina.res.rr.com	2018-07-23 09:09:10.25819-07
22	cpe-69-132-98-0.carolina.res.rr.com	2018-07-23 09:17:06.657001-07
23	cpe-69-132-98-0.carolina.res.rr.com	2018-07-23 09:37:44.630992-07
24	cpe-69-132-98-0.carolina.res.rr.com	2018-07-23 10:00:35.995913-07
25	cpe-69-132-98-0.carolina.res.rr.com	2018-07-23 10:15:24.807444-07
26	cpe-69-132-98-0.carolina.res.rr.com	2018-07-23 10:26:14.004251-07
27	cpe-69-132-98-0.carolina.res.rr.com	2018-07-23 10:37:09.56145-07
28	cpe-69-132-98-0.carolina.res.rr.com	2018-07-23 11:03:56.732978-07
29	cpe-69-132-98-0.carolina.res.rr.com	2018-07-23 12:01:22.799661-07
30	cpe-69-132-98-0.carolina.res.rr.com	2018-07-23 12:07:21.633553-07
31	cpe-69-132-98-0.carolina.res.rr.com	2018-07-24 03:38:07.750665-07
32	cpe-69-132-98-0.carolina.res.rr.com	2018-07-24 04:55:14.809358-07
33	cpe-69-132-98-0.carolina.res.rr.com	2018-07-24 05:06:10.173728-07
34	cpe-69-132-98-0.carolina.res.rr.com	2018-07-24 05:45:46.744715-07
35	cpe-69-132-98-0.carolina.res.rr.com	2018-07-24 05:51:47.886766-07
36	cpe-69-132-98-0.carolina.res.rr.com	2018-07-24 09:31:26.660365-07
37	cpe-69-132-98-0.carolina.res.rr.com	2018-07-24 09:46:30.630809-07
38	cpe-69-132-98-0.carolina.res.rr.com	2018-07-24 10:08:59.325198-07
39	cpe-69-132-98-0.carolina.res.rr.com	2018-07-24 10:56:08.978337-07
40	190.147.153.196	2018-07-24 16:34:44.446622-07
41	cpe-69-132-98-0.carolina.res.rr.com	2018-07-25 03:43:42.779258-07
42	cpe-69-132-98-0.carolina.res.rr.com	2018-07-25 04:55:16.947927-07
43	cpe-69-132-98-0.carolina.res.rr.com	2018-07-25 05:05:33.71108-07
44	cpe-69-132-98-0.carolina.res.rr.com	2018-07-25 05:11:18.901897-07
45	cpe-69-132-98-0.carolina.res.rr.com	2018-07-25 05:18:03.968456-07
46	cpe-69-132-98-0.carolina.res.rr.com	2018-07-25 05:27:03.956181-07
47	cpe-69-132-98-0.carolina.res.rr.com	2018-07-25 05:32:29.202312-07
48	cpe-69-132-98-0.carolina.res.rr.com	2018-07-25 06:10:52.979536-07
49	cpe-69-132-98-0.carolina.res.rr.com	2018-07-25 06:21:24.927987-07
50	cpe-69-132-98-0.carolina.res.rr.com	2018-07-25 06:34:55.743535-07
51	cpe-69-132-98-0.carolina.res.rr.com	2018-07-25 06:45:35.708108-07
52	cpe-69-132-98-0.carolina.res.rr.com	2018-07-25 06:50:05.510715-07
53	cpe-69-132-98-0.carolina.res.rr.com	2018-07-25 07:12:57.498994-07
54	cpe-69-132-98-0.carolina.res.rr.com	2018-07-25 07:18:42.736939-07
55	cpe-69-132-98-0.carolina.res.rr.com	2018-07-25 07:22:59.117047-07
56	cpe-69-132-98-0.carolina.res.rr.com	2018-07-25 08:13:16.619521-07
57	cpe-69-132-98-0.carolina.res.rr.com	2018-07-25 08:28:02.083854-07
58	cpe-69-132-98-0.carolina.res.rr.com	2018-07-25 08:33:27.069391-07
59	cpe-69-132-98-0.carolina.res.rr.com	2018-07-25 10:41:59.224483-07
60	cpe-69-132-98-0.carolina.res.rr.com	2018-07-25 10:48:24.198526-07
61	cpe-69-132-98-0.carolina.res.rr.com	2018-07-25 10:57:14.747361-07
62	cpe-69-132-98-0.carolina.res.rr.com	2018-07-25 11:08:19.848308-07
63	cpe-69-132-98-0.carolina.res.rr.com	2018-07-25 11:09:26.50668-07
64	cpe-69-132-98-0.carolina.res.rr.com	2018-07-25 11:10:22.989005-07
65	cpe-69-132-98-0.carolina.res.rr.com	2018-07-25 11:19:17.989942-07
66	cpe-69-132-98-0.carolina.res.rr.com	2018-07-25 11:50:08.945057-07
940	190.147.153.196	2018-08-30 11:55:33.689564-07
67	cpe-69-132-98-0.carolina.res.rr.com	2018-07-26 03:10:37.548743-07
68	cpe-69-132-98-0.carolina.res.rr.com	2018-07-26 04:55:10.211421-07
69	cpe-69-132-98-0.carolina.res.rr.com	2018-07-26 05:03:30.991965-07
70	190.147.153.196	2018-07-26 08:22:39.627046-07
71	190.147.153.196	2018-07-26 08:23:14.019692-07
72	190.147.153.196	2018-07-26 08:24:04.085782-07
73	190.147.153.196	2018-07-26 11:54:48.597284-07
74	190.147.153.196	2018-07-26 12:04:52.988704-07
75	190.147.153.196	2018-07-26 12:15:38.23764-07
76	190.147.153.196	2018-07-26 12:21:03.000596-07
77	190.147.153.196	2018-07-26 12:29:48.286415-07
78	190.147.153.196	2018-07-26 12:40:37.960417-07
79	190.147.153.196	2018-07-26 12:50:00.631304-07
80	190.147.153.196	2018-07-26 13:00:55.788068-07
81	cpe-69-132-98-0.carolina.res.rr.com	2018-07-26 13:17:30.512828-07
1	cpe-69-132-98-0.carolina.res.rr.com	2018-07-30 03:15:58.501502-07
2	cpe-69-132-98-0.carolina.res.rr.com	2018-07-30 05:49:13.035433-07
3	63-140-68-29-radius.dynamic.acsalaska.net	2018-07-30 06:10:01.765089-07
4	63-140-68-29-radius.dynamic.acsalaska.net	2018-07-30 06:20:50.469203-07
5	63-140-68-29-radius.dynamic.acsalaska.net	2018-07-30 06:41:53.338872-07
6	cpe-69-132-98-0.carolina.res.rr.com	2018-07-30 06:52:15.025733-07
7	cpe-69-132-98-0.carolina.res.rr.com	2018-07-30 07:33:50.627646-07
8	cpe-69-132-98-0.carolina.res.rr.com	2018-07-30 07:42:42.833997-07
9	63-140-68-29-radius.dynamic.acsalaska.net	2018-07-30 07:43:02.449362-07
10	cpe-69-132-98-0.carolina.res.rr.com	2018-07-30 07:59:12.742855-07
11	cpe-69-132-98-0.carolina.res.rr.com	2018-07-30 08:21:45.899558-07
12	cpe-69-132-98-0.carolina.res.rr.com	2018-07-30 08:39:31.33291-07
13	63-140-68-29-radius.dynamic.acsalaska.net	2018-07-30 08:43:44.842955-07
14	cpe-69-132-98-0.carolina.res.rr.com	2018-07-30 09:20:00.990488-07
15	cpe-69-132-98-0.carolina.res.rr.com	2018-07-30 09:28:48.263101-07
16	cpe-69-132-98-0.carolina.res.rr.com	2018-07-30 09:43:37.988963-07
17	63-140-68-29-radius.dynamic.acsalaska.net	2018-07-30 09:44:27.787086-07
18	cpe-69-132-98-0.carolina.res.rr.com	2018-07-30 09:44:54.73909-07
19	cpe-69-132-98-0.carolina.res.rr.com	2018-07-30 09:59:47.135392-07
20	cpe-69-132-98-0.carolina.res.rr.com	2018-07-30 10:05:16.510417-07
21	cpe-69-132-98-0.carolina.res.rr.com	2018-07-30 10:19:40.989296-07
22	cpe-69-132-98-0.carolina.res.rr.com	2018-07-30 10:30:37.594851-07
23	63-140-68-29-radius.dynamic.acsalaska.net	2018-07-30 10:45:09.866718-07
24	cpe-69-132-98-0.carolina.res.rr.com	2018-07-30 10:52:13.898676-07
25	cpe-69-132-98-0.carolina.res.rr.com	2018-07-30 10:59:53.683211-07
26	cpe-69-132-98-0.carolina.res.rr.com	2018-07-30 11:23:03.207088-07
27	cpe-69-132-98-0.carolina.res.rr.com	2018-07-30 11:28:28.033818-07
28	63-140-68-29-radius.dynamic.acsalaska.net	2018-07-30 11:45:44.02521-07
29	cpe-69-132-98-0.carolina.res.rr.com	2018-07-30 11:48:45.799334-07
30	cpe-69-132-98-0.carolina.res.rr.com	2018-07-30 12:11:56.66984-07
31	cpe-69-132-98-0.carolina.res.rr.com	2018-07-30 12:22:30.084717-07
32	cpe-69-132-98-0.carolina.res.rr.com	2018-07-30 12:27:59.980236-07
33	cpe-69-132-98-0.carolina.res.rr.com	2018-07-30 12:35:58.095366-07
34	63-140-68-29-radius.dynamic.acsalaska.net	2018-07-30 12:46:36.634806-07
35	cpe-69-132-98-0.carolina.res.rr.com	2018-07-30 12:46:58.23341-07
36	cpe-69-132-98-0.carolina.res.rr.com	2018-07-30 12:49:43.443346-07
37	cpe-69-132-98-0.carolina.res.rr.com	2018-07-30 13:11:56.008654-07
38	63-140-68-29-radius.dynamic.acsalaska.net	2018-07-30 13:47:17.862132-07
39	63-140-68-29-radius.dynamic.acsalaska.net	2018-07-30 14:48:15.558124-07
40	63-140-68-29-radius.dynamic.acsalaska.net	2018-07-30 15:49:10.084816-07
41	190.147.153.196	2018-07-30 16:07:24.959621-07
42	190.147.153.196	2018-07-30 16:25:13.170592-07
43	63-140-68-29-radius.dynamic.acsalaska.net	2018-07-30 16:50:03.712576-07
44	63-140-68-29-radius.dynamic.acsalaska.net	2018-07-30 17:51:12.398646-07
45	63-140-68-29-radius.dynamic.acsalaska.net	2018-07-30 18:51:43.832319-07
46	63-140-68-29-radius.dynamic.acsalaska.net	2018-07-30 19:52:16.097002-07
47	63-140-68-29-radius.dynamic.acsalaska.net	2018-07-30 20:53:09.073039-07
48	63-140-68-29-radius.dynamic.acsalaska.net	2018-07-30 21:54:01.687019-07
49	63-140-68-29-radius.dynamic.acsalaska.net	2018-07-31 00:07:37.791352-07
50	cpe-69-132-98-0.carolina.res.rr.com	2018-07-31 03:33:59.994255-07
1	cpe-69-132-98-0.carolina.res.rr.com	2018-07-31 05:27:37.195739-07
2	cpe-69-132-98-0.carolina.res.rr.com	2018-07-31 05:36:36.783216-07
3	cpe-69-132-98-0.carolina.res.rr.com	2018-07-31 05:47:31.510712-07
4	cpe-69-132-98-0.carolina.res.rr.com	2018-07-31 06:02:06.284445-07
5	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-07-31 06:27:28.328903-07
6	cpe-69-132-98-0.carolina.res.rr.com	2018-07-31 07:04:01.6555-07
7	cpe-69-132-98-0.carolina.res.rr.com	2018-07-31 11:05:11.800237-07
8	cpe-69-132-98-0.carolina.res.rr.com	2018-07-31 11:17:38.57878-07
9	cpe-69-132-98-0.carolina.res.rr.com	2018-07-31 11:34:45.961702-07
10	cpe-69-132-98-0.carolina.res.rr.com	2018-07-31 12:10:06.515881-07
11	cpe-69-132-98-0.carolina.res.rr.com	2018-07-31 12:20:38.083085-07
12	cpe-69-132-98-0.carolina.res.rr.com	2018-07-31 12:25:43.011464-07
13	cpe-69-132-98-0.carolina.res.rr.com	2018-07-31 12:34:08.454563-07
14	cpe-69-132-98-0.carolina.res.rr.com	2018-07-31 12:41:13.458089-07
15	190.147.153.196	2018-07-31 12:54:50.056156-07
1	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-01 06:07:19.486692-07
2	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-01 06:13:54.921189-07
3	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-01 06:17:42.208225-07
4	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-01 06:23:20.775876-07
5	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-01 06:30:45.017252-07
6	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-01 06:35:24.651536-07
7	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-01 06:44:10.822096-07
8	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-01 06:55:08.51799-07
9	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-01 07:15:57.259345-07
10	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-01 07:22:09.195022-07
11	cpe-69-132-98-0.carolina.res.rr.com	2018-08-01 07:27:19.691891-07
12	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-01 07:32:08.195681-07
13	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-01 07:42:42.637384-07
14	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-01 08:03:46.969618-07
15	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-01 08:16:46.910993-07
18	cpe-69-132-98-0.carolina.res.rr.com	2018-08-01 09:15:10.256681-07
19	cpe-69-132-98-0.carolina.res.rr.com	2018-08-01 09:24:56.233295-07
20	cpe-69-132-98-0.carolina.res.rr.com	2018-08-01 09:35:41.012269-07
21	cpe-69-132-98-0.carolina.res.rr.com	2018-08-01 09:40:43.760608-07
22	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-01 09:43:06.425881-07
23	cpe-69-132-98-0.carolina.res.rr.com	2018-08-01 09:48:43.683234-07
24	cpe-69-132-98-0.carolina.res.rr.com	2018-08-01 09:59:50.444053-07
25	cpe-69-132-98-0.carolina.res.rr.com	2018-08-01 10:07:25.811248-07
26	cpe-69-132-98-0.carolina.res.rr.com	2018-08-01 10:09:54.965049-07
27	cpe-69-132-98-0.carolina.res.rr.com	2018-08-01 10:33:35.422022-07
28	190.147.153.196	2018-08-01 10:35:36.780487-07
29	cpe-69-132-98-0.carolina.res.rr.com	2018-08-01 10:38:50.775256-07
30	cpe-69-132-98-0.carolina.res.rr.com	2018-08-01 10:40:56.761417-07
31	190.147.153.196	2018-08-01 10:44:33.291286-07
32	cpe-69-132-98-0.carolina.res.rr.com	2018-08-01 10:52:57.506576-07
33	190.147.153.196	2018-08-01 10:55:26.771209-07
34	cpe-69-132-98-0.carolina.res.rr.com	2018-08-01 11:01:40.689209-07
35	cpe-69-132-98-0.carolina.res.rr.com	2018-08-01 11:06:31.012565-07
36	190.147.153.196	2018-08-01 11:09:55.65665-07
37	cpe-69-132-98-0.carolina.res.rr.com	2018-08-01 11:11:35.239024-07
38	cpe-69-132-98-0.carolina.res.rr.com	2018-08-01 11:16:40.071001-07
39	190.147.153.196	2018-08-01 11:19:00.895215-07
40	cpe-69-132-98-0.carolina.res.rr.com	2018-08-01 11:22:18.347319-07
41	190.147.153.196	2018-08-01 11:29:56.52936-07
42	cpe-69-132-98-0.carolina.res.rr.com	2018-08-01 11:30:28.189985-07
43	190.147.153.196	2018-08-01 11:34:13.810191-07
44	cpe-69-132-98-0.carolina.res.rr.com	2018-08-01 11:35:28.238232-07
45	190.147.153.196	2018-08-01 11:36:23.12359-07
46	cpe-69-132-98-0.carolina.res.rr.com	2018-08-01 11:38:08.2071-07
47	190.147.153.196	2018-08-01 11:43:38.025973-07
48	cpe-69-132-98-0.carolina.res.rr.com	2018-08-01 11:43:48.969086-07
49	cpe-69-132-98-0.carolina.res.rr.com	2018-08-01 11:49:28.595656-07
50	cpe-69-132-98-0.carolina.res.rr.com	2018-08-01 11:52:08.054247-07
51	190.147.153.196	2018-08-01 11:54:26.267039-07
52	cpe-69-132-98-0.carolina.res.rr.com	2018-08-01 11:58:08.067052-07
53	cpe-69-132-98-0.carolina.res.rr.com	2018-08-01 12:03:53.10212-07
54	cpe-69-132-98-0.carolina.res.rr.com	2018-08-01 12:09:33.794865-07
55	190.147.153.196	2018-08-01 12:46:06.372685-07
56	190.147.153.196	2018-08-01 12:51:11.269907-07
57	cpe-69-132-98-0.carolina.res.rr.com	2018-08-01 12:52:42.073313-07
58	190.147.153.196	2018-08-01 12:56:52.271992-07
59	cpe-69-132-98-0.carolina.res.rr.com	2018-08-01 13:03:32.102224-07
60	190.147.153.196	2018-08-01 13:07:46.051495-07
61	cpe-69-132-98-0.carolina.res.rr.com	2018-08-01 13:10:04.522277-07
62	cpe-69-132-98-0.carolina.res.rr.com	2018-08-01 13:15:29.472549-07
63	cpe-69-132-98-0.carolina.res.rr.com	2018-08-01 13:21:09.368909-07
64	190.147.153.196	2018-08-01 13:28:37.974057-07
65	190.147.153.196	2018-08-01 13:47:12.251127-07
66	190.147.153.196	2018-08-01 13:56:28.823532-07
67	190.147.153.196	2018-08-01 15:03:04.733061-07
68	216-67-119-37-radius.dynamic.acsalaska.net	2018-08-01 15:43:09.219991-07
69	216-67-119-37-radius.dynamic.acsalaska.net	2018-08-01 22:21:08.741841-07
70	cpe-69-132-98-0.carolina.res.rr.com	2018-08-02 03:41:30.728207-07
71	cpe-69-132-98-0.carolina.res.rr.com	2018-08-02 04:11:56.347358-07
72	cpe-69-132-98-0.carolina.res.rr.com	2018-08-02 04:20:42.708749-07
73	cpe-69-132-98-0.carolina.res.rr.com	2018-08-02 04:26:47.639502-07
74	cpe-69-132-98-0.carolina.res.rr.com	2018-08-02 05:07:26.038281-07
75	cpe-69-132-98-0.carolina.res.rr.com	2018-08-02 05:21:47.158785-07
76	cpe-69-132-98-0.carolina.res.rr.com	2018-08-02 05:27:27.20923-07
77	cpe-69-132-98-0.carolina.res.rr.com	2018-08-02 05:32:32.30307-07
78	cpe-69-132-98-0.carolina.res.rr.com	2018-08-02 05:37:46.998073-07
79	cpe-69-132-98-0.carolina.res.rr.com	2018-08-02 05:40:06.675249-07
80	cpe-69-132-98-0.carolina.res.rr.com	2018-08-02 06:10:41.501572-07
81	190.147.153.196	2018-08-02 08:31:24.386973-07
82	190.147.153.196	2018-08-02 11:55:53.517638-07
83	190.147.153.196	2018-08-02 12:04:41.716208-07
84	190.147.153.196	2018-08-02 12:15:17.230027-07
85	190.147.153.196	2018-08-02 12:24:27.960094-07
86	190.147.153.196	2018-08-02 12:30:52.989577-07
87	190.147.153.196	2018-08-02 12:33:26.749838-07
88	190.147.153.196	2018-08-02 12:39:06.766887-07
89	190.147.153.196	2018-08-02 12:46:16.723827-07
90	190.147.153.196	2018-08-02 12:57:16.205627-07
91	190.147.153.196	2018-08-02 13:35:16.061344-07
92	190.147.153.196	2018-08-02 13:54:05.776118-07
93	190.147.153.196	2018-08-02 14:04:08.403006-07
94	190.147.153.196	2018-08-02 14:13:08.646957-07
95	190.147.153.196	2018-08-02 14:21:53.985866-07
96	190.147.153.196	2018-08-02 14:30:49.27288-07
97	190.147.153.196	2018-08-02 14:41:37.205824-07
98	190.147.153.196	2018-08-02 14:56:43.994596-07
99	cpe-69-132-98-0.carolina.res.rr.com	2018-08-03 07:39:12.727698-07
100	cpe-69-132-98-0.carolina.res.rr.com	2018-08-03 08:54:16.623137-07
101	cpe-69-132-98-0.carolina.res.rr.com	2018-08-03 09:03:01.441447-07
102	cpe-69-132-98-0.carolina.res.rr.com	2018-08-03 09:13:36.671253-07
103	cpe-69-132-98-0.carolina.res.rr.com	2018-08-03 09:24:59.225426-07
104	cpe-69-132-98-0.carolina.res.rr.com	2018-08-03 09:34:29.010948-07
105	cpe-69-132-98-0.carolina.res.rr.com	2018-08-03 09:42:26.219226-07
106	cpe-69-132-98-0.carolina.res.rr.com	2018-08-03 09:48:26.236053-07
107	cpe-69-132-98-0.carolina.res.rr.com	2018-08-03 09:55:24.09853-07
108	cpe-69-132-98-0.carolina.res.rr.com	2018-08-03 10:40:25.381707-07
109	cpe-69-132-98-0.carolina.res.rr.com	2018-08-03 10:49:11.331979-07
110	cpe-69-132-98-0.carolina.res.rr.com	2018-08-03 10:57:47.833238-07
111	cpe-69-132-98-0.carolina.res.rr.com	2018-08-03 11:17:01.721129-07
112	cpe-69-132-98-0.carolina.res.rr.com	2018-08-03 11:37:45.872222-07
113	216-67-119-37-radius.dynamic.acsalaska.net	2018-08-04 07:07:41.683017-07
114	216-67-119-37-radius.dynamic.acsalaska.net	2018-08-04 08:18:10.044359-07
115	216-67-119-37-radius.dynamic.acsalaska.net	2018-08-04 08:28:33.260781-07
116	216-67-119-37-radius.dynamic.acsalaska.net	2018-08-04 09:48:47.398205-07
117	216-67-119-37-radius.dynamic.acsalaska.net	2018-08-04 18:21:25.747516-07
118	216-67-119-37-radius.dynamic.acsalaska.net	2018-08-04 19:18:46.370625-07
119	216-67-119-37-radius.dynamic.acsalaska.net	2018-08-05 13:50:16.62585-07
120	216-67-119-37-radius.dynamic.acsalaska.net	2018-08-05 14:18:57.750926-07
121	216-67-119-37-radius.dynamic.acsalaska.net	2018-08-05 14:31:22.822756-07
122	216-67-119-37-radius.dynamic.acsalaska.net	2018-08-05 15:04:23.998185-07
123	216-67-119-37-radius.dynamic.acsalaska.net	2018-08-05 23:08:57.717812-07
124	216-67-119-37-radius.dynamic.acsalaska.net	2018-08-06 01:39:07.513671-07
125	216-67-119-37-radius.dynamic.acsalaska.net	2018-08-06 01:48:12.627764-07
126	216-67-119-37-radius.dynamic.acsalaska.net	2018-08-06 01:59:07.465717-07
127	216-67-119-37-radius.dynamic.acsalaska.net	2018-08-06 02:19:57.192863-07
128	216-67-119-37-radius.dynamic.acsalaska.net	2018-08-06 03:20:55.242639-07
129	cpe-69-132-98-0.carolina.res.rr.com	2018-08-06 03:36:32.856603-07
130	cpe-69-132-98-0.carolina.res.rr.com	2018-08-06 04:10:56.897489-07
131	cpe-69-132-98-0.carolina.res.rr.com	2018-08-06 04:17:19.768479-07
132	216-67-119-37-radius.dynamic.acsalaska.net	2018-08-06 04:21:37.325322-07
133	cpe-69-132-98-0.carolina.res.rr.com	2018-08-06 04:55:07.078185-07
134	216-67-119-37-radius.dynamic.acsalaska.net	2018-08-06 05:22:40.202427-07
135	cpe-69-132-98-0.carolina.res.rr.com	2018-08-06 05:25:35.992818-07
136	cpe-69-132-98-0.carolina.res.rr.com	2018-08-06 05:35:04.060195-07
137	cpe-69-132-98-0.carolina.res.rr.com	2018-08-06 05:44:37.091983-07
138	cpe-69-132-98-0.carolina.res.rr.com	2018-08-06 05:52:56.196474-07
139	cpe-69-132-98-0.carolina.res.rr.com	2018-08-06 06:02:26.230957-07
140	216-67-119-37-radius.dynamic.acsalaska.net	2018-08-06 06:23:22.068283-07
141	cpe-69-132-98-0.carolina.res.rr.com	2018-08-06 06:25:03.318086-07
142	cpe-69-132-98-0.carolina.res.rr.com	2018-08-06 06:39:44.797552-07
143	216-67-119-37-radius.dynamic.acsalaska.net	2018-08-06 07:24:15.631829-07
144	216-67-119-37-radius.dynamic.acsalaska.net	2018-08-06 08:25:19.34422-07
145	cpe-69-132-98-0.carolina.res.rr.com	2018-08-06 08:34:09.451107-07
146	cpe-69-132-98-0.carolina.res.rr.com	2018-08-06 08:44:45.031985-07
147	cpe-69-132-98-0.carolina.res.rr.com	2018-08-06 09:12:10.347286-07
148	cpe-69-132-98-0.carolina.res.rr.com	2018-08-06 09:17:20.845448-07
149	216-67-119-37-radius.dynamic.acsalaska.net	2018-08-06 09:25:55.17438-07
150	cpe-69-132-98-0.carolina.res.rr.com	2018-08-06 09:28:56.931206-07
151	cpe-69-132-98-0.carolina.res.rr.com	2018-08-06 09:39:46.543617-07
152	cpe-69-132-98-0.carolina.res.rr.com	2018-08-06 09:50:06.291374-07
153	cpe-69-132-98-0.carolina.res.rr.com	2018-08-06 09:56:20.702573-07
154	cpe-69-132-98-0.carolina.res.rr.com	2018-08-06 10:01:35.730389-07
155	cpe-69-132-98-0.carolina.res.rr.com	2018-08-06 10:10:03.501646-07
156	cpe-69-132-98-0.carolina.res.rr.com	2018-08-06 10:20:43.300542-07
157	cpe-69-132-98-0.carolina.res.rr.com	2018-08-06 10:25:37.025463-07
158	216-67-119-37-radius.dynamic.acsalaska.net	2018-08-06 10:26:37.297578-07
159	cpe-69-132-98-0.carolina.res.rr.com	2018-08-06 10:45:05.902392-07
160	cpe-69-132-98-0.carolina.res.rr.com	2018-08-06 10:55:26.8759-07
161	cpe-69-132-98-0.carolina.res.rr.com	2018-08-06 11:07:54.912287-07
162	216-67-119-37-radius.dynamic.acsalaska.net	2018-08-06 11:27:11.723261-07
163	216-67-119-37-radius.dynamic.acsalaska.net	2018-08-06 12:27:45.6883-07
164	216-67-119-37-radius.dynamic.acsalaska.net	2018-08-06 13:28:35.581869-07
165	216-67-119-37-radius.dynamic.acsalaska.net	2018-08-06 14:29:33.004606-07
166	216-67-119-37-radius.dynamic.acsalaska.net	2018-08-06 15:30:18.068973-07
167	216-67-119-37-radius.dynamic.acsalaska.net	2018-08-06 16:30:56.34758-07
168	216-67-119-37-radius.dynamic.acsalaska.net	2018-08-06 17:31:46.652266-07
169	216-67-119-37-radius.dynamic.acsalaska.net	2018-08-06 18:32:31.567269-07
170	216-67-119-37-radius.dynamic.acsalaska.net	2018-08-06 19:33:23.193432-07
171	216-67-119-37-radius.dynamic.acsalaska.net	2018-08-06 20:34:19.204294-07
172	216-67-119-37-radius.dynamic.acsalaska.net	2018-08-06 21:35:00.873283-07
173	216-67-119-37-radius.dynamic.acsalaska.net	2018-08-06 22:35:56.769366-07
174	216-67-119-37-radius.dynamic.acsalaska.net	2018-08-06 23:36:27.270164-07
175	216-67-119-37-radius.dynamic.acsalaska.net	2018-08-07 00:37:06.964277-07
176	216-67-119-37-radius.dynamic.acsalaska.net	2018-08-07 01:37:48.629438-07
177	216-67-119-37-radius.dynamic.acsalaska.net	2018-08-07 02:38:21.76013-07
178	cpe-69-132-98-0.carolina.res.rr.com	2018-08-07 02:46:17.070214-07
179	cpe-69-132-98-0.carolina.res.rr.com	2018-08-07 03:10:47.134633-07
180	216-67-119-37-radius.dynamic.acsalaska.net	2018-08-07 03:39:16.976879-07
181	cpe-69-132-98-0.carolina.res.rr.com	2018-08-07 03:45:03.405281-07
182	cpe-69-132-98-0.carolina.res.rr.com	2018-08-07 04:55:06.323241-07
183	cpe-69-132-98-0.carolina.res.rr.com	2018-08-07 05:23:27.171646-07
184	cpe-69-132-98-0.carolina.res.rr.com	2018-08-07 05:36:37.326733-07
185	216-67-119-37-radius.dynamic.acsalaska.net	2018-08-07 05:40:22.388956-07
186	cpe-69-132-98-0.carolina.res.rr.com	2018-08-07 05:55:18.766729-07
187	cpe-69-132-98-0.carolina.res.rr.com	2018-08-07 06:16:16.531247-07
188	cpe-69-132-98-0.carolina.res.rr.com	2018-08-07 06:23:38.592083-07
189	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-07 06:35:25.395946-07
190	216-67-119-37-radius.dynamic.acsalaska.net	2018-08-07 06:41:22.064382-07
191	216-67-119-37-radius.dynamic.acsalaska.net	2018-08-07 07:42:13.703391-07
192	cpe-69-132-98-0.carolina.res.rr.com	2018-08-07 07:45:22.128108-07
193	216-67-119-37-radius.dynamic.acsalaska.net	2018-08-07 09:43:00.255168-07
194	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-07 09:59:51.504622-07
195	cpe-69-132-98-0.carolina.res.rr.com	2018-08-07 10:28:18.286139-07
196	216-67-88-235-radius.dynamic.acsalaska.net	2018-08-07 10:43:38.590321-07
197	cpe-69-132-98-0.carolina.res.rr.com	2018-08-07 10:49:20.842738-07
198	cpe-69-132-98-0.carolina.res.rr.com	2018-08-07 10:55:48.786758-07
199	cpe-69-132-98-0.carolina.res.rr.com	2018-08-07 11:10:21.859368-07
200	cpe-69-132-98-0.carolina.res.rr.com	2018-08-07 11:16:21.898212-07
201	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-07 11:25:34.599041-07
202	216-67-88-235-radius.dynamic.acsalaska.net	2018-08-07 11:44:34.024996-07
203	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-07 11:50:42.623604-07
204	cpe-69-132-98-0.carolina.res.rr.com	2018-08-07 11:57:24.371103-07
205	cpe-69-132-98-0.carolina.res.rr.com	2018-08-07 12:07:39.338934-07
206	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-07 12:24:12.567808-07
207	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-07 12:51:17.32285-07
208	cpe-69-132-98-0.carolina.res.rr.com	2018-08-07 12:52:41.330035-07
209	216-67-88-235-radius.dynamic.acsalaska.net	2018-08-07 13:46:56.954872-07
210	216-67-88-235-radius.dynamic.acsalaska.net	2018-08-07 14:47:47.5639-07
211	216-67-88-235-radius.dynamic.acsalaska.net	2018-08-07 15:16:02.995833-07
212	216-67-88-235-radius.dynamic.acsalaska.net	2018-08-07 16:16:17.919257-07
213	216-67-88-235-radius.dynamic.acsalaska.net	2018-08-07 18:59:36.809221-07
214	216-67-88-235-radius.dynamic.acsalaska.net	2018-08-07 20:57:02.084471-07
215	cpe-69-132-98-0.carolina.res.rr.com	2018-08-08 04:02:17.997558-07
216	cpe-69-132-98-0.carolina.res.rr.com	2018-08-08 04:55:11.341452-07
217	cpe-69-132-98-0.carolina.res.rr.com	2018-08-08 05:07:39.544616-07
218	cpe-69-132-98-0.carolina.res.rr.com	2018-08-08 05:38:46.996407-07
219	cpe-69-132-98-0.carolina.res.rr.com	2018-08-08 05:49:16.715356-07
220	cpe-69-132-98-0.carolina.res.rr.com	2018-08-08 05:52:06.015329-07
221	cpe-69-132-98-0.carolina.res.rr.com	2018-08-08 05:54:05.601723-07
222	cpe-69-132-98-0.carolina.res.rr.com	2018-08-08 06:02:40.407519-07
223	cpe-69-132-98-0.carolina.res.rr.com	2018-08-08 06:52:42.316476-07
224	cpe-69-132-98-0.carolina.res.rr.com	2018-08-08 07:13:50.817244-07
225	cpe-69-132-98-0.carolina.res.rr.com	2018-08-08 07:39:05.223989-07
226	cpe-69-132-98-0.carolina.res.rr.com	2018-08-08 07:46:45.256968-07
227	cpe-69-132-98-0.carolina.res.rr.com	2018-08-08 07:55:28.033805-07
228	cpe-69-132-98-0.carolina.res.rr.com	2018-08-08 08:02:48.242046-07
229	cpe-69-132-98-0.carolina.res.rr.com	2018-08-08 08:08:18.007477-07
230	cpe-69-132-98-0.carolina.res.rr.com	2018-08-08 08:10:38.204947-07
231	cpe-69-132-98-0.carolina.res.rr.com	2018-08-08 08:18:43.127953-07
232	cpe-69-132-98-0.carolina.res.rr.com	2018-08-08 08:27:49.13137-07
233	cpe-69-132-98-0.carolina.res.rr.com	2018-08-08 08:40:01.450575-07
234	cpe-69-132-98-0.carolina.res.rr.com	2018-08-08 08:54:56.28706-07
235	cpe-69-132-98-0.carolina.res.rr.com	2018-08-08 09:00:01.19984-07
236	cpe-69-132-98-0.carolina.res.rr.com	2018-08-08 09:06:11.517201-07
237	cpe-69-132-98-0.carolina.res.rr.com	2018-08-08 09:14:36.631828-07
238	cpe-69-132-98-0.carolina.res.rr.com	2018-08-08 09:38:22.040261-07
239	cpe-69-132-98-0.carolina.res.rr.com	2018-08-08 09:55:25.750683-07
240	cpe-69-132-98-0.carolina.res.rr.com	2018-08-08 10:03:46.181895-07
241	cpe-69-132-98-0.carolina.res.rr.com	2018-08-08 10:10:24.643768-07
242	cpe-69-132-98-0.carolina.res.rr.com	2018-08-08 10:27:02.134042-07
243	cpe-69-132-98-0.carolina.res.rr.com	2018-08-08 10:32:06.993163-07
244	cpe-69-132-98-0.carolina.res.rr.com	2018-08-08 10:42:26.782215-07
245	cpe-69-132-98-0.carolina.res.rr.com	2018-08-08 11:06:35.015537-07
246	cpe-69-132-98-0.carolina.res.rr.com	2018-08-08 11:14:57.918686-07
247	cpe-69-132-98-0.carolina.res.rr.com	2018-08-08 11:49:23.319333-07
248	cpe-69-132-98-0.carolina.res.rr.com	2018-08-08 11:56:27.962235-07
249	cpe-69-132-98-0.carolina.res.rr.com	2018-08-08 11:58:49.638784-07
250	cpe-69-132-98-0.carolina.res.rr.com	2018-08-08 12:16:01.680396-07
251	cpe-69-132-98-0.carolina.res.rr.com	2018-08-08 12:52:22.319757-07
252	cpe-69-132-98-0.carolina.res.rr.com	2018-08-08 12:57:52.351265-07
253	cpe-69-132-98-0.carolina.res.rr.com	2018-08-08 13:00:18.580245-07
254	cpe-69-132-98-0.carolina.res.rr.com	2018-08-08 13:28:37.856135-07
255	cpe-69-132-98-0.carolina.res.rr.com	2018-08-08 13:39:17.718164-07
256	190.147.153.196	2018-08-08 16:06:26.76055-07
257	190.147.153.196	2018-08-09 12:30:57.279604-07
258	190.147.153.196	2018-08-09 12:33:37.764787-07
259	190.147.153.196	2018-08-09 12:46:55.781026-07
260	190.147.153.196	2018-08-09 12:55:05.263224-07
261	190.147.153.196	2018-08-09 13:00:06.095982-07
262	190.147.153.196	2018-08-09 13:02:24.773952-07
263	190.147.153.196	2018-08-09 13:23:55.752685-07
264	190.147.153.196	2018-08-09 16:26:20.085216-07
265	cpe-69-132-98-0.carolina.res.rr.com	2018-08-10 04:14:13.500216-07
266	cpe-69-132-98-0.carolina.res.rr.com	2018-08-10 05:57:57.718832-07
267	cpe-69-132-98-0.carolina.res.rr.com	2018-08-10 06:11:10.006497-07
268	cpe-69-132-98-0.carolina.res.rr.com	2018-08-10 06:19:25.236108-07
269	cpe-69-132-98-0.carolina.res.rr.com	2018-08-10 06:30:29.972388-07
270	cpe-69-132-98-0.carolina.res.rr.com	2018-08-10 06:51:10.165147-07
271	cpe-69-132-98-0.carolina.res.rr.com	2018-08-10 06:55:19.853709-07
272	cpe-69-132-98-0.carolina.res.rr.com	2018-08-10 07:09:22.049866-07
273	cpe-69-132-98-0.carolina.res.rr.com	2018-08-10 07:19:17.185155-07
274	190.147.153.196	2018-08-10 07:27:29.616064-07
275	cpe-69-132-98-0.carolina.res.rr.com	2018-08-10 07:30:08.717505-07
276	cpe-69-132-98-0.carolina.res.rr.com	2018-08-10 07:35:23.909275-07
277	190.147.153.196	2018-08-10 07:36:23.885834-07
278	cpe-69-132-98-0.carolina.res.rr.com	2018-08-10 07:41:15.070308-07
279	190.147.153.196	2018-08-10 07:47:15.329662-07
280	cpe-69-132-98-0.carolina.res.rr.com	2018-08-10 08:02:47.759797-07
281	cpe-69-132-98-0.carolina.res.rr.com	2018-08-10 08:09:25.655871-07
282	cpe-69-132-98-0.carolina.res.rr.com	2018-08-10 08:26:53.450576-07
283	cpe-69-132-98-0.carolina.res.rr.com	2018-08-10 09:49:21.389493-07
284	cpe-69-132-98-0.carolina.res.rr.com	2018-08-10 10:00:21.721198-07
285	cpe-69-132-98-0.carolina.res.rr.com	2018-08-10 10:20:58.977152-07
286	cpe-69-132-98-0.carolina.res.rr.com	2018-08-10 10:50:53.783091-07
287	cpe-69-132-98-0.carolina.res.rr.com	2018-08-10 10:58:40.121596-07
288	cpe-69-132-98-0.carolina.res.rr.com	2018-08-10 11:07:35.256705-07
289	cpe-69-132-98-0.carolina.res.rr.com	2018-08-10 11:18:23.801366-07
290	cpe-69-132-98-0.carolina.res.rr.com	2018-08-10 11:29:34.926021-07
291	cpe-69-132-98-0.carolina.res.rr.com	2018-08-10 11:39:11.055058-07
292	cpe-69-132-98-0.carolina.res.rr.com	2018-08-10 11:49:43.99093-07
293	cpe-69-132-98-0.carolina.res.rr.com	2018-08-10 12:01:00.289469-07
294	cpe-69-132-98-0.carolina.res.rr.com	2018-08-10 12:11:35.28925-07
295	cpe-69-132-98-0.carolina.res.rr.com	2018-08-10 12:32:10.247467-07
296	cpe-69-132-98-0.carolina.res.rr.com	2018-08-10 12:37:50.226849-07
297	cpe-69-132-98-0.carolina.res.rr.com	2018-08-10 13:00:48.240895-07
298	cpe-69-132-98-0.carolina.res.rr.com	2018-08-10 13:07:58.254915-07
299	cpe-69-132-98-0.carolina.res.rr.com	2018-08-10 13:14:31.732461-07
300	cpe-69-132-98-0.carolina.res.rr.com	2018-08-13 03:05:21.134763-07
301	cpe-69-132-98-0.carolina.res.rr.com	2018-08-13 03:15:11.261776-07
302	cpe-69-132-98-0.carolina.res.rr.com	2018-08-13 04:55:08.070691-07
303	cpe-69-132-98-0.carolina.res.rr.com	2018-08-13 05:00:42.986676-07
304	cpe-69-132-98-0.carolina.res.rr.com	2018-08-13 05:02:59.986777-07
305	cpe-69-132-98-0.carolina.res.rr.com	2018-08-13 05:10:09.983357-07
306	cpe-69-132-98-0.carolina.res.rr.com	2018-08-13 05:15:55.106805-07
307	cpe-69-132-98-0.carolina.res.rr.com	2018-08-13 05:18:15.120846-07
308	cpe-69-132-98-0.carolina.res.rr.com	2018-08-13 05:23:40.094678-07
309	cpe-69-132-98-0.carolina.res.rr.com	2018-08-13 05:28:45.184937-07
310	cpe-69-132-98-0.carolina.res.rr.com	2018-08-13 05:34:30.162553-07
311	cpe-69-132-98-0.carolina.res.rr.com	2018-08-13 05:40:30.224906-07
312	cpe-69-132-98-0.carolina.res.rr.com	2018-08-13 05:46:30.174698-07
313	cpe-69-132-98-0.carolina.res.rr.com	2018-08-13 05:57:15.750551-07
314	cpe-69-132-98-0.carolina.res.rr.com	2018-08-13 06:17:47.529139-07
315	cpe-69-132-98-0.carolina.res.rr.com	2018-08-13 06:21:33.882367-07
316	cpe-69-132-98-0.carolina.res.rr.com	2018-08-13 06:40:30.150971-07
317	cpe-69-132-98-0.carolina.res.rr.com	2018-08-13 07:15:45.151217-07
318	190.147.153.196	2018-08-13 08:31:49.733713-07
319	190.147.153.196	2018-08-13 08:40:20.515407-07
320	190.147.153.196	2018-08-13 08:49:30.740768-07
321	cpe-69-132-98-0.carolina.res.rr.com	2018-08-13 08:54:38.674461-07
322	190.147.153.196	2018-08-13 08:55:00.16858-07
323	190.147.153.196	2018-08-13 09:02:25.278815-07
324	cpe-69-132-98-0.carolina.res.rr.com	2018-08-13 09:03:28.882011-07
325	190.147.153.196	2018-08-13 09:08:24.195915-07
326	cpe-69-132-98-0.carolina.res.rr.com	2018-08-13 09:14:19.994513-07
327	cpe-69-132-98-0.carolina.res.rr.com	2018-08-13 09:28:10.790581-07
328	190.147.153.196	2018-08-13 09:34:04.223716-07
329	cpe-69-132-98-0.carolina.res.rr.com	2018-08-13 09:39:03.006609-07
330	cpe-69-132-98-0.carolina.res.rr.com	2018-08-13 09:55:43.342615-07
331	cpe-69-132-98-0.carolina.res.rr.com	2018-08-13 10:01:43.069582-07
332	cpe-69-132-98-0.carolina.res.rr.com	2018-08-13 10:23:45.926684-07
333	cpe-69-132-98-0.carolina.res.rr.com	2018-08-13 11:15:45.794094-07
334	cpe-69-132-98-0.carolina.res.rr.com	2018-08-13 11:24:40.275252-07
335	cpe-69-132-98-0.carolina.res.rr.com	2018-08-13 11:35:22.79808-07
336	cpe-69-132-98-0.carolina.res.rr.com	2018-08-13 11:56:03.659432-07
337	190.147.153.196	2018-08-13 12:02:23.918957-07
338	cpe-69-132-98-0.carolina.res.rr.com	2018-08-13 12:03:34.014721-07
339	190.147.153.196	2018-08-13 12:08:54.014204-07
340	190.147.153.196	2018-08-13 12:11:05.513605-07
341	190.147.153.196	2018-08-13 12:29:40.88102-07
342	cpe-69-132-98-0.carolina.res.rr.com	2018-08-13 12:33:20.294485-07
343	cpe-69-132-98-0.carolina.res.rr.com	2018-08-13 12:38:50.097253-07
344	cpe-69-132-98-0.carolina.res.rr.com	2018-08-13 12:41:05.993988-07
345	cpe-69-132-98-0.carolina.res.rr.com	2018-08-13 12:46:55.708429-07
346	190.147.153.196	2018-08-14 08:43:34.301165-07
347	cpe-69-132-98-0.carolina.res.rr.com	2018-08-14 09:44:38.580005-07
348	cpe-69-132-98-0.carolina.res.rr.com	2018-08-14 10:14:07.839518-07
349	cpe-69-132-98-0.carolina.res.rr.com	2018-08-14 10:14:54.284872-07
350	190.147.153.196	2018-08-14 10:16:11.022946-07
351	190.147.153.196	2018-08-14 10:21:10.093848-07
352	cpe-69-132-98-0.carolina.res.rr.com	2018-08-14 10:23:39.225814-07
353	190.147.153.196	2018-08-14 10:30:20.259877-07
354	cpe-69-132-98-0.carolina.res.rr.com	2018-08-14 10:34:39.021116-07
355	190.147.153.196	2018-08-14 10:41:10.130906-07
356	cpe-69-132-98-0.carolina.res.rr.com	2018-08-14 10:55:35.41986-07
357	cpe-69-132-98-0.carolina.res.rr.com	2018-08-14 11:20:46.768197-07
358	cpe-69-132-98-0.carolina.res.rr.com	2018-08-14 11:26:31.745985-07
359	cpe-69-132-98-0.carolina.res.rr.com	2018-08-14 11:31:51.725013-07
360	cpe-69-132-98-0.carolina.res.rr.com	2018-08-14 11:33:43.27943-07
361	cpe-69-132-98-0.carolina.res.rr.com	2018-08-14 11:39:03.203571-07
362	190.147.153.196	2018-08-14 12:01:13.703514-07
363	cpe-69-132-98-0.carolina.res.rr.com	2018-08-14 12:03:12.27301-07
364	190.147.153.196	2018-08-14 12:03:37.581165-07
365	190.147.153.196	2018-08-14 12:23:15.461963-07
366	190.147.153.196	2018-08-14 12:30:41.159493-07
367	190.147.153.196	2018-08-14 12:32:50.098595-07
368	190.147.153.196	2018-08-14 12:42:45.47062-07
369	190.147.153.196	2018-08-14 12:50:30.587361-07
370	190.147.153.196	2018-08-14 12:59:15.380115-07
371	190.147.153.196	2018-08-14 13:09:57.713919-07
372	190.147.153.196	2018-08-14 13:15:26.982682-07
373	190.147.153.196	2018-08-14 14:54:40.400465-07
374	190.147.153.196	2018-08-14 15:46:18.025396-07
375	190.147.153.196	2018-08-15 09:34:38.867216-07
376	190.147.153.196	2018-08-15 12:16:19.659394-07
377	190.147.153.196	2018-08-15 12:26:29.282048-07
378	190.147.153.196	2018-08-15 12:37:09.011953-07
379	190.147.153.196	2018-08-15 12:58:10.127803-07
380	190.147.153.196	2018-08-15 13:37:25.951835-07
381	190.147.153.196	2018-08-15 13:46:43.038241-07
382	190.147.153.196	2018-08-15 13:52:12.99131-07
383	190.147.153.196	2018-08-15 14:01:12.981244-07
384	190.147.153.196	2018-08-15 14:12:10.734702-07
385	190.147.153.196	2018-08-15 14:32:45.28322-07
386	190.147.153.196	2018-08-15 15:33:16.003704-07
387	190.147.153.196	2018-08-16 06:39:46.358634-07
388	190.147.153.196	2018-08-16 06:40:19.974234-07
389	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-16 10:22:01.208928-07
390	190.147.153.196	2018-08-16 11:37:59.335697-07
391	190.147.153.196	2018-08-16 11:40:36.99488-07
392	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-16 12:20:42.223019-07
393	190.147.153.196	2018-08-16 12:24:55.211085-07
394	190.147.153.196	2018-08-16 12:45:32.002634-07
395	190.147.153.196	2018-08-16 13:46:14.983392-07
396	190.147.153.196	2018-08-16 13:57:25.132685-07
397	190.147.153.196	2018-08-16 14:06:10.286746-07
398	190.147.153.196	2018-08-16 14:11:29.700454-07
399	190.147.153.196	2018-08-16 14:20:25.027551-07
400	190.147.153.196	2018-08-16 14:31:15.994105-07
401	190.147.153.196	2018-08-16 14:52:07.883964-07
402	190.147.153.196	2018-08-16 15:52:45.456531-07
403	190.147.153.196	2018-08-16 16:03:41.969982-07
404	190.147.153.196	2018-08-16 16:09:07.048341-07
405	190.147.153.196	2018-08-16 16:17:20.163406-07
406	190.147.153.196	2018-08-16 16:28:00.078648-07
407	190.147.153.196	2018-08-16 16:48:43.215877-07
408	190.147.153.196	2018-08-16 17:38:05.097823-07
409	190.147.153.196	2018-08-16 17:46:45.721101-07
410	190.147.153.196	2018-08-16 17:55:25.985163-07
411	190.147.153.196	2018-08-16 18:06:14.989875-07
412	190.147.153.196	2018-08-16 18:19:06.012447-07
413	190.147.153.196	2018-08-16 18:28:00.966745-07
414	cpe-69-132-98-0.carolina.res.rr.com	2018-08-17 03:09:27.390651-07
415	cpe-69-132-98-0.carolina.res.rr.com	2018-08-17 03:28:10.936679-07
416	cpe-69-132-98-0.carolina.res.rr.com	2018-08-17 03:36:56.14626-07
417	cpe-69-132-98-0.carolina.res.rr.com	2018-08-17 03:47:31.350602-07
418	cpe-69-132-98-0.carolina.res.rr.com	2018-08-17 04:07:34.035302-07
419	cpe-69-132-98-0.carolina.res.rr.com	2018-08-17 04:13:33.736674-07
420	cpe-69-132-98-0.carolina.res.rr.com	2018-08-17 04:19:17.97761-07
421	cpe-69-132-98-0.carolina.res.rr.com	2018-08-17 04:22:43.719893-07
422	cpe-69-132-98-0.carolina.res.rr.com	2018-08-17 04:31:53.983393-07
423	cpe-69-132-98-0.carolina.res.rr.com	2018-08-17 04:42:46.505582-07
424	cpe-69-132-98-0.carolina.res.rr.com	2018-08-17 05:32:21.461816-07
425	cpe-69-132-98-0.carolina.res.rr.com	2018-08-17 05:57:15.924286-07
426	cpe-69-132-98-0.carolina.res.rr.com	2018-08-17 06:06:31.337451-07
427	cpe-69-132-98-0.carolina.res.rr.com	2018-08-17 06:09:09.853743-07
428	cpe-69-132-98-0.carolina.res.rr.com	2018-08-17 06:15:59.751592-07
429	cpe-69-132-98-0.carolina.res.rr.com	2018-08-17 06:24:41.933172-07
430	cpe-69-132-98-0.carolina.res.rr.com	2018-08-17 06:33:42.780393-07
431	cpe-69-132-98-0.carolina.res.rr.com	2018-08-17 06:39:59.028857-07
432	cpe-69-132-98-0.carolina.res.rr.com	2018-08-17 06:49:14.022428-07
433	cpe-69-132-98-0.carolina.res.rr.com	2018-08-17 06:52:28.933854-07
434	cpe-69-132-98-0.carolina.res.rr.com	2018-08-17 07:01:44.236614-07
435	cpe-69-132-98-0.carolina.res.rr.com	2018-08-17 07:07:19.21177-07
436	cpe-69-132-98-0.carolina.res.rr.com	2018-08-17 07:09:25.870365-07
437	cpe-69-132-98-0.carolina.res.rr.com	2018-08-17 07:22:41.093423-07
438	cpe-69-132-98-0.carolina.res.rr.com	2018-08-17 07:30:11.515599-07
439	cpe-69-132-98-0.carolina.res.rr.com	2018-08-17 07:36:51.26259-07
440	cpe-69-132-98-0.carolina.res.rr.com	2018-08-17 07:39:14.994227-07
441	cpe-69-132-98-0.carolina.res.rr.com	2018-08-17 07:46:44.947444-07
442	cpe-69-132-98-0.carolina.res.rr.com	2018-08-17 07:56:23.204854-07
443	cpe-69-132-98-0.carolina.res.rr.com	2018-08-17 08:05:33.193836-07
444	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-17 08:11:31.610342-07
445	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-17 08:30:11.198338-07
446	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-17 08:50:45.71914-07
447	cpe-69-132-98-0.carolina.res.rr.com	2018-08-17 08:52:39.934538-07
448	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-17 08:59:45.246211-07
449	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-17 09:12:43.983074-07
450	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-17 09:18:58.975847-07
451	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-17 09:25:54.719837-07
452	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-17 09:34:44.959113-07
453	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-17 09:45:38.092355-07
454	cpe-69-132-98-0.carolina.res.rr.com	2018-08-17 10:09:08.646229-07
455	cpe-69-132-98-0.carolina.res.rr.com	2018-08-17 10:11:27.753447-07
456	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-17 10:13:32.951534-07
457	cpe-69-132-98-0.carolina.res.rr.com	2018-08-17 10:17:13.302878-07
458	cpe-69-132-98-0.carolina.res.rr.com	2018-08-17 10:23:22.719724-07
459	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-17 11:03:17.321316-07
460	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-17 11:12:01.950986-07
461	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-17 11:17:56.95344-07
462	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-17 11:23:55.001421-07
463	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-17 11:34:27.623951-07
464	190.147.153.196	2018-08-17 11:45:48.199659-07
465	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-17 11:55:19.743632-07
466	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-17 12:23:00.795882-07
467	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-17 12:31:51.949893-07
468	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-17 14:02:32.926983-07
469	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-17 15:03:21.109548-07
470	190.147.153.196	2018-08-17 15:27:26.102713-07
471	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-17 16:04:01.982803-07
472	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-17 17:04:37.216884-07
473	190.147.153.196	2018-08-17 17:26:33.029386-07
474	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-17 18:05:30.512516-07
475	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-17 19:06:38.964367-07
476	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-17 20:07:15.807408-07
477	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-17 21:08:13.946089-07
478	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-17 23:09:22.254408-07
479	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-18 00:10:08.154464-07
480	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-18 01:10:59.802196-07
481	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-18 02:11:31.19971-07
482	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-18 03:12:28.192326-07
483	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-18 04:13:15.899516-07
484	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-18 05:13:56.992742-07
485	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-18 06:14:41.557191-07
486	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-18 07:15:30.955539-07
487	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-18 08:16:28.966408-07
488	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-18 09:17:31.955378-07
489	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-18 10:18:35.151468-07
490	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-18 11:19:09.220359-07
491	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-18 12:20:02.919236-07
492	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-18 12:25:15.134394-07
493	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-18 12:44:14.728135-07
494	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-18 13:05:08.075487-07
495	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-18 14:06:12.876339-07
496	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-18 15:07:12.970108-07
497	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-18 16:07:50.982632-07
498	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-18 17:08:30.022281-07
499	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-18 18:09:27.350792-07
500	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-18 19:10:21.329392-07
501	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-18 20:11:14.902224-07
502	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-18 21:11:46.86884-07
503	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-18 21:20:27.83279-07
504	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-18 21:51:01.955433-07
505	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-18 22:52:08.716499-07
506	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-18 23:53:16.873818-07
507	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-19 00:53:56.135423-07
508	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-19 01:55:13.154596-07
509	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-19 02:55:51.085665-07
510	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-19 03:56:46.857778-07
511	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-19 04:57:20.850865-07
512	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-19 05:57:51.145085-07
513	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-19 06:58:50.007388-07
514	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-19 07:59:38.08273-07
515	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-19 09:00:08.52013-07
516	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-19 10:00:49.325308-07
517	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-19 11:01:37.08337-07
518	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-19 12:02:22.725565-07
519	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-19 12:27:41.206933-07
520	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-19 12:36:36.93946-07
521	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-19 12:47:37.706663-07
522	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-19 13:08:51.020479-07
523	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-19 14:09:37.995079-07
524	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-19 15:10:29.913424-07
525	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-19 16:11:08.208359-07
526	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-19 17:12:07.047756-07
527	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-19 18:12:59.812257-07
528	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-19 19:13:57.162665-07
529	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-19 20:14:38.750729-07
530	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-19 21:15:18.955539-07
531	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-19 22:16:07.960474-07
532	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-20 00:17:04.156305-07
533	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-20 01:18:05.120145-07
534	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-20 02:18:45.720209-07
535	cpe-69-132-98-0.carolina.res.rr.com	2018-08-20 02:21:47.074925-07
536	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-20 03:19:19.045003-07
537	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-20 04:20:04.096425-07
538	cpe-69-132-98-0.carolina.res.rr.com	2018-08-20 04:55:10.810356-07
539	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-20 05:20:35.498411-07
540	cpe-69-132-98-0.carolina.res.rr.com	2018-08-20 05:52:36.0858-07
541	cpe-69-132-98-0.carolina.res.rr.com	2018-08-20 06:08:12.290414-07
542	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-20 06:11:16.98032-07
543	cpe-69-132-98-0.carolina.res.rr.com	2018-08-20 06:13:36.982679-07
544	cpe-69-132-98-0.carolina.res.rr.com	2018-08-20 06:19:06.998414-07
545	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-20 06:20:16.977947-07
546	cpe-69-132-98-0.carolina.res.rr.com	2018-08-20 06:21:07.252956-07
547	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-20 06:26:23.221425-07
548	cpe-69-132-98-0.carolina.res.rr.com	2018-08-20 06:28:42.191075-07
549	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-20 06:35:05.182191-07
550	cpe-69-132-98-0.carolina.res.rr.com	2018-08-20 06:35:27.342548-07
551	cpe-69-132-98-0.carolina.res.rr.com	2018-08-20 06:38:22.131902-07
552	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-20 06:45:37.17419-07
553	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-20 06:54:05.445846-07
554	cpe-69-132-98-0.carolina.res.rr.com	2018-08-20 06:59:14.882189-07
555	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-20 07:04:02.085348-07
556	cpe-69-132-98-0.carolina.res.rr.com	2018-08-20 07:04:17.033596-07
557	cpe-69-132-98-0.carolina.res.rr.com	2018-08-20 07:08:43.866002-07
558	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-20 07:15:06.95385-07
559	cpe-69-132-98-0.carolina.res.rr.com	2018-08-20 07:28:40.04585-07
560	cpe-69-132-98-0.carolina.res.rr.com	2018-08-20 07:34:15.216009-07
561	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-20 07:35:42.07596-07
562	cpe-69-132-98-0.carolina.res.rr.com	2018-08-20 07:49:57.274691-07
563	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-20 07:54:52.233683-07
564	cpe-69-132-98-0.carolina.res.rr.com	2018-08-20 07:56:18.782585-07
565	cpe-69-132-98-0.carolina.res.rr.com	2018-08-20 08:02:23.702755-07
566	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-20 08:05:37.236648-07
567	cpe-69-132-98-0.carolina.res.rr.com	2018-08-20 08:07:53.08379-07
568	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-20 08:40:47.586945-07
569	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-20 08:49:27.034789-07
570	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-20 08:51:16.299071-07
571	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-20 08:54:09.286422-07
572	cpe-69-132-98-0.carolina.res.rr.com	2018-08-20 09:01:28.832335-07
573	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-20 09:02:33.866534-07
574	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-20 09:11:13.416752-07
575	cpe-69-132-98-0.carolina.res.rr.com	2018-08-20 09:12:22.361602-07
576	cpe-69-132-98-0.carolina.res.rr.com	2018-08-20 09:29:59.999749-07
577	cpe-69-132-98-0.carolina.res.rr.com	2018-08-20 09:39:47.810563-07
578	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-20 09:41:49.208551-07
579	cpe-69-132-98-0.carolina.res.rr.com	2018-08-20 09:48:38.045904-07
580	cpe-69-132-98-0.carolina.res.rr.com	2018-08-20 09:55:15.796032-07
581	cpe-69-132-98-0.carolina.res.rr.com	2018-08-20 10:11:38.864151-07
582	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-20 10:25:54.309786-07
583	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-20 10:34:25.278317-07
584	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-20 10:43:30.201422-07
585	cpe-69-132-98-0.carolina.res.rr.com	2018-08-20 10:46:36.166214-07
586	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-20 10:54:15.613611-07
587	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-20 11:15:07.99219-07
588	cpe-69-132-98-0.carolina.res.rr.com	2018-08-20 11:28:22.516556-07
589	cpe-69-132-98-0.carolina.res.rr.com	2018-08-20 11:35:53.064856-07
590	cpe-69-132-98-0.carolina.res.rr.com	2018-08-20 11:41:08.005977-07
591	cpe-69-132-98-0.carolina.res.rr.com	2018-08-20 11:43:32.191047-07
592	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-20 11:53:06.015298-07
593	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-20 12:01:55.168341-07
594	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-20 12:12:43.813275-07
595	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-20 12:29:51.950597-07
596	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-20 12:38:55.013492-07
597	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-20 13:09:53.62825-07
598	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-20 13:15:48.116456-07
599	23.226.229.209	2018-08-20 14:09:59.566528-07
600	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-20 14:12:00.17246-07
601	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-20 15:12:37.13456-07
602	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-20 16:13:25.231481-07
603	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-20 18:14:08.19428-07
604	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-20 19:15:11.144598-07
605	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-20 20:15:58.955274-07
606	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-20 22:16:50.195281-07
607	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-20 23:17:28.71346-07
608	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-21 00:18:08.141848-07
609	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-21 01:18:40.183746-07
610	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-21 01:37:46.919785-07
611	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-21 02:58:22.806052-07
612	cpe-69-132-98-0.carolina.res.rr.com	2018-08-21 03:22:06.08773-07
613	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-21 03:59:21.088079-07
614	cpe-69-132-98-0.carolina.res.rr.com	2018-08-21 04:55:10.433134-07
615	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-21 05:00:11.922183-07
616	cpe-69-132-98-0.carolina.res.rr.com	2018-08-21 05:50:05.791174-07
617	cpe-69-132-98-0.carolina.res.rr.com	2018-08-21 05:59:08.195437-07
618	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-21 06:00:41.255778-07
619	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-21 06:32:28.891043-07
620	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-21 06:37:38.988205-07
621	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-21 06:46:53.752977-07
622	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-21 06:57:38.081329-07
623	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-21 07:18:30.094111-07
624	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-21 08:19:15.520628-07
625	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-21 08:42:21.743212-07
626	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-21 08:44:46.797529-07
627	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-21 08:52:07.713327-07
628	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-21 09:03:08.186911-07
629	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-21 09:08:56.345756-07
630	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-21 09:17:36.806507-07
631	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-21 09:48:24.840119-07
632	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-21 10:59:40.319786-07
633	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-21 11:08:14.71065-07
634	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-21 11:19:07.724754-07
635	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-21 11:26:11.214745-07
636	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-21 11:28:50.984703-07
637	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-21 11:36:20.89716-07
638	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-21 11:47:42.698487-07
639	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-21 11:54:21.353688-07
640	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-21 12:05:37.043317-07
641	190.147.153.196	2018-08-21 12:17:31.790899-07
642	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-21 12:27:13.253324-07
643	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-21 12:32:15.154612-07
644	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-21 12:35:53.728487-07
645	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-21 13:29:13.986918-07
646	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-21 14:50:00.204753-07
647	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-21 15:50:56.779625-07
648	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-21 16:51:38.083154-07
649	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-21 18:53:11.520744-07
650	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-21 19:54:00.743306-07
651	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-21 20:54:38.351892-07
652	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-21 21:55:20.759003-07
653	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-21 22:56:07.956324-07
654	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-21 23:56:57.349135-07
655	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-22 00:57:33.95954-07
656	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-22 01:58:09.152602-07
657	cpe-69-132-98-0.carolina.res.rr.com	2018-08-22 02:34:39.086948-07
658	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-22 02:58:58.96084-07
659	cpe-69-132-98-0.carolina.res.rr.com	2018-08-22 03:45:12.082694-07
660	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-22 04:00:01.576113-07
661	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-22 05:01:05.866834-07
662	cpe-69-132-98-0.carolina.res.rr.com	2018-08-22 05:53:22.401571-07
663	cpe-69-132-98-0.carolina.res.rr.com	2018-08-22 05:56:05.776474-07
664	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-22 06:01:37.749468-07
665	cpe-69-132-98-0.carolina.res.rr.com	2018-08-22 06:05:11.716798-07
666	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-22 06:13:42.963108-07
667	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-22 06:19:07.052072-07
668	cpe-69-132-98-0.carolina.res.rr.com	2018-08-22 06:20:48.193604-07
669	cpe-69-132-98-0.carolina.res.rr.com	2018-08-22 06:35:18.303768-07
670	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-22 07:10:39.70578-07
671	cpe-69-132-98-0.carolina.res.rr.com	2018-08-22 07:12:43.386274-07
672	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-22 07:19:46.265324-07
673	cpe-69-132-98-0.carolina.res.rr.com	2018-08-22 07:36:44.567717-07
674	cpe-69-132-98-0.carolina.res.rr.com	2018-08-22 07:42:14.102312-07
675	cpe-69-132-98-0.carolina.res.rr.com	2018-08-22 07:52:50.225549-07
676	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-22 07:56:06.128639-07
677	cpe-69-132-98-0.carolina.res.rr.com	2018-08-22 08:00:03.228061-07
678	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-22 08:01:08.449372-07
679	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-22 08:06:52.967963-07
680	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-22 08:17:58.236774-07
681	cpe-69-132-98-0.carolina.res.rr.com	2018-08-22 08:21:41.682613-07
682	190.147.153.196	2018-08-22 08:32:53.974213-07
683	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-22 08:39:02.941511-07
684	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-22 09:39:37.722275-07
685	190.147.153.196	2018-08-22 10:13:14.866543-07
686	cpe-69-132-98-0.carolina.res.rr.com	2018-08-22 10:18:38.263723-07
687	190.147.153.196	2018-08-22 10:22:23.996334-07
688	190.147.153.196	2018-08-22 10:46:44.781756-07
689	cpe-69-132-98-0.carolina.res.rr.com	2018-08-22 11:11:31.905529-07
690	190.147.153.196	2018-08-22 11:14:46.205895-07
691	190.147.153.196	2018-08-22 11:24:45.109823-07
692	190.147.153.196	2018-08-22 11:29:42.15619-07
693	cpe-69-132-98-0.carolina.res.rr.com	2018-08-22 11:39:06.604585-07
694	cpe-69-132-98-0.carolina.res.rr.com	2018-08-22 11:44:20.935166-07
695	190.147.153.196	2018-08-22 12:19:12.901582-07
696	190.147.153.196	2018-08-22 12:30:21.884069-07
697	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-22 12:57:40.101284-07
698	190.147.153.196	2018-08-22 13:01:07.191733-07
699	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-22 13:44:47.280395-07
700	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-22 13:53:54.326415-07
701	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-22 14:04:41.239038-07
702	190.147.153.196	2018-08-22 14:22:12.754882-07
703	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-22 14:25:37.825464-07
704	190.147.153.196	2018-08-22 15:23:08.193659-07
705	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-22 15:26:14.259735-07
706	190.147.153.196	2018-08-22 16:24:03.842708-07
707	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-22 16:27:09.031153-07
708	190.147.153.196	2018-08-22 16:33:13.786668-07
709	190.147.153.196	2018-08-22 16:38:29.735439-07
710	190.147.153.196	2018-08-22 16:54:13.730381-07
711	190.147.153.196	2018-08-22 17:14:46.324622-07
712	190.147.153.196	2018-08-22 17:27:42.227314-07
713	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-22 17:28:00.000259-07
714	190.147.153.196	2018-08-22 17:37:11.171582-07
715	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-22 18:28:44.795756-07
716	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-22 19:30:05.897206-07
717	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-22 20:30:43.090957-07
718	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-22 21:31:38.212505-07
719	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-22 22:32:01.214085-07
720	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-22 23:32:43.116241-07
721	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-23 00:33:40.945981-07
722	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-23 01:34:37.708214-07
723	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-23 02:35:44.063763-07
724	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-23 03:36:29.790788-07
725	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-23 04:37:07.79031-07
726	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-23 05:38:15.050794-07
727	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-23 05:40:36.615887-07
728	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-23 05:58:04.312712-07
729	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-23 06:04:44.545938-07
730	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-23 06:13:37.38894-07
731	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-23 06:19:11.276559-07
732	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-23 06:28:21.101962-07
733	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-23 06:39:05.964312-07
734	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-23 06:45:35.189896-07
735	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-23 06:52:26.404581-07
736	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-23 06:54:38.008242-07
737	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-23 07:13:26.044499-07
738	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-23 07:22:36.393904-07
739	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-23 07:31:38.528797-07
740	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-23 07:42:31.316712-07
741	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-23 08:03:08.177008-07
742	190.147.153.196	2018-08-23 08:42:09.109002-07
743	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-23 09:03:46.625846-07
744	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-23 09:52:56.053214-07
745	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-23 10:11:18.700229-07
746	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-23 10:57:12.377904-07
747	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-23 11:02:13.181217-07
748	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-23 11:07:53.452432-07
749	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-23 11:38:45.45061-07
750	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-23 11:41:22.997099-07
751	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-23 11:46:27.820822-07
752	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-23 11:52:32.757425-07
753	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-23 11:58:01.021305-07
754	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-23 12:03:55.582357-07
755	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-23 12:09:12.167721-07
756	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-23 12:17:42.966731-07
757	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-23 12:25:43.267501-07
758	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-23 12:34:31.971311-07
759	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-23 13:05:09.911824-07
760	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-23 14:05:56.378738-07
761	190.147.153.196	2018-08-23 14:58:52.119655-07
762	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-23 15:06:40.017125-07
763	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-23 16:07:12.251151-07
764	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-23 17:08:19.754947-07
765	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-23 18:09:20.154825-07
766	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-23 19:09:50.655774-07
767	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-23 20:10:35.240074-07
768	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-23 21:11:08.950498-07
769	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-23 22:12:03.385909-07
770	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-23 23:12:52.239045-07
771	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-24 01:13:33.084007-07
772	cpe-69-132-98-0.carolina.res.rr.com	2018-08-24 03:05:08.083808-07
773	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-24 03:14:24.785886-07
774	cpe-69-132-98-0.carolina.res.rr.com	2018-08-24 04:51:55.148934-07
775	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-24 05:15:16.651602-07
776	cpe-69-132-98-0.carolina.res.rr.com	2018-08-24 05:22:33.670907-07
777	cpe-69-132-98-0.carolina.res.rr.com	2018-08-24 05:36:35.630903-07
778	cpe-69-132-98-0.carolina.res.rr.com	2018-08-24 05:51:50.761512-07
779	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-24 06:29:02.016866-07
780	cpe-69-132-98-0.carolina.res.rr.com	2018-08-24 06:37:22.264831-07
781	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-24 07:08:19.039515-07
782	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-24 07:22:31.871501-07
783	cpe-69-132-98-0.carolina.res.rr.com	2018-08-24 07:39:24.023959-07
784	cpe-69-132-98-0.carolina.res.rr.com	2018-08-24 07:58:58.615538-07
785	cpe-69-132-98-0.carolina.res.rr.com	2018-08-24 08:09:55.800544-07
786	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-24 08:12:47.473572-07
787	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-24 08:31:52.345674-07
788	190.147.153.196	2018-08-24 08:46:55.747516-07
789	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-24 09:30:44.720237-07
790	cpe-69-132-98-0.carolina.res.rr.com	2018-08-24 09:59:18.753155-07
791	cpe-69-132-98-0.carolina.res.rr.com	2018-08-24 10:16:10.872309-07
792	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-24 10:30:12.741695-07
793	cpe-69-132-98-0.carolina.res.rr.com	2018-08-24 11:01:40.248603-07
794	cpe-69-132-98-0.carolina.res.rr.com	2018-08-24 11:59:32.089211-07
795	190.147.153.196	2018-08-24 12:08:25.046663-07
796	190.147.153.196	2018-08-24 12:27:38.683859-07
797	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-24 12:57:59.797103-07
798	190.147.153.196	2018-08-24 13:57:02.143256-07
799	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-24 13:58:39.104106-07
800	190.147.153.196	2018-08-24 14:44:10.049502-07
801	190.147.153.196	2018-08-24 15:12:23.487735-07
802	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-24 15:59:35.388208-07
803	190.147.153.196	2018-08-24 15:59:57.375388-07
804	190.147.153.196	2018-08-24 16:18:36.049029-07
805	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-24 18:00:33.324046-07
806	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-24 19:01:30.970452-07
807	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-24 21:02:07.749515-07
808	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-24 23:03:02.586951-07
809	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-25 01:03:42.072741-07
810	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-25 03:04:42.016645-07
811	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-25 05:05:41.629216-07
812	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-25 06:59:13.006488-07
813	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-25 07:17:53.356077-07
814	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-25 09:38:44.301778-07
815	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-25 09:47:40.074013-07
816	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-25 10:18:18.0458-07
817	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-25 11:10:38.781287-07
818	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-25 12:37:23.354386-07
819	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-25 13:08:06.748477-07
820	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-25 15:08:41.068416-07
821	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-25 17:09:29.861183-07
822	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-25 18:10:29.174648-07
823	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-25 20:11:00.095895-07
824	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-25 22:12:00.06018-07
825	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-26 00:13:00.073478-07
826	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-26 01:13:59.777941-07
827	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-26 03:14:36.774248-07
828	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-26 05:15:30.139699-07
829	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-26 07:19:35.369669-07
830	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-26 07:40:21.37694-07
831	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-26 09:41:09.103806-07
832	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-26 11:42:09.061211-07
833	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-26 13:43:09.640223-07
834	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-26 14:44:06.99956-07
835	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-26 15:44:56.637385-07
836	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-26 16:45:36.72211-07
837	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-26 18:46:09.241898-07
838	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-26 20:47:12.32965-07
839	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-26 22:48:12.124694-07
840	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-26 23:48:50.792508-07
841	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-27 01:49:49.998855-07
842	cpe-69-132-98-0.carolina.res.rr.com	2018-08-27 02:43:54.637103-07
843	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-27 03:50:43.760774-07
844	cpe-69-132-98-0.carolina.res.rr.com	2018-08-27 05:29:44.050993-07
845	cpe-69-132-98-0.carolina.res.rr.com	2018-08-27 05:48:55.742754-07
846	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-27 05:51:36.990953-07
847	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-27 06:15:51.084103-07
848	cpe-69-132-98-0.carolina.res.rr.com	2018-08-27 06:16:18.85802-07
849	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-27 06:31:55.462742-07
850	cpe-69-132-98-0.carolina.res.rr.com	2018-08-27 07:07:56.084785-07
851	cpe-69-132-98-0.carolina.res.rr.com	2018-08-27 07:16:54.320188-07
852	cpe-69-132-98-0.carolina.res.rr.com	2018-08-27 07:49:05.317757-07
853	cpe-69-132-98-0.carolina.res.rr.com	2018-08-27 08:04:12.347416-07
854	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-27 08:23:45.77977-07
855	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-27 08:44:24.60724-07
856	190.147.153.196	2018-08-27 08:50:47.456436-07
857	cpe-69-132-98-0.carolina.res.rr.com	2018-08-27 09:33:29.578989-07
858	cpe-69-132-98-0.carolina.res.rr.com	2018-08-27 09:52:48.693836-07
859	cpe-69-132-98-0.carolina.res.rr.com	2018-08-27 10:21:26.151042-07
860	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-27 10:22:21.602018-07
861	69.132.98.0	2018-08-27 10:37:51.314464-07
862	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-27 10:49:22.549065-07
863	cpe-69-132-98-0.carolina.res.rr.com	2018-08-27 10:58:18.092016-07
864	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-27 11:03:37.864129-07
865	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-27 11:36:19.996499-07
866	190.147.153.196	2018-08-27 12:18:38.680097-07
867	190.147.153.196	2018-08-27 12:37:30.586987-07
868	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-27 12:45:16.70071-07
869	190.147.153.196	2018-08-27 12:58:34.994114-07
870	cpe-69-132-98-0.carolina.res.rr.com	2018-08-27 12:59:00.749706-07
871	190.147.153.196	2018-08-27 13:14:32.062574-07
872	190.147.153.196	2018-08-27 13:31:05.849169-07
873	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-27 13:33:12.387451-07
874	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-27 13:52:08.035014-07
875	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-27 14:12:45.750632-07
876	190.147.153.196	2018-08-27 14:14:58.200004-07
877	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-27 15:13:40.644864-07
878	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-27 16:14:41.000301-07
879	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-27 17:04:23.126283-07
880	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-27 17:20:13.189379-07
881	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-27 17:40:57.079569-07
882	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-27 19:42:05.136577-07
883	cpe-69-132-98-0.carolina.res.rr.com	2018-08-28 03:10:11.048156-07
884	cpe-69-132-98-0.carolina.res.rr.com	2018-08-28 04:55:13.003327-07
885	cpe-69-132-98-0.carolina.res.rr.com	2018-08-28 05:54:22.095656-07
886	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-28 05:58:07.351093-07
887	cpe-69-132-98-0.carolina.res.rr.com	2018-08-28 06:31:56.051562-07
888	cpe-69-132-98-0.carolina.res.rr.com	2018-08-28 06:42:52.347806-07
889	190.147.153.196	2018-08-28 09:12:37.653675-07
890	cpe-69-132-98-0.carolina.res.rr.com	2018-08-28 10:24:50.913889-07
891	cpe-69-132-98-0.carolina.res.rr.com	2018-08-28 10:43:14.053256-07
892	cpe-69-132-98-0.carolina.res.rr.com	2018-08-28 11:14:15.730342-07
893	cpe-69-132-98-0.carolina.res.rr.com	2018-08-28 11:45:01.929382-07
894	190.147.153.196	2018-08-28 12:08:05.810504-07
895	190.147.153.196	2018-08-28 13:45:15.021947-07
896	190.147.153.196	2018-08-28 15:46:49.601863-07
897	cpe-69-132-98-0.carolina.res.rr.com	2018-08-29 02:15:10.997338-07
898	cpe-69-132-98-0.carolina.res.rr.com	2018-08-29 02:20:33.726342-07
899	cpe-69-132-98-0.carolina.res.rr.com	2018-08-29 03:03:19.572538-07
900	cpe-69-132-98-0.carolina.res.rr.com	2018-08-29 03:34:30.732991-07
901	cpe-69-132-98-0.carolina.res.rr.com	2018-08-29 04:01:53.776744-07
902	cpe-69-132-98-0.carolina.res.rr.com	2018-08-29 04:11:44.104342-07
903	cpe-69-132-98-0.carolina.res.rr.com	2018-08-29 04:55:11.876823-07
904	cpe-69-132-98-0.carolina.res.rr.com	2018-08-29 05:53:53.302705-07
905	cpe-69-132-98-0.carolina.res.rr.com	2018-08-29 06:21:50.151748-07
906	cpe-69-132-98-0.carolina.res.rr.com	2018-08-29 06:40:35.670608-07
907	cpe-69-132-98-0.carolina.res.rr.com	2018-08-29 07:20:51.331982-07
908	cpe-69-132-98-0.carolina.res.rr.com	2018-08-29 07:37:30.655032-07
909	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-29 07:54:31.111781-07
910	190.147.153.196	2018-08-29 09:31:13.209723-07
911	cpe-69-132-98-0.carolina.res.rr.com	2018-08-29 09:37:39.669628-07
912	cpe-69-132-98-0.carolina.res.rr.com	2018-08-29 09:54:53.774164-07
913	cpe-69-132-98-0.carolina.res.rr.com	2018-08-29 10:16:32.298073-07
914	cpe-69-132-98-0.carolina.res.rr.com	2018-08-29 10:25:36.754227-07
915	cpe-69-132-98-0.carolina.res.rr.com	2018-08-29 10:43:01.030881-07
916	cpe-69-132-98-0.carolina.res.rr.com	2018-08-29 11:10:24.549249-07
917	cpe-69-132-98-0.carolina.res.rr.com	2018-08-29 11:30:12.242024-07
918	190.147.153.196	2018-08-29 13:14:35.89473-07
919	190.147.153.196	2018-08-29 13:23:52.795824-07
920	190.147.153.196	2018-08-29 13:42:51.066783-07
921	190.147.153.196	2018-08-29 13:54:26.174696-07
922	190.147.153.196	2018-08-29 15:48:01.071463-07
923	190.147.153.196	2018-08-29 16:27:30.686093-07
924	190.147.153.196	2018-08-29 19:51:00.653209-07
925	cpe-69-132-98-0.carolina.res.rr.com	2018-08-30 03:33:01.722586-07
926	cpe-69-132-98-0.carolina.res.rr.com	2018-08-30 04:17:27.990698-07
927	190.147.153.196	2018-08-30 06:01:29.281745-07
928	190.147.153.196	2018-08-30 06:10:17.605276-07
929	190.147.153.196	2018-08-30 06:21:16.219875-07
930	190.147.153.196	2018-08-30 06:54:05.616464-07
931	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-08-30 07:29:23.953631-07
932	190.147.153.196	2018-08-30 07:36:15.905434-07
933	cpe-69-132-98-0.carolina.res.rr.com	2018-08-30 07:46:28.311142-07
934	190.147.153.196	2018-08-30 08:14:30.707904-07
935	190.147.153.196	2018-08-30 08:58:44.022738-07
936	190.147.153.196	2018-08-30 09:19:33.046429-07
937	190.147.153.196	2018-08-30 10:20:15.984315-07
941	190.147.153.196	2018-08-30 12:11:39.820572-07
942	190.147.153.196	2018-08-30 12:40:25.914477-07
943	190.147.153.196	2018-08-30 12:56:05.663213-07
944	190.147.153.196	2018-08-30 14:16:49.236257-07
945	190.147.153.196	2018-08-30 14:46:10.678954-07
946	190.147.153.196	2018-08-30 14:56:25.238493-07
947	190.147.153.196	2018-08-30 15:27:28.000243-07
948	cpe-69-132-98-0.carolina.res.rr.com	2018-08-31 02:37:04.094965-07
949	cpe-69-132-98-0.carolina.res.rr.com	2018-08-31 02:57:45.021564-07
950	cpe-69-132-98-0.carolina.res.rr.com	2018-08-31 03:35:55.962789-07
951	cpe-69-132-98-0.carolina.res.rr.com	2018-08-31 04:24:10.281244-07
952	cpe-69-132-98-0.carolina.res.rr.com	2018-08-31 04:36:42.929531-07
953	cpe-69-132-98-0.carolina.res.rr.com	2018-08-31 06:01:35.264579-07
954	cpe-69-132-98-0.carolina.res.rr.com	2018-08-31 06:22:21.623494-07
955	cpe-69-132-98-0.carolina.res.rr.com	2018-08-31 06:40:50.918349-07
956	cpe-69-132-98-0.carolina.res.rr.com	2018-08-31 06:58:22.684447-07
957	cpe-69-132-98-0.carolina.res.rr.com	2018-08-31 08:10:16.743468-07
958	190.147.153.196	2018-08-31 08:15:36.471017-07
959	190.147.153.196	2018-08-31 10:43:56.559472-07
960	cpe-69-132-98-0.carolina.res.rr.com	2018-08-31 11:21:17.729817-07
961	cpe-69-132-98-0.carolina.res.rr.com	2018-08-31 11:32:16.717024-07
962	cpe-69-132-98-0.carolina.res.rr.com	2018-08-31 11:57:16.021865-07
963	190.147.153.196	2018-08-31 12:01:17.666593-07
964	cpe-69-132-98-0.carolina.res.rr.com	2018-08-31 12:13:34.852292-07
965	190.147.153.196	2018-08-31 12:20:13.716142-07
966	cpe-69-132-98-0.carolina.res.rr.com	2018-08-31 12:27:19.088587-07
967	cpe-69-132-98-0.carolina.res.rr.com	2018-08-31 13:10:35.686251-07
968	190.147.153.196	2018-08-31 14:40:57.753294-07
969	190.147.153.196	2018-08-31 14:52:20.865233-07
970	190.147.153.196	2018-08-31 15:48:38.776679-07
971	190.147.153.196	2018-08-31 16:09:19.909599-07
972	190.147.153.196	2018-08-31 16:46:57.805525-07
973	190.147.153.196	2018-08-31 17:02:10.66912-07
974	cpe-69-132-98-0.carolina.res.rr.com	2018-09-03 01:51:11.662104-07
975	cpe-69-132-98-0.carolina.res.rr.com	2018-09-03 02:37:39.842933-07
976	cpe-69-132-98-0.carolina.res.rr.com	2018-09-03 03:27:05.640746-07
977	cpe-69-132-98-0.carolina.res.rr.com	2018-09-03 03:40:12.011654-07
978	cpe-69-132-98-0.carolina.res.rr.com	2018-09-03 04:03:00.65275-07
979	cpe-69-132-98-0.carolina.res.rr.com	2018-09-03 04:23:43.058658-07
980	cpe-69-132-98-0.carolina.res.rr.com	2018-09-03 04:40:05.966739-07
981	190.147.153.196	2018-09-03 08:14:36.104417-07
982	cpe-69-132-98-0.carolina.res.rr.com	2018-09-03 09:44:11.725416-07
983	cpe-69-132-98-0.carolina.res.rr.com	2018-09-03 11:19:15.70424-07
984	190.147.153.196	2018-09-03 12:28:00.771211-07
985	190.147.153.196	2018-09-03 12:42:32.793315-07
986	190.147.153.196	2018-09-03 13:22:30.779773-07
987	190.147.153.196	2018-09-03 13:59:02.703222-07
988	190.147.153.196	2018-09-03 15:12:38.757367-07
989	190.147.153.196	2018-09-03 16:43:22.704843-07
990	cpe-69-132-98-0.carolina.res.rr.com	2018-09-04 03:39:46.846941-07
991	cpe-69-132-98-0.carolina.res.rr.com	2018-09-04 03:55:33.823173-07
992	cpe-69-132-98-0.carolina.res.rr.com	2018-09-04 04:21:31.663865-07
993	cpe-69-132-98-0.carolina.res.rr.com	2018-09-04 04:55:12.014803-07
994	190.147.153.196	2018-09-04 08:15:53.105161-07
995	cpe-69-132-98-0.carolina.res.rr.com	2018-09-04 09:01:26.726484-07
996	cpe-69-132-98-0.carolina.res.rr.com	2018-09-04 09:22:08.809711-07
997	cpe-69-132-98-0.carolina.res.rr.com	2018-09-04 09:45:05.71373-07
998	cpe-69-132-98-0.carolina.res.rr.com	2018-09-04 10:10:18.128062-07
999	cpe-69-132-98-0.carolina.res.rr.com	2018-09-04 10:54:18.681345-07
1000	cpe-69-132-98-0.carolina.res.rr.com	2018-09-04 11:11:32.896076-07
1001	190.147.153.196	2018-09-04 11:38:46.669636-07
1002	cpe-69-132-98-0.carolina.res.rr.com	2018-09-05 01:50:26.650726-07
1003	cpe-69-132-98-0.carolina.res.rr.com	2018-09-05 02:08:14.385866-07
1004	cpe-69-132-98-0.carolina.res.rr.com	2018-09-05 02:17:18.059066-07
1005	cpe-69-132-98-0.carolina.res.rr.com	2018-09-05 02:48:14.956755-07
1006	cpe-69-132-98-0.carolina.res.rr.com	2018-09-05 03:21:34.708066-07
1007	cpe-69-132-98-0.carolina.res.rr.com	2018-09-05 03:35:10.748792-07
1008	cpe-69-132-98-0.carolina.res.rr.com	2018-09-05 04:55:15.00178-07
1009	cpe-69-132-98-0.carolina.res.rr.com	2018-09-05 05:15:39.680545-07
1010	cpe-69-132-98-0.carolina.res.rr.com	2018-09-05 05:21:16.841185-07
1011	cpe-69-132-98-0.carolina.res.rr.com	2018-09-05 06:03:45.161397-07
1012	190.147.153.196	2018-09-05 08:33:22.772081-07
1013	cpe-69-132-98-0.carolina.res.rr.com	2018-09-05 09:00:44.943069-07
1014	cpe-69-132-98-0.carolina.res.rr.com	2018-09-05 09:02:55.754649-07
1015	cpe-69-132-98-0.carolina.res.rr.com	2018-09-05 09:18:08.992732-07
1016	190.147.153.196	2018-09-05 11:01:03.707807-07
1017	190.147.153.196	2018-09-05 11:03:14.885756-07
1018	190.147.153.196	2018-09-05 11:20:31.203444-07
1019	190.147.153.196	2018-09-05 11:49:58.757639-07
1020	cpe-69-132-98-0.carolina.res.rr.com	2018-09-05 11:59:28.143662-07
1021	190.147.153.196	2018-09-05 12:08:36.912204-07
1022	190.147.153.196	2018-09-05 12:55:30.718036-07
1023	190.147.153.196	2018-09-05 13:14:12.657089-07
1024	190.147.153.196	2018-09-05 13:50:32.838948-07
1025	190.147.153.196	2018-09-05 14:10:19.952016-07
1026	190.147.153.196	2018-09-05 14:30:55.763504-07
1027	190.147.153.196	2018-09-05 15:24:12.320027-07
1028	190.147.153.196	2018-09-05 15:36:58.698614-07
1029	190.147.153.196	2018-09-05 15:54:02.09581-07
1030	190.147.153.196	2018-09-05 16:14:51.629173-07
1031	190.147.153.196	2018-09-05 16:37:30.044681-07
1032	cpe-69-132-98-0.carolina.res.rr.com	2018-09-06 03:40:02.803046-07
1033	cpe-69-132-98-0.carolina.res.rr.com	2018-09-06 04:55:14.077228-07
1034	cpe-69-132-98-0.carolina.res.rr.com	2018-09-06 06:25:10.68457-07
1035	cpe-69-132-98-0.carolina.res.rr.com	2018-09-06 06:42:31.760226-07
1036	cpe-69-132-98-0.carolina.res.rr.com	2018-09-06 06:59:15.6425-07
1037	cpe-69-132-98-0.carolina.res.rr.com	2018-09-06 07:04:56.905006-07
1038	cpe-69-132-98-0.carolina.res.rr.com	2018-09-06 07:41:09.671625-07
1039	190.147.153.196	2018-09-06 07:55:19.59044-07
1040	cpe-69-132-98-0.carolina.res.rr.com	2018-09-06 08:35:27.983788-07
1041	cpe-69-132-98-0.carolina.res.rr.com	2018-09-06 09:06:00.996265-07
1042	190.147.153.196	2018-09-06 09:39:31.683579-07
1043	190.147.153.196	2018-09-06 12:28:40.628849-07
1044	190.147.153.196	2018-09-06 12:37:34.915903-07
1045	cpe-69-132-98-0.carolina.res.rr.com	2018-09-06 12:40:00.646078-07
1046	190.147.153.196	2018-09-06 12:55:31.796334-07
1047	cpe-69-132-98-0.carolina.res.rr.com	2018-09-06 13:00:41.942038-07
1048	190.147.153.196	2018-09-06 13:04:31.780378-07
1049	190.147.153.196	2018-09-06 13:13:25.724855-07
1050	cpe-69-132-98-0.carolina.res.rr.com	2018-09-06 13:16:09.107822-07
1051	190.147.153.196	2018-09-06 15:13:21.955895-07
1052	190.147.153.196	2018-09-06 15:44:25.792726-07
1053	190.147.153.196	2018-09-06 16:14:11.68179-07
1054	190.147.153.196	2018-09-06 16:33:25.682934-07
1055	cpe-69-132-98-0.carolina.res.rr.com	2018-09-07 02:09:27.165743-07
1056	cpe-69-132-98-0.carolina.res.rr.com	2018-09-07 04:55:10.660746-07
1057	cpe-69-132-98-0.carolina.res.rr.com	2018-09-07 05:14:10.900574-07
1058	cpe-69-132-98-0.carolina.res.rr.com	2018-09-07 05:25:50.00196-07
1059	cpe-69-132-98-0.carolina.res.rr.com	2018-09-07 05:37:21.915062-07
1060	cpe-69-132-98-0.carolina.res.rr.com	2018-09-07 05:39:49.306737-07
1061	cpe-69-132-98-0.carolina.res.rr.com	2018-09-07 06:37:59.125185-07
1062	190.147.153.196	2018-09-07 08:31:36.689699-07
1063	190.147.153.196	2018-09-07 12:30:10.673126-07
1064	190.147.153.196	2018-09-07 13:09:10.173629-07
1065	190.147.153.196	2018-09-07 14:09:55.929982-07
1066	190.147.153.196	2018-09-07 15:10:45.795816-07
1067	190.147.153.196	2018-09-07 16:02:59.740166-07
1068	190.147.153.196	2018-09-07 16:20:55.603971-07
1069	cpe-69-132-98-0.carolina.res.rr.com	2018-09-10 02:18:46.377504-07
1070	cpe-69-132-98-0.carolina.res.rr.com	2018-09-10 04:55:12.480575-07
1071	cpe-69-132-98-0.carolina.res.rr.com	2018-09-10 05:12:48.920272-07
1072	cpe-69-132-98-0.carolina.res.rr.com	2018-09-10 09:44:32.535035-07
1073	cpe-69-132-98-0.carolina.res.rr.com	2018-09-10 10:35:07.450814-07
1074	cpe-69-132-98-0.carolina.res.rr.com	2018-09-10 10:43:36.846251-07
1075	cpe-69-132-98-0.carolina.res.rr.com	2018-09-10 11:12:31.427273-07
1076	cpe-69-132-98-0.carolina.res.rr.com	2018-09-10 11:41:36.385968-07
1077	cpe-69-132-98-0.carolina.res.rr.com	2018-09-10 12:02:50.906416-07
1078	190.147.153.196	2018-09-10 12:35:07.565477-07
1079	cpe-69-132-98-0.carolina.res.rr.com	2018-09-11 03:06:29.013435-07
1080	cpe-69-132-98-0.carolina.res.rr.com	2018-09-11 03:44:23.461883-07
1081	cpe-69-132-98-0.carolina.res.rr.com	2018-09-11 03:56:01.488937-07
1082	cpe-69-132-98-0.carolina.res.rr.com	2018-09-11 04:13:20.358692-07
1083	cpe-69-132-98-0.carolina.res.rr.com	2018-09-11 04:30:57.151011-07
1084	190.147.153.196	2018-09-11 08:43:48.765452-07
1085	190.147.153.196	2018-09-11 11:58:34.733543-07
1086	190.147.153.196	2018-09-11 15:49:11.831404-07
1087	190.147.153.196	2018-09-11 16:49:00.863193-07
1088	cpe-69-132-98-0.carolina.res.rr.com	2018-09-12 01:48:31.445276-07
1089	cpe-69-132-98-0.carolina.res.rr.com	2018-09-12 02:48:49.818431-07
1090	cpe-69-132-98-0.carolina.res.rr.com	2018-09-12 03:05:50.513384-07
1091	cpe-69-132-98-0.carolina.res.rr.com	2018-09-12 03:53:40.381172-07
1092	cpe-69-132-98-0.carolina.res.rr.com	2018-09-12 04:38:47.873289-07
1093	cpe-69-132-98-0.carolina.res.rr.com	2018-09-12 04:55:18.888405-07
1094	cpe-69-132-98-0.carolina.res.rr.com	2018-09-12 05:36:35.456577-07
1095	cpe-69-132-98-0.carolina.res.rr.com	2018-09-12 06:01:00.46354-07
1096	190.147.153.196	2018-09-12 08:50:30.864588-07
1097	190.147.153.196	2018-09-12 10:24:53.631479-07
1098	190.147.153.196	2018-09-12 10:33:12.105359-07
1099	190.147.153.196	2018-09-12 11:09:03.693865-07
1100	190.147.153.196	2018-09-12 11:35:25.484214-07
1101	190.147.153.196	2018-09-12 12:16:02.542915-07
1102	190.147.153.196	2018-09-12 12:18:24.563525-07
1103	cpe-69-132-98-0.carolina.res.rr.com	2018-09-12 12:42:44.566136-07
1104	cpe-69-132-98-0.carolina.res.rr.com	2018-09-12 13:11:13.933628-07
1105	cpe-69-132-98-0.carolina.res.rr.com	2018-09-12 13:20:10.580916-07
1106	190.147.153.196	2018-09-12 14:29:11.442339-07
1107	190.147.153.196	2018-09-12 14:38:05.455741-07
1108	190.147.153.196	2018-09-12 16:39:18.625394-07
1109	cpe-69-132-98-0.carolina.res.rr.com	2018-09-13 03:28:55.640422-07
1110	cpe-69-132-98-0.carolina.res.rr.com	2018-09-13 04:55:11.007956-07
1111	cpe-69-132-98-0.carolina.res.rr.com	2018-09-13 05:29:51.572038-07
1112	cpe-69-132-98-0.carolina.res.rr.com	2018-09-13 05:36:01.848452-07
1113	cpe-69-132-98-0.carolina.res.rr.com	2018-09-13 05:50:32.527948-07
1114	cpe-69-132-98-0.carolina.res.rr.com	2018-09-13 06:06:43.354047-07
1115	cpe-69-132-98-0.carolina.res.rr.com	2018-09-13 06:41:56.032661-07
1116	cpe-69-132-98-0.carolina.res.rr.com	2018-09-13 07:32:32.602994-07
1117	cpe-69-132-98-0.carolina.res.rr.com	2018-09-13 07:51:01.554655-07
1118	cpe-69-132-98-0.carolina.res.rr.com	2018-09-13 07:57:33.847347-07
1119	190.147.153.196	2018-09-13 09:57:00.164025-07
1120	cpe-69-132-98-0.carolina.res.rr.com	2018-09-13 10:37:54.971767-07
1121	cpe-69-132-98-0.carolina.res.rr.com	2018-09-13 10:48:30.61186-07
1122	cpe-69-132-98-0.carolina.res.rr.com	2018-09-13 11:51:16.826124-07
1123	190.147.153.196	2018-09-13 12:08:15.423953-07
1124	190.147.153.196	2018-09-13 12:13:31.800254-07
1125	190.147.153.196	2018-09-13 12:49:35.63483-07
1126	cpe-69-132-98-0.carolina.res.rr.com	2018-09-14 08:42:42.840005-07
1127	190.147.153.196	2018-09-14 09:53:24.046956-07
1128	190.147.153.196	2018-09-14 12:29:45.433221-07
1129	190.147.153.196	2018-09-14 13:00:39.644212-07
1130	190.147.153.196	2018-09-14 13:15:58.562986-07
1131	190.147.153.196	2018-09-14 13:29:47.03503-07
1132	190.147.153.196	2018-09-14 13:32:00.791271-07
1133	190.147.153.196	2018-09-14 14:13:27.547938-07
1134	190.147.153.196	2018-09-14 15:30:56.913541-07
1135	190.147.153.196	2018-09-14 15:33:32.570155-07
1136	190.147.153.196	2018-09-14 15:49:42.332137-07
1137	190.147.153.196	2018-09-14 16:04:55.411075-07
1138	cpe-69-132-98-0.carolina.res.rr.com	2018-09-17 05:41:27.88496-07
1139	cpe-69-132-98-0.carolina.res.rr.com	2018-09-17 07:07:12.416038-07
1140	cpe-69-132-98-0.carolina.res.rr.com	2018-09-17 07:22:41.436198-07
1141	190.147.153.196	2018-09-17 08:13:31.586076-07
1142	cpe-69-132-98-0.carolina.res.rr.com	2018-09-17 08:17:05.001663-07
1143	cpe-69-132-98-0.carolina.res.rr.com	2018-09-17 08:29:09.054201-07
1144	cpe-69-132-98-0.carolina.res.rr.com	2018-09-17 08:38:18.818118-07
1145	cpe-69-132-98-0.carolina.res.rr.com	2018-09-17 08:54:57.733111-07
1146	cpe-69-132-98-0.carolina.res.rr.com	2018-09-17 09:12:15.611088-07
1147	190.147.153.196	2018-09-17 12:24:46.537321-07
1148	190.147.153.196	2018-09-17 12:33:45.561251-07
1149	190.147.153.196	2018-09-17 12:44:16.423518-07
1150	190.147.153.196	2018-09-17 13:08:07.499581-07
1151	190.147.153.196	2018-09-17 14:47:52.439258-07
1152	190.147.153.196	2018-09-17 15:02:52.583914-07
1153	190.147.153.196	2018-09-17 15:33:38.329462-07
1154	cpe-69-132-98-0.carolina.res.rr.com	2018-09-18 03:35:28.509275-07
1155	cpe-69-132-98-0.carolina.res.rr.com	2018-09-18 04:25:47.856414-07
1156	190.147.153.196	2018-09-18 07:46:12.382262-07
1157	190.147.153.196	2018-09-18 12:58:44.443439-07
1158	190.147.153.196	2018-09-18 13:17:24.854864-07
1159	190.147.153.196	2018-09-18 13:38:32.009815-07
1160	190.147.153.196	2018-09-18 13:49:09.376595-07
1161	190.147.153.196	2018-09-18 15:00:16.442763-07
1162	190.147.153.196	2018-09-18 15:21:05.681065-07
1163	190.147.153.196	2018-09-18 16:21:42.368501-07
1164	190.147.153.196	2018-09-18 17:19:48.520841-07
1165	190.147.153.196	2018-09-19 08:13:15.935997-07
1166	190.147.153.196	2018-09-19 12:08:01.545542-07
1167	190.147.153.196	2018-09-19 12:16:44.758051-07
1168	190.147.153.196	2018-09-19 12:27:34.602041-07
1169	190.147.153.196	2018-09-19 12:48:19.96075-07
1170	cpe-69-132-98-0.carolina.res.rr.com	2018-09-19 13:06:41.454277-07
1171	190.147.153.196	2018-09-19 13:49:06.435304-07
1172	190.147.153.196	2018-09-19 14:03:24.326857-07
1173	190.147.153.196	2018-09-19 14:34:51.443914-07
1174	190.147.153.196	2018-09-19 14:50:44.22506-07
1175	190.147.153.196	2018-09-19 15:11:47.586049-07
1176	190.147.153.196	2018-09-19 15:22:23.496229-07
1177	190.147.153.196	2018-09-19 16:12:56.350783-07
1178	cpe-69-132-98-0.carolina.res.rr.com	2018-09-20 02:43:01.046997-07
1179	cpe-69-132-98-0.carolina.res.rr.com	2018-09-20 03:45:11.442355-07
1180	cpe-69-132-98-0.carolina.res.rr.com	2018-09-20 03:59:53.630131-07
1181	cpe-69-132-98-0.carolina.res.rr.com	2018-09-20 04:15:22.970073-07
1182	cpe-69-132-98-0.carolina.res.rr.com	2018-09-20 04:55:14.838727-07
1183	190.147.153.196	2018-09-20 08:05:22.360757-07
1184	190.147.153.196	2018-09-20 11:20:51.389735-07
1185	190.147.153.196	2018-09-20 11:29:33.663791-07
1186	190.147.153.196	2018-09-20 11:40:31.446292-07
1187	190.147.153.196	2018-09-20 12:03:35.10678-07
1188	190.147.153.196	2018-09-20 12:29:11.735335-07
1189	190.147.153.196	2018-09-20 13:03:35.638709-07
1190	190.147.153.196	2018-09-20 13:24:25.087228-07
1191	190.147.153.196	2018-09-20 13:42:06.476301-07
1192	190.147.153.196	2018-09-20 13:45:52.047123-07
1193	190.147.153.196	2018-09-20 14:01:46.456378-07
1194	190.147.153.196	2018-09-20 15:09:24.618247-07
1195	190.147.153.196	2018-09-20 15:30:00.135898-07
1196	cpe-69-132-98-0.carolina.res.rr.com	2018-09-21 01:58:46.508232-07
1197	cpe-69-132-98-0.carolina.res.rr.com	2018-09-21 02:23:00.063373-07
1198	cpe-69-132-98-0.carolina.res.rr.com	2018-09-21 02:34:03.006582-07
1199	cpe-69-132-98-0.carolina.res.rr.com	2018-09-21 02:55:01.634662-07
1200	cpe-69-132-98-0.carolina.res.rr.com	2018-09-21 03:16:11.434835-07
1201	cpe-69-132-98-0.carolina.res.rr.com	2018-09-21 05:11:20.060961-07
1202	cpe-69-132-98-0.carolina.res.rr.com	2018-09-21 05:22:21.403248-07
1203	cpe-69-132-98-0.carolina.res.rr.com	2018-09-21 05:36:36.490204-07
1204	cpe-69-132-98-0.carolina.res.rr.com	2018-09-21 07:08:49.377618-07
1205	cpe-69-132-98-0.carolina.res.rr.com	2018-09-21 07:21:46.446892-07
1206	cpe-69-132-98-0.carolina.res.rr.com	2018-09-21 07:40:48.691278-07
1207	190.147.153.196	2018-09-21 08:53:40.041222-07
1208	cpe-69-132-98-0.carolina.res.rr.com	2018-09-21 09:22:01.45189-07
1209	cpe-69-132-98-0.carolina.res.rr.com	2018-09-21 09:32:53.177477-07
1210	cpe-69-132-98-0.carolina.res.rr.com	2018-09-21 09:42:28.393641-07
1211	cpe-69-132-98-0.carolina.res.rr.com	2018-09-21 09:55:22.398073-07
1212	190.147.153.196	2018-09-21 10:33:26.910784-07
1213	cpe-69-132-98-0.carolina.res.rr.com	2018-09-21 11:30:20.008691-07
1214	cpe-69-132-98-0.carolina.res.rr.com	2018-09-21 11:56:24.454274-07
1215	cpe-69-132-98-0.carolina.res.rr.com	2018-09-21 12:06:59.388929-07
1216	cpe-69-132-98-0.carolina.res.rr.com	2018-09-21 12:20:20.425937-07
1217	190.147.153.196	2018-09-21 12:28:06.559354-07
1218	190.147.153.196	2018-09-21 12:44:30.012088-07
1219	190.147.153.196	2018-09-21 13:01:05.485464-07
1220	190.147.153.196	2018-09-21 14:29:21.462686-07
1221	190.147.153.196	2018-09-21 14:40:06.398108-07
1222	190.147.153.196	2018-09-21 15:00:40.059028-07
1223	190.147.153.196	2018-09-21 16:01:28.419305-07
1224	190.147.153.196	2018-09-21 17:02:31.43454-07
1225	107-0-223-236-ip-static.hfc.comcastbusiness.net	2018-09-24 02:53:17.430382-07
1226	190.147.153.196	2018-09-24 08:18:11.151264-07
1227	190.147.153.196	2018-09-24 11:59:09.447137-07
1228	190.147.153.196	2018-09-24 12:08:18.854254-07
1229	190.147.153.196	2018-09-24 12:19:14.49455-07
1230	190.147.153.196	2018-09-24 12:39:59.032052-07
1231	190.147.153.196	2018-09-24 13:58:31.718822-07
1232	190.147.153.196	2018-09-24 14:23:05.473424-07
1233	190.147.153.196	2018-09-24 14:41:49.446981-07
1234	190.147.153.196	2018-09-24 15:02:29.494538-07
1235	190.147.153.196	2018-09-24 15:13:48.984306-07
1236	190.147.153.196	2018-09-24 15:23:14.384973-07
1237	190.147.153.196	2018-09-24 15:52:20.444072-07
1238	107-0-223-236-ip-static.hfc.comcastbusiness.net	2018-09-24 18:26:45.406349-07
1239	190.147.153.196	2018-09-25 07:42:42.435399-07
1240	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-09-25 08:19:22.717798-07
1241	190.147.153.196	2018-09-25 12:19:59.391043-07
1242	190.147.153.196	2018-09-25 12:34:12.383117-07
1243	190.147.153.196	2018-09-25 12:49:59.818604-07
1244	190.147.153.196	2018-09-25 14:47:22.706957-07
1245	190.147.153.196	2018-09-25 14:49:36.451187-07
1246	190.147.153.196	2018-09-25 15:06:43.989802-07
1247	190.147.153.196	2018-09-25 15:27:34.870063-07
1248	190.147.153.196	2018-09-25 15:38:11.320483-07
1249	190.147.153.196	2018-09-25 15:58:17.481954-07
1250	190.147.153.196	2018-09-25 16:18:56.10053-07
1251	190.147.153.196	2018-09-26 11:10:10.886567-07
1252	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-09-26 12:49:37.549303-07
1253	190.147.153.196	2018-09-26 16:15:04.017445-07
1254	190.147.153.196	2018-09-26 16:23:56.430613-07
1255	190.147.153.196	2018-09-26 16:37:57.527527-07
1256	nc-76-5-169-64.dhcp.embarqhsd.net	2018-09-27 05:32:55.53984-07
1257	76.5.169.64	2018-09-27 05:33:00.524504-07
1258	nc-76-5-169-64.dhcp.embarqhsd.net	2018-09-27 05:33:16.04835-07
1259	nc-76-5-169-64.dhcp.embarqhsd.net	2018-09-27 05:33:38.52215-07
1260	nc-76-5-169-64.dhcp.embarqhsd.net	2018-09-27 07:07:11.703636-07
1261	nc-76-5-169-64.dhcp.embarqhsd.net	2018-09-27 08:40:01.100428-07
1262	nc-76-5-169-64.dhcp.embarqhsd.net	2018-09-27 08:40:25.925678-07
1263	190.147.153.196	2018-09-27 09:40:11.990452-07
1264	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-09-27 11:24:51.557099-07
1265	190.147.153.196	2018-09-27 12:07:21.486641-07
1266	190.147.153.196	2018-09-27 12:16:19.659223-07
1267	190.147.153.196	2018-09-27 12:47:13.368679-07
1268	190.147.153.196	2018-09-27 13:09:08.433097-07
1269	190.147.153.196	2018-09-27 13:22:39.01999-07
1270	190.147.153.196	2018-09-27 14:23:44.678038-07
1271	cpe-69-132-98-0.carolina.res.rr.com	2018-09-28 06:22:26.529289-07
1272	190.147.153.196	2018-09-28 08:52:09.149829-07
1273	cpe-69-132-98-0.carolina.res.rr.com	2018-09-28 09:03:37.40464-07
1274	cpe-69-132-98-0.carolina.res.rr.com	2018-09-28 09:12:42.521027-07
1275	cpe-69-132-98-0.carolina.res.rr.com	2018-09-28 09:25:38.997364-07
1276	cpe-69-132-98-0.carolina.res.rr.com	2018-09-28 09:55:34.873245-07
1277	cpe-69-132-98-0.carolina.res.rr.com	2018-09-28 10:50:15.872641-07
1278	cpe-69-132-98-0.carolina.res.rr.com	2018-09-28 11:03:15.794183-07
1279	cpe-69-132-98-0.carolina.res.rr.com	2018-09-28 11:12:55.60466-07
1280	cpe-69-132-98-0.carolina.res.rr.com	2018-09-28 11:25:59.147517-07
1281	cpe-69-132-98-0.carolina.res.rr.com	2018-09-28 11:31:56.546414-07
1282	190.147.153.196	2018-09-28 12:16:46.023644-07
1283	190.147.153.196	2018-09-28 12:35:31.417693-07
1284	190.147.153.196	2018-09-28 14:56:04.080184-07
1285	190.147.153.196	2018-09-28 15:56:51.583595-07
1286	190.147.153.196	2018-09-28 16:09:41.460903-07
1287	190.147.153.196	2018-09-28 16:46:38.521417-07
1288	p50889217.dip0.t-ipconnect.de	2018-09-29 10:29:13.033841-07
1289	p50889DF2.dip0.t-ipconnect.de	2018-09-30 11:17:28.74846-07
1290	cpe-69-132-98-0.carolina.res.rr.com	2018-10-01 02:31:12.499108-07
1291	cpe-69-132-98-0.carolina.res.rr.com	2018-10-01 05:12:16.813765-07
1292	cpe-69-132-98-0.carolina.res.rr.com	2018-10-01 06:04:51.372026-07
1293	cpe-69-132-98-0.carolina.res.rr.com	2018-10-01 06:49:06.587571-07
1294	cpe-69-132-98-0.carolina.res.rr.com	2018-10-01 07:38:03.66963-07
1295	cpe-69-132-98-0.carolina.res.rr.com	2018-10-01 08:02:23.897519-07
1296	190.147.153.196	2018-10-01 08:08:44.184489-07
1297	190.147.153.196	2018-10-01 10:24:11.839147-07
1298	190.147.153.196	2018-10-01 10:43:34.28483-07
1299	190.147.153.196	2018-10-01 12:10:56.853224-07
1300	190.147.153.196	2018-10-01 12:57:26.603871-07
1301	190.147.153.196	2018-10-01 13:13:16.412361-07
1302	190.147.153.196	2018-10-01 13:23:56.593602-07
1303	cpe-69-132-98-0.carolina.res.rr.com	2018-10-01 13:36:37.823955-07
1304	190.147.153.196	2018-10-01 13:44:37.390488-07
1305	190.147.153.196	2018-10-01 14:19:42.026742-07
1306	190.147.153.196	2018-10-01 15:58:56.463822-07
1307	190.147.153.196	2018-10-01 16:12:27.535843-07
1308	190.147.153.196	2018-10-01 16:43:29.065982-07
1309	cpe-69-132-98-0.carolina.res.rr.com	2018-10-02 03:18:21.099149-07
1310	cpe-69-132-98-0.carolina.res.rr.com	2018-10-02 03:45:12.680639-07
1311	cpe-69-132-98-0.carolina.res.rr.com	2018-10-02 04:55:18.039978-07
1312	cpe-69-132-98-0.carolina.res.rr.com	2018-10-02 05:15:47.860053-07
1313	cpe-69-132-98-0.carolina.res.rr.com	2018-10-02 05:29:40.031923-07
1314	cpe-69-132-98-0.carolina.res.rr.com	2018-10-02 05:37:02.412486-07
1315	190.147.153.196	2018-10-02 11:29:18.412314-07
1316	190.147.153.196	2018-10-02 16:32:08.339078-07
1317	cpe-69-132-98-0.carolina.res.rr.com	2018-10-03 02:46:55.060435-07
1318	cpe-69-132-98-0.carolina.res.rr.com	2018-10-03 03:19:16.642534-07
1319	cpe-69-132-98-0.carolina.res.rr.com	2018-10-03 03:28:20.466337-07
1320	cpe-69-132-98-0.carolina.res.rr.com	2018-10-03 03:38:58.420659-07
1321	cpe-69-132-98-0.carolina.res.rr.com	2018-10-03 04:11:32.543839-07
1322	cpe-69-132-98-0.carolina.res.rr.com	2018-10-03 04:55:09.058258-07
1323	cpe-69-132-98-0.carolina.res.rr.com	2018-10-03 06:13:50.44514-07
1324	cpe-69-132-98-0.carolina.res.rr.com	2018-10-03 06:30:16.646957-07
1325	cpe-69-132-98-0.carolina.res.rr.com	2018-10-03 06:41:07.974672-07
1326	cpe-69-132-98-0.carolina.res.rr.com	2018-10-03 07:16:24.098725-07
1327	190.147.153.196	2018-10-03 08:52:21.031963-07
1328	cpe-69-132-98-0.carolina.res.rr.com	2018-10-03 09:41:34.133606-07
1329	cpe-69-132-98-0.carolina.res.rr.com	2018-10-03 09:52:20.470605-07
1330	cpe-69-132-98-0.carolina.res.rr.com	2018-10-03 10:12:54.92046-07
1331	cpe-69-132-98-0.carolina.res.rr.com	2018-10-03 10:31:43.780239-07
1332	cpe-69-132-98-0.carolina.res.rr.com	2018-10-03 11:46:47.765744-07
1333	190.147.153.196	2018-10-03 11:53:54.291185-07
1334	190.147.153.196	2018-10-03 12:03:00.112466-07
1335	cpe-69-132-98-0.carolina.res.rr.com	2018-10-03 12:32:19.425965-07
1336	cpe-69-132-98-0.carolina.res.rr.com	2018-10-03 12:50:13.392609-07
1337	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-10-03 13:02:21.549213-07
1338	cpe-69-132-98-0.carolina.res.rr.com	2018-10-03 13:09:34.035199-07
1339	190.147.153.196	2018-10-03 13:33:38.642518-07
1340	cpe-69-132-98-0.carolina.res.rr.com	2018-10-03 13:50:02.775407-07
1341	190.147.153.196	2018-10-03 14:54:19.247194-07
1342	190.147.153.196	2018-10-03 15:35:28.64985-07
1343	190.147.153.196	2018-10-03 16:09:45.352423-07
1344	190.147.153.196	2018-10-03 16:20:43.834697-07
1345	cpe-69-132-98-0.carolina.res.rr.com	2018-10-04 03:28:39.874175-07
1346	cpe-69-132-98-0.carolina.res.rr.com	2018-10-04 08:54:17.367606-07
1347	190.147.153.196	2018-10-04 09:03:16.141858-07
1348	cpe-69-132-98-0.carolina.res.rr.com	2018-10-04 09:39:16.718376-07
1349	cpe-69-132-98-0.carolina.res.rr.com	2018-10-04 10:09:58.00941-07
1350	190.147.153.196	2018-10-04 12:38:25.175267-07
1351	190.147.153.196	2018-10-04 15:16:34.050397-07
1352	190.147.153.196	2018-10-04 15:25:19.351002-07
1353	190.147.153.196	2018-10-04 15:39:44.416883-07
1354	190.147.153.196	2018-10-04 15:42:08.012638-07
1355	190.147.153.196	2018-10-04 15:56:55.443849-07
1356	cpe-69-132-98-0.carolina.res.rr.com	2018-10-05 04:20:03.387135-07
1357	cpe-69-132-98-0.carolina.res.rr.com	2018-10-05 04:20:23.509438-07
1358	cpe-69-132-98-0.carolina.res.rr.com	2018-10-05 05:42:41.920864-07
1359	190.147.153.196	2018-10-05 09:12:06.951225-07
1360	190.147.153.196	2018-10-05 16:43:09.616209-07
1361	cpe-69-132-98-0.carolina.res.rr.com	2018-10-08 02:10:27.314319-07
1362	cpe-69-132-98-0.carolina.res.rr.com	2018-10-08 02:26:25.404018-07
1363	190.147.153.196	2018-10-08 08:43:10.721501-07
1364	cpe-69-132-98-0.carolina.res.rr.com	2018-10-08 10:56:45.901945-07
1365	190.147.153.196	2018-10-08 12:32:10.119624-07
1366	190.147.153.196	2018-10-08 12:41:00.737604-07
1367	190.147.153.196	2018-10-08 13:11:50.797336-07
1368	190.147.153.196	2018-10-08 15:12:25.132169-07
1369	190.147.153.196	2018-10-08 17:13:30.155328-07
1370	cpe-69-132-98-0.carolina.res.rr.com	2018-10-09 01:59:08.715879-07
1371	190.147.153.196	2018-10-09 09:17:33.432417-07
1372	190.147.153.196	2018-10-09 11:11:52.251372-07
1373	190.147.153.196	2018-10-09 11:20:52.615549-07
1374	190.147.153.196	2018-10-09 11:31:31.541944-07
1375	190.147.153.196	2018-10-09 11:44:12.908005-07
1376	190.147.153.196	2018-10-09 11:46:49.65482-07
1377	190.147.153.196	2018-10-09 12:25:53.750372-07
1378	190.147.153.196	2018-10-09 13:46:46.355775-07
1379	190.147.153.196	2018-10-09 14:33:42.201029-07
1380	190.147.153.196	2018-10-09 14:34:59.349123-07
1381	190.147.153.196	2018-10-09 14:53:05.634563-07
1382	190.147.153.196	2018-10-09 15:11:57.467168-07
1383	cpe-69-132-98-0.carolina.res.rr.com	2018-10-10 03:37:19.323908-07
1384	cpe-69-132-98-0.carolina.res.rr.com	2018-10-10 03:58:46.484583-07
1385	cpe-69-132-98-0.carolina.res.rr.com	2018-10-10 04:46:24.28926-07
1386	cpe-69-132-98-0.carolina.res.rr.com	2018-10-10 08:03:45.256808-07
1387	190.147.153.196	2018-10-10 08:51:32.210445-07
1388	cpe-69-132-98-0.carolina.res.rr.com	2018-10-10 09:12:22.404436-07
1389	cpe-69-132-98-0.carolina.res.rr.com	2018-10-10 09:20:57.809547-07
1390	cpe-69-132-98-0.carolina.res.rr.com	2018-10-10 09:32:01.911304-07
1391	cpe-69-132-98-0.carolina.res.rr.com	2018-10-10 09:53:00.456559-07
1392	190.147.153.196	2018-10-10 12:20:57.184297-07
1393	cpe-69-132-98-0.carolina.res.rr.com	2018-10-11 03:22:22.205961-07
1394	cpe-69-132-98-0.carolina.res.rr.com	2018-10-11 04:55:13.776127-07
1395	cpe-69-132-98-0.carolina.res.rr.com	2018-10-11 05:14:40.419957-07
1396	cpe-69-132-98-0.carolina.res.rr.com	2018-10-11 05:23:21.121112-07
1397	cpe-69-132-98-0.carolina.res.rr.com	2018-10-11 05:38:42.698774-07
1398	cpe-69-132-98-0.carolina.res.rr.com	2018-10-11 06:14:27.439423-07
1399	cpe-69-132-98-0.carolina.res.rr.com	2018-10-11 09:03:56.814575-07
1400	190.147.153.196	2018-10-11 09:08:07.988632-07
1401	cpe-69-132-98-0.carolina.res.rr.com	2018-10-11 10:12:55.417108-07
1402	cpe-69-132-98-0.carolina.res.rr.com	2018-10-11 10:33:06.146874-07
1403	cpe-69-132-98-0.carolina.res.rr.com	2018-10-11 10:56:02.437296-07
1404	cpe-69-132-98-0.carolina.res.rr.com	2018-10-11 11:26:54.296204-07
1405	cpe-69-132-98-0.carolina.res.rr.com	2018-10-11 11:43:36.396267-07
1406	cpe-69-132-98-0.carolina.res.rr.com	2018-10-11 12:02:53.849373-07
1407	cpe-69-132-98-0.carolina.res.rr.com	2018-10-11 13:03:50.413451-07
1408	190.147.153.196	2018-10-11 17:07:05.53565-07
1409	cpe-69-132-98-0.carolina.res.rr.com	2018-10-12 02:36:29.077313-07
1410	190.147.153.196	2018-10-12 08:56:12.180473-07
1411	190.147.153.196	2018-10-12 12:10:12.812981-07
1412	190.147.153.196	2018-10-12 16:15:13.160246-07
1413	190.147.153.196	2018-10-12 16:19:49.313815-07
1414	cpe-69-132-98-0.carolina.res.rr.com	2018-10-13 01:30:29.834007-07
1415	cpe-69-132-98-0.carolina.res.rr.com	2018-10-13 01:56:01.126759-07
1416	cpe-69-132-98-0.carolina.res.rr.com	2018-10-13 02:13:42.566502-07
1417	cpe-69-132-98-0.carolina.res.rr.com	2018-10-13 02:29:30.613159-07
1418	cpe-69-132-98-0.carolina.res.rr.com	2018-10-15 01:50:14.655881-07
1419	cpe-69-132-98-0.carolina.res.rr.com	2018-10-15 02:16:53.758232-07
1420	cpe-69-132-98-0.carolina.res.rr.com	2018-10-15 02:19:22.448944-07
1421	cpe-69-132-98-0.carolina.res.rr.com	2018-10-15 02:37:31.592201-07
1422	cpe-69-132-98-0.carolina.res.rr.com	2018-10-15 02:55:51.406275-07
1423	cpe-69-132-98-0.carolina.res.rr.com	2018-10-15 03:09:35.441486-07
1424	cpe-69-132-98-0.carolina.res.rr.com	2018-10-15 05:22:51.127128-07
1425	cpe-69-132-98-0.carolina.res.rr.com	2018-10-15 05:33:27.514225-07
1426	cpe-69-132-98-0.carolina.res.rr.com	2018-10-15 05:43:10.490347-07
1427	cpe-69-132-98-0.carolina.res.rr.com	2018-10-15 05:53:34.452139-07
1428	cpe-69-132-98-0.carolina.res.rr.com	2018-10-15 06:31:50.058116-07
1429	cpe-69-132-98-0.carolina.res.rr.com	2018-10-15 06:40:42.380726-07
1430	cpe-69-132-98-0.carolina.res.rr.com	2018-10-15 07:58:43.968434-07
1431	cpe-69-132-98-0.carolina.res.rr.com	2018-10-15 08:50:50.433427-07
1432	cpe-69-132-98-0.carolina.res.rr.com	2018-10-15 09:04:05.547777-07
1433	cpe-69-132-98-0.carolina.res.rr.com	2018-10-15 09:16:32.638042-07
1434	cpe-69-132-98-0.carolina.res.rr.com	2018-10-15 09:26:54.443296-07
1435	cpe-69-132-98-0.carolina.res.rr.com	2018-10-15 09:43:33.362403-07
1436	cpe-69-132-98-0.carolina.res.rr.com	2018-10-15 11:04:25.15142-07
1437	cpe-69-132-98-0.carolina.res.rr.com	2018-10-15 11:16:50.400727-07
1438	cpe-69-132-98-0.carolina.res.rr.com	2018-10-15 11:29:28.735716-07
1439	cpe-69-132-98-0.carolina.res.rr.com	2018-10-16 03:30:28.888294-07
1440	cpe-69-132-98-0.carolina.res.rr.com	2018-10-16 04:55:16.950622-07
1441	cpe-69-132-98-0.carolina.res.rr.com	2018-10-16 05:03:05.529439-07
1442	cpe-69-132-98-0.carolina.res.rr.com	2018-10-16 05:33:42.446872-07
1443	cpe-69-132-98-0.carolina.res.rr.com	2018-10-16 07:05:52.507515-07
1444	cpe-69-132-98-0.carolina.res.rr.com	2018-10-16 07:21:49.433387-07
1445	190.147.153.196	2018-10-16 08:34:20.801171-07
1446	190.147.153.196	2018-10-16 09:08:50.435771-07
1447	190.147.153.196	2018-10-16 09:27:39.89961-07
1448	190.147.153.196	2018-10-16 09:48:32.529812-07
1449	cpe-69-132-98-0.carolina.res.rr.com	2018-10-16 10:08:16.238766-07
1450	190.147.153.196	2018-10-16 10:49:21.915286-07
1451	190.147.153.196	2018-10-16 11:09:09.130893-07
1452	190.147.153.196	2018-10-16 11:28:00.694668-07
1453	190.147.153.196	2018-10-16 12:42:47.600175-07
1454	190.147.153.196	2018-10-16 12:58:52.735984-07
1455	190.147.153.196	2018-10-16 14:47:43.363278-07
1456	190.147.153.196	2018-10-16 15:06:31.21237-07
1457	190.147.153.196	2018-10-16 15:27:19.594026-07
1458	190.147.153.196	2018-10-16 16:44:02.467071-07
1459	190.147.153.196	2018-10-16 17:08:30.455544-07
1460	190.147.153.196	2018-10-16 17:45:07.409232-07
1461	cpe-69-132-98-0.carolina.res.rr.com	2018-10-17 02:31:31.466846-07
1462	cpe-69-132-98-0.carolina.res.rr.com	2018-10-17 02:48:24.447326-07
1463	cpe-69-132-98-0.carolina.res.rr.com	2018-10-17 03:09:21.179499-07
1464	cpe-69-132-98-0.carolina.res.rr.com	2018-10-17 03:29:29.577785-07
1465	cpe-69-132-98-0.carolina.res.rr.com	2018-10-17 03:55:01.461861-07
1466	cpe-69-132-98-0.carolina.res.rr.com	2018-10-17 04:55:10.621811-07
1467	cpe-69-132-98-0.carolina.res.rr.com	2018-10-17 05:56:27.417558-07
1468	cpe-69-132-98-0.carolina.res.rr.com	2018-10-17 06:29:19.464336-07
1469	cpe-69-132-98-0.carolina.res.rr.com	2018-10-17 06:43:42.64035-07
1470	190.147.153.196	2018-10-17 09:08:58.929028-07
1471	190.147.153.196	2018-10-17 12:18:56.695895-07
1472	190.147.153.196	2018-10-17 12:28:00.811354-07
1473	190.147.153.196	2018-10-17 13:58:44.658425-07
1474	190.147.153.196	2018-10-17 14:17:44.569716-07
1475	190.147.153.196	2018-10-17 14:26:38.376364-07
1476	190.147.153.196	2018-10-17 14:41:02.497004-07
1477	190.147.153.196	2018-10-17 15:16:45.535693-07
1478	190.147.153.196	2018-10-17 15:45:11.989667-07
1479	190.147.153.196	2018-10-17 16:28:30.850997-07
1480	190.147.153.196	2018-10-17 16:47:20.442744-07
1481	190.147.153.196	2018-10-17 17:07:59.59018-07
1482	cpe-69-132-98-0.carolina.res.rr.com	2018-10-18 03:23:23.442393-07
1483	cpe-69-132-98-0.carolina.res.rr.com	2018-10-18 04:55:11.554394-07
1484	cpe-69-132-98-0.carolina.res.rr.com	2018-10-18 06:08:33.613434-07
1485	cpe-69-132-98-0.carolina.res.rr.com	2018-10-18 06:10:40.433835-07
1486	cpe-69-132-98-0.carolina.res.rr.com	2018-10-18 07:26:06.856415-07
1487	cpe-69-132-98-0.carolina.res.rr.com	2018-10-18 07:37:19.455256-07
1488	190.147.153.196	2018-10-18 08:34:10.16359-07
1489	190.147.153.196	2018-10-18 12:08:03.807559-07
1490	190.147.153.196	2018-10-18 12:18:59.372731-07
1491	190.147.153.196	2018-10-18 12:31:58.851145-07
1492	190.147.153.196	2018-10-18 12:50:43.929743-07
1493	cpe-69-132-98-0.carolina.res.rr.com	2018-10-18 13:31:36.392748-07
1494	190.147.153.196	2018-10-18 13:33:20.447395-07
1495	190.147.153.196	2018-10-18 13:53:58.535831-07
1496	190.147.153.196	2018-10-18 14:54:42.540159-07
1497	190.147.153.196	2018-10-18 15:55:26.68673-07
1498	190.147.153.196	2018-10-18 16:56:05.549303-07
1499	cpe-69-132-98-0.carolina.res.rr.com	2018-10-19 02:05:59.898966-07
1500	cpe-69-132-98-0.carolina.res.rr.com	2018-10-19 03:06:05.168757-07
1501	cpe-69-132-98-0.carolina.res.rr.com	2018-10-19 03:14:37.489216-07
1502	cpe-69-132-98-0.carolina.res.rr.com	2018-10-19 03:45:12.721143-07
1503	cpe-69-132-98-0.carolina.res.rr.com	2018-10-19 05:30:29.278892-07
1504	cpe-69-132-98-0.carolina.res.rr.com	2018-10-19 05:46:37.479271-07
1505	190.147.153.196	2018-10-19 12:20:06.60579-07
1506	cpe-69-132-98-0.carolina.res.rr.com	2018-10-22 02:03:13.603621-07
1507	190.147.153.196	2018-10-22 08:06:53.211302-07
1508	190.147.153.196	2018-10-22 12:03:07.583288-07
1509	190.147.153.196	2018-10-22 12:12:08.781639-07
1510	190.147.153.196	2018-10-22 12:22:58.394048-07
1511	190.147.153.196	2018-10-22 14:12:47.55402-07
1512	190.147.153.196	2018-10-22 14:50:13.840621-07
1513	190.147.153.196	2018-10-22 15:29:31.441479-07
1514	190.147.153.196	2018-10-22 17:26:34.852376-07
1515	190.147.153.196	2018-10-23 08:04:28.893615-07
1516	190.147.153.196	2018-10-23 12:16:02.56625-07
1517	190.147.153.196	2018-10-23 12:55:14.46841-07
1518	190.147.153.196	2018-10-23 13:56:12.12458-07
1519	190.147.153.196	2018-10-23 14:57:16.562856-07
1520	190.147.153.196	2018-10-23 15:57:57.125924-07
1521	190.147.153.196	2018-10-23 16:34:47.581166-07
1522	190.147.153.196	2018-10-23 17:05:33.969052-07
1523	190.147.153.196	2018-10-23 17:58:49.104855-07
1524	cpe-69-132-98-0.carolina.res.rr.com	2018-10-24 01:50:27.888412-07
1525	cpe-69-132-98-0.carolina.res.rr.com	2018-10-24 03:20:45.516358-07
1526	190.147.153.196	2018-10-24 08:53:27.526659-07
1527	190.147.153.196	2018-10-24 10:39:29.353804-07
1528	190.147.153.196	2018-10-24 12:28:22.159061-07
1529	190.147.153.196	2018-10-24 12:37:18.944007-07
1530	190.147.153.196	2018-10-24 12:58:20.923099-07
1531	190.147.153.196	2018-10-24 13:07:28.950708-07
1532	190.147.153.196	2018-10-24 13:53:36.405543-07
1533	190.147.153.196	2018-10-24 15:19:54.526668-07
1534	cpe-69-132-98-0.carolina.res.rr.com	2018-10-25 03:06:38.607889-07
1535	190.147.153.196	2018-10-25 09:01:47.860509-07
1536	190.147.153.196	2018-10-25 12:37:26.391947-07
1537	190.147.153.196	2018-10-25 12:56:16.41787-07
1538	190.147.153.196	2018-10-25 13:16:58.067373-07
1539	190.147.153.196	2018-10-25 14:17:38.703323-07
1540	190.147.153.196	2018-10-25 15:18:36.129627-07
1541	190.147.153.196	2018-10-25 15:37:34.493017-07
1542	190.147.153.196	2018-10-25 15:55:00.862416-07
1543	cpe-69-132-98-0.carolina.res.rr.com	2018-10-26 02:18:51.332682-07
1544	cpe-69-132-98-0.carolina.res.rr.com	2018-10-26 03:45:11.003277-07
1545	cpe-69-132-98-0.carolina.res.rr.com	2018-10-26 04:18:22.073915-07
1546	cpe-69-132-98-0.carolina.res.rr.com	2018-10-26 04:55:29.774525-07
1547	cpe-69-132-98-0.carolina.res.rr.com	2018-10-26 06:05:47.572336-07
1548	cpe-69-132-98-0.carolina.res.rr.com	2018-10-26 06:36:21.403744-07
1549	cpe-69-132-98-0.carolina.res.rr.com	2018-10-26 06:49:32.051442-07
1550	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-10-26 06:58:39.237792-07
1551	cpe-69-132-98-0.carolina.res.rr.com	2018-10-26 07:19:29.943066-07
1552	cpe-69-132-98-0.carolina.res.rr.com	2018-10-26 09:23:02.085862-07
1553	cpe-69-132-98-0.carolina.res.rr.com	2018-10-26 09:43:29.084139-07
1554	cpe-69-132-98-0.carolina.res.rr.com	2018-10-26 09:54:01.359355-07
1555	cpe-69-132-98-0.carolina.res.rr.com	2018-10-26 10:27:08.70295-07
1556	cpe-69-132-98-0.carolina.res.rr.com	2018-10-26 10:43:44.680673-07
1557	cpe-69-132-98-0.carolina.res.rr.com	2018-10-26 11:26:37.607963-07
1558	cpe-69-132-98-0.carolina.res.rr.com	2018-10-26 11:53:32.095412-07
1559	cpe-69-132-98-0.carolina.res.rr.com	2018-10-26 13:24:43.053885-07
1560	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-10-29 06:00:07.528706-07
1561	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-10-29 07:23:37.915378-07
1562	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-10-29 07:32:01.511878-07
1563	190.147.153.196	2018-10-29 09:04:44.528401-07
1564	190.147.153.196	2018-10-29 12:28:17.389936-07
1565	190.147.153.196	2018-10-29 14:18:03.388459-07
1566	190.147.153.196	2018-10-29 14:32:08.381984-07
1567	190.147.153.196	2018-10-29 14:51:09.556146-07
1568	190.147.153.196	2018-10-29 15:24:47.729277-07
1569	190.147.153.196	2018-10-29 15:51:37.484569-07
1570	190.147.153.196	2018-10-29 16:11:36.424012-07
1571	2605:a000:ee07:cb00:9569:9ef1:1831:e09d	2018-10-29 20:51:54.750421-07
1572	190.147.153.196	2018-10-30 08:56:07.924375-07
1573	190.147.153.196	2018-10-30 12:39:51.409203-07
1574	190.147.153.196	2018-10-30 12:48:48.712246-07
1575	190.147.153.196	2018-10-30 12:59:28.786973-07
1576	190.147.153.196	2018-10-30 13:20:24.476233-07
1577	190.147.153.196	2018-10-30 13:57:52.9346-07
1578	190.147.153.196	2018-10-30 14:36:30.473794-07
1579	190.147.153.196	2018-10-30 16:37:10.476081-07
1580	cpe-69-132-98-0.carolina.res.rr.com	2018-10-31 03:16:42.394975-07
1581	cpe-69-132-98-0.carolina.res.rr.com	2018-10-31 04:16:42.966125-07
1582	cpe-69-132-98-0.carolina.res.rr.com	2018-10-31 06:12:24.878847-07
1583	cpe-69-132-98-0.carolina.res.rr.com	2018-10-31 06:35:36.513509-07
1584	cpe-69-132-98-0.carolina.res.rr.com	2018-10-31 06:55:59.80821-07
1585	cpe-69-132-98-0.carolina.res.rr.com	2018-10-31 09:17:56.445377-07
1586	cpe-69-132-98-0.carolina.res.rr.com	2018-10-31 09:28:39.348271-07
1587	190.147.153.196	2018-10-31 09:38:44.908209-07
1588	cpe-69-132-98-0.carolina.res.rr.com	2018-10-31 09:42:29.780888-07
1589	cpe-69-132-98-0.carolina.res.rr.com	2018-10-31 10:13:11.402044-07
1590	cpe-69-132-98-0.carolina.res.rr.com	2018-10-31 10:24:15.684554-07
1591	cpe-69-132-98-0.carolina.res.rr.com	2018-10-31 10:43:06.44348-07
1592	cpe-69-132-98-0.carolina.res.rr.com	2018-10-31 11:03:51.928224-07
1593	190.147.153.196	2018-10-31 12:35:56.051459-07
1594	190.147.153.196	2018-10-31 12:54:46.371035-07
1595	190.147.153.196	2018-10-31 13:15:37.663001-07
1596	190.147.153.196	2018-10-31 15:16:19.770673-07
1597	190.147.153.196	2018-10-31 16:14:31.406946-07
1598	cpe-69-132-98-0.carolina.res.rr.com	2018-11-01 03:09:51.429681-07
1599	cpe-69-132-98-0.carolina.res.rr.com	2018-11-01 04:42:25.058454-07
1600	cpe-69-132-98-0.carolina.res.rr.com	2018-11-01 13:03:47.406553-07
1601	190.147.153.196	2018-11-02 08:46:14.789497-07
1602	cpe-69-132-98-0.carolina.res.rr.com	2018-11-02 10:25:59.349546-07
1603	cpe-69-132-98-0.carolina.res.rr.com	2018-11-02 11:20:08.023901-07
1604	190.147.153.196	2018-11-02 12:12:02.362346-07
1605	190.147.153.196	2018-11-02 12:21:03.556382-07
1606	cpe-69-132-98-0.carolina.res.rr.com	2018-11-02 12:22:00.418955-07
1607	cpe-69-132-98-0.carolina.res.rr.com	2018-11-02 12:32:43.558615-07
1608	190.147.153.196	2018-11-02 12:51:36.354104-07
1609	190.147.153.196	2018-11-02 13:14:20.065594-07
1610	190.147.153.196	2018-11-02 13:34:42.379449-07
1611	190.147.153.196	2018-11-02 14:28:28.820973-07
1612	190.147.153.196	2018-11-02 14:37:10.76815-07
1613	190.147.153.196	2018-11-02 15:02:26.422997-07
1614	cpe-69-132-98-0.carolina.res.rr.com	2018-11-05 02:24:29.856874-08
1615	cpe-69-132-98-0.carolina.res.rr.com	2018-11-05 03:02:11.254685-08
1616	cpe-69-132-98-0.carolina.res.rr.com	2018-11-05 03:13:00.411858-08
1617	cpe-69-132-98-0.carolina.res.rr.com	2018-11-05 03:44:03.456113-08
1618	cpe-69-132-98-0.carolina.res.rr.com	2018-11-05 05:38:23.895745-08
1619	cpe-69-132-98-0.carolina.res.rr.com	2018-11-05 05:48:54.388991-08
1620	cpe-69-132-98-0.carolina.res.rr.com	2018-11-05 09:29:07.031748-08
1621	cpe-69-132-98-0.carolina.res.rr.com	2018-11-05 09:39:26.426365-08
1622	cpe-69-132-98-0.carolina.res.rr.com	2018-11-05 09:51:29.77145-08
1623	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-11-05 10:19:58.963268-08
1624	cpe-69-132-98-0.carolina.res.rr.com	2018-11-05 10:28:19.597197-08
1625	cpe-69-132-98-0.carolina.res.rr.com	2018-11-05 10:37:23.840189-08
1626	cpe-69-132-98-0.carolina.res.rr.com	2018-11-05 10:56:01.294562-08
1627	cpe-69-132-98-0.carolina.res.rr.com	2018-11-05 11:07:45.902899-08
1628	cpe-69-132-98-0.carolina.res.rr.com	2018-11-05 12:04:54.532779-08
1629	cpe-69-132-98-0.carolina.res.rr.com	2018-11-05 12:13:08.93442-08
1630	cpe-69-132-98-0.carolina.res.rr.com	2018-11-05 12:24:19.099196-08
1631	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-11-05 12:31:19.363305-08
1632	cpe-69-132-98-0.carolina.res.rr.com	2018-11-05 12:48:48.783633-08
1633	cpe-69-132-98-0.carolina.res.rr.com	2018-11-05 12:56:21.269585-08
1634	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-11-05 13:33:12.24348-08
1635	cpe-69-132-98-0.carolina.res.rr.com	2018-11-06 03:17:24.921365-08
1636	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-11-06 06:33:04.442642-08
1637	190.147.153.196	2018-11-06 07:44:01.378686-08
1638	190.147.153.196	2018-11-06 09:09:36.485772-08
1639	190.147.153.196	2018-11-06 09:18:30.485534-08
1640	190.147.153.196	2018-11-06 09:36:53.858991-08
1641	190.147.153.196	2018-11-06 09:47:56.450976-08
1642	190.147.153.196	2018-11-06 10:03:38.586244-08
1643	190.147.153.196	2018-11-06 10:22:42.699106-08
1644	190.147.153.196	2018-11-06 11:21:11.379052-08
1645	190.147.153.196	2018-11-06 11:40:08.859407-08
1646	190.147.153.196	2018-11-06 12:09:03.558529-08
1647	190.147.153.196	2018-11-06 12:47:50.444925-08
1648	190.147.153.196	2018-11-06 13:46:32.891958-08
1649	cpe-69-132-98-0.carolina.res.rr.com	2018-11-06 14:05:18.371012-08
1650	190.147.153.196	2018-11-06 14:25:53.877013-08
1651	cpe-69-132-98-0.carolina.res.rr.com	2018-11-07 03:09:09.858521-08
1652	cpe-69-132-98-0.carolina.res.rr.com	2018-11-07 05:17:08.977399-08
1653	cpe-69-132-98-0.carolina.res.rr.com	2018-11-07 07:17:58.9137-08
1654	190.147.153.196	2018-11-07 07:38:34.621946-08
1655	cpe-69-132-98-0.carolina.res.rr.com	2018-11-07 09:49:26.170066-08
1656	cpe-69-132-98-0.carolina.res.rr.com	2018-11-07 10:00:30.096485-08
1657	cpe-69-132-98-0.carolina.res.rr.com	2018-11-07 10:14:20.385586-08
1658	cpe-69-132-98-0.carolina.res.rr.com	2018-11-07 10:26:39.388691-08
1659	cpe-69-132-98-0.carolina.res.rr.com	2018-11-07 10:46:07.001915-08
1660	190.147.153.196	2018-11-07 11:55:47.225104-08
1661	cpe-69-132-98-0.carolina.res.rr.com	2018-11-08 03:07:47.458799-08
1662	cpe-69-132-98-0.carolina.res.rr.com	2018-11-08 05:15:11.855617-08
1663	cpe-69-132-98-0.carolina.res.rr.com	2018-11-08 05:32:44.409952-08
1664	190.147.153.196	2018-11-08 09:00:57.960821-08
1665	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-11-08 09:07:30.388988-08
1666	190.147.153.196	2018-11-08 10:33:29.986791-08
1667	190.147.153.196	2018-11-08 10:42:06.432467-08
1668	190.147.153.196	2018-11-08 11:20:52.510004-08
1669	190.147.153.196	2018-11-08 11:29:47.873604-08
1670	190.147.153.196	2018-11-08 12:00:29.873882-08
1671	190.147.153.196	2018-11-08 13:01:10.614176-08
1672	190.147.153.196	2018-11-08 14:01:52.001989-08
1673	190.147.153.196	2018-11-08 14:21:26.932541-08
1674	190.147.153.196	2018-11-08 14:52:29.909468-08
1675	190.147.153.196	2018-11-08 15:53:04.079918-08
1676	cpe-69-132-98-0.carolina.res.rr.com	2018-11-09 03:17:11.383168-08
1677	190.147.153.196	2018-11-09 09:38:47.516457-08
1678	138.130.60.237	2018-11-10 21:33:18.83227-08
1679	107.161.19.53	2018-11-11 15:02:36.077824-08
1680	cpe-69-132-98-0.carolina.res.rr.com	2018-11-12 03:06:36.136153-08
1681	cpe-69-132-98-0.carolina.res.rr.com	2018-11-12 09:24:29.67605-08
1682	cpe-69-132-98-0.carolina.res.rr.com	2018-11-12 09:33:14.537979-08
1683	cpe-69-132-98-0.carolina.res.rr.com	2018-11-12 09:42:46.519458-08
1684	cpe-69-132-98-0.carolina.res.rr.com	2018-11-12 09:57:57.910251-08
1685	cpe-69-132-98-0.carolina.res.rr.com	2018-11-12 11:34:26.168168-08
1686	cpe-69-132-98-0.carolina.res.rr.com	2018-11-12 13:59:45.082849-08
1687	cpe-69-132-98-0.carolina.res.rr.com	2018-11-13 03:28:26.970006-08
1688	cpe-69-132-98-0.carolina.res.rr.com	2018-11-13 05:15:08.017529-08
1689	cpe-69-132-98-0.carolina.res.rr.com	2018-11-13 05:17:27.32394-08
1690	cpe-69-132-98-0.carolina.res.rr.com	2018-11-13 05:32:31.832263-08
1691	190.147.153.196	2018-11-13 07:46:49.118206-08
1692	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-11-13 07:52:25.327617-08
1693	cpe-69-132-98-0.carolina.res.rr.com	2018-11-13 08:39:55.915431-08
1694	cpe-69-132-98-0.carolina.res.rr.com	2018-11-13 09:20:24.339966-08
1695	cpe-69-132-98-0.carolina.res.rr.com	2018-11-13 09:27:44.118418-08
1696	cpe-69-132-98-0.carolina.res.rr.com	2018-11-13 09:41:58.737798-08
1697	cpe-69-132-98-0.carolina.res.rr.com	2018-11-13 10:29:52.8756-08
1698	190.147.153.196	2018-11-13 11:10:48.417485-08
1699	cpe-69-132-98-0.carolina.res.rr.com	2018-11-13 11:12:27.053974-08
1700	190.147.153.196	2018-11-13 11:19:51.363899-08
1701	cpe-69-132-98-0.carolina.res.rr.com	2018-11-13 11:23:01.552637-08
1702	190.147.153.196	2018-11-13 11:50:37.847922-08
1703	190.147.153.196	2018-11-13 12:10:59.431867-08
1704	cpe-69-132-98-0.carolina.res.rr.com	2018-11-13 15:59:56.961041-08
1705	cpe-69-132-98-0.carolina.res.rr.com	2018-11-14 02:22:26.451249-08
1706	cpe-69-132-98-0.carolina.res.rr.com	2018-11-14 02:58:12.551542-08
1707	cpe-69-132-98-0.carolina.res.rr.com	2018-11-14 03:17:20.060251-08
1708	cpe-69-132-98-0.carolina.res.rr.com	2018-11-14 03:28:24.619289-08
1709	cpe-69-132-98-0.carolina.res.rr.com	2018-11-14 03:44:10.952599-08
1710	cpe-69-132-98-0.carolina.res.rr.com	2018-11-14 04:03:05.442697-08
1711	cpe-69-132-98-0.carolina.res.rr.com	2018-11-14 05:28:27.618914-08
1712	cpe-69-132-98-0.carolina.res.rr.com	2018-11-14 05:35:38.937809-08
1713	cpe-69-132-98-0.carolina.res.rr.com	2018-11-14 05:49:19.489895-08
1714	cpe-69-132-98-0.carolina.res.rr.com	2018-11-14 06:02:49.406612-08
1715	cpe-69-132-98-0.carolina.res.rr.com	2018-11-14 06:55:29.366032-08
1716	cpe-69-132-98-0.carolina.res.rr.com	2018-11-14 07:04:24.087117-08
1717	cpe-69-132-98-0.carolina.res.rr.com	2018-11-14 07:21:20.875331-08
1718	190.147.153.196	2018-11-14 08:49:05.497519-08
1719	cpe-69-132-98-0.carolina.res.rr.com	2018-11-14 10:33:08.734463-08
1720	cpe-69-132-98-0.carolina.res.rr.com	2018-11-14 10:38:50.899385-08
1721	cpe-69-132-98-0.carolina.res.rr.com	2018-11-14 10:56:14.93488-08
1722	cpe-69-132-98-0.carolina.res.rr.com	2018-11-14 11:14:48.443385-08
1723	190.147.153.196	2018-11-14 11:27:00.85498-08
1724	190.147.153.196	2018-11-14 11:29:17.890645-08
1725	190.147.153.196	2018-11-14 11:30:04.925404-08
1726	cpe-69-132-98-0.carolina.res.rr.com	2018-11-14 12:00:12.061112-08
1727	cpe-69-132-98-0.carolina.res.rr.com	2018-11-14 12:14:44.540293-08
1728	cpe-69-132-98-0.carolina.res.rr.com	2018-11-14 12:29:44.753508-08
1729	190.147.153.196	2018-11-14 13:23:19.470345-08
1730	190.147.153.196	2018-11-14 13:42:04.691272-08
1731	190.147.153.196	2018-11-14 13:48:25.918251-08
1732	190.147.153.196	2018-11-14 14:02:54.837948-08
1733	190.147.153.196	2018-11-14 14:31:45.977305-08
1734	190.147.153.196	2018-11-14 14:33:49.417136-08
1735	190.147.153.196	2018-11-14 14:51:56.173098-08
1736	cpe-69-132-98-0.carolina.res.rr.com	2018-11-15 07:03:14.405417-08
1737	190.147.153.196	2018-11-15 07:36:03.079238-08
1738	cpe-69-132-98-0.carolina.res.rr.com	2018-11-15 07:57:35.999204-08
1739	cpe-69-132-98-0.carolina.res.rr.com	2018-11-15 08:21:56.383464-08
1740	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-11-15 08:58:00.940839-08
1741	cpe-69-132-98-0.carolina.res.rr.com	2018-11-15 09:28:08.307739-08
1742	cpe-69-132-98-0.carolina.res.rr.com	2018-11-15 09:33:47.429262-08
1743	cpe-69-132-98-0.carolina.res.rr.com	2018-11-15 09:48:48.912448-08
1744	cpe-69-132-98-0.carolina.res.rr.com	2018-11-15 10:18:31.432234-08
1745	cpe-69-132-98-0.carolina.res.rr.com	2018-11-15 10:33:58.871523-08
1746	cpe-69-132-98-0.carolina.res.rr.com	2018-11-15 10:49:45.910555-08
1747	190.147.153.196	2018-11-15 11:09:57.178314-08
1748	cpe-69-132-98-0.carolina.res.rr.com	2018-11-16 03:15:12.811616-08
1749	cpe-69-132-98-0.carolina.res.rr.com	2018-11-16 04:55:10.620274-08
1750	cpe-69-132-98-0.carolina.res.rr.com	2018-11-16 05:13:55.383174-08
1751	cpe-69-132-98-0.carolina.res.rr.com	2018-11-16 05:30:29.437346-08
1752	cpe-69-132-98-0.carolina.res.rr.com	2018-11-16 05:46:52.91097-08
1753	cpe-69-132-98-0.carolina.res.rr.com	2018-11-16 05:58:57.838804-08
1754	cpe-69-132-98-0.carolina.res.rr.com	2018-11-16 06:28:34.384302-08
1755	cpe-69-132-98-0.carolina.res.rr.com	2018-11-16 06:49:26.875999-08
1756	cpe-69-132-98-0.carolina.res.rr.com	2018-11-16 06:57:51.04226-08
1757	cpe-69-132-98-0.carolina.res.rr.com	2018-11-16 08:02:41.986762-08
1758	190.147.153.196	2018-11-16 08:08:23.357331-08
1759	cpe-69-132-98-0.carolina.res.rr.com	2018-11-16 08:16:42.94873-08
1760	190.147.153.196	2018-11-16 08:52:35.592894-08
1761	cpe-69-132-98-0.carolina.res.rr.com	2018-11-16 08:57:51.874521-08
1762	190.147.153.196	2018-11-16 09:01:38.983222-08
1763	cpe-69-132-98-0.carolina.res.rr.com	2018-11-19 02:58:24.484122-08
1764	190.147.153.196	2018-11-19 05:55:39.855072-08
1765	190.147.153.196	2018-11-19 06:04:13.632211-08
1766	190.147.153.196	2018-11-19 06:34:56.491472-08
1767	190.147.153.196	2018-11-19 07:22:38.738905-08
1768	190.147.153.196	2018-11-19 07:39:27.71056-08
1769	190.147.153.196	2018-11-19 11:26:32.400182-08
1770	cpe-69-132-98-0.carolina.res.rr.com	2018-11-20 02:59:41.869171-08
1771	190.147.153.196	2018-11-20 07:34:25.559388-08
1772	cpe-69-132-98-0.carolina.res.rr.com	2018-11-21 02:54:28.785168-08
1773	cpe-69-132-98-0.carolina.res.rr.com	2018-11-21 04:55:13.110413-08
1774	cpe-69-132-98-0.carolina.res.rr.com	2018-11-21 05:12:40.428083-08
1775	cpe-69-132-98-0.carolina.res.rr.com	2018-11-21 05:20:59.402696-08
1776	cpe-69-132-98-0.carolina.res.rr.com	2018-11-21 05:30:42.546003-08
1777	cpe-69-132-98-0.carolina.res.rr.com	2018-11-21 05:48:34.852199-08
1778	cpe-69-132-98-0.carolina.res.rr.com	2018-11-21 06:19:07.884208-08
1779	cpe-69-132-98-0.carolina.res.rr.com	2018-11-21 06:46:20.02085-08
1780	cpe-69-132-98-0.carolina.res.rr.com	2018-11-21 07:16:38.094329-08
1781	190.147.153.196	2018-11-21 07:27:35.400204-08
1782	cpe-69-132-98-0.carolina.res.rr.com	2018-11-21 07:37:48.531096-08
1783	cpe-69-132-98-0.carolina.res.rr.com	2018-11-21 08:08:52.463022-08
1784	cpe-69-132-98-0.carolina.res.rr.com	2018-11-21 08:19:17.981825-08
1785	cpe-69-132-98-0.carolina.res.rr.com	2018-11-21 09:26:21.976453-08
1786	cpe-69-132-98-0.carolina.res.rr.com	2018-11-21 09:58:48.461628-08
1787	cpe-69-132-98-0.carolina.res.rr.com	2018-11-21 10:08:20.137788-08
1788	cpe-69-132-98-0.carolina.res.rr.com	2018-11-21 10:24:14.805246-08
1789	cpe-69-132-98-0.carolina.res.rr.com	2018-11-21 10:42:19.842739-08
1790	190.147.153.196	2018-11-21 10:53:15.829989-08
1791	190.147.153.196	2018-11-21 11:11:39.980219-08
1792	cpe-69-132-98-0.carolina.res.rr.com	2018-11-21 11:23:17.966183-08
1793	190.147.153.196	2018-11-21 11:25:32.944162-08
1794	cpe-69-132-98-0.carolina.res.rr.com	2018-11-21 11:43:52.466468-08
1795	cpe-69-132-98-0.carolina.res.rr.com	2018-11-21 11:54:38.020842-08
1796	cpe-69-132-98-0.carolina.res.rr.com	2018-11-21 12:19:30.559209-08
1797	190.147.153.196	2018-11-21 12:58:14.681901-08
1798	190.147.153.196	2018-11-22 07:35:24.255045-08
1799	190.147.153.196	2018-11-22 07:47:59.82082-08
1800	190.147.153.196	2018-11-22 08:05:21.408351-08
1801	190.147.153.196	2018-11-22 08:55:42.75995-08
1802	190.147.153.196	2018-11-22 09:06:27.35425-08
1803	190.147.153.196	2018-11-22 09:33:34.57312-08
1804	190.147.153.196	2018-11-22 09:49:20.404588-08
1805	190.147.153.196	2018-11-22 10:20:41.039066-08
1806	190.147.153.196	2018-11-22 10:38:45.406476-08
1807	190.147.153.196	2018-11-22 10:54:23.187949-08
1808	190.147.153.196	2018-11-22 11:21:54.623146-08
1809	190.147.153.196	2018-11-22 11:40:52.868531-08
1810	190.147.153.196	2018-11-22 12:01:52.401269-08
1811	190.147.153.196	2018-11-22 12:42:54.476276-08
1812	190.147.153.196	2018-11-22 13:40:59.617449-08
1813	p5DCF9159.dip0.t-ipconnect.de	2018-11-23 08:47:54.519295-08
1814	190.147.153.196	2018-11-23 12:14:20.532517-08
1815	p5DCF9159.dip0.t-ipconnect.de	2018-11-23 13:37:20.763012-08
1816	190.147.153.196	2018-11-23 14:56:47.29208-08
1817	cpe-69-132-98-0.carolina.res.rr.com	2018-11-26 03:06:55.615989-08
1818	cpe-69-132-98-0.carolina.res.rr.com	2018-11-26 04:55:14.705825-08
1819	cpe-69-132-98-0.carolina.res.rr.com	2018-11-26 05:45:00.953661-08
1820	cpe-69-132-98-0.carolina.res.rr.com	2018-11-26 06:02:52.461996-08
1821	cpe-69-132-98-0.carolina.res.rr.com	2018-11-26 07:36:43.973723-08
1822	190.147.153.196	2018-11-26 07:53:19.052791-08
1823	cpe-69-132-98-0.carolina.res.rr.com	2018-11-26 07:56:47.966676-08
1824	cpe-69-132-98-0.carolina.res.rr.com	2018-11-26 09:42:58.970005-08
1825	cpe-69-132-98-0.carolina.res.rr.com	2018-11-26 09:53:45.959138-08
1826	cpe-69-132-98-0.carolina.res.rr.com	2018-11-26 10:07:34.488347-08
1827	cpe-69-132-98-0.carolina.res.rr.com	2018-11-26 11:04:24.257036-08
1828	cpe-69-132-98-0.carolina.res.rr.com	2018-11-26 13:16:05.73122-08
1829	190.147.153.196	2018-11-27 07:50:01.384258-08
1830	190.147.153.196	2018-11-27 09:25:19.60834-08
1831	190.147.153.196	2018-11-27 09:40:27.90256-08
1832	190.147.153.196	2018-11-27 10:44:38.752215-08
1833	190.147.153.196	2018-11-27 10:55:00.884509-08
1834	190.147.153.196	2018-11-27 11:11:50.409467-08
1835	190.147.153.196	2018-11-27 11:27:50.806493-08
1836	190.147.153.196	2018-11-27 11:48:36.965362-08
1837	190.147.153.196	2018-11-27 12:38:09.832785-08
1838	190.147.153.196	2018-11-27 12:45:36.509887-08
1839	190.147.153.196	2018-11-27 13:04:24.795351-08
1840	190.147.153.196	2018-11-27 13:25:10.619387-08
1841	190.147.153.196	2018-11-27 13:57:35.300182-08
1842	190.147.153.196	2018-11-27 14:35:13.667235-08
1843	190.147.153.196	2018-11-27 14:43:55.917859-08
1844	190.147.153.196	2018-11-27 15:14:52.529097-08
1845	190.147.153.196	2018-11-27 15:23:53.539879-08
1846	190.147.153.196	2018-11-27 15:31:24.949565-08
1847	cpe-69-132-98-0.carolina.res.rr.com	2018-11-28 03:19:54.688283-08
1848	190.147.153.196	2018-11-28 09:42:14.010492-08
1849	190.147.153.196	2018-11-28 12:09:54.937411-08
1850	190.147.153.196	2018-11-28 12:12:11.178996-08
1851	190.147.153.196	2018-11-28 12:49:35.529526-08
1852	190.147.153.196	2018-11-28 13:10:18.584935-08
1853	cpe-69-132-98-0.carolina.res.rr.com	2018-11-28 13:24:20.969751-08
1854	190.147.153.196	2018-11-28 14:06:08.83537-08
1855	190.147.153.196	2018-11-28 14:15:29.536991-08
1856	190.147.153.196	2018-11-28 14:31:20.15194-08
1857	190.147.153.196	2018-11-28 14:51:53.452239-08
1858	190.147.153.196	2018-11-28 15:30:16.610849-08
1859	190.147.153.196	2018-11-28 15:44:53.386902-08
1860	190.147.153.196	2018-11-28 16:03:13.843518-08
1861	190.147.153.196	2018-11-28 16:14:05.019601-08
1862	cpe-69-132-98-0.carolina.res.rr.com	2018-11-29 03:03:43.841743-08
1863	cpe-69-132-98-0.carolina.res.rr.com	2018-11-29 03:51:10.478485-08
1864	cpe-69-132-98-0.carolina.res.rr.com	2018-11-29 05:23:43.117443-08
1865	cpe-69-132-98-0.carolina.res.rr.com	2018-11-29 05:36:53.351161-08
1866	cpe-69-132-98-0.carolina.res.rr.com	2018-11-29 05:52:56.091982-08
1867	cpe-69-132-98-0.carolina.res.rr.com	2018-11-29 06:08:55.370963-08
1868	cpe-69-132-98-0.carolina.res.rr.com	2018-11-29 06:23:39.906939-08
1869	190.147.153.196	2018-11-29 08:13:37.746928-08
1870	cpe-69-132-98-0.carolina.res.rr.com	2018-11-29 09:29:16.76006-08
1871	cpe-69-132-98-0.carolina.res.rr.com	2018-11-29 09:57:54.990877-08
1872	cpe-69-132-98-0.carolina.res.rr.com	2018-11-29 10:16:42.836911-08
1873	190.147.153.196	2018-11-29 13:07:16.110373-08
1874	190.147.153.196	2018-11-29 13:16:15.010086-08
1875	cpe-69-132-98-0.carolina.res.rr.com	2018-11-30 07:00:47.509099-08
1876	cpe-69-132-98-0.carolina.res.rr.com	2018-11-30 07:40:13.669426-08
1877	cpe-69-132-98-0.carolina.res.rr.com	2018-11-30 07:49:05.828112-08
1878	cpe-69-132-98-0.carolina.res.rr.com	2018-11-30 09:11:29.500959-08
1879	190.147.153.196	2018-11-30 09:24:07.329208-08
1880	cpe-69-132-98-0.carolina.res.rr.com	2018-11-30 10:36:24.973447-08
1881	cpe-69-132-98-0.carolina.res.rr.com	2018-11-30 10:54:00.196822-08
1882	190.147.153.196	2018-11-30 11:02:45.226068-08
1883	cpe-69-132-98-0.carolina.res.rr.com	2018-11-30 11:20:03.703384-08
1884	190.147.153.196	2018-11-30 11:26:49.822606-08
1885	190.147.153.196	2018-11-30 11:35:49.832112-08
1886	cpe-69-132-98-0.carolina.res.rr.com	2018-11-30 12:12:47.567794-08
1887	cpe-69-132-98-0.carolina.res.rr.com	2018-11-30 12:23:47.960033-08
1888	cpe-69-132-98-0.carolina.res.rr.com	2018-11-30 12:37:50.061437-08
1889	190.147.153.196	2018-11-30 13:06:54.956413-08
1890	cpe-69-132-98-0.carolina.res.rr.com	2018-11-30 13:08:29.469304-08
1891	190.147.153.196	2018-11-30 14:07:42.367943-08
1892	190.147.153.196	2018-11-30 14:47:38.594464-08
1893	cpe-69-132-98-0.carolina.res.rr.com	2018-12-03 03:56:32.996398-08
1894	cpe-69-132-98-0.carolina.res.rr.com	2018-12-03 05:10:20.880965-08
1895	cpe-69-132-98-0.carolina.res.rr.com	2018-12-03 05:42:41.414183-08
1896	cpe-69-132-98-0.carolina.res.rr.com	2018-12-03 05:49:28.365218-08
1897	cpe-69-132-98-0.carolina.res.rr.com	2018-12-03 05:56:42.013695-08
1898	cpe-69-132-98-0.carolina.res.rr.com	2018-12-03 06:41:21.14925-08
1899	cpe-69-132-98-0.carolina.res.rr.com	2018-12-03 07:11:57.562532-08
1900	190.147.153.196	2018-12-03 07:38:27.360477-08
1901	190.147.153.196	2018-12-03 08:44:06.380914-08
1902	190.147.153.196	2018-12-03 08:46:29.006567-08
1903	190.147.153.196	2018-12-03 09:03:44.592152-08
1904	190.147.153.196	2018-12-03 09:24:36.106233-08
1905	190.147.153.196	2018-12-03 10:14:24.683561-08
1906	190.147.153.196	2018-12-03 10:16:49.367201-08
1907	190.147.153.196	2018-12-03 11:10:33.175182-08
1908	190.147.153.196	2018-12-03 12:11:09.40428-08
1909	190.147.153.196	2018-12-03 13:11:51.213463-08
1910	190.147.153.196	2018-12-03 13:18:41.485954-08
1911	190.147.153.196	2018-12-03 13:21:01.598699-08
1912	190.147.153.196	2018-12-03 13:41:33.948456-08
1913	190.147.153.196	2018-12-03 13:44:29.644022-08
1914	190.147.153.196	2018-12-03 15:23:30.181249-08
1915	190.147.153.196	2018-12-03 16:24:20.166692-08
1916	cpe-69-132-98-0.carolina.res.rr.com	2018-12-04 03:08:13.817113-08
1917	cpe-69-132-98-0.carolina.res.rr.com	2018-12-04 04:55:08.938861-08
1918	cpe-69-132-98-0.carolina.res.rr.com	2018-12-04 05:08:27.742311-08
1919	cpe-69-132-98-0.carolina.res.rr.com	2018-12-04 05:18:35.590723-08
1920	190.147.153.196	2018-12-04 11:32:15.176076-08
1921	190.147.153.196	2018-12-04 14:59:51.451036-08
1922	cpe-69-132-98-0.carolina.res.rr.com	2018-12-05 03:26:39.815383-08
1923	190.147.153.196	2018-12-05 07:49:40.924271-08
1924	190.147.153.196	2018-12-05 08:55:36.037045-08
1925	190.147.153.196	2018-12-05 09:14:12.036867-08
1926	190.147.153.196	2018-12-05 09:34:51.533619-08
1927	190.147.153.196	2018-12-05 10:33:01.540207-08
1928	190.147.153.196	2018-12-05 10:51:56.875894-08
1929	190.147.153.196	2018-12-05 10:59:46.761848-08
1930	190.147.153.196	2018-12-05 11:44:47.040892-08
1931	190.147.153.196	2018-12-05 12:19:08.110713-08
1932	190.147.153.196	2018-12-05 12:38:02.809929-08
1933	190.147.153.196	2018-12-05 12:59:05.815028-08
1934	190.147.153.196	2018-12-05 13:59:45.435775-08
1935	190.147.153.196	2018-12-05 15:00:29.597101-08
1936	190.147.153.196	2018-12-05 15:22:08.622464-08
1937	190.147.153.196	2018-12-05 15:33:31.742387-08
1938	190.147.153.196	2018-12-05 15:52:40.094895-08
1939	190.147.153.196	2018-12-05 16:13:22.479267-08
1940	cpe-69-132-98-0.carolina.res.rr.com	2018-12-06 03:29:02.815377-08
1941	cpe-69-132-98-0.carolina.res.rr.com	2018-12-06 05:09:25.625647-08
1942	cpe-69-132-98-0.carolina.res.rr.com	2018-12-06 05:17:51.83789-08
1943	cpe-69-132-98-0.carolina.res.rr.com	2018-12-06 05:29:59.396832-08
1944	cpe-69-132-98-0.carolina.res.rr.com	2018-12-06 05:52:16.934769-08
1945	cpe-69-132-98-0.carolina.res.rr.com	2018-12-06 06:04:11.634697-08
1946	190.147.153.196	2018-12-06 07:20:57.807967-08
1947	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-12-06 09:18:11.81243-08
1948	cpe-69-132-98-0.carolina.res.rr.com	2018-12-06 11:50:27.913584-08
1949	cpe-69-132-98-0.carolina.res.rr.com	2018-12-06 12:01:13.633344-08
2478	190.147.153.196	2019-01-18 16:52:09.396553-08
1950	cpe-69-132-98-0.carolina.res.rr.com	2018-12-06 12:22:08.439395-08
1951	cpe-69-132-98-0.carolina.res.rr.com	2018-12-06 12:38:26.516334-08
1952	cpe-69-132-98-0.carolina.res.rr.com	2018-12-06 13:17:31.003725-08
1953	cpe-69-132-98-0.carolina.res.rr.com	2018-12-07 02:07:06.802825-08
1954	cpe-69-132-98-0.carolina.res.rr.com	2018-12-07 02:57:14.605865-08
1955	cpe-69-132-98-0.carolina.res.rr.com	2018-12-07 03:18:03.187096-08
1956	cpe-69-132-98-0.carolina.res.rr.com	2018-12-07 04:01:46.552914-08
1957	cpe-69-132-98-0.carolina.res.rr.com	2018-12-07 04:20:30.278946-08
1958	cpe-69-132-98-0.carolina.res.rr.com	2018-12-07 04:41:30.436137-08
1959	cpe-69-132-98-0.carolina.res.rr.com	2018-12-07 04:56:12.890088-08
1960	cpe-69-132-98-0.carolina.res.rr.com	2018-12-07 05:21:28.10712-08
1961	cpe-69-132-98-0.carolina.res.rr.com	2018-12-07 05:23:46.39295-08
1962	cpe-69-132-98-0.carolina.res.rr.com	2018-12-07 05:37:33.542457-08
1963	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-12-07 05:55:38.642655-08
1964	190.147.153.196	2018-12-07 05:57:40.586765-08
1965	190.147.153.196	2018-12-07 06:16:39.16663-08
1966	cpe-69-132-98-0.carolina.res.rr.com	2018-12-07 06:35:07.760008-08
1967	190.147.153.196	2018-12-07 07:08:52.054254-08
1968	190.147.153.196	2018-12-07 07:10:44.671005-08
1969	190.147.153.196	2018-12-07 07:49:46.938017-08
1970	cpe-69-132-98-0.carolina.res.rr.com	2018-12-07 07:58:16.400751-08
1971	cpe-69-132-98-0.carolina.res.rr.com	2018-12-07 08:07:26.111269-08
1972	cpe-69-132-98-0.carolina.res.rr.com	2018-12-07 08:17:49.769076-08
1973	cpe-69-132-98-0.carolina.res.rr.com	2018-12-07 08:38:35.47494-08
1974	cpe-69-132-98-0.carolina.res.rr.com	2018-12-07 08:44:05.528007-08
1975	190.147.153.196	2018-12-07 08:50:44.427484-08
1976	190.147.153.196	2018-12-07 09:51:31.016646-08
1977	cpe-69-132-98-0.carolina.res.rr.com	2018-12-07 09:55:31.533828-08
1978	190.147.153.196	2018-12-07 10:11:17.780438-08
1979	190.147.153.196	2018-12-07 10:13:26.748966-08
1980	190.147.153.196	2018-12-07 10:30:34.308647-08
1981	cpe-69-132-98-0.carolina.res.rr.com	2018-12-07 10:35:53.867838-08
1982	cpe-69-132-98-0.carolina.res.rr.com	2018-12-07 10:44:16.815835-08
1983	190.147.153.196	2018-12-07 10:47:26.878465-08
1984	cpe-69-132-98-0.carolina.res.rr.com	2018-12-07 11:04:01.107764-08
1985	cpe-69-132-98-0.carolina.res.rr.com	2018-12-07 11:18:14.467598-08
1986	190.147.153.196	2018-12-07 11:26:07.830725-08
1987	190.147.153.196	2018-12-07 12:27:05.955414-08
1988	cpe-69-132-98-0.carolina.res.rr.com	2018-12-07 13:03:12.516661-08
1989	190.147.153.196	2018-12-07 13:27:40.512944-08
1990	190.147.153.196	2018-12-07 14:28:20.355485-08
1991	190.147.153.196	2018-12-07 15:11:11.617279-08
1992	190.147.153.196	2018-12-07 15:19:58.834685-08
1993	cpe-69-132-98-0.carolina.res.rr.com	2018-12-08 02:55:40.427985-08
1994	cpe-69-132-98-0.carolina.res.rr.com	2018-12-08 04:44:44.11793-08
1995	cpe-69-132-98-0.carolina.res.rr.com	2018-12-08 05:14:19.390587-08
1996	cpe-69-132-98-0.carolina.res.rr.com	2018-12-08 05:27:47.820378-08
1997	cpe-69-132-98-0.carolina.res.rr.com	2018-12-08 05:46:48.422923-08
1998	cpe-69-132-98-0.carolina.res.rr.com	2018-12-10 03:22:50.650049-08
1999	cpe-69-132-98-0.carolina.res.rr.com	2018-12-10 04:51:13.952114-08
2000	cpe-69-132-98-0.carolina.res.rr.com	2018-12-10 04:53:45.528543-08
2001	cpe-69-132-98-0.carolina.res.rr.com	2018-12-10 05:11:06.891567-08
2002	cpe-69-132-98-0.carolina.res.rr.com	2018-12-10 05:26:24.443167-08
2003	cpe-69-132-98-0.carolina.res.rr.com	2018-12-10 05:43:30.65441-08
2004	cpe-69-132-98-0.carolina.res.rr.com	2018-12-10 05:56:39.462951-08
2005	cpe-69-132-98-0.carolina.res.rr.com	2018-12-10 06:14:07.806525-08
2006	190.147.153.196	2018-12-10 06:52:00.464063-08
2007	cpe-69-132-98-0.carolina.res.rr.com	2018-12-10 06:55:00.088307-08
2008	cpe-69-132-98-0.carolina.res.rr.com	2018-12-10 07:05:40.488046-08
2009	cpe-69-132-98-0.carolina.res.rr.com	2018-12-10 07:34:21.874737-08
2010	cpe-69-132-98-0.carolina.res.rr.com	2018-12-10 08:57:48.850397-08
2011	cpe-69-132-98-0.carolina.res.rr.com	2018-12-10 09:07:49.555432-08
2012	cpe-69-132-98-0.carolina.res.rr.com	2018-12-10 09:57:23.153662-08
2013	cpe-69-132-98-0.carolina.res.rr.com	2018-12-10 09:59:55.890884-08
2014	190.147.153.196	2018-12-10 10:56:20.927888-08
2015	190.147.153.196	2018-12-10 11:01:22.931052-08
2016	190.147.153.196	2018-12-10 11:18:33.38583-08
2017	190.147.153.196	2018-12-10 11:39:24.495729-08
2018	190.147.153.196	2018-12-10 12:04:49.897882-08
2019	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-12-10 12:14:54.488034-08
2020	190.147.153.196	2018-12-10 12:28:29.507535-08
2021	cpe-69-132-98-0.carolina.res.rr.com	2018-12-11 03:30:29.778209-08
2022	190.147.153.196	2018-12-11 07:16:59.151839-08
2023	cpe-69-132-98-0.carolina.res.rr.com	2018-12-11 07:53:38.253498-08
2024	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-12-11 08:05:13.582208-08
2025	cpe-69-132-98-0.carolina.res.rr.com	2018-12-11 08:08:33.531418-08
2026	cpe-69-132-98-0.carolina.res.rr.com	2018-12-11 08:28:54.753067-08
2027	cpe-69-132-98-0.carolina.res.rr.com	2018-12-11 08:40:40.356519-08
2028	cpe-69-132-98-0.carolina.res.rr.com	2018-12-11 09:09:48.377821-08
2029	cpe-69-132-98-0.carolina.res.rr.com	2018-12-11 09:50:29.586608-08
2030	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-12-11 10:38:54.630008-08
2031	cpe-69-132-98-0.carolina.res.rr.com	2018-12-11 10:54:47.12048-08
2032	cpe-69-132-98-0.carolina.res.rr.com	2018-12-11 11:10:40.535426-08
2033	190.147.153.196	2018-12-11 11:11:25.875051-08
2034	190.147.153.196	2018-12-11 11:30:29.872856-08
2035	cpe-69-132-98-0.carolina.res.rr.com	2018-12-11 12:08:05.821852-08
2036	cpe-69-132-98-0.carolina.res.rr.com	2018-12-11 12:18:39.530304-08
2037	190.147.153.196	2018-12-11 12:50:58.427274-08
2038	190.147.153.196	2018-12-11 13:16:49.540518-08
2039	190.147.153.196	2018-12-11 13:35:29.920042-08
2040	190.147.153.196	2018-12-11 14:52:16.907868-08
2041	190.147.153.196	2018-12-11 15:01:14.644629-08
2042	190.147.153.196	2018-12-11 15:14:27.404862-08
2043	190.147.153.196	2018-12-11 15:45:08.424653-08
2044	190.147.153.196	2018-12-11 16:43:54.945343-08
2045	cpe-69-132-98-0.carolina.res.rr.com	2018-12-12 04:22:26.893833-08
2046	cpe-69-132-98-0.carolina.res.rr.com	2018-12-12 04:55:09.543611-08
2047	cpe-69-132-98-0.carolina.res.rr.com	2018-12-12 05:10:41.458976-08
2048	cpe-69-132-98-0.carolina.res.rr.com	2018-12-12 05:29:16.825869-08
2049	cpe-69-132-98-0.carolina.res.rr.com	2018-12-12 05:57:33.952444-08
2050	190.147.153.196	2018-12-12 06:24:31.524334-08
2051	cpe-69-132-98-0.carolina.res.rr.com	2018-12-12 06:28:32.06522-08
2052	cpe-69-132-98-0.carolina.res.rr.com	2018-12-12 06:52:10.951477-08
2053	cpe-69-132-98-0.carolina.res.rr.com	2018-12-12 07:16:48.170496-08
2054	190.147.153.196	2018-12-12 07:27:48.404768-08
2055	cpe-69-132-98-0.carolina.res.rr.com	2018-12-12 07:50:10.456607-08
2056	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-12-12 08:34:10.774781-08
2057	cpe-69-132-98-0.carolina.res.rr.com	2018-12-12 08:52:38.109983-08
2058	cpe-69-132-98-0.carolina.res.rr.com	2018-12-12 09:24:50.914862-08
2059	cpe-69-132-98-0.carolina.res.rr.com	2018-12-12 09:35:28.947346-08
2060	cpe-69-132-98-0.carolina.res.rr.com	2018-12-12 10:04:46.490479-08
2061	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-12-12 10:18:57.094176-08
2062	cpe-69-132-98-0.carolina.res.rr.com	2018-12-12 10:53:51.969459-08
2063	190.147.153.196	2018-12-12 10:57:21.363689-08
2064	190.147.153.196	2018-12-12 11:06:09.440359-08
2065	190.147.153.196	2018-12-12 11:36:51.556143-08
2066	cpe-69-132-98-0.carolina.res.rr.com	2018-12-12 11:43:10.90063-08
2067	cpe-69-132-98-0.carolina.res.rr.com	2018-12-12 11:56:55.392743-08
2068	cpe-69-132-98-0.carolina.res.rr.com	2018-12-12 12:06:56.537616-08
2069	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-12-12 12:08:25.890429-08
2070	190.147.153.196	2018-12-12 12:28:42.07625-08
2071	cpe-69-132-98-0.carolina.res.rr.com	2018-12-12 12:37:34.713835-08
2072	190.147.153.196	2018-12-12 12:42:25.515882-08
2073	190.147.153.196	2018-12-12 12:51:10.858643-08
2074	190.147.153.196	2018-12-12 13:09:52.976317-08
2075	190.147.153.196	2018-12-12 13:27:27.128963-08
2076	cpe-69-132-98-0.carolina.res.rr.com	2018-12-12 13:28:52.09419-08
2077	190.147.153.196	2018-12-12 13:36:16.541999-08
2078	cpe-69-132-98-0.carolina.res.rr.com	2018-12-12 13:49:23.740428-08
2079	cpe-69-132-98-0.carolina.res.rr.com	2018-12-12 13:51:55.965111-08
2080	190.147.153.196	2018-12-12 14:05:58.823217-08
2081	190.147.153.196	2018-12-12 14:08:35.510316-08
2082	190.147.153.196	2018-12-12 14:24:28.04934-08
2083	cpe-69-132-98-0.carolina.res.rr.com	2018-12-13 02:45:08.995751-08
2084	cpe-69-132-98-0.carolina.res.rr.com	2018-12-13 04:43:43.570531-08
2085	cpe-69-132-98-0.carolina.res.rr.com	2018-12-13 04:52:45.822707-08
2086	cpe-69-132-98-0.carolina.res.rr.com	2018-12-13 05:25:16.849836-08
2087	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-12-13 06:48:21.814128-08
2088	190.147.153.196	2018-12-13 07:44:55.465565-08
2089	190.147.153.196	2018-12-13 12:04:50.184587-08
2090	190.147.153.196	2018-12-13 12:13:15.468607-08
2091	190.147.153.196	2018-12-13 12:15:35.027288-08
2092	190.147.153.196	2018-12-13 12:52:45.737871-08
2093	190.147.153.196	2018-12-13 13:53:27.968052-08
2094	190.147.153.196	2018-12-13 14:54:09.419785-08
2095	cpe-69-132-98-0.carolina.res.rr.com	2018-12-14 02:36:50.755822-08
2096	cpe-69-132-98-0.carolina.res.rr.com	2018-12-14 06:38:40.941401-08
2097	cpe-69-132-98-0.carolina.res.rr.com	2018-12-14 06:47:35.159759-08
2098	cpe-69-132-98-0.carolina.res.rr.com	2018-12-14 07:01:13.583291-08
2099	cpe-69-132-98-0.carolina.res.rr.com	2018-12-14 07:16:41.79881-08
2100	cpe-69-132-98-0.carolina.res.rr.com	2018-12-14 07:32:21.594423-08
2101	190.147.153.196	2018-12-14 07:49:07.523658-08
2102	cpe-69-132-98-0.carolina.res.rr.com	2018-12-14 07:54:15.895734-08
2103	cpe-69-132-98-0.carolina.res.rr.com	2018-12-14 09:30:30.350195-08
2104	cpe-69-132-98-0.carolina.res.rr.com	2018-12-14 09:51:20.102364-08
2105	cpe-69-132-98-0.carolina.res.rr.com	2018-12-14 10:08:00.942777-08
2106	cpe-69-132-98-0.carolina.res.rr.com	2018-12-14 10:38:47.823004-08
2107	190.147.153.196	2018-12-14 11:42:58.515648-08
2108	cpe-69-132-98-0.carolina.res.rr.com	2018-12-14 11:51:06.933381-08
2109	190.147.153.196	2018-12-14 12:08:48.519041-08
2110	cpe-69-132-98-0.carolina.res.rr.com	2018-12-14 12:10:43.578134-08
2111	190.147.153.196	2018-12-14 12:33:20.832207-08
2112	cpe-69-132-98-0.carolina.res.rr.com	2018-12-14 12:36:58.453841-08
2113	190.147.153.196	2018-12-14 12:42:18.474454-08
2114	cpe-69-132-98-0.carolina.res.rr.com	2018-12-14 12:54:13.592507-08
2115	190.147.153.196	2018-12-14 13:23:09.582207-08
2116	190.147.153.196	2018-12-14 13:38:58.968925-08
2117	190.147.153.196	2018-12-14 13:58:39.305904-08
2118	190.147.153.196	2018-12-14 14:12:31.41379-08
2119	190.147.153.196	2018-12-14 14:24:35.817234-08
2120	190.147.153.196	2018-12-14 14:40:21.910048-08
2121	190.147.153.196	2018-12-14 15:01:20.659879-08
2122	cpe-69-132-98-0.carolina.res.rr.com	2018-12-17 03:32:03.601174-08
2123	cpe-69-132-98-0.carolina.res.rr.com	2018-12-17 04:26:58.838082-08
2124	cpe-69-132-98-0.carolina.res.rr.com	2018-12-17 05:06:55.398348-08
2125	cpe-69-132-98-0.carolina.res.rr.com	2018-12-17 05:12:18.495823-08
2126	cpe-69-132-98-0.carolina.res.rr.com	2018-12-17 06:00:07.643276-08
2127	cpe-69-132-98-0.carolina.res.rr.com	2018-12-17 06:13:17.916052-08
2128	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-12-17 06:58:37.747509-08
2129	cpe-69-132-98-0.carolina.res.rr.com	2018-12-17 07:18:14.837192-08
2130	190.147.153.196	2018-12-17 07:21:55.78021-08
2131	190.147.153.196	2018-12-17 07:23:48.983905-08
2132	cpe-69-132-98-0.carolina.res.rr.com	2018-12-17 07:31:36.505069-08
2133	cpe-69-132-98-0.carolina.res.rr.com	2018-12-17 07:59:30.865792-08
2134	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-12-17 08:28:15.925505-08
2135	cpe-69-132-98-0.carolina.res.rr.com	2018-12-17 09:22:13.537258-08
2136	cpe-69-132-98-0.carolina.res.rr.com	2018-12-17 09:32:54.10706-08
2137	cpe-69-132-98-0.carolina.res.rr.com	2018-12-17 09:46:10.410922-08
2138	cpe-69-132-98-0.carolina.res.rr.com	2018-12-17 10:05:58.590409-08
2139	cpe-69-132-98-0.carolina.res.rr.com	2018-12-17 10:17:52.756043-08
2140	cpe-69-132-98-0.carolina.res.rr.com	2018-12-17 10:48:25.73249-08
2141	cpe-69-132-98-0.carolina.res.rr.com	2018-12-17 11:03:48.976932-08
2142	190.147.153.196	2018-12-17 12:06:24.379617-08
2143	190.147.153.196	2018-12-17 14:38:19.824153-08
2144	190.147.153.196	2018-12-17 14:55:44.892357-08
2145	190.147.153.196	2018-12-17 15:16:23.078096-08
2146	190.147.153.196	2018-12-17 15:24:53.526115-08
2147	190.147.153.196	2018-12-17 15:40:22.553939-08
2148	190.147.153.196	2018-12-17 16:01:08.525708-08
2149	190.147.153.196	2018-12-18 08:29:51.888498-08
2150	190.147.153.196	2018-12-18 12:17:36.997249-08
2151	cpe-69-132-98-0.carolina.res.rr.com	2018-12-18 12:19:52.466405-08
2152	190.147.153.196	2018-12-18 12:36:23.770716-08
2153	190.147.153.196	2018-12-18 12:57:16.414243-08
2154	190.147.153.196	2018-12-18 13:58:06.451015-08
2155	190.147.153.196	2018-12-18 14:06:04.590004-08
2156	p5DCF9159.dip0.t-ipconnect.de	2018-12-18 14:08:09.370291-08
2157	190.147.153.196	2018-12-18 14:25:14.647371-08
2158	190.147.153.196	2018-12-18 14:53:52.395485-08
2159	190.147.153.196	2018-12-18 15:16:44.94267-08
2160	190.147.153.196	2018-12-18 15:35:45.671344-08
2161	cpe-69-132-98-0.carolina.res.rr.com	2018-12-19 03:40:38.385432-08
2162	cpe-69-132-98-0.carolina.res.rr.com	2018-12-19 04:45:36.704549-08
2163	cpe-69-132-98-0.carolina.res.rr.com	2018-12-19 05:01:28.109721-08
2164	cpe-69-132-98-0.carolina.res.rr.com	2018-12-20 03:03:04.734273-08
2659	190.147.153.196	2019-02-01 13:31:54.789544-08
2165	cpe-69-132-98-0.carolina.res.rr.com	2018-12-20 03:05:24.866577-08
2166	cpe-69-132-98-0.carolina.res.rr.com	2018-12-20 04:59:12.327456-08
2167	cpe-69-132-98-0.carolina.res.rr.com	2018-12-20 05:16:07.945286-08
2168	cpe-69-132-98-0.carolina.res.rr.com	2018-12-20 06:49:07.325836-08
2169	cpe-69-132-98-0.carolina.res.rr.com	2018-12-20 06:58:34.976754-08
2170	190.147.153.196	2018-12-20 08:38:25.650782-08
2171	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2018-12-20 11:21:50.446553-08
2172	cpe-69-132-98-0.carolina.res.rr.com	2018-12-21 02:59:55.039517-08
2173	190.147.153.196	2018-12-21 08:34:30.469286-08
2174	190.147.153.196	2018-12-21 10:37:36.356885-08
2175	190.147.153.196	2018-12-21 10:46:14.905548-08
2176	190.147.153.196	2018-12-21 10:57:04.902325-08
2177	190.147.153.196	2018-12-21 12:17:56.903059-08
2178	190.147.153.196	2018-12-21 13:18:29.572515-08
2179	190.147.153.196	2018-12-21 14:19:09.733033-08
2180	190.147.153.196	2018-12-21 14:34:44.786492-08
2181	190.147.153.196	2018-12-21 14:51:03.738501-08
2182	190.147.153.196	2018-12-21 15:30:09.02656-08
2183	112.96.115.238	2018-12-25 19:31:40.302341-08
2184	112.96.115.238	2018-12-25 19:43:58.373886-08
2185	112.96.115.238	2018-12-25 21:13:57.812552-08
2186	112.96.115.238	2018-12-25 21:28:56.360121-08
2187	cpe-69-132-98-0.carolina.res.rr.com	2018-12-27 03:09:28.76441-08
2188	cpe-69-132-98-0.carolina.res.rr.com	2018-12-27 03:54:31.042739-08
2189	cpe-69-132-98-0.carolina.res.rr.com	2018-12-27 04:11:00.071262-08
2190	cpe-69-132-98-0.carolina.res.rr.com	2018-12-27 05:44:23.709276-08
2191	cpe-69-132-98-0.carolina.res.rr.com	2018-12-27 06:01:57.896838-08
2192	cpe-69-132-98-0.carolina.res.rr.com	2018-12-27 06:28:09.470506-08
2193	cpe-69-132-98-0.carolina.res.rr.com	2018-12-27 06:40:36.990005-08
2194	cpe-69-132-98-0.carolina.res.rr.com	2018-12-27 07:02:08.803609-08
2195	cpe-69-132-98-0.carolina.res.rr.com	2018-12-27 07:20:06.793877-08
2196	cpe-69-132-98-0.carolina.res.rr.com	2018-12-27 07:41:10.053386-08
2197	cpe-69-132-98-0.carolina.res.rr.com	2018-12-27 08:08:08.847633-08
2198	cpe-69-132-98-0.carolina.res.rr.com	2018-12-27 08:38:00.598172-08
2199	cpe-69-132-98-0.carolina.res.rr.com	2018-12-27 09:14:30.819003-08
2200	cpe-69-132-98-0.carolina.res.rr.com	2018-12-27 09:33:34.507759-08
2201	cpe-69-132-98-0.carolina.res.rr.com	2018-12-27 09:54:31.301891-08
2202	cpe-69-132-98-0.carolina.res.rr.com	2018-12-27 10:13:49.052612-08
2203	cpe-69-132-98-0.carolina.res.rr.com	2018-12-27 10:29:42.753739-08
2204	cpe-69-132-98-0.carolina.res.rr.com	2018-12-27 11:00:34.473244-08
2205	cpe-69-132-98-0.carolina.res.rr.com	2018-12-27 11:23:16.798152-08
2206	cpe-69-132-98-0.carolina.res.rr.com	2018-12-27 11:35:35.306147-08
2207	cpe-69-132-98-0.carolina.res.rr.com	2018-12-27 11:45:36.52779-08
2208	cpe-69-132-98-0.carolina.res.rr.com	2018-12-27 11:59:27.808079-08
2209	cpe-69-132-98-0.carolina.res.rr.com	2018-12-27 12:22:58.477025-08
2210	cpe-69-132-98-0.carolina.res.rr.com	2018-12-27 12:31:55.754848-08
2211	cpe-69-132-98-0.carolina.res.rr.com	2018-12-27 12:46:48.298328-08
2212	cpe-69-132-98-0.carolina.res.rr.com	2018-12-27 13:05:43.557681-08
2213	cpe-69-132-98-0.carolina.res.rr.com	2018-12-27 13:21:09.364973-08
2214	cpe-69-132-98-0.carolina.res.rr.com	2018-12-28 03:12:21.912189-08
2215	cpe-69-132-98-0.carolina.res.rr.com	2018-12-28 04:55:15.835121-08
2216	cpe-69-132-98-0.carolina.res.rr.com	2018-12-28 05:04:22.394277-08
2217	cpe-69-132-98-0.carolina.res.rr.com	2018-12-28 05:34:59.865038-08
2218	cpe-69-132-98-0.carolina.res.rr.com	2018-12-28 05:46:49.734339-08
2219	cpe-69-132-98-0.carolina.res.rr.com	2018-12-28 06:02:14.851688-08
2220	cpe-69-132-98-0.carolina.res.rr.com	2018-12-28 06:48:02.46575-08
2221	cpe-69-132-98-0.carolina.res.rr.com	2018-12-28 06:53:14.794034-08
2222	cpe-69-132-98-0.carolina.res.rr.com	2018-12-28 07:31:31.395227-08
2223	cpe-69-132-98-0.carolina.res.rr.com	2018-12-28 07:42:19.359834-08
2224	cpe-69-132-98-0.carolina.res.rr.com	2018-12-28 08:19:47.837013-08
2225	cpe-69-132-98-0.carolina.res.rr.com	2018-12-28 08:40:15.560886-08
2226	cpe-69-132-98-0.carolina.res.rr.com	2018-12-28 08:49:16.789642-08
2227	cpe-69-132-98-0.carolina.res.rr.com	2018-12-28 09:04:57.312315-08
2228	cpe-69-132-98-0.carolina.res.rr.com	2018-12-28 09:20:32.753255-08
2229	cpe-69-132-98-0.carolina.res.rr.com	2018-12-28 09:51:39.810895-08
2230	cpe-69-132-98-0.carolina.res.rr.com	2018-12-28 10:03:32.32122-08
2231	cpe-69-132-98-0.carolina.res.rr.com	2018-12-28 10:06:29.35541-08
2232	cpe-69-132-98-0.carolina.res.rr.com	2018-12-28 10:14:52.792216-08
2233	cpe-69-132-98-0.carolina.res.rr.com	2018-12-28 10:30:36.025401-08
2234	cpe-69-132-98-0.carolina.res.rr.com	2018-12-28 10:51:09.810227-08
2235	cpe-69-132-98-0.carolina.res.rr.com	2018-12-28 11:12:40.522784-08
2236	cpe-69-132-98-0.carolina.res.rr.com	2018-12-28 11:22:22.561851-08
2237	cpe-69-132-98-0.carolina.res.rr.com	2018-12-28 11:39:54.020705-08
2238	cpe-69-132-98-0.carolina.res.rr.com	2018-12-28 11:59:55.789328-08
2239	cpe-69-132-98-0.carolina.res.rr.com	2018-12-29 02:17:48.317259-08
2240	cpe-69-132-98-0.carolina.res.rr.com	2018-12-29 03:32:56.474474-08
2241	cpe-69-132-98-0.carolina.res.rr.com	2018-12-29 03:40:26.835427-08
2242	cpe-69-132-98-0.carolina.res.rr.com	2018-12-29 03:54:05.467866-08
2243	cpe-69-132-98-0.carolina.res.rr.com	2018-12-29 04:08:31.301068-08
2244	cpe-69-132-98-0.carolina.res.rr.com	2018-12-31 03:12:18.918975-08
2245	cpe-69-132-98-0.carolina.res.rr.com	2018-12-31 04:55:12.442111-08
2246	cpe-69-132-98-0.carolina.res.rr.com	2018-12-31 05:20:12.737611-08
2247	cpe-69-132-98-0.carolina.res.rr.com	2018-12-31 05:39:15.815852-08
2248	cpe-69-132-98-0.carolina.res.rr.com	2018-12-31 06:00:32.438658-08
2249	cpe-69-132-98-0.carolina.res.rr.com	2018-12-31 06:09:02.736555-08
2250	cpe-69-132-98-0.carolina.res.rr.com	2018-12-31 06:13:18.540913-08
2251	cpe-69-132-98-0.carolina.res.rr.com	2018-12-31 06:15:41.884241-08
2252	cpe-69-132-98-0.carolina.res.rr.com	2018-12-31 06:31:21.35675-08
2253	cpe-69-132-98-0.carolina.res.rr.com	2018-12-31 07:13:00.846907-08
2254	cpe-69-132-98-0.carolina.res.rr.com	2018-12-31 07:23:51.557418-08
2255	cpe-69-132-98-0.carolina.res.rr.com	2018-12-31 07:47:49.023262-08
2256	cpe-69-132-98-0.carolina.res.rr.com	2018-12-31 07:55:26.328012-08
2257	cpe-69-132-98-0.carolina.res.rr.com	2019-01-02 02:53:34.065576-08
2258	cpe-69-132-98-0.carolina.res.rr.com	2019-01-02 03:15:21.866932-08
2259	cpe-69-132-98-0.carolina.res.rr.com	2019-01-02 03:24:04.553272-08
2260	cpe-69-132-98-0.carolina.res.rr.com	2019-01-02 03:45:09.480167-08
2261	cpe-69-132-98-0.carolina.res.rr.com	2019-01-02 04:22:18.458146-08
2262	cpe-69-132-98-0.carolina.res.rr.com	2019-01-02 04:48:37.709583-08
2263	cpe-69-132-98-0.carolina.res.rr.com	2019-01-02 04:58:56.34109-08
2264	cpe-69-132-98-0.carolina.res.rr.com	2019-01-02 05:05:36.038364-08
2265	cpe-69-132-98-0.carolina.res.rr.com	2019-01-02 05:37:19.099353-08
2266	cpe-69-132-98-0.carolina.res.rr.com	2019-01-02 05:55:05.742037-08
2267	cpe-69-132-98-0.carolina.res.rr.com	2019-01-02 06:16:09.803483-08
2268	cpe-69-132-98-0.carolina.res.rr.com	2019-01-02 06:22:20.300229-08
2269	cpe-69-132-98-0.carolina.res.rr.com	2019-01-02 06:46:58.742188-08
2270	cpe-69-132-98-0.carolina.res.rr.com	2019-01-02 06:53:09.099087-08
2271	cpe-69-132-98-0.carolina.res.rr.com	2019-01-02 07:27:35.354669-08
2272	cpe-69-132-98-0.carolina.res.rr.com	2019-01-02 09:02:36.891297-08
2273	cpe-69-132-98-0.carolina.res.rr.com	2019-01-02 09:21:20.474374-08
2274	cpe-69-132-98-0.carolina.res.rr.com	2019-01-02 09:26:13.35573-08
2275	cpe-69-132-98-0.carolina.res.rr.com	2019-01-02 09:39:44.593128-08
2276	cpe-69-132-98-0.carolina.res.rr.com	2019-01-02 09:57:06.904461-08
2277	cpe-69-132-98-0.carolina.res.rr.com	2019-01-02 10:15:50.029297-08
2278	cpe-69-132-98-0.carolina.res.rr.com	2019-01-02 10:48:09.580382-08
2279	cpe-69-132-98-0.carolina.res.rr.com	2019-01-02 11:13:56.754885-08
2280	cpe-69-132-98-0.carolina.res.rr.com	2019-01-02 11:29:13.05219-08
2281	cpe-69-132-98-0.carolina.res.rr.com	2019-01-03 02:11:42.101337-08
2282	cpe-69-132-98-0.carolina.res.rr.com	2019-01-03 02:50:11.299062-08
2283	cpe-69-132-98-0.carolina.res.rr.com	2019-01-03 03:10:47.400548-08
2284	cpe-69-132-98-0.carolina.res.rr.com	2019-01-03 03:39:02.860967-08
2285	cpe-69-132-98-0.carolina.res.rr.com	2019-01-03 04:55:14.30115-08
2286	cpe-69-132-98-0.carolina.res.rr.com	2019-01-03 05:08:11.915423-08
2287	cpe-69-132-98-0.carolina.res.rr.com	2019-01-04 03:54:37.816234-08
2288	cpe-69-132-98-0.carolina.res.rr.com	2019-01-04 05:19:43.813983-08
2289	cpe-69-132-98-0.carolina.res.rr.com	2019-01-04 05:28:26.337829-08
2290	cpe-69-132-98-0.carolina.res.rr.com	2019-01-04 06:16:26.766382-08
2291	cpe-69-132-98-0.carolina.res.rr.com	2019-01-04 06:26:23.257876-08
2292	cpe-69-132-98-0.carolina.res.rr.com	2019-01-04 07:02:26.704264-08
2293	cpe-69-132-98-0.carolina.res.rr.com	2019-01-04 07:13:00.707106-08
2294	cpe-69-132-98-0.carolina.res.rr.com	2019-01-04 07:26:37.87069-08
2295	cpe-69-132-98-0.carolina.res.rr.com	2019-01-04 08:01:42.300685-08
2296	cpe-69-132-98-0.carolina.res.rr.com	2019-01-04 08:09:28.022687-08
2297	cpe-69-132-98-0.carolina.res.rr.com	2019-01-04 08:11:44.21101-08
2298	cpe-69-132-98-0.carolina.res.rr.com	2019-01-04 09:00:36.391321-08
2299	cpe-69-132-98-0.carolina.res.rr.com	2019-01-04 09:14:02.848352-08
2300	cpe-69-132-98-0.carolina.res.rr.com	2019-01-04 09:29:03.832776-08
2301	cpe-69-132-98-0.carolina.res.rr.com	2019-01-04 09:45:46.33672-08
2302	cpe-69-132-98-0.carolina.res.rr.com	2019-01-04 10:35:21.502576-08
2303	cpe-69-132-98-0.carolina.res.rr.com	2019-01-04 10:49:36.320282-08
2304	cpe-69-132-98-0.carolina.res.rr.com	2019-01-04 11:05:20.008119-08
2305	cpe-69-132-98-0.carolina.res.rr.com	2019-01-04 11:15:55.546117-08
2306	cpe-69-132-98-0.carolina.res.rr.com	2019-01-04 11:58:27.793234-08
2307	cpe-69-132-98-0.carolina.res.rr.com	2019-01-04 12:09:41.326205-08
2308	cpe-69-132-98-0.carolina.res.rr.com	2019-01-04 12:22:06.460857-08
2309	cpe-69-132-98-0.carolina.res.rr.com	2019-01-04 13:11:16.478018-08
2310	cpe-69-132-98-0.carolina.res.rr.com	2019-01-04 13:18:03.90203-08
2311	cpe-69-132-98-0.carolina.res.rr.com	2019-01-05 03:56:40.313716-08
2312	ip68-100-100-132.dc.dc.cox.net	2019-01-05 16:48:24.808289-08
2313	cpe-69-132-98-0.carolina.res.rr.com	2019-01-07 03:51:24.846415-08
2314	cpe-69-132-98-0.carolina.res.rr.com	2019-01-07 04:11:34.301598-08
2315	cpe-69-132-98-0.carolina.res.rr.com	2019-01-07 04:25:52.18589-08
2316	cpe-69-132-98-0.carolina.res.rr.com	2019-01-07 05:15:37.163179-08
2317	cpe-69-132-98-0.carolina.res.rr.com	2019-01-07 05:29:03.516142-08
2318	cpe-69-132-98-0.carolina.res.rr.com	2019-01-07 05:41:13.844332-08
2319	cpe-69-132-98-0.carolina.res.rr.com	2019-01-07 06:05:17.144283-08
2320	cpe-69-132-98-0.carolina.res.rr.com	2019-01-07 06:12:36.355073-08
2321	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2019-01-07 07:33:18.860922-08
2322	cpe-69-132-98-0.carolina.res.rr.com	2019-01-08 04:17:50.467489-08
2323	190.147.153.196	2019-01-08 07:35:38.25104-08
2324	190.147.153.196	2019-01-08 07:37:03.119503-08
2325	190.147.153.196	2019-01-08 09:26:53.462954-08
2326	190.147.153.196	2019-01-08 09:29:11.824124-08
2327	190.147.153.196	2019-01-08 09:42:44.916118-08
2328	190.147.153.196	2019-01-08 10:03:37.165001-08
2329	190.147.153.196	2019-01-08 10:23:02.410046-08
2330	190.147.153.196	2019-01-08 10:48:04.793943-08
2331	190.147.153.196	2019-01-08 11:00:56.299128-08
2332	190.147.153.196	2019-01-08 11:16:42.12876-08
2333	190.147.153.196	2019-01-08 11:37:31.170095-08
2334	190.147.153.196	2019-01-08 12:38:11.328594-08
2335	190.147.153.196	2019-01-08 13:17:18.740423-08
2336	190.147.153.196	2019-01-08 13:32:52.133888-08
2337	190.147.153.196	2019-01-08 14:25:02.657464-08
2338	190.147.153.196	2019-01-08 14:45:38.079343-08
2339	190.147.153.196	2019-01-08 15:46:18.463494-08
2340	cpe-69-132-98-0.carolina.res.rr.com	2019-01-09 12:46:20.538717-08
2341	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2019-01-09 13:07:40.599244-08
2342	190.147.153.196	2019-01-09 13:50:35.036977-08
2343	cpe-69-132-98-0.carolina.res.rr.com	2019-01-10 03:33:13.467408-08
2344	cpe-69-132-98-0.carolina.res.rr.com	2019-01-10 04:32:05.202098-08
2345	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2019-01-10 05:50:57.030323-08
2346	190.147.153.196	2019-01-10 07:25:23.124836-08
2347	190.147.153.196	2019-01-10 11:25:35.309558-08
2348	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2019-01-10 11:26:01.813639-08
2349	190.147.153.196	2019-01-10 11:34:31.124251-08
2350	190.147.153.196	2019-01-10 11:47:44.793337-08
2351	190.147.153.196	2019-01-10 12:16:56.300998-08
2352	190.147.153.196	2019-01-10 12:32:40.124797-08
2353	190.147.153.196	2019-01-10 13:05:44.018737-08
2354	190.147.153.196	2019-01-10 13:19:07.61215-08
2355	190.147.153.196	2019-01-10 13:58:05.90996-08
2356	190.147.153.196	2019-01-10 14:58:50.13545-08
2357	190.147.153.196	2019-01-10 15:59:41.919401-08
2358	190.147.153.196	2019-01-11 10:32:58.446643-08
2359	cpe-69-132-98-0.carolina.res.rr.com	2019-01-11 12:52:35.540714-08
2360	cpe-69-132-98-0.carolina.res.rr.com	2019-01-11 13:38:28.823881-08
2361	cpe-69-132-98-0.carolina.res.rr.com	2019-01-11 13:40:11.788876-08
2362	cpe-69-132-98-0.carolina.res.rr.com	2019-01-11 14:12:21.736592-08
2363	cpe-69-132-98-0.carolina.res.rr.com	2019-01-11 14:14:44.468704-08
2364	190.147.153.196	2019-01-11 14:27:40.8663-08
2365	cpe-69-132-98-0.carolina.res.rr.com	2019-01-11 14:31:31.371006-08
2366	cpe-69-132-98-0.carolina.res.rr.com	2019-01-12 01:49:59.027457-08
2367	cpe-69-132-98-0.carolina.res.rr.com	2019-01-12 02:00:40.944267-08
2368	cpe-69-132-98-0.carolina.res.rr.com	2019-01-12 02:28:31.220643-08
2369	p5DCF9051.dip0.t-ipconnect.de	2019-01-13 01:00:50.800119-08
2370	cpe-69-132-98-0.carolina.res.rr.com	2019-01-14 03:12:23.255954-08
2371	cpe-69-132-98-0.carolina.res.rr.com	2019-01-14 03:45:16.164342-08
2372	cpe-69-132-98-0.carolina.res.rr.com	2019-01-14 04:00:49.311739-08
2373	cpe-69-132-98-0.carolina.res.rr.com	2019-01-14 04:55:12.301897-08
2374	cpe-69-132-98-0.carolina.res.rr.com	2019-01-14 05:46:05.945378-08
2375	cpe-69-132-98-0.carolina.res.rr.com	2019-01-14 06:03:27.325744-08
2376	cpe-69-132-98-0.carolina.res.rr.com	2019-01-14 06:16:05.291393-08
2377	190.147.153.196	2019-01-14 06:32:32.162966-08
2378	cpe-69-132-98-0.carolina.res.rr.com	2019-01-14 06:54:56.774642-08
2379	cpe-69-132-98-0.carolina.res.rr.com	2019-01-14 07:02:50.36746-08
2380	190.147.153.196	2019-01-14 07:05:16.409012-08
2381	cpe-69-132-98-0.carolina.res.rr.com	2019-01-14 07:18:44.468692-08
2382	190.147.153.196	2019-01-14 07:24:05.819925-08
2383	cpe-69-132-98-0.carolina.res.rr.com	2019-01-14 07:33:01.206985-08
2384	190.147.153.196	2019-01-14 07:44:46.254315-08
2385	190.147.153.196	2019-01-14 08:34:09.590756-08
2386	cpe-69-132-98-0.carolina.res.rr.com	2019-01-14 08:44:29.535052-08
2387	190.147.153.196	2019-01-14 08:49:17.729549-08
2388	cpe-69-132-98-0.carolina.res.rr.com	2019-01-14 08:49:42.741489-08
2389	cpe-69-132-98-0.carolina.res.rr.com	2019-01-14 09:07:47.350861-08
2390	190.147.153.196	2019-01-14 09:20:23.805169-08
2391	cpe-69-132-98-0.carolina.res.rr.com	2019-01-14 09:21:36.120276-08
2392	cpe-69-132-98-0.carolina.res.rr.com	2019-01-14 09:58:20.991133-08
2393	190.147.153.196	2019-01-14 10:20:58.047151-08
2394	cpe-69-132-98-0.carolina.res.rr.com	2019-01-14 10:31:32.396407-08
2395	cpe-69-132-98-0.carolina.res.rr.com	2019-01-14 10:42:01.122067-08
2396	cpe-69-132-98-0.carolina.res.rr.com	2019-01-14 10:50:49.835986-08
2397	cpe-69-132-98-0.carolina.res.rr.com	2019-01-14 10:53:19.374026-08
2398	190.147.153.196	2019-01-14 11:07:34.878692-08
2399	cpe-69-132-98-0.carolina.res.rr.com	2019-01-14 11:07:54.017616-08
2400	190.147.153.196	2019-01-14 11:23:28.318283-08
2401	cpe-69-132-98-0.carolina.res.rr.com	2019-01-14 11:34:28.504196-08
2402	190.147.153.196	2019-01-14 11:52:09.462765-08
2403	cpe-69-132-98-0.carolina.res.rr.com	2019-01-14 11:53:34.615215-08
2404	190.147.153.196	2019-01-14 12:11:07.023747-08
2405	cpe-69-132-98-0.carolina.res.rr.com	2019-01-14 12:40:52.063351-08
2406	190.147.153.196	2019-01-14 14:04:24.301787-08
2407	190.147.153.196	2019-01-14 14:13:15.354827-08
2408	190.147.153.196	2019-01-14 14:32:05.475024-08
2409	190.147.153.196	2019-01-14 14:40:41.348906-08
2410	190.147.153.196	2019-01-14 15:16:18.894752-08
2411	190.147.153.196	2019-01-14 15:25:51.125278-08
2412	190.147.153.196	2019-01-14 15:56:28.204959-08
2413	190.147.153.196	2019-01-14 16:24:08.854504-08
2414	190.147.153.196	2019-01-15 11:42:06.236251-08
2415	cpe-69-132-97-204.carolina.res.rr.com	2019-01-15 14:12:12.13309-08
2416	cpe-2606-A000-6B84-3DF0-19FD-3514-64EC-966B.dyn6.twc.com	2019-01-16 03:23:38.470606-08
2417	cpe-69-132-97-204.carolina.res.rr.com	2019-01-16 04:53:54.300483-08
2418	cpe-69-132-97-204.carolina.res.rr.com	2019-01-16 05:02:53.550618-08
2419	cpe-69-132-97-204.carolina.res.rr.com	2019-01-16 05:17:23.169906-08
2420	cpe-69-132-97-204.carolina.res.rr.com	2019-01-16 05:42:32.310814-08
2421	cpe-69-132-97-204.carolina.res.rr.com	2019-01-16 05:48:41.611516-08
2422	cpe-69-132-97-204.carolina.res.rr.com	2019-01-16 06:04:33.072167-08
2423	cpe-69-132-97-204.carolina.res.rr.com	2019-01-16 06:35:34.372335-08
2424	cpe-69-132-97-204.carolina.res.rr.com	2019-01-16 07:06:17.257666-08
2425	cpe-69-132-97-204.carolina.res.rr.com	2019-01-16 07:30:50.925699-08
2426	190.147.153.196	2019-01-16 08:47:39.139732-08
2427	cpe-69-132-97-204.carolina.res.rr.com	2019-01-16 09:04:20.215355-08
2428	cpe-69-132-97-204.carolina.res.rr.com	2019-01-16 09:14:55.362432-08
2429	cpe-69-132-97-204.carolina.res.rr.com	2019-01-16 09:26:12.473999-08
2430	cpe-69-132-97-204.carolina.res.rr.com	2019-01-16 10:00:51.730764-08
2431	cpe-69-132-97-204.carolina.res.rr.com	2019-01-16 10:18:36.053134-08
2432	cpe-69-132-97-204.carolina.res.rr.com	2019-01-16 10:27:16.785008-08
2433	190.147.153.196	2019-01-16 11:00:25.858109-08
2434	cpe-69-132-97-204.carolina.res.rr.com	2019-01-16 11:06:04.118575-08
2435	cpe-69-132-97-204.carolina.res.rr.com	2019-01-16 11:14:50.872191-08
2436	190.147.153.196	2019-01-16 11:19:12.832565-08
2437	190.147.153.196	2019-01-16 11:40:08.284013-08
2438	cpe-69-132-97-204.carolina.res.rr.com	2019-01-16 11:43:47.82622-08
2439	cpe-2606-A000-6B84-3DF0-49A4-24D5-D12B-FA3B.dyn6.twc.com	2019-01-16 12:31:24.248578-08
2440	190.147.153.196	2019-01-16 12:40:39.230277-08
2441	190.147.153.196	2019-01-16 13:32:30.147547-08
2442	190.147.153.196	2019-01-16 16:32:51.228977-08
2443	190.147.153.196	2019-01-16 16:55:49.044613-08
2444	cpe-2606-A000-6B84-3DF0-EDBF-A344-4EFD-CA32.dyn6.twc.com	2019-01-17 03:31:06.19771-08
2445	cpe-2606-A000-6B84-3DF0-6020-77AF-9FD7-CC4.dyn6.twc.com	2019-01-17 04:48:36.207588-08
2446	cpe-2606-A000-6B84-3DF0-6020-77AF-9FD7-CC4.dyn6.twc.com	2019-01-17 04:56:48.744962-08
2447	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2019-01-17 06:45:17.506164-08
2448	cpe-2606-A000-6B84-3DF0-6020-77AF-9FD7-CC4.dyn6.twc.com	2019-01-17 07:19:34.730837-08
2449	190.147.153.196	2019-01-17 07:49:58.481116-08
2450	cpe-2606-A000-6B84-3DF0-6020-77AF-9FD7-CC4.dyn6.twc.com	2019-01-17 11:00:14.090729-08
2451	190.147.153.196	2019-01-17 11:28:59.251065-08
2452	cpe-2606-A000-6B84-3DF0-6020-77AF-9FD7-CC4.dyn6.twc.com	2019-01-17 11:37:53.730712-08
2453	190.147.153.196	2019-01-17 11:52:23.390563-08
2454	190.147.153.196	2019-01-17 12:13:07.361902-08
2455	190.147.153.196	2019-01-17 12:42:13.341123-08
2456	190.147.153.196	2019-01-17 12:50:55.734865-08
2457	190.147.153.196	2019-01-17 13:01:52.211205-08
2458	cpe-2606-A000-6B84-3DF0-6020-77AF-9FD7-CC4.dyn6.twc.com	2019-01-17 13:06:06.71079-08
2459	190.147.153.196	2019-01-17 13:22:29.444902-08
2460	190.147.153.196	2019-01-17 14:23:17.360431-08
2461	190.147.153.196	2019-01-17 14:34:42.126454-08
2462	190.147.153.196	2019-01-17 15:40:38.320293-08
2463	190.147.153.196	2019-01-17 15:49:36.572697-08
2464	190.147.153.196	2019-01-17 16:04:24.593353-08
2465	190.147.153.196	2019-01-17 16:08:23.255786-08
2466	cpe-2606-A000-6B84-3DF0-9933-F784-E241-D9F0.dyn6.twc.com	2019-01-18 02:28:40.359887-08
2467	cpe-2606-A000-6B84-3DF0-9933-F784-E241-D9F0.dyn6.twc.com	2019-01-18 04:55:16.719029-08
2468	cpe-2606-A000-6B84-3DF0-9933-F784-E241-D9F0.dyn6.twc.com	2019-01-18 05:14:11.023188-08
2469	cpe-2606-A000-6B84-3DF0-9933-F784-E241-D9F0.dyn6.twc.com	2019-01-18 06:18:16.024152-08
2470	cpe-2606-A000-6B84-3DF0-9933-F784-E241-D9F0.dyn6.twc.com	2019-01-18 06:29:36.810666-08
2471	cpe-2606-A000-6B84-3DF0-9933-F784-E241-D9F0.dyn6.twc.com	2019-01-18 07:08:37.947885-08
2472	190.147.153.196	2019-01-18 07:44:35.209808-08
2473	190.147.153.196	2019-01-18 12:36:24.622667-08
2474	190.147.153.196	2019-01-18 15:56:57.615654-08
2475	190.147.153.196	2019-01-18 16:08:47.817589-08
2476	190.147.153.196	2019-01-18 16:30:32.072009-08
2477	190.147.153.196	2019-01-18 16:39:29.087956-08
2479	cpe-2606-A000-6B84-3DF0-C55B-1313-16A6-720B.dyn6.twc.com	2019-01-21 03:18:37.95639-08
2480	cpe-2606-A000-6B84-3DF0-C55B-1313-16A6-720B.dyn6.twc.com	2019-01-21 04:55:14.720162-08
2481	cpe-2606-A000-6B84-3DF0-C55B-1313-16A6-720B.dyn6.twc.com	2019-01-21 05:05:05.063128-08
2482	cpe-2606-A000-6B84-3DF0-C55B-1313-16A6-720B.dyn6.twc.com	2019-01-21 05:20:37.254418-08
2483	cpe-2606-A000-6B84-3DF0-C55B-1313-16A6-720B.dyn6.twc.com	2019-01-21 05:44:50.795101-08
2484	cpe-2606-A000-6B84-3DF0-C55B-1313-16A6-720B.dyn6.twc.com	2019-01-21 05:53:52.158524-08
2485	cpe-2606-A000-6B84-3DF0-C55B-1313-16A6-720B.dyn6.twc.com	2019-01-21 06:07:38.801766-08
2486	cpe-2606-A000-6B84-3DF0-C55B-1313-16A6-720B.dyn6.twc.com	2019-01-21 06:34:32.815327-08
2487	cpe-2606-A000-6B84-3DF0-C55B-1313-16A6-720B.dyn6.twc.com	2019-01-21 06:37:07.216392-08
2488	cpe-2606-A000-6B84-3DF0-C55B-1313-16A6-720B.dyn6.twc.com	2019-01-21 07:12:30.025976-08
2489	cpe-2606-A000-6B84-3DF0-C55B-1313-16A6-720B.dyn6.twc.com	2019-01-21 09:02:13.361427-08
2490	cpe-2606-A000-6B84-3DF0-C55B-1313-16A6-720B.dyn6.twc.com	2019-01-21 09:12:53.037572-08
2491	cpe-2606-A000-6B84-3DF0-C55B-1313-16A6-720B.dyn6.twc.com	2019-01-21 09:49:01.83206-08
2492	cpe-2606-A000-6B84-3DF0-C55B-1313-16A6-720B.dyn6.twc.com	2019-01-21 09:56:19.708671-08
2493	cpe-2606-A000-6B84-3DF0-C55B-1313-16A6-720B.dyn6.twc.com	2019-01-21 10:11:11.85659-08
2494	cpe-2606-A000-6B84-3DF0-C55B-1313-16A6-720B.dyn6.twc.com	2019-01-21 10:29:59.210044-08
2495	cpe-2606-A000-6B84-3DF0-C55B-1313-16A6-720B.dyn6.twc.com	2019-01-21 11:40:30.77434-08
2496	cpe-2606-A000-6B84-3DF0-C55B-1313-16A6-720B.dyn6.twc.com	2019-01-21 11:42:40.027151-08
2497	cpe-2606-A000-6B84-3DF0-C55B-1313-16A6-720B.dyn6.twc.com	2019-01-21 11:58:34.220921-08
2498	cpe-2606-A000-6B84-3DF0-18EC-C14-2372-682D.dyn6.twc.com	2019-01-22 03:36:27.001489-08
2499	190.147.153.196	2019-01-22 06:53:10.790001-08
2500	190.147.153.196	2019-01-22 12:16:32.770606-08
2501	190.147.153.196	2019-01-22 13:17:29.023034-08
2502	190.147.153.196	2019-01-22 14:18:02.385846-08
2503	190.147.153.196	2019-01-22 15:18:59.52374-08
2504	190.147.153.196	2019-01-22 15:38:54.465161-08
2505	190.147.153.196	2019-01-22 15:50:00.362287-08
2506	190.147.153.196	2019-01-22 16:05:35.924174-08
2507	cpe-2606-A000-6B84-3DF0-804A-29CA-BE1C-8648.dyn6.twc.com	2019-01-23 03:37:49.034247-08
2508	cpe-69-132-97-204.carolina.res.rr.com	2019-01-23 04:55:10.618576-08
2509	cpe-2606-A000-6B84-3DF0-804A-29CA-BE1C-8648.dyn6.twc.com	2019-01-23 05:12:25.616405-08
2510	cpe-2606-A000-6B84-3DF0-804A-29CA-BE1C-8648.dyn6.twc.com	2019-01-23 05:21:09.849418-08
2511	cpe-2606-A000-6B84-3DF0-804A-29CA-BE1C-8648.dyn6.twc.com	2019-01-23 05:38:51.92368-08
2512	cpe-2606-A000-6B84-3DF0-804A-29CA-BE1C-8648.dyn6.twc.com	2019-01-23 06:12:03.228877-08
2513	cpe-2606-A000-6B84-3DF0-804A-29CA-BE1C-8648.dyn6.twc.com	2019-01-23 06:22:55.616123-08
2514	190.147.153.196	2019-01-23 07:00:19.708183-08
2515	cpe-2606-A000-6B84-3DF0-804A-29CA-BE1C-8648.dyn6.twc.com	2019-01-23 07:09:41.072884-08
2516	cpe-2606-A000-6B84-3DF0-804A-29CA-BE1C-8648.dyn6.twc.com	2019-01-23 07:24:56.772487-08
2517	cpe-69-132-97-204.carolina.res.rr.com	2019-01-23 08:36:03.475196-08
2518	cpe-2606-A000-6B84-3DF0-804A-29CA-BE1C-8648.dyn6.twc.com	2019-01-23 08:46:50.618144-08
2519	cpe-2606-A000-6B84-3DF0-804A-29CA-BE1C-8648.dyn6.twc.com	2019-01-23 10:07:36.79881-08
2520	cpe-2606-A000-6B84-3DF0-804A-29CA-BE1C-8648.dyn6.twc.com	2019-01-23 10:12:39.732869-08
2521	190.147.153.196	2019-01-23 10:14:53.468894-08
2522	190.147.153.196	2019-01-23 10:23:52.739004-08
2523	cpe-2606-A000-6B84-3DF0-804A-29CA-BE1C-8648.dyn6.twc.com	2019-01-23 10:25:50.636715-08
2524	190.147.153.196	2019-01-23 10:40:25.429212-08
2525	190.147.153.196	2019-01-23 10:59:31.423919-08
2526	cpe-2606-A000-6B84-3DF0-804A-29CA-BE1C-8648.dyn6.twc.com	2019-01-23 11:09:27.238971-08
2527	190.147.153.196	2019-01-23 11:13:08.115532-08
2528	cpe-2606-A000-6B84-3DF0-804A-29CA-BE1C-8648.dyn6.twc.com	2019-01-23 11:20:00.629822-08
2529	190.147.153.196	2019-01-23 11:26:24.488029-08
2530	cpe-2606-A000-6B84-3DF0-804A-29CA-BE1C-8648.dyn6.twc.com	2019-01-23 11:48:24.824018-08
2531	190.147.153.196	2019-01-23 11:58:10.981071-08
2532	cpe-2606-A000-6B84-3DF0-804A-29CA-BE1C-8648.dyn6.twc.com	2019-01-23 11:58:29.250409-08
2533	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2019-01-23 12:05:55.381523-08
2534	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2019-01-23 12:52:34.690184-08
2535	cpe-2606-A000-6B84-3DF0-5826-BD92-C806-573F.dyn6.twc.com	2019-01-24 03:22:28.424853-08
2536	cpe-2606-A000-6B84-3DF0-5826-BD92-C806-573F.dyn6.twc.com	2019-01-24 04:55:11.717417-08
2537	cpe-2606-A000-6B84-3DF0-5826-BD92-C806-573F.dyn6.twc.com	2019-01-24 05:00:08.809053-08
2538	cpe-2606-A000-6B84-3DF0-5826-BD92-C806-573F.dyn6.twc.com	2019-01-24 07:07:25.618852-08
2539	190.147.153.196	2019-01-24 07:09:26.663481-08
2540	cpe-2606-A000-6B84-3DF0-5826-BD92-C806-573F.dyn6.twc.com	2019-01-24 07:30:11.217675-08
2541	190.147.153.196	2019-01-24 11:12:23.885231-08
2542	cpe-2606-A000-6B84-3DF0-5826-BD92-C806-573F.dyn6.twc.com	2019-01-24 12:23:45.206106-08
2543	cpe-2606-A000-6B84-3DF0-5826-BD92-C806-573F.dyn6.twc.com	2019-01-24 12:34:40.700154-08
2544	190.147.153.196	2019-01-25 06:36:47.614911-08
2545	cpe-2606-A000-6B84-3DF0-E9BE-23D6-E531-725E.dyn6.twc.com	2019-01-25 06:56:59.710785-08
2546	cpe-2606-A000-6B84-3DF0-E9BE-23D6-E531-725E.dyn6.twc.com	2019-01-25 07:15:45.632764-08
2547	cpe-2606-A000-6B84-3DF0-E9BE-23D6-E531-725E.dyn6.twc.com	2019-01-25 08:08:30.646908-08
2548	cpe-2606-A000-6B84-3DF0-E9BE-23D6-E531-725E.dyn6.twc.com	2019-01-25 09:01:05.232759-08
2549	cpe-2606-A000-6B84-3DF0-E9BE-23D6-E531-725E.dyn6.twc.com	2019-01-25 09:40:22.868383-08
2550	cpe-2606-A000-6B84-3DF0-E9BE-23D6-E531-725E.dyn6.twc.com	2019-01-25 09:54:15.616763-08
2551	cpe-2606-A000-6B84-3DF0-E9BE-23D6-E531-725E.dyn6.twc.com	2019-01-25 10:26:18.217828-08
2552	cpe-2606-A000-6B84-3DF0-E9BE-23D6-E531-725E.dyn6.twc.com	2019-01-25 10:39:59.014218-08
2553	cpe-2606-A000-6B84-3DF0-E9BE-23D6-E531-725E.dyn6.twc.com	2019-01-25 11:10:40.615714-08
2554	cpe-2606-A000-6B84-3DF0-E9BE-23D6-E531-725E.dyn6.twc.com	2019-01-25 11:27:06.708774-08
2555	190.147.153.196	2019-01-25 11:28:58.810928-08
2556	cpe-2606-A000-6B84-3DF0-E9BE-23D6-E531-725E.dyn6.twc.com	2019-01-25 11:59:56.012-08
2557	p5DCF9051.dip0.t-ipconnect.de	2019-01-26 09:48:37.655268-08
2558	cpe-2606-A000-6B84-3DF0-8DDD-82A-D512-9A90.dyn6.twc.com	2019-01-28 03:23:00.963358-08
2559	cpe-2606-A000-6B84-3DF0-8DDD-82A-D512-9A90.dyn6.twc.com	2019-01-28 04:35:33.947135-08
2560	cpe-2606-A000-6B84-3DF0-8DDD-82A-D512-9A90.dyn6.twc.com	2019-01-28 04:44:40.235888-08
2561	cpe-2606-A000-6B84-3DF0-8DDD-82A-D512-9A90.dyn6.twc.com	2019-01-28 04:57:42.773318-08
2562	cpe-2606-A000-6B84-3DF0-8DDD-82A-D512-9A90.dyn6.twc.com	2019-01-28 05:35:31.706216-08
2563	cpe-2606-A000-6B84-3DF0-8DDD-82A-D512-9A90.dyn6.twc.com	2019-01-28 05:46:25.678315-08
2660	190.147.153.196	2019-02-01 13:42:35.626551-08
2564	cpe-2606-A000-6B84-3DF0-8DDD-82A-D512-9A90.dyn6.twc.com	2019-01-28 05:58:36.769611-08
2565	cpe-2606-A000-6B84-3DF0-8DDD-82A-D512-9A90.dyn6.twc.com	2019-01-28 06:17:21.206879-08
2566	cpe-2606-A000-6B84-3DF0-8DDD-82A-D512-9A90.dyn6.twc.com	2019-01-28 06:36:57.712154-08
2567	cpe-2606-A000-6B84-3DF0-8DDD-82A-D512-9A90.dyn6.twc.com	2019-01-28 06:50:58.019709-08
2568	cpe-2606-A000-6B84-3DF0-8DDD-82A-D512-9A90.dyn6.twc.com	2019-01-28 07:01:08.836972-08
2569	190.147.153.196	2019-01-28 07:02:13.47642-08
2570	cpe-2606-A000-6B84-3DF0-8DDD-82A-D512-9A90.dyn6.twc.com	2019-01-28 07:16:45.616405-08
2571	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2019-01-28 07:19:30.6332-08
2572	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2019-01-28 07:48:36.779853-08
2573	cpe-2606-A000-6B84-3DF0-8DDD-82A-D512-9A90.dyn6.twc.com	2019-01-28 07:59:37.723317-08
2574	cpe-2606-A000-6B84-3DF0-8DDD-82A-D512-9A90.dyn6.twc.com	2019-01-28 09:01:41.635601-08
2575	cpe-2606-A000-6B84-3DF0-8DDD-82A-D512-9A90.dyn6.twc.com	2019-01-28 09:48:57.237741-08
2576	cpe-2606-A000-6B84-3DF0-8DDD-82A-D512-9A90.dyn6.twc.com	2019-01-28 10:04:56.787208-08
2577	cpe-2606-A000-6B84-3DF0-8DDD-82A-D512-9A90.dyn6.twc.com	2019-01-28 10:36:45.719672-08
2578	190.147.153.196	2019-01-28 11:29:59.497044-08
2579	cpe-2606-A000-6B84-3DF0-E4DF-D1B0-C68C-E32E.dyn6.twc.com	2019-01-28 11:31:52.882502-08
2580	cpe-2606-A000-6B84-3DF0-E4DF-D1B0-C68C-E32E.dyn6.twc.com	2019-01-28 11:37:13.242256-08
2581	190.147.153.196	2019-01-28 11:39:02.90443-08
2582	190.147.153.196	2019-01-28 12:09:42.361785-08
2583	cpe-2606-A000-6B84-3DF0-E4DF-D1B0-C68C-E32E.dyn6.twc.com	2019-01-28 12:20:36.666954-08
2584	cpe-2606-A000-6B84-3DF0-E4DF-D1B0-C68C-E32E.dyn6.twc.com	2019-01-28 12:32:54.330507-08
2585	190.147.153.196	2019-01-28 13:10:15.619947-08
2586	190.147.153.196	2019-01-28 13:22:44.301579-08
2587	190.147.153.196	2019-01-28 13:41:42.808015-08
2588	190.147.153.196	2019-01-28 14:02:36.731571-08
2589	190.147.153.196	2019-01-28 15:03:42.324938-08
2590	190.147.153.196	2019-01-28 15:54:18.467293-08
2591	cpe-2606-A000-6B84-3DF0-7D71-ADFA-C739-6775.dyn6.twc.com	2019-01-29 03:20:43.614677-08
2592	cpe-2606-A000-6B84-3DF0-7D71-ADFA-C739-6775.dyn6.twc.com	2019-01-29 04:09:51.616325-08
2593	cpe-2606-A000-6B84-3DF0-7D71-ADFA-C739-6775.dyn6.twc.com	2019-01-29 04:24:19.769196-08
2594	cpe-2606-A000-6B84-3DF0-7D71-ADFA-C739-6775.dyn6.twc.com	2019-01-29 04:49:54.106617-08
2595	cpe-2606-A000-6B84-3DF0-7D71-ADFA-C739-6775.dyn6.twc.com	2019-01-29 04:58:35.221686-08
2596	cpe-2606-A000-6B84-3DF0-7D71-ADFA-C739-6775.dyn6.twc.com	2019-01-29 05:13:19.77168-08
2597	190.147.153.196	2019-01-29 07:52:29.745453-08
2598	190.147.153.196	2019-01-29 11:23:34.547959-08
2599	190.147.153.196	2019-01-29 11:32:30.338929-08
2600	cpe-2606-A000-6B81-1300-AD0E-9D78-9009-E19D.dyn6.twc.com	2019-01-29 11:36:44.241671-08
2601	190.147.153.196	2019-01-29 12:03:13.394903-08
2602	cpe-2606-A000-6B81-1300-AD0E-9D78-9009-E19D.dyn6.twc.com	2019-01-29 12:26:39.088923-08
2603	190.147.153.196	2019-01-29 13:04:05.697994-08
2604	190.147.153.196	2019-01-29 14:04:38.363686-08
2605	190.147.153.196	2019-01-29 15:05:14.106758-08
2606	190.147.153.196	2019-01-29 17:08:30.577397-08
2607	190.147.153.196	2019-01-30 07:11:08.376429-08
2608	cpe-2606-A000-6B84-3DF0-8A5-F308-DF86-867E.dyn6.twc.com	2019-01-30 08:31:26.018473-08
2609	cpe-2606-A000-6B84-3DF0-8A5-F308-DF86-867E.dyn6.twc.com	2019-01-30 10:08:42.615964-08
2610	cpe-2606-A000-6B84-3DF0-8A5-F308-DF86-867E.dyn6.twc.com	2019-01-30 10:28:45.342557-08
2611	cpe-2606-A000-6B84-3DF0-8A5-F308-DF86-867E.dyn6.twc.com	2019-01-30 10:59:49.644809-08
2612	190.147.153.196	2019-01-30 11:27:18.927937-08
2613	190.147.153.196	2019-01-30 11:29:46.024252-08
2614	cpe-2606-A000-6B84-3DF0-8A5-F308-DF86-867E.dyn6.twc.com	2019-01-30 11:30:22.706769-08
2615	190.147.153.196	2019-01-30 11:43:37.394738-08
2616	190.147.153.196	2019-01-30 11:46:33.36847-08
2617	190.147.153.196	2019-01-30 12:03:50.789146-08
2618	cpe-2606-A000-6B84-3DF0-8A5-F308-DF86-867E.dyn6.twc.com	2019-01-30 12:28:46.70704-08
2619	cpe-2606-A000-6B84-3DF0-8A5-F308-DF86-867E.dyn6.twc.com	2019-01-30 12:31:04.92215-08
2620	190.147.153.196	2019-01-30 12:39:07.382044-08
2621	190.147.153.196	2019-01-30 12:47:57.621406-08
2622	190.147.153.196	2019-01-30 13:15:47.043459-08
2623	cpe-2606-A000-6B84-3DF0-587A-EE80-7EC2-C29C.dyn6.twc.com	2019-01-31 03:27:42.967823-08
2624	cpe-2606-A000-6B84-3DF0-945E-5E25-3E86-A51F.dyn6.twc.com	2019-01-31 04:55:08.218897-08
2625	cpe-2606-A000-6B84-3DF0-945E-5E25-3E86-A51F.dyn6.twc.com	2019-01-31 05:15:29.804397-08
2626	cpe-2606-A000-6B84-3DF0-945E-5E25-3E86-A51F.dyn6.twc.com	2019-01-31 05:35:05.751308-08
2627	cpe-2606-A000-6B84-3DF0-945E-5E25-3E86-A51F.dyn6.twc.com	2019-01-31 06:04:35.772819-08
2628	cpe-2606-A000-6B84-3DF0-945E-5E25-3E86-A51F.dyn6.twc.com	2019-01-31 06:21:53.678941-08
2629	190.147.153.196	2019-01-31 09:53:37.246259-08
2630	190.147.153.196	2019-01-31 15:03:04.364987-08
2631	190.147.153.196	2019-01-31 15:21:45.300208-08
2632	190.147.153.196	2019-01-31 15:49:25.675439-08
2633	190.147.153.196	2019-01-31 16:10:52.327753-08
2634	190.147.153.196	2019-01-31 16:31:25.808805-08
2635	190.147.153.196	2019-01-31 16:37:31.644253-08
2636	190.147.153.196	2019-01-31 16:56:15.368773-08
2637	cpe-2606-A000-6B84-3DF0-892B-D1B8-8F8-69CA.dyn6.twc.com	2019-02-01 05:38:30.622995-08
2638	cpe-2606-A000-6B84-3DF0-780E-76CD-6600-DE55.dyn6.twc.com	2019-02-01 06:57:48.685884-08
2639	cpe-2606-A000-6B84-3DF0-780E-76CD-6600-DE55.dyn6.twc.com	2019-02-01 07:40:12.314647-08
2640	cpe-2606-A000-6B84-3DF0-780E-76CD-6600-DE55.dyn6.twc.com	2019-02-01 07:51:03.722848-08
2641	cpe-2606-A000-6B84-3DF0-780E-76CD-6600-DE55.dyn6.twc.com	2019-02-01 08:25:52.777697-08
2642	cpe-2606-A000-6B84-3DF0-780E-76CD-6600-DE55.dyn6.twc.com	2019-02-01 08:48:47.21752-08
2643	cpe-2606-A000-6B84-3DF0-780E-76CD-6600-DE55.dyn6.twc.com	2019-02-01 08:59:23.639444-08
2644	190.147.153.196	2019-02-01 09:38:29.513694-08
2645	cpe-2606-A000-6B84-3DF0-780E-76CD-6600-DE55.dyn6.twc.com	2019-02-01 10:30:09.776568-08
2646	cpe-2606-A000-6B84-3DF0-780E-76CD-6600-DE55.dyn6.twc.com	2019-02-01 10:41:58.206783-08
2647	cpe-2606-A000-6B84-3DF0-780E-76CD-6600-DE55.dyn6.twc.com	2019-02-01 11:00:46.693568-08
2648	cpe-2606-A000-6B84-3DF0-780E-76CD-6600-DE55.dyn6.twc.com	2019-02-01 11:12:08.036142-08
2649	190.147.153.196	2019-02-01 11:53:18.368461-08
2650	190.147.153.196	2019-02-01 11:55:33.072633-08
2651	190.147.153.196	2019-02-01 12:12:44.476013-08
2652	cpe-2606-A000-6B84-3DF0-780E-76CD-6600-DE55.dyn6.twc.com	2019-02-01 12:13:36.239661-08
2653	cpe-2606-A000-6B84-3DF0-780E-76CD-6600-DE55.dyn6.twc.com	2019-02-01 12:28:27.673204-08
2654	cpe-69-132-97-204.carolina.res.rr.com	2019-02-01 12:38:41.834762-08
2655	cpe-2606-A000-6B84-3DF0-780E-76CD-6600-DE55.dyn6.twc.com	2019-02-01 12:43:45.710628-08
2656	cpe-2606-A000-6B84-3DF0-780E-76CD-6600-DE55.dyn6.twc.com	2019-02-01 13:17:47.618331-08
2657	190.147.153.196	2019-02-01 13:23:00.058197-08
2658	cpe-2606-A000-6B84-3DF0-780E-76CD-6600-DE55.dyn6.twc.com	2019-02-01 13:26:21.344198-08
2661	190.147.153.196	2019-02-01 15:54:03.545203-08
2662	190.147.153.196	2019-02-01 16:02:36.364276-08
2663	190.147.153.196	2019-02-01 16:15:43.616058-08
2664	190.147.153.196	2019-02-01 16:33:05.776908-08
2665	cpe-2606-A000-6B84-3DF0-2859-A965-63BD-7E9E.dyn6.twc.com	2019-02-04 03:21:23.979687-08
2666	cpe-2606-A000-6B84-3DF0-2859-A965-63BD-7E9E.dyn6.twc.com	2019-02-04 04:54:58.723022-08
2667	cpe-2606-A000-6B84-3DF0-2859-A965-63BD-7E9E.dyn6.twc.com	2019-02-04 05:04:04.78737-08
2668	cpe-2606-A000-6B84-3DF0-2859-A965-63BD-7E9E.dyn6.twc.com	2019-02-04 05:19:01.019112-08
2669	cpe-2606-A000-6B84-3DF0-2859-A965-63BD-7E9E.dyn6.twc.com	2019-02-04 06:07:36.023728-08
2670	190.147.153.196	2019-02-04 06:13:51.397002-08
2671	190.147.153.196	2019-02-04 06:22:47.367262-08
2672	cpe-2606-A000-6B84-3DF0-2859-A965-63BD-7E9E.dyn6.twc.com	2019-02-04 06:25:09.614697-08
2673	cpe-2606-A000-6B84-3DF0-2859-A965-63BD-7E9E.dyn6.twc.com	2019-02-04 06:38:09.774544-08
2674	cpe-2606-A000-6B84-3DF0-2859-A965-63BD-7E9E.dyn6.twc.com	2019-02-04 06:55:39.209058-08
2675	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2019-02-04 07:19:51.636314-08
2676	190.147.153.196	2019-02-04 07:41:37.786789-08
2677	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2019-02-04 08:33:59.348912-08
2678	cpe-2606-A000-6B84-3DF0-2859-A965-63BD-7E9E.dyn6.twc.com	2019-02-04 11:40:48.679808-08
2679	cpe-2606-A000-6B84-3DF0-2859-A965-63BD-7E9E.dyn6.twc.com	2019-02-04 12:34:29.70902-08
2680	cpe-2606-A000-6B84-3DF0-CCED-3987-A0BA-636A.dyn6.twc.com	2019-02-05 04:12:12.766713-08
2681	cpe-2606-A000-6B84-3DF0-CCED-3987-A0BA-636A.dyn6.twc.com	2019-02-05 04:33:46.112785-08
2682	cpe-2606-A000-6B84-3DF0-CCED-3987-A0BA-636A.dyn6.twc.com	2019-02-05 04:48:03.230424-08
2683	cpe-2606-A000-6B84-3DF0-89FD-38BC-4A26-3635.dyn6.twc.com	2019-02-05 05:15:41.713741-08
2684	190.147.153.196	2019-02-05 07:09:34.372465-08
2685	190.147.153.196	2019-02-05 11:02:44.870625-08
2686	190.147.153.196	2019-02-05 11:11:44.883773-08
2687	190.147.153.196	2019-02-05 11:22:45.253765-08
2688	190.147.153.196	2019-02-05 11:43:17.643644-08
2689	190.147.153.196	2019-02-05 12:29:33.323895-08
2690	190.147.153.196	2019-02-05 13:08:25.911209-08
2691	190.147.153.196	2019-02-05 14:08:59.739527-08
2692	190.147.153.196	2019-02-05 14:23:03.493818-08
2693	190.147.153.196	2019-02-05 14:31:53.326429-08
2694	190.147.153.196	2019-02-05 14:42:43.841525-08
2695	190.147.153.196	2019-02-05 14:56:55.300898-08
2696	190.147.153.196	2019-02-05 15:15:42.453919-08
2697	190.147.153.196	2019-02-05 15:36:17.067234-08
2698	50.234.200.131	2019-02-06 01:46:33.556344-08
2699	50.234.200.131	2019-02-06 02:36:31.069431-08
2700	50.234.200.131	2019-02-06 02:37:41.374153-08
2701	50.234.200.131	2019-02-06 03:16:57.336114-08
2702	50.234.200.131	2019-02-06 03:23:41.618097-08
2703	50.234.200.131	2019-02-06 03:45:15.578211-08
2704	50.234.200.131	2019-02-06 04:26:12.802803-08
2705	50.234.200.131	2019-02-06 04:46:47.73873-08
2706	50.234.200.131	2019-02-06 04:56:02.325338-08
2707	50.234.200.131	2019-02-06 05:30:15.215482-08
2708	50.234.200.131	2019-02-06 05:40:57.355962-08
2709	50.234.200.131	2019-02-06 06:01:36.822127-08
2710	190.147.153.196	2019-02-06 06:42:56.251987-08
2711	50.234.200.131	2019-02-06 07:02:31.976464-08
2712	50.234.200.131	2019-02-06 07:33:48.849071-08
2713	50.234.200.131	2019-02-06 07:46:50.021655-08
2714	50.234.200.131	2019-02-06 09:30:12.808442-08
2715	50.234.200.131	2019-02-06 10:40:30.02458-08
2716	50.234.200.131	2019-02-06 10:51:01.373363-08
2717	50.234.200.131	2019-02-06 13:00:15.738869-08
2718	50.234.200.131	2019-02-07 02:04:00.76169-08
2719	50.234.200.131	2019-02-07 03:54:41.474737-08
2720	50.234.200.131	2019-02-07 04:13:21.818068-08
2721	50.234.200.131	2019-02-07 04:24:09.615364-08
2722	50.234.200.131	2019-02-07 04:41:13.46025-08
2723	50.234.200.131	2019-02-07 05:24:27.354741-08
2724	50.234.200.131	2019-02-07 07:23:24.325596-08
2725	50.234.200.131	2019-02-07 07:31:48.373714-08
2726	190.147.153.196	2019-02-07 09:48:13.500958-08
2727	50.234.200.131	2019-02-07 13:21:12.321775-08
2728	50.234.200.131	2019-02-07 14:38:47.808138-08
2729	50.234.200.131	2019-02-07 14:52:32.321652-08
2730	50.234.200.131	2019-02-08 01:02:13.643846-08
2731	50.234.200.131	2019-02-08 01:28:48.467343-08
2732	50.234.200.131	2019-02-08 01:31:07.367971-08
2733	190.147.153.196	2019-02-08 07:28:40.576043-08
2734	190.147.153.196	2019-02-08 13:18:05.743007-08
2735	190.147.153.196	2019-02-08 14:49:39.979524-08
2736	cpe-2606-A000-6B84-3DF0-746A-60B3-DABC-6F5.dyn6.twc.com	2019-02-11 05:29:56.282518-08
2737	cpe-2606-A000-6B84-3DF0-746A-60B3-DABC-6F5.dyn6.twc.com	2019-02-11 06:13:55.788914-08
2738	cpe-2606-A000-6B84-3DF0-746A-60B3-DABC-6F5.dyn6.twc.com	2019-02-11 06:24:17.304197-08
2739	cpe-2606-A000-6B84-3DF0-746A-60B3-DABC-6F5.dyn6.twc.com	2019-02-11 06:54:52.079548-08
2740	cpe-2606-A000-6B84-3DF0-746A-60B3-DABC-6F5.dyn6.twc.com	2019-02-11 07:08:59.116535-08
2741	190.147.153.196	2019-02-11 07:14:46.944184-08
2742	cpe-2606-A000-6B84-3DF0-746A-60B3-DABC-6F5.dyn6.twc.com	2019-02-11 07:30:10.27199-08
2743	cpe-2606-A000-6B84-3DF0-746A-60B3-DABC-6F5.dyn6.twc.com	2019-02-11 09:24:22.004001-08
2744	cpe-2606-A000-6B84-3DF0-746A-60B3-DABC-6F5.dyn6.twc.com	2019-02-11 09:30:21.723511-08
2745	cpe-2606-A000-6B84-3DF0-746A-60B3-DABC-6F5.dyn6.twc.com	2019-02-11 10:14:40.204137-08
2746	cpe-2606-A000-6B84-3DF0-746A-60B3-DABC-6F5.dyn6.twc.com	2019-02-11 10:33:04.803146-08
2747	cpe-2606-A000-6B84-3DF0-746A-60B3-DABC-6F5.dyn6.twc.com	2019-02-11 10:51:03.737547-08
2748	cpe-2606-A000-6B84-3DF0-746A-60B3-DABC-6F5.dyn6.twc.com	2019-02-11 11:12:44.166922-08
2749	cpe-2606-A000-6B84-3DF0-746A-60B3-DABC-6F5.dyn6.twc.com	2019-02-11 11:29:17.761479-08
2750	cpe-2606-A000-6B84-3DF0-746A-60B3-DABC-6F5.dyn6.twc.com	2019-02-11 11:43:10.701424-08
2751	190.147.153.196	2019-02-11 12:02:09.522781-08
2752	190.147.153.196	2019-02-11 12:20:32.606179-08
2753	cpe-2606-A000-6B84-3DF0-746A-60B3-DABC-6F5.dyn6.twc.com	2019-02-11 12:20:41.286771-08
2754	190.147.153.196	2019-02-11 12:34:34.399587-08
2755	cpe-2606-A000-6B84-3DF0-746A-60B3-DABC-6F5.dyn6.twc.com	2019-02-11 12:44:39.234363-08
2756	cpe-2606-A000-6B84-3DF0-746A-60B3-DABC-6F5.dyn6.twc.com	2019-02-11 13:00:26.787495-08
2757	190.147.153.196	2019-02-11 14:13:23.354531-08
2758	190.147.153.196	2019-02-11 15:12:48.868448-08
2759	190.147.153.196	2019-02-11 15:21:42.432213-08
2760	190.147.153.196	2019-02-11 15:32:24.521161-08
2761	190.147.153.196	2019-02-11 16:03:04.604321-08
2762	cpe-2606-A000-6B84-3DF0-F57A-940E-64FC-D99C.dyn6.twc.com	2019-02-12 03:26:09.314294-08
2763	cpe-2606-A000-6B84-3DF0-F57A-940E-64FC-D99C.dyn6.twc.com	2019-02-12 04:27:42.374212-08
2764	cpe-2606-A000-6B84-3DF0-F57A-940E-64FC-D99C.dyn6.twc.com	2019-02-12 04:55:12.753301-08
2765	cpe-2606-A000-6B84-3DF0-50DA-31CB-8CF-F4BA.dyn6.twc.com	2019-02-12 05:21:58.469698-08
2766	cpe-2606-A000-6B84-3DF0-50DA-31CB-8CF-F4BA.dyn6.twc.com	2019-02-12 06:30:12.370382-08
2767	190.147.153.196	2019-02-12 06:49:16.936344-08
2862	190.147.153.196	2019-02-18 15:35:27.541311-08
2768	cpe-2606-A000-6B84-3DF0-50DA-31CB-8CF-F4BA.dyn6.twc.com	2019-02-12 11:04:13.003829-08
2769	190.147.153.196	2019-02-12 11:15:27.85247-08
2770	190.147.153.196	2019-02-12 11:24:12.02543-08
2771	cpe-2606-A000-6B84-3DF0-50DA-31CB-8CF-F4BA.dyn6.twc.com	2019-02-12 11:24:56.688723-08
2772	cpe-2606-A000-6B84-3DF0-50DA-31CB-8CF-F4BA.dyn6.twc.com	2019-02-12 11:35:29.30293-08
2773	cpe-2606-A000-6B84-3DF0-50DA-31CB-8CF-F4BA.dyn6.twc.com	2019-02-12 11:50:14.145389-08
2774	cpe-2606-A000-6B84-3DF0-50DA-31CB-8CF-F4BA.dyn6.twc.com	2019-02-12 12:22:19.254236-08
2775	cpe-2606-A000-6BA0-9CF0-50DA-31CB-8CF-F4BA.dyn6.twc.com	2019-02-12 12:43:03.295168-08
2776	190.147.153.196	2019-02-12 12:54:43.813134-08
2777	cpe-2606-A000-6BA0-9CF0-50DA-31CB-8CF-F4BA.dyn6.twc.com	2019-02-12 13:31:46.27682-08
2778	cpe-2606-A000-6BA0-9CF0-50DA-31CB-8CF-F4BA.dyn6.twc.com	2019-02-12 13:41:21.155714-08
2779	190.147.153.196	2019-02-12 13:55:31.072257-08
2780	190.147.153.196	2019-02-12 14:43:55.206854-08
2781	190.147.153.196	2019-02-12 14:57:57.492078-08
2782	190.147.153.196	2019-02-12 15:28:39.183268-08
2783	190.147.153.196	2019-02-12 16:23:42.347864-08
2784	cpe-2606-A000-6BA0-9CF0-DC62-1773-BFC3-B20F.dyn6.twc.com	2019-02-13 03:33:21.113107-08
2785	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2019-02-13 08:29:53.201251-08
2786	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2019-02-13 08:33:34.089971-08
2787	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2019-02-13 08:38:42.326203-08
2788	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2019-02-13 08:41:01.374358-08
2789	cpe-2606-A000-6B84-3DF0-DC62-1773-BFC3-B20F.dyn6.twc.com	2019-02-13 13:01:26.74866-08
2790	cpe-2606-A000-6B84-3DF0-28C9-A1F2-A4C9-A9B2.dyn6.twc.com	2019-02-14 03:08:19.728369-08
2791	cpe-2606-A000-6B84-3DF0-28C9-A1F2-A4C9-A9B2.dyn6.twc.com	2019-02-14 04:54:03.241693-08
2792	cpe-2606-A000-6B84-3DF0-28C9-A1F2-A4C9-A9B2.dyn6.twc.com	2019-02-14 05:05:27.764828-08
2793	cpe-2606-A000-6B84-3DF0-28C9-A1F2-A4C9-A9B2.dyn6.twc.com	2019-02-14 05:25:29.244769-08
2794	cpe-2606-A000-6B84-3DF0-28C9-A1F2-A4C9-A9B2.dyn6.twc.com	2019-02-14 06:00:41.768039-08
2795	190.147.153.196	2019-02-14 06:48:58.774103-08
2796	cpe-2606-A000-6B84-3DF0-28C9-A1F2-A4C9-A9B2.dyn6.twc.com	2019-02-14 07:30:14.0838-08
2797	cpe-2606-A000-6B84-3DF0-28C9-A1F2-A4C9-A9B2.dyn6.twc.com	2019-02-14 07:50:18.360832-08
2798	cpe-2606-A000-6B84-3DF0-28C9-A1F2-A4C9-A9B2.dyn6.twc.com	2019-02-14 07:56:44.769599-08
2799	cpe-2606-A000-6B84-3DF0-28C9-A1F2-A4C9-A9B2.dyn6.twc.com	2019-02-14 08:08:52.322468-08
2800	cpe-69-132-97-204.carolina.res.rr.com	2019-02-14 09:12:27.325216-08
2801	cpe-2606-A000-6B84-3DF0-28C9-A1F2-A4C9-A9B2.dyn6.twc.com	2019-02-14 09:21:17.356463-08
2802	190.147.153.196	2019-02-14 11:26:07.814936-08
2803	190.147.153.196	2019-02-14 11:41:30.758572-08
2804	190.147.153.196	2019-02-14 12:03:19.822943-08
2805	190.147.153.196	2019-02-14 12:37:31.208772-08
2806	190.147.153.196	2019-02-14 12:46:18.375444-08
2807	190.147.153.196	2019-02-14 13:16:50.147271-08
2808	190.147.153.196	2019-02-14 14:17:32.340838-08
2809	190.147.153.196	2019-02-14 14:35:26.813031-08
2810	190.147.153.196	2019-02-14 15:49:34.740084-08
2811	190.147.153.196	2019-02-14 17:26:23.942235-08
2812	cpe-2606-A000-6B84-3DF0-28C9-A1F2-A4C9-A9B2.dyn6.twc.com	2019-02-15 03:31:06.245775-08
2813	cpe-2606-A000-6B84-3DF0-28C9-A1F2-A4C9-A9B2.dyn6.twc.com	2019-02-15 03:46:04.999835-08
2814	cpe-2606-A000-6B84-3DF0-28C9-A1F2-A4C9-A9B2.dyn6.twc.com	2019-02-15 04:15:07.272742-08
2815	cpe-2606-A000-6B84-3DF0-28C9-A1F2-A4C9-A9B2.dyn6.twc.com	2019-02-15 04:38:03.093636-08
2816	cpe-2606-A000-6B84-3DF0-28C9-A1F2-A4C9-A9B2.dyn6.twc.com	2019-02-15 05:41:46.771982-08
2817	cpe-2606-A000-6B84-3DF0-28C9-A1F2-A4C9-A9B2.dyn6.twc.com	2019-02-15 05:55:12.274504-08
2818	cpe-2606-A000-6B84-3DF0-28C9-A1F2-A4C9-A9B2.dyn6.twc.com	2019-02-15 06:06:01.036811-08
2819	cpe-2606-A000-6B84-3DF0-28C9-A1F2-A4C9-A9B2.dyn6.twc.com	2019-02-15 06:18:34.234728-08
2820	cpe-2606-A000-6B84-3DF0-28C9-A1F2-A4C9-A9B2.dyn6.twc.com	2019-02-15 06:40:10.260864-08
2821	cpe-2606-A000-6B84-3DF0-28C9-A1F2-A4C9-A9B2.dyn6.twc.com	2019-02-15 06:51:22.214551-08
2822	cpe-2606-A000-6B84-3DF0-28C9-A1F2-A4C9-A9B2.dyn6.twc.com	2019-02-15 07:16:09.33558-08
2823	cpe-2606-A000-6B84-3DF0-28C9-A1F2-A4C9-A9B2.dyn6.twc.com	2019-02-15 07:21:25.092883-08
2824	cpe-2606-A000-6B84-3DF0-28C9-A1F2-A4C9-A9B2.dyn6.twc.com	2019-02-15 07:37:28.940573-08
2825	190.147.153.196	2019-02-15 07:56:21.010103-08
2826	cpe-2606-A000-6B84-3DF0-28C9-A1F2-A4C9-A9B2.dyn6.twc.com	2019-02-15 07:58:15.770403-08
2827	cpe-2606-A000-6B84-3DF0-28C9-A1F2-A4C9-A9B2.dyn6.twc.com	2019-02-15 08:09:10.336398-08
2828	cpe-2606-A000-6B84-3DF0-28C9-A1F2-A4C9-A9B2.dyn6.twc.com	2019-02-15 08:22:11.27349-08
2829	cpe-2606-A000-6B84-3DF0-28C9-A1F2-A4C9-A9B2.dyn6.twc.com	2019-02-15 08:47:49.028357-08
2830	cpe-2606-A000-6B84-3DF0-28C9-A1F2-A4C9-A9B2.dyn6.twc.com	2019-02-15 08:54:49.044572-08
2831	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2019-02-15 09:11:36.426317-08
2832	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2019-02-15 09:22:04.431055-08
2833	cpe-2606-A000-6B84-3DF0-28C9-A1F2-A4C9-A9B2.dyn6.twc.com	2019-02-15 09:25:08.631651-08
2834	cpe-2606-A000-6B84-3DF0-28C9-A1F2-A4C9-A9B2.dyn6.twc.com	2019-02-15 09:57:54.218592-08
2835	cpe-2606-A000-6B84-3DF0-28C9-A1F2-A4C9-A9B2.dyn6.twc.com	2019-02-15 10:09:52.828363-08
2836	190.147.153.196	2019-02-15 10:42:19.196332-08
2837	cpe-2606-A000-6B84-3DF0-28C9-A1F2-A4C9-A9B2.dyn6.twc.com	2019-02-15 10:55:34.181464-08
2838	190.147.153.196	2019-02-15 10:56:11.638633-08
2839	190.147.153.196	2019-02-15 11:09:57.323824-08
2840	cpe-2606-A000-6B84-3DF0-28C9-A1F2-A4C9-A9B2.dyn6.twc.com	2019-02-15 11:24:17.014856-08
2841	190.147.153.196	2019-02-15 11:25:05.927968-08
2842	190.147.153.196	2019-02-15 11:40:45.234616-08
2843	190.147.153.196	2019-02-15 12:02:32.371125-08
2844	cpe-2606-A000-6B84-3DF0-28C9-A1F2-A4C9-A9B2.dyn6.twc.com	2019-02-15 12:07:52.709082-08
2845	190.147.153.196	2019-02-15 13:16:11.631735-08
2846	cpe-2606-A000-6B84-3DF0-28C9-A1F2-A4C9-A9B2.dyn6.twc.com	2019-02-15 13:33:12.211067-08
2847	cpe-2606-A000-6B84-3DF0-28C9-A1F2-A4C9-A9B2.dyn6.twc.com	2019-02-15 13:41:55.228952-08
2848	190.147.153.196	2019-02-18 08:44:00.649193-08
2849	190.147.153.196	2019-02-18 11:18:23.169564-08
2850	190.147.153.196	2019-02-18 11:37:04.481222-08
2851	190.147.153.196	2019-02-18 11:57:44.109771-08
2852	190.147.153.196	2019-02-18 12:58:20.375583-08
2853	190.147.153.196	2019-02-18 13:30:32.510178-08
2854	190.147.153.196	2019-02-18 13:33:13.501737-08
2855	cpe-2606-A000-6B84-3DF0-55D6-1481-F2BC-194A.dyn6.twc.com	2019-02-18 13:40:22.722561-08
2856	190.147.153.196	2019-02-18 13:47:55.72718-08
2857	190.147.153.196	2019-02-18 13:58:33.059635-08
2858	190.147.153.196	2019-02-18 14:03:09.95587-08
2859	190.147.153.196	2019-02-18 14:23:38.363092-08
2860	190.147.153.196	2019-02-18 15:13:12.872429-08
2861	190.147.153.196	2019-02-18 15:26:45.501857-08
2863	190.147.153.196	2019-02-18 16:06:19.070339-08
2864	cpe-2606-A000-6B84-3DF0-60C9-113E-CCE5-57BF.dyn6.twc.com	2019-02-19 03:10:25.230989-08
2865	cpe-2606-A000-6B84-3DF0-60C9-113E-CCE5-57BF.dyn6.twc.com	2019-02-19 04:55:12.332532-08
2866	cpe-2606-A000-6B84-3DF0-60C9-113E-CCE5-57BF.dyn6.twc.com	2019-02-19 05:35:25.804702-08
2867	cpe-2606-A000-6B84-3DF0-60C9-113E-CCE5-57BF.dyn6.twc.com	2019-02-19 05:47:32.275434-08
2868	cpe-2606-A000-6B84-3DF0-60C9-113E-CCE5-57BF.dyn6.twc.com	2019-02-19 06:04:13.485986-08
2869	cpe-2606-A000-6B84-3DF0-60C9-113E-CCE5-57BF.dyn6.twc.com	2019-02-19 06:21:01.431129-08
2870	cpe-2606-A000-6B84-3DF0-60C9-113E-CCE5-57BF.dyn6.twc.com	2019-02-19 06:33:36.167316-08
2871	cpe-2606-A000-6B84-3DF0-60C9-113E-CCE5-57BF.dyn6.twc.com	2019-02-19 06:52:46.653868-08
2872	cpe-2606-A000-6B84-3DF0-60C9-113E-CCE5-57BF.dyn6.twc.com	2019-02-19 08:13:32.408301-08
2873	cpe-2606-A000-6B84-3DF0-60C9-113E-CCE5-57BF.dyn6.twc.com	2019-02-19 08:37:08.040051-08
2874	cpe-2606-A000-6B84-3DF0-60C9-113E-CCE5-57BF.dyn6.twc.com	2019-02-19 08:58:02.738714-08
2875	cpe-2606-A000-6B84-3DF0-60C9-113E-CCE5-57BF.dyn6.twc.com	2019-02-19 09:58:56.198435-08
2876	190.147.153.196	2019-02-19 10:20:22.914184-08
2877	cpe-2606-A000-6B84-3DF0-60C9-113E-CCE5-57BF.dyn6.twc.com	2019-02-19 10:35:57.236689-08
2878	cpe-2606-A000-6B84-3DF0-60C9-113E-CCE5-57BF.dyn6.twc.com	2019-02-19 10:46:19.730248-08
2879	cpe-2606-A000-6B84-3DF0-60C9-113E-CCE5-57BF.dyn6.twc.com	2019-02-19 11:19:25.48221-08
2880	cpe-2606-A000-6B84-3DF0-60C9-113E-CCE5-57BF.dyn6.twc.com	2019-02-19 11:35:37.038803-08
2881	190.147.153.196	2019-02-19 12:13:11.432734-08
2882	190.147.153.196	2019-02-19 13:07:09.871872-08
2883	cpe-69-132-97-204.carolina.res.rr.com	2019-02-19 14:24:04.074345-08
2884	190.147.153.196	2019-02-20 07:58:27.178291-08
2885	190.147.153.196	2019-02-20 08:39:45.426328-08
2886	190.147.153.196	2019-02-20 08:47:29.139452-08
2887	190.147.153.196	2019-02-20 08:58:04.793733-08
2888	190.147.153.196	2019-02-20 09:58:14.931677-08
2889	190.147.153.196	2019-02-20 10:13:03.212092-08
2890	190.147.153.196	2019-02-20 10:49:15.864931-08
2891	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2019-02-20 10:59:05.788285-08
2892	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2019-02-20 11:03:31.507595-08
2893	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2019-02-20 11:08:06.862199-08
2894	190.147.153.196	2019-02-20 11:29:04.878805-08
2895	190.147.153.196	2019-02-20 11:49:14.047866-08
2896	190.147.153.196	2019-02-20 12:22:46.828975-08
2897	190.147.153.196	2019-02-20 12:29:01.93917-08
2898	190.147.153.196	2019-02-20 12:44:49.812541-08
2899	cpe-2606-A000-6B84-3DF0-D8A4-EDC1-22B0-1F87.dyn6.twc.com	2019-02-20 13:34:42.286065-08
2900	cpe-2606-A000-6B84-3DF0-D8A4-EDC1-22B0-1F87.dyn6.twc.com	2019-02-20 13:42:18.75704-08
2901	190.147.153.196	2019-02-20 13:47:08.323061-08
2902	190.147.153.196	2019-02-20 14:05:29.144081-08
2903	190.147.153.196	2019-02-20 14:14:26.755785-08
2904	190.147.153.196	2019-02-20 14:45:24.54986-08
2905	190.147.153.196	2019-02-20 15:46:04.880695-08
2906	190.147.153.196	2019-02-20 16:01:05.809106-08
2907	190.147.153.196	2019-02-20 16:16:55.325532-08
2908	cpe-2606-A000-6B84-3DF0-9CB6-F1AB-205B-E115.dyn6.twc.com	2019-02-21 09:03:00.034481-08
2909	190.147.153.196	2019-02-21 15:47:16.696313-08
2910	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2019-02-22 07:43:05.132772-08
2911	190.147.153.196	2019-02-22 09:55:39.797714-08
2912	cpe-2606-A000-6B84-3DF0-98E6-2CE4-E2DC-3B22.dyn6.twc.com	2019-02-22 11:18:25.764374-08
2913	190.147.153.196	2019-02-22 12:23:51.889106-08
2914	190.147.153.196	2019-02-22 12:42:50.389724-08
2915	cpe-2606-A000-6B84-3DF0-98E6-2CE4-E2DC-3B22.dyn6.twc.com	2019-02-22 12:57:49.103061-08
2916	190.147.153.196	2019-02-22 13:03:37.614845-08
2917	cpe-2606-A000-6B84-3DF0-98E6-2CE4-E2DC-3B22.dyn6.twc.com	2019-02-22 13:06:47.886084-08
2918	098-127-006-066.res.spectrum.com	2019-02-22 13:22:50.88054-08
2919	098-127-006-066.res.spectrum.com	2019-02-22 13:23:43.548072-08
2920	190.147.153.196	2019-02-22 13:31:49.176833-08
2921	cpe-2606-A000-6B84-3DF0-98E6-2CE4-E2DC-3B22.dyn6.twc.com	2019-02-22 13:37:17.130481-08
2922	190.147.153.196	2019-02-22 13:42:58.229442-08
2923	190.147.153.196	2019-02-22 13:52:31.841997-08
2924	190.147.153.196	2019-02-22 14:07:16.074953-08
2925	190.147.153.196	2019-02-22 14:40:22.412706-08
2926	190.147.153.196	2019-02-22 15:21:44.705398-08
2927	cpe-2606-A000-6B84-3DF0-6CB9-A8CA-3395-1CED.dyn6.twc.com	2019-02-23 04:48:01.734055-08
2928	cpe-2606-A000-6B84-3DF0-6CB9-A8CA-3395-1CED.dyn6.twc.com	2019-02-23 05:04:06.803558-08
2929	cpe-2606-A000-6B84-3DF0-6CB9-A8CA-3395-1CED.dyn6.twc.com	2019-02-23 05:19:46.778324-08
2930	cpe-2606-A000-6B84-3DF0-6CB9-A8CA-3395-1CED.dyn6.twc.com	2019-02-23 05:40:56.226532-08
2931	cpe-2606-A000-6B84-3DF0-6CB9-A8CA-3395-1CED.dyn6.twc.com	2019-02-23 07:01:59.585812-08
2932	cpe-2606-A000-6B84-3DF0-6CB9-A8CA-3395-1CED.dyn6.twc.com	2019-02-23 07:18:07.768477-08
2933	cpe-2606-A000-6B84-3DF0-6CB9-A8CA-3395-1CED.dyn6.twc.com	2019-02-23 07:20:25.321866-08
2934	cpe-69-132-97-204.carolina.res.rr.com	2019-02-23 07:51:10.485562-08
2935	cpe-2606-A000-6B84-3DF0-6CB9-A8CA-3395-1CED.dyn6.twc.com	2019-02-23 08:01:58.012246-08
2936	cpe-2606-A000-6B84-3DF0-6429-81A1-1135-5C0B.dyn6.twc.com	2019-02-25 05:18:27.228359-08
2937	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2019-02-25 06:43:06.870961-08
2938	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2019-02-25 06:45:36.901113-08
2939	190.147.153.196	2019-02-25 07:11:54.16759-08
2940	190.147.153.196	2019-02-25 08:19:18.268128-08
2941	190.147.153.196	2019-02-25 08:38:18.110207-08
2942	cpe-2606-A000-6B84-3DF0-6429-81A1-1135-5C0B.dyn6.twc.com	2019-02-25 09:45:10.183855-08
2943	190.147.153.196	2019-02-25 09:59:03.274041-08
2944	190.147.153.196	2019-02-25 10:08:06.538922-08
2945	190.147.153.196	2019-02-25 10:16:55.374523-08
2946	cpe-2606-A000-6B84-3DF0-6429-81A1-1135-5C0B.dyn6.twc.com	2019-02-25 10:34:27.128423-08
2947	190.147.153.196	2019-02-25 11:07:50.923681-08
2948	190.147.153.196	2019-02-25 11:13:58.331834-08
2949	190.147.153.196	2019-02-25 11:16:19.552869-08
2950	190.147.153.196	2019-02-25 11:22:12.364731-08
2951	cpe-2606-A000-6B84-3DF0-6429-81A1-1135-5C0B.dyn6.twc.com	2019-02-25 11:32:06.731267-08
2952	190.147.153.196	2019-02-25 11:52:46.620052-08
2953	cpe-2606-A000-6B84-3DF0-194D-CC8F-DF0E-2E67.dyn6.twc.com	2019-02-25 11:59:04.79788-08
2954	190.147.153.196	2019-02-25 12:20:44.859506-08
2955	cpe-2606-A000-6B84-3DF0-194D-CC8F-DF0E-2E67.dyn6.twc.com	2019-02-25 12:47:04.521653-08
2956	190.147.153.196	2019-02-25 12:51:28.089449-08
2957	cpe-2606-A000-6B84-3DF0-194D-CC8F-DF0E-2E67.dyn6.twc.com	2019-02-25 12:57:58.205071-08
2958	cpe-2606-A000-6B84-3DF0-194D-CC8F-DF0E-2E67.dyn6.twc.com	2019-02-25 13:06:08.297309-08
2959	cpe-2606-A000-6B84-3DF0-194D-CC8F-DF0E-2E67.dyn6.twc.com	2019-02-25 13:20:16.717153-08
2960	cpe-2606-A000-6B84-3DF0-D1A0-3067-276F-4387.dyn6.twc.com	2019-02-26 04:50:15.737125-08
2961	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2019-02-26 05:54:52.520174-08
2962	cpe-2606-A000-6B84-3DF0-D1A0-3067-276F-4387.dyn6.twc.com	2019-02-26 06:12:04.279352-08
2963	cpe-2606-A000-6B84-3DF0-D1A0-3067-276F-4387.dyn6.twc.com	2019-02-26 06:22:23.748174-08
2964	cpe-2606-A000-6B84-3DF0-D1A0-3067-276F-4387.dyn6.twc.com	2019-02-26 06:37:51.108837-08
2965	cpe-2606-A000-6B84-3DF0-D1A0-3067-276F-4387.dyn6.twc.com	2019-02-26 06:57:17.074028-08
2966	190.147.153.196	2019-02-26 08:20:19.416394-08
2967	190.147.153.196	2019-02-26 09:43:41.475276-08
2968	cpe-2606-A000-6B84-3DF0-D1A0-3067-276F-4387.dyn6.twc.com	2019-02-26 10:18:55.728905-08
2969	cpe-2606-A000-6B84-3DF0-D1A0-3067-276F-4387.dyn6.twc.com	2019-02-26 10:39:46.736473-08
2970	cpe-2606-A000-6B84-3DF0-D1A0-3067-276F-4387.dyn6.twc.com	2019-02-26 11:08:33.708461-08
2971	190.147.153.196	2019-02-26 11:23:56.228748-08
2972	cpe-2606-A000-6B84-3DF0-D1A0-3067-276F-4387.dyn6.twc.com	2019-02-26 11:28:14.739331-08
2973	190.147.153.196	2019-02-26 11:28:58.360236-08
2974	190.147.153.196	2019-02-26 11:34:40.834573-08
2975	cpe-2606-A000-6B84-3DF0-D1A0-3067-276F-4387.dyn6.twc.com	2019-02-26 11:38:54.206367-08
2976	cpe-2606-A000-6B84-3DF0-D1A0-3067-276F-4387.dyn6.twc.com	2019-02-26 11:50:07.207997-08
2977	cpe-2606-A000-6B84-3DF0-D1A0-3067-276F-4387.dyn6.twc.com	2019-02-26 12:01:05.858308-08
2978	190.147.153.196	2019-02-26 12:05:10.610363-08
2979	cpe-2606-A000-6B84-3DF0-D1A0-3067-276F-4387.dyn6.twc.com	2019-02-26 12:18:11.733866-08
2980	190.147.153.196	2019-02-26 12:19:01.888505-08
2981	190.147.153.196	2019-02-26 12:37:56.473027-08
2982	cpe-2606-A000-6B84-3DF0-D1A0-3067-276F-4387.dyn6.twc.com	2019-02-26 12:52:08.21235-08
2983	190.147.153.196	2019-02-26 12:58:38.149209-08
2984	cpe-2606-A000-6B84-3DF0-D1A0-3067-276F-4387.dyn6.twc.com	2019-02-26 13:02:56.704946-08
2985	190.147.153.196	2019-02-26 13:48:55.155534-08
2986	190.147.153.196	2019-02-26 14:07:55.43445-08
2987	190.147.153.196	2019-02-26 14:48:07.279201-08
2988	190.147.153.196	2019-02-26 15:03:56.173331-08
2989	190.147.153.196	2019-02-26 15:24:50.537221-08
2990	190.147.153.196	2019-02-26 16:25:34.193294-08
2991	190.147.153.196	2019-02-26 17:26:27.270916-08
2992	cpe-2606-A000-6B84-3DF0-38C2-E7B4-D8F7-726.dyn6.twc.com	2019-02-27 03:19:17.082367-08
2993	cpe-2606-A000-6B84-3DF0-38C2-E7B4-D8F7-726.dyn6.twc.com	2019-02-27 04:55:14.264744-08
2994	cpe-2606-A000-6B84-3DF0-38C2-E7B4-D8F7-726.dyn6.twc.com	2019-02-27 05:03:57.063088-08
2995	cpe-2606-A000-6B84-3DF0-38C2-E7B4-D8F7-726.dyn6.twc.com	2019-02-27 05:14:34.054068-08
2996	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2019-02-27 06:21:42.408182-08
2997	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2019-02-27 06:40:13.151105-08
2998	190.147.153.196	2019-02-27 06:54:37.49753-08
2999	cpe-2606-A000-6B84-3DF0-498-5EDF-5686-CF1A.dyn6.twc.com	2019-02-27 06:59:25.745153-08
3000	190.147.153.196	2019-02-27 07:59:32.23687-08
3001	190.147.153.196	2019-02-27 08:08:15.336706-08
3002	190.147.153.196	2019-02-27 08:19:04.586405-08
3003	190.147.153.196	2019-02-27 09:39:42.168923-08
3004	190.147.153.196	2019-02-27 10:05:19.624429-08
3005	190.147.153.196	2019-02-27 10:31:05.677595-08
3006	190.147.153.196	2019-02-27 10:39:49.254596-08
3007	cpe-2606-A000-6B84-3DF0-498-5EDF-5686-CF1A.dyn6.twc.com	2019-02-27 10:43:10.240629-08
3008	190.147.153.196	2019-02-27 10:53:46.389047-08
3009	cpe-2606-A000-6B84-3DF0-498-5EDF-5686-CF1A.dyn6.twc.com	2019-02-27 10:55:58.737853-08
3010	190.147.153.196	2019-02-27 11:12:53.529458-08
3011	cpe-2606-A000-6B84-3DF0-498-5EDF-5686-CF1A.dyn6.twc.com	2019-02-27 11:22:11.201283-08
3012	190.147.153.196	2019-02-27 11:24:00.857728-08
3013	cpe-2606-A000-6B84-3DF0-498-5EDF-5686-CF1A.dyn6.twc.com	2019-02-27 11:54:02.752753-08
3014	190.147.153.196	2019-02-27 12:03:51.391247-08
3015	cpe-2606-A000-6B84-3DF0-498-5EDF-5686-CF1A.dyn6.twc.com	2019-02-27 12:25:45.812789-08
3016	cpe-2606-A000-6B84-3DF0-498-5EDF-5686-CF1A.dyn6.twc.com	2019-02-27 12:38:10.2202-08
3017	cpe-2606-A000-6B84-3DF0-498-5EDF-5686-CF1A.dyn6.twc.com	2019-02-27 12:53:52.708027-08
3018	190.147.153.196	2019-02-27 13:04:26.382406-08
3019	cpe-2606-A000-6B84-3DF0-498-5EDF-5686-CF1A.dyn6.twc.com	2019-02-27 13:14:05.036207-08
3020	190.147.153.196	2019-02-27 13:34:27.812379-08
3021	cpe-2606-A000-6B84-3DF0-498-5EDF-5686-CF1A.dyn6.twc.com	2019-02-27 13:34:38.617748-08
3022	190.147.153.196	2019-02-27 14:02:48.148463-08
3023	190.147.153.196	2019-02-27 14:23:18.87074-08
3024	190.147.153.196	2019-02-27 15:23:59.358392-08
3025	190.147.153.196	2019-02-27 15:39:46.378083-08
3026	190.147.153.196	2019-02-27 15:42:04.468653-08
3027	190.147.153.196	2019-02-27 16:18:09.128369-08
3028	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2019-02-28 06:04:00.493054-08
3029	190.147.153.196	2019-02-28 08:02:11.73697-08
3030	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2019-02-28 09:36:12.153914-08
3031	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2019-02-28 10:34:46.137308-08
3032	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2019-02-28 10:34:55.131336-08
3033	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2019-02-28 10:55:51.806993-08
3034	190.147.153.196	2019-02-28 11:29:31.444091-08
3035	190.147.153.196	2019-02-28 11:48:24.500453-08
3036	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2019-02-28 12:10:12.388538-08
3037	190.147.153.196	2019-02-28 13:01:09.465529-08
3038	190.147.153.196	2019-02-28 13:19:51.407869-08
3039	cpe-2606-A000-6B84-3DF0-88A1-9032-A07F-AE4C.dyn6.twc.com	2019-02-28 13:24:31.708272-08
3040	190.147.153.196	2019-02-28 13:40:26.336391-08
3041	190.147.153.196	2019-02-28 13:49:03.198221-08
3042	190.147.153.196	2019-02-28 15:39:17.864466-08
3043	190.147.153.196	2019-02-28 15:58:03.323673-08
3044	190.147.153.196	2019-02-28 16:18:31.331822-08
3045	190.147.153.196	2019-02-28 17:06:31.735752-08
3046	190.147.153.196	2019-02-28 17:25:29.594431-08
3047	190.147.153.196	2019-03-01 07:36:22.807894-08
3048	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2019-03-01 08:21:50.738678-08
3049	190.147.153.196	2019-03-01 12:00:02.574971-08
3050	190.147.153.196	2019-03-01 12:09:05.212428-08
3051	190.147.153.196	2019-03-01 12:39:45.35757-08
3052	190.147.153.196	2019-03-01 12:55:21.60532-08
3053	190.147.153.196	2019-03-01 13:12:45.295448-08
3054	190.147.153.196	2019-03-01 13:28:36.834503-08
3055	190.147.153.196	2019-03-01 14:01:40.290241-08
3056	190.147.153.196	2019-03-01 14:17:18.591983-08
3057	190.147.153.196	2019-03-01 14:26:07.477348-08
3058	190.147.153.196	2019-03-01 15:08:26.153323-08
3059	190.147.153.196	2019-03-01 16:09:33.256055-08
3060	190.147.153.196	2019-03-01 17:10:29.180598-08
3061	190.147.153.196	2019-03-01 18:11:28.509459-08
3062	190.147.153.196	2019-03-04 07:43:42.358956-08
3063	190.147.153.196	2019-03-04 10:55:17.392271-08
3064	190.147.153.196	2019-03-04 11:14:06.325912-08
3065	cpe-2606-A000-6B84-3DF0-7522-83D8-8481-EE5D.dyn6.twc.com	2019-03-05 07:22:29.342516-08
3066	cpe-69-132-97-204.carolina.res.rr.com	2019-03-05 08:05:18.453877-08
3067	cpe-2606-A000-6B84-3DF0-7522-83D8-8481-EE5D.dyn6.twc.com	2019-03-05 08:12:27.235819-08
3068	cpe-2606-A000-6B84-3DF0-7522-83D8-8481-EE5D.dyn6.twc.com	2019-03-05 09:08:42.346336-08
3069	cpe-2606-A000-6B84-3DF0-7522-83D8-8481-EE5D.dyn6.twc.com	2019-03-05 10:16:52.296614-08
3070	cpe-2606-A000-6B84-3DF0-7522-83D8-8481-EE5D.dyn6.twc.com	2019-03-05 11:06:42.300611-08
3071	cpe-2606-A000-6B84-3DF0-7522-83D8-8481-EE5D.dyn6.twc.com	2019-03-05 11:56:57.352529-08
3072	cpe-2606-A000-6B84-3DF0-7522-83D8-8481-EE5D.dyn6.twc.com	2019-03-05 12:45:32.355249-08
3073	190.147.153.196	2019-03-06 07:47:31.145696-08
3074	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2019-03-07 08:05:36.290541-08
3075	190.147.153.196	2019-03-07 11:01:25.310484-08
3076	cpe-2606-A000-6B84-3DF0-182-CA0E-A430-167D.dyn6.twc.com	2019-03-07 12:46:47.363212-08
3077	190.147.153.196	2019-03-08 06:08:57.063605-08
3078	190.147.153.196	2019-03-08 06:28:03.474785-08
3079	190.147.153.196	2019-03-08 07:31:36.343455-08
3080	190.147.153.196	2019-03-08 07:40:49.375487-08
3081	190.147.153.196	2019-03-08 07:57:15.109325-08
3082	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2019-03-08 08:13:33.524938-08
3083	190.147.153.196	2019-03-08 08:32:48.499801-08
3084	190.147.153.196	2019-03-08 09:33:40.571014-08
3085	190.147.153.196	2019-03-08 10:34:23.407202-08
3086	190.147.153.196	2019-03-08 11:11:17.418689-08
3087	190.147.153.196	2019-03-08 11:13:29.576363-08
3088	190.147.153.196	2019-03-08 11:30:37.845526-08
3089	190.147.153.196	2019-03-08 11:56:31.438268-08
3090	190.147.153.196	2019-03-08 11:58:54.891225-08
3091	190.147.153.196	2019-03-08 12:16:05.529111-08
3092	190.147.153.196	2019-03-08 12:36:41.398656-08
3093	190.147.153.196	2019-03-08 13:35:32.29717-08
3094	190.147.153.196	2019-03-08 13:49:41.039515-08
3095	190.147.153.196	2019-03-08 14:00:21.859074-08
3096	190.147.153.196	2019-03-08 14:02:41.3882-08
3097	190.147.153.196	2019-03-08 14:40:11.49334-08
3098	190.147.153.196	2019-03-08 15:58:31.039257-08
3099	190.147.153.196	2019-03-08 16:07:45.178642-08
3100	190.147.153.196	2019-03-08 16:18:34.401334-08
3101	p5DCF9051.dip0.t-ipconnect.de	2019-03-09 03:03:30.180064-08
3102	p5DCF9051.dip0.t-ipconnect.de	2019-03-10 00:55:54.45985-08
3103	p5DCF9051.dip0.t-ipconnect.de	2019-03-10 00:58:13.32698-08
3104	p5DCF9051.dip0.t-ipconnect.de	2019-03-10 01:16:05.041911-08
3105	p5DCF9051.dip0.t-ipconnect.de	2019-03-10 01:17:58.443863-08
3106	p5DCF9051.dip0.t-ipconnect.de	2019-03-10 01:25:45.443476-08
3107	190.147.153.196	2019-03-11 07:58:34.91651-07
3108	190.147.153.196	2019-03-11 10:12:17.37975-07
3109	190.147.153.196	2019-03-11 10:21:03.871607-07
3110	190.147.153.196	2019-03-11 10:48:10.890701-07
3111	cpe-2606-A000-6B84-3DF0-B9AD-6FA2-4DFF-24FA.dyn6.twc.com	2019-03-11 10:50:02.240261-07
3112	190.147.153.196	2019-03-11 11:09:35.832923-07
3113	190.147.153.196	2019-03-11 11:31:42.614689-07
3114	cpe-2606-A000-6B84-3DF0-B9AD-6FA2-4DFF-24FA.dyn6.twc.com	2019-03-11 11:39:52.295383-07
3115	190.147.153.196	2019-03-11 11:58:04.526641-07
3116	190.147.153.196	2019-03-11 12:58:36.709329-07
3117	190.147.153.196	2019-03-11 13:48:29.958589-07
3118	190.147.153.196	2019-03-11 14:28:02.644759-07
3119	190.147.153.196	2019-03-11 15:28:47.615227-07
3120	190.147.153.196	2019-03-11 16:10:30.945565-07
3121	190.147.153.196	2019-03-11 16:26:09.826201-07
3122	190.147.153.196	2019-03-11 16:45:24.730676-07
3123	190.147.153.196	2019-03-11 17:06:04.529092-07
3124	190.147.153.196	2019-03-12 07:45:36.239376-07
3125	cpe-2606-A000-6B84-3DF0-8198-7DA6-D71D-525F.dyn6.twc.com	2019-03-12 10:00:25.340553-07
3126	cpe-2606-A000-6B84-3DF0-8198-7DA6-D71D-525F.dyn6.twc.com	2019-03-12 10:50:41.429-07
3127	p5DCF9051.dip0.t-ipconnect.de	2019-03-12 11:03:45.029016-07
3128	cpe-2606-A000-6B84-3DF0-8198-7DA6-D71D-525F.dyn6.twc.com	2019-03-12 11:49:47.397988-07
3129	cpe-2606-A000-6B84-3DF0-8198-7DA6-D71D-525F.dyn6.twc.com	2019-03-12 12:38:36.69142-07
3130	190.147.153.196	2019-03-12 12:39:39.02219-07
3131	190.147.153.196	2019-03-12 12:48:47.113186-07
3132	190.147.153.196	2019-03-12 14:19:33.839616-07
3133	190.147.153.196	2019-03-12 14:54:46.85606-07
3134	190.147.153.196	2019-03-12 15:03:37.068773-07
3135	190.147.153.196	2019-03-12 16:07:04.792539-07
3136	cpe-2606-A000-6B84-3DF0-18CF-540F-EBB9-567.dyn6.twc.com	2019-03-13 03:25:16.261986-07
3137	cpe-2606-A000-6B84-3DF0-18CF-540F-EBB9-567.dyn6.twc.com	2019-03-13 04:52:46.273514-07
3138	cpe-2606-A000-6B84-3DF0-18CF-540F-EBB9-567.dyn6.twc.com	2019-03-13 05:45:37.41096-07
3139	cpe-2606-A000-6B84-3DF0-14C6-E6F-3845-E86E.dyn6.twc.com	2019-03-13 06:11:03.282115-07
3140	cpe-2606-A000-6B84-3DF0-B119-A6FB-3FF2-5046.dyn6.twc.com	2019-03-13 07:00:13.285972-07
3141	190.147.153.196	2019-03-13 08:34:24.386879-07
3142	190.147.153.196	2019-03-13 12:13:26.441823-07
3143	190.147.153.196	2019-03-13 12:21:11.612545-07
3144	190.147.153.196	2019-03-13 12:35:02.827191-07
3145	cpe-2606-A000-6B84-3DF0-B119-A6FB-3FF2-5046.dyn6.twc.com	2019-03-13 12:39:40.424986-07
3146	190.147.153.196	2019-03-13 12:50:28.096704-07
3147	190.147.153.196	2019-03-13 13:11:43.381621-07
3148	190.147.153.196	2019-03-13 14:32:17.616161-07
3149	190.147.153.196	2019-03-13 14:50:36.347514-07
3150	190.147.153.196	2019-03-13 14:54:34.875436-07
3151	190.147.153.196	2019-03-13 15:08:13.81333-07
3152	190.147.153.196	2019-03-13 15:25:35.286499-07
3153	190.147.153.196	2019-03-13 15:46:24.636959-07
3154	190.147.153.196	2019-03-13 16:09:28.053111-07
3155	190.147.153.196	2019-03-13 16:29:57.407348-07
3156	cpe-2606-A000-6B84-3DF0-CCCC-D473-AFA7-E11C.dyn6.twc.com	2019-03-14 03:48:25.270335-07
3157	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2019-03-14 09:30:49.495158-07
3158	190.147.153.196	2019-03-14 10:22:41.808056-07
3159	p5DCF9051.dip0.t-ipconnect.de	2019-03-14 10:53:50.753487-07
3160	cpe-2606-A000-6B84-3DF0-24F8-2134-4555-D4C2.dyn6.twc.com	2019-03-15 03:19:36.342744-07
3161	cpe-2606-A000-6B84-3DF0-24F8-2134-4555-D4C2.dyn6.twc.com	2019-03-15 07:47:51.328287-07
3162	cpe-2606-A000-6B84-3DF0-24F8-2134-4555-D4C2.dyn6.twc.com	2019-03-15 08:40:15.39876-07
3163	190.147.153.196	2019-03-15 09:03:57.862468-07
3164	cpe-2606-A000-6B84-3DF0-24F8-2134-4555-D4C2.dyn6.twc.com	2019-03-15 09:35:46.279721-07
3165	cpe-2606-A000-6B84-3DF0-24F8-2134-4555-D4C2.dyn6.twc.com	2019-03-15 10:36:39.26771-07
3166	190.147.153.196	2019-03-15 11:44:31.786711-07
3167	190.147.153.196	2019-03-15 11:47:06.387056-07
3168	cpe-2606-A000-6B84-3DF0-24F8-2134-4555-D4C2.dyn6.twc.com	2019-03-15 11:57:41.323929-07
3169	190.147.153.196	2019-03-15 12:24:13.363459-07
3170	cpe-2606-A000-6B84-3DF0-24F8-2134-4555-D4C2.dyn6.twc.com	2019-03-15 12:49:55.309192-07
3171	190.147.153.196	2019-03-15 13:07:29.759202-07
3172	190.147.153.196	2019-03-15 13:17:59.881214-07
3173	190.147.153.196	2019-03-15 13:34:14.65147-07
3174	cpe-2606-A000-6B84-3DF0-24F8-2134-4555-D4C2.dyn6.twc.com	2019-03-15 13:38:54.234165-07
3175	190.147.153.196	2019-03-15 13:57:26.597536-07
3176	190.147.153.196	2019-03-15 14:07:52.944373-07
3177	190.147.153.196	2019-03-15 14:19:12.930282-07
3178	190.147.153.196	2019-03-15 14:50:49.177412-07
3179	190.147.153.196	2019-03-15 15:12:07.622201-07
3180	190.147.153.196	2019-03-15 15:33:03.070492-07
3181	cpe-2606-A000-6B84-3DF0-68F5-37BD-ACD9-76E2.dyn6.twc.com	2019-03-18 05:50:06.734746-07
3182	190.147.153.196	2019-03-18 07:55:23.060755-07
3183	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2019-03-18 08:10:33.92325-07
3184	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2019-03-18 08:11:15.855056-07
3185	190.147.153.196	2019-03-18 10:34:16.000347-07
3186	190.147.153.196	2019-03-18 11:42:42.566175-07
3187	190.147.153.196	2019-03-18 12:01:48.179652-07
3188	190.147.153.196	2019-03-18 12:22:40.342245-07
3189	190.147.153.196	2019-03-18 13:03:44.364055-07
3190	190.147.153.196	2019-03-18 13:14:19.115535-07
3191	190.147.153.196	2019-03-18 13:31:29.610254-07
3192	190.147.153.196	2019-03-18 14:01:09.41124-07
3193	190.147.153.196	2019-03-18 14:21:49.578025-07
3194	190.147.153.196	2019-03-18 14:37:18.571438-07
3195	190.147.153.196	2019-03-18 14:46:25.178355-07
3196	190.147.153.196	2019-03-18 15:10:51.607912-07
3197	190.147.153.196	2019-03-18 15:31:42.760117-07
3198	190.147.153.196	2019-03-18 15:42:49.081005-07
3199	190.147.153.196	2019-03-18 15:59:22.569875-07
3200	190.147.153.196	2019-03-18 16:02:55.460931-07
3201	cpe-2606-A000-6B84-3DF0-38C0-485C-3C5D-333A.dyn6.twc.com	2019-03-19 03:55:59.244416-07
3202	cpe-2606-A000-6B84-3DF0-38C0-485C-3C5D-333A.dyn6.twc.com	2019-03-19 04:50:38.266971-07
3203	cpe-2606-A000-6B84-3DF0-38C0-485C-3C5D-333A.dyn6.twc.com	2019-03-19 05:01:54.73951-07
3204	cpe-2606-A000-6B84-3DF0-38C0-485C-3C5D-333A.dyn6.twc.com	2019-03-19 05:17:56.795476-07
3205	cpe-2606-A000-6B84-3DF0-38C0-485C-3C5D-333A.dyn6.twc.com	2019-03-19 05:34:32.146908-07
3206	cpe-2606-A000-6B84-3DF0-38C0-485C-3C5D-333A.dyn6.twc.com	2019-03-19 05:53:49.250132-07
3207	cpe-2606-A000-6B84-3DF0-38C0-485C-3C5D-333A.dyn6.twc.com	2019-03-19 06:14:58.172352-07
3208	cpe-2606-A000-6B84-3DF0-38C0-485C-3C5D-333A.dyn6.twc.com	2019-03-19 06:21:36.765607-07
3209	cpe-2606-A000-6B84-3DF0-38C0-485C-3C5D-333A.dyn6.twc.com	2019-03-19 06:51:23.669656-07
3210	cpe-2606-A000-6B84-3DF0-38C0-485C-3C5D-333A.dyn6.twc.com	2019-03-19 07:04:58.067788-07
3211	cpe-2606-A000-6B84-3DF0-38C0-485C-3C5D-333A.dyn6.twc.com	2019-03-19 07:20:38.766536-07
3212	190.147.153.196	2019-03-19 07:25:56.605313-07
3213	cpe-2606-A000-6B84-3DF0-38C0-485C-3C5D-333A.dyn6.twc.com	2019-03-19 07:34:14.76323-07
3214	cpe-2606-A000-6B84-3DF0-38C0-485C-3C5D-333A.dyn6.twc.com	2019-03-19 07:53:30.046675-07
3215	cpe-2606-A000-6B84-3DF0-38C0-485C-3C5D-333A.dyn6.twc.com	2019-03-19 08:11:00.639138-07
3216	cpe-2606-A000-6B84-3DF0-38C0-485C-3C5D-333A.dyn6.twc.com	2019-03-19 08:24:23.732589-07
3217	cpe-2606-A000-6B84-3DF0-38C0-485C-3C5D-333A.dyn6.twc.com	2019-03-19 09:07:38.794278-07
3218	cpe-2606-A000-6B84-3DF0-38C0-485C-3C5D-333A.dyn6.twc.com	2019-03-19 09:36:38.084815-07
3219	cpe-2606-A000-6B84-3DF0-38C0-485C-3C5D-333A.dyn6.twc.com	2019-03-19 09:53:42.25038-07
3220	cpe-2606-A000-6B84-3DF0-38C0-485C-3C5D-333A.dyn6.twc.com	2019-03-19 10:14:49.7924-07
3221	cpe-2606-A000-6B84-3DF0-38C0-485C-3C5D-333A.dyn6.twc.com	2019-03-19 10:23:22.76907-07
3222	cpe-2606-A000-6B84-3DF0-38C0-485C-3C5D-333A.dyn6.twc.com	2019-03-19 10:39:03.686118-07
3223	cpe-2606-A000-6B84-3DF0-38C0-485C-3C5D-333A.dyn6.twc.com	2019-03-19 11:00:07.785739-07
3224	cpe-2606-A000-6B84-3DF0-38C0-485C-3C5D-333A.dyn6.twc.com	2019-03-19 11:17:34.313635-07
3225	cpe-2606-A000-6B84-3DF0-38C0-485C-3C5D-333A.dyn6.twc.com	2019-03-19 11:23:05.759646-07
3226	cpe-2606-A000-6B84-3DF0-38C0-485C-3C5D-333A.dyn6.twc.com	2019-03-19 11:40:24.070991-07
3227	cpe-2606-A000-6B84-3DF0-38C0-485C-3C5D-333A.dyn6.twc.com	2019-03-19 11:56:49.66228-07
3228	190.147.153.196	2019-03-19 11:59:27.706652-07
3229	cpe-2606-A000-6B84-3DF0-38C0-485C-3C5D-333A.dyn6.twc.com	2019-03-19 12:11:10.795246-07
3230	cpe-2606-A000-6B84-3DF0-38C0-485C-3C5D-333A.dyn6.twc.com	2019-03-19 12:26:26.302773-07
3231	cpe-2606-A000-6B84-3DF0-38C0-485C-3C5D-333A.dyn6.twc.com	2019-03-19 12:34:27.76498-07
3232	190.147.153.196	2019-03-19 12:38:18.517664-07
3233	cpe-2606-A000-6B84-3DF0-38C0-485C-3C5D-333A.dyn6.twc.com	2019-03-19 12:42:54.61327-07
3234	cpe-2606-A000-6B84-3DF0-38C0-485C-3C5D-333A.dyn6.twc.com	2019-03-19 12:53:47.667282-07
3235	190.147.153.196	2019-03-19 12:56:06.923237-07
3236	190.147.153.196	2019-03-19 13:09:30.056949-07
3237	cpe-2606-A000-6B84-3DF0-38C0-485C-3C5D-333A.dyn6.twc.com	2019-03-19 13:10:44.11602-07
3238	190.147.153.196	2019-03-19 13:27:11.573745-07
3239	190.147.153.196	2019-03-19 13:48:39.858143-07
3240	190.147.153.196	2019-03-19 14:25:41.345575-07
3241	190.147.153.196	2019-03-19 14:44:36.343105-07
3242	190.147.153.196	2019-03-19 16:34:20.53349-07
3243	190.147.153.196	2019-03-19 16:43:10.208802-07
3244	cpe-2606-A000-6B84-3DF0-9851-BAB3-9E47-EBCF.dyn6.twc.com	2019-03-20 02:12:47.807835-07
3245	cpe-2606-A000-6B84-3DF0-9851-BAB3-9E47-EBCF.dyn6.twc.com	2019-03-20 05:06:59.731339-07
3246	cpe-2606-A000-6B84-3DF0-9851-BAB3-9E47-EBCF.dyn6.twc.com	2019-03-20 05:13:05.761796-07
3247	cpe-2606-A000-6B84-3DF0-9851-BAB3-9E47-EBCF.dyn6.twc.com	2019-03-20 05:34:53.246041-07
3248	cpe-2606-A000-6B84-3DF0-9851-BAB3-9E47-EBCF.dyn6.twc.com	2019-03-20 05:45:48.055554-07
3249	cpe-2606-A000-6B84-3DF0-9851-BAB3-9E47-EBCF.dyn6.twc.com	2019-03-20 07:00:11.775322-07
3250	190.147.153.196	2019-03-20 08:40:27.923139-07
3251	190.147.153.196	2019-03-20 08:49:09.467832-07
3252	cpe-2606-A000-6B84-3DF0-9851-BAB3-9E47-EBCF.dyn6.twc.com	2019-03-20 10:01:58.372184-07
3253	cpe-2606-A000-6B84-3DF0-9851-BAB3-9E47-EBCF.dyn6.twc.com	2019-03-20 10:06:24.293617-07
3254	cpe-2606-A000-6B84-3DF0-9851-BAB3-9E47-EBCF.dyn6.twc.com	2019-03-20 10:21:05.760806-07
3255	cpe-2606-A000-6B84-3DF0-9851-BAB3-9E47-EBCF.dyn6.twc.com	2019-03-20 11:07:49.246715-07
3256	cpe-2606-A000-6B84-3DF0-9851-BAB3-9E47-EBCF.dyn6.twc.com	2019-03-20 11:28:30.728746-07
3257	cpe-2606-A000-6B84-3DF0-9851-BAB3-9E47-EBCF.dyn6.twc.com	2019-03-20 11:44:02.312483-07
3258	cpe-2606-A000-6B84-3DF0-9851-BAB3-9E47-EBCF.dyn6.twc.com	2019-03-20 12:02:59.253277-07
3259	cpe-2606-A000-6B84-3DF0-9851-BAB3-9E47-EBCF.dyn6.twc.com	2019-03-20 12:23:36.904182-07
3260	cpe-2606-A000-6B84-3DF0-9851-BAB3-9E47-EBCF.dyn6.twc.com	2019-03-20 12:48:33.717338-07
3261	cpe-2606-A000-6B84-3DF0-9851-BAB3-9E47-EBCF.dyn6.twc.com	2019-03-20 13:12:48.799235-07
3262	cpe-2606-A000-6B84-3DF0-9851-BAB3-9E47-EBCF.dyn6.twc.com	2019-03-20 13:23:55.286601-07
3263	190.147.153.196	2019-03-20 19:01:57.017839-07
3264	cpe-2606-A000-6B84-3DF0-38B9-EDB6-2344-5D79.dyn6.twc.com	2019-03-21 04:38:25.231758-07
3265	cpe-2606-A000-6B84-3DF0-38B9-EDB6-2344-5D79.dyn6.twc.com	2019-03-21 06:38:09.708761-07
3266	cpe-2606-A000-6B84-3DF0-38B9-EDB6-2344-5D79.dyn6.twc.com	2019-03-21 07:31:13.673296-07
3267	190.147.153.196	2019-03-21 08:14:04.298418-07
3268	cpe-2606-A000-6B84-3DF0-38B9-EDB6-2344-5D79.dyn6.twc.com	2019-03-21 09:03:23.662463-07
3269	cpe-2606-A000-6B84-3DF0-38B9-EDB6-2344-5D79.dyn6.twc.com	2019-03-21 09:52:06.699665-07
3270	cpe-2606-A000-6B84-3DF0-38B9-EDB6-2344-5D79.dyn6.twc.com	2019-03-21 10:42:01.651455-07
3271	cpe-2606-A000-6B84-3DF0-38B9-EDB6-2344-5D79.dyn6.twc.com	2019-03-21 11:45:43.687381-07
3272	190.147.153.196	2019-03-21 12:07:28.838408-07
3273	cpe-2606-A000-6B84-3DF0-38B9-EDB6-2344-5D79.dyn6.twc.com	2019-03-21 13:22:20.702316-07
3274	190.147.153.196	2019-03-21 13:46:43.751474-07
3275	190.147.153.196	2019-03-21 14:35:08.796843-07
3276	190.147.153.196	2019-03-21 15:51:42.649588-07
3277	190.147.153.196	2019-03-21 18:48:05.904735-07
3278	cpe-2606-A000-6B84-3DF0-970-D13A-CA39-A9B7.dyn6.twc.com	2019-03-22 03:52:27.857154-07
3279	cpe-2606-A000-6B84-3DF0-970-D13A-CA39-A9B7.dyn6.twc.com	2019-03-22 05:17:45.695789-07
3280	cpe-2606-A000-6B84-3DF0-3194-9AC9-43E8-F831.dyn6.twc.com	2019-03-22 06:08:29.797577-07
3281	cpe-69-132-97-204.carolina.res.rr.com	2019-03-22 06:50:18.899297-07
3282	cpe-2606-A000-6B84-3DF0-3194-9AC9-43E8-F831.dyn6.twc.com	2019-03-22 07:01:08.780266-07
3283	cpe-2606-A000-6B84-3DF0-3194-9AC9-43E8-F831.dyn6.twc.com	2019-03-22 07:10:29.131815-07
3284	190.147.153.196	2019-03-22 07:44:33.247698-07
3285	cpe-2606-A000-6B84-3DF0-3194-9AC9-43E8-F831.dyn6.twc.com	2019-03-22 08:09:04.232674-07
3286	cpe-2606-A000-6B84-3DF0-3194-9AC9-43E8-F831.dyn6.twc.com	2019-03-22 09:09:39.25413-07
3287	cpe-69-132-97-204.carolina.res.rr.com	2019-03-22 10:44:00.40609-07
3288	cpe-2606-A000-6B84-3DF0-3194-9AC9-43E8-F831.dyn6.twc.com	2019-03-22 10:49:34.156539-07
3289	cpe-2606-A000-6B84-3DF0-3194-9AC9-43E8-F831.dyn6.twc.com	2019-03-22 11:44:09.071196-07
3290	cpe-69-132-97-204.carolina.res.rr.com	2019-03-22 12:34:05.413851-07
3291	cpe-2606-A000-6B84-3DF0-3194-9AC9-43E8-F831.dyn6.twc.com	2019-03-22 12:44:49.120845-07
3292	190.147.153.196	2019-03-22 15:24:33.376598-07
3293	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2019-03-25 09:49:28.355292-07
3294	cpe-2606-A000-6B84-3DF0-6DB8-18A2-7AF0-FE36.dyn6.twc.com	2019-03-25 10:23:38.23221-07
3295	cpe-2606-A000-6B84-3DF0-F1DA-60E6-F8F6-1550.dyn6.twc.com	2019-03-26 06:46:05.582488-07
3296	cpe-2606-A000-6B84-3DF0-F1DA-60E6-F8F6-1550.dyn6.twc.com	2019-03-26 07:36:10.136012-07
3297	190.147.153.196	2019-03-26 08:18:54.95019-07
3298	cpe-2606-A000-6B84-3DF0-F1DA-60E6-F8F6-1550.dyn6.twc.com	2019-03-26 08:42:38.188428-07
3299	190.147.153.196	2019-03-26 09:26:21.383497-07
3300	cpe-2606-A000-6B84-3DF0-F1DA-60E6-F8F6-1550.dyn6.twc.com	2019-03-26 09:35:43.056652-07
3301	cpe-2606-A000-6B84-3DF0-F1DA-60E6-F8F6-1550.dyn6.twc.com	2019-03-26 10:33:41.187246-07
3302	cpe-69-132-97-204.carolina.res.rr.com	2019-03-26 11:24:40.530766-07
3303	cpe-2606-A000-6B84-3DF0-F1DA-60E6-F8F6-1550.dyn6.twc.com	2019-03-26 11:35:18.188956-07
3304	190.147.153.196	2019-03-26 11:44:58.068359-07
3305	cpe-2606-A000-6B84-3DF0-F1DA-60E6-F8F6-1550.dyn6.twc.com	2019-03-26 12:28:15.282558-07
3306	190.147.153.196	2019-03-26 12:37:39.914579-07
3307	190.147.153.196	2019-03-26 12:46:39.864504-07
3308	190.147.153.196	2019-03-26 13:07:24.291879-07
3309	190.147.153.196	2019-03-26 13:27:57.861832-07
3310	190.147.153.196	2019-03-26 14:13:32.046123-07
3311	190.147.153.196	2019-03-26 14:18:33.207493-07
3312	190.147.153.196	2019-03-26 14:57:28.117707-07
3313	190.147.153.196	2019-03-26 15:58:10.510197-07
3314	190.147.153.196	2019-03-26 16:51:26.579647-07
3315	cpe-2606-A000-6B84-3DF0-1C1B-9665-2250-E3B2.dyn6.twc.com	2019-03-27 05:09:38.358538-07
3316	cpe-2606-A000-6B84-3DF0-1C1B-9665-2250-E3B2.dyn6.twc.com	2019-03-27 07:00:10.228447-07
3317	cpe-69-132-97-204.carolina.res.rr.com	2019-03-27 08:52:20.558339-07
3318	cpe-2606-A000-6B84-3DF0-1C1B-9665-2250-E3B2.dyn6.twc.com	2019-03-27 08:54:48.208284-07
3319	cpe-2606-A000-6B84-3DF0-1C1B-9665-2250-E3B2.dyn6.twc.com	2019-03-27 09:11:54.796863-07
3320	cpe-2606-A000-6B84-3DF0-1C1B-9665-2250-E3B2.dyn6.twc.com	2019-03-27 09:44:27.203393-07
3321	190.147.153.196	2019-03-27 10:31:39.197133-07
3322	cpe-2606-A000-6B84-3DF0-1C1B-9665-2250-E3B2.dyn6.twc.com	2019-03-27 11:52:04.133645-07
3323	cpe-2606-A000-6B84-3DF0-1C1B-9665-2250-E3B2.dyn6.twc.com	2019-03-27 12:46:05.547083-07
3324	190.147.153.196	2019-03-27 13:11:23.242433-07
3325	190.147.153.196	2019-03-27 13:13:32.314835-07
3326	190.147.153.196	2019-03-27 13:31:05.404695-07
3327	190.147.153.196	2019-03-27 13:51:34.892042-07
3328	190.147.153.196	2019-03-27 14:52:11.828939-07
3329	190.147.153.196	2019-03-27 15:04:33.106723-07
3330	190.147.153.196	2019-03-27 15:43:30.878999-07
3331	190.147.153.196	2019-03-27 16:44:25.09211-07
3332	190.147.153.196	2019-03-27 16:49:12.988735-07
3333	190.147.153.196	2019-03-27 17:01:32.224215-07
3334	190.147.153.196	2019-03-27 17:33:11.026722-07
3335	190.147.153.196	2019-03-27 18:00:50.445966-07
3336	190.147.153.196	2019-03-27 18:03:03.963915-07
3337	190.147.153.196	2019-03-28 09:28:53.342816-07
3338	190.147.153.196	2019-03-28 12:23:04.190427-07
3339	190.147.153.196	2019-03-28 12:41:57.881116-07
3340	190.147.153.196	2019-03-28 13:02:44.489482-07
3341	190.147.153.196	2019-03-28 13:12:15.394674-07
3342	190.147.153.196	2019-03-28 13:31:17.833966-07
3343	cpe-2606-A000-6B84-3DF0-39C8-9FBF-B47A-890D.dyn6.twc.com	2019-03-28 13:36:18.166659-07
3344	190.147.153.196	2019-03-28 13:52:13.19384-07
3345	190.147.153.196	2019-03-28 14:40:10.62202-07
3346	190.147.153.196	2019-03-28 14:55:48.18719-07
3347	190.147.153.196	2019-03-28 15:19:58.08969-07
3348	190.147.153.196	2019-03-28 15:25:06.160511-07
3349	190.147.153.196	2019-03-28 15:53:23.283623-07
3350	190.147.153.196	2019-03-28 15:55:34.195814-07
3351	190.147.153.196	2019-03-28 16:53:51.086453-07
3352	190.147.153.196	2019-03-28 16:55:54.43031-07
3353	190.147.153.196	2019-03-28 17:14:39.481318-07
3354	190.147.153.196	2019-03-28 17:35:24.043901-07
3355	190.147.153.196	2019-03-29 08:30:22.090099-07
3356	cpe-2606-A000-6B84-3DF0-3101-523C-38D9-B1BF.dyn6.twc.com	2019-03-29 08:40:36.219278-07
3357	190.147.153.196	2019-03-29 09:37:28.285332-07
3358	cpe-69-132-97-204.carolina.res.rr.com	2019-03-29 10:06:42.226833-07
3359	cpe-2606-A000-6B84-3DF0-3101-523C-38D9-B1BF.dyn6.twc.com	2019-03-29 10:09:16.142959-07
3360	cpe-2606-A000-6B84-3DF0-3101-523C-38D9-B1BF.dyn6.twc.com	2019-03-29 11:00:28.086859-07
3361	cpe-2606-A000-6B84-3DF0-3101-523C-38D9-B1BF.dyn6.twc.com	2019-03-29 11:49:55.128766-07
3362	cpe-2606-A000-6B84-3DF0-3101-523C-38D9-B1BF.dyn6.twc.com	2019-03-29 12:40:35.057683-07
3363	cpe-2606-A000-6B84-3DF0-3101-523C-38D9-B1BF.dyn6.twc.com	2019-03-29 13:35:24.123511-07
3364	cpe-2606-A000-6B84-3DF0-3101-523C-38D9-B1BF.dyn6.twc.com	2019-03-29 14:30:15.101422-07
3365	190.147.153.196	2019-03-29 15:01:54.192891-07
3366	190.147.153.196	2019-03-29 15:02:51.906016-07
3367	cpe-2606-A000-6B84-3DF0-68EF-7212-8566-BEDD.dyn6.twc.com	2019-04-01 05:16:24.256376-07
3368	190.147.153.196	2019-04-01 07:45:44.295842-07
3369	190.147.153.196	2019-04-01 07:47:33.976209-07
3370	190.147.153.196	2019-04-01 08:01:06.750808-07
3371	190.147.153.196	2019-04-01 09:04:03.95029-07
3372	190.147.153.196	2019-04-01 09:23:26.446862-07
3373	190.147.153.196	2019-04-01 09:33:56.777183-07
3374	190.147.153.196	2019-04-01 09:55:26.988387-07
3375	190.147.153.196	2019-04-01 10:16:16.431552-07
3376	190.147.153.196	2019-04-01 10:22:22.128761-07
3377	190.147.153.196	2019-04-01 10:41:11.032383-07
3378	190.147.153.196	2019-04-01 11:02:09.897045-07
3379	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2019-04-01 11:09:08.280305-07
3380	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2019-04-01 11:09:26.395749-07
3381	cpe-69-132-97-204.carolina.res.rr.com	2019-04-01 11:27:44.01535-07
3382	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2019-04-01 11:30:50.055243-07
3383	cpe-2606-A000-6B84-3DF0-68EF-7212-8566-BEDD.dyn6.twc.com	2019-04-01 11:34:44.775193-07
3384	190.147.153.196	2019-04-01 11:43:01.402329-07
3385	cpe-2606-A000-6B84-3DF0-68EF-7212-8566-BEDD.dyn6.twc.com	2019-04-01 11:50:11.485333-07
3386	190.147.153.196	2019-04-01 11:51:43.094968-07
3387	190.147.153.196	2019-04-01 12:05:48.961297-07
3388	cpe-2606-A000-6B84-3DF0-68EF-7212-8566-BEDD.dyn6.twc.com	2019-04-01 12:06:14.167199-07
3389	cpe-2606-A000-6B84-3DF0-68EF-7212-8566-BEDD.dyn6.twc.com	2019-04-01 12:51:20.723172-07
3390	190.147.153.196	2019-04-01 13:21:20.92539-07
3391	190.147.153.196	2019-04-01 13:23:43.925672-07
3392	190.147.153.196	2019-04-01 13:38:45.002314-07
3393	190.147.153.196	2019-04-01 13:57:37.220296-07
3394	190.147.153.196	2019-04-01 14:18:30.810217-07
3395	190.147.153.196	2019-04-01 15:01:23.296465-07
3396	190.147.153.196	2019-04-01 15:10:24.326557-07
3397	190.147.153.196	2019-04-01 15:24:08.82721-07
3398	cpe-2606-A000-6B84-3DF0-149C-85FD-895D-27CE.dyn6.twc.com	2019-04-02 04:15:26.457555-07
3399	cpe-2606-A000-6B84-3DF0-149C-85FD-895D-27CE.dyn6.twc.com	2019-04-02 04:54:29.932963-07
3400	cpe-2606-A000-6B84-3DF0-149C-85FD-895D-27CE.dyn6.twc.com	2019-04-02 05:08:51.076838-07
3401	cpe-2606-A000-6B84-3DF0-149C-85FD-895D-27CE.dyn6.twc.com	2019-04-02 05:26:07.807474-07
3402	cpe-2606-A000-6B84-3DF0-149C-85FD-895D-27CE.dyn6.twc.com	2019-04-02 05:58:17.133853-07
3403	cpe-2606-A000-6B84-3DF0-149C-85FD-895D-27CE.dyn6.twc.com	2019-04-02 06:14:11.355988-07
3404	cpe-2606-A000-6B84-3DF0-149C-85FD-895D-27CE.dyn6.twc.com	2019-04-02 06:51:26.130984-07
3405	cpe-2606-A000-6B84-3DF0-149C-85FD-895D-27CE.dyn6.twc.com	2019-04-02 07:15:22.80216-07
3406	cpe-2606-A000-6B84-3DF0-149C-85FD-895D-27CE.dyn6.twc.com	2019-04-02 07:44:16.174847-07
3407	cpe-2606-A000-6B84-3DF0-149C-85FD-895D-27CE.dyn6.twc.com	2019-04-02 08:04:49.746996-07
3408	190.147.153.196	2019-04-02 09:18:43.152985-07
3409	cpe-2606-A000-6B84-3DF0-149C-85FD-895D-27CE.dyn6.twc.com	2019-04-02 09:28:41.42795-07
3410	cpe-2606-A000-6B84-3DF0-149C-85FD-895D-27CE.dyn6.twc.com	2019-04-02 12:42:19.413408-07
3411	cpe-2606-A000-6B84-3DF0-149C-85FD-895D-27CE.dyn6.twc.com	2019-04-02 13:22:07.060552-07
3412	cpe-2606-A000-6B84-3DF0-149C-85FD-895D-27CE.dyn6.twc.com	2019-04-02 14:34:23.26837-07
3413	cpe-2606-A000-6B84-3DF0-149C-85FD-895D-27CE.dyn6.twc.com	2019-04-02 14:37:05.176507-07
3414	190.147.153.196	2019-04-03 08:54:34.87846-07
3415	190.147.153.196	2019-04-03 12:26:39.526779-07
3416	190.147.153.196	2019-04-03 12:43:25.872845-07
3417	190.147.153.196	2019-04-03 12:59:09.908132-07
3418	cpe-2606-A000-6B84-3DF0-B8A1-F308-11F3-9A61.dyn6.twc.com	2019-04-03 13:17:55.204317-07
3419	190.147.153.196	2019-04-03 13:19:56.286059-07
3420	190.147.153.196	2019-04-03 14:20:40.377216-07
3421	190.147.153.196	2019-04-03 14:58:53.65666-07
3422	190.147.153.196	2019-04-03 15:01:40.402203-07
3423	190.147.153.196	2019-04-03 15:18:51.759594-07
3424	190.147.153.196	2019-04-03 15:45:34.372605-07
3425	190.147.153.196	2019-04-03 16:04:42.914598-07
3426	190.147.153.196	2019-04-03 17:04:10.642155-07
3427	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2019-04-04 06:56:12.311491-07
3428	cpe-2606-A000-6B84-3DF0-ACD7-BA1C-3137-C4CB.dyn6.twc.com	2019-04-04 07:56:09.169786-07
3429	cpe-69-132-97-204.carolina.res.rr.com	2019-04-04 08:53:18.449253-07
3430	cpe-2606-A000-6B84-3DF0-ACD7-BA1C-3137-C4CB.dyn6.twc.com	2019-04-04 08:55:23.223491-07
3431	190.147.153.196	2019-04-04 08:56:14.086024-07
3432	cpe-2606-A000-6B84-3DF0-ACD7-BA1C-3137-C4CB.dyn6.twc.com	2019-04-04 09:11:49.426753-07
3433	cpe-2606-A000-6B84-3DF0-ACD7-BA1C-3137-C4CB.dyn6.twc.com	2019-04-04 09:22:16.219994-07
3434	cpe-2606-A000-6B84-3DF0-ACD7-BA1C-3137-C4CB.dyn6.twc.com	2019-04-04 10:10:45.082478-07
3435	cpe-2606-A000-6B84-3DF0-ACD7-BA1C-3137-C4CB.dyn6.twc.com	2019-04-04 10:34:58.729322-07
3436	cpe-2606-A000-6B84-3DF0-ACD7-BA1C-3137-C4CB.dyn6.twc.com	2019-04-04 10:59:14.265374-07
3437	cpe-2606-A000-6B84-3DF0-ACD7-BA1C-3137-C4CB.dyn6.twc.com	2019-04-04 11:09:52.128193-07
3438	cpe-2606-A000-6B84-3DF0-ACD7-BA1C-3137-C4CB.dyn6.twc.com	2019-04-04 11:49:31.058755-07
3439	cpe-2606-A000-6B84-3DF0-ACD7-BA1C-3137-C4CB.dyn6.twc.com	2019-04-04 11:58:22.141485-07
3440	190.147.153.196	2019-04-04 12:42:33.862494-07
3441	cpe-2606-A000-6B84-3DF0-ACD7-BA1C-3137-C4CB.dyn6.twc.com	2019-04-04 13:19:44.350367-07
3442	cpe-2606-A000-6B84-3DF0-ACD7-BA1C-3137-C4CB.dyn6.twc.com	2019-04-04 13:26:08.179657-07
3443	190.147.153.196	2019-04-04 17:15:11.964466-07
3444	190.147.153.196	2019-04-05 09:57:20.806949-07
3445	190.147.153.196	2019-04-05 15:21:12.49342-07
3446	cpe-2606-A000-6B84-3DF0-C1B2-14A2-9A87-670F.dyn6.twc.com	2019-04-08 02:57:12.342809-07
3447	cpe-2606-A000-6B84-3DF0-C1B2-14A2-9A87-670F.dyn6.twc.com	2019-04-08 05:12:34.077263-07
3448	cpe-2606-A000-6B84-3DF0-C1B2-14A2-9A87-670F.dyn6.twc.com	2019-04-08 07:00:14.732067-07
3449	190.147.153.196	2019-04-08 08:18:43.962487-07
3450	cpe-2606-A000-6B84-3DF0-C1B2-14A2-9A87-670F.dyn6.twc.com	2019-04-08 11:20:47.539637-07
3451	cpe-2606-A000-6B84-3DF0-C1B2-14A2-9A87-670F.dyn6.twc.com	2019-04-08 11:28:20.823646-07
3452	cpe-2606-A000-6B84-3DF0-C1B2-14A2-9A87-670F.dyn6.twc.com	2019-04-08 11:33:52.416805-07
3453	cpe-2606-A000-6B84-3DF0-C1B2-14A2-9A87-670F.dyn6.twc.com	2019-04-08 11:50:35.090503-07
3454	cpe-2606-A000-6B84-3DF0-C1B2-14A2-9A87-670F.dyn6.twc.com	2019-04-08 12:01:15.744356-07
3455	cpe-2606-A000-6B84-3DF0-C1B2-14A2-9A87-670F.dyn6.twc.com	2019-04-08 13:09:14.794739-07
3456	cpe-2606-A000-6B84-3DF0-C1B2-14A2-9A87-670F.dyn6.twc.com	2019-04-08 13:14:00.399521-07
3457	cpe-2606-A000-6B84-3DF0-D8DB-2253-85D2-D1C7.dyn6.twc.com	2019-04-09 07:12:29.783505-07
3458	190.147.153.196	2019-04-09 08:27:18.093804-07
3459	190.147.153.196	2019-04-09 09:50:43.906141-07
3460	190.147.153.196	2019-04-09 10:38:43.231232-07
3461	190.147.153.196	2019-04-09 11:06:32.921141-07
3462	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2019-04-10 06:35:05.375054-07
3463	190.147.153.196	2019-04-10 12:02:33.925715-07
3464	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2019-04-11 08:41:13.681001-07
3465	cpe-2606-A000-6B84-3DF0-D57C-A160-3E8E-8461.dyn6.twc.com	2019-04-12 06:56:17.236357-07
3466	cpe-2606-A000-6B84-3DF0-D57C-A160-3E8E-8461.dyn6.twc.com	2019-04-12 08:00:16.357776-07
3467	cpe-2606-A000-6B84-3DF0-D57C-A160-3E8E-8461.dyn6.twc.com	2019-04-12 08:19:53.383395-07
3468	cpe-2606-A000-6B84-3DF0-D57C-A160-3E8E-8461.dyn6.twc.com	2019-04-12 08:39:53.331138-07
3469	cpe-2606-A000-6B84-3DF0-D57C-A160-3E8E-8461.dyn6.twc.com	2019-04-12 08:45:42.624005-07
3470	cpe-2606-A000-6B84-3DF0-D57C-A160-3E8E-8461.dyn6.twc.com	2019-04-12 10:12:29.938738-07
3471	cpe-2606-A000-6B84-3DF0-D57C-A160-3E8E-8461.dyn6.twc.com	2019-04-12 10:22:52.351285-07
3472	cpe-2606-A000-6B84-3DF0-D57C-A160-3E8E-8461.dyn6.twc.com	2019-04-12 10:36:14.120512-07
3473	cpe-69-132-97-204.carolina.res.rr.com	2019-04-12 11:30:14.380837-07
3474	190.147.153.196	2019-04-12 16:31:09.720615-07
3475	cpe-2606-A000-6B84-3DF0-F5EA-E476-FE18-39E2.dyn6.twc.com	2019-04-15 03:27:04.684152-07
3476	cpe-2606-A000-6B84-3DF0-F5EA-E476-FE18-39E2.dyn6.twc.com	2019-04-15 03:58:47.436135-07
3477	cpe-2606-A000-6B84-3DF0-F5EA-E476-FE18-39E2.dyn6.twc.com	2019-04-15 04:29:26.352401-07
3478	cpe-2606-A000-6B84-3DF0-F5EA-E476-FE18-39E2.dyn6.twc.com	2019-04-15 04:44:02.211107-07
3479	cpe-2606-A000-6B84-3DF0-F5EA-E476-FE18-39E2.dyn6.twc.com	2019-04-15 05:01:18.482845-07
3480	cpe-2606-A000-6B84-3DF0-F5EA-E476-FE18-39E2.dyn6.twc.com	2019-04-15 05:32:37.404009-07
3481	cpe-2606-A000-6B84-3DF0-F5EA-E476-FE18-39E2.dyn6.twc.com	2019-04-15 05:57:37.307575-07
3482	cpe-2606-A000-6B84-3DF0-F5EA-E476-FE18-39E2.dyn6.twc.com	2019-04-15 06:02:57.757887-07
3483	cpe-2606-A000-6B84-3DF0-F5EA-E476-FE18-39E2.dyn6.twc.com	2019-04-15 06:24:48.123908-07
3484	cpe-2606-A000-6B84-3DF0-F5EA-E476-FE18-39E2.dyn6.twc.com	2019-04-15 10:15:19.073937-07
3485	cpe-2606-A000-6B84-3DF0-F5EA-E476-FE18-39E2.dyn6.twc.com	2019-04-15 10:28:23.40674-07
3486	cpe-2606-A000-6B84-3DF0-F5EA-E476-FE18-39E2.dyn6.twc.com	2019-04-15 10:39:59.789787-07
3487	cpe-2606-A000-6B84-3DF0-F5EA-E476-FE18-39E2.dyn6.twc.com	2019-04-15 11:09:48.711783-07
3488	cpe-2606-A000-6B84-3DF0-F5EA-E476-FE18-39E2.dyn6.twc.com	2019-04-15 11:24:37.108183-07
3489	cpe-2606-A000-6B84-3DF0-F5EA-E476-FE18-39E2.dyn6.twc.com	2019-04-15 11:47:24.367762-07
3490	cpe-2606-A000-6B84-3DF0-F5EA-E476-FE18-39E2.dyn6.twc.com	2019-04-15 12:07:56.363351-07
3491	cpe-2606-A000-6B84-3DF0-F5EA-E476-FE18-39E2.dyn6.twc.com	2019-04-15 12:10:48.802554-07
3492	cpe-2606-A000-6B84-3DF0-F5EA-E476-FE18-39E2.dyn6.twc.com	2019-04-15 12:56:42.35436-07
3493	cpe-2606-A000-6B84-3DF0-F5EA-E476-FE18-39E2.dyn6.twc.com	2019-04-15 13:12:25.115725-07
3494	cpe-2606-A000-6B84-3DF0-F5EA-E476-FE18-39E2.dyn6.twc.com	2019-04-15 13:43:02.087946-07
3495	cpe-2606-A000-6B84-3DF0-F5EA-E476-FE18-39E2.dyn6.twc.com	2019-04-15 13:59:37.401614-07
3496	cpe-2606-A000-6B84-3DF0-F5EA-E476-FE18-39E2.dyn6.twc.com	2019-04-15 14:14:18.25049-07
3497	cpe-2606-A000-6B84-3DF0-24F3-6BF2-3CEC-D093.dyn6.twc.com	2019-04-16 02:38:21.134814-07
3498	cpe-2606-A000-6B84-3DF0-495D-62C4-DC3-62AB.dyn6.twc.com	2019-04-18 09:38:37.402066-07
3499	cpe-2606-A000-6B84-3DF0-495D-62C4-DC3-62AB.dyn6.twc.com	2019-04-18 11:00:33.294119-07
3500	cpe-2606-A000-6B84-3DF0-495D-62C4-DC3-62AB.dyn6.twc.com	2019-04-18 12:10:57.71693-07
3501	cpe-2606-A000-6B84-3DF0-495D-62C4-DC3-62AB.dyn6.twc.com	2019-04-18 12:19:20.388703-07
3502	cpe-2606-A000-6B84-3DF0-495D-62C4-DC3-62AB.dyn6.twc.com	2019-04-18 14:39:24.386077-07
3503	cpe-2606-A000-6B84-3DF0-3C27-EF25-BF3E-20DF.dyn6.twc.com	2019-04-22 11:32:07.720577-07
3504	cpe-2606-A000-6B84-3DF0-3C27-EF25-BF3E-20DF.dyn6.twc.com	2019-04-22 12:46:07.641812-07
3505	cpe-2606-A000-6B84-3DF0-B9-D5E5-1A19-C9F2.dyn6.twc.com	2019-04-23 10:10:33.624947-07
3506	cpe-2606-A000-6B84-3DF0-B9-D5E5-1A19-C9F2.dyn6.twc.com	2019-04-23 10:59:57.625584-07
3507	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2019-04-23 11:25:11.839395-07
3508	cpe-2606-A000-6B84-3DF0-B9-D5E5-1A19-C9F2.dyn6.twc.com	2019-04-23 11:49:17.643089-07
3509	cpe-2606-A000-6B84-3DF0-B9-D5E5-1A19-C9F2.dyn6.twc.com	2019-04-23 12:42:27.686012-07
3510	cpe-2606-A000-6B84-3DF0-49A3-A9E9-6923-476D.dyn6.twc.com	2019-04-24 02:59:38.864008-07
3511	cpe-69-132-97-204.carolina.res.rr.com	2019-04-24 03:41:32.693417-07
3512	cpe-2606-A000-6B84-3DF0-ED23-32E9-673E-958.dyn6.twc.com	2019-04-25 03:24:58.728865-07
3513	cpe-2606-A000-6B84-3DF0-ED23-32E9-673E-958.dyn6.twc.com	2019-04-25 04:31:45.675875-07
3514	cpe-2606-A000-6B84-3DF0-ED23-32E9-673E-958.dyn6.twc.com	2019-04-25 05:20:17.681751-07
3515	cpe-2606-A000-6B84-3DF0-A86E-BD3D-C2A2-AEA2.dyn6.twc.com	2019-04-25 11:05:55.623884-07
3516	cpe-2606-A000-6B84-3DF0-A86E-BD3D-C2A2-AEA2.dyn6.twc.com	2019-04-25 12:18:03.69329-07
3517	cpe-2606-A000-6B84-3DF0-64BA-C645-A38E-5598.dyn6.twc.com	2019-04-26 02:51:18.624029-07
3518	cpe-2606-A000-6B84-3DF0-64BA-C645-A38E-5598.dyn6.twc.com	2019-04-26 05:30:15.63229-07
3519	cpe-2606-A000-6B84-3DF0-64BA-C645-A38E-5598.dyn6.twc.com	2019-04-26 06:19:48.650609-07
3520	cpe-69-132-97-204.carolina.res.rr.com	2019-04-26 07:08:35.928697-07
3521	cpe-2606-A000-6B84-3DF0-64BA-C645-A38E-5598.dyn6.twc.com	2019-04-26 07:47:06.733822-07
3522	cpe-69-132-97-204.carolina.res.rr.com	2019-04-26 08:06:05.891207-07
3523	cpe-2606-A000-6B84-3DF0-896B-9DC3-D497-A92.dyn6.twc.com	2019-04-29 04:00:18.688391-07
3524	cpe-2606-A000-6B84-3DF0-896B-9DC3-D497-A92.dyn6.twc.com	2019-04-29 04:55:18.602674-07
3525	cpe-2606-A000-6B84-3DF0-896B-9DC3-D497-A92.dyn6.twc.com	2019-04-29 05:43:44.599593-07
3526	cpe-2606-A000-6B84-3DF0-896B-9DC3-D497-A92.dyn6.twc.com	2019-04-29 06:45:16.601603-07
3527	cpe-2606-A000-6B84-3DF0-896B-9DC3-D497-A92.dyn6.twc.com	2019-04-29 11:30:15.598276-07
3528	cpe-2606-A000-6B84-3DF0-896B-9DC3-D497-A92.dyn6.twc.com	2019-04-29 13:30:16.879006-07
3529	cpe-2606-A000-6B84-3DF0-896B-9DC3-D497-A92.dyn6.twc.com	2019-04-29 15:30:11.667048-07
3530	cpe-2606-A000-6B84-3DF0-896B-9DC3-D497-A92.dyn6.twc.com	2019-04-29 17:30:15.598996-07
3531	cpe-2606-A000-6B84-3DF0-896B-9DC3-D497-A92.dyn6.twc.com	2019-04-30 02:45:09.599412-07
3532	cpe-2606-A000-6B84-3DF0-896B-9DC3-D497-A92.dyn6.twc.com	2019-04-30 03:46:06.354109-07
3533	cpe-2606-A000-6B84-3DF0-896B-9DC3-D497-A92.dyn6.twc.com	2019-04-30 04:55:14.51157-07
3534	cpe-2606-A000-6B84-3DF0-896B-9DC3-D497-A92.dyn6.twc.com	2019-04-30 05:54:07.702307-07
3535	cpe-2606-A000-6B84-3DF0-896B-9DC3-D497-A92.dyn6.twc.com	2019-04-30 06:42:47.637678-07
3536	cpe-2606-A000-6B84-3DF0-896B-9DC3-D497-A92.dyn6.twc.com	2019-04-30 07:45:03.599628-07
3537	cpe-2606-A000-6B84-3DF0-896B-9DC3-D497-A92.dyn6.twc.com	2019-04-30 08:33:49.709957-07
3538	cpe-2606-A000-6B84-3DF0-896B-9DC3-D497-A92.dyn6.twc.com	2019-04-30 09:42:16.59907-07
3539	cpe-2606-A000-6B84-3DF0-896B-9DC3-D497-A92.dyn6.twc.com	2019-04-30 10:34:09.607157-07
3540	cpe-2606-A000-6B84-3DF0-896B-9DC3-D497-A92.dyn6.twc.com	2019-04-30 11:38:50.60371-07
3541	cpe-2606-A000-6B84-3DF0-896B-9DC3-D497-A92.dyn6.twc.com	2019-04-30 12:55:45.749739-07
3542	cpe-2606-A000-6B84-3DF0-79F5-92D0-8489-621D.dyn6.twc.com	2019-05-01 02:49:06.602201-07
3543	cpe-2606-A000-6B84-3DF0-79F5-92D0-8489-621D.dyn6.twc.com	2019-05-01 04:19:19.614329-07
3544	cpe-2606-A000-6B84-3DF0-79F5-92D0-8489-621D.dyn6.twc.com	2019-05-01 05:17:07.59906-07
3545	cpe-2606-A000-6B84-3DF0-79F5-92D0-8489-621D.dyn6.twc.com	2019-05-01 06:26:44.599308-07
3546	cpe-2606-A000-6B84-3DF0-AD70-D653-1696-ED0E.dyn6.twc.com	2019-05-01 12:26:44.672865-07
3547	cpe-2606-A000-6B84-3DF0-AD70-D653-1696-ED0E.dyn6.twc.com	2019-05-01 13:30:18.672313-07
3548	cpe-2606-A000-6B84-3DF0-AD70-D653-1696-ED0E.dyn6.twc.com	2019-05-01 16:00:16.719782-07
3549	cpe-2606-A000-6B84-3DF0-AD70-D653-1696-ED0E.dyn6.twc.com	2019-05-02 02:00:14.616032-07
3550	cpe-2606-A000-6B84-3DF0-AD70-D653-1696-ED0E.dyn6.twc.com	2019-05-02 02:49:15.699897-07
3551	cpe-2606-A000-6B84-3DF0-AD70-D653-1696-ED0E.dyn6.twc.com	2019-05-02 03:52:01.641915-07
3552	cpe-2606-A000-6B84-3DF0-AD70-D653-1696-ED0E.dyn6.twc.com	2019-05-02 04:55:15.609908-07
3553	cpe-2606-A000-6B84-3DF0-AD70-D653-1696-ED0E.dyn6.twc.com	2019-05-02 05:49:57.704439-07
3554	cpe-2606-A000-6B84-3DF0-AD70-D653-1696-ED0E.dyn6.twc.com	2019-05-02 06:41:18.639449-07
3555	cpe-2606-A000-6B84-3DF0-54C0-5AF2-AB7F-EA3E.dyn6.twc.com	2019-05-02 13:04:39.601045-07
3556	cpe-2606-A000-6B84-3DF0-7509-E28D-91CA-6DE5.dyn6.twc.com	2019-05-03 03:34:01.600631-07
3557	cpe-2606-A000-6B84-3DF0-7509-E28D-91CA-6DE5.dyn6.twc.com	2019-05-03 05:59:26.600235-07
3558	cpe-2606-A000-6B81-1300-112F-7231-9947-AE30.dyn6.twc.com	2019-05-03 09:31:33.598383-07
3559	cpe-2606-A000-6B81-1300-112F-7231-9947-AE30.dyn6.twc.com	2019-05-03 10:26:36.988584-07
3560	cpe-2606-A000-6B81-1300-112F-7231-9947-AE30.dyn6.twc.com	2019-05-03 11:30:15.714966-07
3561	cpe-2606-A000-6B81-1300-112F-7231-9947-AE30.dyn6.twc.com	2019-05-03 13:01:36.607102-07
3562	cpe-2606-A000-6B81-1300-112F-7231-9947-AE30.dyn6.twc.com	2019-05-03 14:00:11.061843-07
3563	cpe-2606-A000-6B81-1300-112F-7231-9947-AE30.dyn6.twc.com	2019-05-03 15:07:35.232643-07
3564	cpe-2606-A000-6B81-1300-112F-7231-9947-AE30.dyn6.twc.com	2019-05-03 15:28:37.739591-07
3565	cpe-2606-A000-6B81-1300-112F-7231-9947-AE30.dyn6.twc.com	2019-05-03 16:29:28.519534-07
3566	cpe-2606-A000-6B81-1300-112F-7231-9947-AE30.dyn6.twc.com	2019-05-03 16:51:17.17646-07
3567	cpe-2606-A000-6B81-1300-112F-7231-9947-AE30.dyn6.twc.com	2019-05-03 17:06:05.108946-07
3568	cpe-2606-A000-6B81-1300-112F-7231-9947-AE30.dyn6.twc.com	2019-05-04 02:00:11.729834-07
3569	cpe-2606-A000-6B81-1300-112F-7231-9947-AE30.dyn6.twc.com	2019-05-04 03:00:17.121064-07
3570	cpe-2606-A000-6B81-1300-112F-7231-9947-AE30.dyn6.twc.com	2019-05-04 11:27:19.337645-07
3571	cpe-2606-A000-6B81-1300-112F-7231-9947-AE30.dyn6.twc.com	2019-05-04 12:45:17.663509-07
3572	cpe-2606-A000-6B81-1300-112F-7231-9947-AE30.dyn6.twc.com	2019-05-04 14:30:14.259151-07
3573	cpe-2606-A000-6B81-1300-112F-7231-9947-AE30.dyn6.twc.com	2019-05-04 15:13:13.434158-07
3574	cpe-2606-A000-6B81-1300-112F-7231-9947-AE30.dyn6.twc.com	2019-05-04 15:42:19.303162-07
3575	cpe-2606-A000-6B81-1300-112F-7231-9947-AE30.dyn6.twc.com	2019-05-04 16:06:48.429712-07
3576	cpe-69-132-101-19.carolina.res.rr.com	2019-05-05 02:00:15.931347-07
3577	cpe-2606-A000-6B81-1300-20C7-A6F3-7DD4-6FD2.dyn6.twc.com	2019-05-05 05:13:10.774319-07
3578	cpe-2606-A000-6B81-1300-20C7-A6F3-7DD4-6FD2.dyn6.twc.com	2019-05-05 05:31:14.319961-07
3579	cpe-2606-A000-6B81-1300-20C7-A6F3-7DD4-6FD2.dyn6.twc.com	2019-05-05 07:20:17.300107-07
3580	cpe-2606-A000-6B81-1300-20C7-A6F3-7DD4-6FD2.dyn6.twc.com	2019-05-05 13:30:14.294062-07
3581	cpe-2606-A000-6B81-1300-20C7-A6F3-7DD4-6FD2.dyn6.twc.com	2019-05-05 17:00:18.45502-07
3582	cpe-2606-A000-6B81-1300-20C7-A6F3-7DD4-6FD2.dyn6.twc.com	2019-05-05 17:43:13.649587-07
3583	cpe-2606-A000-6B81-1300-20C7-A6F3-7DD4-6FD2.dyn6.twc.com	2019-05-05 18:00:19.646784-07
3584	cpe-69-132-101-19.carolina.res.rr.com	2019-05-05 18:13:11.363261-07
3585	cpe-2606-A000-6B84-3DF0-6C16-DA39-AF21-166.dyn6.twc.com	2019-05-06 06:43:00.26357-07
3586	cpe-2606-A000-6B84-3DF0-6C16-DA39-AF21-166.dyn6.twc.com	2019-05-06 08:07:41.472291-07
3587	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2019-05-08 10:48:38.260682-07
3588	cpe-2606-A000-6B84-3DF0-41C-435B-BAC7-E329.dyn6.twc.com	2019-05-09 02:50:08.284491-07
3589	cpe-2606-A000-6B84-3DF0-D24-EC70-1EE3-B1F4.dyn6.twc.com	2019-05-10 03:12:39.419582-07
3590	cpe-2606-A000-6B84-3DF0-D24-EC70-1EE3-B1F4.dyn6.twc.com	2019-05-10 03:41:01.386464-07
3591	cpe-2606-A000-6B84-3DF0-D24-EC70-1EE3-B1F4.dyn6.twc.com	2019-05-10 03:59:46.633051-07
3592	cpe-2606-A000-6B84-3DF0-D24-EC70-1EE3-B1F4.dyn6.twc.com	2019-05-10 05:07:49.25753-07
3593	cpe-2606-A000-6B84-3DF0-D24-EC70-1EE3-B1F4.dyn6.twc.com	2019-05-10 07:52:14.632318-07
3594	cpe-2606-A000-6B84-3DF0-E567-416C-3B32-839D.dyn6.twc.com	2019-05-13 03:02:07.620202-07
3595	cpe-2606-A000-6B84-3DF0-E567-416C-3B32-839D.dyn6.twc.com	2019-05-13 04:47:01.619572-07
3596	cpe-2606-A000-6B84-3DF0-E567-416C-3B32-839D.dyn6.twc.com	2019-05-13 04:49:37.723314-07
3597	cpe-2606-A000-6B84-3DF0-E567-416C-3B32-839D.dyn6.twc.com	2019-05-13 05:06:54.465719-07
3598	cpe-69-132-97-204.carolina.res.rr.com	2019-05-13 06:00:09.508191-07
3599	cpe-69-132-97-204.carolina.res.rr.com	2019-05-13 11:00:11.36188-07
3600	cpe-69-132-97-204.carolina.res.rr.com	2019-05-13 11:45:14.081046-07
3601	cpe-2606-A000-6B84-3DF0-E567-416C-3B32-839D.dyn6.twc.com	2019-05-13 11:47:52.713412-07
3602	cpe-2606-A000-6B84-3DF0-E567-416C-3B32-839D.dyn6.twc.com	2019-05-13 11:58:06.386195-07
3603	cpe-69-132-97-204.carolina.res.rr.com	2019-05-13 13:13:27.781349-07
3604	cpe-2606-A000-6B84-3DF0-DDC5-5D64-8607-C92A.dyn6.twc.com	2019-05-14 02:55:08.73364-07
3605	cpe-2606-A000-6B84-3DF0-DDC5-5D64-8607-C92A.dyn6.twc.com	2019-05-14 05:01:59.427618-07
3606	cpe-2606-A000-6B84-3DF0-DDC5-5D64-8607-C92A.dyn6.twc.com	2019-05-14 05:29:36.720531-07
3607	cpe-2606-A000-6B84-3DF0-DDC5-5D64-8607-C92A.dyn6.twc.com	2019-05-14 05:54:49.057819-07
3608	cpe-2606-A000-6B84-3DF0-DDC5-5D64-8607-C92A.dyn6.twc.com	2019-05-14 06:26:24.653423-07
3609	remote.bureaufris.nl	2019-05-14 08:06:38.755358-07
3610	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2019-05-14 08:17:08.348394-07
3611	cpe-2606-A000-6B84-3DF0-DDC5-5D64-8607-C92A.dyn6.twc.com	2019-05-14 08:22:15.876925-07
3612	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2019-05-14 08:40:48.026044-07
3613	cpe-2606-A000-6B84-3DF0-DDC5-5D64-8607-C92A.dyn6.twc.com	2019-05-14 08:47:55.437984-07
3614	cpe-2606-A000-6B84-3DF0-DDC5-5D64-8607-C92A.dyn6.twc.com	2019-05-14 09:38:41.428826-07
3615	cpe-2606-A000-6B84-3DF0-DDC5-5D64-8607-C92A.dyn6.twc.com	2019-05-14 10:23:39.401531-07
3616	cpe-2606-A000-6B84-3DF0-DDC5-5D64-8607-C92A.dyn6.twc.com	2019-05-14 10:44:21.716342-07
3617	cpe-2606-A000-6B84-3DF0-DDC5-5D64-8607-C92A.dyn6.twc.com	2019-05-14 10:57:22.385132-07
3618	cpe-2606-A000-6B84-3DF0-DDC5-5D64-8607-C92A.dyn6.twc.com	2019-05-14 11:33:21.740335-07
3774	cpe-2606-A000-6B84-3DF0-A8DE-A80D-1153-B22.dyn6.twc.com	2019-06-07 09:46:37.306081-07
3619	cpe-2606-A000-6B84-3DF0-DDC5-5D64-8607-C92A.dyn6.twc.com	2019-05-14 11:54:26.273888-07
3620	cpe-2606-A000-6B84-3DF0-DDC5-5D64-8607-C92A.dyn6.twc.com	2019-05-14 12:30:16.386769-07
3621	cpe-2606-A000-6B84-3DF0-C0D6-75F9-9A99-B6A3.dyn6.twc.com	2019-05-16 05:21:55.11276-07
3622	cpe-2606-A000-6B84-3DF0-C0D6-75F9-9A99-B6A3.dyn6.twc.com	2019-05-16 06:39:24.621435-07
3623	cpe-2606-A000-6B84-3DF0-C0D6-75F9-9A99-B6A3.dyn6.twc.com	2019-05-16 06:57:09.431536-07
3624	cpe-2606-A000-6B84-3DF0-C0D6-75F9-9A99-B6A3.dyn6.twc.com	2019-05-16 07:05:59.451934-07
3625	cpe-2606-A000-6B84-3DF0-C0D6-75F9-9A99-B6A3.dyn6.twc.com	2019-05-16 07:40:19.639504-07
3626	cpe-2606-A000-6B84-3DF0-C0D6-75F9-9A99-B6A3.dyn6.twc.com	2019-05-16 07:51:01.022592-07
3627	cpe-2606-A000-6B84-3DF0-C0D6-75F9-9A99-B6A3.dyn6.twc.com	2019-05-16 08:11:51.803422-07
3628	cpe-2606-A000-6B84-3DF0-C0D6-75F9-9A99-B6A3.dyn6.twc.com	2019-05-16 08:16:58.514776-07
3629	cpe-2606-A000-6B84-3DF0-C0D6-75F9-9A99-B6A3.dyn6.twc.com	2019-05-16 08:40:00.638332-07
3630	cpe-2606-A000-6B84-3DF0-C0D6-75F9-9A99-B6A3.dyn6.twc.com	2019-05-16 08:50:32.04643-07
3631	cpe-2606-A000-6B84-3DF0-C0D6-75F9-9A99-B6A3.dyn6.twc.com	2019-05-16 09:16:52.959621-07
3632	cpe-2606-A000-6B84-3DF0-C0D6-75F9-9A99-B6A3.dyn6.twc.com	2019-05-16 10:05:12.061856-07
3633	cpe-69-132-97-204.carolina.res.rr.com	2019-05-16 10:30:13.643925-07
3634	cpe-2606-A000-6B84-3DF0-C0D6-75F9-9A99-B6A3.dyn6.twc.com	2019-05-16 11:04:57.019286-07
3635	cpe-2606-A000-6B84-3DF0-C0D6-75F9-9A99-B6A3.dyn6.twc.com	2019-05-16 11:23:01.303871-07
3636	cpe-2606-A000-6B84-3DF0-C0D6-75F9-9A99-B6A3.dyn6.twc.com	2019-05-16 11:37:52.469209-07
3637	cpe-2606-A000-6B84-3DF0-C0D6-75F9-9A99-B6A3.dyn6.twc.com	2019-05-16 11:56:13.908611-07
3638	cpe-2606-A000-6B84-3DF0-C0D6-75F9-9A99-B6A3.dyn6.twc.com	2019-05-16 12:18:35.258365-07
3639	cpe-2606-A000-6B84-3DF0-C0D6-75F9-9A99-B6A3.dyn6.twc.com	2019-05-16 12:43:12.385333-07
3640	cpe-2606-A000-6B84-3DF0-C0D6-75F9-9A99-B6A3.dyn6.twc.com	2019-05-16 13:02:35.759431-07
3641	cpe-2606-A000-6B84-3DF0-C0D6-75F9-9A99-B6A3.dyn6.twc.com	2019-05-16 13:23:14.716011-07
3642	cpe-2606-A000-6B84-3DF0-C0D6-75F9-9A99-B6A3.dyn6.twc.com	2019-05-16 13:42:16.387042-07
3643	cpe-2606-A000-6B84-3DF0-C0D6-75F9-9A99-B6A3.dyn6.twc.com	2019-05-16 13:54:39.229842-07
3644	cpe-2606-A000-6B84-3DF0-C0D6-75F9-9A99-B6A3.dyn6.twc.com	2019-05-16 14:43:21.048956-07
3645	cpe-2606-A000-6B84-3DF0-17A-91B2-4B6C-6F01.dyn6.twc.com	2019-05-17 05:32:53.085724-07
3646	cpe-2606-A000-6B84-3DF0-17A-91B2-4B6C-6F01.dyn6.twc.com	2019-05-17 06:00:13.280876-07
3647	cpe-69-132-97-204.carolina.res.rr.com	2019-05-17 06:30:15.268943-07
3648	cpe-2606-A000-6B84-3DF0-17A-91B2-4B6C-6F01.dyn6.twc.com	2019-05-17 06:52:06.021285-07
3649	cpe-69-132-97-204.carolina.res.rr.com	2019-05-17 07:23:13.390376-07
3650	cpe-2606-A000-6B84-3DF0-17A-91B2-4B6C-6F01.dyn6.twc.com	2019-05-17 07:41:19.81515-07
3651	cpe-2606-A000-6B84-3DF0-17A-91B2-4B6C-6F01.dyn6.twc.com	2019-05-17 07:43:46.611877-07
3652	cpe-2606-A000-6B84-3DF0-17A-91B2-4B6C-6F01.dyn6.twc.com	2019-05-17 08:03:09.438121-07
3653	cpe-2606-A000-6B84-3DF0-17A-91B2-4B6C-6F01.dyn6.twc.com	2019-05-17 08:13:50.020804-07
3654	cpe-2606-A000-6B84-3DF0-17A-91B2-4B6C-6F01.dyn6.twc.com	2019-05-17 08:33:45.27255-07
3655	cpe-2606-A000-6B84-3DF0-17A-91B2-4B6C-6F01.dyn6.twc.com	2019-05-17 08:52:42.612859-07
3656	cpe-2606-A000-6B84-3DF0-17A-91B2-4B6C-6F01.dyn6.twc.com	2019-05-17 09:16:19.390501-07
3657	cpe-2606-A000-6B84-3DF0-17A-91B2-4B6C-6F01.dyn6.twc.com	2019-05-17 09:37:46.714474-07
3658	cpe-2606-A000-6B84-3DF0-17A-91B2-4B6C-6F01.dyn6.twc.com	2019-05-17 09:45:11.771464-07
3659	cpe-2606-A000-6B84-3DF0-17A-91B2-4B6C-6F01.dyn6.twc.com	2019-05-17 10:04:15.328175-07
3660	cpe-2606-A000-6B84-3DF0-17A-91B2-4B6C-6F01.dyn6.twc.com	2019-05-17 10:26:36.717077-07
3661	cpe-2606-A000-6B84-3DF0-17A-91B2-4B6C-6F01.dyn6.twc.com	2019-05-17 10:47:18.387656-07
3662	cpe-2606-A000-6B84-3DF0-17A-91B2-4B6C-6F01.dyn6.twc.com	2019-05-17 11:25:05.024223-07
3663	cpe-2606-A000-6B84-3DF0-17A-91B2-4B6C-6F01.dyn6.twc.com	2019-05-17 11:32:14.26367-07
3664	cpe-2606-A000-6B84-3DF0-17A-91B2-4B6C-6F01.dyn6.twc.com	2019-05-17 11:49:00.418175-07
3665	cpe-2606-A000-6B84-3DF0-17A-91B2-4B6C-6F01.dyn6.twc.com	2019-05-17 12:19:48.654775-07
3666	cpe-2606-A000-6B84-3DF0-17A-91B2-4B6C-6F01.dyn6.twc.com	2019-05-17 12:34:57.721372-07
3667	cpe-2606-A000-6B84-3DF0-17A-91B2-4B6C-6F01.dyn6.twc.com	2019-05-17 12:51:41.258728-07
3668	cpe-2606-A000-6B84-3DF0-4A0-F757-42E2-6ECD.dyn6.twc.com	2019-05-20 02:55:56.317134-07
3669	cpe-2606-A000-6B84-3DF0-4A0-F757-42E2-6ECD.dyn6.twc.com	2019-05-20 04:42:12.278006-07
3670	cpe-2606-A000-6B84-3DF0-3DDD-7FFD-30D8-609D.dyn6.twc.com	2019-05-21 02:40:38.915504-07
3671	cpe-2606-A000-6B84-3DF0-65D6-27F2-6242-51AE.dyn6.twc.com	2019-05-21 08:07:41.111889-07
3672	cpe-2606-A000-6B84-3DF0-65D6-27F2-6242-51AE.dyn6.twc.com	2019-05-21 10:13:38.432765-07
3673	cpe-2606-A000-6B84-3DF0-65D6-27F2-6242-51AE.dyn6.twc.com	2019-05-21 11:06:11.404068-07
3674	cpe-2606-A000-6B84-3DF0-65D6-27F2-6242-51AE.dyn6.twc.com	2019-05-21 11:59:27.023188-07
3675	cpe-2606-A000-6B84-3DF0-74F0-9957-DA09-4915.dyn6.twc.com	2019-05-22 02:56:53.438258-07
3676	cpe-2606-A000-6B84-3DF0-558F-DAE4-EB6D-540C.dyn6.twc.com	2019-05-22 04:18:11.630072-07
3677	cpe-2606-A000-6B84-3DF0-E517-157C-1A40-BA4E.dyn6.twc.com	2019-05-22 04:43:16.964186-07
3678	cpe-2606-A000-6B84-3DF0-1CC0-7EB4-BF53-E4D4.dyn6.twc.com	2019-05-22 12:50:45.39402-07
3679	p549DB331.dip0.t-ipconnect.de	2019-05-23 03:32:47.262237-07
3680	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2019-05-23 06:58:20.862093-07
3681	cpe-2606-A000-6B84-3DF0-5D1D-77BE-9576-687C.dyn6.twc.com	2019-05-29 03:16:06.636279-07
3682	cpe-2606-A000-6B84-3DF0-5D1D-77BE-9576-687C.dyn6.twc.com	2019-05-29 04:55:21.31944-07
3683	cpe-2606-A000-6B84-3DF0-5D1D-77BE-9576-687C.dyn6.twc.com	2019-05-29 07:30:14.717146-07
3684	cpe-2606-A000-6B84-3DF0-5D1D-77BE-9576-687C.dyn6.twc.com	2019-05-29 14:30:11.710326-07
3685	cpe-2606-A000-6B84-3DF0-5D1D-77BE-9576-687C.dyn6.twc.com	2019-05-29 16:30:11.614946-07
3686	cpe-2606-A000-6B84-3DF0-6DB5-FA73-5DDC-9587.dyn6.twc.com	2019-05-30 01:25:40.715581-07
3687	cpe-2606-A000-6B84-3DF0-6DB5-FA73-5DDC-9587.dyn6.twc.com	2019-05-30 01:43:15.272708-07
3688	cpe-2606-A000-6B84-3DF0-6DB5-FA73-5DDC-9587.dyn6.twc.com	2019-05-30 01:53:53.598925-07
3689	cpe-2606-A000-6B84-3DF0-6DB5-FA73-5DDC-9587.dyn6.twc.com	2019-05-30 02:14:59.76909-07
3690	cpe-2606-A000-6B84-3DF0-6DB5-FA73-5DDC-9587.dyn6.twc.com	2019-05-30 02:33:04.716395-07
3691	cpe-2606-A000-6B84-3DF0-6DB5-FA73-5DDC-9587.dyn6.twc.com	2019-05-30 03:24:18.022671-07
3692	cpe-2606-A000-6B84-3DF0-6DB5-FA73-5DDC-9587.dyn6.twc.com	2019-05-30 03:33:04.771032-07
3693	cpe-2606-A000-6B84-3DF0-6DB5-FA73-5DDC-9587.dyn6.twc.com	2019-05-30 04:18:05.620176-07
3694	cpe-2606-A000-6B84-3DF0-6DB5-FA73-5DDC-9587.dyn6.twc.com	2019-05-30 04:35:57.561819-07
3695	cpe-2606-A000-6B84-3DF0-6DB5-FA73-5DDC-9587.dyn6.twc.com	2019-05-30 05:25:19.720143-07
3696	cpe-2606-A000-6B84-3DF0-6DB5-FA73-5DDC-9587.dyn6.twc.com	2019-05-30 05:46:06.070974-07
3697	cpe-2606-A000-6B84-3DF0-6DB5-FA73-5DDC-9587.dyn6.twc.com	2019-05-30 06:02:43.742394-07
3698	cpe-2606-A000-6B84-3DF0-6DB5-FA73-5DDC-9587.dyn6.twc.com	2019-05-30 06:27:11.738936-07
3699	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2019-05-30 06:29:15.421501-07
3700	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2019-05-30 06:48:19.763242-07
3701	cpe-2606-A000-6B84-3DF0-6DB5-FA73-5DDC-9587.dyn6.twc.com	2019-05-30 06:51:14.719864-07
3702	cpe-2606-A000-6B84-3DF0-6DB5-FA73-5DDC-9587.dyn6.twc.com	2019-05-30 07:05:06.816315-07
3703	cpe-2606-A000-6B84-3DF0-6DB5-FA73-5DDC-9587.dyn6.twc.com	2019-05-30 08:51:56.838164-07
3704	cpe-2606-A000-6B84-3DF0-6DB5-FA73-5DDC-9587.dyn6.twc.com	2019-05-30 09:12:44.658801-07
3705	cpe-2606-A000-6B84-3DF0-6DB5-FA73-5DDC-9587.dyn6.twc.com	2019-05-30 10:41:57.028548-07
3706	cpe-2606-A000-6B84-3DF0-6DB5-FA73-5DDC-9587.dyn6.twc.com	2019-05-30 11:27:17.144992-07
3707	cpe-2606-A000-6B84-3DF0-6DB5-FA73-5DDC-9587.dyn6.twc.com	2019-05-30 11:42:37.169675-07
3708	cpe-2606-A000-6B84-3DF0-6DB5-FA73-5DDC-9587.dyn6.twc.com	2019-05-30 11:56:31.716681-07
3709	cpe-2606-A000-6B84-3DF0-6DB5-FA73-5DDC-9587.dyn6.twc.com	2019-05-30 12:17:10.020581-07
3710	cpe-2606-A000-6B84-3DF0-F49A-A224-607D-4458.dyn6.twc.com	2019-05-31 04:47:37.329215-07
3711	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2019-05-31 05:19:30.495862-07
3712	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2019-05-31 05:29:14.669904-07
3713	cpe-2606-A000-6B84-3DF0-F49A-A224-607D-4458.dyn6.twc.com	2019-05-31 06:10:08.71742-07
3714	cpe-2606-A000-6B84-3DF0-F49A-A224-607D-4458.dyn6.twc.com	2019-05-31 06:28:51.418988-07
3715	cpe-2606-A000-6B84-3DF0-F49A-A224-607D-4458.dyn6.twc.com	2019-05-31 06:48:56.667473-07
3716	cpe-2606-A000-6B84-3DF0-F49A-A224-607D-4458.dyn6.twc.com	2019-05-31 06:59:28.738265-07
3717	cpe-2606-A000-6B84-3DF0-F49A-A224-607D-4458.dyn6.twc.com	2019-05-31 07:41:34.415923-07
3718	cpe-2606-A000-6B84-3DF0-F49A-A224-607D-4458.dyn6.twc.com	2019-05-31 08:05:01.655474-07
3719	cpe-2606-A000-6B84-3DF0-F49A-A224-607D-4458.dyn6.twc.com	2019-05-31 08:16:06.046299-07
3720	cpe-2606-A000-6B84-3DF0-F49A-A224-607D-4458.dyn6.twc.com	2019-05-31 09:44:51.825465-07
3721	cpe-2606-A000-6B84-3DF0-F49A-A224-607D-4458.dyn6.twc.com	2019-05-31 10:31:43.622389-07
3722	cpe-2606-A000-6B84-3DF0-F49A-A224-607D-4458.dyn6.twc.com	2019-05-31 10:46:39.858109-07
3723	cpe-2606-A000-6B84-3DF0-F49A-A224-607D-4458.dyn6.twc.com	2019-05-31 11:50:15.775257-07
3724	cpe-2606-A000-6B84-3DF0-F49A-A224-607D-4458.dyn6.twc.com	2019-05-31 11:59:38.621207-07
3725	cpe-2606-A000-6B84-3DF0-8549-FCDE-D9CA-39BC.dyn6.twc.com	2019-06-03 01:45:11.826775-07
3726	cpe-2606-A000-6B84-3DF0-8549-FCDE-D9CA-39BC.dyn6.twc.com	2019-06-03 04:11:26.264935-07
3727	cpe-2606-A000-6B84-3DF0-8549-FCDE-D9CA-39BC.dyn6.twc.com	2019-06-03 04:20:29.262723-07
3728	cpe-2606-A000-6B84-3DF0-8549-FCDE-D9CA-39BC.dyn6.twc.com	2019-06-03 05:04:09.427257-07
3729	cpe-2606-A000-6B84-3DF0-8549-FCDE-D9CA-39BC.dyn6.twc.com	2019-06-03 05:13:45.78247-07
3730	cpe-2606-A000-6B84-3DF0-8549-FCDE-D9CA-39BC.dyn6.twc.com	2019-06-03 05:21:32.26446-07
3731	cpe-2606-A000-6B84-3DF0-8549-FCDE-D9CA-39BC.dyn6.twc.com	2019-06-03 07:00:12.406668-07
3732	cpe-2606-A000-6B84-3DF0-8549-FCDE-D9CA-39BC.dyn6.twc.com	2019-06-03 11:30:13.495535-07
3733	cpe-2606-A000-6B84-3DF0-8549-FCDE-D9CA-39BC.dyn6.twc.com	2019-06-03 12:30:12.422296-07
3734	cpe-2606-A000-6B84-3DF0-8549-FCDE-D9CA-39BC.dyn6.twc.com	2019-06-03 14:13:01.870911-07
3735	cpe-2606-A000-6B84-3DF0-8549-FCDE-D9CA-39BC.dyn6.twc.com	2019-06-03 14:16:05.731567-07
3736	cpe-2606-A000-6B84-3DF0-4420-FEB5-83CB-7854.dyn6.twc.com	2019-06-04 02:59:50.305743-07
3737	cpe-2606-A000-6B84-3DF0-4420-FEB5-83CB-7854.dyn6.twc.com	2019-06-04 03:49:04.257938-07
3738	cpe-2606-A000-6B84-3DF0-4420-FEB5-83CB-7854.dyn6.twc.com	2019-06-04 05:12:39.27074-07
3739	cpe-2606-A000-6B84-3DF0-3434-F7CD-CB4E-F8EE.dyn6.twc.com	2019-06-04 06:08:09.796469-07
3740	cpe-2606-A000-6B84-3DF0-3434-F7CD-CB4E-F8EE.dyn6.twc.com	2019-06-04 06:58:49.426745-07
3741	cpe-2606-A000-6B84-3DF0-3434-F7CD-CB4E-F8EE.dyn6.twc.com	2019-06-04 07:51:14.269399-07
3742	cpe-2606-A000-6B84-3DF0-3434-F7CD-CB4E-F8EE.dyn6.twc.com	2019-06-04 08:46:30.405929-07
3743	cpe-2606-A000-6B84-3DF0-3434-F7CD-CB4E-F8EE.dyn6.twc.com	2019-06-04 09:36:29.304147-07
3744	cpe-2606-A000-6B84-3DF0-3434-F7CD-CB4E-F8EE.dyn6.twc.com	2019-06-04 10:30:44.275244-07
3745	cpe-2606-A000-6B84-3DF0-3434-F7CD-CB4E-F8EE.dyn6.twc.com	2019-06-04 11:27:14.261874-07
3746	cpe-2606-A000-6B84-3DF0-3434-F7CD-CB4E-F8EE.dyn6.twc.com	2019-06-04 12:40:03.533189-07
3747	cpe-2606-A000-6B84-3DF0-41FB-82EA-E2C3-7296.dyn6.twc.com	2019-06-05 04:57:49.373896-07
3748	cpe-2606-A000-6B84-3DF0-41FB-82EA-E2C3-7296.dyn6.twc.com	2019-06-05 05:15:32.40812-07
3749	cpe-2606-A000-6B84-3DF0-41FB-82EA-E2C3-7296.dyn6.twc.com	2019-06-05 05:48:03.260111-07
3750	cpe-2606-A000-6B84-3DF0-41FB-82EA-E2C3-7296.dyn6.twc.com	2019-06-05 07:01:23.710588-07
3751	cpe-2606-A000-6B84-3DF0-41FB-82EA-E2C3-7296.dyn6.twc.com	2019-06-05 08:00:10.413652-07
3752	cpe-2606-A000-6B84-3DF0-1045-FACD-EA45-6E70.dyn6.twc.com	2019-06-05 11:17:43.401615-07
3753	cpe-2606-A000-6B84-3DF0-1045-FACD-EA45-6E70.dyn6.twc.com	2019-06-05 12:32:28.301847-07
3754	cpe-2606-A000-6B84-3DF0-E12C-A0B8-ABFB-57F3.dyn6.twc.com	2019-06-06 03:01:19.335113-07
3755	cpe-2606-A000-6B84-3DF0-D3C-AF63-2BBE-EDC9.dyn6.twc.com	2019-06-06 08:10:23.388736-07
3756	cpe-2606-A000-6B84-3DF0-D3C-AF63-2BBE-EDC9.dyn6.twc.com	2019-06-06 09:01:18.265732-07
3757	cpe-2606-A000-6B84-3DF0-D3C-AF63-2BBE-EDC9.dyn6.twc.com	2019-06-06 09:10:14.41061-07
3758	cpe-2606-A000-6B84-3DF0-D3C-AF63-2BBE-EDC9.dyn6.twc.com	2019-06-06 09:53:58.509256-07
3759	cpe-2606-A000-6B84-3DF0-D3C-AF63-2BBE-EDC9.dyn6.twc.com	2019-06-06 10:28:00.409171-07
3760	cpe-2606-A000-6B84-3DF0-D3C-AF63-2BBE-EDC9.dyn6.twc.com	2019-06-06 10:43:43.279852-07
3761	cpe-2606-A000-6B84-3DF0-D3C-AF63-2BBE-EDC9.dyn6.twc.com	2019-06-06 11:26:14.536784-07
3762	cpe-2606-A000-6B84-3DF0-D3C-AF63-2BBE-EDC9.dyn6.twc.com	2019-06-06 11:41:28.288929-07
3763	cpe-2606-A000-6B84-3DF0-D3C-AF63-2BBE-EDC9.dyn6.twc.com	2019-06-06 12:31:58.266993-07
3764	cpe-2606-A000-6B84-3DF0-A8DE-A80D-1153-B22.dyn6.twc.com	2019-06-07 02:50:24.423545-07
3765	cpe-2606-A000-6B84-3DF0-A8DE-A80D-1153-B22.dyn6.twc.com	2019-06-07 04:48:41.464002-07
3766	cpe-2606-A000-6B84-3DF0-A8DE-A80D-1153-B22.dyn6.twc.com	2019-06-07 04:53:33.311112-07
3767	cpe-2606-A000-6B84-3DF0-A8DE-A80D-1153-B22.dyn6.twc.com	2019-06-07 05:38:24.390385-07
3768	cpe-2606-A000-6B84-3DF0-A8DE-A80D-1153-B22.dyn6.twc.com	2019-06-07 05:57:58.714911-07
3769	cpe-2606-A000-6B84-3DF0-A8DE-A80D-1153-B22.dyn6.twc.com	2019-06-07 06:48:28.262771-07
3770	cpe-2606-A000-6B84-3DF0-A8DE-A80D-1153-B22.dyn6.twc.com	2019-06-07 06:57:43.754749-07
3771	cpe-2606-A000-6B84-3DF0-A8DE-A80D-1153-B22.dyn6.twc.com	2019-06-07 07:51:42.345702-07
3772	cpe-2606-A000-6B84-3DF0-A8DE-A80D-1153-B22.dyn6.twc.com	2019-06-07 08:11:44.406651-07
3773	cpe-2606-A000-6B84-3DF0-A8DE-A80D-1153-B22.dyn6.twc.com	2019-06-07 08:57:57.370059-07
3775	cpe-2606-A000-6B84-3DF0-A8DE-A80D-1153-B22.dyn6.twc.com	2019-06-07 10:26:53.479666-07
3776	cpe-2606-A000-6B84-3DF0-A8DE-A80D-1153-B22.dyn6.twc.com	2019-06-07 10:43:07.284458-07
3777	cpe-2606-A000-6B84-3DF0-A8DE-A80D-1153-B22.dyn6.twc.com	2019-06-07 11:39:13.38473-07
3778	cpe-69-132-97-204.carolina.res.rr.com	2019-06-07 12:30:13.053807-07
3779	cpe-2606-A000-6B84-3DF0-2D51-BB72-393-B4DA.dyn6.twc.com	2019-06-10 02:53:34.30751-07
3780	cpe-2606-A000-6B84-3DF0-2D51-BB72-393-B4DA.dyn6.twc.com	2019-06-10 05:00:20.717027-07
3781	cpe-2606-A000-6B84-3DF0-2D51-BB72-393-B4DA.dyn6.twc.com	2019-06-10 05:30:20.131953-07
3782	cpe-2606-A000-6B84-3DF0-2D51-BB72-393-B4DA.dyn6.twc.com	2019-06-10 08:00:14.681742-07
3783	cpe-2606-A000-6B84-3DF0-2D51-BB72-393-B4DA.dyn6.twc.com	2019-06-10 12:30:15.562421-07
3784	cpe-2606-A000-6B84-3DF0-2D51-BB72-393-B4DA.dyn6.twc.com	2019-06-10 12:58:41.390824-07
3785	cpe-2606-A000-6B84-3DF0-2D51-BB72-393-B4DA.dyn6.twc.com	2019-06-10 13:55:11.288864-07
3786	cpe-2606-A000-6B84-3DF0-91E9-B6A6-548B-7A5D.dyn6.twc.com	2019-06-11 03:02:00.44621-07
3787	cpe-2606-A000-6B84-3DF0-91E9-B6A6-548B-7A5D.dyn6.twc.com	2019-06-11 03:57:29.845412-07
3788	cpe-2606-A000-6B84-3DF0-91E9-B6A6-548B-7A5D.dyn6.twc.com	2019-06-11 04:59:15.308777-07
3789	cpe-2606-A000-6B84-3DF0-91E9-B6A6-548B-7A5D.dyn6.twc.com	2019-06-11 05:18:45.781422-07
3790	cpe-2606-A000-6B84-3DF0-91E9-B6A6-548B-7A5D.dyn6.twc.com	2019-06-11 06:34:43.458203-07
3791	cpe-2606-A000-6B84-3DF0-91E9-B6A6-548B-7A5D.dyn6.twc.com	2019-06-11 06:53:10.642511-07
3792	cpe-2606-A000-6B84-3DF0-91E9-B6A6-548B-7A5D.dyn6.twc.com	2019-06-11 07:42:39.294146-07
3793	cpe-2606-A000-6B84-3DF0-91E9-B6A6-548B-7A5D.dyn6.twc.com	2019-06-11 07:59:23.393125-07
3794	cpe-2606-A000-6B84-3DF0-91E9-B6A6-548B-7A5D.dyn6.twc.com	2019-06-11 08:14:46.713786-07
3795	cpe-2606-A000-6B84-3DF0-91E9-B6A6-548B-7A5D.dyn6.twc.com	2019-06-11 08:31:21.340068-07
3796	cpe-2606-A000-6B84-3DF0-91E9-B6A6-548B-7A5D.dyn6.twc.com	2019-06-11 09:20:41.344005-07
3797	cpe-2606-A000-6B84-3DF0-91E9-B6A6-548B-7A5D.dyn6.twc.com	2019-06-11 10:13:39.719078-07
3798	cpe-2606-A000-6B84-3DF0-91E9-B6A6-548B-7A5D.dyn6.twc.com	2019-06-11 10:16:06.203859-07
3799	cpe-2606-A000-6B84-3DF0-91E9-B6A6-548B-7A5D.dyn6.twc.com	2019-06-11 10:18:11.38468-07
3800	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2019-06-11 10:23:40.196715-07
3801	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2019-06-11 10:30:02.898521-07
3802	cpe-2606-A000-6B84-3DF0-91E9-B6A6-548B-7A5D.dyn6.twc.com	2019-06-11 11:17:40.649317-07
3803	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2019-06-11 11:29:04.50002-07
3804	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2019-06-11 11:35:27.509186-07
3805	cpe-2606-A000-6B84-3DF0-91E9-B6A6-548B-7A5D.dyn6.twc.com	2019-06-11 11:38:20.384024-07
3806	cpe-2606-A000-6B84-3DF0-91E9-B6A6-548B-7A5D.dyn6.twc.com	2019-06-11 12:08:34.648811-07
3807	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2019-06-11 12:39:35.71792-07
3808	cpe-2606-A000-6B84-3DF0-91E9-B6A6-548B-7A5D.dyn6.twc.com	2019-06-11 13:01:05.955909-07
3809	cpe-2606-A000-6B84-3DF0-1551-A6C6-7807-1077.dyn6.twc.com	2019-06-12 02:33:57.715412-07
3810	cpe-2606-A000-6B84-3DF0-1551-A6C6-7807-1077.dyn6.twc.com	2019-06-12 05:52:24.389419-07
3811	cpe-2606-A000-6B84-3DF0-98-534C-FD10-2595.dyn6.twc.com	2019-06-13 02:38:53.389828-07
3812	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2019-06-13 05:52:43.638057-07
3813	cpe-69-132-97-204.carolina.res.rr.com	2019-06-13 12:49:46.26357-07
3814	cpe-2606-A000-6B84-3DF0-98-534C-FD10-2595.dyn6.twc.com	2019-06-13 12:53:01.337759-07
3815	cpe-2606-A000-6B84-3DF0-98-534C-FD10-2595.dyn6.twc.com	2019-06-13 13:06:05.715049-07
3816	cpe-2606-A000-6B84-3DF0-98-534C-FD10-2595.dyn6.twc.com	2019-06-13 13:53:29.66972-07
3817	cpe-2606-A000-6B84-3DF0-98-534C-FD10-2595.dyn6.twc.com	2019-06-13 14:06:30.263803-07
3818	cpe-2606-A000-6B84-3DF0-98-534C-FD10-2595.dyn6.twc.com	2019-06-13 14:30:29.71523-07
3819	107.161.86.161	2019-06-13 14:33:12.858765-07
3820	cpe-2606-A000-6B84-3DF0-AC08-A132-89D2-6191.dyn6.twc.com	2019-06-14 02:38:38.269167-07
3821	cpe-2606-A000-6B84-3DF0-AC08-A132-89D2-6191.dyn6.twc.com	2019-06-14 06:18:19.382029-07
3822	cpe-2606-A000-6B84-3DF0-AC08-A132-89D2-6191.dyn6.twc.com	2019-06-14 06:37:15.391891-07
3823	cpe-2606-A000-6B84-3DF0-AC08-A132-89D2-6191.dyn6.twc.com	2019-06-14 06:57:48.8177-07
3824	cpe-2606-A000-6B84-3DF0-AC08-A132-89D2-6191.dyn6.twc.com	2019-06-14 07:32:12.268127-07
3825	cpe-2606-A000-6B84-3DF0-AC08-A132-89D2-6191.dyn6.twc.com	2019-06-14 08:14:03.394533-07
3826	cpe-2606-A000-6B84-3DF0-AC08-A132-89D2-6191.dyn6.twc.com	2019-06-14 08:18:47.768874-07
3827	cpe-2606-A000-6B84-3DF0-AC08-A132-89D2-6191.dyn6.twc.com	2019-06-14 08:55:01.342345-07
3828	cpe-2606-A000-6B84-3DF0-A81D-6DF4-25C1-A10D.dyn6.twc.com	2019-06-17 06:20:16.78416-07
3829	69.12.94.115	2019-06-17 08:36:25.637899-07
3830	2600:380:514b:d870:2c92:554:17e8:ef5e	2019-06-17 16:21:12.947361-07
3831	cpe-2606-A000-6B84-3DF0-2C3F-20BD-56F2-2B7F.dyn6.twc.com	2019-06-18 02:47:47.267233-07
3832	cpe-2606-A000-6B84-3DF0-2C3F-20BD-56F2-2B7F.dyn6.twc.com	2019-06-18 05:24:32.387249-07
3833	cpe-2606-A000-6B84-3DF0-2C3F-20BD-56F2-2B7F.dyn6.twc.com	2019-06-18 06:00:17.266525-07
3834	cpe-2606-A000-6B84-3DF0-2C3F-20BD-56F2-2B7F.dyn6.twc.com	2019-06-18 06:35:39.393611-07
3835	cpe-2606-A000-6B84-3DF0-9980-9241-D961-EC43.dyn6.twc.com	2019-06-18 13:23:39.384777-07
3836	cpe-2606-A000-6B84-3DF0-9980-9241-D961-EC43.dyn6.twc.com	2019-06-18 13:25:12.390034-07
3837	cpe-2606-A000-6B84-3DF0-697E-2FB1-DDBF-2FF5.dyn6.twc.com	2019-06-19 02:45:02.387346-07
3838	cpe-2606-A000-6B84-3DF0-697E-2FB1-DDBF-2FF5.dyn6.twc.com	2019-06-19 04:54:40.533927-07
3839	cpe-2606-A000-6B84-3DF0-697E-2FB1-DDBF-2FF5.dyn6.twc.com	2019-06-19 05:03:38.746021-07
3840	cpe-2606-A000-6B84-3DF0-697E-2FB1-DDBF-2FF5.dyn6.twc.com	2019-06-19 05:14:18.38275-07
3841	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2019-06-19 09:10:23.156379-07
3842	198.55.125.217	2019-06-19 09:17:23.483846-07
3843	198.55.125.224	2019-06-19 10:50:04.31741-07
3844	cpe-2606-A000-6B81-1300-99E6-2892-ED7D-3D89.dyn6.twc.com	2019-06-19 17:18:31.389388-07
3845	cpe-2606-A000-6B84-3DF0-D4FB-606-1015-87B9.dyn6.twc.com	2019-06-20 02:47:11.391796-07
3846	cpe-2606-A000-6B84-3DF0-D4FB-606-1015-87B9.dyn6.twc.com	2019-06-20 04:42:52.877546-07
3847	cpe-2606-A000-6B84-3DF0-D4FB-606-1015-87B9.dyn6.twc.com	2019-06-20 04:51:36.621832-07
3848	cpe-2606-A000-6B84-3DF0-D4FB-606-1015-87B9.dyn6.twc.com	2019-06-20 05:20:07.604256-07
3849	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2019-06-20 06:02:48.495986-07
3850	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2019-06-20 06:05:07.853067-07
3851	198.55.125.207	2019-06-20 14:04:55.492572-07
3852	198.55.125.207	2019-06-20 16:16:41.916718-07
3853	cpe-2606-A000-6B84-3DF0-8C2-D31F-EA19-D4B9.dyn6.twc.com	2019-06-21 02:40:53.622329-07
3854	cpe-2606-A000-6B84-3DF0-9FF-61E5-F6C4-BFC7.dyn6.twc.com	2019-06-21 08:42:47.720158-07
3855	cpe-2606-A000-6B84-3DF0-9FF-61E5-F6C4-BFC7.dyn6.twc.com	2019-06-21 09:52:48.460416-07
3856	cpe-2606-A000-6B84-3DF0-9FF-61E5-F6C4-BFC7.dyn6.twc.com	2019-06-21 10:01:48.039154-07
3857	cpe-2606-A000-6B84-3DF0-9FF-61E5-F6C4-BFC7.dyn6.twc.com	2019-06-21 10:18:16.386971-07
3858	cpe-2606-A000-6B84-3DF0-9FF-61E5-F6C4-BFC7.dyn6.twc.com	2019-06-21 10:37:26.621173-07
3859	cpe-2606-A000-6B84-3DF0-9FF-61E5-F6C4-BFC7.dyn6.twc.com	2019-06-21 10:45:26.719083-07
3860	cpe-2606-A000-6B84-3DF0-9FF-61E5-F6C4-BFC7.dyn6.twc.com	2019-06-21 11:24:31.784175-07
3861	cpe-2606-A000-6B84-3DF0-9FF-61E5-F6C4-BFC7.dyn6.twc.com	2019-06-21 11:53:56.389814-07
3862	cpe-2606-A000-6B84-3DF0-9FF-61E5-F6C4-BFC7.dyn6.twc.com	2019-06-21 12:46:13.405608-07
3863	cpe-2606-A000-6B84-3DF0-9FF-61E5-F6C4-BFC7.dyn6.twc.com	2019-06-21 13:02:31.782827-07
3864	cpe-2606-A000-6B84-3DF0-1006-8A8C-26C8-444A.dyn6.twc.com	2019-06-24 02:43:37.836322-07
3865	cpe-2606-A000-6B84-3DF0-1006-8A8C-26C8-444A.dyn6.twc.com	2019-06-24 03:22:41.387707-07
3866	cpe-2606-A000-6B84-3DF0-1006-8A8C-26C8-444A.dyn6.twc.com	2019-06-24 03:39:44.714715-07
3867	cpe-2606-A000-6B84-3DF0-1006-8A8C-26C8-444A.dyn6.twc.com	2019-06-24 04:06:18.024118-07
3868	cpe-2606-A000-6B84-3DF0-1006-8A8C-26C8-444A.dyn6.twc.com	2019-06-24 04:55:14.719178-07
3869	cpe-2606-A000-6B84-3DF0-1006-8A8C-26C8-444A.dyn6.twc.com	2019-06-24 05:23:35.600194-07
3870	cpe-69-132-101-19.carolina.res.rr.com	2019-06-24 12:58:57.274362-07
3871	cpe-2606-A000-6B81-1300-7874-3200-97CF-FF49.dyn6.twc.com	2019-06-25 01:13:24.866523-07
3872	cpe-2606-A000-6B81-1300-7874-3200-97CF-FF49.dyn6.twc.com	2019-06-25 03:03:30.113249-07
3873	cpe-2606-A000-6B81-1300-7874-3200-97CF-FF49.dyn6.twc.com	2019-06-25 03:52:28.929974-07
3874	cpe-2606-A000-6B81-1300-7874-3200-97CF-FF49.dyn6.twc.com	2019-06-25 04:55:09.647891-07
3875	cpe-2606-A000-6B81-1300-7874-3200-97CF-FF49.dyn6.twc.com	2019-06-25 05:44:48.865525-07
3876	cpe-2606-A000-6B81-1300-7874-3200-97CF-FF49.dyn6.twc.com	2019-06-25 06:35:58.928905-07
3877	cpe-2606-A000-6B81-1300-7874-3200-97CF-FF49.dyn6.twc.com	2019-06-25 07:57:18.929688-07
3878	cpe-2606-A000-6B81-1300-7874-3200-97CF-FF49.dyn6.twc.com	2019-06-25 09:02:08.905895-07
3879	cpe-2606-A000-6B81-1300-7874-3200-97CF-FF49.dyn6.twc.com	2019-06-25 11:52:38.865835-07
3880	cpe-2606-A000-6B81-1300-7874-3200-97CF-FF49.dyn6.twc.com	2019-06-25 12:42:53.869595-07
3881	cpe-69-132-101-19.carolina.res.rr.com	2019-06-26 01:15:54.894496-07
3882	cpe-69-132-101-19.carolina.res.rr.com	2019-06-26 03:28:49.236926-07
3883	cpe-2606-A000-6B81-1300-35DA-DD39-6115-76F3.dyn6.twc.com	2019-06-26 06:28:20.025032-07
3884	cpe-2606-A000-6B81-1300-35DA-DD39-6115-76F3.dyn6.twc.com	2019-06-26 06:47:30.538094-07
3885	cpe-2606-A000-6B81-1300-35DA-DD39-6115-76F3.dyn6.twc.com	2019-06-26 06:56:37.334002-07
3886	cpe-2606-A000-6B81-1300-35DA-DD39-6115-76F3.dyn6.twc.com	2019-06-26 07:10:00.718779-07
3887	cpe-2606-A000-6B81-1300-35DA-DD39-6115-76F3.dyn6.twc.com	2019-06-26 07:47:06.611555-07
3888	cpe-2606-A000-6B81-1300-35DA-DD39-6115-76F3.dyn6.twc.com	2019-06-26 08:41:17.608873-07
3889	cpe-2606-A000-6B81-1300-35DA-DD39-6115-76F3.dyn6.twc.com	2019-06-26 08:46:48.43841-07
3890	cpe-2606-A000-6B81-1300-35DA-DD39-6115-76F3.dyn6.twc.com	2019-06-26 09:30:07.629651-07
3891	ipagstaticip-ce91908f-4a38-cb4c-d1be-5c4353ae21ac.sdsl.bell.ca	2019-06-26 11:51:13.634729-07
3892	cpe-2606-A000-6B84-3DF0-4541-3881-FB3C-C8F9.dyn6.twc.com	2019-06-27 13:10:15.713325-07
3893	cpe-2606-A000-6B84-3DF0-4541-3881-FB3C-C8F9.dyn6.twc.com	2019-06-27 13:31:24.394873-07
3894	cpe-2606-A000-6B84-3DF0-4541-3881-FB3C-C8F9.dyn6.twc.com	2019-06-27 13:54:40.664092-07
3895	cpe-2606-A000-6B84-3DF0-4541-3881-FB3C-C8F9.dyn6.twc.com	2019-06-27 14:02:02.988468-07
3896	cpe-2606-A000-6B84-3DF0-7417-B855-9F92-6A96.dyn6.twc.com	2019-06-28 01:41:38.602622-07
3897	cpe-2606-A000-6B84-3DF0-7417-B855-9F92-6A96.dyn6.twc.com	2019-06-28 03:16:48.779474-07
3898	cpe-2606-A000-6B84-3DF0-7417-B855-9F92-6A96.dyn6.twc.com	2019-06-28 03:25:42.388255-07
3899	cpe-69-132-97-204.carolina.res.rr.com	2019-06-28 04:55:12.582511-07
3900	2606:a000:6b84:3df0:7417:b855:9f92:6a96	2019-06-28 05:16:03.600325-07
3901	cpe-2606-A000-6B84-3DF0-7417-B855-9F92-6A96.dyn6.twc.com	2019-06-28 05:42:07.20111-07
3902	cpe-2606-A000-6B84-3DF0-7417-B855-9F92-6A96.dyn6.twc.com	2019-06-28 06:18:47.765765-07
3903	cpe-2606-A000-6B84-3DF0-7417-B855-9F92-6A96.dyn6.twc.com	2019-06-28 06:27:21.606239-07
3904	cpe-69-132-97-204.carolina.res.rr.com	2019-06-28 07:01:29.333734-07
3905	cpe-2606-A000-6B84-3DF0-7417-B855-9F92-6A96.dyn6.twc.com	2019-06-28 07:26:05.613542-07
3906	cpe-2606-A000-6B84-3DF0-7417-B855-9F92-6A96.dyn6.twc.com	2019-06-28 07:28:38.023423-07
3907	cpe-2606-A000-6B84-3DF0-7417-B855-9F92-6A96.dyn6.twc.com	2019-06-28 08:17:46.61703-07
3908	cpe-2606-A000-6B84-3DF0-7417-B855-9F92-6A96.dyn6.twc.com	2019-06-28 09:38:22.499076-07
3909	cpe-2606-A000-6B84-3DF0-7417-B855-9F92-6A96.dyn6.twc.com	2019-06-28 10:00:12.438584-07
3910	cpe-2606-A000-6B84-3DF0-7417-B855-9F92-6A96.dyn6.twc.com	2019-06-28 12:29:22.642601-07
3911	cpe-2606-A000-6B84-3DF0-7417-B855-9F92-6A96.dyn6.twc.com	2019-06-28 12:38:28.715403-07
3912	cpe-2606-A000-6B84-3DF0-7417-B855-9F92-6A96.dyn6.twc.com	2019-06-28 13:24:23.601046-07
3913	cpe-2606-A000-6B84-3DF0-7417-B855-9F92-6A96.dyn6.twc.com	2019-06-28 13:35:15.02704-07
3914	cpe-2606-A000-6B84-3DF0-C04F-23DF-BBFF-3C48.dyn6.twc.com	2019-07-01 02:52:42.612201-07
3915	cpe-2606-A000-6B84-3DF0-C04F-23DF-BBFF-3C48.dyn6.twc.com	2019-07-01 03:55:40.554264-07
3916	cpe-2606-A000-6B84-3DF0-C04F-23DF-BBFF-3C48.dyn6.twc.com	2019-07-01 04:06:35.390101-07
3917	cpe-2606-A000-6B84-3DF0-C04F-23DF-BBFF-3C48.dyn6.twc.com	2019-07-01 04:55:20.860859-07
3918	cpe-2606-A000-6B84-3DF0-C04F-23DF-BBFF-3C48.dyn6.twc.com	2019-07-01 05:10:39.067156-07
3919	cpe-2606-A000-6B84-3DF0-C04F-23DF-BBFF-3C48.dyn6.twc.com	2019-07-01 05:24:58.803591-07
3920	cpe-69-132-97-204.carolina.res.rr.com	2019-07-01 06:30:21.671656-07
3921	cpe-2606-A000-6B84-3DF0-FD55-389F-BC3F-E574.dyn6.twc.com	2019-07-01 06:46:13.745428-07
3922	cpe-2606-A000-6B84-3DF0-FD55-389F-BC3F-E574.dyn6.twc.com	2019-07-01 06:55:25.616359-07
3923	cpe-2606-A000-6B84-3DF0-FD55-389F-BC3F-E574.dyn6.twc.com	2019-07-01 07:23:22.398918-07
3924	cpe-2606-A000-6B84-3DF0-FD55-389F-BC3F-E574.dyn6.twc.com	2019-07-01 07:36:14.631245-07
3925	cpe-2606-A000-6B84-3DF0-FD55-389F-BC3F-E574.dyn6.twc.com	2019-07-01 07:57:06.334667-07
3926	cpe-2606-A000-6B84-3DF0-FD55-389F-BC3F-E574.dyn6.twc.com	2019-07-01 08:11:56.474363-07
3927	cpe-2606-A000-6B84-3DF0-FD55-389F-BC3F-E574.dyn6.twc.com	2019-07-01 08:12:33.746419-07
3928	cpe-2606-A000-6B84-3DF0-FD55-389F-BC3F-E574.dyn6.twc.com	2019-07-01 08:45:56.953263-07
3929	cpe-2606-A000-6B84-3DF0-FD55-389F-BC3F-E574.dyn6.twc.com	2019-07-01 09:03:12.601621-07
3930	host-72-174-12-143.msl-mt.client.bresnan.net	2019-07-01 13:03:12.634025-07
3931	host-72-174-12-143.msl-mt.client.bresnan.net	2019-07-01 13:04:05.376743-07
3932	cpe-2606-A000-6B81-1300-40-6AAD-AE03-C322.dyn6.twc.com	2019-07-01 14:40:12.429655-07
3933	cpe-2606-A000-6B81-1300-40-6AAD-AE03-C322.dyn6.twc.com	2019-07-01 18:08:19.391497-07
3934	cpe-2606-A000-6B84-3DF0-3057-8918-F50D-183D.dyn6.twc.com	2019-07-02 03:08:39.732642-07
3935	cpe-2606-A000-6B84-3DF0-3057-8918-F50D-183D.dyn6.twc.com	2019-07-02 03:45:20.40372-07
3936	host-72-174-12-143.msl-mt.client.bresnan.net	2019-07-02 04:45:00.202785-07
3937	cpe-2606-A000-6B84-3DF0-3057-8918-F50D-183D.dyn6.twc.com	2019-07-02 04:51:29.022168-07
3938	cpe-2606-A000-6B84-3DF0-3057-8918-F50D-183D.dyn6.twc.com	2019-07-02 05:46:53.622314-07
3939	74-93-28-142-Washington.hfc.comcastbusiness.net	2019-07-02 11:15:20.808349-07
3940	74-93-28-142-Washington.hfc.comcastbusiness.net	2019-07-02 11:16:19.77544-07
3941	cpe-2606-A000-6B84-3DF0-3864-91B1-C9C6-32E6.dyn6.twc.com	2019-07-03 02:43:17.637563-07
3942	cpe-2606-A000-6B84-3DF0-3864-91B1-C9C6-32E6.dyn6.twc.com	2019-07-03 04:55:19.100102-07
3943	cpe-2606-A000-6B84-3DF0-3864-91B1-C9C6-32E6.dyn6.twc.com	2019-07-03 05:01:08.618514-07
\.


--
-- Name: object_id_seq; Type: SEQUENCE SET; Schema: public; Owner: jim
--

SELECT pg_catalog.setval('public.object_id_seq', 3943, true);


--
-- Data for Name: object_type_tables; Type: TABLE DATA; Schema: public; Owner: jim
--

COPY public.object_type_tables (object_type, table_name, id_column) FROM stdin;
\.


--
-- Data for Name: object_types; Type: TABLE DATA; Schema: public; Owner: jim
--

COPY public.object_types (object_type, supertype, extension_table, ext_tbl_id_column, table_name, id_column, package_name, pretty_name, pretty_plural, abstract_p, type_extension_table, name_method, dynamic_p) FROM stdin;
object	\N	\N	\N	objects	object_id	object	Object	Objects	f	\N	\N	f
\.


--
-- Data for Name: objects; Type: TABLE DATA; Schema: public; Owner: jim
--

COPY public.objects (object_id, object_type, creation_date, creation_ip, last_modified, modifying_ip, modifying_user, creation_user, context_id, package_id, title) FROM stdin;
\.


--
-- Name: t_attribute_id_seq; Type: SEQUENCE SET; Schema: public; Owner: jim
--

SELECT pg_catalog.setval('public.t_attribute_id_seq', 10, true);


--
-- Name: datatypes acs_datatypes_datatype_pk; Type: CONSTRAINT; Schema: public; Owner: jim
--

ALTER TABLE ONLY public.datatypes
    ADD CONSTRAINT acs_datatypes_datatype_pk PRIMARY KEY (datatype);


--
-- Name: object_type_tables acs_object_type_tables_pk; Type: CONSTRAINT; Schema: public; Owner: jim
--

ALTER TABLE ONLY public.object_type_tables
    ADD CONSTRAINT acs_object_type_tables_pk PRIMARY KEY (object_type, table_name);


--
-- Name: attributes attributes_attr_name_un; Type: CONSTRAINT; Schema: public; Owner: jim
--

ALTER TABLE ONLY public.attributes
    ADD CONSTRAINT attributes_attr_name_un UNIQUE (attribute_name, object_type);


--
-- Name: attributes attributes_attribute_id_pk; Type: CONSTRAINT; Schema: public; Owner: jim
--

ALTER TABLE ONLY public.attributes
    ADD CONSTRAINT attributes_attribute_id_pk PRIMARY KEY (attribute_id);


--
-- Name: attributes attributes_pretty_name_un; Type: CONSTRAINT; Schema: public; Owner: jim
--

ALTER TABLE ONLY public.attributes
    ADD CONSTRAINT attributes_pretty_name_un UNIQUE (pretty_name, object_type);


--
-- Name: attributes attributes_sort_order_un; Type: CONSTRAINT; Schema: public; Owner: jim
--

ALTER TABLE ONLY public.attributes
    ADD CONSTRAINT attributes_sort_order_un UNIQUE (attribute_id, sort_order);


--
-- Name: factoids factoids_pk; Type: CONSTRAINT; Schema: public; Owner: jim
--

ALTER TABLE ONLY public.factoids
    ADD CONSTRAINT factoids_pk PRIMARY KEY (key);


--
-- Name: object_types object_type_pk; Type: CONSTRAINT; Schema: public; Owner: jim
--

ALTER TABLE ONLY public.object_types
    ADD CONSTRAINT object_type_pk PRIMARY KEY (object_type);


--
-- Name: objects objects_pk; Type: CONSTRAINT; Schema: public; Owner: jim
--

ALTER TABLE ONLY public.objects
    ADD CONSTRAINT objects_pk PRIMARY KEY (object_id);


--
-- Name: attributes attributes_datatype_fk; Type: FK CONSTRAINT; Schema: public; Owner: jim
--

ALTER TABLE ONLY public.attributes
    ADD CONSTRAINT attributes_datatype_fk FOREIGN KEY (datatype) REFERENCES public.datatypes(datatype);


--
-- Name: attributes attributes_object_type_fk; Type: FK CONSTRAINT; Schema: public; Owner: jim
--

ALTER TABLE ONLY public.attributes
    ADD CONSTRAINT attributes_object_type_fk FOREIGN KEY (object_type) REFERENCES public.object_types(object_type);


--
-- Name: attributes attrs_obj_type_tbl_name_fk; Type: FK CONSTRAINT; Schema: public; Owner: jim
--

ALTER TABLE ONLY public.attributes
    ADD CONSTRAINT attrs_obj_type_tbl_name_fk FOREIGN KEY (object_type, table_name) REFERENCES public.object_type_tables(object_type, table_name);


--
-- Name: object_type_tables obj_type_tbls_obj_type_fk; Type: FK CONSTRAINT; Schema: public; Owner: jim
--

ALTER TABLE ONLY public.object_type_tables
    ADD CONSTRAINT obj_type_tbls_obj_type_fk FOREIGN KEY (object_type) REFERENCES public.object_types(object_type);


--
-- Name: objects object_object_type_fk; Type: FK CONSTRAINT; Schema: public; Owner: jim
--

ALTER TABLE ONLY public.objects
    ADD CONSTRAINT object_object_type_fk FOREIGN KEY (object_type) REFERENCES public.object_types(object_type) ON DELETE SET NULL;


--
-- Name: object_types supertype__object_type__fk; Type: FK CONSTRAINT; Schema: public; Owner: jim
--

ALTER TABLE ONLY public.object_types
    ADD CONSTRAINT supertype__object_type__fk FOREIGN KEY (supertype) REFERENCES public.object_types(object_type);


--
-- PostgreSQL database dump complete
--

\connect odoo

SET default_transaction_read_only = off;

--
-- PostgreSQL database dump
--

-- Dumped from database version 9.6.14
-- Dumped by pg_dump version 9.6.14

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
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


--
-- PostgreSQL database dump complete
--

\connect postgres

SET default_transaction_read_only = off;

--
-- PostgreSQL database dump
--

-- Dumped from database version 9.6.14
-- Dumped by pg_dump version 9.6.14

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
-- Name: DATABASE postgres; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON DATABASE postgres IS 'default administrative connection database';


--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


--
-- PostgreSQL database dump complete
--

\connect template1

SET default_transaction_read_only = off;

--
-- PostgreSQL database dump
--

-- Dumped from database version 9.6.14
-- Dumped by pg_dump version 9.6.14

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
-- Name: DATABASE template1; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON DATABASE template1 IS 'default template for new databases';


--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


--
-- PostgreSQL database dump complete
--

--
-- PostgreSQL database cluster dump complete
--

