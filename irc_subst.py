#!/usr/bin/python3

# this listens to the outgoing irc lines (ones the client would send to irc) for
# keys that look like [[key]] and substitutes a value looked up in a pg database.
# Right now, this is specific to hexchat.

__module_name__ = "irc_subst"

# whether to print the config file when first loading the script
printConfigP = True

import pathlib
import re, shlex
from sqlalchemy import create_engine, MetaData, Table
from sqlalchemy import Column, Integer, String, ForeignKey
from sqlalchemy import select, func
# import arrow # for timestamps
# from dateutil import tz

import hexchat

import sys, os

import subprocess
from subprocess import PIPE
# from configparser import ConfigParser

__module_name__ = "Jim's IRC substituter"
__module_version__ = "1.0.0"
__module_description__ = "IRC substituter by Jim"

# script and config file dir

# nedbat's hack to replace __file__
def foo():
    pass
pathname = pathlib.Path(foo.__code__.co_filename).parent.__str__()

sys.path.append(pathname) # so that modules that are siblings of the script can be found

from utils.commandtarget import CommandTarget
from objects import nextObjectID
from debugsects import DebugSectsObj
from utils.dex import dex
from utils.keywordList import KeywordList
from utils.configReader import ConfigReader
from utils.debugTabObj import DebugTabObj
from utils.sqla_dbutils import SqlA_DbUtils

# return a string detailing a list (its items togeter with each index)
def detailList(l):
    # hexchat.prnt("testing detailList:")
    # test0 = []
    # test1 = ["one"]
    # test2 = ["one", "two"]
    # hexchat.prnt(f"empty: {test0}")
    # hexchat.prnt(f"1 item: {test1}")
    # hexchat.prnt(f"2 items: {test2}")

    reslst = []

    for i, item in enumerate(l):
        reslst.append(f"[{i}]: {item}")

    if len(reslst) != 0:
        resStr = " ".join(reslst)
    else: # reslst is empty
        resStr = "[]"

    return resStr

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


class irc_subst(CommandTarget):
    # reload config file
    #
    # vars that get set as a result of this call:
    # - self.cmdPrefix (the char to signal 'this is a command to the script')
    # - self.dbSpecs (the dict with the database settings, to be give to psycopg2.open()
    # - self.config["db"]["dbOK"] (boolean telling whether database is reachable and openable)
    # - self.printConfigP (which is true if reload calls should print the config file)
    def doReload(self, scriptPath):
        # a list of words, which if present specify a section to print debugging about.
        # at first, this will be each hook
        self.debugSectsObj = DebugSectsObj()
        self.readResult = ConfigReader(scriptPath)

        if not self.readResult.successP:
            print("FATAL: problem reading file '" + scriptPath + "'")
            exit(0)

        self.config = self.readResult.config

        self.sqla_dbutils_obj = SqlA_DbUtils(self.config['db'])

        # print the config file (if desired)
        if self.config['general']['print-config']:
            self.debugPrint("config file: ")

            for sect in self.config:
                self.debugPrint(f"section {sect}:")

                for opt in self.config[sect]:
                    val = self.config[sect][opt]
                    self.debugPrint(f"  {opt} = {val}")

            if self.config["db"]["dbOK"]:
                self.debugPrint(f"sqlalchemy_conn_str is {self.config['db']['sqlalchemy_conn_str']}")

    def __init__(self, scriptPath):
        # # the debug tab name, which will show up in the client
        # self.debugtab_nick = "DebugTab" # TODO: put this in config file
        self.debug_tab = DebugTabObj()

        self.scriptPath = scriptPath

        self.doReload(self.scriptPath)
        #self.sent = False

        self.allDebugSects = []

        self.allDebugSects = ["privmsgbasic", "privmsgsql", "notice", "noticetests", "join", "part", "partreas"]

        self.command_dict = {}

        self.command_dict["lskeys"] = self.list_keys
        self.command_dict["remove"] = self.doRemove
        self.command_dict["addmacro"] = self.doAddMacro
        self.command_dict["rmmacro"] = self.doRMMacro
        self.command_dict["showmacro"] = self.doShowMacro
        self.command_dict["info"] = self.doInfo
        self.command_dict["debughi"] = self.doDebugHi
        self.command_dict["ancdirs"] = self.doAncestorDirs
        self.command_dict["debugsects"] = self.doDebugSects
        self.command_dict["lsdebugsects"] = self.doLSDebugSects
        self.command_dict["lscmds"] = self.doLsCmds
        #self.command_dict["cvttime"] = self.doCvtTime

        self.cmdReload = "reload"

        self.factoid_key_re = re.compile("^\[\[[a-zA-Z-_]+\]\]$")
        self.macroname_key_re = re.compile("^[a-zA-Z0-9-_]+$")
        self.macro_re = re.compile("^\(([a-zA-Z0-9-_ ]*)\)(.*)$")
        self.channel_re = re.compile("^[#&~].*$")

        # initialize superclass
        super(irc_subst, self).__init__()

    def debugSectsContains(self, sectName):
        return self.debugSectsObj.debugSectsContains(sectName)

    def debugPrint(self, printThis):
        self.debug_tab.debugPrint(printThis)

        # reprPrintThis = repr(printThis)

        #self.debug_tab.context.prnt(printThis) # old debugPrintS

        # try debugPrinting on curr. context, to see if I like it
        # hexchat.prnt(printThis) # trying this way

    def doRemove(self, cmdString, argList, kwargs):
        result = 0 # no error

        if dex("rm", self.debugSects) != -1:
            debugRm = True
        else:
            debugRm = False

        channel = None
        nick = None
        reason = None

        if len(argList) == 0:
            self.debugPrint("remove usage:")
            self.debugPrint("remove <nick>")
            self.debugPrint("remove <nick> \"reason\" # must quote reason in 2-arg form")
            self.debugPrint("remove <channel> <nick> <reason> # need not quote reason in 3-arg form")
        else: # not zero args
            if len(argList) >= 3:
                reason = " ".join(argList[2:])
                nick = argList[1]
                channel = argList[0]
            else:
                if len(argList) == 2:
                    reason = argList[1]
                    nick = argList[0]
                    channel = hexchat.get_info("channel")

                if len(argList) == 1:
                    nick = argList[0]
                    reason = nick
                    channel = hexchat.get_info("channel")

            removeCommand = f"remove {channel} {nick}"
            if reason is not None:
                removeCommand += " :{reason}"

            if debugRm:
                self.debugPrint("debugRm: {removeCommand}")
            else:
                hexchat.command(removeCommand)

        return result

    # make list of dirs, going back to its ancestor
    def doAncestorDirs(self, cmdString, argList, kwargs):
        if len(argList) != 1:
            self.debugPrint("takes one arg, the pathname")
        else:
            pathName = argList[0]
            pathList = list(pathlib.Path(pathName).parents)
            pathList = list(reversed(pathList))
            pathList.append(pathlib.Path(pathName))

            outStr = ""
            for path in pathList:
                outStr += str(path) + " "

            self.debugPrint(outStr)

    def doShowMacro(self, cmdString, argList, kwargs):
        result = 0

        if len(argList) == 0:
            # print usage
            self.debugPrint("showmacro usage:")
            self.debugPrint("showmacro <key>")

        elif len(argList) != 1:
            # wrong nbr args
            self.debugPrint("showmacro: wrong number of arguments")
        else:
            # correct number of args

            if self.config["db"]["dbOK"]:
                bad = False
                key = argList[0]

                if not self.macroname_key_re.match(key):
                    self.debugPrint("macro show: the key -- %s -- doesn't look like 'a-zA-A0-9-_'" % (key))
                    bad = True

                if not bad:
                    lookupTable = self.lookupKeyList([key])

                    if lookupTable:
                        bad = False
                    else:
                        bad = True
                        self.debugPrint("showmacro: no such macro '%s'" % key)

                    if not bad:
                        self.debugPrint("showmacro: key %s has value \"%s\"" % (key, lookupTable[key]))
            else:
                self.debugPrint("showmacro: no db")

        return result

    def doAddMacro(self, cmdString, argList, kwargs):
        result = 0 # success/command is found

        if self.config["db"]["dbOK"]:
            bad = True
            key = ""
            value = ""

            if len(argList) == 0:
                self.debugPrint("addmacro usage:")
                self.debugPrint("addmacro <key> <value>")
            elif len(argList) < 2:
                self.debugPrint("macro add: too few args")
            elif len(argList) > 2:
                self.debugPrint("macro add: too many args")
            else:
                # correct number of args
                bad = False
                key = argList[0]
                value = argList[1]

            if not bad:
                if not self.macroname_key_re.match(key):
                    self.debugPrint("macro add: the key -- %s -- doesn't look like 'a-zA-A0-9-_'" % (key))
                    bad = True

            if not bad:
                lookupTable = self.lookupKeyList([key])
                if lookupTable:
                    # key is already in db
                    self.debugPrint("key %s is already in db" % (key))
                    bad = True

            if not bad:
                # do query and insert here
                with self.sqla_eng.begin() as conn:
                    conn.execute\
                        (\
                            self.sqla_factoids_table.insert(),
                            {'key': key, 'value': value}
                        )

                self.debugPrint("macro add: key \"%s\", value \"%s\"" % (key, value))
        else:
            self.debugPrint("no db")

        return result

    def doRMMacro(self, cmdString, argList, kwargs):
        result = 0 # success/command is found

        if self.config["db"]["dbOK"]:
            bad = True
            key = ""
            value = ""

            if len(argList) == 0:
                self.debugPrint("rmmacro usage:")
                self.debugPrint("rmmacro <key>")
            elif len(argList) < 1:
                self.debugPrint("macro remove: too few args")
            elif len(argList) > 1:
                self.debugPrint("macro remove: too many args")
            else:
                # correct number of args
                bad = False
                key = argList[0]

            if not bad:
                if not self.macroname_key_re.match(key):
                    self.debugPrint("macro remove: the key -- %s -- doesn't look like 'a-zA-A0-9-_'" % (key))
                    bad = True

            if not bad:
                lookupTable = self.lookupKeyList([key])
                if not lookupTable:
                    # key is not in db
                    self.debugPrint("macro remove: key %s is not in db" % (key))
                    bad = True

            if not bad:
                # do delete query here
                self.debugPrint("macro remove: key %s" % (key))

                with self.sqla_eng.begin() as conn:
                    conn.execute\
                        (
                            self.sqla_factoids_table\
                                .delete()\
                                .where\
                                (
                                    self.sqla_factoids_table.c.key
                                    ==
                                    key
                                )
                        )
        else:
            self.debugPrint("no db")

        return result

    # def doCvtTime(self, cmdString, argList, kwargs):
    #     result = 0
    #
    #     if len(argList) < 1 or len(argList) > 1:
    #         result = -1
    #
    #         print("cvttime usage:")
    #         print("cvttime <timeString>")
    #         print("displays time in the local timezone")
    #
    #         if len(argList) < 1:
    #             print("cvttime: too few args")
    #         elif len(argList) > 1:
    #             print("cvttime: too many args")
    #     else:
    #         # correct number of args
    #         timeString = argList[0]
    #         timeObj = arrow.get(timeString)
    #
    #         print(timeObj.to('local').format('YYYY-MM-DD HH:mm:ss ZZ'))
    #
    #     return result

    def doInfo(self, cmdString, argList, kwargs):
        result = 0

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

        return result

    def addDebugSect(self, addedSect):
        addRes = self.debugSectsObj.addDebugSect(addedSect)

        self.debugPrint(addRes[1])

        return addRes[0]

    def rmDebugSect(self, removedSect):
        rmRes = self.debugSectsObj.rmDebugSect(removedSect)

        self.debugPrint(rmRes[1])

        return rmRes[0]

    def doDebugSects(self, cmdString, argList, kwargs):
        result = 0

        if len(argList) == 0:
            # no args, so -list- current debug sections
            self.debugPrint(f"debug sections: {self.debugSectsObj.debugSectsList}")
        elif len(argList) == 2:
            if argList[0] == "add":
                self.addDebugSect(argList[1])
            elif argList[0] == "rm":
                self.rmDebugSect(argList[1])
            else:
                self.debugPrint("debugsects: unrecognized subcommand '%s'" % (argList[0]))
        else:
            self.debugPrint("debug sections: wrong number of args")

        return result

    def doDebugHi(self, cmdString, argList, kwargs):
        self.debugPrint("hi")

    def doLSDebugSects(self, cmdString, argList, kwargs):
        self.debugPrint("possible debug sections: " + repr(self.allDebugSects))

        return 0

    def doLsCmds(self, cmdString, argList, kwargs):
        cmdList = sorted(self.command_dict)

        self.debugPrint(repr(cmdList))

        return 0

    # override from commandtarget
    #
    # doCommandStr: try to find the command in command_dict
    #      if found, run it, returning 0 if no errors
    #      if not found, return 1

    def doCommandStr(self, cmdString, *args, **kwargs):
        result = None

        debugCmd = self.debugSectsContains("cmd")

        if debugCmd:
            self.debugPrint(f"in doCommandStr")

        argList = args[0]

        if debugCmd:
            print(f"command is {cmdString}")
            print(f"args are {repr(argList)}")

        # (extract from args whatever might be needed
        #   #  for running the command)

        if cmdString == self.cmdReload:
            self.debugPrint("reloading config file...")
            self.doReload(self.scriptPath)
        elif cmdString in self.command_dict:
            # next line calls -function- stored in command_dict
            if debugCmd:
                print(f"command found, run it")
            result = self.command_dict[cmdString](cmdString, argList, kwargs)
        else:
            if debugCmd:
                print(f"cmd is not reload, and is not found, pass buck to superclass")
            # pass buck to superclass
            result = super(irc_subst, self).doCommandStr(cmdString, args, kwargs)

        # return success/fail exit status
        return result

    # for debugging, print a list, one line per item

    def debugPrintListAsStack(self, theList):
        if len(theList) == 0:
            self.debugPrint("stack empty")
        else:
            for index, item in enumerate(theList):
                self.debugPrint(f"{index}: {item}")

    # takes
    #   the string to be sent (which could be altered inside the func)
    # returns a list,
    #   first item is True if the string is altered, False otherwise
    #   second item is the string
    #
    # extracts any strings it finds that match [[something]]
    # looks up those keys
    # substitutes the values for the keys
    #
    # also parses the [[ ... ]] stuff
    # -note- there's no current reason to allow a [[ ... ]]
    # to span lines

    def outLine(self, inString):
        debug_outline = self.debugSectsContains("outline")
        debug_noOut = self.debugSectsContains("mute")
        macro_stack = []

        lookup = {}

        modified = False

        # split string using [[ and ]] as delims
        linelistparen = re.split(r'(\[\[|\]\])', inString)

        if debug_outline:
            self.debugPrint("paren list: " + repr(linelistparen))
            self.debugPrint("macro stack:")
            self.debugPrintListAsStack(macro_stack)

        # will become output string
        resultList = []

        lookup = dict()

        outStrParen = ""

        while len(linelistparen) != 0:
            currSymbol = linelistparen.pop(0)

            if currSymbol == '[[':
                # start of macro call
                macro_stack.append(resultList)
                resultList = ["[["]

                if debug_outline:
                    self.debugPrint("\nstart of macro")
                    self.debugPrint("currSymbol: %s" % (currSymbol))
                    self.debugPrint("resultList: %s" % (resultList))
                    self.debugPrint("macro stack:")
                    self.debugPrintListAsStack(macro_stack)
            elif currSymbol == ']]':
                # end of macro call

                # if nothing is on macro_stack, this is an error
                if len(macro_stack) == 0:
                    hexchat.prnt("Syntax error: ]] without [[\n")
                    linelistparen = []
                else:
                    # parameter of macro call (incl. name of macro)
                    resultList.append(']]')

                    if debug_outline:
                        self.debugPrint("resultList just after ]] seen:")
                        self.debugPrint(repr(resultList))

                    # invoke the macro, to produce a string, then replace
                    # resultList with [thatString] and set the var
                    # modified to True, to tell hexchat not to eat it

                    if debug_outline:
                        self.debugPrint("macro call is %s\n" % (repr(resultList)))

                    resultList.pop(0) # [[
                    resultList.pop(-1) # ]]

                    # look name up
                    macro_call_name = resultList.pop(0) # name

                    lookup = self.lookupKeyList([macro_call_name], lookup)

                    # now, resultList has just has the parameters, so compare
                    # length of actual params to length of formal params

                    if macro_call_name in lookup:
                        macro = lookup[macro_call_name]

                        # resultList should now have just the params of the macro call: their number
                        # should match the number of formal params in the macro definition (well, first cut.)

                        matchObj = re.match(self.macro_re, macro)
                        mac_params = matchObj.group(1)
                        mac_body = matchObj.group(2).lstrip() # and remove leading spaces

                        # params in (params list) are space-separated
                        mac_params_array = mac_params.split()

                        # this simple comparison will change when I add features to macros
                        if len(mac_params_array) == len(resultList):
                            # params in the body should be of the form %name%, so change formal params to that
                            renamed_params = ["%" + x + "%" for x in mac_params_array]

                            param_lookup = dict(zip(renamed_params, resultList))

                            param_pattern = r"(%[a-zA-Z0-9_-]+%)"

                            body_param_list = re.split(param_pattern, mac_body)

                            # apply the macro, and substitute the params
                            out_list = []
                            for body_part in body_param_list:
                                if body_part in param_lookup:
                                    out_list.append(param_lookup[body_part])
                                else:
                                    out_list.append(body_part)

                            result_str = "".join(out_list)

                            resultList = [result_str]

                            modified = True
                        else: # wrong nbr of params
                            self.debugPrint("wrong number of macro parameters\n")
                    else: # macro not found in lookup table
                        # turn the text of the call into a string

                        resList = resultList[:]
                        resList.insert(0, macro_call_name)
                        resultList = [ f"[[{' '.join(resList)}]]"]

                        modified = True

                        if debug_outline:
                            self.debugPrint(f"converted macro call: {repr(resultList)}")

                    tempList = resultList
                    resultList = macro_stack.pop(-1)
                    resultList.extend(tempList)

                if debug_outline:
                    self.debugPrint("\nend of macro")
                    self.debugPrint("currSymbol: %s" % (currSymbol))
                    self.debugPrint("resultList: %s" % (resultList))
                    self.debugPrint("macro stack:")
                    self.debugPrintListAsStack(macro_stack)
            else:
                # parameter of macro call or not in a macro call
                # separate macro parameters

                if len(macro_stack) != 0:
                    # inside any number of macro calls

                    paramsList = shlex.split(currSymbol)

                    if debug_outline:
                        self.debugPrint("\nparameter of macro")

                    resultList.extend(paramsList)
                else:
                    # outside all macro calls

                    resultList.append(currSymbol)

                    if debug_outline:
                        self.debugPrint("\nnot inside a macro call")

                if debug_outline:
                    self.debugPrint("currSymbol: %s" % (currSymbol))
                    self.debugPrint("resultList: %s" % (resultList))
                    self.debugPrint("macro stack:")
                    self.debugPrintListAsStack(macro_stack)

        # while loop has exited, so linelistparen is empty.
        #
        # so, either the macro_stack is also empty (means we're done)
        # or it's not, meaning there are missing ']]'s

        if len(macro_stack) != 0:
            hexchat.prnt("Syntax error: [[ without ]]\n")
            outStrParen = ""
        else:
            outStrParen = "".join(resultList)

        if debug_outline:
            self.debugPrint("Exit outLine")

        if debug_noOut:
            result = [False, None] # debugging: MUTE output
        else:
            result = [modified, outStrParen]

        return result

    # prints to the irc client the list of keys available in the db
    def list_keys(self, cmdString, argList, kwargs):

        if self.config["db"]["dbOK"]:

            factoids = self.sqla_dbutils_obj.sqla_factoids_table
            sel = select([factoids.c.key, factoids.c.value]).order_by(factoids.c.key)

            with self.sqla_eng.begin() as conn:
                result = conn.execute(sel)

            macro_string = ""
            for row in result:
                test_str = row[factoids.c.key]
                macro_def = row[factoids.c.value]
                macro_match_obj = self.macro_re.match(macro_def)

                if macro_match_obj is not None:
                    macro_params = macro_match_obj.group(1) # macro params

                    params_list = macro_params.split()
                    params_list.insert(0, test_str) # put macroname as first param

                    if self.macroname_key_re.match(test_str):
                        macro_string += "[[" + " ".join(params_list) + "]]" + "\n"
                else:
                    self.debugPrint \
                    (
                        "the macro value ('%s') at key '%s' doesn't look like a macro"
                      %
                        (macro_def, test_str)
                    )

            # in Python 3, no strings support the buffer interface, because they don't contain bytes.
            # Before, I was using print. print only writes strings. I shouldn't use print to try and
            # write to a file opened in binary mode (and a pipe is opened in binary mode). I should use
            # the write() method of to_col, which itself is a pipe.

            column = subprocess.Popen(["/usr/bin/column"], stdin=PIPE, stdout=PIPE)
            comm_stdout, comm_sterr = column.communicate(macro_string.encode())

            lineList = comm_stdout.splitlines()
            for line in lineList:
                self.debugPrint(line.decode())

            result = 0 # success
        else:
            print("no db")
            result = 1

        return result

    # accepts an irc line as a list of words, which is the arguments to a command
    # consolidates the quoted arguments into a single list item
    # returns the list of quoted and not-quoted args

    def quotizeWordList(self, lst):
        li = iter(lst)
        result = []

        for w in li:
            result.append(w)

        return result

    # refactored from inputHook(), this is called if the
    # input line is found to be backslashed.

    def process_backslashed_line(self, word_eol):
        backslashed_line = word_eol[0]
        hexchat.command(f"say {backslashed_line[1:]}")
        outLineResult = self.outLine("say " + backslashed_line[1:])

        # implement noout in debugsects by testing for None
        if outLineResult[1] is None:
            # means we're testing:
            # noout is in debugSects, so mute user output
            # and don't do anything else

            pass

        result = hexchat.EAT_ALL

        return result

    # refactored from inputHook(), this is called if the input
    # is found to be a command; process that command

    def process_command(self, word):
        debugCmd = self.debugSectsContains("cmd")
        debug_input = self.debugSectsContains("input")

        if debug_input: self.debugPrint("first word starts with cmdPrefix")

        result = hexchat.EAT_ALL

        cmd = word[0][1:]
        args = word[1:]

        if debug_input or debugCmd:
            self.debugPrint(f"cmd is {cmd}")
            self.debugPrint(f"args are {args}")

        cmdResult = self.doCommandStr(cmd, args, None)

        if cmdResult == 1:
            result = hexchat.EAT_NONE
            print(f"command '{cmd}' not found")

        else:
            # eat the command the user typed if found;
            # if not, let it get sent like any other input
            result = hexchat.EAT_ALL

        return result

    def process_normal_line(self, line):
        result = hexchat.EAT_NONE

        outLineResult = self.outLine(f"say {line}")

        if outLineResult[0]:
            # outLine() altered the line, so use
            # the one in outLineResult[1]

            result = hexchat.EAT_ALL
            hexchat.command(outLineResult[1])

        return result

    def process_quoting(self, input_line):
        debugQuote = self.debugSectsContains("quotes")

        if debugQuote:
            self.debugPrint("enter process_quoting")

        # result is a list of dicts, each has the char, and some attribs
        result = []
        self.next_ch_backslashed = False
        in_single_quote = False
        in_double_quote = False

        for ch in input_line:
            if debugQuote:
                self.debugPrint(f"this char is {ch}")

            if self.next_ch_backslashed:
                # add the char, with a "quoted" attrib
                result.append({"ch": ch, "quoted": True})
                self.next_ch_backslashed = False
            elif in_single_quote:
                if ch == "'":
                    # end of quoted string
                    in_single_quote = False
                else:
                    # single quoted character, add it
                    pass
            elif in_double_quote:
                if ch == '"':
                    # end of double quote
                    in_double_quote = False
                else:
                    # double quoted character, add it
                    pass
            elif ch == '\\':
                self.next_ch_backslashed = True
            elif ch == "'":
                # single quote
                in_single_quote = True
            elif ch == '"':
                # start of double quote
                in_double_quote = True

        if debugQuote:
            self.debugPrint("exit process_quoting")

        return result

    # this function interfaces with hexchat when it is set as the input hook
    #
    # if the input starts with self.cmdPrefix (a char), it is considered a command
    # and is sent to be processed to doCommmandStr().
    #
    # if not, it's a regular irc line, which is searched for keys which will be
    # substituted by the values from the db

    def inputHook(self, word, word_eol, userdata):
        # line from irc client
        input_line = word_eol[0]

        # default return value
        result = hexchat.EAT_NONE

        # are we debugging input and inputHook? commands?
        debug_input = self.debugSectsContains("input")
        debugCmd = self.debugSectsContains("cmd")
        debug_initinput = self.debugSectsContains("initinput")
        debugQuote = self.debugSectsContains("quotes")

        # some opening debug info
        if debug_input:
            self.debugPrint("entering inputHook()")

            self.debugPrint("print the word array:")

            self.debugPrint(f"word's type is {type(word)}")

            if word is not None:
                self.debugPrint(f"word in detail is: {detailList(word)}")
            else:
                self.debugPrint("word is None")

        if debug_initinput:
            self.debugPrint(repr(word))

        #if not self.sent:
        # note, there's no more self.sent

        #self.sent = True

        if len(word) > 0:
            if debug_input:
                self.debugPrint("len(word) > 0")
                self.debugPrint(f"the input line is {input_line}")

            # new quoting system

            quoting_result = self.process_quoting(input_line)

            if debugQuote:
                if len(quoting_result) > 0:
                    for d in quoting_result:
                        self.debugPrint(repr(d))
                else:
                    self.debugPrint("input line empty")

            if word_eol[0].startswith("\\"):
                # if so, the irc line is backslashed

                if debug_input or debug_initinput:
                    self.debugPrint(f"first word (should start '\\') is {word[0]}")

                if debug_initinput:
                    self.debugPrint(f"repr(word): {repr(word)}")

                result = self.process_backslashed_line(word_eol)

            elif word[0].startswith(self.config["general"]["command-prefix"]):

                if debugCmd or debug_input or debug_initinput:
                    self.debugPrint("cmd prefix present, go process command")

                if debug_initinput:
                    self.debugPrint(f"word: {detailList(word)}")

                result = self.process_command(word)

            else: # not a command, not backslashed, so normal line
                if debug_initinput:
                    self.debugPrint(f"normal line, {detailList(word)}")

                result = self.process_normal_line(word_eol[0])

        else:
            if debug_input:
                self.debugPrint("word is an empty list")

        #self.sent = False

        return result

    # text event hook func for 'Channel Message'
    def channel_msg_hook(self, word, word_eol, userdata, attribs):
        dest = hexchat.get_info('channel')

        nick = word[0]
        msg = word[1]

        # index user_list by nick, in user_dict
        # NOTE, TODO: build a way to keep this list maintained
        user_list = hexchat.get_list("users")

        user_dict = dict()
        for user in user_list:
            user_dict[user.nick] = user

        user_hostmask = user_dict[nick].host

        if self.debugSectsContains("chanmsgdetail"):

            out = "chanmsgdetail dest: " + dest + "; nick: " + nick
            out += " ("
            if user_hostmask is not None:
                out += user_hostmask
            else:
                out += "None"
            out += "); msg: " + msg

            self.debugPrint(out)

        return hexchat.EAT_NONE

    # text event hook func for 'Private Message'
    # and also for 'Private Message to Dialog'
    def private_maybe_dialog_msg_hook(self, dialog_p, word, word_eol, userdata, attribs):
        sender_nick = word[0]
        msg = word[1]

        # if "privmsgdetail" is in debugsects, show the entire array
        # of all priv messaages and messages to channels.
        if self.debugSectsContains("privmsgdetail"):
            debugDetailP = True
        else:
            debugDetailP = False

        # if the word "privmsgbasic" is in the list debugSects, print debug message
        if self.debugSectsContains("privmsgbasic"):
            debugBasicP = True
        else:
            debugBasicP = False

        # if the word "privmsgsql" is in the list debugSects, print debug message
        if self.debugSectsContains("privmsgsql"):
            debugSQLP = True
        else:
            debugSQLP = False

        if dialog_p:
            eventStub = "privMsgToDialog"
        else:
            eventStub = "privMsg"

        if debugDetailP:
            self.debugPrint(eventStub + ": " + detailList(word))

        if debugBasicP:
            self.debugPrint(eventStub + ": nick: %s, message: %s" % (sender_nick, msg))

        return hexchat.EAT_NONE

    def private_msg_hook(self, word, word_eol, userdata, attribs):
        result = self.private_maybe_dialog_msg_hook(False, word, word_eol, userdata, attribs)

        return result

    def private_dialog_msg_hook(self, word, word_eol, userdata, attribs):
        result = self.private_maybe_dialog_msg_hook(True, word, word_eol, userdata, attribs)

        return result

    def insertFailedLogin(self, failed_login_id_or_null, ip_or_hostname_or_null, timestamp_or_null):
        if timestamp_or_null is None:
            # get a now() into timestamp_or_null with correct time zone
            timestamp_or_null = arrow.now().datetime

        # (begin transaction)
        with self.sqla_eng.begin() as conn:

          # (get id if failed_login_id_or_null is None)
          if failed_login_id_or_null is None:
              failed_login_id_or_null = nextObjectID(conn)

          # (add row to failed_logins_sasl table)
          fl_ins = self.sqla_failed_logins_table.insert()

          conn.execute\
          (
            fl_ins,
            {
                'failed_login_id': failed_login_id_or_null,
                'host_or_ip_addr': ip_or_hostname_or_null,
                'timestamp': timestamp_or_null
            }
          )
          # (end transaction)

    # func processSASLFailedNotice
    #    check for sasl failed login, and log it if so
    #
    #   self - a value of type my irc_subst class
    #   word - input from server, split into words
    #   word_eol - documented in hexchat docs
    #   userdata - documented in hexchat docs

    def processSASLFailedNotice(self, word, word_eol, userdata, result):
        # one from libera, from client: -SaslServ- <Unknown user on tin.libera.chat (via SASL):69-92-185-65.cpe.sparklight.net> failed to login to jim. There have been 3 failed login attempts since your last successful login.
        w = word # less typing
        debugNoticeP = self.debugSectsContains("notice")
        debugNoticeTestsP = self.debugSectsContains("noticetests")

        if debugNoticeP:
            self.debugPrint("ENTER processSASLFailedNotice")

        if debugNoticeP:
            self.debugPrint("word array length: " + str(len(w)))

        if debugNoticeP:
            self.debugPrint("word_eol[0] is " + word_eol[0])

        src_hostmask = w[0][1:]

        if debugNoticeP:
            self.debugPrint("source hostmask was " + src_hostmask)

        # is it from saslserv?
        fromSASLServ_maybe_freenode = (src_hostmask == "SaslServ!SaslServ@services.")
        fromSASLServ_libera = (src_hostmask == "SaslServ!SaslServ@services.libera.chat")
        fromSASLServP = (fromSASLServ_maybe_freenode or fromSASLServ_libera)

        if fromSASLServP:
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

                if self.config["db"]["dbOK"]:
                    strDbOk = ""
                else:
                    strDbOk = " (no db)"

                print("failed sasl login from %s%s" % (ipAddr, strDbOk))

                if self.config["db"]["dbOK"]:
                    self.insertFailedLogin(None, ipAddr, None)

                result = hexchat.EAT_ALL
            else:
                if debugNoticeTestsP:
                    self.debugPrint("!justToMeP or !failedLoginP or !unknownUserP or !viaSASLP")
                    self.debugPrint("justToMeP: %s, failedLoginP: %s, unknownUserP: %s, viaSASLP: %s" % (str(justToMeP), str(failedLoginP), str(unknownUserP), str(viaSASLP)))

        elif src_hostmask == "NickServ!NickServ@services.":
            # TODO: [20170301 00:45:36] -NickServ- JiML_!~jim@kivu.grabeuh.com failed to login to jim.  There have been 75 failed login attempts since your last successful login.
            # TODO: [20170302 12:31:37]  notice: [0]: :NickServ!NickServ@services. [1]: NOTICE [2]: jim [3]: :+JiML_!~jim@kivu.grabeuh.com [4]: failed [5]: to [6]: login [7]: to [8]: jim. [9]: There [10]: have [11]: been [12]: 135 [13]: failed [14]: login [15]: attempts [16]: since [17]: your [18]: last [19]: successful [20]: login.
            # messages as they appeared in client:
            # -SaslServ- <Unknown user on tin.libera.chat (via SASL):69-92-185-65.cpe.sparklight.net> failed to login to jim. There have been 2 failed login attempts since your last successful login.
            # -SaslServ- <Unknown user on tin.libera.chat (via SASL):69-92-185-65.cpe.sparklight.net> failed to login to jim. There have been 3 failed login attempts since your last successful login.
            # -SaslServ- <Unknown user on tin.libera.chat (via SASL):69-92-185-65.cpe.sparklight.net> failed to login to jim. There have been 4 failed login attempts since your last successful login.
            # -SaslServ- <Unknown user on sodium.libera.chat (via SASL):69-92-185-65.cpe.sparklight.net> failed to login to jim. There have been 5 failed login attempts since your last successful login.
            # -SaslServ- <Unknown user on sodium.libera.chat (via SASL):69-92-185-65.cpe.sparklight.net> failed to login to jim. There have been 6 failed login attempts since your last successful login.
            # notice: [0]: :SaslServ!SaslServ@services.libera.chat [1]: NOTICE [2]: jim [3]: :<Unknown [4]: user [5]: on [6]: copper.libera.chat [7]: (via [8]: SASL):108-226-23-245.lightspeed.sntcca.sbcglobal.net> [9]: failed [10]: to [11]: login [12]: to [13]: jim. [14]: There [15]: have [16]: been [17]: 8 [18]: failed [19]: login [20]: attempts [21]: since [22]: your [23]: last [24]: successful [25]: login.

            justToMeP = (w[2] == "jim")
            failedLoginP = (w[4] == "failed" and w[6] == "login")

            if debugNoticeTestsP:
                self.debugPrint("justToMeP: %s, failedLoginP: %s" % (str(justToMeP), str(failedLoginP)))

            if justToMeP and failedLoginP:
                failingHostmask = w[3][2:]

        else:
            # from someone else
            if debugNoticeTestsP:
                self.debugPrint("notice was not from saslserv or nickserv")

        if debugNoticeP:
            self.debugPrint("notice: %s" % (detailList(word)))

        if debugNoticeP:
            self.debugPrint("EXIT processSASLFailedNotice")

        return result


    def notice_hook(self, word, word_eol, userdata):
        result = hexchat.EAT_NONE
        debugNoticeP = self.debugSectsContains("notice")
        debugNoticeTestsP = self.debugSectsContains("noticetests")
        w = word # less typing

        result = self.processSASLFailedNotice(word, word_eol, userdata, result)

        return result

    def join_hook(self, word, word_eol, userdata, attribs):
        if self.debugSectsContains("join"):
            debugJoinP = True
        else:
            debugJoinP = False

        if debugJoinP:
            self.debugPrint("debugJoinP: " + word_eol[0])
            self.debugPrint("attribs:    " + repr(attribs))

        return hexchat.EAT_NONE

    def part_hook(self, word, word_eol, userdata, attribs):
        if self.debugSectsContains("part"):
            debugPartP = True
        else:
            debugPartP = False

        if debugPartP:
            self.debugPrint("debugPartP: " + word_eol[0])
            self.debugPrint("attribs:    " + repr(attribs))

        return hexchat.EAT_NONE

    def partreas_hook(self, word, word_eol, userdata, attribs):
        if self.debugSectsContains("partreas"):
            debugPartReasP = True
        else:
            debugPartReasP = False

        if debugPartReasP:
            self.debugPrint("debugPartReasP: " + word_eol[0])
            self.debugPrint("attribs:    " + repr(attribs))

        return hexchat.EAT_NONE


# make an object of the class which contains all of the above funcs as methods
irc_subst_obj = irc_subst(pathname)

# establish the hook to the input method, immediately above
hexchat.hook_command('', irc_subst_obj.inputHook)

# establish the hook to the notice method of irc_subst, above
hexchat.hook_server('NOTICE', irc_subst_obj.notice_hook)

# establish the hook to the join_hook method of irc_subst, above
hexchat.hook_print_attrs('Join', irc_subst_obj.join_hook)

# establish the hooks to the part_hook and partreas_hook methods of irc_subst, above
hexchat.hook_print_attrs('Part', irc_subst_obj.part_hook)
hexchat.hook_print_attrs('Part with Reason', irc_subst_obj.partreas_hook)

# establish for channel, and for private, messages
hexchat.hook_print_attrs('Channel Message', irc_subst_obj.channel_msg_hook)
hexchat.hook_print_attrs('Private Message', irc_subst_obj.private_msg_hook)
hexchat.hook_print_attrs('Private Message to Dialog', irc_subst_obj.private_dialog_msg_hook)
