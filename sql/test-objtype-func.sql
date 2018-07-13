CREATE OR REPLACE FUNCTION attribute__delete(
   p_object_type varchar,
   p_attribute_name varchar,
   p_drop_column_p boolean default 'f'

) RETURNS integer AS $$
DECLARE
  v_table_name             acs_object_types.table_name%TYPE;
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
--
--   -- Drop the table if one were specified for the type and we're asked to
--   if p_drop_column_p and v_table_name is not null then
--       execute 'alter table ' || v_table_name || ' drop column ' ||
--         p_attribute_name || ' cascade';
--   end if;
--
--   -- Finally, get rid of the attribute
--   delete from acs_attributes
--   where object_type = p_object_type
--   and attribute_name = p_attribute_name;
--
  return 0;
END;
$$ LANGUAGE plpgsql;
