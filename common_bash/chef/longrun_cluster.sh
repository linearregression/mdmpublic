#!/bin/bash -e
##-------------------------------------------------------------------
## @copyright 2016 DennyZhang.com
## Licensed under MIT
##   https://raw.githubusercontent.com/DennyZhang/devops_public/master/LICENSE
##
## File : longrun_cluster.sh
## Author : DennyZhang.com <denny@dennyzhang.com>
## Description :
## --
## Created : <2015-07-03>
## Updated: Time-stamp: <2016-06-04 13:59:13>
##-------------------------------------------------------------------

################################################################################################
## env variables:
##       longrun_env_parameters:
##             export STOP_CONTAINER=false
##             export KILL_RUNNING_CHEF_UPDATE=false
##             export START_COMMAND="docker start kitchen-cluster-node1 kitchen-cluster-node2 kitchen-cluster-node3"
##             export POST_START_COMMAND="sleep 5; service apache2 start; true"
##             export PRE_STOP_COMMAND="service apache2 stop; true"
##             export STOP_COMMAND="docker stop kitchen-cluster-node1 kitchen-cluster-node2 kitchen-cluster-node3"
##             export CODE_SH=""
##             export SSH_SERVER_PORT=22
##             export CHEF_BINARY_CMD=chef-client
##
##       # Parse all other parameters to deploy_cluster.sh
##
## Hook points: START_COMMAND -> POST_START_COMMAND -> PRE_STOP_COMMAND -> STOP_COMMAND
################################################################################################
. /etc/profile
if [ ! -f /var/lib/devops/refresh_common_library.sh ]; then
    [ -d /var/lib/devops/ ] || (sudo mkdir -p  /var/lib/devops/ && sudo chmod 777 /var/lib/devops)
    wget -O /var/lib/devops/refresh_common_library.sh \
         https://raw.githubusercontent.com/DennyZhang/devops_public/master/common_library/refresh_common_library.sh
fi
# export AVOID_REFRESH_LIBRARY=true
bash /var/lib/devops/refresh_common_library.sh "999962759"
. /var/lib/devops/devops_common_library.sh
################################################################################################

##########################################################################################
source_string "$env_parameters"
server_list=$(string_strip_comments "$server_list")
echo "server_list: ${server_list}"
check_list_fields "IP:TCP_PORT" "$server_list"

## File : longrun_cluster.sh ends
