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

from configparser import ConfigParser

class Test(object):
    def reload(self, scriptPath):
        parser = ConfigParser()
        conffiles = parser.read(scriptPath + '/' + 'irc-subst.cfg')

        if dex(scriptPath + '/' + 'irc-subst.cfg', conffiles) == -1:
            print("config file '" + scriptPath + "/irc-subst.cfg' cannot be found")

        # pull stuff from general section of config file
        if dex('general', parser.sections()) != -1:
            if dex('command-prefix', parser.options('general')) != -1:
                self.cmdPrefix = parser.get('general', 'command-prefix')
            else:
                # no command-prefix in general sect
                self.cmdPrefix = '.' # default

            if dex('print-config', parser.options('general')) != -1:
                self.printConfigP = parser.get('general', 'print-config')

                if self.printConfigP.startswith("t"):
                    self.printConfigP = True
                elif self.printConfigP.startswith("f"):
                    self.printConfigP = False
                else:
                    self.printConfigP = True # default
            else:
                # no print-config in general sect
                self.printConfigP = True # default

        else:
            # no general sect
            self.cmdPrefix = '.' # default
            self.printConfigP = True # default

        if dex("db", parser.sections()) == -1:
            self.dbOK = False
        else:
            self.dbOK = True

        self.dbSpecs = None
        self.sqlalchemy_conn_str = None

        if self.dbOK:
            self.dbSpecs = {}
            for option in parser.options('db'):
                self.dbSpecs[option] = parser.get('db', option)

            # build the sqlalchemy connect string
            k = self.dbSpecs.keys()

            s = "postgresql://"
            if 'user' in k:
                s += self.dbSpecs['user']
                if 'password' in k:
                    s += ':' + self.dbSpecs['password']

                if 'host' in k:
                    s += '@' + self.dbSpecs['host']
                else:
                    s += '@localhost'

                if 'port' in k:
                    s += ':' + self.dbSpecs['port']

            s += '/' + self.dbSpecs['dbname']
            self.sqlalchemy_conn_str = s

            self.sqla_eng = create_engine(self.sqlalchemy_conn_str, client_encoding='utf8')
            self.sqla_meta = MetaData()

            self.sqla_factoids_table = Table\
                                       (\
                                        "factoids",
                                        self.sqla_meta,
                                        autoload=True,
                                        autoload_with=self.sqla_eng
                                       )

            self.sqla_failed_logins_table = Table\
                                            (\
                                             "failed_logins_sasl",
                                             self.sqla_meta,
                                             autoload=True,
                                             autoload_with=self.sqla_eng
                                            )


        # print the config file (if desired)
        if self.printConfigP:
            print("config file: ")

            for sect in parser.sections():
                print("section %s:" % sect)
                for opt in parser.options(sect):
                    val = parser.get(sect, opt)
                    print("  %s = %s" % (opt, val))

            if self.dbOK:
                print("sqlalchemy_conn_str is " + self.sqlalchemy_conn_str)


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
