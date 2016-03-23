#!/bin/bash -e
##-------------------------------------------------------------------
## File : diagnostic_jenkinsjob_slow.sh
## Author : Denny <denny.zhang001@gmail.com>
## Co-Author :
## Description :
## --
## Created : <2016-01-06>
## Updated: Time-stamp: <2016-03-02 16:37:01>
##-------------------------------------------------------------------

################################################################################################
## env variables:
##       jenkins_job:
##       job_run_id:
##       env_parameters:
##           export jenkins_baseurl="http://inhousejenkins.jinganiam.com"
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
if [ -z "$PY_PATH" ]; then
    PY_PATH="/var/lib/jenkins/code/bash_dir/master/devops-knowledgebase/code/jenkins/diagnostic_jenkinsjob_slow/diagnostic_jenkinsjob_slow.py"
fi

echo "get console file"
url=$jenkins_baseurl/view/All/job/$jenkins_job/$job_run_id/consoleFull
curl -I $url | grep "HTTP/1.1 200"
curl -o $CONSOLE_FILE $url

echo "parse console"
rm -rf $SQLITE_FILE # TODO: remove later

python $PY_PATH
## File : diagnostic_jenkinsjob_slow.sh ends
