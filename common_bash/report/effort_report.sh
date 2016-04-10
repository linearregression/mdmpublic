#!/bin/bash -e
##-------------------------------------------------------------------
## @copyright 2015 DennyZhang.com
## File : effort_report.sh
## Author : DennyZhang.com <denny@dennyzhang.com>
## Description :
## --
## Created : <2015-10-13>
## Updated: Time-stamp: <2016-04-10 14:30:33>
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
################################################################################################
if [ ! -f /var/lib/enable_common_library.sh ]; then
    wget -O /var/lib/enable_common_library.sh \
         https://raw.githubusercontent.com/DennyZhang/devops_public/master/common_library/enable_common_library.sh
fi
# export AVOID_REFRESH_LIBRARY=true
bash /var/lib/enable_common_library.sh "1512381967"
################################################################################################

function get_effort_summary() {
    #set -xe
    git_dir=${1?}
    start_pattern=${2?}
    end_pattern=${3?}
    result=""
    for f in `find $git_dir -name "effort.md"`; do
        if ! grep $end_pattern $f >/dev/null 2>&1 ; then
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
