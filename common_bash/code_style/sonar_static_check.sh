#!/bin/bash -ex
##-------------------------------------------------------------------
## @copyright 2015 DennyZhang.com
## File : sonar_static_check.sh
## Author : Denny <denny.zhang001@gmail.com>
## Description :
## --
## Created : <2015-07-03>
## Updated: Time-stamp: <2016-01-21 21:47:04>
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
function remove_hardline() {
    local str=$*
    echo "$str" | tr -d '\r'
}

function log() {
    local msg=$*
    echo -ne `date +['%Y-%m-%d %H:%M:%S']`" $msg\n"
}

function git_update_code() {
    set -e
    local git_repo=${1?}
    local git_repo_url=${2?}
    local branch_name=${3?}
    local working_dir=${4?}
    local git_pull_outside=${5:-"no"}

    log "Git update code for '$git_repo_url' to $working_dir, branch_name: $branch_name"
    # checkout code, if absent
    if [ ! -d $working_dir/$branch_name/$git_repo ]; then
        mkdir -p $working_dir/$branch_name
        cd $working_dir/$branch_name
        git clone --depth 1 $git_repo_url --branch $branch_name --single-branch
    else
        cd $working_dir/$branch_name/$git_repo
        git config remote.origin.url $git_repo_url
        if [ $git_pull_outside = "no" ]; then
            # add retry for network turbulence
            git pull origin $branch_name || (sleep 2 && git pull origin $branch_name)
        fi
    fi

    cd $working_dir/$branch_name/$git_repo
    #git reset --hard
    git checkout $branch_name
}

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
. /etc/profile
git_repo=$(echo ${git_repo_url%.git} | awk -F '/' '{print $2}')
code_dir=$working_dir/$branch_name/$git_repo

env_dir="/tmp/env/"
env_file="$env_dir/$$"
env_parameters=$(remove_hardline "$env_parameters")
if [ -n "$env_parameters" ]; then
    mkdir -p $env_dir
    log "env file: snar_static_check.sh Set env parameters:"
    log "$env_parameters"
    cat > $env_file <<EOF
$env_parameters
EOF
    . $env_file
fi

# Update code
git_update_code $git_repo $git_repo_url $branch_name $working_dir "yes"
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