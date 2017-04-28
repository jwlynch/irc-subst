# class, methods and funcs for dealing with objects and object types

# to READ an object, find its object type, read from the type table the superclass,
# find a complete chain of superclasses, then using the object ID, read the rows of
# each supertype tables, and form a hash of types, each type leading to a hash
# of table columns, each of which leads to a value.
#
# to WRITE an object, first read the columnsfrom each type table, forming a hash
# as above, then (using python assignments) fill in that structure like it was
# a form, get a new object ID, then insert a row in each of the type extension
# tableswith the values in the hash structure.
#
# to EDIT (or update) an object, first READ it, then change whatever attribs,
# then write it back to each table using update thetable where ob_id=...
#
# checking should be done, for example for columns that have nullable=False
# make sure they have a value, etc
#
# TODO: the types table needs a supertype column

from sqlalchemy import select, func, Table, MetaData, Column
from sqlalchemy.types import BigInteger, DateTime, String
from sqlalchemy import create_engine, ForeignKey

# index of item in list, or -1 if ValueError
def dex(item, lst):
    result = -1

    try:
        result = lst.index(item)
    finally:
        return result

def nextObjectID(conn):
    seq_sel = select([func.nextval('object_id_seq')])
    # scalar executes, and gets first col of first row
    result = conn.scalar(seq_sel)

    return result


class Objects(object):
    def __init__(self, engine, metadata):
        self.engine = engine
        self.metadata = metadata

        self.object_type_table = Table(
            "object_type",
            self.metadata,
            Column(
                "object_type",
                String(100),
                nullable=False,
                primary_key = True
            ),
            Column(
                "supertype",
                String(100),
                ForeignKey("object_type.object_type")
            ),
            Column("extension_table", String(100)),
            Column("ext_tbl_id_column", String(100))
        )

        self.objects_table = Table(
            "object",
            self.metadata,
            Column("object_id", BigInteger, primary_key = True),
            Column(
                "object_type",
                String(100),
                ForeignKey("object_type.object_type"),
                nullable=False
            ),
            Column("creation_date", DateTime(timezone=True)),
            Column(
                "creation_user",
                BigInteger,
                ForeignKey("object.object_id")
            ),
            Column(
                "context_id",
                BigInteger,
                ForeignKey("object.object_id")
            )
        )

    def object__new(self, conn, **kwargs):
        pass

    def object_type__new(self, conn, **kwargs):
        pass
