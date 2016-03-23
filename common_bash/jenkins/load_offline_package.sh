#!/bin/bash -e
##-------------------------------------------------------------------
## @copyright 2015 DennyZhang.com
## File : load_offline_package.sh
## Author : Manley <liumingli@jingantech.com>
## Co-Author : UU <youyou.li78@gmail.com>
## Description :
## --
## Created : <2016-01-06>
## Updated: Time-stamp: <2016-01-20 15:34:44>
##-------------------------------------------------------------------

################################################################################################
## env variables:
##       from_server: 172.17.0.2:22
##       to_server_list: 172.17.0.2:4022
##                       172.17.0.2:6022
##       package_location: /root/install_file/XXX.tar.gz
##       package_new_location: /var/www/repo/download
################################################################################################

function remove_hardline() {
    local str=$*
    echo "$str" | tr -d '\r'
}

function log() {
    local msg=$*
    echo -ne `date +['%Y-%m-%d %H:%M:%S']`" $msg\n"
}

function shell_exit() {
    errcode=$?

    END=$(date +%s)
    DIFF=$(echo "$END - $START" | bc)
    log "Track time spent: $DIFF seconds"
    if [ $errcode -eq 0 ]; then
        log "Load file successfully."
    else
        log "ERROR: Load file failed"
    fi

    log "rm tmp dir:${tmp_dir}"
    rm -rf $tmp_dir
    
    exit $errcode
}

########################################################################
trap shell_exit SIGHUP SIGINT SIGTERM 0

log "Deploy to ${ssh_server_ip}:${ssh_port}"
log "From server: ${from_server}"

from_server_split=(${from_server//:/ })
from_ssh_server_ip=${from_server_split[0]}
from_ssh_port=${from_server_split[1]}

START=$(date +%s)

# Global variables needed to enable the current script
env_parameters=$(remove_hardline "$env_parameters")
IFS=$'\n'
for env_variable in `echo "$env_parameters"`; do
    eval $env_variable
done
unset IFS

log "The parameter :package_location=${package_location}, package_new_location=${package_new_location}"
ssh_key_file="/var/lib/jenkins/.ssh/id_rsa"

common_ssh_options="-i $ssh_key_file -o StrictHostKeyChecking=no "

if [ -z "${package_location}" ];then
    log "The parameter package_location is invalid."
    exit 1
fi
if [ -z "${package_new_location}" ];then
    log "The parameter package_new_location is invalid."
    exit 1
fi

tmp_dir="/tmp/load_offline_package"
log "make tmp dir:${tmp_dir}"
[ -d $tmp_dir ] || mkdir -p $tmp_dir

package_tar_file=`basename ${package_location}`

log "scp ${package_location} to tmp dir:${tmp_dir}"
scp ${common_ssh_options} -P ${from_ssh_port} root@${from_ssh_server_ip}:${package_location} ${tmp_dir}/${package_tar_file}

# Copy the file from the docker demo server or repo lab
for server in ${to_server_list}
do
    log "scp to server:$server"
    server_split=(${server//:/ })
    ssh_server_ip=${server_split[0]}
    ssh_port=${server_split[1]}

    ssh ${common_ssh_options} -p ${ssh_port} root@${ssh_server_ip} [ -d ${package_new_location} ] || mkdir -p ${package_new_location}
    scp ${common_ssh_options} -P ${ssh_port} ${tmp_dir}/${package_tar_file} root@$ssh_server_ip:${package_new_location}

    ssh ${common_ssh_options} -p ${ssh_port} root@${ssh_server_ip} tar zxf ${package_new_location}/${package_tar_file} -C ${package_new_location}/

    ssh ${common_ssh_options} -p ${ssh_port} root@${ssh_server_ip} rm -f ${package_new_location}/${package_tar_file}

    ssh ${common_ssh_options} -p ${ssh_port} root@${ssh_server_ip} chmod -R 755 ${package_new_location}
    log "scp to server:$server ok"
done

log "Load package successfully."
