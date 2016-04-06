#!/bin/bash -ex
##-------------------------------------------------------------------
## @copyright 2015 DennyZhang.com
## File : update_artifactserver.sh
## Author : Denny <denny@dennyzhang.com>
## Description :
## --
## Created : <2015-08-05>
## Updated: Time-stamp: <2016-04-06 07:01:35>
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
function remove_hardline() {
    local str=$*
    echo "$str" | tr -d '\r'
}

function log() {
    local msg=$*
    echo -ne `date +['%Y-%m-%d %H:%M:%S']`" $msg\n"
}

########################################################################

# Global variables needed to enable the current script
env_parameters=$(remove_hardline "$env_parameters")
env_parameters=$(list_strip_comments "$env_parameters")
IFS=$'\n'
for env_variable in `echo "$env_parameters"`; do
    eval $env_variable
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

ssh -i $ssh_key_file -p $ssh_port -o StrictHostKeyChecking=no root@$ssh_server_ip mkdir -p $tmp_dir

log "scp files from local machine to $ssh_server_ip"
scp -i $ssh_key_file -P $ssh_port -o StrictHostKeyChecking=no -r $src_dir/* root@$ssh_server_ip:/$tmp_dir/

log "make symbol link"
ssh -i $ssh_key_file -p $ssh_port -o StrictHostKeyChecking=no root@$ssh_server_ip rm -rf $dst_dir
ssh -i $ssh_key_file -p $ssh_port -o StrictHostKeyChecking=no root@$ssh_server_ip ln -s $tmp_dir $dst_dir
## File : update_artifactserver.sh ends
