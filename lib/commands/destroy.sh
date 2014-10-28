#!/bin/bash
set -e

BASE_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../" && pwd )"
CMD_PATH="${BASH_SOURCE[0]}"
source $BASE_PATH/lstack.sh

check_distro
needs_root

if ! lxc-info -n "$LSTACK_NAME" >/dev/null 2>&1; then
  error "$LSTACK_NAME container not available"
  exit 1
fi

destroy_vg(){
  local vg_name=$1

  if [ -z "$vg_name" ]; then
    error "destroy_vg: invalid parameter"
    return 1
  fi

  # If the container was not fully provisioned vgremove may not be there
  cexe "$LSTACK_NAME" "which vgremove" > /dev/null || return 0

  debug "Removing the LVM volume"
  # try to remove the volume group only if it's there
  if cexe "$LSTACK_NAME" "vgdisplay $vg_name" > /dev/null 2>&1; then
    cexe "$LSTACK_NAME" "vgremove -f $vg_name" > /dev/null 2>&1
  fi
}

cleanup_loopdev() {
  local loopdev=$1

  if [ -z "$loopdev" ]; then
    error "cleanup_loopdev: invalid parameter"
    return 1
  fi

  debug "Cleanup the loop device"
  # if the loop device isn't found we don't need to delete it
  losetup -a | grep -q $loopdev 2>/dev/null || return 0

  losetup -d $loopdev || {
    error "Could not cleanup loop device. Aborting."
    return 1
  }
}

# If the provisioning was interrupted, the metadata file may not be there
if [ -f $LSTACK_ROOTFS/var/lib/lstack/metadata ]; then

  source $LSTACK_ROOTFS/var/lib/lstack/metadata

  # FIXME: not sure if this is actually required
  # If the container is stopped, we need to boot it to clean the
  # volume group and the loop device.
  if lxc-info -n $LSTACK_NAME | grep STOPPED >/dev/null; then
    warn "Container stopped. Booting it to clean it up."
    lxc-start -n $LSTACK_NAME -d
    wait_for_container_ip
  fi

  if [ -f $LSTACK_ROOTFS/root/creds.sh ]; then
    debug "Destroying instances"
    destroy_instances
    debug "Detroy the volume group $VGNAME"
    destroy_vg "$VGNAME"
    cleanup_loopdev "$LOOPDEV"
  fi

else
  warn "Metadata file not found. Incomplete bootstrap process?"
fi

info "Destroying the container..."
lxc-destroy -n $LSTACK_NAME -f
