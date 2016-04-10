#!/bin/bash -e
##-------------------------------------------------------------------
## @copyright 2015 DennyZhang.com
## File : docker_destroy.sh
## Author : DennyZhang.com <denny@dennyzhang.com>
## Description :
## --
## Created : <2016-01-02>
## Updated: Time-stamp: <2016-04-10 12:18:18>
##-------------------------------------------------------------------
################################################################################################
if [ ! -f /var/lib/enable_common_library.sh ]; then
    wget -O /var/lib/enable_common_library.sh \
         https://raw.githubusercontent.com/DennyZhang/devops_public/master/common_library/enable_common_library.sh
fi
# export AVOID_REFRESH_LIBRARY=true
bash /var/lib/enable_common_library.sh "1512381967"
################################################################################################
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
