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
        parser = ConfigParser()

        self.confFilePathName = scriptPath + '/' + 'irc-subst.cfg'
        conffiles = None

        conffiles = parser.read(self.confFilePathName)

        if dex(self.confFilePathName, conffiles) == -1:
            print("FATAL: config file '" + self.confFilePathName + "' cannot be found")
            exit(0)

        # pull stuff from general section of config file
        if dex('general', parser.sections()) != -1:
            pass
        else:
            # no general sect
            pass

converter_object = FactoidConverter("/home/jim/.config/hexchat/addons/")

print("hi")
