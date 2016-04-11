#!/usr/bin/python3

import re

# set up the lookup table
lookup = dict()
lookup["[[foo]]"] = "hello"
lookup["[[bar]]"] = "world"

instring = '[[foo]], the message is "[[foo]] [[bar]]"'

# split string, using [[ and ]] as delims
linelist = re.split(r'(\[{2}|\]{2})', instring)

long = len(linelist)

in_lookup = 0
lookupKey = ""
outStr = ""

for item in range(long):
  # not in the middle of forming
  if in_lookup == 0:
    
    # beginning of lookup key?
    if linelist[item] == "[[":
      lookupKey = "[["
      in_lookup = 2
    else: # in the middle of getting lookup key?
      print("|" + linelist[item] + "|")
      outStr += linelist[item]
  else:
    lookupKey += linelist[item]
    in_lookup -= 1
    
    # we have the whole lookup key?
    if in_lookup == 0:
      print("key: " + lookupKey)
      # here, we would actually do the lookup and append the result
      outStr += lookup.get(lookupKey)
      lookup = ""

print("final out: " + outStr)
