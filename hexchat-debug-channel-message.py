import hexchat

__module_name__ = "debug"
__module_author__ = "jim"
__module_version__ = "0.1"
__module_descritption = "shows all the callback params"

# this function, to be hooked to the "Channel Message" event, is
# for the purpose of looking at the event information, doesn't
# do anything else, and because it returns EAT_NONE, hexchat will
# handle the event as normal.

def readMessage(word, word_eol, userdata, attribs):
  print("word: " + repr(word))
  print("word_eol: " + repr(word_eol))
  print("userdata: " + repr(userdata))
  print("attribs: " + repr(attribs))

  return hexchat.EAT_NONE

hexchat.hook_print_attrs('Channel Message', readMessage)
