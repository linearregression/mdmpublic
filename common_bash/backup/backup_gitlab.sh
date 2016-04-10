#!/bin/bash -ex
##-------------------------------------------------------------------
## @copyright 2015 DennyZhang.com
## File : backup_gitlab.sh
## Author : DennyZhang.com <denny@dennyzhang.com>
## Description :
## --
## Created : <2016-03-05>
## Updated: Time-stamp: <2016-04-10 14:49:49>
##-------------------------------------------------------------------
################################################################################################
## env variables:
##      server_ip_port: 123.57.240.189:22
##      env_parameters:
##          export KEEP_DAY=7
##          export KEEP_BACKUP_DAY=7
##          export ssh_key_file=/var/lib/jenkins/.ssh/id_rsa
################################################################################################
if [ ! -f /var/lib/devops/refresh_common_library.sh ]; then
    [ -d /var/lib/devops/ ] || (sudo mkdir -p  /var/lib/devops/ && sudo chmod 777 /var/lib/devops)
    wget -O /var/lib/devops/refresh_common_library.sh \
         https://raw.githubusercontent.com/DennyZhang/devops_public/master/common_library/refresh_common_library.sh
fi
# export AVOID_REFRESH_LIBRARY=true
bash /var/lib/devops/refresh_common_library.sh "1512381967"
. /var/lib/devops/devops_common_library.sh
################################################################################################
# env parameters
env_parameters=$(remove_hardline "$env_parameters")
env_parameters=$(list_strip_comments "$env_parameters")
IFS=$'\n'
for env_variable in `echo "$env_parameters"`; do
    eval $env_variable
done
unset IFS

[ -n "$ssh_key_file" ] || ssh_key_file="/var/lib/jenkins/.ssh/id_rsa"
[ -n "$transfer_dst_path" ] || transfer_dst_path="/var/lib/jenkins/jobs/$JOB_NAME/workspace"
[ -n "$KEEP_BACKUP_DAY" ] || KEEP_BACKUP_DAY=7
[ -n "$KEEP_DAY" ] || KEEP_DAY=7
server_split=(${server_ip_port//:/ })
ssh_server_ip=${server_split[0]}
ssh_port=${server_split[1]}
backup_dir="/var/opt/gitlab/backups"

ssh_connect="ssh -i $ssh_key_file -p $ssh_port -o StrictHostKeyChecking=no root@$ssh_server_ip"

echo "Remove old backup on demand"
if [ "$KEEP_DAY" = "0" ]; then
    $ssh_connect rm -rf $backup_dir/*
else
    $ssh_connect "find $backup_dir -name \"*.tar\" -mtime +$KEEP_DAY -and -not -type d -delete"
fi

echo "Perform gitlab backup"
$ssh_connect gitlab-rake gitlab:backup:create

echo "SCP backup set to Jenkins machine: $transfer_dst_path"
scp -r -P $ssh_port -i $ssh_key_file root@$ssh_server_ip:/var/opt/gitlab/backups/* $transfer_dst_path/

echo "Remove obsolete backup set"
find $transfer_dst_path -name "*.tar" -mtime +$KEEP_BACKUP_DAY -and -not -type d -delete 
## File : backup_gitlab.sh ends
