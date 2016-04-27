#!/bin/bash -e
################################################################################################
## @copyright 2016 DennyZhang.com
## Licensed under MIT
##   https://raw.githubusercontent.com/DennyZhang/devops_public/master/LICENSE
##
# * Author        : doungni
# * Email         : doungni@doungni.com
# * Last modified : 2016-01-04 16:21
# * Filename      : stop_black_containers.sh
# * Description   :
################################################################################################

################################################################################################
# * By Jenkins config
#       docker_ip_port: Docker daemon server ip:port
#       regular_black_list: Regular expressions are supported
# * By define parameter
#       ssh_identity_file ssh_connet black_list running_contianer_names
#       black_containers_list count_v container_name
################################################################################################

# TODO: Need to reduce code duplication in between stop_old_containers.sh and stop_black_containers.sh
############################## Function Start ##################################################
################################################################################################
if [ ! -f /var/lib/devops/refresh_common_library.sh ]; then
    [ -d /var/lib/devops/ ] || (sudo mkdir -p  /var/lib/devops/ && sudo chmod 777 /var/lib/devops)
    wget -O /var/lib/devops/refresh_common_library.sh \
         https://raw.githubusercontent.com/DennyZhang/devops_public/master/common_library/refresh_common_library.sh
fi
# export AVOID_REFRESH_LIBRARY=true
bash /var/lib/devops/refresh_common_library.sh "2993535181"
. /var/lib/devops/devops_common_library.sh
################################################################################################
# Docker client version gather than 1.9.1
function stop_black_containers() {
    # Save running container names
    running_container_names=($($ssh_connect docker ps | awk '{print $NF}' | sed '1d'))
    log "Docker daemon: $daemon_ip:$daemon_port current running container list[${#running_container_names[@]}]:\n${running_container_names[*]}"

    # Count variable
    local count_v=0
    # Continue to traverse the currently running container on the server
    for container_name in "${running_container_names[@]}"
    do
        for black_name in "${black_list[@]}"
        do
            # Find the container in the white list and mark it as 1
            if [ "$container_name" = "$black_name" ]; then
                log "Container: [$container_name] in the black list, Will be stopped"
                $ssh_connect docker stop "$container_name"

                # Store is not white list and the need to stop the container
                stop_black_containers[count_v]=$container_name
                count_v=$((count_v+1))
                break
            fi
        done
    done
}

# main entry function
function main_entry() {
    for ip_port in "${docker_ip_port[@]}"
    do
        daemon_ip_port=(${ip_port//:/ })
        daemon_ip=${daemon_ip_port[0]}
        daemon_port=${daemon_ip_port[1]}

        # SSH connect parameter
        ssh_connect="ssh -p $daemon_port -i $ssh_identity_file -o StrictHostKeyChecking=no root@$daemon_ip"

        nc_return=$(nc -w 1 "$daemon_ip" "$daemon_port" >/dev/null 2>&1 && echo yes || echo no)
        if [ "x$nc_return" == "xno" ]; then
            log "Can not connect docker daemon server $daemon_ip:$daemon_port"
            continue
        fi

        # Get black list
        if [ ${#regular_black_list[@]} -gt 0 ]; then
            for regular in "${regular_black_list[@]}"
            do
                regular_list=($($ssh_connect docker ps | awk '{print $NF}' | sed '1d' | grep -e "^$regular"))||true
                black_list+=("${regular_list[@]}")
            done

            log "Docker daemon $daemon_ip:$daemon_port black list[${#black_list[@]}]:\n${black_list[*]}"
        fi

        # Judge black list
        if [ ${#black_list[@]} -le 0 ] || [ -z "$black_list" ]; then
            log "Docker daemon server[$daemon_ip:$daemon_port]: the black list of the container is empty"
            continue
        fi

        # Call stop expired container function
        stop_black_containers

        log "Docker daemon server: $daemon_ip:$daemon_port operation is completed!"
        black_containers_list+=("\n${daemon_ip}:${daemon_port} stop container list:\n${stop_black_containers[@]}")

        # Empty current ip:port white list
        unset black_list[@]
    done

    if [ ${#black_containers_list[@]} -gt 0 ]; then
        log "${black_containers_list[@]}"
        exit 1
    else
        log "Has not stopped any container or has been stopped"
    fi
}

############################## Function End ####################################################

############################## Shell Start #####################################################

ssh_identity_file="/var/lib/jenkins/.ssh/id_rsa"

# Jenkins parameter judge
if [ -z "$docker_ip_port" ]; then
    log "$docker_ip_port can not find"
    exit 1
fi
docker_ip_port=(${docker_ip_port// / })

if [ -n "$regular_black_list" ]; then
    regular_black_list=(${regular_black_list// / })
else
    log "Regular white list is empty, will stop over than $keep_days all containers"
fi

# Call main entry function
main_entry
############################## Shell End #######################################################
