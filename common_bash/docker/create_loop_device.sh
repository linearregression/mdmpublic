#!/bin/bash -e
##-------------------------------------------------------------------
## @copyright 2015 DennyZhang.com
## File : create_loop_device.sh
## Author : DennyZhang.com <denny@dennyzhang.com>
## Description :
## --
## Created : <2015-12-28>
## Updated: Time-stamp: <2016-04-10 12:18:14>
##-------------------------------------------------------------------
################################################################################################
if [ ! -f /var/lib/enable_common_library.sh ]; then
    wget -O /var/lib/enable_common_library.sh \
         https://raw.githubusercontent.com/DennyZhang/devops_public/master/common_library/enable_common_library.sh
fi
# export AVOID_REFRESH_LIBRARY=true
bash /var/lib/enable_common_library.sh "1512381967"
################################################################################################
file_count=${1?}

for((i=0; i< $file_count; i++)); do
    if [ ! -b /dev/loop$i ]; then
        log "mknod -m0660 /dev/loop$i b 7 $i"
        mknod -m0660 /dev/loop$i b 7 $i
    fi
done
## File : create_loop_device.sh ends
