#!/bin/bash -e
##-------------------------------------------------------------------
## @copyright 2016 DennyZhang.com
## Licensed under MIT
##   https://raw.githubusercontent.com/DennyZhang/devops_public/master/LICENSE
##
## File : git_update.sh
## Author : Denny <denny@dennyzhang.com>
## Description :
## --
## Created : <2016-04-15>
## Updated: Time-stamp: <2016-05-04 09:49:36>
##-------------------------------------------------------------------
working_dir=${1?}
git_repo_url=${2?}
branch_name=${3?}

function git_update_code() {
    set -e
    local branch_name=${1?}
    local working_dir=${2?}
    local git_repo_url=${3?}

    local git_repo
    git_repo=$(echo "${git_repo_url%.git}" | awk -F '/' '{print $2}')

    local code_dir="$working_dir/$branch_name/$git_repo"
    echo "Git update code for $git_repo_url to $code_dir"
    # checkout code, if absent
    if [ ! -d "$working_dir/$branch_name/$git_repo" ]; then
        mkdir -p "$working_dir/$branch_name"
        cd "$working_dir/$branch_name"
        git clone --depth 1 "$git_repo_url" --branch "$branch_name" --single-branch
        cd "$code_dir"
        git tag -l
        git config --global user.email "jenkins@devops.com"
        git config --global user.name "Jenkins Auto"
    else
        cd "$code_dir"
        git tag -l
        git config remote.origin.url "$git_repo_url"
        git config --global user.email "jenkins@devops.com"
        git config --global user.name "Jenkins Auto"
        # add retry for network turbulence
        git pull origin "$branch_name" || (sleep 2 && git pull origin "$branch_name")
    fi

    cd "$code_dir"
    git checkout "$branch_name"
    # git reset --hard
}

git_update_code "$branch_name" "$working_dir" "$git_repo_url"
## File : git_update.sh ends
