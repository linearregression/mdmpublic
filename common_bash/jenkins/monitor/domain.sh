#!/bin/bash -xe
################################################################################################
## @copyright 2015 DennyZhang.com
# * Author        : doungni
# * Email         : doungni@doungni.com
# * Last modified : 2016-01-06 17:05
# * Filename      : domain.sh
# * Description   : 
################################################################################################

############################## Function Start ##################################################

function domain() {
    # Check command: jq, for deal with json format
    if command -v jq >/dev/null 2>&1; then
        jq --version
    else
        sudo apt-get install jq -y
    fi

    # Versify command jq
    if [ $? -ne 0 ]; then
        log "Error: command "jq" not exist"
        exit 1
    fi

    # Get domain date_expires
    local count_v=0
    while [ $count_v -le ${#apikey[@]} ]
    do
        api_url="http://api.whoapi.com/?apikey=${api_key[count_v]}&r=whois&domain=$1"

        ret=$(curl -m 10 --connect-timeout 10 -s -d "getcode=secret" $api_url | jq . | grep date_expires| awk -F "\"" '{print $4}'| awk '{print $1}')
        ex_ret=$(date +%s -d $ret)
        cur_ret=$(date +%s)
        day_ret=$(((ex_ret-cur_ret)/86400))
        if [ $da_ret -lt 30 ]; then
            log "Warning: $1 will be date expired letter than 30"
            expired_domain+=("\n$1")
        fi

        # $2 -> $1
        shift
        count_v=$((count_v+1))
    done

    if [ ${#expired_domain[@]} -gt 0 ]; then
    fi
}

############################## Function End ####################################################

############################## Shell Start #####################################################
# Api parameter
local apikey=("6d085843a8275d59f90c4ff12a6f3770"
              "6ba653d26095ded20fb5aafba67a9031")

. $work_dir/common.sh
domain $*

############################## Shell End #######################################################
