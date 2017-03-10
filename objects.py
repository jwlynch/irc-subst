# class, methods and funcs for dealing with objects and object types

from sqlalchemy import select, func

def nextObjectID(conn):
    seq_sel = select([func.nextval('object_id_seq')])
    # scalar executes, and gets first col of first row
    result = conn.scalar(seq_sel)

    return result

class Objects():
    pass
