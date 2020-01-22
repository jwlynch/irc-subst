mac_split_pattern = "\(([^)]*)\)(.*)" # splits the macro def into its parts
#macro = "(a b c d e) %a% is %b% while %c% is %d% with %e%"
macro = "() paramless macro call"
mac_name = "test"
import re

# split macro def into its params string (matchObj.group(1))
# and its body (matchObj.group(2))
matchObj = re.match(mac_split_pattern, macro)

mac_params = matchObj.group(1)
mac_body = matchObj.group(2)

# params in (params list) are space-separated
mac_params_array = mac_params.split()

# this is the macro call we want to run, split into list form
#macro_call = ["((", "test", "george", "downcast", "john", "good", "wine", "))"]
macro_call = ["((", "test", "))"]

# TODO
# the name of the macro in the definition should match the first param in the call

print("macro call is %s\n" % (repr(macro_call)))

# apply the macro: first get list of actual parameters
macro_call.pop(0) # ((
macro_call.pop(-1) # ))

macro_call_name = macro_call.pop(0) # name

# now, macro_call has just has the parameters

# TODO
# macro_call should now just have the params of the macro call: their number
# should match the number of formal params in the macro definition (well, first cut.)

# params in the body should be of the form %name%, so change formal params to that
renamed_params = ["%" + x + "%" for x in mac_params_array]

param_lookup = dict(zip(renamed_params, macro_call))

param_pattern = r"(%[a-zA-Z0-9_]+%)"

body_param_list = re.split(param_pattern, mac_body)

# apply the macro, and substitute the params
out_list = []
for body_part in body_param_list:
    if body_part in param_lookup:
        out_list.append(param_lookup[body_part])
    else:
        out_list.append(body_part)

result_str = "".join(out_list)

print("result is %s\n" % (result_str))
