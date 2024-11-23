from configparser import ConfigParser

class ConfigReader:
    def __init__(self, confFilePathName):
        p = ConfigParser()
        pathName = confFilePathName + '/' + 'irc-subst.cfg'
        confFiles = p.read(pathName)

        # did we successfully read the config file?
        if len(confFiles) > 0:
            self.successP = pathName in confFiles
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

        # pull stuff from general section of config file

        if 'general' in self.config:
            if 'command-prefix' in self.config['general']:
                pass
            else:
                # no command-prefix in general sect
                self.config['general']['command-prefix'] = '.' # default

            if 'print-config' in self.config['general']:
                if self.config['general']['print-config'].startswith("t"):
                    self.config['general']['print-config'] = True
                elif self.config['general']['print-config'].startswith("f"):
                    self.config['general']['command-prefix'] = False
                else:
                    self.config['general']['print-config'] = True # default
            else:
                # no print-config in general sect
                self.config['general']['print-config'] = True # default

        else:
            # no general sect
            self.config['general'] = {}

            self.config['general']['command-prefix'] = '.' # default
            self.config['general']['print-config'] = True # default

        # now form sqlalchemy connect string

        # if there's no db section in the config, db is bad
        if 'db' in self.config:
            self.config["db"]["dbOK"] = True
        else:
            self.config["db"]["dbOK"] = False

        self.dbSpecs = None
        self.config["db"]["sqlalchemy_conn_str"] = None

        if self.config["db"]["dbOK"]:
            # build the sqlalchemy connect string
            k = self.config['db'].keys()

            # sample conn str: postgresql://scott:tiger@localhost/test?application_name=myapp

            s = "postgresql://"
            if 'user' in k:
                s += self.config['db']['user']
                if 'password' in k:
                    s += ':' + self.config['db']['password']

                if 'host' in k:
                    s += '@' + self.config['db']['host']
                else:
                    s += '@localhost'

                if 'port' in k:
                    s += ':' + self.config['db']['port']

            s += '/' + self.config['db']['dbname']

            # put app name in connect string, if it appears in the config
            if 'appname' in k:
                s += f"?application_name={self.config['db']['appname']}"

            self.config['db']['sqlalchemy_conn_str'] = s
