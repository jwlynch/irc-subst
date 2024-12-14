# this class's instances will contain:
#  - sqla_eng, an engine produced from the db specs.
#  - sqla_meta, bound to the engine created above.
#  - sqla_factoids_table, a list of factoids and keys.
#  - sqla_failed_logins_table, list of failed logins
#      together with their IP address.

from sqlalchemy import create_engine, MetaData, Table
from sqlalchemy import Column, Integer, String, ForeignKey
from sqlalchemy import select, func

class SqlA_DbUtils:
    def __init__(self, dbspecs):
        # NOTE: dbspecs is expected to be a dictionary, specifically the
        # config["db"] dict.
        self.config = {}
        self.config["db"] = dbspecs

        self.sqla_eng = create_engine(
                                            dbspecs["sqlalchemy_conn_str"],
                                            client_encoding='utf8'
                                        )
        self.sqla_meta = MetaData(bind=self.sqla_eng)
        self.sqla_meta.reflect()

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
    # a database select function that can accept
    # filter arguments, as well as order by args

    def factoid_select(self, filtering=None, ordering=None):
        sel = select([self.sqla_factoids_table])

        if filtering is not None:
            sel = sel.where(filtering)

        if ordering is not None:
            sel = sel.order_by(ordering)

        return sel

    # accepts list of keys (strings of the form "[[somekey]]"),
    # optionally followed by an existing dict, which will be used
    # to store additional key/value pairs.
    #
    # returns a dictionary (possibly the one passed in) with those
    # keys as keys, and values that come from the db

    def lookupKeyList(self, key_list, running_dict=None):
        # now query the db
        if running_dict is None:
            lookup = dict()
        else:
            lookup = running_dict

        if len(key_list) == 0:
            pass # through to return stmt, returning empty dict
        elif self.config["db"]["dbOK"]:
            factoids = self.sqla_factoids_table

            # "select * from factoids where key in (key_list)"
            sel_stmt = select([factoids]).\
                            where\
                              (\
                                factoids.c.key.in_(key_list)
                              )

            with self.sqla_eng.begin() as conn:
                result = conn.execute(sel_stmt)

            # go through results, forming a lookup table
            for row in result:
                lookup[row[factoids.c.key]] = row[factoids.c.value]
        else:
            # populate lookup table with (no db) for each key
            for key in key_list:
                lookup[key] = "(no db)"

        return lookup

    def insert_factoid(self, key, value):
        with self.sqla_eng.begin() as conn:
            conn.execute\
            (\
                self.sqla_factoids_table.insert(),
                {'key': key, 'value': value}
            )

    def rm_factoid(self, key):
        with self.sqla_eng.begin() as conn:
            conn.execute\
            (
                self.sqla_dbutils_obj.sqla_factoids_table\
                    .delete()\
                    .where\
                    (
                        self.sqla_dbutils_obj.sqla_factoids_table.c.key
                        ==
                        key
                    )
            )
