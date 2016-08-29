#!/usr/bin/env bash
# Title      : checkmyfarm.bash
# Description: Check available updates across multiple Debian/CentOS servers using SSH and sudo
# Author     : linuxitux
# Date       : 29-08-2016
# Usage      : ./checkmyfarm.bash
# Notes      : Read the documentation first
#0 2 * * * /home/sysadmin/updatemyfarm/checkmyfarm.bash

# Configuration files
CONF="updatemyfarm.conf"
LOGDIR="log"

# Get time and date
DATETIME=$(date +%Y-%m-%d_%H-%M-%S)
DATE=$(date +"%d/%m/%Y")
LOGFILE="$LOGDIR/updates-$DATETIME.log"

# Mail settings
MAILFROM="Sysadmin @ Linuxito <sysadmin@linuxito.com>"
MAILTO="emiliano@linuxito.com"
SUBJECT="Available updates ($DATE)"

# 'mail' params may vary on different systems
MAILCMD="mail -s "$SUBJECT" -aFrom:"$MAILFROM" $MAILTO"

# Commands to check for updates
CMD_DEBIAN="sudo apt-get update >/dev/null; LANG=C sudo apt-get -s upgrade 2>/dev/null"
CMD_CENTOS="LANG=C sudo yum check-update"

# Commands to get OS version
V_DEBIAN="lsb_release -a 2>/dev/null | grep Desc | cut -d':' -f2 | xargs"
V_CENTOS="cat /etc/redhat-release"

# Information about target servers
USERS="users"
HOSTS="hosts"
PORTS="ports"
OSES="oses"

AVAILABLE=0

# CONF - username:host:port:os
for SERVER in $(cat $CONF | grep -v "^#")
do
    # Parse configuration line
    USER=$(echo $SERVER | cut -d ':' -f1)
    HOST=$(echo $SERVER | cut -d ':' -f2)
    PORT=$(echo $SERVER | cut -d ':' -f3)
    OS=$(echo $SERVER | cut -d ':' -f4)

    # Check for updates
    case $OS in
      "debian")
          UPDATES=$(ssh -p $PORT $USER@$HOST $CMD_DEBIAN | grep -v '\.\.\.' | grep -v ':' )
          VERSION=$(ssh -p $PORT $USER@$HOST $V_DEBIAN)
          COUNT=$(echo "$UPDATES" | grep "upgraded" | cut -d ' ' -f 1)
          UPDATES=$(echo "$UPDATES" | grep -v upgraded)
          if [ $COUNT -gt 0 ] ; then
              ((AVAILABLE++))
              echo "$HOST - $VERSION:" >> $LOGFILE
              echo "" >> $LOGFILE
              echo "$UPDATES" >> $LOGFILE
              echo >> $LOGFILE
              echo >> $LOGFILE
          fi
          ;;
      "centos")     
          UPDATES=$(ssh -t -t -p $PORT $USER@$HOST "$CMD_CENTOS" 2>/dev/null; echo $?.ENDUPDT)
          VERSION=$(ssh -t -t -p $PORT $USER@$HOST "$V_CENTOS" 2>/dev/null)
          COUNT=$(echo "$UPDATES" | grep ENDUPDT | cut -d '.' -f 1)
          if [ $COUNT -gt 0 ] ; then
              ((AVAILABLE++))
              echo "$HOST - $VERSION:" >> $LOGFILE
              echo "$UPDATES" | grep -v ENDUPDT | grep -v 'Loaded plugins' | grep -v 'Loading mirror' | grep -v '*' | grep -v -e '^$' >> $LOGFILE
              echo >> $LOGFILE
              echo >> $LOGFILE
          fi
          ;;
    esac

done

if [ $AVAILABLE -gt 0 ] ; then
    cat $LOGFILE | $MAILCMD
fi
