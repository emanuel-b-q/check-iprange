#!/bin/bash
set -x

usage() {
  echo "$0 -n <xxx.xxx.xxx.xxx/xx> [ -w|--warning <number>% -c|--critical <number>% -l|--lower <number> -u|--upper <number>]"
  echo " "
  echo "Where xxx.xxx.xxx.xxx it the network address, xx is the prefixlen "
  echo "The current status is OK, as long as one system responds"
  #echo "optional is the usage of -w (--warning) and -c (--critical) which specifies the percentage of systems which must be reachable"
  #echo "optional is also the usage of -l (--lower) and/or -u (--upper) to specify a number"
  #echo "in case all optional parameters are empty/not set the check is OK as long as there is ONE system responding"
  #echo "if -u or -l are specified they have precedence over -w/-c
  echo "eg. $0 -n 192.168.1.0/24 -w 40% -c 90%"
  exit 2
}

GETOPT=$(getopt -o n:,l:,u:,w:,c: --long network:,lower:,upper:,warning:,critical: -n $0 -- "$@")

if [ $? != 0 ]; then usage; fi


eval set -- "$GETOPT"

while true; do
        case "$1" in
                -n | --network )    NETWORK="$(echo $2 | sed -e "s/'//g")"; shift 2;;
                -w | --warning )    WARNING="$(echo $2 | sed -e "s/'//g")"; shift 2;;
                -l | --lower )      LOWER="$(echo $2 | sed -e "s/'//g")"; shift 2;;
                -u | --upper )      UPPER="$(echo $2 | sed -e "s/'//g")"; shift 2;;
                -c | --critical )   CRITICAL="$(echo $2 | sed -e "s/'//g")"; shift 2;;
                -- )                shift; break;;
                * )                 break;;
        esac
done

if [ ! "$NETWORK" ] ; then usage; fi

######################################################################
#
# GLOBAL VARIABLES
#
######################################################################
PLUGINNAME="CHECK-FPING"
EXITTEXT=([0]=OK [1]=WARNING [2]=CRITICAL [3]=UNKNOWN)
PERFDATA=""
EXITSTATE=0
STATUSLINE=""
LONGOUTPUT=""
TEMPFILEHOSTID=`mktemp --suffix=hostid`
CRIT=100%
WARN=100%

######################################################################
#
# INITIALIZE VARIABLES
#
######################################################################
if [ ! "$LOWER" ] ;  then LOWER=0; fi
if [ ! "$UPPER" ] ;  then UPPER=0; fi
if [ ! "$WARNING" ] ;  then WARNING=100; else WARN=`echo ${WARNING} | tr -d '%'` ; fi
if [ ! "$CRITICAL" ] ;  then CRITICAL=100; else CRIT=`echo ${CRITICAL} | tr -d '%'` ;fi
echo ${CRIT}
echo ${WARN}

######################################################################
#
# GLOBAL FUNCTIONS
#
######################################################################
longout_append () {
        RET=$?
        LONGOUTPUT="$LONGOUTPUT$@\n"
        return ${RET}
}

statusline_append () {
    if [ -z "${STATUSLINE}" ] ; then
        STATUSLINE=":"
    else
        DELIMITER=" - "
    fi

    STATUSLINE="${STATUSLINE}${DELIMITER}$@"
}

set_exit_state() {
        if [ ${1} -gt ${EXITSTATE} -o ${EXITSTATE} -eq 3 ] ; then
            EXITSTATE=$1
        fi

        if [ ${1} -gt 0 ] ; then
            statusline_append "$2:" ${EXITTEXT[$1]}
        fi

        return $1
}

exit_plugin () {
    test -n "$1" && STATUSLINE=$@
    echo "${PLUGINNAME} ${EXITTEXT[$EXITSTATE]} ${STATUSLINE}${PERFDATA}"
    echo -e $LONGOUTPUT
    exit $EXITSTATE
}
######################################################################
#
# Check for IP Range
#
######################################################################
#echo "Please use this: check_fping.sh <ip-range> w% c%"
#echo " for example : check_fping.sh 10.43.132.0/24 45% 10%"
#rm /tmp/hostid.txt

fping -i 10 -r 1 -g ${NETWORK} >& $TEMPFILEHOSTID

total=`cat $TEMPFILEHOSTID | grep -v "ICMP Echo sent" |wc -l`
Alive=`cat $TEMPFILEHOSTID | grep alive | wc -l`
Unreach=`cat $TEMPFILEHOSTID | grep unreach | wc -l`
echo "Total number of IP: $total"
echo  "Number of IP online on ${NETWORK}: $Alive"
echo "Number of IP offline ${NETWORK}: $Unreach"

# No floating point in shell
# percent_unreach=`bc <<< "scale=2; 100*$Unreach/$total"`
percent_unreach=$((100*$Unreach/$total + 200*$Unreach/$total % 2))


# No floating point in shell
# percent_alive=`bc <<< "scale=2; 100*$Alive/$total"`
percent_alive=$((100*$Alive/$total + 200*$Alive/$total % 2))

echo "IPs online percentage is: $percent_alive%"
echo "IPs offline percentage is: $percent_unreach%"
iprange=`echo $NETWORK | cut -d "/" -f 1`

PERFDATA="|'iprange_usage_percent'=${percent_alive}%;${WARN}%;${CRIT}%;0%;100% 'IPs_active'=${Alive};0;${total}"

rm $TEMPFILEHOSTID
if [ $Alive -ge "1" ]; then
  if [ ${percent_alive} -gt ${CRIT} ]
    then
    longout_append "The usage of ${NETWORK} ip range reached the CRITICAL level!"
    set_exit_state 2
  elif [ ${percent_alive} -gt ${WARN} ]
    then
    longout_append "The usage of ${NETWORK} ip range reached the WARNING level!"
    set_exit_state 1
  else
    longout_append "The usage of ${NETWORK} ip range is GOOD and Active!"
    set_exit_state 0
  fi
else
  longout_append "No host available for the ${NETWORK} ip range!"
  set_exit_state 2
fi

exit_plugin
