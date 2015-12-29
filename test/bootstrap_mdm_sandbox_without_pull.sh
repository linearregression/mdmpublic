#!/bin/bash -e
##-------------------------------------------------------------------
## File : bootstrap_mdm_sandbox_without_pull.sh
## Author : Denny <denny.zhang@totvs.com>
## Description :
## --
## Created : <2015-05-28>
## Updated: Time-stamp: <2015-12-29 16:22:23>
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
        log "Install docker: wget -qO- https://get.docker.com/ | sh"
        wget -qO- https://get.docker.com/ | sh
    else
        log "docker service exists, skip installation"
    fi
}

function create_enough_loop_device() {
    # Docker start may fail, due to "There are no more loopback devices available."
    for i in {0..500}
    do
        if [ ! -b /dev/loop$i ]; then
            mknod -m0660 /dev/loop$i b 7 $i
        fi
    done
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

function remove_vagrant_user_from_root() {
    [ ! -f /etc/sudoers.d/vagrant ] || rm -rf /etc/sudoers.d/vagrant
    mkdir -p /root/.ssh/
    echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDBFs/3IWqXacrS+uq2bshz5CROPvIoZTFtxArD17Vvl3RNd6IQR513GAULriF4JrXPNqy+D4B6SCGVCAsyl29zHspyFBSmBtP45Rp7oS1jX0FaS3hP1kFAgcUfmcVKTSaDmEe5YSLY0OTrRpHDKPigXGpHOxeJi8fY6X+wnIPqS1taORJu0qoQ0jisZtiw1Hl6GgpcJXjuWs2/uiOE8ieY1uvYGAtHnyrxWabYJriZESQObRQYvixaTeOzL6RxROgl1yo69G6M/qxr0lcyfGJAuOzrZLBa6TDuTM3vTmoJPQA4gHdJoOlrsFUKDf5HEsgjd8i/C3JRRpNn/ut+HLXT ssh.login@totvs.com" >> /root/.ssh/authorized_keys
}

function shell_exit() {
    exit_code=$?
    END=$(date +%s)
    DIFF=$(echo "$END - $START" | bc)
    log "Track time spent: $DIFF seconds"
    if [ $exit_code -eq 0 ]; then
        log "All set. Let's try Jenkins now: http://YOUR_SERVER_IP:18080"
    else
        log "ERROR: the procedure failed"
    fi
    exit $exit_code
}

################################################################################################
START=$(date +%s)
ensure_is_root

apt-get -y install bc

trap shell_exit SIGHUP SIGINT SIGTERM 0

# set PATH, just in case binary like chmod can't be found
PATH=$PATH:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

log "Install docker"
install_docker

create_enough_loop_device

if ! service docker status 1>/dev/null 2>/dev/null; then
    service docker start
fi

log "prepare shared directory for docker"
rm -rf /root/couchbase/* && mkdir -p /root/couchbase
mkdir -p /root/docker/

remove_vagrant_user_from_root

log "Install autostart script for /etc/init.d/mdm_sandbox"
curl -o /etc/init.d/mdm_sandbox https://raw.githubusercontent.com/TOTVS/mdmpublic/master/test/mdm_sandbox.sh
chmod 755 /etc/init.d/mdm_sandbox
update-rc.d mdm_sandbox defaults
update-rc.d mdm_sandbox enable

log "Start docker of mdm-jenkins"
image_repo_name=${1?"docker image repo name"}
tag_name=${2:-"latest"}
image_name="${image_repo_name}:$tag_name"
flag_file="image.txt"

image_has_new_version="no"

container_name="mdm-jenkins"
container_hostname="jenkins"
container_status=$(is_container_running $container_name)
if [ $container_status = "running" ] && [ "$image_has_new_version" = "yes" ]; then
    log "$image_name has new version, stop old running container: $container_name"
    docker stop $container_name
    docker rm $container_name
    container_status="none"
fi

if [ $container_status = "none" ]; then
    docker run -d -t --privileged -v /root/docker/:/var/lib/jenkins/code/ -h $container_hostname --name $container_name -p 5022:22 -p 18000:18000 -p 18080:18080 $image_name /usr/sbin/sshd -D
elif [ $container_status = "dead" ]; then 
    docker start $container_name    
fi

log "Start docker of mdm-all-in-one"
container_name="mdm-all-in-one"
container_hostname="aio"
container_status=$(is_container_running $container_name)
if [ $container_status = "running" ] && [ "$image_has_new_version" = "yes" ]; then
    log "$image_name has new version, stop old running container: $container_name"
    docker stop $container_name
    docker rm $container_name
    container_status="none"
fi

if [ $container_status = "none" ]; then
    docker run -d -t --privileged -v /root/couchbase/:/opt/couchbase/ -h $container_hostname --name $container_name -p 8080-8092:8080-8092 -p 8443:8443 -p 9200:9200 -p 80:80 -p 443:443 -p 6022:22 $image_name /usr/sbin/sshd -D
elif [ $container_status = "dead" ]; then 
    docker start $container_name    
fi

log "Start services inside docker"
service mdm_sandbox start

for d in `ls -d /root/docker/*`; do
    rm -rf $d/*
done

chmod 777 -R /root/docker/

log "Check docker containers: docker ps" 
docker ps

## File : bootstrap_mdm_sandbox_without_pull.sh ends
