#!/bin/bash -e
##-------------------------------------------------------------------
## @copyright 2016 DennyZhang.com
## File : create_loop_device.sh
## Author : DennyZhang.com <denny@dennyzhang.com>
## Description :
## --
## Created : <2015-12-28>
## Updated: Time-stamp: <2016-04-15 07:52:40>
##-------------------------------------------------------------------
################################################################################################
if [ ! -f /var/lib/devops/refresh_common_library.sh ]; then
    [ -d /var/lib/devops/ ] || (sudo mkdir -p  /var/lib/devops/ && sudo chmod 777 /var/lib/devops)
    wget -O /var/lib/devops/refresh_common_library.sh \
         https://raw.githubusercontent.com/DennyZhang/devops_public/master/common_library/refresh_common_library.sh
fi
# export AVOID_REFRESH_LIBRARY=true
bash /var/lib/devops/refresh_common_library.sh "3372880711"
. /var/lib/devops/devops_common_library.sh
################################################################################################
file_count=${1?}

for((i=0; i< $file_count; i++)); do
    if [ ! -b /dev/loop$i ]; then
        log "mknod -m0660 /dev/loop$i b 7 $i"
        mknod -m0660 /dev/loop$i b 7 $i
    fi
done
## File : create_loop_device.sh ends
