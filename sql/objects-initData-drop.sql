select attribute__delete(
    p_object_type => 'object',
    p_attribute_name => 'security_inherit_p',
    p_drop_column_p => 't'
);

select attribute__delete(
    p_object_type => 'object',
    p_attribute_name => 'title',
    p_drop_column_p => 't'
);

select attribute__delete(
    p_object_type => 'object',
    p_attribute_name => 'package_id',
    p_drop_column_p => 't'
);

select attribute__delete(
    p_object_type => 'object',
    p_attribute_name => 'context_id',
    p_drop_column_p => 't'
);

select attribute__delete(
    p_object_type => 'object',
    p_attribute_name => 'creation_user',
    p_drop_column_p => 't'
);

select attribute__delete(
    p_object_type => 'object',
    p_attribute_name => 'modifying_user',
    p_drop_column_p => 't'
);

select attribute__delete(
    p_object_type => 'object',
    p_attribute_name => 'modifying_ip',
    p_drop_column_p => 't'
);

select attribute__delete(
    p_object_type => 'object',
    p_attribute_name => 'last_modified',
    p_drop_column_p => 't'
);

select attribute__delete(
    p_object_type => 'object',
    p_attribute_name => 'creation_ip',
    p_drop_column_p => 't'
);

select attribute__delete(
    p_object_type => 'object',
    p_attribute_name => 'creation_date',
    p_drop_column_p => 't'
);

select attribute__delete(
    p_object_type => 'object',
    p_attribute_name => 'object_type',
    p_drop_column_p => 't'
);

select object_type__delete
(
    'object',
    p_drop_children_p => 't',
    p_drop_table_p => 't'
);
