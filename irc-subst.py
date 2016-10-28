#!/usr/bin/python3

# this listens to the outgoing irc lines (ones the client would send to irc) for
# keys that look like [[key]] and substitutes a value looked up in a pg database.
# Right now, this is specific to hexchat.

__module_name__ = "Jim's IRC substituter"
__module_version__ = "1.0.0"
__module_description__ = "IRC substituter by Jim"

# configuration

from configparser import ConfigParser
parser = ConfigParser()
conffiles = parser.read('irc-subst.cfg')

if conffiles[0] != 'irc-subst.cfg':
    print("config file 'irc-subst.cfg' cannot be found")
    sys.exit(0)

def dex(item, lst):
    result = -1

    try:
        result = lst.index(item)
    finally:
        return result

commandPrefix = '.' # get this from general section of config file

dbSpecs = {}

if dex("db", parser.sections()) == -1:
    print("config file has no section 'db'")
    sys.exit(0)

for option in parser.options('db'):
    dbSpecs[option] = parser.get('db', option)

print( "\0034",__module_name__, __module_version__,"has been loaded\003" )

import re
import psycopg2

import hexchat
import sys
import subprocess
from subprocess import PIPE

from utils import commandtarget

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
                                                                                   
class irc_subst(commandtarget.CommandTarget):
    def __init__(self, cmdPre, dbSpecs):
        self.sent = False
        self.cmdLskeys = "lskeys"
        self.cmdPrefix = cmdPre
        self.dbSpecs = dbSpecs

        # initialize superclass
        super(irc_subst, self).__init__()

    # override from commandtarget
    def doCommandStr(self, cmdString, *args, **kwargs):
        result = None

        # (extract from args whatever might be needed
        #   #  for running the command)

        if cmdString == self.cmdLskeys:
            self.list_keys()
            result = 0 # success
        else:
            # pass buck to superclass
            result = super(irc_subst, self).doCommandStr(cmdString, *args, **kwargs)

        # return success/fail exit status
        return result

    # opens connection to db, returns that connection object
    def opendb(self):
        result = psycopg2.connect(str(KeywordList(self.dbSpecs)))

        return result

    # takes database connection object, closes connection
    def closedb(self, conn):
        conn.close()

    # accepts list of keys (strings of the form "[[somekey]]") and
    # returns a dictionary with those keys as keys, and values that
    # come from the db

    def lookupKeyList(self, key_list):
        # now query the db
        conn = self.opendb()
        cur = conn.cursor()
        cur.execute("""select i.key,i.value from irc_subst i where i.key = any (%s)""", (key_list,))
        result_list = cur.fetchall()
        self.closedb(conn)

        # go through results, forming a lookup table
        lookup = dict()

        for row in result_list:
            lookup[row[0]] = row[1]

        return lookup

    # takes
    #   the string to be sent (which could be altereed inside the func)
    # returns a list,
    #   first item is True if the string is altered, False otherwise
    #   second item is the string
    #
    # extracts any strings it finds that match [[something]]
    # looks up those keys
    # substitutes the values for the keys

    def outLine(self, inString):
        modified = False

        # split string, using [[ and ]] as delims
        linelist = re.split(r"(\[\[[^\[\]]+\]\])", inString)

        key_re = re.compile("^\[\[[a-zA-Z-_]+\]\]$")
        key_list = list(filter(key_re.match, linelist))

        lookup = self.lookupKeyList(key_list)

        numItems = len(linelist)

        outStr = ""

        for item in range(numItems):
            if linelist[item] in lookup:
                outStr += lookup[linelist[item]]
                modified = True
            else:
                outStr += linelist[item]

        return [modified, outStr]

    # prints to the irc client the list of keys available in the db
    def list_keys(self):
        conn = self.opendb()
        cur = conn.cursor()
        cur.execute("select i.key from irc_subst i order by i.key;")
        result_list = cur.fetchall()
        self.closedb(conn)

        result_string = ""
        for row in result_list:
            result_string += row[0] + "\n"

        # in Python 3, no strings support the buffer interface, because they don't contain bytes.
        # Before, I was using print. print only writes strings. I shouldn't use print to try and
        # write to a file opened in binary mode (and a pipe is opened in binary mode). I should use
        # the write() method of to_col, which itself is a pipe.

        column = subprocess.Popen(["/usr/bin/column"], stdin=PIPE, stdout=PIPE)

        # note, encoding a str object, you get a bytes object,
        # and, decoding a bytes object, you get a str obhect

        comm_stdout, comm_sterr = column.communicate(result_string.encode())
        # here, split the stdout to lines

        lineList = comm_stdout.splitlines()
        for line in lineList:
            print(line.decode())
            #sys.stdout.write(comm_stdout.decode())

    # this function interfaces with hexchat when it is set as the input hook
    #
    # if the input starts with self.cmdPrefix (a char), it is considered a command
    # and is sent to be processed to doCommmandStr().
    #
    # if not, it's a regular irc line, which is searched for keys which will be
    # substituted by the values from the db

    def inputHook(self, word, word_eol, userdata):
        result = hexchat.EAT_NONE

        if not self.sent:
            self.sent = True

            if len(word) > 0:
                if word[0].startswith(self.cmdPrefix):
                    cmd = word[0][1:]
                    cmdResult = self.doCommandStr(cmd, word[1:], None)

                    if cmdResult == 1:
                        print("command not found")

                    result = hexchat.EAT_ALL

            outLineResult = self.outLine("say " + word_eol[0])
            if outLineResult[0]:
                hexchat.command(outLineResult[1])
                result = hexchat.EAT_ALL

            self.sent = False

        return result

# make an object of the class which contains all of the above funcs as methods
irc_subst_obj = irc_subst(commandPrefix)

# establish the hook to the input method, immediately above
hexchat.hook_command('', irc_subst_obj.inputHook)
