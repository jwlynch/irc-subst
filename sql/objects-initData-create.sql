-- create 'object' type

select object_type__new
(
    'object',
    'Object',
    'Objects',
    p_supertype => NULL,
    p_table_name => 'objects',
    p_id_column => 'object_id',
    p_create_table_p => 't'
);
