#!/bin/bash -e
##-------------------------------------------------------------------
## @copyright 2016 DennyZhang.com
## File : check_yml_file.sh
## Author : Denny <denny@dennyzhang.com>
## Description :
## --
## Created : <2016-04-03>
## Updated: Time-stamp: <2016-04-18 10:13:28>
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

for yml in `ls -1 .kitchen*.yml*`; do
    export KITCHEN_YAML=$yml
    echo "Check yml of $COOKBOOK: $yml"
    kitchen diagnose --no-instances --loader 2>&1 1>/dev/null
done
## File : check_yml_file.sh ends
