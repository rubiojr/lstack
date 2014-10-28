#!/bin/bash
set -e

BASE_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../" && pwd )"
CMD_PATH="${BASH_SOURCE[0]}"
source $BASE_PATH/lstack.sh

check_distro
needs_root

source /var/lib/lxc/$LSTACK_NAME/rootfs/var/lib/lstack/metadata

if [ -z "$LSTACK_NAME" ]; then
  error "LSTACK_NAME not set. That should not happen."
  exit 1
fi

if [ -z "$VGNAME" ]; then
  error "VGNAME not set. Invalid metadata info."
  exit 1
fi

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
  if cexe "$LSTACK_NAME" "vgdisplay $VGNAME" > /dev/null 2>&1; then
    cexe "$LSTACK_NAME" "vgremove -f $VGNAME" > /dev/null 2>&1
  fi
fi

debug "Cleanup the loop device"
if losetup -a | grep -q $LOOPDEV; then
  losetup -d /dev/$LOOPDEV || {
    warn "Failed to detach the file from the loop device, retrying..."
    sleep 2; losetup -d /dev/$loopdev || {
      error "Could not cleanup loop device. Aborting."
      exit 1
    }
  }
fi

info "Destroying the container..."
lxc-destroy -n $LSTACK_NAME -f
