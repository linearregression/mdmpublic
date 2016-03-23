#!/bin/bash -e
##-------------------------------------------------------------------
## @copyright 2015 DennyZhang.com
## File : jenkins_code_build.sh
## Author : Denny <denny.zhang001@gmail.com>
## Description :
## --
## Created : <2015-07-03>
## Updated: Time-stamp: <2016-01-22 10:23:12>
##-------------------------------------------------------------------

################################################################################################
## env variables:
##      working_dir: /var/lib/jenkins/code
##      git_repo_url: git@bitbucket.org:XXX/XXX.git
##      branch_name: dev
##      branch_name: dev
##      revision: HEAD
##      files_to_copy: gateway/war/build/libs/gateway-war-1.0-SNAPSHOT.war oauth2/rest-service/build/libs/oauth2-rest-1.0-SNAPSHOT.war
##      env_parameters:
##           export CLEAN_START=true
##           export FORCE_BUILD=false
##           export SKIP_COPY=false
##           export IS_PACK_FILE=false
##           export IS_GENERATE_SHA1SUM=false
##      build_command: make
################################################################################################
function remove_hardline() {
    local str=$*
    echo "$str" | tr -d '\r'
}

function current_git_sha() {
    set -e
    local src_dir=${1?}
    cd $src_dir
    sha=$(git log -n 1 | head -n 1 | grep commit | head -n 1 | awk -F' ' '{print $2}')
    echo $sha
}

function log() {
    local msg=$*
    echo -ne `date +['%Y-%m-%d %H:%M:%S']`" $msg\n"
}

function git_update_code() {
    set -e
    local git_repo=${1?}
    local git_repo_url=${2?}
    local branch_name=${3?}
    local working_dir=${4?}
    local git_pull_outside=${5:-"no"}

    log "Git update code for '$git_repo_url' to $working_dir, branch_name: $branch_name"
    # checkout code, if absent
    if [ ! -d $working_dir/$branch_name/$git_repo ]; then
        mkdir -p $working_dir/$branch_name
        cd $working_dir/$branch_name
        git clone --depth 1 $git_repo_url --branch $branch_name --single-branch
    else
        cd $working_dir/$branch_name/$git_repo
        git config remote.origin.url $git_repo_url
        if [ $git_pull_outside = "no" ]; then
            # add retry for network turbulence
            git pull origin $branch_name || (sleep 2 && git pull origin $branch_name)
        fi
    fi

    cd $working_dir/$branch_name/$git_repo
    #git reset --hard
    git checkout $branch_name
}

function copy_to_reposerver() {
    # Upload Packages to local apache vhost
    local git_repo=${1?}
    shift
    local branch_name=${1?}
    shift
    local code_dir=${1?}
    shift
    local revision_sha=${1?}
    shift
    local repo_dir=${1?}
    shift

    local files_to_copy=($*)
    files_to_copy=$(remove_hardline "$files_to_copy")
    cd $code_dir

    local repo_link="$repo_dir/$branch_name"
    local dst_dir="$repo_dir/${branch_name}_code_${revision_sha}"

    [ -d $dst_dir ] || mkdir -p $dst_dir
    [ -d $repo_link ] || mkdir -p $repo_link

    for f in ${files_to_copy[*]};do
        cp $f $dst_dir/
        file_name=`basename $f`
        rm -rf $repo_link/$file_name
        ln -s $dst_dir/$file_name $repo_link/$file_name
    done

    log "Just keep $leave_old_count old builds for $repo_dir/$branch_name_code"
    ls -d -t $repo_dir/* | grep ${branch_name}_code | head -n $leave_old_count | xargs touch
    find $repo_dir -type d -name "${branch_name}_code*" -and -mtime +1 -exec rm -r {} +
}

function pack_files(){
    # Pack war package.
    local file_dir=${1?}
    local git_repo=${2?}
    local base_name=$(basename $repo_dir)
    local package_name="${base_name}_${git_repo}.tar.gz"
    local sha1sum_name="${base_name}_${git_repo}.sha1"

    log "Packing the file ${package_name},please wait for a moment..."
    cd $file_dir
    rm -f ${package_name}
    rm -f ${sha1sum_name}
    tar zcf ${package_name} *

    if [ -n "$IS_GENERATE_SHA1SUM" ] && $IS_GENERATE_SHA1SUM ;then
        log "Generate the sha1 check file ${sha1sum_name}"
        sha1sum ${package_name} > ${sha1sum_name}
        mv ${sha1sum_name} ${repo_dir}
    fi
    mv ${package_name} ${repo_dir}
}

function generate_checksum() {
    local dst_dir=${1?}

    cd $dst_dir
    ls -1 | grep -v checksum.txt | xargs cksum > checksum.txt
}

flag_file="/var/lib/jenkins/$JOB_NAME.flag"

function shell_exit() {
    errcode=$?
    if [ $errcode -eq 0 ]; then
        echo "OK"> $flag_file
    else
        echo "ERROR"> $flag_file
    fi
    exit $errcode
}

########################################################################
trap shell_exit SIGHUP SIGINT SIGTERM 0

. /etc/profile

leave_old_count=1 # only keep one days' build by default
# Build Repo
git_repo=$(echo ${git_repo_url%.git} | awk -F '/' '{print $2}')
code_dir=$working_dir/$branch_name/$git_repo

# Global variables needed to enable the current script
env_parameters=$(remove_hardline "$env_parameters")
IFS=$'\n'
for env_variable in `echo "$env_parameters"`; do
    eval $env_variable
done
unset IFS

log "env variables. CLEAN_START: $CLEAN_START, SKIP_COPY: $SKIP_COPY, FORCE_BUILD: $FORCE_BUILD, build_command: $build_command"
if [ -n "$CLEAN_START" ] && $CLEAN_START; then
    [ ! -d $code_dir ] || rm -rf $code_dir
fi

if [ ! -d $working_dir ]; then
    sudo mkdir -p "$working_dir"
    sudo chown -R jenkins:jenkins "$working_dir"
fi

if [ -d $code_dir ]; then
    old_sha=$(current_git_sha $code_dir)
else
    old_sha=""
fi

# Update code
git_update_code $git_repo $git_repo_url $branch_name $working_dir "yes"
cd $working_dir/$branch_name/$git_repo
# add retry for network turbulence
git pull origin $branch_name || (sleep 2 && git pull origin $branch_name)

new_sha=$(current_git_sha $code_dir)
log "old_sha: $old_sha, new_sha: $new_sha"
if ! $FORCE_BUILD; then
    if [ $revision = "HEAD" ] && [ "$old_sha" = "$new_sha" ]; then
        log "No new commit, since previous build"
        if [ -f $flag_file ] && [[ `cat $flag_file` = "ERROR" ]]; then
            log "Previous build has failed"
            exit 1
        else
            exit 0
        fi
    fi
fi

cd $code_dir
git checkout $revision

log "================= Build Environment ================="
env
log "\n\n\n"

log "================= Build code: cd $code_dir ================="
sudo /usr/sbin/locale-gen --lang en_US.UTF-8
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

log "$build_command"
eval $build_command

log "================= Confirm files are generated ================="
for f in ${files_to_copy[*]};do
    if [ ! -f $f ]; then
        log "Error: $f is not created"
        exit 1
    fi
done

if [ -z "$repo_dir" ]; then
    repo_dir="/var/www/repo"
fi

if [ -n "$files_to_copy" ] && ! $SKIP_COPY; then
    log "================= Generate Packages ================="
    copy_to_reposerver $git_repo $branch_name $code_dir $new_sha $repo_dir "$files_to_copy"

    log "================= Generate checksum ================="
    generate_checksum "${repo_dir}/${branch_name}_code_${new_sha}"

    if [ -n "$IS_PACK_FILE" ] && $IS_PACK_FILE ;then
        log "================= Pack war file =================="
        pack_files "${repo_dir}/${branch_name}_code_${new_sha}" "$git_repo"
    fi
fi
## File : jenkins_code_build.sh ends
