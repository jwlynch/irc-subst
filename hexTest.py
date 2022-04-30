# thanks for agreeing to help by testing this script
#
# The first step, is to load the script,
#
# (menu) => Hexchat => Load Plugin or Script
#
# then navigate to this script, and click OK
#
# I'm looking to find out what happens if you enter 1 word,
# and 2 words, and 3 words, so, you might try:
#
# foo <enter>
# foo bar <enter>
# foo bar baz <enter>
#
# and pastebin the results.
#
# You will want to unload the script when you're done testing and
# observing, that is done this way:
#
# (menu) => Window => Plugins and Scripts
#
# then you'll get a small window, click on the line representing
# this module, it should highlight, then at the bottom center of
# the small window, you should see an Unload button, press that.
#
# NOTE, if you don't see the representative line in the small window,
# you might have to quit hexchat and restart it, to get rid of the
# script.
#
# Again, thanks!
#
# -jim

import hexchat

__module_name__ = "hexTest"
__module_version__ = "0.1d"
__module_description__ = "shows details of inputs"

hexchat.prnt(f"loading {__module_name__}-{__module_version__}")
hexchat.prnt(f"({__module_description__})")

# return a string detailing a list (its items togeter with each index)
def detailList(l):
    # self.debugPrint("testing detailList:")
    # test0 = []
    # test1 = ["one"]
    # test2 = ["one", "two"]
    # self.debugPrint(f"empty: {test0}")
    # self.debugPrint(f"1 item: {test1}")
    # self.debugPrint(f"2 items: {test2}")

    reslst = []

    for i, item in enumerate(l):
        reslst.append(f"[{i}]: {item}")

    if len(reslst) != 0:
        resStr = " ".join(reslst)
    else: # reslst is empty
        resStr = "[]"

    return resStr

def testHex(word, word_eol, userdata):
    print(f"word in detail is: {detailList(word)}")

hexchat.hook_command('', testHex)
