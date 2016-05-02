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
## Updated: Time-stamp: <2016-05-02 21:31:23>
##-------------------------------------------------------------------

################################################################################################
## env variables:
##      cron_job_list:
##        172.17.0.1:22:echo hello
##        172.17.0.1:23:rm /tmp/npm-*
##
##       env_parameters:
##         export ssh_key_file="/var/lib/jenkins/.ssh/id_rsa"
################################################################################################
. /etc/profile
################################################################################################
if [ ! -f /var/lib/devops/refresh_common_library.sh ]; then
    [ -d /var/lib/devops/ ] || (sudo mkdir -p  /var/lib/devops/ && sudo chmod 777 /var/lib/devops)
    wget -O /var/lib/devops/refresh_common_library.sh \
         https://raw.githubusercontent.com/DennyZhang/devops_public/master/common_library/refresh_common_library.sh
fi
# export AVOID_REFRESH_LIBRARY=true
bash /var/lib/devops/refresh_common_library.sh "555331144"
. /var/lib/devops/devops_common_library.sh
################################################################################################

# Global variables needed to enable the current script
env_parameters=$(remove_hardline "$env_parameters")
env_parameters=$(string_strip_comments "$env_parameters")
IFS=$'\n'
for env_variable in $env_parameters; do
    eval "$env_variable"
done
unset IFS

########################################################
cron_job_list=$(string_strip_comments "$cron_job_list")

[ -n "$ssh_key_file" ] || ssh_key_file="/var/lib/jenkins/.ssh/id_rsa"
IFS=$'\n'
for cron_job in ${cron_job_list[*]}
do
    unset IFS

    IFS=:
    item=($cron_job)
    unset IFS

    server_ip=${item[0]}
    server_port=${item[1]}
    string_prefix="$server_ip:$server_port:"
    cron_command="${cron_job#${string_prefix}}"

    ssh_connect="ssh -i $ssh_key_file -p $server_port -o StrictHostKeyChecking=no root@$server_ip"
    echo "=============== $ssh_connect $cron_command"
    $ssh_connect "$cron_command"
done
## File : system_cron_jobs.sh ends
