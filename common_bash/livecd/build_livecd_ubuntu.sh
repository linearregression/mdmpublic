#!/bin/bash -e
##-------------------------------------------------------------------
## @copyright 2015 DennyZhang.com
## File : build_livecd_ubuntu.sh
## Author : Denny <denny@dennyzhang.com>
## Description :
## --
## Created : <2016-01-05>
## Updated: Time-stamp: <2016-04-07 09:13:26>
##-------------------------------------------------------------------

# How to build liveCD of ubuntu: http://customizeubuntu.com/ubuntu-livecd
# Note: above instruction only support desktop version of ubuntu, instead of server version

working_dir=${1:-"/root/work/"}
fetch_iso_url=${2:-"http://releases.ubuntu.com/14.04/ubuntu-14.04.3-desktop-amd64.iso"}
livecd_image_name=${3:-"my-ubuntu-14.04.3.iso"}
volume_id=${4:-"DevOps Ubuntu"}

############################################################################
function log() {
    local msg=$*
    echo -ne `date +['%Y-%m-%d %H:%M:%S']`" $msg\n"
    
    if [ -n "$LOG_FILE" ]; then
        echo -ne `date +['%Y-%m-%d %H:%M:%S']`" $msg\n" >> $LOG_FILE
    fi
}

function fail_unless_root() {
    # Make sure only root can run our script
    if [[ $EUID -ne 0 ]]; then
        echo "Error: This script must be run as root." 1>&2
        exit 1
    fi
}

function os_release() {
    set -e
    distributor_id=$(lsb_release -a 2>/dev/null | grep 'Distributor ID' | awk -F":\t" '{print $2}')
    if [ "$distributor_id" == "RedHatEnterpriseServer" ]; then
        echo "redhat"
    elif [ "$distributor_id" == "Ubuntu" ]; then
        echo "ubuntu"
    else
        if grep CentOS /etc/issue 1>/dev/null; then
            echo "centos"
        else
            echo "ERROR: Not supported OS"
        fi
    fi
}
############################################################################
function umount_dir()
{
    local dir=${1?}

    if [ -d $dir ]; then
        fs_name=`stat --file-system --format=%T $dir`
        if [ "$fs_name" = "tmpfs" ] || [ "$fs_name" = "isofs" ]; then
            umount $dir
        fi
    fi
}

function original_ubuntu_iso() {
    local working_dir=${1?}
    local short_iso_filename=$(basename $fetch_iso_url)
    echo "$working_dir/../$short_iso_filename"
}

function livecd_clean_up() {
    umount_dir $working_dir/mnt
    umount_dir $working_dir/edit/dev
}

function clean_up_dev_mount() {
    local working_dir=${1?}
    if [ -d $working_dir/edit ]; then
        fs_name=`stat --file-system --format=%T /dev`
        if [ "$fs_name" = "tmpfs" ] || [ "$fs_name" = "isofs" ]; then
            cd $working_dir
            chroot edit umount /proc || true
            chroot edit umount /sys || true
            chroot edit umount /dev/pts || true
            umount edit/dev || true
        fi
    fi
}

function customize_ubuntu_image() {
    set -e
    log "Customize Image"
    local chroot_dir=${1?}
    local download_dir=${2:-"/data/download"}

    log "change /etc/resolv.conf"
    chroot $chroot_dir bash -c "echo nameserver 8.8.8.8 > /etc/resolv.conf"
    log "apt-get -y update"
    chroot $chroot_dir bash -c "apt-get -y update" 1>/dev/null
    chroot $chroot_dir bash -c "apt-get install -y tmux vim openssh-server" 1>/dev/null

    log "Install docker. This may take several minutes"
    chroot $chroot_dir bash -c "wget -qO- https://get.docker.com/ | sh"

    # TODO:
    # log "Enable docker autostart"
    # chroot $chroot_dir bash -c "update-rc.d docker defaults"
    # chroot $chroot_dir bash -c "update-rc.d docker enable"
}

############################################################################
# Make sure the script is run in right OS
if [[ "$(os_release)" != "ubuntu" ]]; then
    echo "Error: This script can only run in ubuntu OS." 1>&2
    exit 1
fi

# Make sure the script is run as a root
fail_unless_root
trap livecd_clean_up SIGHUP SIGINT SIGTERM 0

dst_iso="$working_dir/$livecd_image_name"

log "Install necessary packages"
which aptitude 1>/dev/null || apt-get install -y aptitude 1>/dev/null
aptitude install -y squashfs-tools genisoimage 1>/dev/null

rm -rf $working_dir && mkdir -p $working_dir
cd $working_dir
mkdir mnt

ubuntu_iso_full_path=$(original_ubuntu_iso $working_dir)
if [ ! -f $ubuntu_iso_full_path ]; then
    log "Download original ubuntu iso"
    wget -O  $ubuntu_iso_full_path $fetch_iso_url
fi

# mount mnt
clean_up_dev_mount $working_dir
log "Mount iso and extract content. This may takes ~30 seconds"
mount -o loop $(original_ubuntu_iso $working_dir) mnt
mkdir extract-cd
rsync --exclude=/casper/filesystem.squashfs -a mnt/ extract-cd

# unsquashfs
unsquashfs mnt/casper/filesystem.squashfs
mv squashfs-root edit

log "Prepare and chroot"
mount --bind /dev/ edit/dev
chroot edit mount -t proc none /proc
chroot edit mount -t sysfs none /sys
chroot edit mount -t devpts none /dev/pts

# chroot edit export HOME=/root
# chroot edit export LC_ALL=C

customize_ubuntu_image $working_dir/edit

log "Clean up and umount filesystem"
chroot edit apt-get -y update
chroot edit apt-get install -y aptitude
chroot edit aptitude clean
chroot edit rm -rf /tmp/* ~/.bash_history
# TODO
# chroot edit rm -rf /etc/resolv.conf
# chroot edit rm -rf /var/lib/dbus/machine-id
# chroot edit rm -rf /sbin/initctl
# chroot edit dpkg-divert --rename --remove /sbin/initctl

chroot edit umount /proc
chroot edit umount /sys
chroot edit umount /dev/pts
umount edit/dev

log "Regenerate Manifest"
chmod +w extract-cd/casper/filesystem.manifest
chroot edit dpkg-query -W --showformat='${Package} ${Version}\n' > extract-cd/casper/filesystem.manifest
cp extract-cd/casper/filesystem.manifest extract-cd/casper/filesystem.manifest-desktop
sed -i '/ubiquity/d' extract-cd/casper/filesystem.manifest-desktop # TODO
sed -i '/casper/d' extract-cd/casper/filesystem.manifest-desktop # TODO

log "Compress to SquashFS Filesystem. This shall take several minutes"
[ ! -f extract-cd/casper/filesystem.squashfs ] || rm extract-cd/casper/filesystem.squashfs
mksquashfs edit extract-cd/casper/filesystem.squashfs

log "Update md5sum"
cd extract-cd
rm md5sum.txt
find -type f -print0 | xargs -0 md5sum | grep -v isolinux/boot.cat | tee md5sum.txt

log "Create ISO image"
mkisofs -r -D -V "$volume_id" -cache-inodes -J -l -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -o $dst_iso .
log "Build process completed: image can be found in $dst_iso."
## File : build_livecd_ubuntu.sh ends
