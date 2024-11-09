

class CommandTarget:
    def __init__(self):
        super(CommandTarget, self).__init__()
        self._itsNextTarget = None

# in your subclass's __init__(), you must call
# the inherited __init__() above, like this:
#
# def __init__(self, other, params):
#     (do whatever initialization your subclass needs)
#
#     # initialize superclass
#     super().__init__()

    def imYourNextTarget(self, aCommandTarget):
        if not isinstance(aCommandTarget, CommandTarget):
            raise Exception(
                "The object you're trying to send is not the correct type. Did you forget to also inherit from CommandTarget?"
            )

        self._itsNextTarget = aCommandTarget

#
# suggestion for command list for doCommandStr
#
# first, set vars to command strings
#
# cmdFoo = "foo"
# cmdBar = "bar"
#

    # func doCommandStr
    # takes:
    #   self - object this msg was sent to
    #   cmdString - the command to run
    #   args - positional parameters
    #   kwargs - keyword args
    # returns:
    #    0 on success
    #
    # runs one of the commands provided by the object, returns
    # a success indication or None (if no indicator was set)
    #
    # at this level, simply passes the buck to itsNextTarget (if set)

    def doCommandStr(self, cmdString, *args, **kwargs):
        result = None

        # pass the buck
        if self._itsNextTarget is not None:
            result = self._itsNextTarget.doCommandStr(cmdString, *args, **kwargs)
        else:
            result = 1

        return result

#
# doCommandStr suggestion for override
#
# def doCommandStr(self, cmdString, *args, **kwargs):
#     result = None
#
#     # (extract from args whatever might be needed
#     #  for running the command)
#
#     if cmdString == self.cmdFoo:
#         (code for the command goes here, set result to success (0) or raise exception)
#     elif cmdString == self.cmdBar:
#         (code for cmdBar goes here, set result or raise excepton)
#     else:
#         # pass buck to superclass
#         result = super(ReplaceWithThisClass, self).doCommandStr(cmdString, *args, **kwargs)
#
#     # return success/fail exit status
#     return result
