#!/bin/bash -e
##-------------------------------------------------------------------
## @copyright 2016 DennyZhang.com
## Licensed under MIT
##   https://raw.githubusercontent.com/DennyZhang/devops_public/master/LICENSE
##
## File : monitor_filechanges.sh
## Author : DennyZhang.com <denny@dennyzhang.com>
## Description :
## --
## Created : <2015-08-05>
## Updated: Time-stamp: <2016-05-02 07:47:31>
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
if [ ! -f /var/lib/devops/refresh_common_library.sh ]; then
    [ -d /var/lib/devops/ ] || (sudo mkdir -p  /var/lib/devops/ && sudo chmod 777 /var/lib/devops)
    wget -O /var/lib/devops/refresh_common_library.sh \
         https://raw.githubusercontent.com/DennyZhang/devops_public/master/common_library/refresh_common_library.sh
fi
# export AVOID_REFRESH_LIBRARY=true
bash /var/lib/devops/refresh_common_library.sh "2756010837"
. /var/lib/devops/devops_common_library.sh
################################################################################################
function git_changed_filelist() {
    set -e
    local src_dir=${1?}
    local old_sha=${2?}
    local new_sha=${3?}
    cd "$src_dir"
    git diff --name-only "$old_sha" "$new_sha"
}

function detect_changed_file() {
    set -e
    local src_dir=${1?}
    local old_sha=${2?}
    local new_sha=${3?}
    local files_to_monitor=${4?}
    local file_list
    file_list=$(git_changed_filelist "$src_dir" "$old_sha" "$new_sha")

    echo -e "\n\n========== git diff --name-only ${old_sha}..${new_sha}\n"
    echo -e "${file_list}\n"
    IFS=$'\n'
    for file in ${file_list[*]}; do
      if echo -e "$files_to_monitor" | grep "$file" 1>/dev/null 2>1; then
         changed_file_list="$changed_file_list $file"
      fi
    done
}

flag_file="/var/lib/jenkins/$JOB_NAME.flag"

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

log "env variables. CLEAN_START: $CLEAN_START"

git_repo=$(echo "${git_repo_url%.git}" | awk -F '/' '{print $2}')
code_dir=$working_dir/$branch_name/$git_repo

# Global variables needed to enable the current script
env_parameters=$(remove_hardline "$env_parameters")
env_parameters=$(string_strip_comments "$env_parameters")
IFS=$'\n'
for env_variable in $env_parameters; do
    eval "$env_variable"
done
unset IFS

filelist_to_monitor=$(string_strip_comments "$filelist_to_monitor")
if [ -n "$mark_previous_fixed" ] && $mark_previous_fixed; then
    rm -rf "$flag_file"
fi

# check previous failure
if [ -f "$flag_file" ] && [[ "$(cat "$flag_file")" = "ERROR" ]]; then
    echo "Previous check has failed"
    exit 1
fi

if [ -n "$CLEAN_START" ] && $CLEAN_START; then
  [ ! -d "$code_dir" ] || rm -rf "$code_dir"
fi

if [ ! -d "$working_dir" ]; then
   mkdir -p "$working_dir"
   chown -R jenkins:jenkins "$working_dir"
fi

if [ -d "$code_dir" ]; then
  old_sha=$(current_git_sha "$code_dir")
else
  old_sha=""
fi

# Update code
git_update_code "$branch_name" "$working_dir" "$git_repo_url"
code_dir="$working_dir/$branch_name/$git_repo"
cd "$code_dir"

changed_file_list=""
cd "$code_dir"

new_sha=$(current_git_sha "$code_dir")

if [ -z "$old_sha" ] || [ "$old_sha" = "$new_sha" ]; then
    echo -e "\n\n========== Latest git sha is $old_sha. No commits since last git pull\n\n"
else
    detect_changed_file "$code_dir" "$old_sha" "$new_sha" "$filelist_to_monitor"
    if [ -n "$changed_file_list" ]; then
        echo -e "\n\n========== git diff ${old_sha} ${new_sha}\n"
        echo -e "========== ERROR file changed: \n$(echo "$changed_file_list" | tr ' ' '\n')\n"
        exit 1
    fi
fi
## File : monitor_filechanges.sh ends
