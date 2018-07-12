--
-- deletes the object functions
--

drop function object_type__delete(
  p_object_type varchar,
  p_drop_children_p boolean,
  p_drop_table_p boolean
);

drop function object_type__new(
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
);
