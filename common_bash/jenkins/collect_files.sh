#!/bin/bash -xe
################################################################################################
# * Author        : doungni
# * Email         : doungni@doungni.com
# * Last modified : 2016-01-25 00:59
# * Filename      : collect_scp_files.sh
# * Description   : 
################################################################################################

############################## Function Start ##################################################

function log() {
    local msg=$*

    echo -e `date +['%Y-%m-%d %H-%M-%S']` "\n$msg\n"
}

# For collect logfile
function collect_files() {

    local count_traversal=0
    # $1=server_list array
    for server in $1
    do
        local server_split=(${server//:/ })
        local server_ip=${server_split[0]}
        local server_port=${server_split[1]}

        count_traversal=$((count_traversal+1))
        log "Collect log files from ServerIp_Port[$count_traversal]: $server_ip:$server_port"

        # Check if IP:PORT can connect, timeout 1 seconds
        local nc_return=$(nc -w 1 $server_ip $server_port >/dev/null 2>&1 && echo yes || echo no)
        if [ "x$nc_return" == "xno" ]; then
            log "Warning: $server_ip:$server_port can not connect: please check if the network is connected or otherwise"
            unconnect_list+=("\n$server")
            continue
        fi

        local ssh_connect="ssh -i $ssh_key_file -p $server_port -o StrictHostKeyChecking=no root@$server_ip"

        # Check if SSH service can connect
        ssh_return=$($ssh_connect hostname >/dev/null 2>&1 && echo yes || echo no)
        if [ "x$nc_return" == "xno" ]; then
            log "Can not connect $server_ip:$server_port by ssh"
            continue
        fi

        # Get server_ip hostname, need judge can not connect
        server_hostname=$($ssh_connect "hostname")

        # Use currrent time for collect every server
        local collect_time=$(date +'%Y%m%d-%H%M%S')
        local work_path="$file_path/$JOB_NAME-$server_hostname/$JOB_NAME-$server_ip-$server_port-$collect_time"

        $ssh_connect "[ ! -d $work_path ] && mkdir -p $work_path && cd $work_path"

        # Cycle files_list ,$2 = files_list
        for files in $2
        do
            
            # By connect ip collect files
            log "Current collection log server:[$server_hostname]$server_ip:$server_port:$files"
    
            # True if files exists and is readable
            ssh_result=$($ssh_connect test -r $files && echo yes || echo no)
            # If non-existent and unreadable
            if [ "x$ssh_result" == "xno" ]; then
                log "Warning: Log files $files not readable"
                unexist_unread_list+=("\n$server-$files")
                continue
            fi

            # Deal with files pathname
            local file_parent_dir=${files%/*}
            local file_pathname=${file_parent_dir#*/}
            local file_name=${files##*/}

            $ssh_connect "[ -d $work_path/$file_pathname ] || mkdir -p $work_path/$file_pathname"
            if [ $tail_line -gt 0 ]; then
                log "Collect the tail $tail_line line of the log file"
                $ssh_connect "tail -n $tail_line $files > $work_path/$file_pathname/$file_name"
            else
                log "Complete log files"
                $ssh_connect "cp $files $work_path/$file_pathname/$file_name"
            fi

            # The array is used for need remote upload
            need_upload_list+=("$server:$file_path/$JOB_NAME-$server_hostname")
        done

        if [ $($ssh_connect "ls $work_path | wc -l") -gt 0 ]; then
            # Compress current named:hostname-server_ip-server_port-current_time files
            log "Tar current Server collected log files"
            $ssh_connect "tar -Jcvf ${work_path}.tar.xz $work_path/* --remove-files"
            tar_list+=("\n${work_path}.tar.xz")
        fi

        # Delete expired file
        $ssh_connect "find $work_path -name "$JOB_NAME*" -mtime +$keep_day -exec rm -rfv {} \+"
    done
}

function print_info() {
    # Print disconnect ssh server
    if [ ${#unconnect_list[@]} -gt 0 ]; then
        log "Unconnect ssh list:\n${unconnect_list[@]}"
    fi
    
    # Print unexist and unread files list
    if [ ${#unexist_unread_list[@]} -gt 0 ]; then
        log "Non-existent and unread log file list:\n${unexist_unread_list[@]}"
    fi

    # Print collect log list
    if [ ${#tar_list[@]} -gt 0 ]; then
        log "Collected log list:\n${tar_list[@]}"
    fi
}
############################## Function End ####################################################

############################## Shell Start #####################################################
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

# Delete retention day tar
if [ -z "$keep_day" ]; then
    keep_day=7
fi

# Connect server and collect files
collect_files "${server_list[*]}" "${files_list[*]}" "${tail_line[*]}" $keep_day

# Echo print info
print_info
echo ${need_upload_list[@]}
echo ${need_upload_list[1]}
# Excute scp for remote
#if [ ${#full_files_list[@]} -gt 0 ]; then
    if [ -n "$upload_repo" ]; then
        upload_repo=(${upload_repo// / })
        # 0 upload remote shell pathname and name
        # 1 upload remote mode[scp/rsync/...]
        # 2 repo ssh key pathname[/root/.ssh/id_rsa]
        # 3 repo server[ip:port:filepath]
        # 4 repo server data keep days[7] 
        # 5 remote server[ip:port:filepath], by this shell provide
        # 6 remote server[$ssh_key_file], by this shell provide
        bash -ex ${upload_repo[0]} ${upload_repo[1]} ${upload_repo[2]} ${upload_repo[3]} ${upload_repo[4]} "${need_upload_list[*]}" $ssh_key_file
    fi
#fi

############################## Shell End #######################################################
