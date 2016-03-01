#!/bin/bash -e
##-------------------------------------------------------------------
## @copyright 2015 DennyZhang.com
## File : effort_report.sh
## Author : Denny <denny.zhang001@gmail.com>
## Description :
## --
## Created : <2015-10-13>
## Updated: Time-stamp: <2016-02-29 09:46:24>
##-------------------------------------------------------------------

################################################################################################
## env variables: working_dir, git_repo_url, branch_nae, start_weekday
##
## Example:
##      working_dir: /var/lib/jenkins/weekly_report
##      git_repo_url:"git@bitbucket.org:authright/devops_effort.git"
##      branch_name: master
##      start_weekday:"2015-10-12"
################################################################################################
. /etc/profile

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
    fi

    cd $working_dir/$branch_name/$git_repo
    #git reset --hard
    git checkout $branch_name 2>/dev/null
    if [ $git_pull_outside = "no" ]; then
        # add retry for network turbulence
        git pull origin $branch_name 2>/dev/null || (sleep 2 && git pull origin $branch_name 2>/dev/null)
    fi
}

function get_effort_summary() {
    #set -xe
    git_dir=${1?}
    start_pattern=${2?}
    end_pattern=${3?}
    result=""
    for f in `find $git_dir -name "effort.md"`; do
        if ! grep $end_pattern $f; then
            end_pattern="`date +'%Y'`-"
            echo "Warning: Failed to find $end_pattern in $f. Choose another pattern: $end_pattern"
        fi 
        content="`awk "/$start_pattern/,/$end_pattern/" $f | grep -v "^$start_pattern" | grep -v '^=======' | grep -v "^$end_pattern"`"   
        name=$(dirname $f)
        name=${name##*/}
        result="${result}Member - ${name}:\n${content}\n---------------------------------\n\n"
    done
    echo -e "$result"
}

if [ -z "$start_weekday" ]; then
    start_weekday=`date -d 'last Monday' '+%Y-%m-%d'`
fi

start_pattern=$start_weekday
end_pattern=$(date -d "$start_pattern -7 days" +'%Y-%m-%d')

# checkout code
git_repo=$(echo ${git_repo_url%.git} | awk -F '/' '{print $2}')
code_dir=$working_dir/$branch_name/$git_repo
output=$(git_update_code $git_repo $git_repo_url $branch_name $working_dir "no")

# parse content
content=$(get_effort_summary $code_dir "$start_pattern" "$end_pattern")
echo "Show report"
title="DevOps周报"
echo -e "☆☆☆☆ ${title}: ${start_weekday} ☆☆☆☆\n\n$content"
echo "Report is generated"
## File : effort_report.sh ends
