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

    # set up the lookup table
    lookup = dict()
    lookup["[[foo]]"] = "hello"
    lookup["[[bar]]"] = "world"
    
    # split string, using [[ and ]] as delims
    linelist = re.split(r'(\[{2}|\]{2})', inString)

    long = len(linelist)

    in_lookup = 0
    lookupKey = ""
    outStr = ""

    for item in range(long):
        # not forming the lookup key?
        if in_lookup == 0:
        
            # beginning of lookup key?
            if linelist[item] == "[[":
                lookupKey = "[["
                in_lookup = 2
            else: # symbol is not part of lookup key?
                outStr += linelist[item]

        else: # in the middle of forming lookup key?
            lookupKey += linelist[item]
            in_lookup -= 1
            
            # we have the whole lookup key?
            if in_lookup == 0:
                # here, we would actually do the lookup and append the result
                if lookup.__contains__(lookupKey):
                    modified = True
                    lookupResult = lookup.get(lookupKey)
                else:
                    lookupResult = lookupKey
 
                outStr += lookupResult
                lookupKey = ""
    
    return [modified, outStr]

import hexchat

sent = False

def inputHook(word, word_eol, userdata):
    global sent
    
    result = hexchat.EAT_NONE
    
    if not sent:
        sent = True
        outLineResult = outLine("say " + word_eol[0])
        if outLineResult[0]:
            hexchat.command(outLineResult[1])
            result = hexchat.EAT_ALL
        sent = False
    
    return result

hexchat.hook_command('', inputHook)