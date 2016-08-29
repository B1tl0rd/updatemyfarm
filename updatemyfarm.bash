#!/usr/bin/env bash
# Title      : updatemyfarm.bash
# Description: Update multiple Debian/CentOS servers using SSH and sudo
# Author     : linuxitux
# Date       : 11-12-2012
# Usage      : ./updatemyfarm.bash
# Notes      : Read the documentation first

# Configuration files
CONF="updatemyfarm.conf"
LOGDIR="log"

# Commands to check for updates
CMD_DEBIAN="sudo apt-get update; LANG=C sudo apt-get -s upgrade"
CMD_CENTOS="sudo yum check-update"

# Commands to update
CMD_DEBIAN_UPDT="LANG=C sudo apt-get -q -y upgrade && sudo apt-get -q -y clean"
CMD_CENTOS_UPDT="LANG=C sudo yum -y update"

# Dialog configuration
OPTIONS=""
INDEX=1
KERN=0

# Information about target servers
USERS="users"
HOSTS="hosts"
HOSTSK="hostsk"
PORTS="ports"
OSES="oses"

# Get time and date
DATETIME=$(date +%Y-%m-%d_%H-%M-%S)
echo "Starting updates: $DATETIME"
echo -n "Updating repositories..."

COUNT=0

# CONF - username:host:port:os

for SERVER in $(cat $CONF | grep -v "^#")
do
    # Parse configuration line
    USER=$(echo $SERVER | cut -d ':' -f1)
    HOST=$(echo $SERVER | cut -d ':' -f2)
    PORT=$(echo $SERVER | cut -d ':' -f3)
    OS=$(echo $SERVER | cut -d ':' -f4)

    # Verify available updates
    case $OS in
      "debian")
          ssh -p $PORT $USER@$HOST $CMD_DEBIAN >$LOGDIR/.$HOST.update.tmp 2>&1 &
          ;;
      "centos")
          (ssh -t -t -p $PORT $USER@$HOST "$CMD_CENTOS" >$LOGDIR/.$HOST.update.tmp 2>&1; echo -n $?.FINUPDT >>$LOGDIR/.$HOST.update.tmp) &
          ;;
    esac

    ((COUNT++))

done

# Wait for all repositories updates
while [ 1 ]
do
    # Wait 2 seconds
    sleep 2

    JOBS=$(jobs | wc -l)
    DIFF=$((COUNT-JOBS))

    # Delete and print current progress
    tput el1
    tput cub 666
    echo -n "Updating repositories ($DIFF/$COUNT)"

    if [ $JOBS -eq 0 ]
    then
        break
    fi

    jobs >/dev/null

done

echo ""

for SERVER in $(cat $CONF | grep -v "^#")
do
    # Parse each configuration line
    USER=$(echo $SERVER | cut -d ':' -f1)
    HOST=$(echo $SERVER | cut -d ':' -f2)
    PORT=$(echo $SERVER | cut -d ':' -f3)
    OS=$(echo $SERVER | cut -d ':' -f4)

    # Get a list of servers with pending updates
    case $OS in
      "debian")
          UPDATES=$(cat $LOGDIR/.$HOST.update.tmp | grep upgraded | tail -n 1 | cut -d' ' -f1)
          KERN=$(cat $LOGDIR/.$HOST.update.tmp | grep linux | wc -l)
          ;;
      "centos")
          UPDATES=$(cat $LOGDIR/.$HOST.update.tmp | tail -n 1 | cut -d'.' -f1)
          KERN=$(cat $LOGDIR/.$HOST.update.tmp | grep kernel | wc -l)
          ;;
    esac

    if [ "$UPDATES" = "" ]
    then
      # Show a very descriptive error LOL
      >&2 echo -e "\e[1m$HOST: ERROR"
      >&2 echo -e "\e[1m$HOST: \e[21mUnexpected error."
      >&2 echo -e "\e[1m$HOST: \e[21mPlease try again later.\e[0m"
      continue
    fi

    # If there is pending updates, add to the list
    if [ $UPDATES -gt 0 ]
    then
        if [ $KERN -eq 0 ]
        then
            OPTIONS=("${OPTIONS[@]}" $INDEX "$HOST" off)
            HOSTSK=("${HOSTSK[@]}" $HOST)
        else
            OPTIONS=("${OPTIONS[@]}" $INDEX "$HOST (KERNEL)" off)
            HOSTSK=("${HOSTSK[@]}" "$HOST (KERNEL)")
        fi
        USERS=("${USERS[@]}" $USER)
        HOSTS=("${HOSTS[@]}" $HOST)
        PORTS=("${PORTS[@]}" $PORT)
        OSES=("${OSES[@]}" $OS)
        ((INDEX++))
    fi

done

# Exit if there is no pending updates across all servers
if [ $INDEX -eq 1 ]
then
    exit 0
fi

# Print dialog
SELECTION=$(/usr/bin/dialog --separate-output --checklist "Please select which servers you want to update:" 22 76 16"${OPTIONS[@]}" 2>&1 > /dev/tty)

clear
echo "Updating..."

# Launch parallel updates
for SERV in $SELECTION
do
    echo " - ${HOSTS[$SERV]}"

    # Update server
    case ${OSES[$SERV]} in
        "debian") (ssh -p ${PORTS[$SERV]} ${USERS[$SERV]}@${HOSTS[$SERV]} $CMD_DEBIAN_UPDT; echo $?.ENDUP) > $LOGDIR/$DATETIME-${HOSTS[$SERV]}.log 2>&1 &;;
        "centos") (ssh -t -t -p ${PORTS[$SERV]} ${USERS[$SERV]}@${HOSTS[$SERV]} "$CMD_CENTOS_UPDT"; echo $?.ENDUP) > $LOGDIR/$DATETIME-${HOSTS[$SERV]}.log 2>&1 &;;
    esac
done

# Number of lines to delete from screen
CLEAR=0

echo "Processing..."

# Wait for all updates to end up
while [ 1 ]
do
    # Wait 3 seconds
    sleep 3

    FIN=1

    # Clear previous lines from screen
    for (( i = 0 ; i < $CLEAR ; i++ ))
    do
        tput cuu1 # Up 1 line
        tput el   # Delete characters to the end of the line
    done

    # Print updating servers
    UPDATING=$(ps a | grep "sysadmin@" | grep -v grep | cut -d'@' -f2 | cut -d' ' -f1)
    echo "$UPDATING"

    # Save the number of lines to delete
    CLEAR=$(echo "$UPDATING" | wc -l)

    # Check all log files
    for SERV in $SELECTION
    do
        # Determine if current server has done updating
        ENDUP=$(tail $LOGDIR/$DATETIME-${HOSTS[$SERV]}.log 2>/dev/null | grep "ENDUP" | wc -l)
        if [ $ENDUP -eq 0 ]
        then
            FIN=0
            break
        fi
    done

    if [ $FIN -gt 0 ]
    then
        break
    fi
done

# Clear empty line
tput cuu1 # Up 1 line
tput el   # Delete characters to the end of the line

echo "Process completed."

# Verify return codes
ERRORS=0
for SERV in $SELECTION
do
    # Get exit code
    RET=$(grep ".ENDUP" $LOGDIR/$DATETIME-${HOSTS[$SERV]}.log | cut -d'.' -f1)
    if [ $RET -gt 0 ]
    then
        echo "*****" ${HOSTSK[$SERV]} has ended with ERRORS
        ERRORS=1
    else
        echo "*" ${HOSTSK[$SERV]} has completed successfully
    fi
done

if [ $ERRORS -eq 1 ]
then
    echo
    echo "***** WARNING ****"
    echo "At least 1 update has ended with errors"
    echo
fi

echo -n "Press [Enter] to continue..."
read

# Check log files
for LOGFILE in $LOGDIR/$DATETIME*
do
    less $LOGFILE 2>/dev/null
done

