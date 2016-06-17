#!/bin/bash -e
##-------------------------------------------------------------------
## @copyright 2016 DennyZhang.com
## Licensed under MIT
##   https://raw.githubusercontent.com/DennyZhang/devops_public/master/LICENSE
##
## File : monitor_git_branch_list.sh
## Author : DennyZhang.com <denny@dennyzhang.com>
## Description :
## --
## Created : <2015-08-05>
## Updated: Time-stamp: <2016-06-17 10:09:13>
##-------------------------------------------------------------------
################################################################################################
## env variables:
##      git_repo_url: git@bitbucket.org:XXX/XXX.git
##      branch_name: dev
##      activesprint_branch_pattern: ^sprint-[0-9]+$
##      env_parameters:
##         export mark_previous_fixed=false
##         export CLEAN_START=false
##         export working_dir=/var/lib/jenkins/code/monitorfile
################################################################################################
. /etc/profile
if [ ! -f /var/lib/devops/refresh_common_library.sh ]; then
    [ -d /var/lib/devops/ ] || (sudo mkdir -p  /var/lib/devops/ && sudo chmod 777 /var/lib/devops)
    wget -O /var/lib/devops/refresh_common_library.sh \
         https://raw.githubusercontent.com/DennyZhang/devops_public/master/common_library/refresh_common_library.sh
fi
bash /var/lib/devops/refresh_common_library.sh "1457168676"
. /var/lib/devops/devops_common_library.sh
################################################################################################
function git_ls_branch() {
    set -e
    local src_dir=${1?}
    cd "$src_dir"
    output=$(git ls-remote --heads origin)
    echo "$output" | awk -F'/' '{print $3}'
}

function detect_matched_branch() {
    # get all remote branches which match given pattern
    set -e
    local src_dir=${1?}
    local branch_pattern=${2?}
    branch_list=$(git_ls_branch "$src_dir")
    for branch in $branch_list; do
        if [[ $branch =~ $branch_pattern ]]; then
            echo "$branch"
        fi
    done
}

flag_file="/var/lib/jenkins/$JOB_NAME.flag"
previous_activesprint_file="/var/lib/jenkins/previous_activesprint_$JOB_NAME.flag"

function shell_exit() {
    errcode=$?
    if [ $errcode -eq 0 ]; then
        echo "OK" > "$flag_file"
    else
        echo "ERROR" > "$flag_file"
    fi
    exit $errcode
}
########################################################################
trap shell_exit SIGHUP SIGINT SIGTERM 0
source_string "$env_parameters"
[ -n "$working_dir" ] || working_dir="/var/lib/jenkins/code/$JOB_NAME"

git_repo=$(parse_git_repo "$git_repo_url")
code_dir="$working_dir/$branch_name/$git_repo"

if [ -n "$mark_previous_fixed" ] && $mark_previous_fixed; then
    rm -rf "$flag_file"
fi

if [ "$CLEAN_START" = "true" ]; then
    [ ! -d "$code_dir" ] || rm -rf "$code_dir"
    rm -rf "$flag_file"
    rm -rf "$previous_activesprint_file"
fi

# check previous failure
if [ -f "$flag_file" ] && [[ "$(cat "$flag_file")" = "ERROR" ]]; then
    echo "Previous check has failed"
    exit 1
fi

if [ ! -d "$working_dir" ]; then
    mkdir -p "$working_dir"
    chown -R jenkins:jenkins "$working_dir"
fi

touch "$previous_activesprint_file"
branch_whitelist=$(cat "$previous_activesprint_file")
echo -e "Previous ActiveSprint List: \n$branch_whitelist"

git_update_code "$branch_name" "$working_dir" "$git_repo_url"
matched_branch_list=$(detect_matched_branch "$code_dir" "$activesprint_branch_pattern")
echo -e "Potential Matched ActiveSprint List: \n$matched_branch_list"

if [ -n "$mark_previous_fixed" ] && $mark_previous_fixed; then
    echo "$matched_branch_list" > "$previous_activesprint_file"
    exit 0
fi

for branch in $matched_branch_list; do
    if [[ "${branch_whitelist}" == *"$branch"* ]]; then
        continue
    else
        echo "========== Matched branch: $branch"
        exit 1
    fi
done
## File : monitor_git_branch_list.sh ends
