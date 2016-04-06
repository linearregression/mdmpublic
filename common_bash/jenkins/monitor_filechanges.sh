#!/bin/bash -e
##-------------------------------------------------------------------
## @copyright 2015 DennyZhang.com
## File : monitor_filechanges.sh
## Author : Denny <denny@dennyzhang.com>
## Description :
## --
## Created : <2015-08-05>
## Updated: Time-stamp: <2016-04-06 07:01:36>
##-------------------------------------------------------------------

################################################################################################
## env variables:
##      working_dir: /var/lib/jenkins/code/monitorfile
##      git_repo_url: git@bitbucket.org:XXX/XXX.git
##      filelist_to_monitor:
##          account/src/main/resources/XXX.properties
##          account/service/src/test/resources/XXX.js
##          audit/src/main/resources/XXX.properties
##          gateway/protection/src/main/resources/config/XXX.json
##          gateway/protection/src/main/resources/config/routes/XXX.json
##      branch_name: dev
##      env_parameters:
##         export mark_previous_fixed=false
##         export CLEAN_START=false
##
################################################################################################
function remove_hardline() {
    local str=$*
    echo "$str" | tr -d '\r'
}

function list_strip_comments() {
    my_list=$(echo "$my_list" | grep -v '^#')
    echo "$my_list"
}

function log() {
    local msg=$*
    echo -ne `date +['%Y-%m-%d %H:%M:%S']`" $msg\n"
}

################################################################################################
function git_update_code() {
    set -e
    local git_repo=${1?}
    local branch_name=${2?}
    local working_dir=${3?}
    local git_repo_url=${4?}
    local git_pull_outside=${5:-"no"}

    echo "Git update code for '$git_repo_url' to $working_dir, branch_name: $branch_name"
    # checkout code, if absent
    if [ ! -d $working_dir/$branch_name/$git_repo ]; then
        mkdir -p $working_dir/$branch_name
        cd $working_dir/$branch_name
        git clone --depth 1 $git_repo_url --branch $branch_name --single-branch
    else
        cd $working_dir/$branch_name/$git_repo
        git config remote.origin.url $git_repo_url
        # add retry for network turbulence
        git pull origin $branch_name || (sleep 2 && git pull origin $branch_name)
    fi

    cd $working_dir/$branch_name/$git_repo
    git checkout $branch_name
    git reset --hard
}

function current_git_sha() {
    set -e
    local src_dir=${1?}
    cd $src_dir
    sha=$(git log -n 1 | grep commit | head -n 1 | awk -F' ' '{print $2}')
    echo $sha
}

function git_changed_filelist() {
    set -e
    local src_dir=${1?}
    local old_sha=${2?}
    local new_sha=${3?}
    cd $src_dir
    git diff --name-only $old_sha $new_sha
}

function detect_changed_file() {
    set -e
    local src_dir=${1?}
    local old_sha=${2?}
    local new_sha=${3?}
    local files_to_monitor=${4?}
    local file_list=$(git_changed_filelist $src_dir $old_sha $new_sha)

    echo -ne "\n\n==========""git diff --name-only ${old_sha}..${new_sha}\n"
    echo $file_list
    IFS=$'\n'
    for file in ${file_list[*]}; do
      if echo -ne "$files_to_monitor" | grep "$file" 1>/dev/null 2>1; then
         echo -ne "\n\n=========="" $file is changed!"
         changed_file_list="$changed_file_list $file"
      fi
    done
}

flag_file="/var/lib/jenkins/$JOB_NAME.flag"

function shell_exit() {
    errcode=$?
    if [ $errcode -eq 0 ]; then
        echo "OK"> $flag_file
    else
        echo "ERROR"> $flag_file
    fi
    exit $errcode
}

########################################################################
trap shell_exit SIGHUP SIGINT SIGTERM 0

log "env variables. CLEAN_START: $CLEAN_START"

git_repo=$(echo ${git_repo_url%.git} | awk -F '/' '{print $2}')
code_dir=$working_dir/$branch_name/$git_repo

# Global variables needed to enable the current script
env_parameters=$(remove_hardline "$env_parameters")
env_parameters=$(list_strip_comments "$env_parameters")
IFS=$'\n'
for env_variable in `echo "$env_parameters"`; do
    eval $env_variable
done
unset IFS

filelist_to_monitor=$(list_strip_comments "$filelist_to_monitor")
if [ -n "$mark_previous_fixed" ] && $mark_previous_fixed; then
    rm -rf $flag_file
fi

# check previous failure
if [ -f $flag_file ] && [[ `cat $flag_file` = "ERROR" ]]; then
    echo "Previous check has failed"
    exit 1
fi

if [ -n "$CLEAN_START" ] && $CLEAN_START; then
  [ ! -d $code_dir ] || rm -rf $code_dir
fi

if [ ! -d $working_dir ]; then
   mkdir -p "$working_dir"
   chown -R jenkins:jenkins "$working_dir"
fi

if [ -d $code_dir ]; then
  old_sha=$(current_git_sha $code_dir)
else
  old_sha=""
fi

# Update code
git_update_code $git_repo $branch_name $working_dir $git_repo_url
cd $working_dir/$branch_name/$git_repo
# add retry for network turbulence
git pull origin $branch_name || (sleep 2 && git pull origin $branch_name)

changed_file_list=""
cd $code_dir

new_sha=$(current_git_sha $code_dir)

if [ -z "$old_sha" ] || [ $old_sha = $new_sha ]; then
    log -ne "\n\n========== ""Latest git sha is $old_sha. No commits since last git pull\n\n"
else
    detect_changed_file $code_dir $old_sha $new_sha "$filelist_to_monitor"
    if [ -n "$changed_file_list" ]; then
        log -ne "\n\n==========""git diff $old_sha $new_sha\n"
        log -ne "\n\n=====================\n\n"
        log -ne "ERROR file changed: \n`echo "$changed_file_list" | tr ' ' '\n'`\n"
        exit 1
    fi
fi
## File : monitor_filechanges.sh ends
