#!/bin/bash -e
##-------------------------------------------------------------------
## File : list_network_traffic.sh
## Author : DennyZhang.com <denny@dennyzhang.com>
## Description :
## --
## Created : <2016-06-14>
## Updated: Time-stamp: <2016-06-22 21:07:52>
##-------------------------------------------------------------------
## env variables:
##      ssh_server: 192.168.1.2:2704:root
##      env_parameters:
##          export FORCE_RESTART_JUSTNIFFER_PROCESS=false
##          export STOP_JUSTNIFFER_PROCESS=false
##          export TRAFFIC_LOG_FILE="/root/justniffer.log"
##          export ssh_key_file="/var/lib/jenkins/.ssh/id_rsa"
################################################################################################
. /etc/profile
if [ ! -f /var/lib/devops/refresh_common_library.sh ]; then
    [ -d /var/lib/devops/ ] || (sudo mkdir -p  /var/lib/devops/ && sudo chmod 777 /var/lib/devops)
    wget -O /var/lib/devops/refresh_common_library.sh \
         https://raw.githubusercontent.com/DennyZhang/devops_public/master/common_library/refresh_common_library.sh
fi
bash /var/lib/devops/refresh_common_library.sh "538135635"
. /var/lib/devops/devops_common_library.sh
################################################################################################
function remote_install_justniffer() {
    if $SSH_CONNECT "! which justniffer 1>/dev/null 2>&1"; then
        echo "========== install justniffer"

        command="add-apt-repository -y ppa:oreste-notelli/ppa"
        echo "$command" && $SSH_CONNECT "$command"

        command="apt-get -y update"
        echo "$command" && $SSH_CONNECT "$command"

        command="apt-get install -y justniffer"
        echo "$command" && $SSH_CONNECT "$command"
    fi
}

function remote_list_network_traffic() {
    log_file=${1?}
    command="cat $log_file"
    echo -e "\n========== Show network traffic report: $command" && $SSH_CONNECT "$command"
}

function shell_exit() {
    errcode=$?
    if [ "$STOP_JUSTNIFFER_PROCESS" = "true" ]; then
        remote_stop_process "$SSH_CONNECT"
    fi
    exit $errcode
}

################################################################################################
trap shell_exit SIGHUP SIGINT SIGTERM 0
source_string "$env_parameters"

# TODO: check remote server: only support ubuntu

[ -n "$ssh_key_file" ] || ssh_key_file="/var/lib/jenkins/.ssh/id_rsa"
[ -n "$FORCE_RESTART_JUSTNIFFER_PROCESS" ] || FORCE_RESTART_JUSTNIFFER_PROCESS=false
[ -n "$STOP_JUSTNIFFER_PROCESS" ] || STOP_JUSTNIFFER_PROCESS=false
[ -n "$TRAFFIC_LOG_FILE" ] || TRAFFIC_LOG_FILE="/root/justniffer.log"

# Input Parameters check
check_list_fields "IP:TCP_PORT:STRING" "$ssh_server"
enforce_ssh_check "true" "$ssh_server" "$ssh_key_file"

server_split=(${ssh_server//:/ })
server_ip=${server_split[0]}
server_port=${server_split[1]}
ssh_username=${server_split[2]}
[ -n "$ssh_username" ] || ssh_username="root"

export SSH_CONNECT="ssh -i $ssh_key_file -p $server_port -o StrictHostKeyChecking=no $ssh_username@$server_ip"

remote_install_justniffer
if [ "$FORCE_RESTART_JUSTNIFFER_PROCESS" = "true" ]; then
    remote_stop_process "$SSH_CONNECT" "justniffer"
fi

start_command="nohup /usr/bin/justniffer -i eth0 -l '%request.timestamp(%T %%D) - %request.header.host - %response.code - %response.time' > $TRAFFIC_LOG_FILE 2>&1 &"

remote_start_process "$SSH_CONNECT" "justniffer" "$start_command"
remote_list_network_traffic "$TRAFFIC_LOG_FILE"
## File : list_network_traffic.sh ends
