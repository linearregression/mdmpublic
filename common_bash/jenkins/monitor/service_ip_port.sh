#!/bin/bash -xe
################################################################################################
## @copyright 2015 DennyZhang.com
# * Author        : doungni
# * Email         : doungni@doungni.com
# * Last modified : 2016-01-06 13:26
# * Filename      : service_ip_port.sh
# * Description   : 
################################################################################################

############################## Function Start ##################################################
function service_ip_port() {
    # Count value
    local count=0
    for sip in $*
    do
        service_ip_port=(${sip//:/ })
        ip=${service_ip_port[1]}
        port=${service_ip_port[2]}

        nc_return=$(nc -w 1 $ip $port >/dev/null 2>&1 && echo yes || echo no)
        if [ "x$nc_return" == "xno" ]; then
            connect_failed_list+=("\n$sip can not be connected")
        fi
    done

    if [ ${#connect_failed_list[@]} -gt 0 ]; then
        log "The following Service:Ip:Port can not be connected:${connect_failed_list[@]}"
    fi
}
############################## Function End ####################################################

############################## Shell Start #####################################################

. $work_dir/common.sh

service_ip_port $*


############################## Shell End #######################################################
