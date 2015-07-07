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

function log() {
    local msg=${1?}
    echo -ne `date +['%Y-%m-%d %H:%M:%S']`" $msg\n"

    if [ -n "$LOG_FILE" ]; then
        echo -ne `date +['%Y-%m-%d %H:%M:%S']`" $msg\n" >> $LOG_FILE
    fi
}


case "$1" in
    start)
        . /etc/profile
        log "run mdm_sandbox.sh"
        log "start docker container mdm-jenkins and mdm-all-in-one"
        docker start mdm-jenkins
        docker start mdm-all-in-one

        log "sleep a while for containers to be up and running"
        sleep 5

        log "start services inside the mdm-jenkins"
        docker exec mdm-jenkins service jenkins start
        docker exec mdm-jenkins service apache2 stop || true
        docker exec mdm-jenkins rm -rf /var/run/apache2/apache2.pid || true
        docker exec mdm-jenkins service apache2 start || true

        # mdm may not be started yet
        log "start services inside the mdm-aio"
        docker exec mdm-all-in-one [ ! -f /opt/mdm/bin/mdm_start_all.sh ] ||  /opt/mdm/bin/mdm_start_all.sh || true
        docker exec mdm-all-in-one service apache2 start || true
        docker exec mdm-all-in-one service nagios3 start || true
        docker exec mdm-all-in-one service nagios-nrpe-server start || true
        log "Finish run mdm_sandbox.sh"
        ;;
    *)
        echo "Usage: $0 {start}" >&2
        exit 1
        ;;
esac
