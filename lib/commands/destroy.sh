#!/bin/bash
set -e

# command boilerplate
BASE_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../" && pwd )"
CMD_PATH="${BASH_SOURCE[0]}"
source $BASE_PATH/lstack.sh

check_distro
needs_root

if ! lxc-info -n "$LSTACK_NAME" >/dev/null 2>&1; then
  error "$LSTACK_NAME container not available"
  exit 1
fi

# FIXME: not sure if this is actually required or if there's faster and
# equaly safe way.
# If the container is stopped, we need to boot it to clean the
# volume group and the loop device.
if lxc-info -n "$LSTACK_NAME" | grep STOPPED >/dev/null; then
  warn "Container stopped. Booting it to clean it up."
  lxc-start -n "$LSTACK_NAME" -d
  wait_for_container_ip
fi

# We need to destroy the instances in case they have Cinder volumes
# attached. Otherwise we won't be able to remove the LVM volume group
# and the loopback device.
if [ -f $LSTACK_ROOTFS/root/creds.sh ]; then
  debug "Destroying instances"
  destroy_instances
else
  warn "OpenStack credentials not found. Won't destroy the instances (if any)"
fi

for volume in $(cexe "nova volume-list"|grep -v ID|awk '{print $2}'|xargs); do
  cexe "nova volume-delete $volume" || {
    error "Error deleting Cinder volume $volume"
    exit 1
  }
done

# Destroy the Volume Group used for Cinder
debug "Destroy the volume group $VGNAME"
# If the container was not fully provisioned vgremove may not be there
if cexe "$LSTACK_NAME" "which vgremove" > /dev/null; then
  debug "Removing the LVM volume group"
  # Remove the volume group only if it's there
  if cexe "$LSTACK_NAME" "vgdisplay $LSTACK_NAME-vg" > /dev/null 2>&1; then
    cexe "$LSTACK_NAME" "vgremove -f $LSTACK_NAME-vg" > /dev/null 2>&1
  fi
fi

debug "Cleanup the loop device"
# if the loop device isn't found we don't need to delete it
__loopdev=$(losetup -a | grep $LSTACK_NAME-vg 2>/dev/null | cut -d: -f1)
if [ -n "$__loopdev" ]; then
  losetup -d "$__loopdev" || {
    error "Could not cleanup loop device. Aborting."
    exit 1
  }
fi

info "Destroying the container..."
lxc-destroy -n $LSTACK_NAME -f
