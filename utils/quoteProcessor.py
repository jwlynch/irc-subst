# class holding internal state of quoting parse

from utils.debugsects import DebugSectsObj
from utils.debugTabObj import DebugTabObj

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

    def process_quoting(self, input_line):
        debugQuoteByChar = self.debugSectsContains("quoteschar")
        debugQuote = self.debugSectsContains("quotes")

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
        self.curr_quote_type = 0

        for ch in input_line:
            if debugQuoteByChar:
                if ch == "'":
                    dispCh = f'"{ch}"'
                else:
                    dispCh = f"'{ch}'"

                self.debugPrint(f"this char is {dispCh}, quoting type is {self.quote_type_str()}, backslashed is {str(self.next_ch_backslashed)}")

            if self.next_ch_backslashed:
                # add the char, with a "escaped" attrib
                result.append({"ch": ch, "escaped": True})
                self.next_ch_backslashed = False

                if debugQuoteByChar:
                    self.debugPrint(f"this char is {ch}, quoting")
            elif self.curr_quote_type == in_single_quote:
                if ch == "'":
                    # end of quoted string
                    in_single_quote = False
                    result.append({"quoStr": self.collector_str})
                    self.collector_str = ""
                else:
                    # single quoted character, add it
                    self.collector_str += ch
            elif self.curr_quote_type == in_double_quote:
                if ch == '"':
                    # end of double quote
                    in_double_quote = False
                    result.append({"quoStr": self.collector_str})
                    self.collector_str = ""
                else:
                    # double quoted character, add it
                    self.collector_str += ch
            elif ch == '\\':
                self.next_ch_backslashed = True
            elif ch == "'":
                # single quote
                self.curr_quote_type = in_single_quote
            elif ch == '"':
                # start of double quote
                self.curr_quote_type = in_double_quote
            else: # self.curr_quote_type == in_plain_string
                result.append({"ch": ch, "plainP": True})

        if debugQuote or debugQuoteByChar:
            self.debugPrint("exit process_quoting")

        return result
