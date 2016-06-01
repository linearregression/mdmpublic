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
## Updated: Time-stamp: <2016-05-31 12:14:33>
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
##       ssh_private_key: XXX
##           # ssh id_rsa private key to login servers without password
##       env_parameters:
##             export KILL_RUNNING_CHEF_UPDATE=false
##             export CHEF_BINARY_CMD=chef-client
##             export CODE_SH="/root/mydevops/misc/git_update.sh"
################################################################################################
. /etc/profile
if [ ! -f /var/lib/devops/refresh_common_library.sh ]; then
    [ -d /var/lib/devops/ ] || (sudo mkdir -p  /var/lib/devops/ && sudo chmod 777 /var/lib/devops)
    wget -O /var/lib/devops/refresh_common_library.sh \
         https://raw.githubusercontent.com/DennyZhang/devops_public/master/common_library/refresh_common_library.sh
fi
# export AVOID_REFRESH_LIBRARY=true
bash /var/lib/devops/refresh_common_library.sh "1788082022"
. /var/lib/devops/devops_common_library.sh
################################################################################################
function bindhosts() {
    # TODO: make the code general and move to bash_common_library.sh
    local server_list=${1?}

    local hosts_list=""
    local ssh_args="-i $ssh_key_file -o StrictHostKeyChecking=no"

    for server in ${server_list}
    do
        server_split=(${server//:/ })
        ssh_server_ip=${server_split[0]}
        ssh_port=${server_split[1]}
        ssh_command="ssh $ssh_args -p $ssh_port root@$ssh_server_ip ifconfig eth0 | grep 'inet addr:' | awk '{print \$2}' | cut -c 6-"
        ip=$(eval "$ssh_command")

        ssh_command="ssh $ssh_args -p $ssh_port root@$ssh_server_ip hostname"
        hostname=$(eval "$ssh_command")
        hosts_list="${hosts_list},${ip}:${hostname}"
    done

    # Fix acl issue
    sudo touch /tmp/deploy_cluster_bindhosts.sh
    sudo chmod 777 /tmp/deploy_cluster_bindhosts.sh
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
        ssh_command="scp $ssh_args -P $ssh_port /tmp/deploy_cluster_bindhosts.sh root@$ssh_server_ip:/tmp/deploy_cluster_bindhosts.sh"
        $ssh_command

        ssh_command="ssh $ssh_args -p $ssh_port root@$ssh_server_ip bash -xe /tmp/deploy_cluster_bindhosts.sh $hosts_list"
        $ssh_command
    done
}

function deploy() {
    local server=${1?}
    log "Deploy to ${server}"

    local server_split=(${server//:/ })
    local ssh_server_ip=${server_split[0]}
    local ssh_port=${server_split[1]}

    log "Prepare chef configuration"
    cat > /tmp/client.rb <<EOF
file_cache_path "/var/chef/cache"
$chef_client_rb
EOF
    echo -e "{\n\"run_list\": [${deploy_run_list}],\n$chef_json\n}" > /tmp/client.json

    
    ssh_command="scp $ssh_scp_args -P $ssh_port /tmp/client.rb root@$ssh_server_ip:/root/client.rb"
    $ssh_command

    ssh_command="scp $ssh_scp_args -P $ssh_port /tmp/client.json root@$ssh_server_ip:/root/client.json"
    $ssh_command

    log "Apply chef update"
    # TODO: use chef-zero, instead of chef-solo
    # ssh_command="ssh $ssh_scp_args -p $ssh_port root@$ssh_server_ip $CHEF_BINARY_CMD --config /root/client.rb -j /root/client.json --local-mode"
    ssh_command="ssh $ssh_scp_args -p $ssh_port root@$ssh_server_ip $CHEF_BINARY_CMD --config /root/client.rb -j /root/client.json"
    $ssh_command

    log "Deploy $server end"
}

function init_cluster() {
    local server=${1?}

    log "Initialize to $server"
    local server_split=(${server//:/ })
    local ssh_server_ip=${server_split[0]}
    local ssh_port=${server_split[1]}

    log "Prepare chef configuration"
    echo "$chef_client_rb" > /tmp/client_init.rb
    echo -e "{\n\"run_list\": [${init_run_list}],\n$chef_json\n}" > /tmp/client_init.json

    ssh_command="scp $ssh_scp_args -P $ssh_port /tmp/client_init.rb root@$ssh_server_ip:/root/client_init.rb"
    $ssh_command

    ssh_command="scp $ssh_scp_args -P $ssh_port /tmp/client_init.json root@$ssh_server_ip:/root/client_init.json"
    $ssh_command

    log "Apply chef update"
    ssh_command="ssh $ssh_scp_args -p $ssh_port root@$ssh_server_ip $CHEF_BINARY_CMD --config /root/client_init.rb -j /root/client_init.json"
    $ssh_command

    log "Initialize $server end"
}

function check_command() {
    local server=${1?}

    local server_split=(${server//:/ })
    local ssh_server_ip=${server_split[0]}
    local ssh_port=${server_split[1]}
    log "check server:${ssh_server_ip}:${ssh_port}"
    ssh_command="ssh $ssh_scp_args -p $ssh_port root@$ssh_server_ip $check_command"
    $ssh_command
}

##########################################################################################
source_string "$env_parameters"
server_list=$(string_strip_comments "$server_list")
echo "server_list: ${server_list}"
check_list_fields "IP:TCP_PORT" "$server_list"

[ -n "${ssh_key_file}" ] || ssh_key_file="/var/lib/jenkins/.ssh/ci_id_rsa"

# TODO: use chef-zero, instead of chef-solo
#[ -n "${CHEF_BINARY_CMD}" ] || CHEF_BINARY_CMD=chef-client
[ -n "${CHEF_BINARY_CMD}" ] || CHEF_BINARY_CMD=chef-solo
[ -n "$code_dir" ] || code_dir="/root/test"

if [ -n "$ssh_private_key" ]; then
    mkdir -p /var/lib/jenkins/.ssh/
    if [ -f "$ssh_key_file" ]; then
        chmod 777 "$ssh_key_file"
    fi
    echo "$ssh_private_key" > "$ssh_key_file"
    chmod 400 "$ssh_key_file"
fi

ssh_scp_args=" -i $ssh_key_file -o StrictHostKeyChecking=no "

if [ -z "$git_repo_url" ]; then
    echo "Error: git_repo_url can't be empty"
fi
git_repo=$(echo "${git_repo_url%.git}" | awk -F '/' '{print $2}')


if [ -z "${chef_client_rb}" ]; then
    chef_client_rb="cookbook_path [\"$code_dir/$devops_branch_name/$git_repo/cookbooks\",\"$code_dir/$devops_branch_name/$git_repo/community_cookbooks\"]"
fi

if [ -n "${chef_json}" ]; then
    chef_json=$(string_strip_comments "$chef_json")
    chef_json="$chef_json"
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
        # TODO: what if $CHEF_BINARY_CMD has whitespace?
        log "ps -ef | grep ${CHEF_BINARY_CMD} || killall -9 ${CHEF_BINARY_CMD}"
        ssh_command="ssh $ssh_scp_args -p $ssh_port root@$ssh_server_ip killall -9 $CHEF_BINARY_CMD || true"
        $ssh_command
    fi

    if [ -n "${CODE_SH}" ]; then
        log "Update git codes"
        ssh_command="ssh $ssh_scp_args -p $ssh_port root@$ssh_server_ip $CODE_SH $code_dir $git_repo_url $devops_branch_name"
        $ssh_command
    fi
done

if [ -n "$backup_run_list" ]; then
    log "Start to backup"
    for server in ${server_list}
    do
        echo "TODO: implement logic"
    done
    log "Backup End"
fi

if [ -n "$deploy_run_list" ]; then
    log "Star to Deploy cluster"
    for server in ${server_list}
    do
        deploy "$server"
    done
    log "Deploy End"
fi

if [ -n "$init_run_list" ]; then
    log "Star to Initialize cluster"
    for server in ${server_list}
    do
        init_cluster "$server"
    done
    log "Initialize End"
fi

if [ -n "$restart_run_list" ]; then
    for server in ${server_list}
    do
        echo "TODO: implement logic"
    done
fi

if [ -n "$check_command" ]; then
    log "Start to check: $check_command"
    for server in ${server_list}
    do
        check_command "$server"
    done
    log "Check End"
fi
## File : deploy_cluster.sh ends
