#!/bin/bash -xe
################################################################################################
## @copyright 2015 DennyZhang.com
# * Author        : doungni
# * Email         : doungni@doungni.com
# * Last modified : 2016-01-06 13:34
# * Filename      : monitor.sh
# * Description   : 
################################################################################################

############################## Function Start ##################################################
############################## Function End ####################################################

############################## Shell Start #####################################################

# Common function
. $work_dir/common.sh
# work_dir by Jenkins Execute shell config
if [ -z "$work_dir" ]; then
    exit 1
fi

# Service ip:port
log "======= Monitor Service ip:port: ======="
if [ -n "$service_ip_port" ]; then
    service_ip_port=("${service_ip_port// / }")
    . $work_dir/service_ip_port.sh "${service_ip_port[@]}"
else
    log "Warning: Service ip port not exist"
fi

# Website
log  "======= Monitor Website ======="
if [ -n "$website_list" ]; then
    website_list=("${website_list// / }")
    . $work_dir/website.sh "${website_list[@]}"
else
    log "Warning: Website list not exist"
fi

# Domain
log  "======= Monitor Domain ======="
if [ -n "$domain_list" ]; then
    domain_list=("${domain_list// / }")
    . $work_dir/domain.sh "${domain_list[@]}"
else
    log "Warning: Doamin list not exist"
fi

############################## Shell End #######################################################
