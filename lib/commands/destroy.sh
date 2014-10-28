#!/bin/bash
set -e

BASE_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../" && pwd )"
CMD_PATH="${BASH_SOURCE[0]}"
source $BASE_PATH/lstack.sh
volume_name=cinder-volumes
loopdev=loop6

check_distro
needs_root

# FIXME: not sure if this is actually required
# If the container is stopped, we need to boot it to clean the
# volume group and the loop device.
if lxc-info -n $LSTACK_NAME | grep STOPPED >/dev/null; then
  warn "Container stopped. Booting it to clean it up."
  lxc-start -n $LSTACK_NAME -d
  wait_for_container_ip
fi

# If the container was not fully provisioned vgrename may not be there
if cexe "$LSTACK_NAME" "which vgremove" > /dev/null; then
  debug "Removing the LVM volume"
  # try to remove the volume group only if it's there
  if cexe "$LSTACK_NAME" "vgdisplay $volume_name" > /dev/null 2>&1; then
    cexe "$LSTACK_NAME" "vgremove -f $volume_name" > /dev/null 2>&1
  fi
fi

debug "Cleanup the loop device"
if losetup -a | grep -q $loopdev; then
  losetup -d /dev/$loopdev || {
    warn "Failed to detach the file from the loop device, retrying..."
    sleep 2; losetup -d /dev/$loopdev || {
      error "Could not cleanup loop device. Aborting."
      exit 1
    }
  }
fi

info "Destroying the container..."
lxc-destroy -n $LSTACK_NAME -f
