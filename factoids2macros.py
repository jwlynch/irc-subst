#!/usr/bin/env python

import pathlib
import re

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

        self.config = ConfigReader(scriptPath).config

        if self.config["db"]["dbOK"]:
            self.sqla_dbutils = SqlA_DbUtils(self.config["db"])

    def get_factoids(self):
        selector = select([self.sqla_dbutils.sqla_factoids_table])

        conn = self.sqla_dbutils.sqla_eng.connect()

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

        inserter = self.sqla_dbutils.sqla_factoids_table.insert()

        conn = self.sqla_dbutils.sqla_eng.connect()

        result = conn.execute(inserter, self.insert_list)

        return result

#converter_object = FactoidConverter("/home/jim/.config/hexchat/addons/")
converter_object = FactoidConverter()
