#!/bin/bash
set -e

BASE_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../" && pwd )"
CMD_PATH="${BASH_SOURCE[0]}"
source $BASE_PATH/lib.sh

need_pkg "lxc"
if [ `whoami` != "root" ]; then
  warn "Need to run as root, trying sudo"
  exec sudo bash $CMD_PATH $@
fi

info "Removing the LVM volume"
cexe "oslxc" "vgremove -f cinder-volumes"

info "Destroying the container"
lxc-destroy -n oslxc -f

info "Cleanup the loop device"
losetup -d /dev/loop6
