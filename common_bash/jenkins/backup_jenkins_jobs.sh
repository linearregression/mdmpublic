#!/bin/bash -ex
##-------------------------------------------------------------------
## @copyright 2015 DennyZhang.com
## File : backup_jenkins_jobs.sh
## Author : Denny <denny.zhang001@gmail.com>
## Description :
## --
## Created : <2015-08-05>
## Updated: Time-stamp: <2016-01-20 15:32:52>
##-------------------------------------------------------------------
export BACKUP_DIR="/tmp/backup/"
export BACKUP_SET_PREFIX="jenkins"

[ -d $BACKUP_DIR ] ||  mkdir -p $BACKUP_DIR

# backup files
find /var/lib/jenkins/jobs -name config.xml | xargs -i cp -r --parents {} $BACKUP_DIR

if [ ! -f /usr/sbin/backup_dir.sh ]; then
    wget -O /usr/sbin/backup_dir.sh https://raw.githubusercontent.com/DennyZhang/backup_dir/master/backup_dir.sh
    chmod 755 /usr/sbin/backup_dir.sh
fi

bash /usr/sbin/backup_dir.sh
## File : backup_jenkins_jobs.sh ends
