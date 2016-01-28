#!/usr/bin/env bash
##-------------------------------------------------------------------
## @copyright 2015 DennyZhang.com
## File : perform_load_test.sh
## Description :
## --
## Created : <2015-11-19>
## Updated: Time-stamp: <2016-01-20 15:35:02>
##-------------------------------------------------------------------

function log() {
    local msg=$*
    echo -ne `date +['%Y-%m-%d %H:%M:%S']`" $msg\n"
}

#################################################################################

jmeter_testplan="$workspace_path/jmeter_testplan.jmx"
ssh_key_file="/var/lib/jenkins/.ssh/id_rsa"
code_sh="jmeter -n -t jmeter_testplan.jmx -l jmeter_testplan_`date +['%Y-%m-%d-%H:%M:%S']`.jtl"

log "generate $jmeter_testplan"
cat > $jmeter_testplan <<EOF
$test_plan
EOF

log "scp $jmeter_testplan to /tmp/jmeter_testplan.jmx"
scp -i $ssh_key_file -P $ssh_server_port -o StrictHostKeyChecking=no $jmeter_testplan root@$ssh_server_ip:/tmp/jmeter_testplan.jmx

log "ssh to autotest container to run the test plan: $code_sh"
ssh -i $ssh_key_file -p $ssh_server_port -o StrictHostKeyChecking=no root@$ssh_server_ip $code_sh

## File : perform_load_test.sh ends