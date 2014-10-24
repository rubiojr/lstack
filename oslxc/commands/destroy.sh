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

# If the container was not fully provisioned vgrename may not be there
if cexe "oslxc" "which vgremove"; then
  info "Removing the LVM volume"
  # try to remove the volume group only if it's there
  cexe "oslxc" "vgdisplay cinder-volumes" && \
    cexe "oslxc" "vgremove -f cinder-volumes"
  info "Cleanup the loop device"
  (losetup -a | grep loop6) && losetup -d /dev/loop6 || true
fi

info "Destroying the container"
lxc-destroy -n oslxc -f
