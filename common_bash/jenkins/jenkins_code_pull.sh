#!/bin/bash -e
##-------------------------------------------------------------------
## @copyright 2015 DennyZhang.com
## File : jenkins_code_pull.sh
## Author : DennyZhang.com <denny@dennyzhang.com>
## Description :
## --
## Created : <2015-07-03>
## Updated: Time-stamp: <2016-04-10 12:21:33>
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
################################################################################################
if [ ! -f /var/lib/enable_common_library.sh ]; then
    wget -O /var/lib/enable_common_library.sh \
         https://raw.githubusercontent.com/DennyZhang/devops_public/master/common_library/enable_common_library.sh
fi
# export AVOID_REFRESH_LIBRARY=true
bash /var/lib/enable_common_library.sh "1512381967"
################################################################################################
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
