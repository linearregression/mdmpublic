#!/bin/bash -e
##-------------------------------------------------------------------
## File : diagnostic_jenkinsjob_slow.sh
## Author : DennyZhang.com <denny@dennyzhang.com>
## Co-Author :
## Description :
## --
## Created : <2016-01-06>
## Updated: Time-stamp: <2016-05-02 21:31:24>
##-------------------------------------------------------------------

################################################################################################
## env variables:
##       jenkins_job:
##       job_run_id:
##       env_parameters:
##           export JENKINS_BASEURL="http://jenkins.dennyzhang.com"
##           export TOP_COUNT=20
##           export CONSOLE_FILE="/tmp/console.log"
##           export SQLITE_FILE="/tmp/console.sqlite"
##           export context_count=0
################################################################################################

################################################################################################
if [ ! -f /var/lib/devops/refresh_common_library.sh ]; then
    [ -d /var/lib/devops/ ] || (sudo mkdir -p  /var/lib/devops/ && sudo chmod 777 /var/lib/devops)
    wget -O /var/lib/devops/refresh_common_library.sh \
         https://raw.githubusercontent.com/DennyZhang/devops_public/master/common_library/refresh_common_library.sh
fi
# export AVOID_REFRESH_LIBRARY=true
bash /var/lib/devops/refresh_common_library.sh "555331144"
. /var/lib/devops/devops_common_library.sh
################################################################################################
# TODO: provide a common function
echo "evaluate env"
env_parameters=$(remove_hardline "$env_parameters")
env_parameters=$(string_strip_comments "$env_parameters")
IFS=$'\n'
for env_variable in $env_parameters; do
    eval "$env_variable"
done
unset IFS

[ -n "$TOP_COUNT" ] || export TOP_COUNT="20"
[ -n "$CONSOLE_FILE" ] || export CONSOLE_FILE="/tmp/console.log"
[ -n "$SQLITE_FILE" ] || export SQLITE_FILE="/tmp/console.sqlite"
[ -n "$JENKINS_BASEURL" ] || export JENKINS_BASEURL="$JENKINS_URL"

ensure_variable_isset "ERROR wrong parameter: jenkins_baseurl can't be empty" "$JENKINS_BASEURL"

# set default value
dir_name=$(dirname "$0")
py_file="${dir_name}/diagnostic_jenkinsjob_slow.py"

echo "get console file"
url="${JENKINS_BASEURL}/view/All/job/$jenkins_job/$job_run_id/consoleFull"
curl -I "$url" | grep "HTTP/1.1 200"
curl -o "$CONSOLE_FILE" "$url"

echo "parse console"
rm -rf "$SQLITE_FILE"

python "$py_file"
## File : diagnostic_jenkinsjob_slow.sh ends
