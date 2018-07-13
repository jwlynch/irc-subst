drop table attributes;

drop view attribute_id_seq;
drop sequence t_attribute_id_seq;

drop table object_type_tables;

drop table datatypes;

delete from object_types
    where object_type = 'object';

drop table objects;

drop table object_types;
