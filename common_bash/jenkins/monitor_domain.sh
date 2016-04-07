#!/bin/bash -e
################################################################################################
# * Author        : doungni
# * Email         : doungni@doungni.com
# * Last modified : 2016-01-06 17:05
# * Filename      : domain.sh
# * Description   : 
################################################################################################

############################## Function Start ##################################################
function log() {
    local msg=$*

    echo -ne `date +'%Y-%m-%d %H:%M:%S'` " $msg\n"
}

function check_domain() {
    # Check command: jq, for deal with json format
    if ! command -v jq >/dev/null 2>&1; then
        sudo apt-get install jq -y
    fi

    # Versify command jq
    if [ $? -ne 0 ]; then
        log "Error: command "jq" not exist"
        exit 1
    fi

    # Get domain date_expires
    local count_v=0
    while [ $count_v -lt ${#apikey_list[@]} ]
    do
        api_url="http://api.whoapi.com/?apikey=${apikey_list[count_v]}&r=whois&domain=$1"

        ret=$(curl -m 10 --connect-timeout 10 -s -d "getcode=secret" $api_url | jq . | grep date_expires | awk -F "\"" '{print $4}'| awk '{print $1}')
        if [ -z $ret ]; then
            log "Current API cannot call or APIKEY exception or domain error"
            exit 1
        fi
        ex_ret=$(date +%s -d $ret)
        cur_ret=$(date +%s)
        day_ret=$(((ex_ret-cur_ret)/86400))

        current_domain+=("\n$1, expired_date:$ret, $day_ret days from now")

        if [ $day_ret -lt 30 ]; then
            log "Warning: $1 will be date expired letter than 30"
            expired_domain+=("\n$1, expired_date:$ret, $day_ret days from now")
        fi

        # Domain list $2->$1
        shift
        count_v=$((count_v+1))
    done

    if [ ${#expired_domain[@]} -gt 0 ]; then
        log "Expired domain list:\n${expired_domain[@]}"
        exit 1
    else
        log "Currently no expiration domain\nCurrent domain expires instructions:${current_domain[@]}"
    fi
}

############################## Function End ####################################################

############################## Shell Start #####################################################
# Jenkins parameter
if [ -n "$apikey_list" ]; then
    apikey_list=(${apikey_list// / })
else
    log "Apikey list is empty"
    exit 1
fi

if [ -n "$domain_list" ]; then
    domain_list=(${domain_list// / })
else
    log "Domain list is empty"
    exit 1
fi

check_domain ${domain_list[@]}
############################## Shell End #######################################################
