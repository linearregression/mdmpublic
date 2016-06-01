#!/bin/bash -e
##-------------------------------------------------------------------
## @copyright 2016 DennyZhang.com
## Licensed under MIT
##   https://raw.githubusercontent.com/DennyZhang/devops_public/master/LICENSE
##
## File : run_command_on_servers.sh
## Author : DennyZhang.com <denny@dennyzhang.com>
## Description :
## --
## Created : <2016-04-13>
## Updated: Time-stamp: <2016-06-01 18:38:14>
##-------------------------------------------------------------------

################################################################################################
## env variables:
##       server_list: ip-1:port-1:root
##                    ip-2:port-2:root
##       command_list:
##        cat /etc/hosts
##        ls /opt/
##
##       env_parameters:
##         export ssh_key_file="/var/lib/jenkins/.ssh/id_rsa"
################################################################################################
. /etc/profile

if [ ! -f /var/lib/devops/refresh_common_library.sh ]; then
    [ -d /var/lib/devops/ ] || (sudo mkdir -p  /var/lib/devops/ && sudo chmod 777 /var/lib/devops)
    wget -O /var/lib/devops/refresh_common_library.sh \
         https://raw.githubusercontent.com/DennyZhang/devops_public/master/common_library/refresh_common_library.sh
fi
# export AVOID_REFRESH_LIBRARY=true
bash /var/lib/devops/refresh_common_library.sh "1788082022"
. /var/lib/devops/devops_common_library.sh
################################################################################################
function shell_exit() {
    errcode=$?
    rm "$tmp_file"
    exit $errcode
}
################################################################################################
trap shell_exit SIGHUP SIGINT SIGTERM 0
source_string "$env_parameters"

[ -n "$ssh_key_file" ] || ssh_key_file="/var/lib/jenkins/.ssh/id_rsa"

server_list=$(string_strip_comments "$server_list")
command=$(string_strip_comments "$command")

# Input Parameters check
check_list_fields "STRING:TCP_PORT" "$server_list"

# Dump bash command to scripts
current_filename=$(basename "${0}")
tmp_file="/tmp/${current_filename}_$$"
cat > "$tmp_file" <<EOF
$command_list
EOF

IFS=$'\n'
for server in ${server_list}
do
    unset IFS
    server_split=(${server//:/ })
    ssh_server_ip=${server_split[0]}
    ssh_port=${server_split[1]}
    ssh_username=${server_split[2]}
    [ -n "$ssh_username" ] || ssh_username="root"
    
    ssh_command="scp -P $ssh_port -i $ssh_key_file -o StrictHostKeyChecking=no $tmp_file $ssh_username@$ssh_server_ip:/$tmp_file"
    $ssh_command

    ssh_connect="ssh -i $ssh_key_file -p $ssh_port -o StrictHostKeyChecking=no $ssh_username@$ssh_server_ip"
    echo "=============== Run Command on $ssh_server_ip:$ssh_port"
    $ssh_connect "bash -ex $tmp_file"
done
## File : run_command_on_servers.sh ends
