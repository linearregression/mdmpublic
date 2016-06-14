#!/bin/bash -e
##-------------------------------------------------------------------
## File : diagnostic_jenkinsjob_slow.sh
## Author : DennyZhang.com <denny@dennyzhang.com>
## Description :
##        Note: To run the job, make sure target jenkins run has timestamper plugin properly enabled
## --
## Created : <2016-01-06>
## Updated: Time-stamp: <2016-06-12 15:08:52>
##-------------------------------------------------------------------

################################################################################################
## env variables:
##       jenkins_job:
##       job_run_id:
##       env_parameters:
##           export JENKINS_BASEURL="http://jenkins.dennyzhang.com"
##           export TOP_COUNT=40
##           export CONSOLE_FILE="/tmp/console.log"
##           export SQLITE_FILE="/tmp/console.sqlite"
##           export context_count=0
################################################################################################
. /etc/profile
if [ ! -f /var/lib/devops/refresh_common_library.sh ]; then
    [ -d /var/lib/devops/ ] || (sudo mkdir -p  /var/lib/devops/ && sudo chmod 777 /var/lib/devops)
    wget -O /var/lib/devops/refresh_common_library.sh \
         https://raw.githubusercontent.com/DennyZhang/devops_public/master/common_library/refresh_common_library.sh
fi
bash /var/lib/devops/refresh_common_library.sh "1309341070"
. /var/lib/devops/devops_common_library.sh
################################################################################################
function install_sqlite() {
    if ! sudo which sqlite 1>/dev/null 2>&1; then
        os_version=$(os_release)
        if [ "$os_version" == "ubuntu" ]; then
            echo "Install sqlite"
            sudo apt-get install -y sqlite
        else
            echo "Error: not implemented supported for OS: $os_version"
            exit 1
        fi
    fi
}
################################################################################################
source_string "$env_parameters"

[ -n "$TOP_COUNT" ] || export TOP_COUNT="40"
[ -n "$CONSOLE_FILE" ] || export CONSOLE_FILE="/tmp/console.log"
[ -n "$SQLITE_FILE" ] || export SQLITE_FILE="/tmp/console.sqlite"
[ -n "$JENKINS_BASEURL" ] || export JENKINS_BASEURL="$JENKINS_URL"

ensure_variable_isset "ERROR wrong parameter: jenkins_baseurl can't be empty" "$JENKINS_BASEURL"

# set default value
dir_name=$(dirname "$0")
py_file="${dir_name}/diagnostic_jenkinsjob_slow.py"

install_sqlite

echo "get console file"
url="${JENKINS_BASEURL}/view/All/job/$jenkins_job/$job_run_id/consoleFull"
curl -I "$url" | grep "HTTP/1.1 200"
curl -o "$CONSOLE_FILE" "$url"

echo "parse console"
rm -rf "$SQLITE_FILE"

python "$py_file"
## File : diagnostic_jenkinsjob_slow.sh ends
