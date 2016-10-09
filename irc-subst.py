#!/usr/bin/python3

__module_name__ = "Jim's IRC substituter"
__module_version__ = "1.0.0"
__module_description__ = "IRC substituter by Jim"

# configuration
commandPrefix = '.'

print( "\0034",__module_name__, __module_version__,"has been loaded\003" )

import re
import psycopg2

import hexchat
import sys
import subprocess
from subprocess import PIPE

from utils import commandtarget

class irc_subst(commandtarget.CommandTarget):
    def __init__(self, cmdPre):
        self.sent = False
        self.cmdLskeys = "lskeys"
        self.cmdPrefix = cmdPre

    # override from commandtarget
    def doCommandStr(self, cmdString, *args, **kwargs):
        result = None

        # (extract from args whatever might be needed
        #   #  for running the command)

        if cmdString == self.cmdLskeys:
            self.list_keys()
        else:
            # pass buck to superclass
            result = super(FooClass, self).doCommandStr(cmdString, *args, **kwargs)

        # return success/fail exit status
        return result

    def opendb(self):
        result = psycopg2.connect("dbname=jim user=jim")

        return result

    def closedb(self, conn):
        conn.close()

    # takes
    #   the string to be sent (which could be altereed inside the func)
    #   the lookup table
    # returns a list,
    #   first item is True if the string is altered, False otherwise
    #   second item is the string

    def outLine(self, inString):
        modified = False

        # split string, using [[ and ]] as delims
        linelist = re.split(r"(\[\[[^\[\]]+\]\])", inString)

        key_re = re.compile("^\[\[[a-zA-Z-_]+\]\]$")
        key_list = list(filter(key_re.match, linelist))

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

        numItems = len(linelist)

        outStr = ""

        for item in range(numItems):
            if linelist[item] in lookup:
                outStr += lookup[linelist[item]]
                modified = True
            else:
                outStr += linelist[item]

        return [modified, outStr]

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


    def inputHook(self, word, word_eol, userdata):
        result = hexchat.EAT_NONE

        if not self.sent:
            self.sent = True

            if len(word) > 0:
                if word[0].startswith(self.cmdPrefix):
                    cmd = word[0][1:]
                    cmdResult = self.doCommandStr(cmd, word[1:], None)
                    result = hexchat.EAT_ALL

            if len(word) == 1:
                if word[0] == "lskeys":
                    self.doCommandStr("lskeys", None, None)
                    result = hexchat.EAT_ALL

            outLineResult = self.outLine("say " + word_eol[0])
            if outLineResult[0]:
                hexchat.command(outLineResult[1])
                result = hexchat.EAT_ALL

            self.sent = False

        return result

irc_subst_obj = irc_subst(commandPrefix)
hexchat.hook_command('', irc_subst_obj.inputHook)
