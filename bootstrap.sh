#!/bin/bash
#
# This is mostly based on https://github.com/fornyx/OpenStack-Havana-Install-Guide/blob/master/OpenStack-Havana-Install-Guide.rst
#
# Tweaked a bit to work inside LXC.
#
# Needs module scsi_transport_iscsi and nbd loaded in the host
#
set -e
[ -n "$DEBUG" ] && set -x

BASE_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LXC_NAME=icehouse-lxc
LXC_ROOTFS=/var/lib/lxc/$LXC_NAME/rootfs
LOG_FILE=/tmp/${LXC_NAME}.log
UBUNTU_MIRROR=${UBUNTU_MIRROR:-archive.ubuntu.com}
export LC_ALL=en_US.UTF-8

source $BASE_PATH/lib.sh

if [ `whoami` != "root" ]; then
  warn "Need to run as root, trying sudo"
  exec sudo $BASE_PATH/$0 $@ > $LOG_FILE
fi

if ! [[ "$@" =~ '--force-unsupported' ]]; then
  egrep -q "DISTRIB_CODENAME=(utopic|trusty)" /etc/lsb-release || {
    error "Ubuntu Precise and Trusty are the only releases supported."
    exit 1
  }
fi

need_pkg "lxc"
need_pkg "sudo"
need_pkg "iscsitarget-dkms"

info "Loading required kernel modules"
modprobe nbd
modprobe scsi_transport_iscsi
modprobe ebtables
modprobe iscsi_trgt

info "Creating the LXC container"
quiet "lxc-create -n $LXC_NAME -t ubuntu -- -r precise --mirror http://$UBUNTU_MIRROR/ubuntu"
if check_kvm_reqs; then
  # /dev/kvm support
  info "KVM acceleration available"
  lxc_config_set $LXC_NAME "lxc.cgroup.devices.allow = c 10:232 rwm"
else
  warn "No KVM acceleration support detected, using QEMU (bad performance)."
fi
# /dev/net/tun support
lxc_config_set $LXC_NAME "lxc.cgroup.devices.allow = c 10:200 rwm"
lxc_config_set $LXC_NAME "lxc.cgroup.devices.allow = b 7:* rwm"

# lvm support inside the container
lxc_config_set $LXC_NAME "lxc.cgroup.devices.allow = c 10:236 rwm"
lxc_config_set $LXC_NAME "lxc.cgroup.devices.allow = b 252:* rwm"

lxc-start -n $LXC_NAME -d

info "Waiting for the container to get an IP..."
wait_for_container_ip $LXC_NAME

mkdir $LXC_ROOTFS/$LXC_NAME
cp -r * $LXC_ROOTFS/$LXC_NAME

# Disable KVM support if not available
kvm_ok? || sed -i "s/^virt_type.*/virt_type = qemu/" \
  $LXC_ROOTFS/$LXC_NAME/configs/nova/nova*conf

info "Proceeding with the install"
info "Run 'tail -f $LOG_FILE' to follow progress"
info "Error messages go to $LOG_FILE.errors"
lxc-attach -n $LXC_NAME bash /$LXC_NAME/install.sh 2> $LOG_FILE.errors

info "Done!"
