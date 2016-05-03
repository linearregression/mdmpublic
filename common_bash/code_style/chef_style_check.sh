#!/bin/bash -e
##-------------------------------------------------------------------
## @copyright 2016 DennyZhang.com
## Licensed under MIT
##   https://raw.githubusercontent.com/DennyZhang/devops_public/master/LICENSE
##
## File : chef_style_check.sh
## Author : DennyZhang.com <denny@dennyzhang.com>
## Description :
## --
## Created : <2015-07-03>
## Updated: Time-stamp: <2016-05-03 07:56:33>
##-------------------------------------------------------------------
################################################################################################
if [ ! -f /var/lib/devops/refresh_common_library.sh ]; then
    [ -d /var/lib/devops/ ] || (sudo mkdir -p  /var/lib/devops/ && sudo chmod 777 /var/lib/devops)
    wget -O /var/lib/devops/refresh_common_library.sh \
         https://raw.githubusercontent.com/DennyZhang/devops_public/master/common_library/refresh_common_library.sh
fi
# export AVOID_REFRESH_LIBRARY=true
bash /var/lib/devops/refresh_common_library.sh "1141491927"
. /var/lib/devops/devops_common_library.sh
################################################################################################
# get default env parameter
base_dir=$(basename "$(pwd)")
if [ -z "$CURRENT_COOKBOOK" ]; then
    export COOKBOOK="../${base_dir}"
else
    export COOKBOOK="../$CURRENT_COOKBOOK"
fi

log "foodcritic $COOKBOOK"
foodcritic "$COOKBOOK"

log "rubocop $COOKBOOK"
rubocop "$COOKBOOK"
## File : chef_style_check.sh ends
