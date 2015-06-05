#!/bin/bash -e
##-------------------------------------------------------------------
## File : bootstrap_mdm_sandbox.sh
## Author : Denny <denny.zhang@totvs.com>
## Description :
## --
## Created : <2015-05-28>
## Updated: Time-stamp: <2015-06-04 21:07:42>
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
    local image_repo_name=${1?}    
    local image_name=${2?}
    local flag_file=${3?}
    command="docker pull $image_name"

    old_image_id=""
    if docker images | grep $image_repo_name; then
        old_image_id=$(docker images | grep $image_repo_name | awk -F' ' '{print $3}')
    fi

    log "docker pull $image_name, this steps may take tens of minutes."
    docker pull $image_name

    new_image_id=$(docker images | grep $image_repo_name | awk -F' ' '{print $3}')

    if [ "$old_image_id" = "$new_image_id" ]; then
        echo "no" > $flag_file
    else
        echo "yes" > $flag_file
    fi
}

function is_container_running(){
    local container_name=${1?}
    if docker ps -a | grep $container_name 1>/dev/null 2>/dev/null; then
        if docker ps | grep $container_name  1>/dev/null 2>/dev/null; then
            echo "running"
        else
            echo "dead"
        fi
    else
        echo "none"
    fi
}

################################################################################################
ensure_is_root

log "Install autostart script for /etc/init.d/mdm_sandbox"
curl -o /etc/init.d/mdm_sandbox https://raw.githubusercontent.com/TOTVS/mdmpublic/master/test/mdm_sandbox.sh
chmod 755 /etc/init.d/mdm_sandbox
update-rc.d mdm_sandbox defaults
update-rc.d mdm_sandbox enable

log "Install docker"
install_docker

create_enough_loop_device

if ! service docker status 1>/dev/null 2>/dev/null; then
    service docker start
fi

log "prepare shared directory for docker"
rm -rf /root/docker/couchbase && mkdir -p /root/docker/couchbase
if [ -d /root/docker/code ]; then
    rm -rf /root/docker/code/*
else
    mkdir -p /root/docker/code/
fi

chmod 777 -R /root/docker/code

log "Start docker of mdm-jenkins"
image_repo_name="totvslabs/mdm"
image_name="${image_repo_name}:latest"
flag_file="image.txt"

docker_pull_image $image_repo_name $image_name $flag_file
image_has_new_version=`cat $flag_file`

container_name="mdm-jenkins"
container_status=$(is_container_running $container_name)
if [ $container_status = "running" ] && [ "$image_has_new_version" = "yes" ]; then
    log "$image_name has new version, stop old running container: $container_name"
    docker stop $container_name
    docker rm $container_name
    container_status=$(is_container_running $container_name)
fi

if [ $container_status = "none" ]; then
    docker run -d -t --privileged -v /root/docker/code/:/var/lib/jenkins/code/ --name $container_name -p 5022:22 -p 18000:18000 -p 18080:18080 totvslabs/mdm:latest /usr/sbin/sshd -D
elif [ $container_status = "dead" ]; then 
    docker start $container_name    
fi

# when docker start, make sure jenkins autostart
docker exec $container_name service jenkins start
docker exec $container_name service apache2 start

log "Start docker of mdm-all-in-one"
container_name="mdm-all-in-one"
container_status=$(is_container_running $container_name)
if [ $container_status = "running" ] && [ "$image_has_new_version" = "yes" ]; then
    log "$image_name has new version, stop old running container: $container_name"
    docker stop $container_name
    docker rm $container_name
    container_status=$(is_container_running $container_name)
fi

if [ $container_status = "none" ]; then
    docker run -d -t --privileged -v /root/docker/couchbase/:/opt/couchbase/ --name $container_name -p 8080:8080 -p 8443:8443 -p 8091:8091 -p 9200:9200 -p 80:80 -p 8081:8081 -p 6022:22 totvslabs/mdm:latest /usr/sbin/sshd -D
elif [ $container_status = "dead" ]; then 
    docker start $container_name    
fi

log "Check docker containers: docker ps" 
docker ps

log "All set. Let's try Jenkins now: http://sandbox:18080"
## File : bootstrap_mdm_sandbox.sh ends
