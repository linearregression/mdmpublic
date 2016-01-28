#!/bin/bash -e
## @copyright 2015 DennyZhang.com
### BEGIN INIT INFO
# Provides: docker_sandbox
# Required-Start:
# Required-Stop:
# Default-Start: 2 3 4 5
# Default-Stop: 0 1 6
# Short-Description:
# Description:
### END INIT INFO

LOG_FILE="/var/log/docker_sandbox.log"

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
        
        log "run docker_sandbox.sh"
        if ! service docker status | grep running;then
            # start docker
            log "start docker:"
            service docker start
        fi
        
        log "start docker container docker-jenkins and docker-all-in-one"
        docker start docker-jenkins
        docker start docker-all-in-one

        log "sleep a while for containers to be up and running"
        sleep 5

        log "start services inside the docker-jenkins"
        docker exec docker-jenkins service jenkins start
        docker exec docker-jenkins service apache2 start

        log "start services inside the docker-all-in-one"
        # TODO: add more start scripts
        log "Finish run docker_sandbox.sh"
        ;;
    *)
        echo "Usage: $0 {start}" >&2
        exit 1
        ;;
esac
