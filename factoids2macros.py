#!/usr/bin/python3

import pathlib
import re

from sqlalchemy import create_engine, MetaData, Table
from sqlalchemy import Column, Integer, String, ForeignKey
from sqlalchemy import select, func

from configparser import ConfigParser

# index of item in list, or -1 if ValueError
def dex(item, lst):
    result = -1

    try:
        result = lst.index(item)
    finally:
        return result

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

class FactoidConverter(object):
    def __init__(self, scriptPath):
        self.factoid_key_re = re.compile("^\[\[([a-zA-Z-_]+)\]\]$")

        parser = ConfigParser()

        self.confFilePathName = scriptPath + '/' + 'irc-subst.cfg'
        conffiles = None

        conffiles = parser.read(self.confFilePathName)

        if dex(self.confFilePathName, conffiles) == -1:
            print("FATAL: config file '" + self.confFilePathName + "' cannot be found")
            exit(0)

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

        # if there's no db section in the config, db is bad
        if dex("db", parser.sections()) == -1:
            self.dbOK = False
        else:
            self.dbOK = True

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

results_list = []

converter_object = FactoidConverter("/home/jim/.config/hexchat/addons/")
for row in converter_object.get_factoids():
    pass

print(results_list)
print("hi")
