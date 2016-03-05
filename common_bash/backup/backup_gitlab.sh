#!/bin/bash -ex
##-------------------------------------------------------------------
## @copyright 2015 DennyZhang.com
## File : backup_gitlab.sh
## Author : Denny <denny.zhang001@gmail.com>
## Description :
## --
## Created : <2016-03-05>
## Updated: Time-stamp: <2016-03-05 10:14:51>
##-------------------------------------------------------------------
################################################################################################
## env variables:
##      server_ip_port: 123.57.240.189:22
##      env_parameters:
##          export KEEP_DAY=7
##          export ssh_key_file=/var/lib/jenkins/.ssh/id_rsa

function remove_hardline() {
    local str=$*
    echo "$str" | tr -d '\r'
}
# env parameters
env_parameters=$(remove_hardline "$env_parameters")
IFS=$'\n';
for env_variable in `echo "$env_parameters"`; do
    eval $env_variable
done
unset IFS

[ -n "$ssh_key_file" ] || ssh_key_file="/var/lib/jenkins/.ssh/id_rsa"
[ -n "$transfer_dst_path" ] || transfer_dst_path="/var/lib/jenkins/jobs/$JOB_NAME/workspace"

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
## File : backup_gitlab.sh ends
