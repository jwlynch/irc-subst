from utils.dex import dex

class DebugSectsObj:
    def __init__(self):
        self.debugSectsList = []
    
    def debugSectsContains(self, section):
        return dex(section, self.debugSectsList) != -1

    def addDebugSect(self, addedSect):
        if not self.debugSectsContains(addedSect):
            self.debugSectsList.append(addedSect)

            result = [True, f"debugsects add: {addedSect}"]
        else:
            result = [False, f"debugsects add: {addedSect} already present"]

        return result

    def rmDebugSect(self, removedSect):
        if self.debugSectsContains(removedSect):
            self.debugSectsList.remove(removedSect)

            result = [True, f"debugsects rm: {removedSect}"]
        else:
            result = [False, f"debugsects rm: {removedSect} not present"]

        return result

