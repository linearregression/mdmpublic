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
##           export TOP_COUNT=10
##           export CONTEXT_COUNT=0
##           export CONSOLE_FILE="/tmp/console.log"
##           export SQLITE_FILE="/tmp/console.sqlite"
################################################################################################
env_dir="/tmp/env/"
env_file="$env_dir/$$"

echo "evaluate env"
if [ -n "$env_parameters" ]; then
    mkdir -p $env_dir
    echo "env_file_: $env_file Set env parameters:"
    echo "$env_parameters"
    cat > $env_file <<EOF
$env_parameters
EOF
    . $env_file
fi

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
