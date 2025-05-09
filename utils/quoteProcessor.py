# class holding internal state of quoting parse

from utils.debugsects import DebugSectsObj
from utils.debugTabObj import DebugTabObj

# allow 'prepend' to an iterable currently used in a loop
from more_itertools import peekable

class QuoteProcessor:
    def __init__(self, debugSects, debugTabObject):
        self.debugSects = debugSects
        self.debugTabObject = debugTabObject

    def debugPrint(self, p):
        # forward to debugTabObject
        self.debugTabObject.debugPrint(p)

    def debugSectsContains(self, section):
        # forward to debugSects
        return self.debugSects.debugSectsContains(section)

    def quote_type_str(self):
        result = ""

        if self.next_ch_backslashed:
            result = "next char backslashed"
        elif self.curr_quote_type == 1:
            result = "in_plain_string"
        elif self.curr_quote_type == 2:
            result = "in_single_quote"
        elif self.curr_quote_type == 3:
            result = "in_double_quote"

        return result

    def end_run(self):
        res_dict = {}

        # possible values for curr_quote_type:
        in_plain_string = 1
        in_single_quote = 2
        in_double_quote = 3

        if self.curr_quote_type == in_plain_string:
            res_dict['plainStr'] = self.collector_str
        elif self.curr_quote_type == in_single_quote:
            res_dict['singlequoStr'] = self.collector_str
        elif self.curr_quote_type == in_double_quote:
            res_dict['doublequoStr'] = self.collector_str

        self.curr_quote_type = in_plain_string
        self.collector_str = ""

        return res_dict

    def process_quoting(self, input_line):
        debugQuoteByChar = self.debugSectsContains("quoteschar")
        debugQuote = self.debugSectsContains("quotes")

        # this for-loop turns the input_line into a list of dicts,
        # one for each char in the input line, the last of which
        # is marked with an "end of line" marker
        input_list = []
        for char in input_line:
            theD = dict()
            theD["ch"] = char
            theD["end"] = False

            input_list.append(theD)

        input_list[-1]["end"] = True

        if debugQuote or debugQuoteByChar:
            self.debugPrint("enter process_quoting")

        # result is a list of dicts, each has the char, and some attribs
        result = []
        self.next_ch_backslashed = False

        # possible values for curr_quote_type:
        in_plain_string = 1
        in_single_quote = 2
        in_double_quote = 3
        self.collector_str = ""
        self.curr_quote_type = in_plain_string

        for char_d in input_list:
            ch = char_d["ch"]

            if debugQuoteByChar:

                # change display quote if the ch is that quote
                if ch == "'":
                    dispCh = f'"{ch}"' # if ch is c, this is "c"
                else:
                    dispCh = f"'{ch}'" # this one is 'c'

                self.debugPrint(f"this char is {dispCh}, quoting type is {self.quote_type_str()}, backslashed is {str(self.next_ch_backslashed)}")

            if self.next_ch_backslashed:
                # add the char, with a "escaped" attrib
                result.append({"ch": ch, "escaped": True})
                self.next_ch_backslashed = False

                if debugQuoteByChar:
                    self.debugPrint(f"this char is {ch}, quoting")
            elif self.curr_quote_type == in_single_quote:
                if ch == "'":
                    # end of single-quoted string
                    result.append(self.end_run())
                    self.collector_str = "" # since adding prev one to result
                    self.curr_quote_type = in_plain_string # since at the end
                else:
                    # single quoted character, add it
                    self.collector_str += ch
            elif self.curr_quote_type == in_double_quote:
                if ch == '"':
                    # end of double quote
                    result.append(self.end_run())
                    self.collector_str = "" # since adding prev one to result
                    self.curr_quote_type = in_plain_string # since at the end
                else:
                    # double quoted character, add it
                    self.collector_str += ch
            elif ch == '\\':
                if self.curr_quote_type == in_plain_string:
                    if len(self.collector_str) > 0:
                        result.append(self.end_run())

                        self.collector_str = ""

                self.next_ch_backslashed = True

                # note, consider adding "backslashing" within single or double quotes
                # (and what this implies for quoting result)
            elif ch == "'":
                # take care of any prev. existing plainStr
                if self.curr_quote_type == in_plain_string:
                    if len(self.collector_str) > 0:
                        result.append(self.end_run())

                        self.collector_str = ""
                # single quote
                self.curr_quote_type = in_single_quote
            elif ch == '"':
                if self.curr_quote_type == in_plain_string:
                    if len(self.collector_str) > 0:
                        result.append(self.end_run())

                        self.collector_str = ""
                # start of double quote
                self.curr_quote_type = in_double_quote
            else: # self.curr_quote_type == in_plain_string
                self.collector_str += ch

                if char_d["end"]:
                    result.append(self.end_run())

        if debugQuote or debugQuoteByChar:
            self.debugPrint("exit process_quoting")

        return result
