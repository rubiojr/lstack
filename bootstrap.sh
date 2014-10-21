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
export LC_ALL=en_US.UTF-8

info() {
  >&2 echo "$1"
}

egrep "DISTRIB_CODENAME=(utopic|trusty|precise)" /etc/lsb-release || {
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

info "Creating the LXC container"
lxc-create -n $LXC_NAME -t ubuntu -- -r precise
lxc-start -n $LXC_NAME -d

info "Waiting for the container to get an IP..."
n=0
until [ $n -ge 5 ]; do
  IP=$(lxc-ls --fancy icehouse-lxc | tail -n1 | awk '{print $3}')
  [ -n "$IP" ] && break  # substitute your command here
  n=$[$n+1]
  sleep 5
done
mkdir $LXC_ROOTFS/$LXC_NAME
cp -r * $LXC_ROOTFS/$LXC_NAME
info "Proceeding to install. Run 'tail -f $LOG_FILE' to follow progress."
lxc-attach -n $LXC_NAME bash /$LXC_NAME/install.sh 2> $LOG_FILE.errors
