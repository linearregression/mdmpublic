#!/bin/bash -e
##-------------------------------------------------------------------
## @copyright 2016 DennyZhang.com
## Licensed under MIT
##   https://raw.githubusercontent.com/DennyZhang/devops_public/master/LICENSE
##
## File : system_cron_jobs.sh
## Author : DennyZhang.com <denny@dennyzhang.com>
## Description :
## --
## Created : <2016-04-13>
## Updated: Time-stamp: <2016-05-30 17:42:08>
##-------------------------------------------------------------------

################################################################################################
## env variables:
##      cron_job_list:
##        root:172.17.0.1:22:echo hello
##        root:172.17.0.1:23:rm /tmp/npm-*
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
source_string "$env_parameters"

[ -n "$ssh_key_file" ] || ssh_key_file="/var/lib/jenkins/.ssh/id_rsa"

# Input Parameters check
check_list_fields "IP:TCP_PORT:STRING" "$cron_job_list"

cron_job_list=$(string_strip_comments "$cron_job_list")

IFS=$'\n'
for cron_job in ${cron_job_list[*]}
do
    unset IFS

    IFS=:
    item=($cron_job)
    unset IFS

    ssh_username=${item[0]}
    server_ip=${item[1]}
    server_port=${item[2]}
    string_prefix="$ssh_username:$server_ip:$server_port:"
    cron_command="${cron_job#${string_prefix}}"

    ssh_connect="ssh -i $ssh_key_file -p $server_port -o StrictHostKeyChecking=no $ssh_username@$server_ip"
    echo "=============== $ssh_connect $cron_command"
    $ssh_connect "$cron_command"
done
## File : system_cron_jobs.sh ends
