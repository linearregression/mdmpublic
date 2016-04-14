#!/bin/bash -e
#######################################################################################
## @copyright 2016 DennyZhang.com
#  Author        : doungni
#  Email         : doungni@doungni.com
#  Last modified : 2015-11-04 10:53
#  Filename      : collect_logfile.sh
#  Description   : collect logfile, by ssh 
#######################################################################################

#######################################################################################
# env variables  : work_path, collect_time, ssh_key_file, server_list, logfile_list
#                  tail_line, retention_day
# env value
# work_path:     : ${WORKSPACE}
# collect_time   : `date+'%Y%m%d-%H%M%S'`
# ssh_key_file   : "${JENKINS_HOME}/.ssh/id_rsa"
# server_list    : By jenkins job configuration
# logfile_list   : By jenkins job configuration
# tail_line      : By jenkins job configuration
# retention_day  : By jenkins job configuration
#######################################################################################

################################################################################################
if [ ! -f /var/lib/devops/refresh_common_library.sh ]; then
    [ -d /var/lib/devops/ ] || (sudo mkdir -p  /var/lib/devops/ && sudo chmod 777 /var/lib/devops)
    wget -O /var/lib/devops/refresh_common_library.sh \
         https://raw.githubusercontent.com/DennyZhang/devops_public/master/common_library/refresh_common_library.sh
fi
# export AVOID_REFRESH_LIBRARY=true
bash /var/lib/devops/refresh_common_library.sh "1582193298"
. /var/lib/devops/devops_common_library.sh
################################################################################################

#######################################################################################
# Paramenter     : server_list, server_arr[], server_split[], server_ip, server_port
#                  server_hostname, ssh_result, logfile_list, logfile_parent_dir
#                  logfile_name, tail_line
# Function       :
#                  split each server
#                  split ip and port
#                  connect server
#                  collect logfile
#                  compress logfile
#                  output download path
#######################################################################################
function collect_logfile() {

    local count_traversal=0
    for server in ${server_list[*]}
    do
        server_split=(${server//:/ })
        server_ip=${server_split[0]}
        server_port=${server_split[1]}

        count_traversal=$((count_traversal+1))
        log "Collect log files from ServerIp_Port[$count_traversal]: $server_ip:$server_port"

        # Check if IP:PORT can connect, timeout 1 seconds
        nc_return=$(nc -w 1 $server_ip $server_port >/dev/null 2>&1 && echo yes || echo no)
        if [ "x$nc_return" == "xno" ]; then
            log "Warning: $server_ip:$server_port can not connect: please check if the network is connected or otherwise"
            continue
        fi

        local ssh_connect="ssh -i $ssh_key_file -p $server_port -o StrictHostKeyChecking=no root@$server_ip"
        # Check if SSH service can connect
        ssh_return=$($ssh_connect uname -a >/dev/null 2>&1 && echo yes || echo no)
        if [ "x$nc_return" == "xno" ]; then
            log "Can not connect $server_ip:$server_port by ssh"
            unconnect_ssh+=("\n$server_ip:$server_porth")
            continue
        fi

        # Use currrent time for collect every server
        collect_time=$(date +'%Y%m%d-%H%M%S')
        work_path="$WORKSPACE/$JOB_NAME-$server_ip-$server_port-$collect_time"
        [ ! -d $work_path ] && mkdir -p $work_path && cd $work_path

        # Cycle logfile_list
        for logfile in ${logfile_list[*]}
        do
            # Get server_ip hostname, need judge can not connect
            server_hostname=$($ssh_connect "hostname")
            
            # By connect ip collect logfile
            log "Current collection log server:[$server_hostname]$server_ip:$server_port:$logfile"
    
            # True if logfile exists and is readable
            ssh_result=$($ssh_connect test -r $logfile && echo yes || echo no)
            # If non-existent and unreadable
            if [ "x$ssh_result" == "xno" ]; then
                log "Warning: Log files $logfile not readable"
                unexist_unread_list+=("\n$logfile")
                continue
            fi

            # Deal with logfile pathname
            logfile_parent_dir=${logfile%/*}
            mkdir -p ${logfile_parent_dir#*/}
            logfile_name=${logfile##*/}
    
            log "Collect the tail $tail_line line of the log file"
            $ssh_connect "tail -n $tail_line $logfile" > ./$logfile_parent_dir/$logfile_name
        done

        if [ $(ls | wc -l) -gt 0 ]; then
            # Compress current named:hostname-server_ip-server_port-current_time logfile
            log "Tar current Server:${server_ip}:${server_port} collected log files"
            tar -zcvf ../$JOB_NAME-$server_hostname-$server_ip-$server_port-${collect_time}.tar.gz ./*
            tar_list+=("\n$JOB_NAME-$server_hostname-$server_ip-$server_port-${collect_time}")
        else
            log "Warning: The $server_ip:$server_port log folder is empty,did not collect the log file"
        fi

        rm -rf $work_path
    done

    if [ ${#unconnect_ssh[@]} -gt 0 ]; then
        log "Unconnect ssh list:\n${unconnect_ssh[@]}"
    fi
    
    if [ ${#unexist_unread_list[@]} -gt 0 ]; then
        log "Non-existent and unread log file list:${unexist_unread_list[@]}"
    fi
}

#######################################################################################
# Shell Entracnce 
#######################################################################################
# Parameter for current time

ssh_key_file="${JENKINS_HOME}/.ssh/id_rsa"

# Jenkins parameter judge
if [ -z "$server_list" ]; then
    log "Error: Please refer to the correct parameters for the prompt configuration"
    exit 1
fi

# Judge logfile list exist
if [ -z "$logfile_list" ]; then
    log "Error: Please refer to the correct parameters for the prompt configuration"
    exit 1
fi

# Judge tail line exist and gather than zero
if [ $tail_line -le 0 ] || [ -z $tail_line ];then
    log "Error: Invalid parameter for $tail_line. It should be positive integer"
    exit 1
fi

# connect server and collect logfile
collect_logfile

# Check the files generated within 10 minutes.
if [ ${#tar_list[@]} -gt 0 ]; then
    # Download logfile
    if [ -z $JOB_URL ]; then
        log "Log file storage path: $WORKSPACE, log list:\n${tar_list[@]}"
    else
        log "Generate log files download link:\n${JOB_URL}ws"
    fi
else
    log "Warning: Failed to collect any logs"
fi

# Delete retention day tar
cd $WORKSPACE
if [ -z "$keep_day" ]; then
    keep_day=7
fi

find $WORKSPACE -type f -name "$JOB_NAME*" -mtime +$keep_day -exec rm -rfv {} \+
############################ collect_logfile.sh End #################################
