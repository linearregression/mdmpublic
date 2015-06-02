#!/bin/bash -e
### BEGIN INIT INFO
# Provides: mdm_sandbox
# Required-Start:
# Required-Stop:
# Default-Start: 2 3 4 5
# Default-Stop: 0 1 6
# Short-Description:
# Description:
### END INIT INFO

LOG_FILE="/var/log/mdm_sandbox.log"

case "$1" in
    start)
        . /etc/profile
        echo -ne `date +['%Y-%m-%d %H:%M:%S']`" run mdm_sandbox.sh\n" >> $LOG_FILE
        docker start mdm-jenkins
        docker start mdm-all-in-one
        docker exec mdm-all-in-one /opt/mdm/bin/mdm_start_all.sh

        docker exec mdm-jenkins service jenkins start
        docker exec mdm-jenkins service apache2 start
        ;;
    *)
        echo "Usage: $0 {start}" >&2
        exit 1
        ;;
esac
