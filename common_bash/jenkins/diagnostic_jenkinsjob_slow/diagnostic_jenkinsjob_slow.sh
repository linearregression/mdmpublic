# -*- coding: utf-8 -*-
#!/bin/bash -ex
##-------------------------------------------------------------------
## @copyright 2015 DennyZhang.com
## File : diagnostic_jenkinsjob_slow.sh
## Author : Denny <denny.zhang001@gmail.com>
## Description :
## --
## Created : <2016-01-15>
## Updated: Time-stamp: <2016-01-20 15:34:21>
##-------------------------------------------------------------------
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

echo "get console file"
# TODO: remove this hardcode
curl -o $CONSOLE_FILE http://inhousejenkins.jinganiam.com/view/All/job/$jenkins_job/$job_run_id/consoleFull

echo "parse console"
rm -rf $SQLITE_FILE # TODO: remove later
# TODO: change this
python /var/lib/jenkins/code/bash_dir/master/devops-knowledgebase/code/jenkins/diagnostic_jenkinsjob_slow/diagnostic_jenkinsjob_slow.py
## File : diagnostic_jenkinsjob_slow.sh ends
