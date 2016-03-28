#!/bin/bash -e
##-------------------------------------------------------------------
## @copyright 2015 DennyZhang.com
## File : jenkins_code_pull.sh
## Author : Denny <denny@dennyzhang.com>
## Description :
## --
## Created : <2015-07-03>
## Updated: Time-stamp: <2016-03-28 16:27:16>
##-------------------------------------------------------------------

################################################################################################
## env variables:
##      git_pull_list:
##               /var/lib/jenkins/code/bash_dir/,git@XXX:XXX/XXX.git,master
##               /var/lib/jenkins/code/dockerfeaturemustpass/,git@XXX:XXX/XXX.git,dev
##               /var/lib/jenkins/code/dockerbasicmustpass/,git@XXX:XXX/XXX.git,dev
##               /var/lib/jenkins/code/dockerallinonemustpass/,git@XXX:XXX/XXX.git,dev
##               /var/lib/jenkins/code/codestylemustpass/,git@XXX:XXX/XXX.git,dev
################################################################################################
function remove_hardline() {
    local str=$*
    echo "$str" | tr -d '\r'
}

function current_git_sha() {
    set -e
    local src_dir=${1?}
    cd $src_dir
    sha=$(git log -n 1 | head -n 1 | grep commit | head -n 1 | awk -F' ' '{print $2}')
    echo $sha
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

function shell_exit() {
    errcode=$?
    exit $errcode
}

trap shell_exit SIGHUP SIGINT SIGTERM 0

. /etc/profile
########################################################################

for git_pull in `echo $git_pull_list`; do
    git_pull=`echo $git_pull | sed 's/,/ /g'`
    item=($git_pull)
    working_dir=${item[0]}
    git_repo_url=${item[1]}
    git_repo=$(echo ${git_repo_url%.git} | awk -F '/' '{print $2}')
    branch_name=${item[2]}
    log "git pull in working_dir"
    git_update_code $git_repo $git_repo_url $branch_name $working_dir "no"
done
## File : jenkins_code_pull.sh ends
