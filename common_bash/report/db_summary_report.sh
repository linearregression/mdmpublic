#!/bin/bash -e
##-------------------------------------------------------------------
## File : db_summary_report.sh
## Author : DennyZhang.com <denny@dennyzhang.com>
## Description :
## --
## Created : <2016-02-23>
## Updated: Time-stamp: <2016-06-13 20:59:39>
##-------------------------------------------------------------------

################################################################################################
## Purpose: Show the summary information of a designated database
##
## env variables:
##      env_parameters:
##          export STDOUT_SHOW_DATA_OUT="true"
##          export CFG_DIR="/opt/devops/dump_db_summary/cfg_dir"
##          export DATA_OUT_DIR="/opt/devops/dump_db_summary/data_out"
##          export REFRESH_BASH="false"
################################################################################################
. /etc/profile
if [ ! -f /var/lib/devops/refresh_common_library.sh ]; then
    [ -d /var/lib/devops/ ] || (sudo mkdir -p  /var/lib/devops/ && sudo chmod 777 /var/lib/devops)
    wget -O /var/lib/devops/refresh_common_library.sh \
         https://raw.githubusercontent.com/DennyZhang/devops_public/master/common_library/refresh_common_library.sh
fi
bash /var/lib/devops/refresh_common_library.sh "3543853840"
. /var/lib/devops/devops_common_library.sh
################################################################################################
source_string "$env_parameters"
[ -n "$STDOUT_SHOW_DATA_OUT" ] || STDOUT_SHOW_DATA_OUT=true
[ -n "$CFG_DIR" ] || CFG_DIR="/opt/devops/dump_db_summary/cfg_dir"
[ -n "$DATA_OUT_DIR" ] || DATA_OUT_DIR="/opt/devops/dump_db_summary/data_out"
[ -n "$REFRESH_BASH" ] || REFRESH_BASH=false

# TODO: better way to update below script
bash_sh="/var/lib/devops/dump_db_summary.sh"
if [ ! -f "$bash_sh" ] || [ "$REFRESH_BASH" = "true" ]; then
    wget -O "$bash_sh" \
         https://raw.githubusercontent.com/DennyZhang/devops_public/master/bash/dump_db_summary/dump_db_summary.sh \
         1>/dev/null 2>&1
fi

[ -d "$CFG_DIR" ] || sudo mkdir -p "$CFG_DIR"; sudo chmod 777 "$CFG_DIR"
[ -d "$DATA_OUT_DIR" ] || sudo mkdir -p "$DATA_OUT_DIR"; sudo chmod 777 "$DATA_OUT_DIR"

bash -e "$bash_sh" "$STDOUT_SHOW_DATA_OUT" "$CFG_DIR" "$DATA_OUT_DIR"
## File : db_summary_report.sh ends
