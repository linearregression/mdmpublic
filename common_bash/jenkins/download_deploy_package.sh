#!/bin/bash -e
##-------------------------------------------------------------------
## @copyright 2016 DennyZhang.com
## File : download_deploy_package.sh
## Author : DennyZhang.com <denny@dennyzhang.com>
## Description :
## --
## Created : <2015-08-05>
## Updated: Time-stamp: <2016-04-18 10:50:22>
##-------------------------------------------------------------------

################################################################################################
## env variables:
##     repo_server: http://192.168.1.2:28000/dev
##     dst_path: /var/www/repo/download/
##     download_files:
##               doc-mgr/frontend/build/libs/XXX.war
##               configuration/rest/build/libs/XXX.war
##               gateway/war/build/libs/XXX.war
################################################################################################
################################################################################################
if [ ! -f /var/lib/devops/refresh_common_library.sh ]; then
    [ -d /var/lib/devops/ ] || (sudo mkdir -p  /var/lib/devops/ && sudo chmod 777 /var/lib/devops)
    wget -O /var/lib/devops/refresh_common_library.sh \
         https://raw.githubusercontent.com/DennyZhang/devops_public/master/common_library/refresh_common_library.sh
fi
# export AVOID_REFRESH_LIBRARY=true
bash /var/lib/devops/refresh_common_library.sh "3606538101"
. /var/lib/devops/devops_common_library.sh
################################################################################################
checksum_link="$repo_server/checksum.txt"
checksum_file="/tmp/checksum.txt"

log "Download $checksum_link"
wget -O $checksum_file $checksum_link 1>/dev/null 2>/dev/null

[ -d $dst_path ] || mkdir -p $dst_path

cd $dst_path
has_file_changed=false

download_files=$(remove_hardline "$download_files")
# Check whether to re-download packages, by comparing the checksum file
for f in $download_files; do
    f=$(basename $f)
    if [ -f $f ]; then
        remote_checksum=$(grep $f $checksum_file)
        if [ $? -ne 0 ]; then
            log "ERROR: Fail to find $f in $checksum_link"
            exit 1
        else
            local_checksum=$(cksum $f)
            if [ "$remote_checksum" != "$local_checksum" ]; then
                log "Re-download $f, since it is changed in server side"
                wget -O $f "$repo_server/$f"
                has_file_changed=true
            fi
        fi
    else
        log "Download $f, since it's missing in local drive"
        wget -O $f "$repo_server/$f"
        has_file_changed=true
    fi
done

if $has_file_changed; then
    log "Update checksum, since some files are changed"
    ls -1 | grep -v checksum.txt | xargs cksum > checksum.txt
else
    log "No files are changed in remote server, since previous download"
fi
## File : download_deploy_package.sh ends
