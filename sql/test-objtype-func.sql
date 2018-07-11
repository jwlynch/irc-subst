CREATE OR REPLACE FUNCTION object_type__delete(
   p_object_type varchar,
   p_drop_children_p boolean default 'f',
   p_drop_table_p boolean    default 'f'

) RETURNS varchar AS $$
DECLARE
  row                               record;
  object_row                        record;
  v_table_name                      object_types.table_name%TYPE;

  v_test_out                         varchar;
BEGIN
  v_test_out = 'p_object_type is ' || p_object_type;

    -- drop children recursively
    if p_drop_children_p then
      for row in select object_type
                 from acs_object_types
                 where supertype = p_object_type
      loop
        perform object_type__delete(row.object_type, 't', p_drop_table_p);
      end loop;
    end if;

  return v_test_out;
END;
$$ LANGUAGE plpgsql;


--
-- procedure acs_object_type__drop_type/3
--
-- (got stuff from here)
--
--
--   -- drop all the attributes associated with this type
--   for row in select attribute_name
--              from acs_attributes
--              where object_type = p_object_type
--   loop
--     perform acs_attribute__drop_attribute (p_object_type, row.attribute_name);
--   end loop;
--
--   -- Remove the associated table if it exists and p_drop_table_p is true
--
--   if p_drop_table_p then
--
--     select table_name into v_table_name
--     from acs_object_types
--     where object_type = p_object_type;
--
--     if found then
--       if not exists (select 1
--                      from pg_class
--                      where relname = lower(v_table_name)) then
--         raise exception 'Table "%" does not exist', v_table_name;
--       end if;
--
--       execute 'drop table ' || v_table_name || ' cascade';
--     end if;
--
--   end if;
--
--   delete from acs_object_types
--   where object_type = p_object_type;
--
-- (and from here)
