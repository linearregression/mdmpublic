#!/bin/bash -e
##-------------------------------------------------------------------
## @copyright 2015 DennyZhang.com
## File : chef_style_check.sh
## Author : DennyZhang.com <denny@dennyzhang.com>
## Description :
## --
## Created : <2015-07-03>
## Updated: Time-stamp: <2016-04-10 12:18:03>
##-------------------------------------------------------------------
################################################################################################
if [ ! -f /var/lib/enable_common_library.sh ]; then
    wget -O /var/lib/enable_common_library.sh \
         https://raw.githubusercontent.com/DennyZhang/devops_public/master/common_library/enable_common_library.sh
fi
# export AVOID_REFRESH_LIBRARY=true
bash /var/lib/enable_common_library.sh "1512381967"
################################################################################################
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
