#!/bin/bash
set -e

BASE_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../" && pwd )"
CMD_PATH="${BASH_SOURCE[0]}"
source $BASE_PATH/lstack.sh
volume_name=cinder-volumes
loopdev=loop6

check_distro

if [ `whoami` != "root" ]; then
  debug "Need to run as root, trying sudo"
  exec sudo bash $CMD_PATH $@
fi

# If the container was not fully provisioned vgrename may not be there

if cexe "lstack" "which vgremove" > /dev/null; then
  debug "Removing the LVM volume"
  # try to remove the volume group only if it's there
  if cexe "lstack" "vgdisplay $volume_name" > /dev/null 2>&1; then
    cexe "lstack" "vgremove -f $volume_name" > /dev/null 2>&1
  fi
fi

debug "Cleanup the loop device"
(losetup -a | grep -q $loopdev) && losetup -d /dev/$loopdev || {
  warn "Failed to detach the file from the loop device, retrying..."
  sleep 2; losetup -d /dev/$loopdev || true
  sleep 2; losetup -d /dev/$loopdev || {
    error "Could not cleanup loop device. Aborting."
    exit 1
  }
}

info "Destroying the container..."
lxc-destroy -n lstack -f
