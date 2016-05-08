#!/bin/bash -e
##-------------------------------------------------------------------
## @copyright 2016 DennyZhang.com
## Licensed under MIT
##   https://raw.githubusercontent.com/DennyZhang/devops_public/master/LICENSE
##
## File : shellcheck_style_check.sh
## Author : DennyZhang.com <denny@dennyzhang.com>
## Description :
## --
## Created : <2016-04-25>
## Updated: Time-stamp: <2016-05-07 09:53:28>
##-------------------------------------------------------------------
################################################################################################
## env variables:
##      git_list:
##           git@github.com:DennyZhang/devops_public.git,master
##           git@gitlabcn.dennyzhang.com:devops/devops_scripts.git,master
##      env_parameters:
##           export working_dir="/var/lib/jenkins/code/codestyle"
################################################################################################
. /etc/profile
if [ ! -f /var/lib/devops/refresh_common_library.sh ]; then
    [ -d /var/lib/devops/ ] || (sudo mkdir -p  /var/lib/devops/ && sudo chmod 777 /var/lib/devops)
    wget -O /var/lib/devops/refresh_common_library.sh \
         https://raw.githubusercontent.com/DennyZhang/devops_public/master/common_library/refresh_common_library.sh
fi
# export AVOID_REFRESH_LIBRARY=true
bash /var/lib/devops/refresh_common_library.sh "3038936287"
. /var/lib/devops/devops_common_library.sh
################################################################################################
function install_shellcheck() {
    if ! sudo which shellcheck 1>/dev/null 2>&1; then
        os_version=$(os_release)
        if [ "$os_version" == "ubuntu" ]; then
            echo "Install shellcheck"
            sudo apt-get install -y cabal-install
            sudo cabal update
            sudo cabal install shellcheck
            if [ ! -f /usr/sbin/shellcheck ]; then
                sudo ln -s /root/.cabal/bin/shellcheck /usr/sbin/shellcheck
            fi
        else
            echo "Error: not implemented supported for OS: $os_version"
            exit 1
        fi
    fi
}

function shellcheck_git_repo(){
    local branch_name=${1?}
    local working_dir=${2?}
    local git_repo_url=${3?}

    local git_repo
    git_repo=$(echo "${git_repo_url%.git}" | awk -F '/' '{print $2}')
    local code_dir="$working_dir/$branch_name/$git_repo"

    git_update_code "$branch_name" "$working_dir" "$git_repo_url"

    echo "================================ Test: ShellCheck check for $git_repo_url"
    local command="find $code_dir -name '*.sh' | xargs sudo shellcheck -e $exclude_code_list"
    echo "$command"
    if ! eval "$command"; then
        failed_git_repos="${failed_git_repos} ${git_repo}:${branch_name}"
    fi
}

function shell_exit() {
    errcode=$?
    if [ "$failed_git_repos" != "" ]; then
        echo "Failed Git Repos: $failed_git_repos"
        exit 1
    fi
    exit $errcode
}

################################################################################
trap shell_exit SIGHUP SIGINT SIGTERM 0

source_string "$env_parameters"

[ -n "$working_dir" ] || working_dir="/var/lib/jenkins/code/codestyle"
# http://github.com/koalaman/shellcheck/wiki/SC1091
[ -n "$exclude_code_list" ] || exclude_code_list="SC1090,SC1091,SC2154,SC2001"

failed_git_repos=""
install_shellcheck

git_list=$(string_strip_comments "$git_list")
for git_repo_url in $git_list; do
    git_repo_url=${git_repo_url//,/ }
    item=($git_repo_url)
    git_repo_url=${item[0]}
    branch_name=${item[1]}
    shellcheck_git_repo "$branch_name" "$working_dir" "$git_repo_url"
done
## File : shellcheck_style_check.sh ends
