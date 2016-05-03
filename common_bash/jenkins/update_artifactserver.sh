#!/bin/bash -ex
##-------------------------------------------------------------------
## @copyright 2016 DennyZhang.com
## Licensed under MIT
##   https://raw.githubusercontent.com/DennyZhang/devops_public/master/LICENSE
##
## File : update_artifactserver.sh
## Author : DennyZhang.com <denny@dennyzhang.com>
## Description :
## --
## Created : <2015-08-05>
## Updated: Time-stamp: <2016-05-03 07:56:32>
##-------------------------------------------------------------------

################################################################################################
## env variables:
##       ssh_server_ip: 123.57.240.189
##       ssh_port:22
##       ssh_key_file:/var/lib/jenkins/.ssh/id_rsa
##       src_dir:/var/www/repo/dev
##       dst_dir:/var/www/repo/dev
##       tmp_dir:/tmp/artifact
################################################################################################
################################################################################################
if [ ! -f /var/lib/devops/refresh_common_library.sh ]; then
    [ -d /var/lib/devops/ ] || (sudo mkdir -p  /var/lib/devops/ && sudo chmod 777 /var/lib/devops)
    wget -O /var/lib/devops/refresh_common_library.sh \
         https://raw.githubusercontent.com/DennyZhang/devops_public/master/common_library/refresh_common_library.sh
fi
# export AVOID_REFRESH_LIBRARY=true
bash /var/lib/devops/refresh_common_library.sh "1141491927"
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

log "env variables. kill_running_chef_update: $kill_running_chef_update, STOP_CONTAINER: $STOP_CONTAINER"

# ssh_server_ip
if [ -z "$tmp_dir" ]; then
    tmp_dir="/root/artifact/"
fi

if [ -z "$src_dir" ]; then
    src_dir="/var/www/repo/dev"
fi

if [ -z "$dst_dir" ]; then
    dst_dir="/var/www/repo/dev"
fi

if [ -z "$ssh_key_file" ]; then
    ssh_key_file="/var/lib/jenkins/.ssh/id_rsa"
fi

if [ -z "$ssh_port" ]; then
    ssh_port="22"
fi

ssh -i $ssh_key_file -p "$ssh_port" -o StrictHostKeyChecking=no "root@$ssh_server_ip" mkdir -p $tmp_dir

log "scp files from local machine to $ssh_server_ip"
scp -i $ssh_key_file -P $ssh_port -o StrictHostKeyChecking=no -r $src_dir/* "root@$ssh_server_ip:/${tmp_dir}/"

log "make symbol link"
ssh -i $ssh_key_file -p $ssh_port -o StrictHostKeyChecking=no "root@$ssh_server_ip" rm -rf $dst_dir
ssh -i $ssh_key_file -p $ssh_port -o StrictHostKeyChecking=no "root@$ssh_server_ip" ln -s $tmp_dir $dst_dir
## File : update_artifactserver.sh ends
