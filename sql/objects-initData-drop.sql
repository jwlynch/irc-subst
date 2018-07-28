select object_type__delete
(
    'object',
    p_drop_children_p => 't',
    p_drop_table_p => 't'
);
