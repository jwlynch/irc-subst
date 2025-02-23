#!/usr/bin/env python

import pathlib
import re

# you can do the goal of this script using this:
#
# update factoids set value = '()' || value where value not like '()%';

from sqlalchemy import create_engine, MetaData, Table
from sqlalchemy import Column, Integer, String, ForeignKey
from sqlalchemy import select, func

from utils.configReader import ConfigReader
from utils.dex import  dex
from utils.keywordList import KeywordList
from utils.sqla_dbutils import SqlA_DbUtils

class FactoidConverter(object):
    def __init__(self, scriptPath=None):
        self.factoid_key_re = re.compile("^\[\[([a-zA-Z-_]+)\]\]$")
        self.results_list = []
        self.insert_list = []
        self.update_list = []

        self.config = ConfigReader(scriptPath).config

        if self.config["db"]["dbOK"]:
            self.sqla_dbutils = SqlA_DbUtils(self.config["db"])

    def get_factoids(self):
        selector = select([self.sqla_dbutils.sqla_factoids_table])

        conn = self.sqla_dbutils.sqla_eng.connect()

        self.factoids_result = conn.execute(selector)

        return self.factoids_result

    # needs self.get_factoids()
    def build_results(self):
        for row in self.factoids_result:
            match_result = self.factoid_key_re.match(row[0])

            if match_result is not None:
                result_dict = dict()
                result_dict["factoid_key"] = match_result.group(0)
                result_dict["macro_key"] = match_result.group(1)
                result_dict["value"] = row[1]

                self.results_list.append(result_dict)

        return self.results_list

    # needs self.build_results()
    def build_update_list(self):
        self.changed_list = []

        for row in self.results_list:
            if not row["value"].startswith("()"):
                changed_dict = {}

                # shorthand for macro key
                k = row["macro_key"]

                # shorthand for the value for that key
                v = "()" + row["value"]

                changed_dict["key"] = k
                changed_dict["value"] = v

                self.changed_list.append(changed_dict)

                # shorthand for factoids table
                t = self.sqla_dbutils.sqla_factoids_table

                # shorthand for update object
                u = t.update().where(t.c.key == k).values(value = v)

                # add update object to update list
                self.update_list.append(u)

        return self.update_list

    # needs self.build_results() and self.build_update_list()
    def update_macros(self):
        conn = self.sqla_dbutils.sqla_eng.connect()

        # for each changed row:
        for updater in self.update_list:
            # do each row update in its own transaction
            with conn.begin():
                conn.execute(updater)

    def main(self, scriptPath=None):
        self.get_factoids()
        self.build_results()
        self.build_update_list()
        self.update_macros()

#converter_object = FactoidConverter("/home/jim/.config/hexchat/addons/")
converter_object = FactoidConverter()
c = converter_object
#converter_object.main()
