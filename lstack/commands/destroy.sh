#!/bin/bash
set -e

BASE_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../" && pwd )"
CMD_PATH="${BASH_SOURCE[0]}"
source $BASE_PATH/lib.sh

check_distro

if [ `whoami` != "root" ]; then
  debug "Need to run as root, trying sudo"
  exec sudo bash $CMD_PATH $@
fi

# If the container was not fully provisioned vgrename may not be there

if cexe "lstack" "which vgremove" > /dev/null; then
  debug "Removing the LVM volume"
  # try to remove the volume group only if it's there
  if cexe "lstack" "vgdisplay cinder-volumes" > /dev/null 2>&1; then
    cexe "lstack" "vgremove -f cinder-volumes" > /dev/null 2>&1
  fi
fi

debug "Cleanup the loop device"
(losetup -a | grep -q loop6) && losetup -d /dev/loop6 || true

info "Destroying the container..."
lxc-destroy -n lstack -f
