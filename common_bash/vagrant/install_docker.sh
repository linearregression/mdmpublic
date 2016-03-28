#!/bin/bash -e
##-------------------------------------------------------------------
## @copyright 2015 DennyZhang.com
## File : install_docker.sh
## Author : Denny <denny@dennyzhang.com>
## Description :
## --
## Created : <2015-05-28>
## Updated: Time-stamp: <2016-03-28 16:27:14>
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

function os_release() {
    set -e
    distributor_id=$(lsb_release -a 2>/dev/null | grep 'Distributor ID' | awk -F":\t" '{print $2}')
    if [ "$distributor_id" == "RedHatEnterpriseServer" ]; then
        echo "redhat"
    elif [ "$distributor_id" == "Ubuntu" ]; then
        echo "ubuntu"
    else
        if grep CentOS /etc/issue 1>/dev/null 2>/dev/null; then
            echo "centos"
        else
            if uname -a | grep '^Darwin' 1>/dev/null 2>/dev/null; then
                echo "osx"
            else
                echo "ERROR: Not supported OS"
            fi
        fi
    fi
}
################################################################################################
function update_system() {
    local os_release_name=$(os_release)
    if [ "$os_release_name" == "ubuntu" ]; then
        log "apt-get -y update"
        rm -rf /var/lib/apt/lists/*
        apt-get -y update
        apt-get install -y bc
    fi

    if [ "$os_release_name" == "redhat" ] || [ "$os_release_name" == "centos" ]; then
        yum -y update
        yum install -y bc
    fi
}

function install_docker() {
    if ! which docker 1>/dev/null 2>/dev/null; then
        local os_release_name=$(os_release)
        if [ "$os_release_name" == "centos" ]; then
            log "yum install -y docker-io"
            yum install -y http://mirrors.yun-idc.com/epel/6/i386/epel-release-6-8.noarch.rpm
            yum install -y docker-io
            service docker start
            chkconfig docker on
        else
            log "Install docker: wget -qO- https://get.docker.com/ | sh"
            wget -qO- https://get.docker.com/ | sh
        fi
    else
        log "docker service exists, skip installation"
    fi
}

function create_enough_loop_device() {
    # Docker start may fail, due to no available loopback devices
    for i in {0..500}
    do
        if [ ! -b /dev/loop$i ]; then
            mknod -m0660 /dev/loop$i b 7 $i
        fi
    done
}

function shell_exit() {
    exit_code=$?
    END=$(date +%s)
    DIFF=$(echo "$END - $START" | bc)
    log "Track time spent: $DIFF seconds"
    if [ $exit_code -eq 0 ]; then
        log "All set. Let's try Jenkins now: http://192.168.50.10:28080"
    else
        log "ERROR: the procedure failed"
    fi
    exit $exit_code
}

################################################################################################
START=$(date +%s)
ensure_is_root

update_system

trap shell_exit SIGHUP SIGINT SIGTERM 0

# set PATH, just in case binary like chmod can't be found
PATH=$PATH:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

log "Install docker"
install_docker

create_enough_loop_device

if ! service docker status 1>/dev/null 2>/dev/null; then
    service docker start
fi

## File : install_docker.sh ends
