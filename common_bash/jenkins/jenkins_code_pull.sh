#!/bin/bash -e
##-------------------------------------------------------------------
## @copyright 2015 DennyZhang.com
## File : jenkins_code_pull.sh
## Author : DennyZhang.com <denny@dennyzhang.com>
## Description :
## --
## Created : <2015-07-03>
## Updated: Time-stamp: <2016-04-10 14:52:05>
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
. /etc/profile
################################################################################################
if [ ! -f /var/lib/devops/refresh_common_library.sh ]; then
    [ -d /var/lib/devops/ ] || (sudo mkdir -p  /var/lib/devops/ && sudo chmod 777 /var/lib/devops)
    wget -O /var/lib/devops/refresh_common_library.sh \
         https://raw.githubusercontent.com/DennyZhang/devops_public/master/common_library/refresh_common_library.sh
fi
# export AVOID_REFRESH_LIBRARY=true
bash /var/lib/devops/refresh_common_library.sh "1512381967"
. /var/lib/devops/devops_common_library.sh
################################################################################################
function shell_exit() {
    errcode=$?
    exit $errcode
}

trap shell_exit SIGHUP SIGINT SIGTERM 0

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
