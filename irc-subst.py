#!/usr/bin/python3

__module_name__ = "Jim's IRC substituter"
__module_version__ = "1.0.0"
__module_description__ = "IRC substituter by Jim"

print( "\0034",__module_name__, __module_version__,"has been loaded\003" )

import re
import psycopg2

def opendb():
    result = psycopg2.connect("dbname=jim user=jim")
    
    return result

def closedb(conn):
    conn.close()

# takes 
#   the string to be sent (which could be altereed inside the func)
#   the lookup table
# returns a list,
#   first item is True if the string is altered, False otherwise
#   second item is the string

def outLine(inString):
    modified = False

    # split string, using [[ and ]] as delims
    linelist = re.split(r"(\[\[[^\[\]]+\]\])", inString)

    key_re = re.compile("^\[\[[a-zA-Z-_]+\]\]$")
    key_list = list(filter(key_re.match, linelist))

    # now query the db
    conn = opendb()
    cur = conn.cursor()
    cur.execute("""select i.key,i.value from irc_subst i where i.key = any (%s)""", (key_list,))
    result_list = cur.fetchall()
    closedb(conn)

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

import hexchat
import subprocess
from subprocess import PIPE

sent = False

def inputHook(word, word_eol, userdata):
    global sent
    
    result = hexchat.EAT_NONE
    
    if not sent:
        sent = True

        if len(word) == 1:
            if word[0] == "lskeys":
                print("in lskeys")
                result = hexchat.EAT_ALL
        
                conn = opendb()
                cur = conn.cursor()
                cur.execute("select i.key from irc_subst i order by i.key;")
                result_list = cur.fetchall()
                closedb(conn)

                # in Python 3, no strings support the buffer interface, because they don't contain bytes.
                # Before, I was using print. print only writes strings. I shouldn't use print to try and 
                # write to a file opened in binary mode (and a pipe is opened in binary mode). I should use
                # the write() method of to_col, which itself is a pipe.

                column = subprocess.Popen(["/usr/bin/column"], stdin=PIPE, stdout=PIPE)
                to_col = column.stdin
                for item in buf_list:
                    #comm_result = column.communicate(item[0].encode('utf-8'))
                    print(item, file=to_col)

                ## this is the original way I printed the keys
                #for item in result_list:
                #    print(item[0])

        outLineResult = outLine("say " + word_eol[0])
        if outLineResult[0]:
            hexchat.command(outLineResult[1])
            result = hexchat.EAT_ALL
        sent = False
    
    return result

hexchat.hook_command('', inputHook)