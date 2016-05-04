#!/bin/bash -e
##-------------------------------------------------------------------
## @copyright 2016 DennyZhang.com
## Licensed under MIT
##   https://raw.githubusercontent.com/DennyZhang/devops_public/master/LICENSE
##
## File : replicate_git_repos.sh
## Author : DennyZhang.com <denny@dennyzhang.com>
## Description :
## --
## Created : <2016-04-13>
## Updated: Time-stamp: <2016-05-04 20:27:15>
##-------------------------------------------------------------------

################################################################################################
## env variables:
##      repo_list:
##        git@github.com:TEST/test.git,master,git@gitlabcn.dennyzhang.com:customer/mdmdevops-test.git,master
##        git@git.test.com:TEST/mytest.git,master,git@gitlabcn.dennyzhang.com:customer/mdmdevops-mytest.git,master
##
##       env_parameters:
##             export CLEAN_START=false
##             export working_dir=
################################################################################################
. /etc/profile
################################################################################################
if [ ! -f /var/lib/devops/refresh_common_library.sh ]; then
    [ -d /var/lib/devops/ ] || (sudo mkdir -p  /var/lib/devops/ && sudo chmod 777 /var/lib/devops)
    wget -O /var/lib/devops/refresh_common_library.sh \
         https://raw.githubusercontent.com/DennyZhang/devops_public/master/common_library/refresh_common_library.sh
fi
# export AVOID_REFRESH_LIBRARY=true
bash /var/lib/devops/refresh_common_library.sh "2520035396"
. /var/lib/devops/devops_common_library.sh
################################################################################################
function shell_exit() {
    errcode=$?
    exit $errcode
}

function git_directory_commit() {
    local code_dir=${1?}
    local branch_name=${2?}

    cd "$code_dir"
    echo "Commit changes detected in intermediate directory"
    git_status=$(git status)
    if echo "$git_status" | grep "nothing to commit, working directory clean" 1>/dev/null 2>&1; then
        echo "No change"
    else
        git_commit_message="Robot Push: Sync Git Repo"

        echo "=========== Jenkins Robot push changes: $git_commit_message"
        echo "git_status: $git_status"

        git config --global user.email "$git_email"
        git config --global user.name "$git_username"
        git add ./*

        git commit -am "$git_commit_message"
        git push origin "$branch_name"
    fi
}

function replicate_git_repo() {
    local git_repo_src_url=${1?}
    local git_branch_src=${2?}
    local git_repo_dst_url=${3?}
    local git_branch_dst=${4?}
    local working_dir=${5?}

    local intermediate_dir
    local git_repo_src_name
    local git_repo_dst_name

    [ -d "$working_dir" ] || mkdir -p "$working_dir"
    intermediate_dir="$working_dir/$git_branch_dst/intermediate"
    git_repo_src_name=$(echo "${git_repo_src_url%.git}" | awk -F '/' '{print $2}')
    git_repo_dst_name=$(echo "${git_repo_dst_url%.git}" | awk -F '/' '{print $2}')

    git_update_code "$git_branch_src" "$working_dir" "$git_repo_src_url"
    git_update_code "$git_branch_dst" "$working_dir" "$git_repo_dst_url"

    echo "Update intermediate directory: $intermediate_dir"
    rm -rf "$intermediate_dir" && mkdir -p "$intermediate_dir"
    cp -r "$working_dir/$git_branch_dst/$git_repo_dst_name/.git" "$intermediate_dir/"
    src_dir="$working_dir/$git_branch_src/$git_repo_src_name/"
    for d in "${src_dir}/"*; do
        cp -r "$d" "$intermediate_dir/"
    done

    git_directory_commit "$intermediate_dir" "$git_branch_dst"
}

trap shell_exit SIGHUP SIGINT SIGTERM 0

source_string "$env_parameters"

########################################################
[ -n "$working_dir" ] || working_dir="/var/lib/jenkins/code"
[ -d "$working_dir" ] || mkdir -p $working_dir

git_email="jenkins.auto@dennyzhang.com"
git_username="Jenkins Auto"

repo_list=$(string_strip_comments "$repo_list")
for repo in $repo_list; do
    repo=${repo//,/ }
    item=($repo)
    git_repo_src=${item[0]}
    git_branch_src=${item[1]}
    git_repo_dst=${item[2]}
    git_branch_dst=${item[3]}
    echo "Replicate $git_repo_src:$git_branch_src to $git_repo_dst:$git_branch_dst"
    replicate_git_repo "$git_repo_src" "$git_branch_src" "$git_repo_dst" "$git_branch_dst" "$working_dir"
done
## File : replicate_git_repos.sh ends
