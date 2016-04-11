#!/usr/bin/python3

__module_name__ = "Jim's IRC substituter"
__module_version__ = "1.0.0"
__module_description__ = "IRC substituter by Jim"

print( "\0034",__module_name__, __module_version__,"has been loaded\003" )

import re

def outLine(inString):
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
                lookupResult = lookup.get(lookupKey)
                outStr += lookupResult
                lookupKey = ""
    
    return outStr

import hexchat

def inputHook(word, word_eol, userdata):
    hexchat.command(outLine(word_eol))
    
    return hexchat.EAT_ALL

hexchat.hook_command('', inputHook)