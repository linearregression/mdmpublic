#!/bin/bash -xe
################################################################################################
## @copyright 2016 DennyZhang.com
## Licensed under MIT
##   https://raw.githubusercontent.com/DennyZhang/devops_public/master/LICENSE
##
## File : collect_files.sh
## Author : Denny <denny@dennyzhang.com>
## Description : collect the files across servers, and transfer to specific destination
## --
## Created : <2016-04-14>
## Updated: Time-stamp: <2016-05-02 21:31:25>
##-------------------------------------------------------------------

################################################################################################
## env variables:
##      server_list:
##         # Jenkins
##         172.17.0.2:22
##         # Gitlab
##         172.17.0.4:22
##         # Atlassian: JIRA/Confluence
##         172.17.0.3:22
##
##      files_list:
##         # Jenkins backup
##         eval: find /var/lib/jenkins/jobs -name config.xml
##         # Confluence backup
##         eval: find /var/atlassian/application-data/confluence/backups/ -name *.zip | head -n 1
##         # JIRA backup
##         eval: find /var/atlassian/application-data/jira/export/ -name *.zip | head -n 1
##         # Gitlab backup
##         eval: find /var/opt/gitlab/backups -name *.tar | head -n 1
##
##      env_parameters:
##          export ssh_key_file="/var/lib/jenkins/.ssh/id_rsa"
##          export REMOVE_PREVIOUS_DOWNLOAD=false
##          export KEEP_DAY=7
##          export SERVER_REMOTE_COPY="104.236.159.226:22:/data/backup/server1"
##          export JENKINS_BASEURL="http://123.57.240.189:58080"
##
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
############################## Function Start ##################################################
function data_retention() {
    local keep_day=${1?}
    local server_list=${2?}
    echo "=============== Remove old files to clean up disk"
    for server in ${server_list[*]}
    do
        local server_split=(${server//:/ })
        local server_ip=${server_split[0]}
        local server_port=${server_split[1]}
        local ssh_connect="ssh -i $ssh_key_file -p $server_port -o StrictHostKeyChecking=no root@$server_ip"
        if [ "x$(check_ssh_available "$server_ip" "$server_port")" = "xyes" ]; then
            echo "Delete expired file in $server"
            $ssh_connect "cd $save_path/$JOB_NAME-*-$server_ip-$server_port && find . -name \"$JOB_NAME*\" -mtime +$keep_day -exec rm -rfv {} \+"
        else
            echo "Error: Fail to ssh $server_ip:$server_port"
        fi
    done

    echo "rm obselete files under $transfer_dst_path older than $keep_day"
    find "$transfer_dst_path" -name "*.tar.gz*" -mtime "+$keep_day" -and -not -type d -delete
}

function collect_files_by_host() {
    local server_ip=${1?}
    local server_port=${2?}
    local work_path=${3?}
    local files_list=${4?}

    local ssh_connect="ssh -i $ssh_key_file -p $server_port -o StrictHostKeyChecking=no root@$server_ip"

    # loop files_list
    IFS=$'\n'
    for t_file in ${files_list[*]}
    do
        unset IFS
        if [[ "$t_file" = "eval: "* ]]; then
            echo "Evaluate file list: $t_file"
            local eval_command=${t_file#"eval: "}
            set +e
            ssh_result=$($ssh_connect "$eval_command")
            if [ $? -ne 0 ] || [ -z "$ssh_result" ]; then
                echo "Warning: Fail to run $eval_command"
            else
                collect_files_by_host "$server_ip" "$server_port" "$work_path" "$ssh_result"
            fi
            # TODO: restore set -e setting
        else
            echo "Collect files:$t_file"
            ssh_result=$($ssh_connect test -r "$t_file" && echo yes || echo no)
            if [ "x$ssh_result" == "xno" ]; then
                echo "Warning: file [$t_file] not readable"
                continue
            fi

            # copy files
            file_parent_dir=${t_file%/*}
            save_pathname=${file_parent_dir#*/}
            file_name=${t_file##*/}

            $ssh_connect "mkdir -p $work_path/$save_pathname"
            $ssh_connect "cp -r $t_file $work_path/$save_pathname/$file_name"
        fi
    done
}

function collect_files() {
    local server_list=${1?}
    local files_list=${2?}

    for server in ${server_list[*]}
    do
        local server_split=(${server//:/ })
        local server_ip=${server_split[0]}
        local server_port=${server_split[1]}
        local server_hostname
        local file_count

        local ssh_connect="ssh -i $ssh_key_file -p $server_port -o StrictHostKeyChecking=no root@$server_ip"

        echo "=============== Collect files from $server_ip:$server_port"
        if [ "x$(check_ssh_available "$server_ip" "$server_port")" = "xyes" ]; then
            server_hostname=$($ssh_connect "hostname")

            local dir_by_hostname="${JOB_NAME}-${server_hostname}-${server_ip}-${server_port}"
            local dir_by_time="${JOB_NAME}-${server_ip}-${server_port}-${collect_time}"
            local work_path="${save_path}/${dir_by_hostname}/${dir_by_time}"
            $ssh_connect "[ -d $work_path ] || mkdir -p $work_path"
            collect_files_by_host "$server_ip" "$server_port" "$work_path" "$files_list"

            file_count=$($ssh_connect "ls $work_path | wc -l")
            if [ "$file_count" -gt 0 ]; then
                # Compress named:hostname-server_ip-server_port-current_time files
                echo "Compress collected files at $server"
                local dir_by_hostname_path="${save_path}/${dir_by_hostname}"
                $ssh_connect "cd ${dir_by_hostname_path} && tar -zcvf ${dir_by_time}.tar.gz ${dir_by_time} 1>/dev/null && rm -rf $work_path"

                echo "scp ${work_path}.tar.gz to Jenkins node $transfer_dst_path/"
                ssh_command="scp -P $server_port -i $ssh_key_file -o StrictHostKeyChecking=no root@$server_ip:/${work_path}.tar.gz $transfer_dst_path/"
                $ssh_command
                # TODO: improve werid logic
                tar_list+=("\n${work_path}.tar.gz")
            fi
        else
            echo "Error: Fail to ssh $server_ip:$server_port"
        fi
    done
}

############################## Function End ####################################################

############################## Shell Start #####################################################
# evaulate env
IFS=$'\n'
for env_variable in $env_parameters; do
    eval "$env_variable"
done
unset IFS

ensure_variable_isset "ERROR wrong parameter: server_list can't be empty" "$server_list"
ensure_variable_isset "ERROR wrong parameter: files_list can't be empty" "$files_list"
ensure_variable_isset "ERROR wrong parameter: JOB_NAME can't be empty" "$JOB_NAME"

collect_time=$(date +'%Y%m%d-%H%M%S')
[ -n "$ssh_key_file" ] || ssh_key_file="/var/lib/jenkins/.ssh/id_rsa"

server_list=$(string_strip_comments "$server_list")
files_list=$(string_strip_comments "$files_list")

# Set default value
[ -n "$KEEP_DAY" ] || KEEP_DAY="7"
[ -n "$JENKINS_BASEURL" ] || JENKINS_BASEURL=$JENKINS_URL

[ -n "$transfer_dst_path" ] || transfer_dst_path="/var/lib/jenkins/jobs/$JOB_NAME/workspace"
[ -n "$save_path" ] || save_path="/tmp/"

if [ -z "$REMOVE_PREVIOUS_DOWNLOAD" ] || $REMOVE_PREVIOUS_DOWNLOAD; then
    echo "Remove previous files: $transfer_dst_path"
    rm -rf "${transfer_dst_path:?}"/*
fi

# Connect server and collect files
collect_files "$server_list" "$files_list" $KEEP_DAY

data_retention $KEEP_DAY "$server_list"

if [ -n "$SERVER_REMOTE_COPY" ]; then
    echo "=============== Copy collected files to remote server"
    my_list=(${SERVER_REMOTE_COPY//:/ })
    remote_server_ip=${my_list[0]}
    remote_server_port=${my_list[1]}
    remote_dst_dir=${my_list[2]}

    ssh_command="ssh -o StrictHostKeyChecking=no -p $remote_server_port root@$remote_server_ip mkdir -p $remote_dst_dir"
    $ssh_command

    ssh_command="scp -P $remote_server_port -r $transfer_dst_path/* root@$remote_server_ip:$remote_dst_dir"
    echo "$ssh_command"
    $ssh_command
fi

# Print download link at the bottom
if [ -n "$JENKINS_BASEURL" ]; then
    echo -e "=============== Download link:\n${JENKINS_BASEURL}/job/${JOB_NAME}/ws/"
fi
############################## Shell End #######################################################
