import hexchat

__module_name__ = "hexTest"

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
