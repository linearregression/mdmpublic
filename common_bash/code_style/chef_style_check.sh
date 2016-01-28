#!/bin/bash -e
##-------------------------------------------------------------------
## @copyright 2015 DennyZhang.com
## File : chef_style_check.sh
## Author : Denny <denny.zhang001@gmail.com>
## Description :
## --
## Created : <2015-07-03>
## Updated: Time-stamp: <2016-01-20 15:33:27>
##-------------------------------------------------------------------
function log() {
    local msg=$*
    echo -ne `date +['%Y-%m-%d %H:%M:%S']`" $msg\n"
}

# get default env parameter
if [ -z "$CURRENT_COOKBOOK" ]; then
    export COOKBOOK="../"$(basename $(pwd))
else
    export COOKBOOK="../$CURRENT_COOKBOOK"
fi

log "foodcritic $COOKBOOK"
foodcritic $COOKBOOK

log "rubocop $COOKBOOK"
rubocop $COOKBOOK
## File : chef_style_check.sh ends
