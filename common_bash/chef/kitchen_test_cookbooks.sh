#!/bin/bash -e
##-------------------------------------------------------------------
## @copyright 2016 DennyZhang.com
## File : kitchen_test_cookbooks.sh
## Author : DennyZhang.com <denny@dennyzhang.com>
## Description :
## --
## Created : <2015-07-03>
## Updated: Time-stamp: <2016-04-13 23:24:37>
##-------------------------------------------------------------------
################################################################################################
## env variables:
##      git_repo_url: git@bitbucket.org:XXX/XXX.git
##      branch_name: dev
##      working_dir: /var/lib/jenkins/code/dockerfeature
##      test_command: curl -L https://raw.githubusercontent.com/DennyZhang/data/master/jenkins/kitchen_raw_test.sh | bash
##      cookbook_list: gateway-auth oauth2-auth account-auth audit-auth mfa-auth message-auth platformportal-auth ssoportal-auth tenantadmin-auth
##      skip_cookbook_list: sandbox-test
##      must_cookbook_list: gateway-auth
##      env_parameters:
##         export SKIP_CODE_UPDATE=false
##         export KEEP_FAILED_INSTANCE=true
##         export KEEP_INSTANCE=false
##         export REMOVE_BERKSFILE_LOCK=false
##         export CLEAN_START=false
##         export TEST_KITCHEN_YAML=
##         export TEST_KITCHEN_YAML_BLACKLIST=".kitchen.vagrant.yml,.kitchen.digitalocean.yml"
################################################################################################
. /etc/profile
################################################################################################
if [ ! -f /var/lib/devops/refresh_common_library.sh ]; then
    [ -d /var/lib/devops/ ] || (sudo mkdir -p  /var/lib/devops/ && sudo chmod 777 /var/lib/devops)
    wget -O /var/lib/devops/refresh_common_library.sh \
         https://raw.githubusercontent.com/DennyZhang/devops_public/master/common_library/refresh_common_library.sh
fi
# export AVOID_REFRESH_LIBRARY=true
bash /var/lib/devops/refresh_common_library.sh "1512381967"
. /var/lib/devops/devops_common_library.sh
################################################################################################
function get_cookbooks() {
    cookbook_list=${1?}
    cookbook_dir=${2?}
    skip_cookbook_list=${3:-""}
    cd $cookbook_dir

    if [ "$cookbook_list" = "ALL" ]; then
        cookbooks=`ls -1 .`
        cookbooks="$cookbooks"
    else
        cookbooks=$(echo $cookbook_list | sed "s/,/ /g")
    fi

    # skip_cookbook_list
    cookbooks_ret=""
    for cookbook in $cookbooks; do
        if [[ "${skip_cookbook_list}" != *$cookbook* ]]; then
            cookbooks_ret="${cookbooks_ret}${cookbook} "
        fi
    done

    # must_cookbook_list
    if [ "$must_cookbook_list" = "ALL" ]; then
        must_cookbooks=`ls -1 .`
        must_cookbooks="$must_cookbooks"
    else
        must_cookbooks=$(echo $must_cookbook_list | sed "s/,/ /g")
    fi

    for cookbook in $must_cookbooks; do
        if [[ "${cookbooks_ret}" != *$cookbook* ]]; then
            cookbooks_ret="${cookbooks_ret}${cookbook} "
        fi
    done

    echo $cookbooks_ret | sed "s/ $//g"
}

function test_cookbook() {
    test_command=${1?}
    cookbook_dir=${2?}
    coobook=${3?}
    
    cd ${cookbook_dir}/${cookbook}

    MY_BUILD_ID=$(echo $BUILD_ID | tr '_' '-')
    export CURRENT_COOKBOOK=$cookbook    
    if [ -z "$INSTANCE_NAME" ]; then
        if [ -z "$BUILD_USER" ]; then
            export INSTANCE_NAME="${cookbook}-${JOB_NAME}-${MY_BUILD_ID}"
        else
            BUILD_USER=$(echo $BUILD_USER | sed 's/ /-/g')
            export INSTANCE_NAME="${cookbook}-${JOB_NAME}-${MY_BUILD_ID}-${BUILD_USER}"
        fi
    fi

    if [ -n "${TEST_KITCHEN_YAML}" ]; then
        yml_list=(${TEST_KITCHEN_YAML//,/ })
    else
        all_yml_list=$(ls -a | grep  "^\.kitchen.*\.yml$" || echo)
        black_yml_list=(${TEST_KITCHEN_YAML_BLACKLIST//,/\\n})
        yml_list=$(echo -e "${all_yml_list}\n${black_yml_list}\n${black_yml_list}" | sort | uniq -u )
    fi

    log "yml list is:${yml_list}"
    log "test $cookbook"
    log "cd `pwd`"
    log "export INSTANCE_NAME=$INSTANCE_NAME"
    log "$test_command"
    for yml in ${yml_list}; do
        log "export KITCHEN_YAML=${yml}"
        export KITCHEN_YAML=${yml}
        if ! eval "$test_command"; then
            log "ERROR $cookbook"
            failed_cookbooks="${failed_cookbooks} ${cookbook}:${yml}"
        fi
        log "failed_cookbooks=$failed_cookbooks"            
    done
    unset INSTANCE_NAME
}

function test_cookbook_list() {
    test_command=${1?}
    cookbooks=${2?}
    cookbook_dir=${3?}

    for cookbook in $cookbooks; do
        test_cookbook "${test_command}" "${cookbook_dir}" "${cookbook}"
    done
}

function shell_exit() {
    errcode=$?
    exit $errcode
}
########################################################################
git_repo=$(echo ${git_repo_url%.git} | awk -F '/' '{print $2}')
code_dir=$working_dir/$branch_name/$git_repo
env_parameters=$(remove_hardline "$env_parameters")
env_parameters=$(list_strip_comments "$env_parameters")
IFS=$'\n'
for env_variable in `echo "$env_parameters"`; do
    eval $env_variable
done
unset IFS

if [ -n "$CLEAN_START" ] && $CLEAN_START; then
    [ ! -d $code_dir ] || sudo rm -rf $code_dir
fi

if [ ! -d $working_dir ]; then
    mkdir -p "$working_dir"
    chown -R jenkins:jenkins "$working_dir"
fi

if [ -d $code_dir ]; then
    if [ -n "$REMOVE_BERKSFILE_LOCK" ] && $REMOVE_BERKSFILE_LOCK; then
        cd $code_dir/cookbooks
        git checkout */Berksfile.lock
    fi
fi

if [ -z "$SKIP_CODE_UPDATE" ] || [ ! $SKIP_CODE_UPDATE ]; then
    git_update_code $git_repo $branch_name $working_dir $git_repo_url
    cd $working_dir/$branch_name/$git_repo
    # add retry for network turbulence
    git pull origin $branch_name || (sleep 2 && git pull origin $branch_name)
fi

cookbook_dir="$code_dir/cookbooks"
cd $cookbook_dir

failed_cookbooks=""
cookbooks=$(get_cookbooks "$cookbook_list" "$cookbook_dir" "$skip_cookbook_list")

log "Get cookbooks List"
echo "cookbooks: $cookbooks"

echo "Set locale as en_US.UTF-8"
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

log "Test Cookbooks"
test_cookbook_list "$test_command" "$cookbooks" "$cookbook_dir"

if [ "$failed_cookbooks" != "" ]; then
    log "Failed cookbooks: $failed_cookbooks"
    exit 1
fi
## File : kitchen_test_cookbooks.sh ends
