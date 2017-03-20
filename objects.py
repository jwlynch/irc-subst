# class, methods and funcs for dealing with objects and object types

from sqlalchemy import select, func, Table, MetaData, Column

def nextObjectID(conn):
    seq_sel = select([func.nextval('object_id_seq')])
    # scalar executes, and gets first col of first row
    result = conn.scalar(seq_sel)

    return result

class Objects(object):
    def __init__(self, engine, metadata):
        self.engine = engine
        self.metadata = metadata

