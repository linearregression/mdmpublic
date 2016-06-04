#!/bin/bash -e
##-------------------------------------------------------------------
## @copyright 2016 DennyZhang.com
## Licensed under MIT
##   https://raw.githubusercontent.com/DennyZhang/devops_public/master/LICENSE
##
## File : run_remote_command.sh
## Author : DennyZhang.com <denny@dennyzhang.com>
## Description :
## --
## Created : <2016-04-13>
## Updated: Time-stamp: <2016-06-04 22:07:06>
##-------------------------------------------------------------------

################################################################################################
## env variables:
##      command_list:
##        172.17.0.1:22:root:echo hello
##        172.17.0.1:23:root:rm /tmp/npm-*
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
bash /var/lib/devops/refresh_common_library.sh "2205160402"
. /var/lib/devops/devops_common_library.sh
################################################################################################
source_string "$env_parameters"

[ -n "$ssh_key_file" ] || ssh_key_file="/var/lib/jenkins/.ssh/id_rsa"

command_list=$(string_strip_comments "$command_list")
# Input Parameters check
check_list_fields "STRING:TCP_PORT:STRING:STRING" "$command_list"

IFS=$'\n'
for command_item in ${command_list[*]}
do
    unset IFS

    IFS=:
    item=($command_item)
    unset IFS

    server_ip=${item[0]}
    server_port=${item[1]}
    ssh_username=${item[2]}
    string_prefix="$server_ip:$server_port:$ssh_username:"
    bash_command="${command_item#${string_prefix}}"

    ssh_connect="ssh -i $ssh_key_file -p $server_port -o StrictHostKeyChecking=no $ssh_username@$server_ip"
    echo "=============== $ssh_connect $bash_command"
    $ssh_connect "$bash_command"
done
## File : run_remote_command.sh ends
