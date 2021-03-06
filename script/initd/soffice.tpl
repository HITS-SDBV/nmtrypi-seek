#!/bin/bash
# originally from: http://code.google.com/p/openmeetings/wiki/OpenOfficeConverter
# openoffice.org  headless server script
#
# description: headless openoffice server script
# processname: openoffice
#
# Author: Vic Vijayakumar
# Modified by Federico Ch. Tomasczik
# Modified by Stuart Owen
#
OOo_HOME=/usr/bin
SOFFICE_PATH=$OOo_HOME/soffice

set -e

start_soffice(){
      echo "Starting OpenOffice headless server"
      sudo -H -u {{ www_user }} $SOFFICE_PATH --headless --nologo --nofirststartwizard --accept="socket,host=127.0.0.1,port=8100;urp" & > /dev/null 2>&1
}

stop_soffice(){
      echo "Stopping OpenOffice headless server."
      killall -9 soffice.bin
}

COMMAND="$1"
shift

case $COMMAND in
status)
    ;;
start|stop|restart)
    $ECHO
    if [ "$COMMAND" = "stop" ]; then
        stop_soffice
    elif [ "$COMMAND" = "start" ]; then
        start_soffice
    elif  [ "$COMMAND" = "restart" ]; then
        stop_soffice
        sleep 1s
        start_soffice
        exit 0
    fi
    ;;
esac

exit 0
