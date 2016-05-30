#!/bin/bash -e
################################################################################################
## @copyright 2016 DennyZhang.com
## Licensed under MIT
##   https://raw.githubusercontent.com/DennyZhang/devops_public/master/LICENSE
##
## File : protractor_verify_gui_login.sh
## Author : Denny <denny@dennyzhang.com>
## Description : collect the files across servers, and transfer to specific destination
## --
## Created : <2016-05-29>
## Updated: Time-stamp: <2016-05-30 09:16:49>
##-------------------------------------------------------------------

################################################################################################
## env variables:
##      protractor_testcase_js:
##
##      protractor_rest_server=172.17.0.6:4445
##
##      env_parameters:
##          export ssh_key_file="/var/lib/jenkins/.ssh/id_rsa"
##
################################################################################################
. /etc/profile
if [ ! -f /var/lib/devops/refresh_common_library.sh ]; then
    [ -d /var/lib/devops/ ] || (sudo mkdir -p  /var/lib/devops/ && sudo chmod 777 /var/lib/devops)
    wget -O /var/lib/devops/refresh_common_library.sh \
         https://raw.githubusercontent.com/DennyZhang/devops_public/master/common_library/refresh_common_library.sh
fi
# export AVOID_REFRESH_LIBRARY=true
bash /var/lib/devops/refresh_common_library.sh "2549425636"
. /var/lib/devops/devops_common_library.sh
################################################################################################
function shell_exit() {
    errcode=$?
    rm "$tmp_file"
    echo "If Snapshot images are generated, check http://${protractor_rest_server}/get_image/\$file_name"
    exit $errcode
}
################################################################################################
trap shell_exit SIGHUP SIGINT SIGTERM 0

source_string "$env_parameters"

ensure_variable_isset "ERROR wrong parameter: protractor_testcase_js can't be empty" "$protractor_testcase_js"
tmp_file="/tmp/testcase_$$.js"

cat > "$tmp_file" <<EOF
$protractor_testcase_js
EOF

echo "============ Run Protractor Test by API"
echo "curl -F upload=@$tmp_file http://$protractor_rest_server/protractor_request"
output=$(curl -F "upload=@$tmp_file" "http://${protractor_rest_server}/protractor_request")

echo "$output"
if echo "$output" | grep "0 failures" 1>/dev/null 2>&1; then
    echo "Action Pass"
else
    echo "Action Fail"
    exit 1
fi
## File : protractor_verify_gui_login.sh ends
