#!/bin/bash -e
##-------------------------------------------------------------------
## File : bootstrap_mdm_sandbox.sh
## Author : Denny <denny.zhang@totvs.com>
## Description :
## --
## Created : <2015-05-28>
## Updated: Time-stamp: <2015-05-28 13:43:24>
##-------------------------------------------------------------------
function log() {
    local msg=${1?}
    echo -ne `date +['%Y-%m-%d %H:%M:%S']`" $msg\n"
    
    if [ -n "$LOG_FILE" ]; then
        echo -ne `date +['%Y-%m-%d %H:%M:%S']`" $msg\n" >> $LOG_FILE
    fi
}

function ensure_is_root() {
    # Make sure only root can run our script
    if [[ $EUID -ne 0 ]]; then
        echo "Error: This script must be run as root." 1>&2
        exit 1
    fi
}

function install_docker() {
    if ! which docker 1>/dev/null 2>/dev/null; then
        log "Install docker: $command"
        command="wget -qO- https://get.docker.com/ | sh"
        eval $command
    else
        log "docker exists, skip installation"
    fi
}

################################################################################################
ensure_is_root

install_docker

# TODO: make docker is start
# TODO: Docker start may fail, due to "There are no more loopback devices available."
command="docker pull totvslabs/mdm:latest"
log "run $command"
output=$(eval $command)
if ! echo "$output" | grep "Status: Image is up to date"; then
    log "docker stop"
    docker stop
fi

log "prepare docker directory for couchbase"
rm -rf /root/tmp/couchbase && mkdir -p /root/tmp/couchbase

# log "docker start"
# docker run -d -t --privileged --name mdm-jenkins -p 5022:22 -p 18000:18000 -p 18080:18080 totvslabs/mdm:latest /usr/sbin/sshd -D
# docker run -d -t --privileged -v /root/tmp/couchbase/:/opt/couchbase/ --name mdm-all-in-one -p 8443:8443 -p 8091:8091 -p 9200:9200 -p 80:80 -p 6022:22 totvslabs/mdm:latest /usr/sbin/sshd -D

# # TODO: when docker start, make sure jenkins autostart
# # Login to docker container need password
# ssh -p 5022 root@127.0.0.1 service jenkins start

## File : bootstrap_mdm_sandbox.sh ends
