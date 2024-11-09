class DebugSectsObj:
    def __init__(self):
        self.debugSectsList = []

    def debugSectsContains(self, sectName):
        result = dex(sectName, self.debugSectsList) != -1

        return result

    def addDebugSect(self, addedSect):
        if not self.debugSectsContains(addedSect):
            self.debugSectsList.append(addedSect)
            self.debugPrint(f"debugsects add: {addedSect}")
        else:
            self.debugPrint(f"debugsects add: {addedSect} already present")

    def rmDebugSect(self, removedSect):
        if self.debugSectsContains(removedSect):
            self.debugSectsList.remove(removedSect)
            self.debugPrint(f"debugsects rm: {removedSect}")
        else:
            self.debugPrint(f"debugsects rm: {removedSect} not present")

