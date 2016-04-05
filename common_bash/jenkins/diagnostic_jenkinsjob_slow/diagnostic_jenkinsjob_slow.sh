#!/bin/bash -e
##-------------------------------------------------------------------
## File : diagnostic_jenkinsjob_slow.sh
## Author : Denny <denny@dennyzhang.com>
## Co-Author :
## Description :
## --
## Created : <2016-01-06>
## Updated: Time-stamp: <2016-04-05 17:52:06>
##-------------------------------------------------------------------

################################################################################################
## env variables:
##       jenkins_job:
##       job_run_id:
##       env_parameters:
##           export jenkins_baseurl="http://jenkins.dennyzhang.com"
##           export top_count=10
##           export context_count=0
##           export console_file="/tmp/console.log"
##           export sqlite_file="/tmp/console.sqlite"
################################################################################################

echo "evaluate env"
IFS=$'\n'
for env_variable in `echo "$env_parameters"`; do
    eval $env_variable
done
unset IFS

# set default value
dir_name=$(dirname $0)
py_file="${dir_name}/diagnostic_jenkinsjob_slow.py"

echo "get console file"
url=$jenkins_baseurl/view/All/job/$jenkins_job/$job_run_id/consoleFull
curl -I $url | grep "HTTP/1.1 200"
curl -o $CONSOLE_FILE $url

echo "parse console"
rm -rf $SQLITE_FILE # TODO: remove later

python $py_file
## File : diagnostic_jenkinsjob_slow.sh ends
