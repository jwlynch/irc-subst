#!/usr/bin/python3

import re

# set up the lookup table
lookup = dict()
lookup["[[foo]]"] = "hello"
lookup["[[bar]]"] = "world"

instring = '[[foo]], the message is "[[foo]] [[bar]]"'

def outLine(inString):
    # split string, using [[ and ]] as delims
    linelist = re.split(r'(\[{2}|\]{2})', instring)

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
            outStr += lookup.get(lookupKey)
            lookupKey = ""

print("final out line: " + outLine(inString))