from configparser import ConfigParser

class ConfigReader:
    def __init__(self, confFilePathName):
        p = ConfigParser()
        pathName = confFilePathName + '/' + 'irc-subst.cfg'
        confFiles = p.read(confFilePathName)

        # did we successfully read the config file?
        if len(confFiles) > 0:
            self.successP = confFiles[0] == confFilePathName
        else:
            self.successP = False

        configSections = {}

        for psect in p.sections():
            configSections[psect] = {}

            for opt in p.options(psect):
                optValue = p.get(psect, opt)
                configSections[psect][opt] = optValue

        self.config = configSections

        # import like this:
        #
        # from utils.configReader import ConfigReader
        #
        # this class reads the configuration file and forms
        # a dict of the configuration sections, which it puts
        # into self.colnfig, and the value of each section is 
        # a dict of the section options, the value
        # of each option is the value of the option.
        #
        # you can acess values in the config like this:
        #
        # self.config[section name here][option name here]
