# class and methods for dealing with objects and object types

from sqlalchemy import select, func
from utils import commandtarget

class Objects(commandtarget.CommandTarget):
    def nextObjectID(self, conn):
        seq_sel = select([func.nextval('object_id_seq')])
        # scalar executes, and gets first col of first row
        result = conn.scalar(seq_sel)

        return result
