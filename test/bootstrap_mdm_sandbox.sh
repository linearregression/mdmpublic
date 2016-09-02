#!/bin/bash -e
##-------------------------------------------------------------------
## File : bootstrap_mdm_sandbox.sh
## Author : Denny <denny.zhang@totvs.com>
## Description :
## --
## Created : <2015-05-28>
## Updated: Time-stamp: <2016-09-02 11:36:03>
##-------------------------------------------------------------------
function log() {
    # log message to both stdout and logfile on condition
    local msg=$*
    date_timestamp=$(date +['%Y-%m-%d %H:%M:%S'])
    echo -ne "$date_timestamp $msg\n"

    if [ -n "$LOG_FILE" ]; then
        echo -ne "$date_timestamp $msg\n" >> "$LOG_FILE"
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
function update_docker_daemon() {
    local docker_opts=${1?}
    # TODO: don't overwrite existing customization of docker opts
    if ! grep -e "$docker_opts" /etc/default/docker; then
        echo "Update docker daemon opts: $docker_opts, then restart docker"
        echo "DOCKER_OPTS=\"$docker_opts\"" >> /etc/default/docker
        service docker stop || true
        service docker start
    fi
}

function install_docker() {
    if ! which docker 1>/dev/null 2>/dev/null; then
        log "Install docker: wget -qO- https://get.docker.com/ | sh"
        wget -qO- https://get.docker.com/ | sh
        # install docker 1.11.2
        apt-get install -y --force-yes docker-engine=1.12.1-0~trusty
        # prevent upgrade on sys upgrade
        apt-mark hold docker-engine
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

function start_docker() {
    local docker_opts=${1?}
    create_enough_loop_device
    update_docker_daemon "$docker_opts"
    if ! service docker status 1>/dev/null 2>/dev/null; then
        service docker start
    fi
}

function docker_login() {
    local docker_username=${1?}
    local docker_passwd=${2?}
    local docker_email="denny.zhang@totvs.com"
    echo "docker login with $docker_username"
    docker login -u "$docker_username" -p "$docker_passwd" -e "$docker_email"
}

function docker_pull_image() {
    local image_repo_name=${1?}
    local image_name=${2?}
    local flag_file=${3?}

    old_image_id=""
    if docker images | grep "$image_repo_name"; then
        old_image_id=$(docker images | grep "$image_repo_name" | awk -F' ' '{print $3}')
    fi

    log "docker pull $image_name, this steps may take tens of minutes."
    set +e
    docker pull "$image_name"
    if [ $? -eq 0 ]; then
        log "Retry: docker pull $image_name, in case doggy internet issue."
        docker pull "$image_name"
    fi
    set -e

    new_image_id=$(docker images | grep "$image_repo_name" | awk -F' ' '{print $3}')

    if [ "$old_image_id" = "$new_image_id" ]; then
        echo "no" > "$flag_file"
    else
        echo "yes" > "$flag_file"
    fi
}

function is_container_running(){
    local container_name=${1?}
    if docker ps -a | grep "$container_name" 1>/dev/null 2>/dev/null; then
        if docker ps | grep "$container_name"  1>/dev/null 2>/dev/null; then
            echo "running"
        else
            echo "dead"
        fi
    else
        echo "none"
    fi
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
function start_jenkins_contianer() {
    mkdir -p /root/docker/
    chmod 777 -R /root/docker/
    log "cleanup for /root/docker"
    for d in /root/docker/*; do
        if [ -d "$d" ]; then
            rm -rf "$d"/*
        fi
    done

    log "Start docker of mdm-jenkins"
    container_name="mdm-jenkins"
    container_hostname="jenkins"
    container_status=$(is_container_running $container_name)
    if [ "$container_status" = "running" ] && [ "$image_has_new_version" = "yes" ]; then
        log "$image_name has new version, stop old running container: $container_name"
        docker stop "$container_name"
        docker rm "$container_name"
        container_status="none"
    fi

    if [ $container_status = "none" ]; then
        docker run -d -t --privileged -v /root/docker/:/var/lib/jenkins/code/ -h "$container_hostname" --name "$container_name" -p 5022:22 -p 18000:18000 -p 18080:18080 "$image_name" /usr/sbin/sshd -D
    elif [ $container_status = "dead" ]; then
        docker start $container_name
    fi
}

function start_mdmaio_contianer() {
    log "prepare shared directory for docker"
    rm -rf /root/couchbase/* && mkdir -p /root/couchbase
    log "Start docker of mdm-all-in-one"
    container_name="mdm-all-in-one"
    container_hostname="aio"
    container_status=$(is_container_running $container_name)
    if [ "$container_status" = "running" ] && [ "$image_has_new_version" = "yes" ]; then
        log "$image_name has new version, stop old running container: $container_name"
        docker stop $container_name
        docker rm $container_name
        container_status="none"
    fi

    if [ $container_status = "none" ]; then
        docker run -d -t --privileged -v /root/couchbase/:/opt/couchbase/ -h "$container_hostname" --name "$container_name" -p 8080-8180:8080-8180 -p 8443:8443 -p 9200:9200 -p 9300:9300 -p 9400:9400 -p 9500:9500 -p 80:80 -p 443:443 -p 6022:22 "$image_name" /usr/sbin/sshd -D
    elif [ $container_status = "dead" ]; then
        docker start $container_name
    fi
}

function service_autostart() {
    log "Install autostart script for /etc/init.d/mdm_sandbox"

    curl -o /etc/init.d/mdm_sandbox "${DOWNLOAD_PREFIX}/test/mdm_sandbox.sh"
    chmod 755 /etc/init.d/mdm_sandbox
    update-rc.d mdm_sandbox defaults
    update-rc.d mdm_sandbox enable
}
################################################################################################
trap shell_exit SIGHUP SIGINT SIGTERM 0

image_repo_name=${1?"docker image repo name"}
tag_name=${2:-"latest"}
docker_username=${3:-""}
docker_passwd=${4:-""}
docker_opts=${5:-"--iptables=false --dns 8.8.8.8 --dns 8.8.4.4"}
image_name="${image_repo_name}:$tag_name"
flag_file="image.txt"

[ -n "$DOWNLOAD_PREFIX" ] || export DOWNLOAD_PREFIX="https://raw.githubusercontent.com/TOTVS/mdmpublic/master"

START=$(date +%s)
ensure_is_root

apt-get -y install bc
# set PATH, just in case binary like chmod can't be found
PATH=$PATH:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
LOG_FILE="/var/log/bootstrap_mdm_sandbox.log"

# download ufw setup tool
curl -o /root/enable_ufw.sh "${DOWNLOAD_PREFIX}/bash/enable_ufw/enable_ufw.sh"

log "Install docker"
install_docker
start_docker "$docker_opts"

if [ -n "$docker_username" ]; then
    docker_login "$docker_username" "$docker_passwd"
fi

# Update docker image
if [ -n "$SKIP_DOCKER_PULL" ]; then
    image_has_new_version="no"
else
    log "pull docker image: $image_name"
    docker_pull_image "$image_repo_name" "$image_name" "$flag_file"
    image_has_new_version=$(cat "$flag_file")
fi

start_jenkins_contianer
start_mdmaio_contianer

log "Start services inside docker"
service_autostart
service mdm_sandbox start

log "Check docker containers: docker ps"
docker ps
## File : bootstrap_mdm_sandbox.sh ends
