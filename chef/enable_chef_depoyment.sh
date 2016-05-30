#!/bin/bash -e
##-------------------------------------------------------------------
## @copyright 2016 DennyZhang.com
## Licensed under MIT
##   https://raw.githubusercontent.com/DennyZhang/devops_public/master/LICENSE
##
## File : enable_chef_depoyment.sh
## Author : Denny <denny@dennyzhang.com>
## Description :
## --
## Created : <2016-04-20>
## Updated: Time-stamp: <2016-05-30 12:47:40>
##-------------------------------------------------------------------
################################################################
# How To Use
#        export git_update_url="https://raw.githubusercontent.com/TEST/test/master/git_update.sh"
#        export ssh_email="auto.devops@test.com"
#
#        export ssh_public_key="AAAAB3NzaC1yc2EAAAADAQABAAABAQClL5PmH01x8eRPQ7FsodNT172ZIXiE2CT3RhBZpPpMFCdUyFTGBRfgbX/UE86MfycPHkzNnKemFNJOqFVdzK7eTIayxX9FYPOk+ONi2sbKkwAE4No+R0d4/ehoVzflbYXRWyxLqDKkqbJPDxY39xS2V7h4bSQWwrMyeYoGBn82AW5vSoonQMIrxe+bm6zWWtL6SzsYM/KNM1T+2pfU7Rq/YQPs2tf07rauyeT3bylhUf/CUqVPt2Xpf4qgmpGqp9Hyoy7FIfBHmCgXLRpia2KhpYr0j08s8cxBx1PEJiQ6EaWO2WlzyJIqgU2t9piDHEIUd6yCPmpshLtlOvno6KN5"
#
#        export ssh_config_content="Host github.com
#          StrictHostKeyChecking no
#          User git
#          HostName github.com
#          IdentityFile /root/.ssh/git_id_rsa"
#
#        export git_deploy_key="-----BEGIN RSA PRIVATE KEY-----
#        MIIJKgIBAAKCAgEAq6Jv5VPd82Lu2WE3R4/lNeA5Txckf3FE3aKRVBhRWy1ds1V9
#        ... ...
#        GnR17IjnTN5QS4/i6WhUuCU7F4OnIwjQETRCQtDJVU+VT5CKiIsUR7/VeaBruCFB
#        ZEtPc5dStJrtTrWRf1BOMlY/by7vaXII1Bkd+jSpLNqzfOpJdNWCaK+08bSOkA==
#        -----END RSA PRIVATE KEY-----"
#
#        bash ./enable_chef_depoyment.sh
################################################################
function log() {
    local msg=$*
    date_timestamp=$(date +['%Y-%m-%d %H:%M:%S'])
    echo -ne "$date_timestamp $msg\n"

    if [ -n "$LOG_FILE" ]; then
        echo -ne "$date_timestamp $msg\n" >> "$LOG_FILE"
    fi
}

################################################################
function enable_chef_deployment() {
    mkdir -p /root/.ssh/
    log "enable chef deployment"
    install_packages "wget" "wget"
    install_packages "curl" "curl"
    install_packages "git" "git"
    download_facility "$git_update_url" "/root/git_update.sh"
    inject_git_deploy_key "/root/.ssh/git_id_rsa" "$git_deploy_key"

    if [ -n "$ssh_config_content" ]; then
        git_ssh_config "/root/.ssh/config" "$ssh_config_content"
    fi

    inject_ssh_authorized_keys "$ssh_email" "$ssh_public_key"
    install_chef "$chef_version"
}

function install_chef() {
    local chef_version=${1?}
    if ! which chef-client 1>/dev/null 2>&1; then
        (echo "version=$chef_version"; curl -L https://www.opscode.com/chef/install.sh) |  bash
    fi
}

function install_packages() {
    local package=${1?}
    local binary_name=${2?}
    if ! which "$binary_name" 1>/dev/null 2>&1; then
        apt-get install -y "$package"
    fi
}

function download_facility() {
    local url=${1?}
    local dst_file=${2:?}
    if [ ! -f "$dst_file" ]; then
        command="wget -O $dst_file $url"
        log "$command"
        eval "$command"
        chmod 755 "$dst_file"
    fi
}

function inject_git_deploy_key() {
    local ssh_key=${1?}
    shift
    local ssh_key_content=$*

    log "inject git deploy key to $ssh_key"
    cat > "$ssh_key" <<EOF
$ssh_key_content
EOF
    chmod 400 "$ssh_key"
}

function git_ssh_config() {
    local ssh_config_file=${1?}
    shift
    local ssh_config_content="$*"

    log "configure $ssh_config_file"
    cat > "$ssh_config_file" <<EOF
$ssh_config_content
EOF
}

function inject_ssh_authorized_keys() {
    local ssh_email=${1?}
    local ssh_public_key=${2?}

    local ssh_authorized_key_file="/root/.ssh/authorized_keys"

    log "inject ssh authorized keys to $ssh_authorized_key_file"
    if ! grep "$ssh_email" $ssh_authorized_key_file 1>/dev/null 2>&1; then
        echo "$ssh_public_key" >> $ssh_authorized_key_file
    fi
}
####################################
export chef_version="12.4.1"
if [ -z "$git_update_url" ]; then
   export git_update_url="https://raw.githubusercontent.com/TOTVS/mdmpublic/master/git_update.sh"
fi

if [ -z "$ssh_email" ]; then
    export ssh_email="auto.devops@totvs.com"
fi

if [ -z "$ssh_config_content" ]; then
    export ssh_config_content="Host github.com
  StrictHostKeyChecking no
  User git
  HostName github.com
  IdentityFile /root/.ssh/git_id_rsa"
fi

ssh_public_key_file="/root/ssh_id_rsa.pub"

if [ -z "$ssh_public_key" ] && [ -f "$ssh_public_key_file" ]; then
    export ssh_public_key
    ssh_public_key=$(cat "$ssh_public_key_file")
fi

# Use this key to checkout mdm devops code
if [ -z "$git_deploy_key" ]; then
    export git_deploy_key="-----BEGIN RSA PRIVATE KEY-----
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
-----END RSA PRIVATE KEY-----"
fi

enable_chef_deployment
echo "Action Done"
## File : enable_chef_depoyment.sh ends
