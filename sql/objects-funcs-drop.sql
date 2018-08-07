--
-- deletes the object functions
--

drop FUNCTION acs_datatype__timestamp_output_function(
   p_attribute_name text
);

drop FUNCTION acs_datatype__date_output_function(
   p_attribute_name text
);

drop FUNCTION attribute__delete(
   p_object_type varchar,
   p_attribute_name varchar,
   p_drop_column_p boolean

);

drop FUNCTION attribute__new(
   p_object_type varchar,
   p_attribute_name varchar,
   p_datatype varchar,
   p_pretty_name varchar,
   p_pretty_plural varchar,
   p_table_name varchar,
   p_column_name varchar,
   p_default_value varchar,
   p_min_n_values integer,
   p_max_n_values integer,
   p_sort_order integer,
   p_storage varchar,
   p_static_p boolean,
   p_create_column_p boolean,
   p_database_type varchar,
   p_size varchar,
   p_null_p boolean,
   p_references varchar,
   p_check_expr varchar,
   p_column_spec varchar
);

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
