#!/usr/bin/env bash
##-------------------------------------------------------------------
## @copyright 2016 DennyZhang.com
## Licensed under MIT
##   https://raw.githubusercontent.com/DennyZhang/devops_public/master/LICENSE
##
## File : perform_load_test.sh
## Description :
## --
## Created : <2015-11-19>
## Updated: Time-stamp: <2016-04-25 14:12:30>
##-------------------------------------------------------------------

################################################################################################
if [ ! -f /var/lib/devops/refresh_common_library.sh ]; then
    [ -d /var/lib/devops/ ] || (sudo mkdir -p  /var/lib/devops/ && sudo chmod 777 /var/lib/devops)
    wget -O /var/lib/devops/refresh_common_library.sh \
         https://raw.githubusercontent.com/DennyZhang/devops_public/master/common_library/refresh_common_library.sh
fi
# export AVOID_REFRESH_LIBRARY=true
bash /var/lib/devops/refresh_common_library.sh "3313057955"
. /var/lib/devops/devops_common_library.sh
################################################################################################
jmeter_testplan="$workspace_path/jmeter_testplan.jmx"
ssh_key_file="/var/lib/jenkins/.ssh/id_rsa"
code_sh="jmeter -n -t jmeter_testplan.jmx -l jmeter_testplan_`date +['%Y-%m-%d-%H:%M:%S']`.jtl"

log "generate $jmeter_testplan"
cat > "$jmeter_testplan" <<EOF
$test_plan
EOF

log "scp $jmeter_testplan to /tmp/jmeter_testplan.jmx"
scp -i $ssh_key_file -P "$ssh_server_port" -o StrictHostKeyChecking=no "$jmeter_testplan" "root@${ssh_server_ip}:/tmp/jmeter_testplan.jmx"

log "ssh to autotest container to run the test plan: $code_sh"
ssh -i $ssh_key_file -p "$ssh_server_port" -o StrictHostKeyChecking=no "root@${ssh_server_ip}" "$code_sh"

## File : perform_load_test.sh ends