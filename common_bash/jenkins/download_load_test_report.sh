#!/bin/bash -ex
##-------------------------------------------------------------------
## @copyright 2015 DennyZhang.com
## File : download_load_test_report.sh
## Description :
## --
## Created : <2015-09-24>
## Updated: Time-stamp: <2016-01-20 15:34:36>
##-------------------------------------------------------------------

################################################################################################
## env variables:
##       ssh_server_ip: 123.57.240.189
##       ssh_port: 6022
##       project_name: autotest-auth
##       chef_json:
##             {
##               "run_list": ["recipe[autotest-auth]"],
##               "autotest_auth":{"branch_name":"dev",
##                                "install_audit":"1"
##                               }
##             }
##       devops_branch_name: master
##       env_parameters:
##             export STOP_CONTAINER=false
##             export STOP_CONTAINER=true
##             export START_COMMAND="docker start osc-aio"
##             export STOP_COMMAND="docker stop osc-aio"
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
    rm -rf $env_file
    if [ $errcode -eq 0 ]; then
        log "Action succeeds."
        if ! $ALWAYS_KEEP_INSTANCE; then
            if [ -n "$STOP_COMMAND" ]; then
                stop_instance_command="ssh -i $ssh_key_file -o StrictHostKeyChecking=no root@$ssh_server_ip $STOP_COMMAND"
                log $stop_instance_command
                eval $stop_instance_command
            fi
        fi
    else
        log "Action Fails."
        if [ -n "$STOP_CONTAINER" ] && $STOP_CONTAINER; then
            if [ -n "$STOP_COMMAND" ]; then
                stop_instance_command="ssh -i $ssh_key_file -o StrictHostKeyChecking=no root@$ssh_server_ip $STOP_COMMAND"
                log $stop_instance_command
                eval $stop_instance_command
            fi
        fi
    fi
    exit $errcode
}


trap shell_exit SIGHUP SIGINT SIGTERM 0

########################################################################
echo "Deploy to ${ssh_server_ip}:${ssh_port}"
env_dir="/tmp/env/"
env_file="$env_dir/$$"
env_parameters=$(remove_hardline "$env_parameters")
if [ -n "$env_parameters" ]; then
    mkdir -p $env_dir
    log "env file: $env_file. Set env parameters:"
    log "$env_parameters"
    cat > $env_file <<EOF
$env_parameters
EOF
    . $env_file
fi

log "Start to copy the remote report file..."

jenkins_job_name="${test_report_url##*/}"
log "variables. test_report_url: $test_report_url, jenkins_job_name=$jenkins_job_name, workspace_path=$workspace_path"

ssh_key_file="/var/lib/jenkins/.ssh/id_rsa"
report_file_name="jmeter.html"
report_check_log="/etc/jmeter/plans.d/verify_load_test.log"
report_remote_path="/etc/jmeter/plans.d/$report_file_name"

report_dir_name="TestReport_`date +'%Y%m%d%H%M%S'`"
report_dir_path="$workspace_path/$report_dir_name"

if [ -z "$ssh_server_port" ]; then
    start_instance_command="ssh -i $ssh_key_file -o StrictHostKeyChecking=no root@$ssh_server_ip $START_COMMAND"
else
    start_instance_command="ssh -i $ssh_key_file -p $ssh_server_port -o StrictHostKeyChecking=no root@$ssh_server_ip $START_COMMAND"    
fi

if [ -n "$START_COMMAND" ]; then
    log $start_instance_command
    eval $start_instance_command
    sleep 5
fi

ssh -i $ssh_key_file -p $ssh_port -o StrictHostKeyChecking=no root@$ssh_server_ip test -f $report_remote_path
if [ $? -ne 0 ];then
    log "The load test report file don't be found in the container."
    exit 1
fi

mkdir -p $report_dir_path

scp -i $ssh_key_file -P $ssh_port -o StrictHostKeyChecking=no root@$ssh_server_ip:${report_remote_path%/*}/* $report_dir_path
scp -i $ssh_key_file -P $ssh_port -o StrictHostKeyChecking=no root@$ssh_server_ip:$report_check_log $report_dir_path
cat $report_dir_path/${report_check_log##*/}
result=$(cat $report_dir_path/${report_check_log##*/} | grep -w "Check failed" | sed -n '1p')

log "If you want to view all the load test result file, please click the link: $test_report_url/ws/$report_dir_name."
log "If you only want to view the load test report file, please click the link: $test_report_url/ws/$report_dir_name/$report_file_name."

if [ ! -z "$result" ];then
    log "=======LoadTest Check failed.======="
    exit 1
fi
## File : download_load_test_report.sh ends