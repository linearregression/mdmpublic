#!/bin/bash -e
##-------------------------------------------------------------------
## @copyright 2015 DennyZhang.com
## File : kitchen_raw_test.sh
## Author : Denny <denny.zhang001@gmail.com>
## Description :
## --
## Created : <2015-07-03>
## Updated: Time-stamp: <2016-01-29 11:36:04>
##-------------------------------------------------------------------

################################################################################################
## env variables:
##      KEEP_INSTANCE(boolean)
##      KEEP_FAILED_INSTANCE(boolean)
##      REMOVE_BERKSFILE_LOCK(boolean)
##      KITCHEN_VERIFY_SHOW_DEBUG(boolean)
##      KITCHEN_LOGLEVEL(debug, info, warn, error, fatal)
##      SKIP_KITCHEN_CONVERGE(boolean)
##      SKIP_KITCHEN_VERIFY(boolean)
################################################################################################
function log() {
    local msg=$*
    echo -ne `date +['%Y-%m-%d %H:%M:%S']`"========== $msg ==========\n"
}

function exit_if_error() {
    if [ $? -ne 0 ];then
        exit 1
    fi
}

function exec_kitchen_cmd() {
    hooks_dir="$1/.kitchen.hooks"
    shift
    cmd=$1
    shift
    options=$@

    if [ -a "${hooks_dir}/pre-$cmd" ];then
        log "start to exec kitchen hook: pre-$cmd"
        bash -e "${hooks_dir}/pre-$cmd" && log "kitchen hook: pre-$cmd exec done!"
        exit_if_error
    fi

    command="kitchen $cmd $options"
    log "exec kitchen command: $command"
    eval "$command"
    exit_if_error
    
    if [ -a "${hooks_dir}/post-$cmd" ];then
        log "start to exec kitchen hook: post-$cmd"
        bash -e "${hooks_dir}/post-$cmd" && log "kitchen hook: post-$cmd exec done!"
        exit_if_error        
    fi
}

function shell_exit() {
    errcode=$?
    log "shell_exit: KEEP_FAILED_INSTANCE: $KEEP_FAILED_INSTANCE, KEEP_INSTANCE: $KEEP_INSTANCE"
    if [ $errcode -eq 0 ]; then
        log "Kitchen test pass."
    else
        log "Kitchen test fail."
    fi

    # whether destroy instance
    if [ -n "$KEEP_INSTANCE" ] && $KEEP_INSTANCE; then
        log "keep instance as demanded."
    else
        if [ -n "$KEEP_FAILED_INSTANCE" ] && $KEEP_FAILED_INSTANCE && [ $errcode -ne 0 ];then
            log "keep instance"
        else
            log "destroy instance."
            exec_kitchen_cmd ${kitchen_dir} destroy $show_log
        fi
    fi

    exit $errcode
}

trap shell_exit SIGHUP SIGINT SIGTERM 0

current_cookbook=`pwd`
current_cookbook=${current_cookbook##*/}

if [ -z $KITCHEN_VERIFY_SHOW_DEBUG ]; then
    KITCHEN_VERIFY_SHOW_DEBUG=false
fi

if  [ -n "$KITCHEN_LOGLEVEL" ]; then
    show_log="-l $KITCHEN_LOGLEVEL"
fi

log "env variables. cookbok: $current_cookbook, KEEP_INSTANCE: $KEEP_INSTANCE, KEEP_FAILED_INSTANCE: $KEEP_FAILED_INSTANCE"
if [ -n "$REMOVE_BERKSFILE_LOCK" ] && $REMOVE_BERKSFILE_LOCK; then
    command="rm -rf Berksfile.lock"
    log "$command" && eval "$command"
fi

kitchen_dir=`pwd`
if [ -z "$SKIP_KITCHEN_DESTROY" ] || ! $SKIP_KITCHEN_DESTROY; then
    exec_kitchen_cmd ${kitchen_dir} destroy "$show_log"
else
    log "skip kitchen destroy"
fi
if [ -z "$SKIP_KITCHEN_CREATE" ] || ! $SKIP_KITCHEN_CREATE; then
    exec_kitchen_cmd ${kitchen_dir} create "$show_log"
else
    log "skip kitchen create"
fi

if [ -z "$SKIP_KITCHEN_CONVERGE" ] || ! $SKIP_KITCHEN_CONVERGE; then
    exec_kitchen_cmd ${kitchen_dir} converge  "$show_log"
else
    log "skip kitchen converge"
fi

if [ -z "$SKIP_KITCHEN_VERIFY" ] || ! $SKIP_KITCHEN_VERIFY; then
    if $KITCHEN_VERIFY_SHOW_DEBUG; then
        exec_kitchen_cmd ${kitchen_dir} verify -l debug
    else
        exec_kitchen_cmd ${kitchen_dir} verify "$show_log"
    fi
else
    log "skip kitchen verify"
fi
## File : kitchen_raw_test.sh ends
