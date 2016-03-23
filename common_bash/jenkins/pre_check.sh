#!/bin/bash -ex
##-------------------------------------------------------------------
## @copyright 2015 DennyZhang.com
## File : pre_check.sh
## Description :
## --
## Created : <2015-10-27>
## Updated: Time-stamp: <2016-01-20 15:35:26>
##-------------------------------------------------------------------
################################################################################################
## env variables:
##         export MAX_CONNECT_NUMBER=5
##         export WEBSITE_LIST="https://bitbucket.org http://baidu.com"
##         export JENKINS_JOB_STATUS_FILES="CommonServerCheck.flag"
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
    if [ $errcode -eq 0 ];then
        log "The pre_check has passed."
    else
        log "The pre_check has failed."
    fi
    exit $errcode
}

########################################################
##Function Name:    check_network
##Description:      Check the website if can connect
##Input:            max_connect_number,website_list
##Output:           0:success , 1:failed. 
########################################################
function check_network() 
{
    # The maximum number of trying to connect website
    local max_retries_count=${1:-3}
    
    # Check website whether can connect, multiple websites, separated by spaces
    local website_list=${2:-"https://bitbucket.org/"}

    # Connect timeout
    local timeout=7
    
    # The maximum allowable time data transmission
    local maxtime=10
    
    # If the website cannnt connect,will sleep several second
    local sleep_time=5
    
    # If any one website cannt connect,the flag value is false, otherwise is true.
    local check_flag=true
    
    log "max_retries_count=$max_retries_count, website_list=$website_list"
    
    connect_failed_website=""
    for website in ${website_list[*]}
    do
        for ((i=1; i <= $max_retries_count; i++))
        do
            # get http_code
            curl -I -s --connect-timeout $timeout -m $maxtime $website | tee website_tmp.txt
            ret=`cat website_tmp.txt | grep -q "200 OK" && echo yes || echo no`
            if [ "X$ret" = "Xyes" ]; then
                log "$website connect succeed"
                break
            fi
            if [ $i -eq $max_retries_count ];then
                log "$website connect failed"
                log "The curl result:"
                cat website_tmp.txt
                connect_failed_website="${connect_failed_website} ${website}"
                check_flag=false
                break
            fi
            sleep $sleep_time
        done
    done
    log "========== connect_failed_website= ${connect_failed_website}=========="
    if ! $check_flag ;then
        exit 1
    fi
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
        if test -f $flag_file ;then
            if [ `cat ${flag_file}` != "OK" ];then
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
IFS=$'\n'
for env_variable in `echo "$env_parameters"`; do
    eval $env_variable
done
unset IFS

if [ -n "$WEBSITE_LIST" ]; then
    #Check the network whether can connect.
    check_network "$MAX_CONNECT_NUMBER" "$WEBSITE_LIST"
fi

#Check the status of jenkins job:CommonServerCheck.
check_jenkins_job_status "$JENKINS_JOB_STATUS_FILES"

## File : pre_check.sh ends
