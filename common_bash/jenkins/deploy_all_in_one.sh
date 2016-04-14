#!/bin/bash -ex
##-------------------------------------------------------------------
## @copyright 2016 DennyZhang.com
## File : deploy_all_in_one.sh
## Author : DennyZhang.com <denny@dennyzhang.com>
## Description :
## --
## Created : <2015-08-05>
## Updated: Time-stamp: <2016-04-14 16:52:21>
##-------------------------------------------------------------------

################################################################################################
## Purpose: General function to deploy all-in-one env by chef
##
## env variables:
##       ssh_server_ip: 123.57.240.189
##       ssh_port: 6022
##       chef_json:
##             {
##               "run_list": ["recipe[all-in-one-auth]"],
##               "os_basic_auth":{"repo_server":"123.57.240.189:28000"},
##               "all_in_one_auth":{"branch_name":"dev",
##               "install_audit":"1"}
##             }
##       chef_client_rb: cookbook_path ["/root/test/dev/mydevops/cookbooks","/root/test/dev/mydevops/community_cookbooks"]
##       check_command: enforce_all_nagios_check.sh "check_.*_log|check_.*_cpu"
##       devops_branch_name: master
##       env_parameters:
##             export STOP_CONTAINER=false
##             export KILL_RUNNING_CHEF_UPDATE=false
##             export START_COMMAND="docker start longrun-aio"
##             export POST_START_COMMAND="sleep 5; service apache2 start"
##             export PRE_STOP_COMMAND="service apache2 stop"
##             export STOP_COMMAND="docker stop longrun-aio"
##             export CODE_SH=""
##             export SSH_SERVER_PORT=22
##
## Hook points: START_COMMAND -> POST_START_COMMAND -> PRE_STOP_COMMAND -> STOP_COMMAND
################################################################################################
################################################################################################
if [ ! -f /var/lib/devops/refresh_common_library.sh ]; then
    [ -d /var/lib/devops/ ] || (sudo mkdir -p  /var/lib/devops/ && sudo chmod 777 /var/lib/devops)
    wget -O /var/lib/devops/refresh_common_library.sh \
         https://raw.githubusercontent.com/DennyZhang/devops_public/master/common_library/refresh_common_library.sh
fi
# export AVOID_REFRESH_LIBRARY=true
bash /var/lib/devops/refresh_common_library.sh "1582193298"
. /var/lib/devops/devops_common_library.sh
################################################################################################
function shell_exit() {
    errcode=$?
    if $STOP_CONTAINER; then
        if [ -n "$PRE_STOP_COMMAND" ]; then
            pre_stop_command='ssh $common_ssh_options -p $ssh_port root@$ssh_server_ip "$PRE_STOP_COMMAND"'
            log $pre_stop_command
            eval $pre_stop_command
        fi

        log "stop container."
        stop_command='ssh $common_ssh_options -p $SSH_SERVER_PORT root@$ssh_server_ip "$STOP_COMMAND"'
        log $stop_command
        eval $stop_command

    fi
    exit $errcode
}

########################################################################
trap shell_exit SIGHUP SIGINT SIGTERM 0

echo "Deploy to ${ssh_server_ip}:${ssh_port}"
env_parameters=$(remove_hardline "$env_parameters")
env_parameters=$(list_strip_comments "$env_parameters")
IFS=$'\n'
for env_variable in `echo "$env_parameters"`; do
    eval $env_variable
done
unset IFS

if [ -n "$STOP_CONTAINER" ] && $STOP_CONTAINER; then
    ensure_variable_isset "When STOP_CONTAINER is set, STOP_COMMAND must be given " "$STOP_COMMAND"
fi

log "env variables. KILL_RUNNING_CHEF_UPDATE: $KILL_RUNNING_CHEF_UPDATE, STOP_CONTAINER: $STOP_CONTAINER"

ssh_key_file="/var/lib/jenkins/.ssh/id_rsa"
kill_chef_command="killall -9 chef-solo || true"

if [ -n "$CODE_SH" ]; then
    ensure_variable_isset "Error: when CODE_SH is not empty, git_repo_url can't be empty" "$git_repo_url"
fi

if [ -z "$code_dir" ]; then
    code_dir="/root/test"
fi

# TODO: remove this section later
if [ -z "$chef_client_rb" ]; then
    git_repo="iamdevops"
    chef_client_rb="cookbook_path [\"$code_dir/$devops_branch_name/$git_repo/cookbooks\",\"$code_dir/$devops_branch_name/$git_repo/community_cookbooks\"]"
else
    chef_client_rb=$(echo $chef_client_rb | sed -e "s/ +/ /g")
fi

if [ -z "$SSH_SERVER_PORT" ]; then
    SSH_SERVER_PORT=22
fi

# TODO: ensure_variable_isset "chef_client_rb must be set" "$chef_client_rb"
common_ssh_options="-i $ssh_key_file -o StrictHostKeyChecking=no "

if [ -n "$START_COMMAND" ]; then
    start_command='ssh $common_ssh_options -p $SSH_SERVER_PORT root@$ssh_server_ip "$START_COMMAND"'
    log $start_command
    eval $start_command

    sleep 2

    post_start_command='ssh $common_ssh_options -p $ssh_port root@$ssh_server_ip "$POST_START_COMMAND"'
    log $post_start_command
    eval $post_start_command
fi

if $KILL_RUNNING_CHEF_UPDATE; then
    log $kill_chef_command
    ssh -i $ssh_key_file -p $ssh_port -o StrictHostKeyChecking=no root@$ssh_server_ip $kill_chef_command
fi

if [ -n "$CODE_SH" ]; then
    log "Update git codes"
    git_repo=$(echo ${git_repo_url%.git} | awk -F '/' '{print $2}')
    # ssh -i $ssh_key_file -p $ssh_port -o StrictHostKeyChecking=no root@$ssh_server_ip $CODE_SH $code_dir $git_repo_url $git_repo $devops_branch_name
    # TODO: remove this line and replace to above
    ssh -i $ssh_key_file -p $ssh_port -o StrictHostKeyChecking=no root@$ssh_server_ip $CODE_SH $code_dir $git_repo_url $git_repo $devops_branch_name "all-in-one"
fi

log "Prepare chef configuration"
echo "$chef_client_rb" > /tmp/client.rb
echo "$chef_json" > /tmp/client.json

scp -i $ssh_key_file -P $ssh_port -o StrictHostKeyChecking=no /tmp/client.rb root@$ssh_server_ip:/root/client.rb
scp -i $ssh_key_file -P $ssh_port -o StrictHostKeyChecking=no /tmp/client.json root@$ssh_server_ip:/root/client.json

log "Apply chef update"
ssh -i $ssh_key_file -p $ssh_port -o StrictHostKeyChecking=no root@$ssh_server_ip chef-solo --config /root/client.rb -j /root/client.json

if [ -n "$check_command" ]; then
    log "$check_command"
    ssh -i $ssh_key_file -p $ssh_port -o StrictHostKeyChecking=no root@$ssh_server_ip "$check_command"
fi
## File : deploy_all_in_one.sh ends
