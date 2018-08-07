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

select  attribute__new (
  p_object_type => 'object',
  p_attribute_name => 'object_type',
  p_datatype => 'string',      --
  p_pretty_name => 'Object Type',
  p_pretty_plural => 'Object Types',
  p_references => 'object_types',

  p_create_column_p => 't'
);

select attribute__new (
  p_object_type => 'object',
  p_attribute_name => 'creation_date',
  p_datatype => 'date',
  p_pretty_name => 'Created Date',

  p_create_column_p => 't'
);

select attribute__new (
    p_object_type => 'object',
    p_attribute_name => 'creation_ip',
    p_datatype => 'string',
    p_pretty_name => 'Creation IP Address',

    p_create_column_p => 't'
);

select attribute__new (
  p_object_type => 'object',
  p_attribute_name => 'last_modified',
  p_datatype => 'date',
  p_pretty_name => 'Last Modified On',

  p_create_column_p => 't'
);

select attribute__new (
  p_object_type => 'object',
  p_attribute_name => 'modifying_ip',
  p_datatype => 'string',
  p_pretty_name => 'Modifying IP Address',

  p_create_column_p => 't'
);

select attribute__new (
  p_object_type => 'object',
  p_attribute_name => 'modifying_user',
  p_datatype => 'integer',
  p_pretty_name => 'Modifying User',

  p_create_column_p => 't'
);

select attribute__new (
   p_object_type => 'object',
   p_attribute_name => 'creation_user',
   p_datatype => 'integer',
   p_pretty_name => 'Creation user',
   p_pretty_plural => 'Creation users',

   p_create_column_p => 't'
);

select attribute__new (
   p_object_type => 'object',
   p_attribute_name => 'context_id',
   p_datatype => 'integer',
   p_pretty_name => 'Context ID',
   p_pretty_plural => 'Context IDs',
   p_min_n_values => 0,
   p_max_n_values => 1,

   p_create_column_p => 't'
);

select attribute__new (
   p_object_type => 'object',
   p_attribute_name => 'package_id',
   p_datatype => 'integer',
   p_pretty_name => 'Package ID',
   p_pretty_plural => 'Package IDs',
   p_min_n_values => 0,
   p_max_n_values => 1,

   p_create_column_p => 't'
);

select attribute__new (
   p_object_type => 'object',
   p_attribute_name => 'title',
   p_datatype => 'string',
   p_pretty_name => 'Title',
   p_pretty_plural => 'Titles',
   p_min_n_values => 0,
   p_max_n_values => 1,

   p_create_column_p => 't'
);

select attribute__new (
   p_object_type => 'object',
   p_attribute_name => 'security_inherit_p',
   p_datatype => 'boolean',
   p_pretty_name => 'Security Inherits P',

   p_create_column_p => 't'
);
