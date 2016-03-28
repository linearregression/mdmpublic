#!/bin/bash -ex
##-------------------------------------------------------------------
## @copyright 2015 DennyZhang.com
## File : backup_jenkins_jobs.sh
## Author : Denny <denny@dennyzhang.com>
## Description :
## --
## Created : <2015-08-05>
## Updated: Time-stamp: <2016-03-28 16:27:21>
##-------------------------------------------------------------------
[ -d $BACKUP_DIR ] ||  mkdir -p $BACKUP_DIR
. /etc/profile

# backup files
if [ -z "$jenkins_job_dir" ]; then
    jenkins_job_dir="/var/lib/jenkins/jobs"
fi

cd $jenkins_job_dir
for f in `find . -name config.xml`; do
    rsync -R $f $BACKUP_DIR
done

backup_url="https://raw.githubusercontent.com/DennyZhang/backup_dir/master/backup_dir.sh"
backup_cksum="1605019814"
backup_dir_sh="/tmp/backup_dir.sh"
base_dir=$(dirname $backup_dir_sh)

if [ -f $backup_dir_sh ]; then
    cksum=$(cksum $backup_dir_sh | awk -F' ' '{print $1}')
    if [ "$cksum" == $backup_cksum ]; then
        echo "skip downloading backup_dir.sh, since it's already in right version"
    else
        wget -O $backup_dir_sh $backup_url
        chmod 755 $backup_dir_sh
    fi
else
    wget -O $backup_dir_sh $backup_url
    chmod 755 $backup_dir_sh
fi

# generate backup_dir.rc
cd $base_dir
> backup_dir.rc
echo "BACKUP_DIR=/tmp/backup/" >> backup_dir.rc
echo "BACKUP_SET_PREFIX=jenkins" >> backup_dir.rc

sudo bash $backup_dir_sh
## File : backup_jenkins_jobs.sh ends
