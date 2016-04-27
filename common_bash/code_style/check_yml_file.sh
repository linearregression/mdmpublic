#!/bin/bash -e
##-------------------------------------------------------------------
## @copyright 2016 DennyZhang.com
## Licensed under MIT
##   https://raw.githubusercontent.com/DennyZhang/devops_public/master/LICENSE
##
## File : check_yml_file.sh
## Author : Denny <denny@dennyzhang.com>
## Description :
## --
## Created : <2016-04-03>
## Updated: Time-stamp: <2016-04-27 10:25:29>
##-------------------------------------------------------------------

base_dir=$(basename "$(pwd)")
# get default env parameter
if [ -z "$CURRENT_COOKBOOK" ]; then
    export COOKBOOK="../${base_dir}"
else
    export COOKBOOK="../$CURRENT_COOKBOOK"
fi

for yml in .kitchen*.yml*; do
    export KITCHEN_YAML=$yml
    echo "Check yml of $COOKBOOK: $yml"
    kitchen diagnose --no-instances --loader 1>/dev/null 2>&1
done
## File : check_yml_file.sh ends
