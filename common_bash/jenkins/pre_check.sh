#!/bin/bash -ex
##-------------------------------------------------------------------
## @copyright 2016 DennyZhang.com
## Licensed under MIT
##   https://raw.githubusercontent.com/DennyZhang/devops_public/master/LICENSE
##
## File : pre_check.sh
## Description :
## --
## Created : <2015-10-27>
## Updated: Time-stamp: <2016-04-26 23:11:16>
##-------------------------------------------------------------------
################################################################################################
## env variables:
##         export MAX_CONNECT_NUMBER=5
##         export WEBSITE_LIST="https://bitbucket.org http://baidu.com"
##         export JENKINS_JOB_STATUS_FILES="CommonServerCheck.flag"
################################################################################################
################################################################################################
if [ ! -f /var/lib/devops/refresh_common_library.sh ]; then
    [ -d /var/lib/devops/ ] || (sudo mkdir -p  /var/lib/devops/ && sudo chmod 777 /var/lib/devops)
    wget -O /var/lib/devops/refresh_common_library.sh \
         https://raw.githubusercontent.com/DennyZhang/devops_public/master/common_library/refresh_common_library.sh
fi
# export AVOID_REFRESH_LIBRARY=true
bash /var/lib/devops/refresh_common_library.sh "2993535181"
. /var/lib/devops/devops_common_library.sh
################################################################################################
function shell_exit() {
    errcode=$?
    if [ $errcode -eq 0 ];then
        log "The pre_check has passed."
    else
        log "The pre_check has failed."
    fi
    exit $errcode
}

########################################################
##Function Name:    check_jenkins_job_status
##Description:      Check the status of designated jenkins job
##Input:            jenkins_job_status_files
##Output:           0:success , 1:failed.
########################################################
function check_jenkins_job_status()
{
    # The status flag file list for all the jenkins jobs，multiple files, separated by spaces
    jenkins_job_status_files=${1:-"CommonServerCheck.flag"}

    # If status of any one flag file is not OK,the flag value is false, otherwise is true.
    local check_flag=true

    for flag_file_name in ${jenkins_job_status_files[*]}
    do
        local flag_file="/var/lib/jenkins/$flag_file_name"
        if test -f "$flag_file" ;then
            if [ "$(cat "$flag_file")" != "OK" ];then
                log "The status of $flag_file is ERROR."
                check_flag=false
            else
                log "The status of $flag_file is OK."
            fi
        else
            log "The flag file:$flag_file doesn't be found."
        fi
    done
    if ! $check_flag ;then
        exit 1
    fi
}

########################################################################
trap shell_exit SIGHUP SIGINT SIGTERM 0

echo "Check the env befor operating..."

# Global variables needed to enable the current script
env_parameters=$(remove_hardline "$env_parameters")
env_parameters=$(string_strip_comments "$env_parameters")
IFS=$'\n'
for env_variable in $env_parameters; do
    eval "$env_variable"
done
unset IFS

if [ -n "$WEBSITE_LIST" ]; then
    #Check the network whether can connect.
    check_network "$MAX_CONNECT_NUMBER" "$WEBSITE_LIST"
fi

#Check the status of jenkins job:CommonServerCheck.
check_jenkins_job_status "$JENKINS_JOB_STATUS_FILES"

## File : pre_check.sh ends
