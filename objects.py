# class, methods and funcs for dealing with objects and object types

from sqlalchemy import select, func, Table, MetaData, Column
from sqlalchemy.types import BigInteger, DateTime, String

def nextObjectID(conn):
    seq_sel = select([func.nextval('object_id_seq')])
    # scalar executes, and gets first col of first row
    result = conn.scalar(seq_sel)

    return result

class Objects(object):
    def __init__(self, engine, metadata):
        self.engine = engine
        self.metadata = metadata

        self.objects_table = Table(
            "object",
            self.metadata,
            Column("object_id", BigInteger, primary_key = True),
            Column(
                "object_type",
                String(100),
                nullable=False,
                ForeignKey("object_type.object_type")
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

        self.object_type_table = Table(
            "object_type",
            self.metadata,
            autoload=True,
            autoload_with=self.engine
        )
