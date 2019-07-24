masksToBan = "*!*@1.248.57.188 *!*@121.165.250.205 *!*@100.net119083074.t-com.ne.jp *!*@119.192.209.120 *!*@119.192.167.20 *!*@y247171.dynamic.ppp.asahi-net.or.jp *!*@p1080172-ipngn200805fukuokachu.fukuoka.ocn.ne.jp *!*@14.34.175.28 *!*@flets-110-092-039-072.fip.synapse.ne.jp *!*@39.122.244.17 *!*@211.208.194.109"

maskList = masksToBan.split()

# given list of hostmasks, write out commands to banforward them
#
#for mask in maskList:
#    print("/mode ##linux +b " + mask + "$##arguments")

# list of banIDs kept by eir

eir_ban_numbers = "125773 125774 125776 125777 125778 125779 125780 125781 125782 125783 125784"

banList = eir_ban_numbers.split()

# given list of banIDs, tell eir to ban for 10 years
#
for banid in banList:
    print ("btset " + banid + " ~3650d")
