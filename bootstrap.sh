#!/bin/bash
#
# This is mostly based on https://github.com/fornyx/OpenStack-Havana-Install-Guide/blob/master/OpenStack-Havana-Install-Guide.rst
#
# Tweaked a bit to work inside LXC.
#
# Needs module scsi_transport_iscsi and nbd loaded in the host
#
set -e

BASE_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LXC_NAME=icehouse-lxc
LXC_ROOTFS=/var/lib/lxc/$LXC_NAME/rootfs
LOG_FILE=/tmp/${LXC_NAME}.log
UBUNTU_MIRROR=${UBUNTU_MIRROR:-archive.ubuntu.com}
export LC_ALL=en_US.UTF-8

info() {
  >&2 echo -e "\e[32m** \e[0m$1"
}

egrep -q "DISTRIB_CODENAME=(utopic|trusty)" /etc/lsb-release || {
  info "Ubuntu Precise and Trusty are the only releases supported."
  exit 1
}

[ -f /usr/bin/lxc-attach ] || {
  info "LXC doesn't seem to be installed."
  info "Run 'sudo apt-get install lxc' first."
}

if [ `whoami` != "root" ]; then
  exec sudo $BASE_PATH/$0 $@ > $LOG_FILE
fi


info "Loading required kernel modules"
modprobe nbd
modprobe scsi_transport_iscsi
modprobe ebtables

info "Creating the LXC container"
lxc-create -n $LXC_NAME -t ubuntu -- -r precise --mirror http://$UBUNTU_MIRROR/ubuntu
lxc-start -n $LXC_NAME -d

info "Waiting for the container to get an IP..."
n=0
until [ $n -ge 5 ]; do
  sleep 5
  IP=$(lxc-ls --fancy icehouse-lxc | tail -n1 | awk '{print $3}')
  [ -n "$IP" ] && break  # substitute your command here
  n=$[$n+1]
done
echo "lxc.cgroup.devices.allow = c 10:200 rwm" >> /var/lib/lxc/$LXC_NAME/config
mkdir $LXC_ROOTFS/$LXC_NAME
cp -r * $LXC_ROOTFS/$LXC_NAME
info "Proceeding with the install"
info "Run 'tail -f $LOG_FILE' to follow progress"
info "Error messages go to $LOG_FILE.errors"
lxc-attach -n $LXC_NAME bash /$LXC_NAME/install.sh 2> $LOG_FILE.errors
info "Done!"
