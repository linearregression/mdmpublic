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

case "$1" in
    start)
        . /etc/profile
        docker start mdm-all-in-one
        docker start mdm-jenkins
        docker exec mdm-jenkins service jenkins start
        docker exec mdm-jenkins service apache2 start
        ;;
    *)
        echo "Usage: $0 {start}" >&2
        exit 1
        ;;
esac
