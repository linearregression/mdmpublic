#!/bin/bash -e
##-------------------------------------------------------------------
## @copyright 2016 DennyZhang.com
## Licensed under MIT 
##   https://raw.githubusercontent.com/DennyZhang/devops_public/master/LICENSE
##
## File : deploy_cluster.sh
## Author : DennyZhang.com <denny@dennyzhang.com>
## Description :
## --
## Created : <2015-07-03>
## Updated: Time-stamp: <2016-04-19 21:12:55>
##-------------------------------------------------------------------

################################################################################################
## env variables:
##       server_list: ip-1:port-1
##                    ip-2:port-2
##       deploy_run_list: "recipe[apt::default]","recipe[cluster-auth::multi_instance]"
##       init_run_list: "recipe[apt::default]","recipe[cluster-auth::initialize]"
##       chef_client_rb: cookbook_path ["/root/test/mydevops/cookbooks","/root/test/mydevops/community_cookbooks"]
##       chef_json:
##        {"os_basic_auth":
##                {"enable_firewall": "0",
##                "repo_server": "104.236.159.226:18000"},
##        "common_auth":
##                {"package_url": "http://172.17.42.1:28000/dev",
##                "rubygem_source": "http://rubygems.org/",
##                "service_list":["mongodb", "elasticsearch", "kibana", "logstash", "logstash_forwarder", "ldap", "redis", "mfa", "audit", "account", "message", "authz", "oauth2", "configuration", "ssoportal", "gateway", "docmgrpoc", "tenantadmin", "configuration_setup", "store_rest", "tomcat", "nginx", "haproxy"],
##                "nginx_host": "devops-cluster-nginx",
##                "haproxy_host": "devops-cluster-ha",
##                "mongodb_host": "devops-cluster-database-1",
##                "elasticsearch_host": "devops-cluster-database-1",
##                "kibana_hosts": ["devops-cluster-backend-1","devops-cluster-backend-2"],
##                "logstash_host": "devops-cluster-database-1",
##                "logstash_forwarder_hosts": ["devops-cluster-backend-1","devops-cluster-backend-2","devops-cluster-frontend-1","devops-cluster-frontend-2"],
##                "ldap_server_host": "devops-cluster-database-1",
##                "redis_host": "devops-cluster-database-1",
##                "tomcat":
##                     {"hosts": ["devops-cluster-backend-1","devops-cluster-backend-2", "devops-cluster-frontend-1","devops-cluster-frontend-2"]}}
##      }
##
##       check_command: enforce_all_nagios_check.sh "check_.*_log|check_.*_cpu"
##       devops_branch_name: master
##       env_parameters:
##             export KILL_RUNNING_CHEF_UPDATE=false
##             export CHEF_BINARY_CMD=chef-solo
##             export CODE_SH="/root/mydevops/misc/git_update.sh"
################################################################################################
if [ ! -f /var/lib/devops/refresh_common_library.sh ]; then
    [ -d /var/lib/devops/ ] || (sudo mkdir -p  /var/lib/devops/ && sudo chmod 777 /var/lib/devops)
    wget -O /var/lib/devops/refresh_common_library.sh \
         https://raw.githubusercontent.com/DennyZhang/devops_public/master/common_library/refresh_common_library.sh
fi
# export AVOID_REFRESH_LIBRARY=true
bash /var/lib/devops/refresh_common_library.sh "750668488"
. /var/lib/devops/devops_common_library.sh
################################################################################################
function bindhosts() {
    # TODO: make the code general and move to bash_common_library.sh
    local server_list=${1?}

    local hosts_list=""

    for server in ${server_list}
    do
        server_split=(${server//:/ })
        ssh_server_ip=${server_split[0]}
        ssh_port=${server_split[1]}
        ip=$(ssh $ssh_scp_args -p $ssh_port root@$ssh_server_ip ifconfig eth0 | grep "inet addr:" | awk '{print $2}' | cut -c 6-)
        hostname=$(ssh $ssh_scp_args -p $ssh_port root@$ssh_server_ip hostname)
        hosts_list="${hosts_list},${ip}:${hostname}"
    done

    cat << "EOF" > /tmp/deploy_cluster_bindhosts.sh
#!/bin/bash -xe

hosts_list=${1?}
cp /etc/hosts /tmp/hosts

hosts_arr=(${hosts_list//,/ })

for host in ${hosts_arr[@]}
do
    host_split=(${host//:/ })
    ip=${host_split[0]}
    domain=${host_split[1]}
    grep ${domain} /tmp/hosts && sed -i "/${domain}/c\\${ip}    ${domain}" /tmp/hosts ||  echo "${ip}    ${domain}" >> /tmp/hosts
done
cp -f /tmp/hosts /etc/hosts
EOF

    for server in ${server_list}
    do
        server_split=(${server//:/ })
        ssh_server_ip=${server_split[0]}
        ssh_port=${server_split[1]}
        scp $ssh_scp_args -P $ssh_port /tmp/deploy_cluster_bindhosts.sh root@$ssh_server_ip:/tmp/deploy_cluster_bindhosts.sh
        ssh $ssh_scp_args -p $ssh_port root@$ssh_server_ip bash -xe /tmp/deploy_cluster_bindhosts.sh $hosts_list
    done
}

function deploy() {
    local server=${1?}
    log "Deploy to ${server}"

    local server_split=(${server//:/ })
    local ssh_server_ip=${server_split[0]}
    local ssh_port=${server_split[1]}

    log "Prepare chef configuration"
    echo "${chef_client_rb}" > /tmp/client.rb
    echo -e "{\n\"run_list\": [${deploy_run_list}],\n$chef_json\n}" > /tmp/client.json

    scp $ssh_scp_args -P $ssh_port /tmp/client.rb root@$ssh_server_ip:/root/client.rb
    scp $ssh_scp_args -P $ssh_port /tmp/client.json root@$ssh_server_ip:/root/client.json

    log "Apply chef update"
    ssh $ssh_scp_args -p $ssh_port root@$ssh_server_ip ${CHEF_BINARY_CMD} --config /root/client.rb -j /root/client.json

    log "Deploy $server end"
}

function init_cluster() {
    local server=${1?}

    log "Initialize to $server"
    local server_split=(${server//:/ })
    local ssh_server_ip=${server_split[0]}
    local ssh_port=${server_split[1]}

    log "Prepare chef configuration"
    echo ${chef_client_rb} > /tmp/client_init.rb
    echo -e "{\n\"run_list\": [${init_run_list}],\n$chef_json\n}" > /tmp/client_init.json    

    scp $ssh_scp_args -P $ssh_port /tmp/client_init.rb root@$ssh_server_ip:/root/client_init.rb
    scp $ssh_scp_args -P $ssh_port /tmp/client_init.json root@$ssh_server_ip:/root/client_init.json

    log "Apply chef update"
    ssh $ssh_scp_args -p $ssh_port root@$ssh_server_ip ${CHEF_BINARY_CMD} --config /root/client_init.rb -j /root/client_init.json

    log "Initialize $server end"
}

function check_command() {
    local server=${1?}

    local server_split=(${server//:/ })
    local ssh_server_ip=${server_split[0]}
    local ssh_port=${server_split[1]}
    log "check server:${ssh_server_ip}:${ssh_port}"
    ssh $ssh_scp_args -p $ssh_port root@$ssh_server_ip "$check_command"
}

##########################################################################################
## bash start
##########################################################################################
server_list=$(list_strip_comments "$server_list")
echo "server_list: ${server_list}"

env_parameters=$(remove_hardline "$env_parameters")
env_parameters=$(list_strip_comments "$env_parameters")
IFS=$'\n'
for env_variable in `echo "$env_parameters"`; do
    eval $env_variable
done
unset IFS

if [ -z "${ssh_key_file}" ]; then
    ssh_key_file="/var/lib/jenkins/.ssh/id_rsa"
fi

ssh_scp_args=" -i $ssh_key_file -o StrictHostKeyChecking=no "

if [ -z "${CHEF_BINARY_CMD}"]; then
    CHEF_BINARY_CMD=chef-solo
fi

if [ -z "$git_repo_url" ]; then
    echo "Error: git_repo_url can't be empty"
fi
git_repo=$(echo ${git_repo_url%.git} | awk -F '/' '{print $2}')

if [ -z "$code_dir" ]; then
    code_dir="/root/test"
fi

if [ -z "${chef_client_rb}" ]; then
    chef_client_rb="cookbook_path [\"$code_dir/$devops_branch_name/$git_repo/cookbooks\",\"$code_dir/$devops_branch_name/$git_repo/community_cookbooks\"]"
fi

if [ -n "${chef_json}" ]; then
    chef_json=`echo $chef_json`    
    chef_json=${chef_json/#\{/}
    chef_json=${chef_json/%\}/}
fi

log "Start to bind cluster hosts"
bindhosts "$server_list"

for server in ${server_list}
do
    server_split=(${server//:/ })
    ssh_server_ip=${server_split[0]}
    ssh_port=${server_split[1]}

    if ${KILL_RUNNING_CHEF_UPDATE}; then
        log "ps -ef | grep ${CHEF_BINARY_CMD} || killall -9 ${CHEF_BINARY_CMD}"
        ssh $ssh_scp_args -p $ssh_port root@$ssh_server_ip "killall -9 ${CHEF_BINARY_CMD} || true"
    fi

    if [ -n "${CODE_SH}" ]; then
        log "Update git codes"
        ssh $ssh_scp_args -p $ssh_port root@$ssh_server_ip $CODE_SH $code_dir $git_repo_url $devops_branch_name
    fi
done

if [ -n "$backup_run_list" ]; then
    log "Start to backup"
    for server in ${server_list}
    do
        echo "TODO"
    done
    log "Backup End"
fi

if [ -n "$deploy_run_list" ]; then
    log "Star to Deploy cluster"
    for server in ${server_list}
    do
        deploy $server
    done
    log "Deploy End"
fi

if [ -n "$init_run_list" ]; then
    log "Star to Initialize cluster"
    for server in ${server_list}
    do
        init_cluster $server
    done
    log "Initialize End"
fi

if [ -n "$restart_run_list" ]; then
    for server in ${server_list}
    do
        echo "TODO"
    done
fi

if [ -n "$check_command" ]; then
    log "Start to check: $check_command"
    for server in ${server_list}
    do
        check_command $server
    done
    log "Check End"
fi
