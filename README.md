# check-iprange
Check how many IPs are used within an iprange

!! Attention -l and -u are not yet working options !!

How to execute:

# check_fping.sh -n <xxx.xxx.xxx.xxx/xx> [ -w|--warning <number>% -c|--critical <number>% -l|--lower <number> -u|--upper <number>]

Where xxx.xxx.xxx.xxx it the network address, xx is the prefixlen
The current status is OK, as long as one system responds
eg. ./check_fping.sh -n 192.168.1.0/24 -w 40% -c 90%



 
