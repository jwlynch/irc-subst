import hexchat

class DebugTabObj:
    def __init__(self):
        self.debugtab_nick = "DebugTab" # TODO: put this in config file

        # add the tab for debugging
        hexchat.command(f"query {self.debugtab_nick}")

        debug_channel = None
        for c in hexchat.get_list('channels'):
            if c.channel == self.debugtab_nick:
                self.debug_tab = c

        print(repr)
            # put the channel list entry for it in the object so I can get at it

        self.context = self.debug_tab.context

    def debugPrint(self, printThis):
        reprPrintThis = repr(printThis)

        self.context.prnt(printThis) # old debugPrintS

        # try debugPrinting on curr. context, to see if I like it
        # hexchat.prnt(printThis) # trying this way
