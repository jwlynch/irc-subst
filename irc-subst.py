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

def outLine(inString, lookup):
    modified = False

    # split string, using [[ and ]] as delims
    linelist = re.split(r"(\[\[[^\[\]]+\]\])", inString)

    key_re = re.compile("^\[\[[a-zA-Z-_]+\]\]$")
    key_list = list(filter(key_re.match, linelist))

    # now query the db
    conn = opendb()
    cur = conn.cursor()
    cur.execute("""select i.key,i.value from irc_subst i where i.key = any (%s)""", (key_list))
    result_list = cur.fetchall()
    closedb(conn)
    #debug
    print("key list:")
    print(key_list)
    print("result list:")
    print(result_list)

    numItems = len(linelist)

    outStr = ""

    for item in range(numItems):
        if lookup.__contains__(linelist[item]):
            outStr += lookup[linelist[item]]
            modified = True
        else:
            outStr += linelist[item]

    return [modified, outStr]

import hexchat

sent = False

def inputHook(word, word_eol, userdata):
    global sent
    
    result = hexchat.EAT_NONE
    
    if not sent:
        sent = True

        # set up the lookup table
        lookup = dict()
        lookup["[[foo]]"] = "hello"
        lookup["[[bar]]"] = "world"
        
        outLineResult = outLine("say " + word_eol[0], lookup)
        if outLineResult[0]:
            hexchat.command(outLineResult[1])
            result = hexchat.EAT_ALL
        sent = False
    
    return result

hexchat.hook_command('', inputHook)