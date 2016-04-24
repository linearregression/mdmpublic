#!/bin/bash -ex
##-------------------------------------------------------------------
## @copyright 2016 DennyZhang.com
## Licensed under MIT 
##   https://raw.githubusercontent.com/DennyZhang/devops_public/master/LICENSE
##
## File : sonar_static_check.sh
## Author : DennyZhang.com <denny@dennyzhang.com>
## Description :
## --
## Created : <2015-07-03>
## Updated: Time-stamp: <2016-04-24 15:42:34>
##-------------------------------------------------------------------
################################################################################################
## env variables:
##      working_dir: /var/lib/jenkins/code
##      git_repo_url: git@bitbucket.org:XXX/XXX.git
##      branch_name: dev
##      branch_name: dev
##      revision: HEAD
##      env_parameters:
##         export SONAR_BASE_URL=http://localhost:9000
##         export SONAR_SOURCES=
##         export SONAR_TESTS=
##         export SONAR_PROJECTKEY=
##         export SONAR_PROJECTNAME=
##         export REFRESH_SONAR_CONF=true
##         export SONAR_LANGUAGE=java
################################################################################################
. /etc/profile
################################################################################################
if [ ! -f /var/lib/devops/refresh_common_library.sh ]; then
    [ -d /var/lib/devops/ ] || (sudo mkdir -p  /var/lib/devops/ && sudo chmod 777 /var/lib/devops)
    wget -O /var/lib/devops/refresh_common_library.sh \
         https://raw.githubusercontent.com/DennyZhang/devops_public/master/common_library/refresh_common_library.sh
fi
# export AVOID_REFRESH_LIBRARY=true
bash /var/lib/devops/refresh_common_library.sh "3767938096"
. /var/lib/devops/devops_common_library.sh
################################################################################################
function start_sonar_server() {
    local sonar_port="9000"
    if sudo lsof -i tcp:$sonar_port 2>/dev/null 1>/dev/null; then
        log "SonarQube server is already running"
    else
        log "Start SonarQube server: sonar.sh start" 
        sudo $SONARQUBE_HOME/bin/linux-x86-64/sonar.sh start
        log "Wait several seconds for SonarQube server to be up"
        sleep 30
    fi
}

function sonar_runner_project() {
    local code_dir=${1?}
    local git_repo=${2?}
    cd $code_dir
    [ -n "$SONAR_PROJECTKEY" ] || export SONAR_PROJECTKEY="test:$git_repo"
    [ -n "$SONAR_PROJECTNAME" ] || export SONAR_PROJECTNAME="$git_repo"
    [ -n "$SONAR_LANGUAGE" ] || export SONAR_LANGUAGE="java"
    if [ -z "$SONAR_SOURCES" ]; then
        if [ "$SONAR_LANGUAGE" = "java" ]; then
            main_list=$(find . -name main)
            main_list=$(echo $main_list | tr ' ' ',')
            export SONAR_SOURCES=$main_list
        else
            export SONAR_SOURCES="."
        fi
    fi

    if [ -f sonar-project.properties ] && ! $REFRESH_SONAR_CONF; then
        log "sonar-project.properties exists, reuse it"
    else
        log "generate sonar-project.properties"
        cat > sonar-project.properties <<EOF
# must be unique in a given SonarQube instance
sonar.projectKey=$SONAR_PROJECTKEY
# this is the name displayed in the SonarQube UI
sonar.projectName=$SONAR_PROJECTNAME
sonar.projectVersion=1.0
 
# Path is relative to the sonar-project.properties file. Replace "\" by "/" on Windows.
# Since SonarQube 4.2, this property is optional if sonar.modules is set. 
# If not set, SonarQube starts looking for source code from the directory containing 
# the sonar-project.properties file.
sonar.sources=$SONAR_SOURCES

# Encoding of the source code. Default is default system encoding
# sonar.sourceEncoding=UTF-8

sonar.tests=$SONAR_TESTS
# sonar.binaries=target/classes
sonar.language=$SONAR_LANGUAGE

EOF
    fi

    log "Run sonar-runner"
    sonar-runner

    [ -n "$SONAR_BASE_URL" ] || export SONAR_BASE_URL="http://localhost:9000"
    log "Code quality inspect report: $SONAR_BASE_URL/dashboard/index/$SONAR_PROJECTKEY"
}

################################################################################################
git_repo=$(echo ${git_repo_url%.git} | awk -F '/' '{print $2}')
code_dir=$working_dir/$branch_name/$git_repo

env_parameters=$(remove_hardline "$env_parameters")
env_parameters=$(string_strip_comments "$env_parameters")
IFS=$'\n'
for env_variable in `echo "$env_parameters"`; do
        eval $env_variable
done 
unset IFS

[ -n "$SONAR_BASE_URL" ] || SONAR_BASE_URL=$JENKINS_URL

# Update code
git_update_code $branch_name  $working_dir $git_repo_url "yes"
code_dir=$working_dir/$branch_name/$git_repo
cd $code_dir
# add retry for network turbulence
git pull origin $branch_name || (sleep 2 && git pull origin $branch_name)

cd $code_dir
git checkout $revision

# start SonarQube
start_sonar_server

# run SonarRunner
sonar_runner_project $code_dir $git_repo
## File : sonar_static_check.sh ends
