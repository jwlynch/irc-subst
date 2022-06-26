#!/usr/bin/python3

__module_name__ = "Jim's word test script"
__module_version__ = "0.0.1d"
__module_description__ = "word test script"

import hexchat

def inputHook(word, word_eol, userdata):
    pass

# establish the hook to the input method, immediately above
hexchat.hook_command('', inputHook)
