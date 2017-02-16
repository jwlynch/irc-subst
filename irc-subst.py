#!/usr/bin/python3

# this listens to the outgoing irc lines (ones the client would send to irc) for
# keys that look like [[key]] and substitutes a value looked up in a pg database.
# Right now, this is specific to hexchat.

# whether to print the config file when first loading the script
printConfigP = True

import pathlib
import re
import psycopg2
from sqlalchemy import create_engine
import arrow # for timestamps

import hexchat

import sys, os

import subprocess
from subprocess import PIPE
from configparser import ConfigParser

__module_name__ = "Jim's IRC substituter"
__module_version__ = "1.0.0"
__module_description__ = "IRC substituter by Jim"

# index of item in list, or -1 if ValueError
def dex(item, lst):
    result = -1

    try:
        result = lst.index(item)
    finally:
        return result

# script and config file dir

pathname = pathlib.Path(__file__).parent.__str__()
sys.path.append(pathname) # so that modules that are siblings of the script can be found

from utils import commandtarget

# return a string detailing a list (its items togeter with each index)
def detailList(l):
    reslst = []

    for i in range(len(l)):
        reslst.append("[%s]: %s" % (str(i), str(l[i])))

    return " ".join(reslst)

# splits hostmask (string of form nick!email@site) into its parts
# returns a dict with keys nick, emailname, site
def split_hostmask(hostmask):
    (nick, email) = hostmask.split(sep="!")
    (emailname,site) = email.split(sep="@")

    result = {}
    result["nick"] = nick
    result["emailname"] = emailname
    result["site"] = site

    return result

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
    # reload config file
    #
    # vars that get set as a result of this call:
    # - self.cmdPrefix (the char to signal 'this is a command to the script')
    # - self.dbSpecs (the dict with the database settings, to be give to psycopg2.open()
    # - self.dbOK (boolean telling whether database is reachable and openable)
    # - self.printConfigP (which is true if reload calls should print the config file)
    def reload(self, scriptPath):
        parser = ConfigParser()
        conffiles = parser.read(scriptPath + '/' + 'irc-subst.cfg')

        if dex(scriptPath + '/' + 'irc-subst.cfg', conffiles) == -1:
            print("config file '" + scriptPath + "/irc-subst.cfg' cannot be found")

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

        if dex("db", parser.sections()) == -1:
            self.dbOK = False
        else:
            self.dbOK = True

        self.dbSpecs = None
        self.sqlalchemy_conn_str = None

        if self.dbOK:
            self.dbSpecs = {}
            for option in parser.options('db'):
                self.dbSpecs[option] = parser.get('db', option)

            # build the sqlalchemy connect string
            k = self.dbSpecs.keys()

            s = "postgresql://"
            if 'user' in k:
                s += self.dbSpecs['user']
                if 'passwd' in k:
                    s += ':' + self.dbSpecs['passwd']

                if 'host' in k:
                    s += '@' + self.dbSpecs['host']
                else:
                    s += '@localhost'

                if 'port' in k:
                    s += ':' + self.dbSpecs['port']

            s += '/' + 'sqlaTest' # self.dbSpecs['dbname']
            self.sqlalchemy_conn_str = s

        # print the config file (if desired)
        if self.printConfigP:
            print("config file: ")

            for sect in parser.sections():
                print("section %s:" % sect)
                for opt in parser.options(sect):
                    val = parser.get(sect, opt)
                    print("  %s = %s" % (opt, val))

            if self.dbOK:
                print("sqlalchemy_conn_str is " + self.sqlalchemy_conn_str)

    def __init__(self, scriptPath):
        self.scriptPath = scriptPath
        self.reload(self.scriptPath)
        self.sent = False

        # now storing db connection info in the object, init to None
        self.db_psyco_conn = None

        # sqlalchemy
        self.sqla_eng = None
        self.sqla_meta = None
        self.sqla_conn = None

        if self.dbOK:
            self.sqla_eng = create_engine(self.sqlalchemy_conn_str, client_encoding='utf8')
            self.sqla_meta = Metadata(bind=self.sqla_eng, reflect=True)

        # a list of words, which if present specify a section to print debugging about.
        # at first, this will be each hook
        self.debugSects = []
        # the list of all such sections
        self.allDebugSects = []

        self.allDebugSects = ["privmsgbasic", "privmsgsql", "notice", "noticetests", "join", "part", "partreas"]

        # the debug tab name, which will show up in the client
        self.debugtab_nick = "DebugTab"

        self.makeDebugTab()

        self.cmdReload = "reload"
        self.cmdLskeys = "lskeys"
        self.cmdRemove = "remove"
        self.cmdAddFact = "addfact"
        self.cmdRmFact = "rmfact"
        self.cmdInfo = "info"
        self.cmdDebugSects = "debugsects"
        self.cmdLSDebugSects = "lsdebugsects"

        self.cmdDebugHi = "debughi"

        self.key_re = re.compile("^\[\[[a-zA-Z-_]+\]\]$")
        self.channel_re = re.compile("^[#&~].*$")

        # initialize superclass
        super(irc_subst, self).__init__()

    def makeDebugTab(self):
        # add the tab for debugging
        hexchat.command("query " + self.debugtab_nick)

        # put the channel list entry for it in the object so I can get at it
        self.debug_tab = [c for c in hexchat.get_list('channels') if c.channel == self.debugtab_nick][0]

    def debugPrint(self, *args, **kwargs):
        self.debug_tab.context.prnt(*args, **kwargs)

    # override from commandtarget
    def doCommandStr(self, cmdString, *args, **kwargs):
        result = None

        argList = args[0]

        # (extract from args whatever might be needed
        #   #  for running the command)

        if cmdString == self.cmdReload:
            print("reloading config file...")
            self.reload(self.scriptPath)
        elif cmdString == self.cmdLskeys:
            if self.dbOK:
                self.list_keys()
                result = 0 # success
            else:
                print("no db")

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

            if self.dbOK:
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
                    self.opendb()
                    conn = self.db_psyco_conn

                    try:
                        self.cur = conn.cursor()
                        self.cur.execute("insert into factoids(key, value) values (%s, %s)", (key, value))
                    except psycopg2.Error as pe:
                        conn.rollback()
                        print("factoid add: db insert error: " + str(pe))
                    finally:
                        self.cur.close()
                        conn.commit()

                    self.cur = None
                    self.closedb()

                result = 0

            else:
                print("no db")

        elif cmdString == self.cmdRmFact:
            result = 0 # success/command is found

            if self.dbOK:
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
                    self.opendb()
                    conn = self.db_psyco_conn

                    try:
                        self.cur = conn.cursor()
                        self.cur.execute("delete from factoids where key = %s", (key,))
                    except psycopg2.Error as pe:
                        conn.rollback()
                        print("factoid remove: db insert error: " + str(pe))
                    finally:
                        self.cur.close()
                        conn.commit()

                    self.cur = None
                    self.closedb()
            else:
                print("no db")

        elif cmdString == self.cmdInfo:
            top_context = hexchat.find_context()
            channel_list = hexchat.get_list('channels')
            front_tab = [c for c in hexchat.get_list('channels') if c.context == top_context][0]
            type = front_tab.type

            if type == 1:
                # server tab
                print("server tab, server is", front_tab.server)
            elif type == 2:
                # channel tab
                print("channel tab, channel is %s, modes are %s" % (front_tab.channel, front_tab.chanmodes))
                users = top_context.get_list("users")
            elif type == 3:
                # dialog/query tab
                print("query tab, nick is", front_tab.channel)
            elif type == 4:
                # notices tab
                print("notices tab")
            elif type == 5:
                # SNotices tab
                print("SNotices tab")
        elif cmdString == self.cmdDebugHi:
            self.debugPrint("hi")
        elif cmdString == self.cmdLSDebugSects:
            self.debugPrint("possible debug sections: " + repr(self.allDebugSects))
        elif cmdString == self.cmdDebugSects:
            if len(argList) == 0:
                self.debugPrint("debug sections: " + repr(self.debugSects))
            elif len(argList) == 2:
                if argList[0] == "add":
                    if dex(argList[1], self.debugSects) == -1:
                        self.debugSects.append(argList[1])
                        print("debugsects add: %s" % (argList[1]))
                    else:
                        print("debugsects add: %s already present" % (argList[1]))
                elif argList[0] == "rm":
                    if dex(argList[1], self.debugSects) != -1:
                        self.debugSects.remove(argList[1])
                        print("debugsects rm: %s" % (argList[1]))
                    else:
                        print("debugsects rm: %s not present" % (argList[1]))
                else:
                    print("debugsects: unrecognized subcommand '%s'" % (argList[0]))
            else:
                print("debug sections: wrong number of args")

        else:
            # pass buck to superclass
            result = super(irc_subst, self).doCommandStr(cmdString, *args, **kwargs)

        # return success/fail exit status
        return result

    # opens connection to db, returns that connection object
    def opendb(self):
        result = psycopg2.connect(str(KeywordList(self.dbSpecs)))

        self.db_psyco_conn = result

    # takes database connection object, closes connection
    def closedb(self):
        self.db_psyco_conn.close()

        self.db_psyco_conn = None

    # accepts list of keys (strings of the form "[[somekey]]") and
    # returns a dictionary with those keys as keys, and values that
    # come from the db

    def lookupKeyList(self, key_list):
        # now query the db
        if self.dbOK:
            self.opendb()
            conn = self.db_psyco_conn
            cur = conn.cursor()
            cur.execute("""select f.key,f.value from factoids f where f.key = any (%s)""", (key_list,))
            result_list = cur.fetchall()
            self.closedb()

        # go through results, forming a lookup table
        lookup = dict()

        if self.dbOK:
            for row in result_list:
                lookup[row[0]] = row[1]
        else:
            # populate lookup table with (no db) for each key
            for key in key_list:
                lookup[key] = "(no db)"

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
        self.opendb()
        conn = self.db_psyco_conn
        cur = conn.cursor()
        cur.execute("select i.key from factoids i order by i.key;")
        result_list = cur.fetchall()
        self.closedb()

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

    # privmsg hook

    def privmsg_hook(self, word, word_eol, userdata):

        # TODO
        #      -
        #      - store hostmask and nick somewhere (db?)
        #      - get user's account name (where is this stored already?
        #                                 would like to get it from that
        #                                 rather than bother the server about it

        src_hostmask = word[0][1:]
        dest = word[2]
        message = word[3][1:] + " " + " ".join(word[4:])

        hostmaskdict = split_hostmask(src_hostmask)

        src_nick = hostmaskdict["nick"]
        src_emailname = hostmaskdict["emailname"]
        src_host = hostmaskdict["site"]

        # if the word "privmsgbasic" is in the list debugSects, print debug message
        if dex("privmsgbasic", self.debugSects) != -1:
            debugBasicP = True
        else:
            debugBasicP = False

        # if the word "privmsgsql" is in the list debugSects, print debug message
        if dex("privmsgsql", self.debugSects) != -1:
            debugSQLP = True
        else:
            debugSQLP = False

        if debugBasicP:
            self.debugPrint("source nick:      " + src_nick)
            self.debugPrint("source emailname: " + src_emailname)
            self.debugPrint("source host:      " + src_host)

        # differentiate between private messages and messages to channels
        if re.match(self.channel_re, dest):
            channel = dest

            if debugBasicP:
                self.debugPrint("destination channel: " + channel)

        else:
            nick = dest

            if debugBasicP:
                self.debugPrint("destination nick: " + nick)

        if debugBasicP:
            self.debugPrint("message: " + message)

        return hexchat.EAT_NONE

    def insertFailedLogin(self, failed_login_id_or_null, ip_or_hostname_or_null, timestamp_or_null):
        if timestamp_or_null is None:
            # get a now() into timestamp_or_null with correct time zone
            timestamp_or_null = arrow.now().datetime

        self.opendb()
        conn = self.db_psyco_conn

        cur = conn.cursor()
        if failed_login_id_or_null is None:
            cur.execute("select nextval('object_id_seq');")
            failed_login_id_or_null = cur.fetchone()[0]

        cur.execute("begin transaction;")
        cur.execute("select failed_login_new(%s, %s, %s);", [failed_login_id_or_null, ip_or_hostname_or_null, timestamp_or_null])
        cur.execute("end transaction;")

        cur.close()

        self.closedb()

    def notice_hook(self, word, word_eol, userdata):
        result = hexchat.EAT_NONE

        if dex("notice", self.debugSects) != -1:
            debugNoticeP = True
        else:
            debugNoticeP = False

        if dex("noticetests", self.debugSects) != -1:
            debugNoticeTestsP = True
        else:
            debugNoticeTestsP = False

        # less typing
        w = word

        src_hostmask = w[0][1:]

        # is it from saslserv?
        if src_hostmask == "SaslServ!SaslServ@services.":
            if debugNoticeTestsP:
                self.debugPrint("notice was from saslserv")

            justToMeP = (w[2] == "jim")
            failedLoginP = (w[7] == "failed" and w[9] == "login")
            unknownUserP = (w[3][4:] == "Unknown" and w[4] == "user")
            viaSASLP = (w[5] == "(via" and w[6].startswith("SASL):"))

            if justToMeP and failedLoginP and unknownUserP and viaSASLP:
                if debugNoticeTestsP:
                    self.debugPrint("justToMeP and failedLoginP and unknownUserP and viaSASLP")

                ipAddr = w[6][6:-2]
                if debugNoticeTestsP:
                    self.debugPrint("w[6][6:-2] aka the IP: %s" % (w[6][6:-2]))

                if self.dbOK:
                    strDbOk = ""
                else:
                    strDbOk = " (no db)"

                print("failed sasl login from %s%s" % (ipAddr, strDbOk))

                if self.dbOK:
                    self.insertFailedLogin(None, ipAddr, None)

                result = hexchat.EAT_ALL
            else:
                if debugNoticeTestsP:
                    self.debugPrint("!justToMeP or !failedLoginP or !unknownUserP or !viaSASLP")
                    self.debugPrint("justToMeP: %s, failedLoginP: %s, unknownUserP: %s, viaSASLP: %s" % (str(justToMeP), str(failedLoginP), str(unknownUserP), str(viaSASLP)))

        else:
            # from someone else
            if debugNoticeTestsP:
                self.debugPrint("notice was not from saslserv")

        if debugNoticeP:
            self.debugPrint("notice: %s" % (detailList(word)))

        return result

    def join_hook(self, word, word_eol, userdata):
        if dex("join", self.debugSects) != -1:
            debugJoinP = True
        else:
            debugJoinP = False

        if debugJoinP:
            self.debugPrint("debugJoinP: " + word_eol[0])

        return hexchat.EAT_NONE

    def part_hook(self, word, word_eol, userdata):
        if dex("part", self.debugSects) != -1:
            debugPartP = True
        else:
            debugPartP = False

        if debugPartP:
            self.debugPrint("debugPartP: " + word_eol[0])

        return hexchat.EAT_NONE

    def partreas_hook(self, word, word_eol, userdata):
        if dex("partreas", self.debugSects) != -1:
            debugPartReasP = True
        else:
            debugPartReasP = False

        if debugPartReasP:
            self.debugPrint("debugPartReasP: " + word_eol[0])

        return hexchat.EAT_NONE


# make an object of the class which contains all of the above funcs as methods
irc_subst_obj = irc_subst(pathname)

# establish the hook to the input method, immediately above
hexchat.hook_command('', irc_subst_obj.inputHook)

# establish the hook to the privmsg method of irc_subst, above
hexchat.hook_server('PRIVMSG', irc_subst_obj.privmsg_hook)

# establish the hook to the notice method of irc_subst, above
hexchat.hook_server('NOTICE', irc_subst_obj.notice_hook)

# establish the hook to the join_hook method of irc_subst, above
hexchat.hook_print('Join', irc_subst_obj.join_hook)

# establish the hooks to the part_hook and partreas_hook methods of irc_subst, above
hexchat.hook_print('Part', irc_subst_obj.part_hook)
hexchat.hook_print('Part with Reason', irc_subst_obj.partreas_hook)
