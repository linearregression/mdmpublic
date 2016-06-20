#!/bin/bash -e
##-------------------------------------------------------------------
## @copyright 2016 DennyZhang.com
## Licensed under MIT
##   https://raw.githubusercontent.com/DennyZhang/devops_public/master/LICENSE
##
## File : monitor_server_filechanges.sh
## Author : DennyZhang.com <denny@dennyzhang.com>
## Description :
## --
## Created : <2016-04-03>
## Updated: Time-stamp: <2016-06-21 07:10:40>
##-------------------------------------------------------------------
################################################################################################
## env variables:
##      server_list:
##         192.168.1.2:2703
##         192.168.1.3:2704
##      file_list:
##         /etc/hosts
##         /etc/profile.d
##      env_parameters:
##          export MARK_PREVIOUS_AS_TRUE=false
##          export FORCE_RESTART_INOTIFY_PROCESS=false
##          export BACKUP_OLD_DIR=/root/monitor_backup
##          export EXIT_NODE_CONNECT_FAIL=false
################################################################################################
. /etc/profile
if [ ! -f /var/lib/devops/refresh_common_library.sh ]; then
    [ -d /var/lib/devops/ ] || (sudo mkdir -p  /var/lib/devops/ && sudo chmod 777 /var/lib/devops)
    wget -O /var/lib/devops/refresh_common_library.sh \
         https://raw.githubusercontent.com/DennyZhang/devops_public/master/common_library/refresh_common_library.sh
fi
bash /var/lib/devops/refresh_common_library.sh "1457168676"
. /var/lib/devops/devops_common_library.sh
################################################################################################
function install_inotifywait_package() {
    local ssh_connect=${1?}

    echo "Check whether inotify utility is installed"
    if ! $ssh_connect which inotifywait 2>/dev/null 2>&1; then
        echo "Warning: inotify utility is not installed. Install it"
        $ssh_connect apt-get install -y inotify-tools
    fi
}

function get_inotifywait_command() {
    local ssh_connect=${1?}
    local file_list=${2?}
    local inotifywait_command="/usr/bin/inotifywait -d -m --timefmt '%Y-%m-%d %H:%M:%S' --format '%T %w %e %f' -e modify -r "
    local monitor_directories=""

    for file in $file_list; do
        if $ssh_connect [ -f "$file" -o -d "$file" ]; then
            monitor_directories="$monitor_directories $file"
        fi
    done

    if [ "$monitor_directories" = "" ]; then
        echo "ERROR: No qualified files to be monitored in $ssh_server_ip"
        has_error="1"
        return
    fi

    echo "$inotifywait_command $monitor_directories"
}

function start_remote_inotify_process() {
    local ssh_connect=${1?}
    local should_restart_process=${2?}

    local ssh_connect="ssh -i $ssh_key_file -p $ssh_port -o StrictHostKeyChecking=no root@$ssh_server_ip"
    if $ssh_connect ps -ef | grep -v grep | grep inotifywait; then
        if [ "$should_restart_process" = "true" ]; then
            echo "kill existing inotify process"
            command="killall inotifywait"
            $ssh_connect "$command"
        else
            return 0
        fi
    fi

    if inotifywait_command=$(get_inotifywait_command "$ssh_connect" "$file_list"); then
        local command="$ssh_connect \"$inotifywait_command --outfile $log_file\""
        echo "Run $command"
        eval "$command"
    fi
}

function check_server_filechanges() {
    local ssh_connect=${1?}

    echo "Check whether new file changes have happened"
    if [ "$MARK_PREVIOUS_AS_TRUE" = "true" ]; then
        $ssh_connect truncate --size=0 "$log_file"
    fi

    file_size=$($ssh_connect stat -c %s "$log_file")
    if [ "$file_size" != "0" ]; then
        echo "ERROR: $log_file is not empty, which indicates files changed"
        echo -e "\n============== File change list =============="
        $ssh_connect cat "$log_file"
        show_changeset
        copy_files "$ssh_connect" "$file_list" "$BACKUP_OLD_DIR"
        echo -e "\n=============================================="
        has_error="1"
    fi
}

function copy_files(){
    local ssh_connect=${1?}
    local file_list=${2?}
    local target_dir=${3?}
    $ssh_connect "mkdir -p $target_dir"
    echo "Copy files to $target_dir"
    IFS=$'\n'
    for t_file in ${file_list[*]}; do
        unset IFS
        if $ssh_connect [ -f "$t_file" -o -d "$t_file" ]; then
            $ssh_connect "cp -Lr $t_file $target_dir/"
        fi
    done
}

function show_changeset() {
    # TODO
    echo "TODO"
}

previous_filelist_file="/var/lib/jenkins/previous_filelist_$JOB_NAME.flag"

function shell_exit() {
    errcode=$?
    echo "$file_list" > "$previous_filelist_file"
    exit $errcode
}
################################################################################################
trap shell_exit SIGHUP SIGINT SIGTERM 0
source_string "$env_parameters"

# fail_unless_os "ubuntu/redhat/centos"

[ -n "$ssh_key_file" ] || export ssh_key_file="/var/lib/jenkins/.ssh/id_rsa"
[ -n "$EXIT_NODE_CONNECT_FAIL" ] || export EXIT_NODE_CONNECT_FAIL=false
[ -n "$BACKUP_OLD_DIR" ] || export BACKUP_OLD_DIR=/root/monitor_backup
[ -n "$MARK_PREVIOUS_AS_TRUE" ] || export MARK_PREVIOUS_AS_TRUE=false
[ -n "$FORCE_RESTART_INOTIFY_PROCESS" ] || export FORCE_RESTART_INOTIFY_PROCESS=false

BACKUP_OLD_DIR="$BACKUP_OLD_DIR/$(date +'%Y-%m-%d_%H-%M-%S')"
export has_error="0"
log_file="/root/monitor_server_filechanges.log"

server_list=$(string_strip_comments "$server_list")
server_list=$(string_strip_whitespace "$server_list")

file_list=$(string_strip_comments "$file_list")
file_list=$(string_strip_whitespace "$file_list")

# Input Parameters check
verify_comon_jenkins_parameters

# restart inotify process, if file list has been changed
if [ -f "$previous_filelist_file" ]; then
    previous_filelist=$(cat "$previous_filelist_file")
    if [ "$previous_filelist" != "$file_list" ] && \
           [ "$FORCE_RESTART_INOTIFY_PROCESS" = "false" ]; then
        FORCE_RESTART_INOTIFY_PROCESS=true
    fi
fi

has_error="0"

# make initial backup
for server in ${server_list}; do
    server_split=(${server//:/ })
    ssh_server_ip=${server_split[0]}
    ssh_port=${server_split[1]}
    ssh_connect="ssh -i $ssh_key_file -p $ssh_port -o StrictHostKeyChecking=no root@$ssh_server_ip"
    if [ "$FORCE_RESTART_INOTIFY_PROCESS" = "true" ] || $ssh_connect [ ! -f "$log_file" ]; then
        echo "Make Initial Backup on $server"
        copy_files "$ssh_connect" "$file_list" "$BACKUP_OLD_DIR"
    fi
done

# check files
for server in ${server_list}; do
    server_split=(${server//:/ })
    ssh_server_ip=${server_split[0]}
    ssh_port=${server_split[1]}
    echo -e "\n============== Check Node ${ssh_server_ip}:${ssh_port} for file changes =============="
    ssh_connect="ssh -i $ssh_key_file -p $ssh_port -o StrictHostKeyChecking=no root@$ssh_server_ip"
    install_inotifywait_package  "$ssh_connect"
    start_remote_inotify_process "$ssh_connect" "$FORCE_RESTART_INOTIFY_PROCESS"
    check_server_filechanges "$ssh_connect"
done

# TODO: backup changed files

# TODO: show diff

# quit with exit code restored
if [ "$has_error" = "1" ]; then
    exit 1
fi
## File : monitor_server_filechanges.sh ends
