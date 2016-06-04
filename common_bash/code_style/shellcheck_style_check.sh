#!/bin/bash -e
##-------------------------------------------------------------------
## @copyright 2016 DennyZhang.com
## Licensed under MIT
##   https://raw.githubusercontent.com/DennyZhang/devops_public/master/LICENSE
##
## File : shellcheck_style_check.sh
## Author : DennyZhang.com <denny@dennyzhang.com>
## Description :
##      Demo: http://jenkinscn.dennyzhang.com:18088/job/BashCodeQualityCheck/
## --
## Created : <2016-04-25>
## Updated: Time-stamp: <2016-06-04 22:07:07>
##-------------------------------------------------------------------
################################################################################################
## env variables:
##      git_list:
##           git@github.com:DennyZhang/devops_public.git,master
##           git@gitlabcn.dennyzhang.com:devops/devops_scripts.git,master
##      env_parameters:
##           export working_dir="/var/lib/jenkins/code/codestyle"
##           export EXCLUDE_CODE_LIST="SC1090,SC1091,SC2154,SC2001"
##           export SHELLCHECK_IGNORE_FILE=".shellcheck_ignore"
##               ##  Use SHELLCHECK_IGNORE_FILE to skip checks for certain files
##               ##  The logic is similar like .gitignore for git
################################################################################################
. /etc/profile
if [ ! -f /var/lib/devops/refresh_common_library.sh ]; then
    [ -d /var/lib/devops/ ] || (sudo mkdir -p  /var/lib/devops/ && sudo chmod 777 /var/lib/devops)
    wget -O /var/lib/devops/refresh_common_library.sh \
         https://raw.githubusercontent.com/DennyZhang/devops_public/master/common_library/refresh_common_library.sh
fi
# export AVOID_REFRESH_LIBRARY=true
bash /var/lib/devops/refresh_common_library.sh "2205160402"
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
            if [ ! -f /usr/sbin/shellcheck ] ; then
                if [ -f /root/.cabal/bin/shellcheck ]; then
                    sudo ln -s /root/.cabal/bin/shellcheck /usr/sbin/shellcheck
                else
                    if [ -f /var/lib/jenkins/.cabal/bin/shellcheck ]; then
                       sudo ln -s /var/lib/jenkins/.cabal/bin/shellcheck /usr/sbin/shellcheck
                    fi
                fi
            fi
        else
            echo "Error: not implemented supported for OS: $os_version"
            exit 1
        fi
    fi
}

function should_skip_file() {
    local check_file=${1?}
    local ignore_patterns=${2?}
    for pattern in $ignore_patterns; do
        if [[ "$check_file" == *${pattern}* ]]; then
            echo "yes"
            return
        fi
    done
    echo "no"
}

function shellcheck_git_repo(){
    local branch_name=${1?}
    local working_dir=${2?}
    local git_repo_url=${3?}

    local check_fail=false
    local skip_content=""

    local git_repo
    git_repo=$(echo "${git_repo_url%.git}" | awk -F '/' '{print $2}')
    local code_dir="$working_dir/$branch_name/$git_repo"

    git_update_code "$branch_name" "$working_dir" "$git_repo_url"

    echo "================================ Test: ShellCheck check for $git_repo_url"
    cd "$code_dir"
    echo "cd $code_dir"

    if [ -f "$SHELLCHECK_IGNORE_FILE" ]; then
        skip_content=$(cat "$SHELLCHECK_IGNORE_FILE")
    fi

    while IFS= read -r -d '' file
    do
        if [ -n "$skip_content" ] && \
               [ "$(should_skip_file "$file" "$skip_content")" = "yes" ]; then
           continue
        fi

        command="sudo shellcheck -e $EXCLUDE_CODE_LIST $file"
        echo "shellcheck $file"
        if ! eval "$command"; then
            check_fail=true
        fi
    done < <(find . -name '*.sh' -print0)

    if $check_fail; then
        failed_git_repos="${failed_git_repos}\n${git_repo}:${branch_name}"
    fi
}

function shell_exit() {
    errcode=$?
    if [ "$failed_git_repos" != "" ]; then
        echo -e "Failed Git Repos: $failed_git_repos"
        exit 1
    fi
    exit $errcode
}

################################################################################
trap shell_exit SIGHUP SIGINT SIGTERM 0

source_string "$env_parameters"

[ -n "$working_dir" ] || working_dir="/var/lib/jenkins/code/codestyle"
[ -n "$SHELLCHECK_IGNORE_FILE" ] || SHELLCHECK_IGNORE_FILE=".shellcheck_ignore"

# http://github.com/koalaman/shellcheck/wiki/SC1091
[ -n "$EXCLUDE_CODE_LIST" ] || EXCLUDE_CODE_LIST="SC1090,SC1091,SC2154,SC2001"

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
