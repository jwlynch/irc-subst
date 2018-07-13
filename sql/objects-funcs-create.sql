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
   p_supertype varchar             default 'object',
   p_table_name varchar            default null,
   p_id_column varchar             default null,
   p_package_name varchar          default null,
   p_abstract_p boolean            default 'f',
   p_type_extension_table varchar  default null,
   p_name_method varchar           default null,
   p_create_table_p boolean        default 'f',
   p_dynamic_p boolean             default 'f'
)
-- final func should return integer
returns varchar
language 'plpgsql'
as
$$
  declare
    v_package_name                      object_types.package_name%TYPE;
    v_supertype                         object_types.supertype%TYPE;
    v_name_method                       varchar;
    v_idx                               integer;
    v_temp_p                            boolean;
    v_supertype_table                   object_types.table_name%TYPE;
    v_id_column                         object_types.id_column%TYPE;
    v_table_name                        object_types.table_name%TYPE;

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

         if p_create_table_p then

           if exists (select 1
                      from pg_class
                      where relname = lower(v_table_name)) then
             raise exception 'Table "%" already exists', v_table_name;
           end if;

           loop
             select table_name,object_type into v_supertype_table,v_supertype
             from object_types
             where object_type = v_supertype;
             exit when v_supertype_table is not null;
           end loop;

           execute
             'create table ' || v_table_name || ' (' ||
             v_id_column || ' integer constraint ' || v_table_name ||
             '_pk primary key ' || ' constraint ' || v_table_name ||
             '_fk references ' || v_supertype_table || ' on delete cascade)';
         end if;


      return v_test_out; -- should return 0 in final func
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

-- object_type__delete()/3

CREATE OR REPLACE FUNCTION object_type__delete(
    p_object_type varchar,
    p_drop_children_p boolean default 'f',
    p_drop_table_p boolean    default 'f'

) RETURNS varchar AS $$
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
$$ LANGUAGE plpgsql;

--
-- procedure attribute__new/20
--
CREATE OR REPLACE FUNCTION attribute__new(
   p_object_type varchar,
   p_attribute_name varchar,
   p_datatype varchar,
   p_pretty_name varchar,
   p_pretty_plural varchar     default null,
   p_table_name varchar        default null,
   p_column_name varchar       default null,
   p_default_value varchar     default null,
   p_min_n_values integer      default 1, -- default '1'
   p_max_n_values integer      default 1, -- default '1'
   p_sort_order integer        default null,
   p_storage varchar           default 'type_specific',
   p_static_p boolean          default 'f',
   p_create_column_p boolean   default 'f',
   p_database_type varchar     default null,
   p_size varchar              default null,
   p_null_p boolean            default 't',
   p_references varchar        default null,
   p_check_expr varchar        default null,
   p_column_spec varchar       default null

) RETURNS integer AS $$
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
$$ LANGUAGE 'plpgsql';
