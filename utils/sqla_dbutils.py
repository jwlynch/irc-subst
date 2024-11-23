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
