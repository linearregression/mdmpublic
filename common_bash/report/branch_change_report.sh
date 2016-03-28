#!/bin/bash -e
##-------------------------------------------------------------------
## @copyright 2016 DennyZhang.com
## File : branch_change_report.sh
## Author : Denny <denny@dennyzhang.com>
## Description :
## --
## Created : <2016-03-28>
## Updated: Time-stamp: <2016-03-28 22:10:43>
##-------------------------------------------------------------------

################################################################################################
## env variables:
##      git_repo_url: git@bitbucket.org:XXX/XXX.git
##      previous_release_branch: sprint-28
##      current_active_branch: sprint-29
##      env_parameters:
##          export working_dir=/var/lib/jenkins/code/branchchangereport/
################################################################################################
function remove_hardline() {
    local str=$*
    echo "$str" | tr -d '\r'
}

function git_update_code2() {
    set -e
    local git_repo=${1?}
    local git_repo_url=${2?}
    local working_dir=${3?}

    echo "Git update code for '$git_repo_url' to $working_dir"
    # checkout code, if absent
    if [ ! -d $working_dir/$git_repo ]; then
        mkdir -p $working_dir/
        cd $working_dir/
        git clone --depth 1 $git_repo_url
    else
        cd $working_dir/$git_repo
        git config remote.origin.url $git_repo_url
    fi
}

########################################################################
. /etc/profile

# Build Repo
git_repo=$(echo ${git_repo_url%.git} | awk -F '/' '{print $2}')

# Global variables needed to enable the current script
env_parameters=$(remove_hardline "$env_parameters")
IFS=$'\n'
for env_variable in `echo "$env_parameters"`; do
    eval $env_variable
done
unset IFS

if [ -z "$working_dir" ]; then
    working_dir=/var/lib/jenkins/code/
fi

if [ ! -d $working_dir ]; then
    sudo mkdir -p "$working_dir"
    sudo chown -R jenkins:jenkins "$working_dir"
fi

# Update code
git_update_code2 $git_repo $git_repo_url $working_dir
cd $working_dir/$git_repo

echo "Checkout branches: $previous_release_branch"
# Here we mute stdout/stderr on purpose, thus the report looks clean and clear
if ! $(git branch | grep $previous_release_branch 2>&1 1>/dev/null); then
    git branch $previous_release_branch 2>&1 1>/dev/null
fi
git pull origin $previous_release_branch 2>&1 1>/dev/null

echo "Checkout branches: $current_active_branch"
if ! $(git branch | grep $current_active_branch 2>&1 1>/dev/null); then
    git branch $current_active_branch 2>&1 1>/dev/null
fi
git pull origin $current_active_branch 2>&1 1>/dev/null

echo -e "\n ======= Generating ChangeSet Report: ========\n"
echo "Git Commit Messages: git show-branch $current_active_branch origin/$previous_release_branch $previous_release_branch"
git show-branch $current_active_branch origin/$previous_release_branch $previous_release_branch

echo -e "\n ============================================\n"
echo "Files Changed: git diff --stat $current_active_branch...$previous_release_branch"
git diff --stat $current_active_branch..$previous_release_branch
## File : branch_change_report.sh ends
