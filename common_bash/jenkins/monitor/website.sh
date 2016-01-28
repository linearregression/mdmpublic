#!/bin/bash -xe
################################################################################################
## @copyright 2015 DennyZhang.com
# * Author        : doungni
# * Email         : doungni@doungni.com
# * Last modified : 2016-01-08 13:16
# * Filename      : website.sh
# * Description   : 
################################################################################################

############################## Function Start ##################################################
function website() {
    # The maximum number of trying to connect website
    local max_retries_count=3
    # Connect timeout
    local timeout=3
    # The maximum allowable time data transmission
    local maxtime=5
    # If the website cannnt connect,will sleep several second
    local sleep_time=2
    for website in $*
    do
        for ((i=1; i <= $max_retries_count; i++))
        do
            c_ret=$(curl -I -s --connect-timeout $timeout -m $maxtime $website | grep "HTTP" | grep -q "200" && echo yes || echo no)
            [ "X$c_ret" == "Xyes" ] && break

            website=$(echo $website | awk -F '/' '{print $3}')
            p_ret=$(ping -c1 $website >/dev/null 2>&1 && echo yes || echo no)
            [ "X$p_ret" == "Xyes" ] && break

            if [ $i -eq $max_retries_count ];then
                connect_failed_website+=("\n${website}")
                break
            fi
            sleep $sleep_time
        done
    done

    if [ ${#connect_failed_website[@]} -gt 0 ]; then
        log "Connect failed website:${connect_failed_website[@]}"
    fi
}
############################## Function End ####################################################

############################## Shell Start #####################################################
. $work_dir/common.sh

website $*
############################## Shell End #######################################################
