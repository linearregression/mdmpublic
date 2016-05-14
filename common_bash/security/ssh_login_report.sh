#!/bin/bash -e
##-------------------------------------------------------------------
## @copyright 2016 DennyZhang.com
## Licensed under MIT
## https://raw.githubusercontent.com/DennyZhang/devops_public/master/LICENSE
##
## File : ssh_login_report.sh
## Author : DennyZhang.com <denny@dennyzhang.com>
## Description :
## --
## Created : <2016-04-03>
## Updated: Time-stamp: <2016-05-14 08:14:31>
##-------------------------------------------------------------------
################################################################################################
## env variables:
##      ssh_server: 192.168.1.3:2704
##      env_parameters:
##           export HAS_INIT_ANALYSIS=false
##           export AUTH_LOG_PATH=/var/log/auth.log  # For Ubuntu/Debian
##           export AUTH_LOG_PATH=/var/log/secure # For CentOS
##           export WORKING_DIR=/tmp/auth
##           export PARSE_MAXIMUM_ENTRIES="500"
##           export GET_CITY_FROM_IP=false
################################################################################################
. /etc/profile
if [ ! -f /var/lib/devops/refresh_common_library.sh ]; then
    [ -d /var/lib/devops/ ] || (sudo mkdir -p /var/lib/devops/ && sudo chmod 777 /var/lib/devops)
    wget -O /var/lib/devops/refresh_common_library.sh \
         https://raw.githubusercontent.com/DennyZhang/devops_public/master/common_library/refresh_common_library.sh
fi
# export AVOID_REFRESH_LIBRARY=true
bash /var/lib/devops/refresh_common_library.sh "538154310"
. /var/lib/devops/devops_common_library.sh
################################################################################################
function prepare_auth_log_files() {
    local working_dir=${1?}
    local auth_log_dir="$working_dir/auth_log"
    command="rm -rf $working_dir && mkdir -p $auth_log_dir"
    $SSH_CONNECT "$command"
    echo "Copy ${AUTH_LOG_PATH}* to $auth_log_dir"
    $SSH_CONNECT cp "${AUTH_LOG_PATH}*" "$auth_log_dir"
    if [ "$AUTH_LOG_PATH" = "/var/log/auth.log" ]; then
        $SSH_CONNECT gzip -d "$auth_log_dir/auth.log.*.gz"
    fi
}

function generate_ssh_login_log() {
    local working_dir=${1?}
    local ssh_login_logfile=${2?}

    local auth_log_dir="$working_dir/auth_log"
    echo "Dump ssh logs to $ssh_login_logfile"
    grep_command="grep -C 5 -h -R 'sshd.*session opened' $auth_log_dir"
    # TODO: sort by time, instead of alph characters
    command="$grep_command | sort | tail -n $PARSE_MAXIMUM_ENTRIES > $ssh_login_logfile"
    $SSH_CONNECT "$command"
}

function generate_fingerprint() {
    local fingerprint_file=${1?}
    echo "generate fingerprint for public key files to $fingerprint_file"
    command="cat /root/.ssh/authorized_keys /home/*/.ssh/authorized_keys | grep '^ssh-rsa'"
    current_filename=$(basename "${0}")
    tmp_file="/tmp/${current_filename}_$$"

    fingerprint_result=""
    output=$($SSH_CONNECT "$command")
    IFS=$'\n'
    for entry in $output; do
        unset IFS
        # TODO: what if, email can't be found
        email=$(echo "$entry" | awk -F' ' '{print $3}')
        echo "$entry" > "$tmp_file"
        fingerprint=$(ssh-keygen -lf "$tmp_file")
        fingerprint_result="${fingerprint_result}\n${email} ${fingerprint}"
    done

    command="echo -e \"$fingerprint_result\" > $fingerprint_file"
    $SSH_CONNECT "$command"
}

function ip_to_city() {
    local ip=${1?}
    city="unknown"
    # TODO
    echo "$ip"
    echo "$city"
}

function parse_ssh_session() {
    # Sample return: May 9 22:31:02, sshd[619] 172.221.147.244:52740 (XXX), key_email, 0 seconds
    local session_id=${1?}
    local start_entry=${2?}
    local end_entry=${3?}
    local login_entry=${4?}
    local fingerprint_list=${5?}

    start_time=$(echo "$start_entry" | awk -F' ' '{print $1" "$2" "$3}')
    end_time=$(echo "$end_entry" | awk -F' ' '{print $1" "$2" "$3}')

    # parse login entry
    if echo "$login_entry" | grep "Accepted publickey" 1>/dev/null 2>&1; then
        auth_method="publickey"
        # sample: May 9 22:31:02 denny-pc sshd[619]: Accepted publickey for root from 171.221.147.244 port 52740 ssh2: RSA 2f:66:6c:2a:09:67:c0:ce:37:3f:96:a8:e9:aa:b5:ea
        fingerprint=$(echo "$login_entry" | awk -F' RSA ' '{print $2}')
        if output=$(echo "$fingerprint_list" | grep "$fingerprint" | awk -F' ' '{print $1}'); then
            fingerprint=$output
        fi

        # TODO: remove code duplication by bash regrexp pattern match
        ssh_username=$(echo "$login_entry" | awk -F' Accepted publickey for ' '{print $2}')
        ssh_username=$(echo "$ssh_username" | awk -F' ' '{print $1}')

        client_ip=$(echo "$login_entry" | awk -F' from ' '{print $2}')
        client_ip=$(echo "$client_ip" | awk -F' ' '{print $1}')

        client_port=$(echo "$login_entry" | awk -F' port ' '{print $2}')
        client_port=$(echo "$client_port" | awk -F' ' '{print $1}')
    fi

    if echo "$login_entry" | grep "Accepted password" 1>/dev/null 2>&1; then
        auth_method="password"
        # sample: May 13 17:03:54 denny-pc sshd[29980]: Accepted password for denny from ::1 port 60608 ssh2
        ssh_username=$(echo "$login_entry" | awk -F' Accepted password for ' '{print $2}')
        ssh_username=$(echo "$ssh_username" | awk -F' ' '{print $1}')

        client_ip=$(echo "$login_entry" | awk -F' from ' '{print $2}')
        client_ip=$(echo "$client_ip" | awk -F' ' '{print $1}')

        client_port=$(echo "$login_entry" | awk -F' port ' '{print $2}')
        client_port=$(echo "$client_port" | awk -F' ' '{print $1}')
    fi

    output_prefix="sshd[$session_id] ${start_time} -- ${end_time} client(${client_ip}:${client_port}) ${ssh_username}"
    if [ "$auth_method" = "publickey" ]; then
        output_prefix="${output_prefix} ${auth_method}(${fingerprint})"
    fi

    if [ "$auth_method" = "password" ]; then
        output_prefix="${output_prefix} ${auth_method}"
    fi

    echo "$output_prefix"
}

function ssh_login_events() {
    local ssh_raw_log=${1?}
    local fingerprint_list=${2?}

    local entry
    ssh_session_list=$(echo "$ssh_raw_log" | grep 'session opened' | awk -F' ' '{print $5}')
    for session in $ssh_session_list; do
        session_id=$(echo "$session" | awk -F'\[' '{print $2}')
        session_id=$(echo "$session_id" | awk -F'\]' '{print $1}')

        # TODO: what if no matched entries
        start_entry=$(echo "$ssh_raw_log" | grep "sshd\[$session_id\].*session opened" | head -n1)
        end_entry=$(echo "$ssh_raw_log" | grep "sshd\[$session_id\].*session closed" | tail -n1)
        login_entry=$(echo "$ssh_raw_log" | grep "sshd\[$session_id\].*Accepted " | tail -n1)

        # echo "start_entry: $start_entry"
        # echo "end_entry: $end_entry"
        # echo "login_entry: $login_entry"

        parse_ssh_session "$session_id" "$start_entry" "$end_entry" "$login_entry" "$fingerprint_list"
    done
}

function shell_exit() {
    errcode=$?
    current_filename=$(basename "${0}")
    tmp_file="/tmp/${current_filename}_$$"
    rm -rf "$tmp_file"
    exit $errcode
}
################################################################################################
trap shell_exit SIGHUP SIGINT SIGTERM 0

source_string "$env_parameters"

[ -n "$ssh_key_file" ] || ssh_key_file="/var/lib/jenkins/.ssh/id_rsa"
[ -n "$WORKING_DIR" ] || WORKING_DIR=/tmp/auth
[ -n "$HAS_INIT_ANALYSIS" ] || HAS_INIT_ANALYSIS=false
[ -n "$AUTH_LOG_PATH" ] || AUTH_LOG_PATH=/var/log/auth.log
[ -n "$PARSE_MAXIMUM_ENTRIES" ] || PARSE_MAXIMUM_ENTRIES="500"
[ -n "$GET_CITY_FROM_IP" ] || GET_CITY_FROM_IP=false

SSH_LOGIN_LOGFILE="$WORKING_DIR/ssh_login.log"
FINGERPRINT_FILE="$WORKING_DIR/fingerprint"

server_split=(${ssh_server//:/ })
server_ip=${server_split[0]}
server_port=${server_split[1]}

SSH_CONNECT="ssh -i $ssh_key_file -p $server_port -o StrictHostKeyChecking=no root@$server_ip"

if [ "$HAS_INIT_ANALYSIS" = "false" ]; then
    prepare_auth_log_files $WORKING_DIR
    generate_ssh_login_log $WORKING_DIR $SSH_LOGIN_LOGFILE
    generate_fingerprint $FINGERPRINT_FILE
fi

ssh_raw_log=$($SSH_CONNECT "tail -n $PARSE_MAXIMUM_ENTRIES $SSH_LOGIN_LOGFILE")
fingerprint_list=$($SSH_CONNECT "cat $FINGERPRINT_FILE")

echo -e "===================== SSH Login Events On $ssh_server:"
ssh_login_events "$ssh_raw_log" "$fingerprint_list"
## File : ssh_login_report.sh ends
