#!/usr/bin/python3

import pathlib
import re

from sqlalchemy import create_engine, MetaData, Table
from sqlalchemy import Column, Integer, String, ForeignKey
from sqlalchemy import select, func

class KeywordList(object):
    def __init__(self, properties):
        self.string = ""
        self.properties = properties

    def __repr__(self):
        reslist = []

        for key in self.properties:
            reslist.append(key + "=" + self.properties[key])

        return " ".join(reslist)

    def attachProp(self, prop, value):
        self.properties[prop] = value
from utils.configReader import ConfigReader
from utils.dex import  dex

class FactoidConverter(object):
    def __init__(self, scriptPath):
        self.factoid_key_re = re.compile("^\[\[([a-zA-Z-_]+)\]\]$")
        self.results_list = []
        self.insert_list = []

        self.config = ConfigReader(scriptPath)

        if self.config["db"]["dbOK"]:

            self.sqla_eng = create_engine(self.sqlalchemy_conn_str, client_encoding='utf8')
            self.sqla_meta = MetaData(bind=self.sqla_eng)

            self.sqla_factoids_table = Table\
                                       (\
                                        "factoids",
                                        self.sqla_meta,
                                        autoload=True,
                                        autoload_with=self.sqla_eng
                                       )

    def get_factoids(self):
        selector = select([self.sqla_factoids_table])

        conn = self.sqla_eng.connect()

        self.factoids_result = conn.execute(selector)

        return self.factoids_result

    def build_results(self):
        for row in self.get_factoids():
            match_result = self.factoid_key_re.match(row[0])

            if match_result is not None:
                result_dict = dict()
                result_dict["factoid_key"] = match_result.group(0)
                result_dict["macro_key"] = match_result.group(1)
                result_dict["value"] = row[1]

                self.results_list.append(result_dict)

        return self.results_list

    def build_insert_list(self):
        for row in self.results_list:
            insert_dict = {}

            insert_dict["key"] = row["macro_key"]
            insert_dict["value"] = "()" + row["value"]

            self.insert_list.append(insert_dict)

        return self.insert_list

    def insert_macros(self):
        self.build_results()
        self.build_insert_list()

        inserter = self.sqla_factoids_table.insert()

        conn = self.sqla_eng.connect()

        result = conn.execute(inserter, self.insert_list)

        return result

converter_object = FactoidConverter("/home/jim/.config/hexchat/addons/")
