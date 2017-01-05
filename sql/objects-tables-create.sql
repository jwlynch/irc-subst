
create table object_type
(
  object_type varchar(100)
    constraint object_type_pk
      primary key
    constraint object_type_nn
      not null,
  extension_table varchar(100),
  ext_tbl_id_column varchar(100)
);

create table object
(
  object_id bigint
    constraint objects_pk
      primary key,
  object_type varchar(100)
    constraint object_type_nn
      not null
    constraint object_type_fk_ob_type
      references object_type(object_type),
  creation_date timestamptz
);

