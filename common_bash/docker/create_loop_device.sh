#!/bin/bash -e
##-------------------------------------------------------------------
## @copyright 2015 DennyZhang.com
## File : create_loop_device.sh
## Author : Denny <denny.zhang001@gmail.com>
## Description :
## --
## Created : <2015-12-28>
## Updated: Time-stamp: <2016-01-20 15:33:31>
##-------------------------------------------------------------------
file_count=${1?}

function log() {
    local msg=$*
    echo -ne `date +['%Y-%m-%d %H:%M:%S']`" $msg\n"
    
    if [ -n "$LOG_FILE" ]; then
        echo -ne `date +['%Y-%m-%d %H:%M:%S']`" $msg\n" >> $LOG_FILE
    fi
}

for((i=0; i< $file_count; i++)); do
    if [ ! -b /dev/loop$i ]; then
        log "mknod -m0660 /dev/loop$i b 7 $i"
        mknod -m0660 /dev/loop$i b 7 $i
    fi
done
## File : create_loop_device.sh ends
