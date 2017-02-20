--
-- funcs for objects: create/drop object/type
--
-- create type
--
-- accepts:
--
-- returns: nothing
--

create or replace function object_type__new(
   p_object_type varchar,
   p_pretty_name varchar,
   p_pretty_plural varchar,
   p_supertype varchar,
   p_table_name varchar,           -- default null
   p_id_column varchar,            -- default null
   p_package_name varchar,         -- default null
   p_abstract_p boolean,           -- default 'f'
   p_type_extension_table varchar, -- default null
   p_name_method varchar,          -- default null
   p_create_table_p boolean,       -- default 'f'
   p_dynamic_p boolean             -- default 'f'
				    
)
returns void
language 'plpgsql'
as
$$
  begin
  end;
$$;

create or replace function object_type__delete(
)
returns void
language 'plpgsql'
as
$$
  begin
  end;
$$;

