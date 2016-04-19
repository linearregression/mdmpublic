#!/bin/bash -e
##-------------------------------------------------------------------
## @copyright 2016 DennyZhang.com
## File : replicate_git_repos.sh
## Author : DennyZhang.com <denny@dennyzhang.com>
## Description :
## --
## Created : <2016-04-13>
## Updated: Time-stamp: <2016-04-18 10:50:20>
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
bash /var/lib/devops/refresh_common_library.sh "3606538101"
. /var/lib/devops/devops_common_library.sh
################################################################################################
function shell_exit() {
    errcode=$?
    exit $errcode
}

function git_directory_commit() {
    local code_dir=${1?}
    local branch_name=${2?}

    cd $code_dir
    echo "Commit changes detected in intermediate directory"
    git_status=$(git status)
    if echo "$git_status" | grep "nothing to commit, working directory clean" 2>&1 1>/dev/null; then
        echo "No change"
    else
        echo "=========== git commit changes"
        echo "git_status: $git_status"

        git config --global user.email "$git_email"
        git config --global user.name "$git_username"
        git add *

        git_commit_message="Robot Push: Sync Git Repo"
        git commit -am "$git_commit_message"
        git push origin $branch_name
    fi
}

function replicate_git_repo() {
    local git_repo_src_url=${1?}
    local git_branch_src=${2?}
    local git_repo_dst_url=${3?}
    local git_branch_dst=${4?}
    local working_dir=${5?}

    [ -d $working_dir ] || mkdir -p $working_dir
    local intermediate_dir="$working_dir/$git_branch_dst/intermediate"
    local git_repo_src_name=$(echo ${git_repo_src_url%.git} | awk -F '/' '{print $2}')
    local git_repo_dst_name=$(echo ${git_repo_dst_url%.git} | awk -F '/' '{print $2}')

    echo "Update source git repo"
    git_update_code $git_branch_src $working_dir $git_repo_src_url

    echo "Update destination git repo"
    git_update_code $git_branch_dst $working_dir $git_repo_dst_url

    echo "Update intermediate directory: $intermediate_dir"
    rm -rf $intermediate_dir && mkdir -p  $intermediate_dir
    cp -r $working_dir/$git_branch_dst/$git_repo_dst_name/.git $intermediate_dir/
    src_dir="$working_dir/$git_branch_src/$git_repo_src_name/"
    for d in `ls -1a | grep -v "^.git$" | grep -v "^.$" | grep -v "^..$"`; do
        cp -r $src_dir/$d  $intermediate_dir/
    done

    git_directory_commit $intermediate_dir $git_branch_dst
}

trap shell_exit SIGHUP SIGINT SIGTERM 0

# Global variables needed to enable the current script
env_parameters=$(remove_hardline "$env_parameters")
env_parameters=$(list_strip_comments "$env_parameters")
IFS=$'\n'
for env_variable in `echo "$env_parameters"`; do
    eval $env_variable
done
unset IFS

########################################################
[ -n "$working_dir" ] || working_dir="/var/lib/jenkins/code"
[ -d "$working_dir" ] || mkdir -p $working_dir

git_email="jenkins.auto@dennyzhang.com"
git_username="Jenkins Auto"

repo_list=$(list_strip_comments "$repo_list")
for repo in `echo $repo_list`; do
    repo=`echo $repo | sed 's/,/ /g'`
    item=($repo)
    git_repo_src=${item[0]}
    git_branch_src=${item[1]}
    git_repo_dst=${item[2]}
    git_branch_dst=${item[3]}
    echo "Replicate $git_repo_src:$git_branch_src to $git_repo_dst:$git_branch_dst"
    replicate_git_repo $git_repo_src $git_branch_src $git_repo_dst $git_branch_dst $working_dir
done
## File : replicate_git_repos.sh ends
