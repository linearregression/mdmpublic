#!/bin/bash -e
##-------------------------------------------------------------------
## @copyright 2015 DennyZhang.com
## File : monitor_server_filechanges.sh
## Author : Denny <denny.zhang001@gmail.com>
## Description :
## --
## Created : <2015-07-03>
## Updated: Time-stamp: <2016-03-17 10:22:14>
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
##           export mark_previous_as_true=false
##           export start_inotifywait_when_stopped=true
################################################################################################
# evaulate env
IFS=$'\n'
for env_variable in `echo "$env_parameters"`; do
    eval $env_variable
done
unset IFS

[ -n "$ssh_key_file" ] || ssh_key_file="/var/lib/jenkins/.ssh/id_rsa"
[ -n "$start_inotifywait_when_stopped" ] || start_inotifywait_when_stopped=true

log_file="/root/monitor_server_filechanges.log"

function monitor_server_filechanges() {
    local ssh_server_ip=${1?}
    local ssh_port=${2?}

    local ssh_connect="ssh -i $ssh_key_file -p $ssh_port -o StrictHostKeyChecking=no root@$ssh_server_ip"

    echo "Check whether inotify utility is installed"
    if ! $ssh_connect which inotifywait 2>/dev/null 2>&1; then
        echo "Warning: inotify utility is not installed. Install it"
        $ssh_connect apt-get install -y inotify-tools
    fi

    echo "Check whether inotify process is running"
    if ! $ssh_connect ps -ef | grep -v grep | grep inotifywait; then
        echo "Warning: inotifywait is not running in the server"
        if $start_inotifywait_when_stopped; then
            local inotifywait_command="/usr/bin/inotifywait -d -m --timefmt \"%Y-%m-%d %H:%M:%S\" --format \"%T %w %e %f\" -e modify -r "
            local monitor_directories=""
            for file in $file_list; do
                if $ssh_connect [ -f $file -o -d $file ]; then
                    monitor_directories="$monitor_directories $file"
                fi
            done
            if [ "$monitor_directories" = "" ]; then
                echo "ERROR: No qualified files to be monitored in $ssh_server_ip"
                exit 1
            fi
            local command="$ssh_connect $inotifywait_command $monitor_directories --outfile $log_file"
            echo "Run $command"
            $command
        fi
    fi

    if [ -n "$mark_previous_as_true" ] && $mark_previous_as_true; then
        $ssh_connect truncate --size=0 $log_file
    fi

    echo "Check whether new file changes have happened"
    file_size=$($ssh_connect stat -c %s $log_file)
    if [ "$file_size" != "0" ]; then
        echo "ERROR: $log_file is not empty, which indicates files changed"
        echo -e "\n============== File change list =============="
        $ssh_connect cat $log_file
        echo -e "\n=============================================="
        exit 1
    fi
}

for server in ${server_list}
do
    server_split=(${server//:/ })
    ssh_server_ip=${server_split[0]}
    ssh_port=${server_split[1]}
    echo "Check Node $ssh_server_ip for file changes"
    monitor_server_filechanges $ssh_server_ip $ssh_port
done
## File : monitor_server_filechanges.sh ends