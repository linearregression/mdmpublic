#!/bin/bash -e
##-------------------------------------------------------------------
## File : bootstrap_mdm_sandbox.sh
## Author : Denny <denny.zhang@totvs.com>
## Description :
## --
## Created : <2015-05-28>
## Updated: Time-stamp: <2015-05-31 10:40:38>
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

################################################################################################
function install_docker() {
    if ! which docker 1>/dev/null 2>/dev/null; then
        log "Install docker: $command"
        command="wget -qO- https://get.docker.com/ | sh"
        eval $command
    else
        log "docker service exists, skip installation"
    fi
}

function create_enough_loop_device() {
    # Docker start may fail, due to "There are no more loopback devices available."
    for i in {0..20}
    do
        if [ ! -b /dev/loop$i ]; then
            mknod -m0660 /dev/loop$i b 7 $i
        fi
    done
}

function docker_pull_image() {
    local image_name=${1?}
    command="docker pull $image_name"

    output=$(eval $command)
    if echo "$output" | grep "Status: Image is up to date" 1>/dev/null 2>/dev/null; then
        echo "no"
    else
        echo "yes"
    fi
}

function is_container_running(){
    local container_name=${1?}
    if docker inspect $container_name 1>/dev/null 2>/dev/null; then
        if docker ps | grep $container_name  1>/dev/null 2>/dev/null; then
            echo "running"
        else
            echo "dead"
        fi
    else
        echo "none"
    fi
}

function docker_update_image() {
    local image_name=${1?}
    local container_name=${2?}

    log "docker pull $image_name. This steps may take tens of minutes"
    has_new_version=$(docker_pull_image $image_name)
    if [ "$has_new_version" = "yes" ]; then
        if [ $(is_container_running $container_name) = "running" ]; then
            log "Stop container($container_name), since image($image_name) has a new version"
            docker stop $container_name
        fi
    else
        log "image($image_name) has no newer version"
    fi
}
################################################################################################
ensure_is_root

log "Install autostart script for /etc/init.d/mdm_sandbox"
curl -o /etc/init.d/mdm_sandbox https://raw.githubusercontent.com/TOTVS/mdmpublic/master/test/mdm_sandbox.sh
update-rc.d mdm_sandbox defaults
update-rc.d mdm_sandbox enable

log "Install docker"
install_docker

create_enough_loop_device

if ! service docker status 1>/dev/null 2>/dev/null; then
    service docker start
fi

log "prepare docker directory for couchbase"
rm -rf /root/docker/couchbase && mkdir -p /root/docker/couchbase
rm -rf /root/docker/code && mkdir -p /root/docker/code

# Start docker of mdm-jenkins
image_name="totvslabs/mdm:latest"
container_name="mdm-jenkins"
docker_update_image $image_name $container_name
container_status=$(is_container_running $container_name)
if [ $container_status == "none" ]; then
    docker run -d -t --privileged -v /root/ --name $container_name -p 5022:22 -p 18000:18000 -p 18080:18080 totvslabs/mdm:latest /usr/sbin/sshd -D
elif [ $container_status == "dead" ]; then 
    docker start $container_name    
fi

# when docker start, make sure jenkins autostart
docker exec $container_name service jenkins start
docker exec $container_name service apache2 start

# Start docker of mdm-all-in-one
image_name="totvslabs/mdm:latest"
container_name="mdm-all-in-one"
docker_update_image $image_name $container_name
container_status=$(is_container_running $container_name)
if [ $container_status == "none" ]; then
    docker run -d -t --privileged -v /root/docker/couchbase/:/opt/couchbase/ --name $container_name -p 8080:8080 -p 8443:8443 -p 8091:8091 -p 9200:9200 -p 80:80 -p 8081:8081 -p 6022:22 totvslabs/mdm:latest /usr/sbin/sshd -D
elif [ $container_status == "dead" ]; then 
    docker start $container_name    
fi

log "Check docker containers: docker ps" 
docker ps

log "All set. Let's try Jenkins now: http://sandbox:18080"
## File : bootstrap_mdm_sandbox.sh ends
