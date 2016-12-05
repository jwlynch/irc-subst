#!/usr/bin/python3

# this listens to the outgoing irc lines (ones the client would send to irc) for
# keys that look like [[key]] and substitutes a value looked up in a pg database.
# Right now, this is specific to hexchat.

import re
import psycopg2

import hexchat

import sys, os

import subprocess
from subprocess import PIPE

__module_name__ = "Jim's IRC substituter"
__module_version__ = "1.0.0"
__module_description__ = "IRC substituter by Jim"

# script and config file dir

pathname = os.path.abspath(os.path.dirname(sys.argv[0]))
sys.path.append(pathname)

print("this script should be in " + pathname)

from utils import commandtarget

# configuration

from configparser import ConfigParser
parser = ConfigParser()
conffiles = parser.read('irc-subst.cfg')

if conffiles[0] != 'irc-subst.cfg':
    print("config file 'irc-subst.cfg' cannot be found")
    sys.exit(0)

# index of item in list, or -1 if ValueError
def dex(item, lst):
    result = -1

    try:
        result = lst.index(item)
    finally:
        return result

commandPrefix = '.' # default in case there's not a general/commandPrefix in the config file

if dex('general', parser.sections()) != -1:
    print("there is a general section")
    print("...and the options in that section are %s" % (parser.options('general')))
    if dex('command-prefix', parser.options('general')) != -1:
        print("...and a command-prefix option")
        commandPrefix = parser.get('general', 'command-prefix')
        print("value of commaPrefix from the config file is |%s|" % (commandPrefix))
    else:
        print("there's no command-prefix in the general section")
else:
    print("there's no general section")

dbSpecs = {}

if dex("db", parser.sections()) == -1:
    print("config file has no section 'db'")
    sys.exit(0)

for option in parser.options('db'):
    dbSpecs[option] = parser.get('db', option)

print( "\0034",__module_name__, __module_version__,"has been loaded\003" )

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
        self.cmdRemove = "remove"
        self.cmdAddFact = "addfact"
        self.cmdRmFact = "rmfact"

        self.cmdPrefix = cmdPre
        self.dbSpecs = dbSpecs

        self.key_re = re.compile("^\[\[[a-zA-Z-_]+\]\]$")

        # initialize superclass
        super(irc_subst, self).__init__()

    # override from commandtarget
    def doCommandStr(self, cmdString, *args, **kwargs):
        result = None

        argList = args[0]

        # (extract from args whatever might be needed
        #   #  for running the command)

        if cmdString == self.cmdLskeys:
            self.list_keys()
            result = 0 # success
        elif cmdString == self.cmdRemove:
            channel = None
            nick = None
            reason = None

            if len(argList) >= 3:
                reason = " ".join(argList[2:])

            if len(argList) >= 2:
                nick = argList[1]

            if len(argList) >= 1:
                channel = argList[0]

            if len(argList) == 1:
                # command is 'remove nick', get channel
                nick = argList[0]
                channel = hexchat.get_info("channel")

            removeCommand = "remove " + channel + " " + nick
            if reason is not None:
                removeCommand += " :" + reason

            hexchat.command(removeCommand)

            result = 0 # success

        elif cmdString == self.cmdAddFact:
            result = 0 # success/command is found
            bad = True
            key = ""
            value = ""

            if len(argList) < 2:
                print("factoid add: too few args")
            elif len(argList) > 2:
                print("factoid add: too many args")
            else:
                # correct number of args
                bad = False
                key = argList[0]
                value = argList[1]

            if not bad:
                if not self.key_re.match(key):
                    print("factoid add: the key -- %s -- doesn't look like '[[a-zA-A-_]]'" % (key))
                    bad = True

            if not bad:
                lookupTable = self.lookupKeyList([key])
                if lookupTable:
                    # key is already in db
                    print("key %s is already in db" % (key))
                    bad = True

            if not bad:
                # do query and insert here
                print("factoid add: key %s, value %s" % (key, value))
                conn = self.opendb()

                try:
                    self.cur = conn.cursor()
                    self.cur.execute("insert into irc_subst(key, value) values (%s, %s)", (key, value))
                except psycopg2.Error as pe:
                    conn.rollback()
                    print("factoid add: db insert error: " + str(pe))
                finally:
                    self.cur.close()
                    conn.commit()

                self.cur = None
                self.closedb(conn)

            result = 0
        elif cmdString == self.cmdRmFact:
            result = 0 # success/command is found
            bad = True
            key = ""
            value = ""

            if len(argList) < 1:
                print("factoid remove: too few args")
            elif len(argList) > 1:
                print("factoid remove: too many args")
            else:
                # correct number of args
                bad = False
                key = argList[0]

            if not bad:
                if not self.key_re.match(key):
                    print("factoid remove: the key -- %s -- doesn't look like '[[a-zA-A-_]]'" % (key))
                    bad = True

            if not bad:
                lookupTable = self.lookupKeyList([key])
                if not lookupTable:
                    # key is not in db
                    print("factoid remove: key %s is not in db" % (key))
                    bad = True

            if not bad:
                # do delete query here
                print("factoid remove: key %s" % (key))
                conn = self.opendb()

                try:
                    self.cur = conn.cursor()
                    self.cur.execute("delete from irc_subst where key = %s", (key,))
                except psycopg2.Error as pe:
                    conn.rollback()
                    print("factoid remove: db insert error: " + str(pe))
                finally:
                    self.cur.close()
                    conn.commit()

                self.cur = None
                self.closedb(conn)
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

        key_list = list(filter(self.key_re.match, linelist))

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

    # accepts an irc line as a list of words, which is the arguments to a command
    # consolidates the quoted arguments into a single list item
    # returns the list of quoted and not-quoted args

    def quotizeWordList(self, lst):
        li = iter(lst)
        result = []

        for w in li:
            result.append(w)

        return result

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
                if word[0].startswith("\\"):
                    hexchat.command("say " + word_eol[0][1:])
                    result = hexchat.EAT_ALL
                elif word[0].startswith(self.cmdPrefix):
                    result = hexchat.EAT_ALL
                    cmd = word[0][1:]
                    cmdResult = self.doCommandStr(cmd, word[1:], None)

                    if cmdResult == 1:
                        print("command '%s' not found" % (cmd))
                else:
                    outLineResult = self.outLine("say " + word_eol[0])
                    if outLineResult[0]:
                        hexchat.command(outLineResult[1])
                        result = hexchat.EAT_ALL

            self.sent = False

        return result

# make an object of the class which contains all of the above funcs as methods
irc_subst_obj = irc_subst(commandPrefix, dbSpecs)

# establish the hook to the input method, immediately above
hexchat.hook_command('', irc_subst_obj.inputHook)
