
create table object_types
(
  object_type varchar(100)
    constraint object_type_pk
      primary key
    constraint object_type_nn
      not null,
  supertype varchar(100)
    constraint supertype__object_type__fk
      references object_types(object_type),
  extension_table varchar(100),
  ext_tbl_id_column varchar(100),
  table_name varchar(100),
  id_column varchar(100),
  package_name varchar(100),
  pretty_name varchar(100),
  pretty_plural varchar(100),
  abstract_p boolean,
  type_extension_table varchar(100),
  name_method varchar(100),
  dynamic_p boolean
);

comment on table object_types is '
 Each row in the acs_object_types table represents a distinct class
 of objects. For each instance of any acs_object_type, there is a
 corresponding row in the acs_objects table. Essentially,
 acs_objects.object_id supersedes the on_which_table/on_what_id pair
 that ACS 3.x used as the system-wide identifier for heterogeneous
 objects. The value of having a system-wide identifier for
 heterogeneous objects is that it helps us provide general solutions
 for common problems like access control, workflow, categorppization,
 and search. (Note that this framework is not overly restrictive,
 because it doesn''t force every type of object to be represented in
 the acs_object_types table.) Each acs_object_type has:
 * Attributes (stored in the acs_attributes table)
   Examples:
   * the "user" object_type has "email" and "password" attributes
   * the "content_item" object_type has "title" and "body" attributes
 * Relationship types (stored in the acs_rel_types table)
   Examples:
   * "a team has one team leader who is a user" (in other words,
     instances of the "team" object_type must have one "team leader"
     relationship to an instance of the "user" object_type)
   * "a content item may have zero or authors who are people or
     organizations, i.e., parties" (in other words, instances of
     the "content_item" object_type may have zero or more "author"
     relationships to instances of the "party" object_type)
 Possible extensions include automatic versioning, logical deletion,
 and auditing.
';

comment on column object_types.supertype is '
 The object_type of which this object_type is a specialization (if
 any). For example, the supertype of the "user" object_type is
 "person". An object_type inherits the attributes and relationship
 rules of its supertype, though it can add constraints to the
 attributes and/or it can override the relationship rules. For
 instance, the "person" object_type has an optional "email" attribute,
 while its "user" subtype makes "email" mandatory.
';

comment on column object_types.abstract_p is '
 ...
 If the object_type is not abstract, then all of its attributes must
 have a non-null storage specified.
';

comment on column object_types.table_name is '
 The name of the type-specific table in which the values of attributes
 specific to this object_type are stored, if any.
';

comment on column object_types.id_column is '
 The name of the primary key column in the table identified by
 table_name.
';

comment on column object_types.name_method is '
 The name of a stored function that takes an object_id as an argument
 and returns a varchar2: the corresponding object name. This column is
 required to implement the polymorphic behavior of the acs.object_name()
 function.
';

comment on column object_types.type_extension_table is '
 Object types (and their subtypes) that require more type-specific
 data than the fields already existing in object_types may name
 a table in which that data is stored.  The table should be keyed
 by the associated object_type.  For example, a row in the group_types
 table stores a default approval policy for every user group of that type.
 In this example, the group_types table has a primary key named
 group_type that references object_types.  If a subtype of groups
 for example, lab_courses, has its own type-specific data, it could be
 maintained in a table called lab_course_types, with a primary key named
 lab_course_type that references group_types.  This provides the same
 functionality as static class fields in an object-oriented programming language.
';


comment on column object_types.dynamic_p is '
  This flag is used to identify object types created dynamically
  (e.g. through a web interface). Dynamically created object types can
  be administered differently. For example, the group type admin pages
  only allow users to add attributes or otherwise modify dynamic
  object types. This column is still experimental and may not be supported in the
  future. That is the reason it is not yet part of the API.
';

------------------------------------
-- DATATYPES AND ATTRIBUTES --
------------------------------------

create table datatypes (
	datatype	varchar(50) not null
			constraint acs_datatypes_datatype_pk primary key,
	max_n_values	integer default 1
			constraint acs_datatypes_max_n_values_ck
			check (max_n_values > 0),
        database_type   text,
        column_size     text,
        column_check_expr text,
        column_output_function text
);

comment on table datatypes is '
 Defines the set of available abstract datatypes for attributes, along with
 an optional default mapping to a database type, size, and constraint to use if the
 attribute is created with create_attribute''s storage_type param set to "type_specific"
 and the create_storage_p param is set to true.  These defaults can be overwritten by
 the caller.

 The set of pre-defined datatypes is inspired by XForms
 (http://www.w3.org/TR/xforms-datamodel/).
';

comment on column datatypes.max_n_values is '
 The maximum number of values that any attribute with this datatype
 can have. Of the predefined attribute types, only "boolean" specifies
 a non-null max_n_values, because it doesn''t make sense to have a
 boolean attribute with more than one value. There is no
 corresponding min_n_values column, because each attribute may be
 optional, i.e., min_n_values would always be zero.
';

comment on column datatypes.database_type is '
  The base database type corresponding to the abstract datatype.  For example "varchar" or
  "integer".
';

comment on column datatypes.column_size is '
  Optional default column size specification to append to the base database type.  For
  example "1000" for the "string" abstract datatype, or "10,2" for "number".
';

comment on column datatypes.column_check_expr is '
  Optional check constraint expression to declare for the type_specific database column.  In
  Oracle, for instance, the abstract "boolean" type is declared "text", with a column
  check expression to restrict the values to "f" and "t".
';

comment on column datatypes.column_output_function is '
  Function to call for this datatype when building a select view.  If not null, it will
  be called with an attribute name and is expected to return an expression on that
  attribute.  Example: date attributes will be transformed to calls to "to_char()".
';

-- Load pre-defined datatypes.
--
begin;
 insert into datatypes
  (datatype, max_n_values, database_type, column_size)
 values
  ('string', null, 'varchar', '4000');

 insert into datatypes
  (datatype, max_n_values, database_type, column_size)
 values
  ('boolean', 1, 'bool', null);

 insert into datatypes
  (datatype, max_n_values, database_type, column_size)
 values
  ('number', null, 'numeric', '10,2');

 insert into datatypes
  (datatype, max_n_values, database_type, column_size)
 values
  ('integer', 1, 'integer', null);

 insert into datatypes
  (datatype, max_n_values, database_type, column_size)
 values
  ('currency', null, 'money', null);

 insert into datatypes
  (datatype, max_n_values, database_type, column_output_function)
 values
  ('date', null, 'timestamp', 'acs_datatype__date_output_function');

 insert into datatypes
  (datatype, max_n_values, database_type, column_output_function)
 values
  ('timestamp', null, 'timestamp', 'acs_datatype__timestamp_output_function');

 insert into datatypes
  (datatype, max_n_values, database_type, column_output_function)
 values
  ('time_of_day', null, 'timestamp', 'acs_datatype__timestamp_output_function');

 insert into datatypes
  (datatype, max_n_values, database_type, column_size)
 values
  ('enumeration', null, 'varchar', '100');

 insert into datatypes
  (datatype, max_n_values, database_type, column_size)
 values
  ('url', null, 'varchar', '250');

 insert into datatypes
  (datatype, max_n_values, database_type, column_size)
 values
  ('email', null, 'varchar', '200');

 insert into datatypes
  (datatype, max_n_values, database_type, column_size)
 values
  ('file', 1, 'varchar', '100');

insert into datatypes
 (datatype, max_n_values, database_type, column_size)
values
 ('text', null, 'text', null);

insert into datatypes
  (datatype, max_n_values, database_type)
values
  ('keyword', 1, 'text');

insert into datatypes
 (datatype, max_n_values, database_type, column_size)
values
 ('richtext', null, 'text', null);

insert into datatypes
 (datatype, max_n_values, database_type, column_size)
values
 ('filename', null, 'varchar', '100');

insert into datatypes
 (datatype, max_n_values, database_type, column_size)
values
 ('float', null, 'float8', null);

-- PG 8.x has no unsigned integer datatype
insert into datatypes
 (datatype, max_n_values, database_type, column_size)
values
 ('naturalnum', null, 'integer', null);

end;

-- we might have to add the supertype__object_type__fk constraint
-- after defining the table

create table objects
(
  object_id bigint
    constraint objects_pk
      primary key,
  object_type varchar(100)
    constraint object_type_nn
      not null
    constraint object_type_fk_ob_type
      references object_types(object_type),
  creation_date timestamptz,
  creation_user bigint
    constraint creation_user__object_id__fk
      references objects(object_id),
  context_id bigint
    constraint context_id__object_id__fk
      references objects(object_id)
);

comment on table objects is '
The root table for the acs object heirarchy.  It all starts here folks.
';

comment on column objects.context_id is '
 The context_id column points to an object that provides a context for
 this object. Often this will reflect an observed hierarchy in a site,
 for example a bboard message would probably list a bboard topic as
 it''s context, and a bboard topic might list a sub-site as it''s
 context. Whenever we ask a question of the form "can user X perform
 action Y on object Z", the acs security model will defer to an
 object''s context if there is no information about user X''s
 permission to perform action Y on object Z.
';

comment on column objects.creation_user is '
 Who created the object; may be null since objects can be created by
 automated processes
';

comment on column objects.modifying_user is '
 Who last modified the object
';

comment on column objects.package_id is '
 Which package instance this object belongs to.
 Please note that in mid-term this column will replace all
 package_ids of package specific tables.
';

comment on column objects.title is '
 Title of the object if applicable.
 Please note that in mid-term this column will replace all
 titles or object_names of package specific tables.
';

insert
    into object_types
    (
        object_type,
        pretty_name,
        pretty_plural,
        supertype,
        table_name,
        id_column
    )
    values
    (
        'object',
        'Object',
        'Objects',
        NULL,
        'objects',
        'object_id'
    );
