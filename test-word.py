#!/usr/bin/python3

__module_name__ = "Jim's word test script"
__module_version__ = "0.0.1d"
__module_description__ = "word test script"

import hexchat

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

def inputHook(word, word_eol, userdata):
    pass

# establish the hook to the input method, immediately above
hexchat.hook_command('', inputHook)
