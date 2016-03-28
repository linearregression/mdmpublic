#!/bin/bash -e
##-------------------------------------------------------------------
## @copyright 2015 DennyZhang.com
## File : docker_destroy.sh
## Author : Denny <denny@dennyzhang.com>
## Description :
## --
## Created : <2016-01-02>
## Updated: Time-stamp: <2016-03-28 16:27:20>
##-------------------------------------------------------------------
function log() {
    local msg=$*
    echo -ne `date +['%Y-%m-%d %H:%M:%S']`" $msg\n"

    if [ -n "$LOG_FILE" ]; then
        echo -ne `date +['%Y-%m-%d %H:%M:%S']`" $msg\n" >> $LOG_FILE
    fi
}

if ! which docker 2>/dev/null 1>/dev/null; then
    log "Skip, since docker is not installed"
else
    if ! sudo service docker status 2>/dev/null 1>/dev/null; then
        log "Start docker daemon"
        sudo service docker start
    fi

    log "Prepare to destroy all docker contianers"
    for container in `sudo docker ps -a | grep -v '^CONTAINER' | awk -F' ' '{print $1}'`; do
        log "docker inspect $container"
        sudo docker inspect $container

        log "Destroy container: $container."
        sudo docker stop $container || true
        sudo docker rm $container || true
    done

    log "shutdown docker daemon"
    sudo service docker stop
fi
## File : docker_destroy.sh ends
