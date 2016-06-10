#!/bin/bash -e
##-------------------------------------------------------------------
## @copyright 2016 DennyZhang.com
## Licensed under MIT
## https://raw.githubusercontent.com/DennyZhang/devops_public/master/LICENSE
##
## File : package_action_report.sh
## Author : DennyZhang.com <denny@dennyzhang.com>
## Description :
##
## --
## Created : <2016-04-03>
## Updated: Time-stamp: <2016-06-10 08:28:14>
##-------------------------------------------------------------------
################################################################################################
## env variables:
##      ssh_server: 192.168.1.3:2704:root
##      env_parameters:
##           export HAS_INIT_ANALYSIS=false
################################################################################################
. /etc/profile
if [ ! -f /var/lib/devops/refresh_common_library.sh ]; then
    [ -d /var/lib/devops/ ] || (sudo mkdir -p /var/lib/devops/ && sudo chmod 777 /var/lib/devops)
    wget -O /var/lib/devops/refresh_common_library.sh \
         https://raw.githubusercontent.com/DennyZhang/devops_public/master/common_library/refresh_common_library.sh
fi
# export AVOID_REFRESH_LIBRARY=true
bash /var/lib/devops/refresh_common_library.sh "3801543898"
. /var/lib/devops/devops_common_library.sh
################################################################################################

## File : package_action_report.sh ends
