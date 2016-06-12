#!/bin/bash -e
##-------------------------------------------------------------------
## @copyright 2016 DennyZhang.com
## Licensed under MIT
## https://raw.githubusercontent.com/DennyZhang/devops_public/master/LICENSE
##
## File : package_action_report.sh
## Author : DennyZhang.com <denny@dennyzhang.com>
## Description :
##
## --
## Created : <2016-04-03>
## Updated: Time-stamp: <2016-06-12 08:02:21>
##-------------------------------------------------------------------
################################################################################################
## env variables:
##      ssh_server: 192.168.1.3:2704:root
##      env_parameters:
##           export HAS_INIT_ANALYSIS=false
##           export PARSE_MAXIMUM_ENTRIES="500"
################################################################################################
. /etc/profile
if [ ! -f /var/lib/devops/refresh_common_library.sh ]; then
    [ -d /var/lib/devops/ ] || (sudo mkdir -p /var/lib/devops/ && sudo chmod 777 /var/lib/devops)
    wget -O /var/lib/devops/refresh_common_library.sh \
         https://raw.githubusercontent.com/DennyZhang/devops_public/master/common_library/refresh_common_library.sh
fi
# export AVOID_REFRESH_LIBRARY=true
bash /var/lib/devops/refresh_common_library.sh "1352904353"
. /var/lib/devops/devops_common_library.sh
################################################################################################
function generate_package_log_file() {
    local working_dir=${1?}
    local action_log_file=${2?}

    cat > /tmp/copy_package_log.sh <<EOF
#!/bin/bash -e
working_dir="$working_dir"
action_log_file="$action_log_file"
rm -rf \$working_dir
mkdir -p \$working_dir

> $action_log_file
cd /var/log/apt
echo "Copy /var/log/apt/history.log* to \$action_log_file"
for f in \$(ls -rt history.log*); do
    cp \$f \$working_dir/
    if [[ "\${f}" == *.gz ]]; then
         gzip -d \$working_dir/\$f
         f=\${f%.gz}
    fi
    cat \$working_dir/\$f >> \$action_log_file
done
EOF
    echo "Upload /tmp/copy_package_log.sh"
    scp -i "$ssh_key_file" -P "$server_port" -o StrictHostKeyChecking=no /tmp/copy_package_log.sh \
        "$ssh_username@$server_ip:/tmp/copy_package_log.sh"

    $SSH_CONNECT "bash -e /tmp/copy_package_log.sh"
}

function show_package_report() {
    local action_log_file=${1?}
    local entry_num=${2?}
    ssh_command="tail -n $entry_num $action_log_file"
    echo "$ssh_command"
    $SSH_CONNECT "$ssh_command"
}

function shell_exit() {
    errcode=$?
    exit $errcode
}
################################################################################################
trap shell_exit SIGHUP SIGINT SIGTERM 0
source_string "$env_parameters"

[ -n "$ssh_key_file" ] || ssh_key_file="/var/lib/jenkins/.ssh/id_rsa"
[ -n "$PARSE_MAXIMUM_ENTRIES" ] || PARSE_MAXIMUM_ENTRIES="500"
[ -n "$HAS_INIT_ANALYSIS" ] || HAS_INIT_ANALYSIS=false
[ -n "$WORKING_DIR" ] || WORKING_DIR=/tmp/package_log

ACTION_LOG_FILE="$WORKING_DIR/package_action.log"

# Input Parameters check
check_list_fields "IP:TCP_PORT:STRING" "$ssh_server"
enforce_ssh_check "true" "$ssh_server" "$ssh_key_file"

server_split=(${ssh_server//:/ })
server_ip=${server_split[0]}
server_port=${server_split[1]}
ssh_username=${server_split[2]}

[ -n "$ssh_username" ] || ssh_username="root"

SSH_CONNECT="ssh -i $ssh_key_file -p $server_port -o StrictHostKeyChecking=no $ssh_username@$server_ip"

if [ "$HAS_INIT_ANALYSIS" = "false" ]; then
    generate_package_log_file "$WORKING_DIR" "$ACTION_LOG_FILE"
fi

show_package_report "$ACTION_LOG_FILE" "$PARSE_MAXIMUM_ENTRIES"
## File : package_action_report.sh ends
