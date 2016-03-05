#!/bin/bash -xe
################################################################################################
## @copyright 2015 DennyZhang.com
## File : collect_files.sh
## Author : doungni<doungni@doungni.com>, Denny <denny.zhang001@gmail.com>
## Description : collect the files across servers, and transfer to specific destination
## --
## Created : <2016-01-25>
## Updated: Time-stamp: <2016-03-04 19:51:23>
##-------------------------------------------------------------------

################################################################################################
## env variables:
##      server_list: The list of servers to collect
##      files_list : Collected on each server file list
##      env_parameters:
##          export jenkins_baseurl="http://123.57.240.189:58080"
##          export ssh_key_file="/var/lib/jenkins/.ssh/id_rsa"
##          export REMOVE_PREVIOUS_DOWNLOAD=false
##          export KEEP_DAY=7
##
############################## Function Start ##################################################
function log() {
    local msg=$*

    echo -e `date +['%Y-%m-%d %H-%M-%S']` "\n$msg\n"
}

function remove_hardline() {
    local str=$*
    echo "$str" | tr -d '\r'
}

# For collect logfile
function collect_files() {
    local server_list=$1
    local files_list=$2
    local keep_day=$3
    local tail_line=$4

    local count_traversal=0
    local save_path="/tmp/"

    for server in ${server_list[@]}
    do
        local server_split=(${server//:/ })
        local server_ip=${server_split[0]}
        local server_port=${server_split[1]}

        count_traversal=$((count_traversal+1))
        log "Collect files from Server Ip_Port[$count_traversal]: $server_ip:$server_port"

        # Check if IP:PORT can connect, timeout 1 seconds
        local nc_return=$(nc -w 1 $server_ip $server_port >/dev/null 2>&1 && echo yes || echo no)
        if [ "x$nc_return" == "xno" ]; then
            log "Warning: Server: $server_ip:$server_port can not connect"
            unconnect_list+=("\n$server")
            continue
        fi

        local ssh_connect="ssh -i $ssh_key_file -p $server_port -o StrictHostKeyChecking=no root@$server_ip"

        # Check if SSH service can connect
        local ssh_return=$($ssh_connect hostname >/dev/null 2>&1 && echo yes || echo no)
        if [ "x$nc_return" == "xno" ]; then
            log "Warning: Can not connect $server_ip:$server_port by ssh"
            continue
        fi

        # Get server_ip hostname, need judge can not connect
        local server_hostname=$($ssh_connect "hostname")

        # Use currrent time for collect every server
        local collect_time=$(date +'%Y%m%d-%H%M%S')
        local work_path="$save_path/$JOB_NAME-$server_hostname-$server_ip-$server_port/$JOB_NAME-$server_ip-$collect_time"

        $ssh_connect "[ -d $work_path ] || mkdir -p $work_path && cd $work_path"

        # Cycle files_list
        for files in ${files_list[@]}
        do
            # By connect ip collect files
            log "Current collect files: [$server_hostname]$server_ip:$server_port:$files"

            # True if files exists and is readable
            ssh_result=$($ssh_connect test -r $files && echo yes || echo no)
            # If non-existent and unreadable
            if [ "x$ssh_result" == "xno" ]; then
                log "Warning: files [$files] not readable"
                unexist_unread_list+=("\n$server:$files")
                continue
            fi

            # Deal with files pathname
            file_parent_dir=${files%/*}
            save_pathname=${file_parent_dir#*/}
            file_name=${files##*/}

            $ssh_connect "mkdir -p $work_path/$save_pathname"
            # Include tail_line exist and not exist
            if [ -n "$tail_line" ] && [ $tail_line -gt 0 ]; then
                log "Collect the tail $tail_line line of the files"
                $ssh_connect "tail -n $tail_line $files > $work_path/$save_pathname/$file_name"
            else
                log "Complete log files"
                $ssh_connect "cp -r $files $work_path/$save_pathname/$file_name"
            fi
        done

        if [ $($ssh_connect "ls $work_path | wc -l") -gt 0 ]; then
            # Compress named:hostname-server_ip-server_port-current_time files
            log "$server collect files compress start"
            $ssh_connect "tar -zcvf ${work_path}.tar.gz $work_path/* && rm -rf $work_path"

            log "scp ${work_path}.tar.gz to Jenkins node $transfer_dst_path/"
            scp -P $server_port -i $ssh_key_file -o StrictHostKeyChecking=no root@$server_ip:/${work_path}.tar.gz $transfer_dst_path/

            tar_list+=("\n${work_path}.tar.gz")
        fi
        # The array is used for need remote upload
        need_transfer_list+=("$server:${work_path}.tar.gz:$job_name-$server_hostname-$server_ip-$server_port")

        log "Delete expired file in $server"
        $ssh_connect "find $save_path/$JOB_NAME-$server_hostname-$server_ip-$server_port -name "$JOB_NAME*" -mtime +$keep_day -exec rm -rfv {} \+"
    done
}

function print_info() {
    # Print disconnect ssh server
    if [ ${#unconnect_list[@]} -gt 0 ]; then
        log "Unconnect ssh list:${unconnect_list[@]}"
    fi

    # Print unexist and unread files list
    if [ ${#unexist_unread_list[@]} -gt 0 ]; then
        log "Files don't exist or not found:${unexist_unread_list[@]}"
    fi

    # Print collect log list
    if [ ${#tar_list[@]} -gt 0 ]; then
        log "Collected log list:${tar_list[@]}"
    fi
}
############################## Function End ####################################################

############################## Shell Start #####################################################
# evaulate env
env_dir="/tmp/env/"
env_file="$env_dir/$$"

if [ -n "$env_parameters" ]; then
    mkdir -p $env_dir
    log "env file: $env_file. Set env parameters:"
    log "$env_parameters"
    cat > $env_file <<EOF
$env_parameters
EOF
    . $env_file
fi

# Parameter for current time
if [ -z "$ssh_key_file" ]; then
    ssh_key_file="/var/lib/jenkins/.ssh/id_rsa"
fi
file_path="/tmp"

# Jenkins parameter judge
if [ -z "$server_list" ]; then
    log "ERROR wrong parameter: server_list can't be empty"
    exit 1
fi

# Judge files list exist
if [ -z "$files_list" ]; then
    log "ERROR wrong parameter: files_list can't be empty"
    exit 1
fi

# Set default value
[ -n "$KEEP_DAY" ] || KEEP_DAY=7
[ -n "$transfer_dst_path" ] || transfer_dst_path="/var/lib/jenkins/jobs/$JOB_NAME/workspace"
[ -n "$transfer_dst_keep_day" ] || transfer_dst_keep_day="7"

if [ -z "$REMOVE_PREVIOUS_DOWNLOAD" ] || $REMOVE_PREVIOUS_DOWNLOAD; then
    rm -rf $transfer_dst_path/*
fi
# Connect server and collect files
collect_files "${server_list[*]}" "${files_list[*]}" $KEEP_DAY $TAIL_LINE

# Echo print info
print_info

# Print download link
if [ -n $jenkins_baseurl ]; then
    log "Download link:\n${jenkins_baseurl}/job/${JOB_NAME}/ws/"
fi

echo "rm obselete files under $transfer_dst_path older than $KEEP_DAY"
find $transfer_dst_path -name "*.tar.gz*" -mtime +$KEEP_DAY -and -not -type d -delete 
############################## Shell End #######################################################
