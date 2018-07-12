drop FUNCTION attribute__new(
   p_object_type varchar,
   p_attribute_name varchar,
   p_datatype varchar,
   p_pretty_name varchar,
   p_pretty_plural varchar,   -- default null
   p_table_name varchar,      -- default null
   p_column_name varchar,     -- default null
   p_default_value varchar,   -- default null
   p_min_n_values integer,    -- default 1 -- default '1'
   p_max_n_values integer,    -- default 1 -- default '1'
   p_sort_order integer,      -- default null
   p_storage varchar,         -- default 'type_specific'
   p_static_p boolean,        -- default 'f'
   p_create_column_p boolean, -- default 'f'
   p_database_type varchar,   -- default null
   p_size varchar,            -- default null
   p_null_p boolean,          -- default 't'
   p_references varchar,      -- default null
   p_check_expr varchar,      -- default null
   p_column_spec varchar      -- default null

);
