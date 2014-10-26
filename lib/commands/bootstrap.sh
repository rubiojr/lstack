#!/bin/bash
set -e

BASE_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../" && pwd )"
CMD_PATH="${BASH_SOURCE[0]}"
LXC_NAME=lstack
LXC_ROOTFS=/var/lib/lxc/$LXC_NAME/rootfs
LOG_FILE=/tmp/${LXC_NAME}.log
UBUNTU_MIRROR=${UBUNTU_MIRROR:-archive.ubuntu.com}
INSTALL_DIR=/usr/share/lstack
export LC_ALL=en_US.UTF-8
BOOTSTRAP_DIR=$LXC_ROOTFS/root/lstack
BOOTSTRAP_CDIR=/root/lstack/
CONF_DIR=$HOME/.config/lstack
source $BASE_PATH/lstack.sh

check_distro
needs_root

mkdir -p $CONF_DIR
[ -f $CONF_DIR/sshkey ] || {
  info "Creating container SSH keypair"
  echo y | ssh-keygen -f $CONF_DIR/sshkey -N "" -C lstack-key -q
}

found=$(lxc-ls -1 | grep lstack) || true
if [ -n "$found" ]; then
  [ "$1" = "-q" ] || warn "Container already running."
else

  debug "Using Ubuntu mirror: $UBUNTU_MIRROR"

  info "Loading required kernel modules"
  modprobe nbd
  modprobe scsi_transport_iscsi
  modprobe ebtables
  modprobe iscsi_trgt

  info "Creating the LXC container"
  quiet "lxc-create -n $LXC_NAME -t ubuntu -- -r precise --mirror http://$UBUNTU_MIRROR/ubuntu"

  # Enable KVM support
  if check_kvm_reqs; then
    # /dev/kvm support
    info "KVM acceleration available"
    lxc_config_set $LXC_NAME "lxc.cgroup.devices.allow = c 10:232 rwm"
    HYPERVISOR=kvm
  else
    warn "No KVM acceleration support detected, using QEMU (bad performance)."
  fi

  # /dev/net/tun support
  lxc_config_set $LXC_NAME "lxc.cgroup.devices.allow = c 10:200 rwm"
  lxc_config_set $LXC_NAME "lxc.cgroup.devices.allow = b 7:* rwm"

  # lvm support inside the container
  lxc_config_set $LXC_NAME "lxc.cgroup.devices.allow = c 10:236 rwm"
  lxc_config_set $LXC_NAME "lxc.cgroup.devices.allow = b 252:* rwm"

  # /dev/loop* for loop mounting
  lxc_config_set $LXC_NAME "lxc.cgroup.devices.allow = b 7:* rwm"
  lxc_config_set $LXC_NAME "lxc.cgroup.devices.allow = c 10:237 rwm"

  lxc-start -n $LXC_NAME -d

  info "Waiting for the container to get an IP..."
  wait_for_container_ip $LXC_NAME

  mkdir $LXC_ROOTFS/$LXC_NAME
  cp -r $BASE_PATH/ $BOOTSTRAP_DIR

  # Disable KVM support if not available
  kvm_ok? || sed -i "s/^virt_type.*/virt_type = qemu/" \
    $BOOTSTRAP_DIR/configs/nova/nova*conf

  info "Proceeding with the install"
  info "Run 'tail -f $LOG_FILE' to follow progress"
  info "Error messages go to $LOG_FILE.errors"

  # Redirect stdout to log file
  exec > "$LOG_FILE"

  cat > $BOOTSTRAP_DIR/metadata << EOH
HYPERVISOR=$HYPERVISOR
EOH

  # Add the SSH public key to the container so we can SSH into it
  mkdir -p $LXC_ROOTFS/root/.ssh
  chmod 0700 $LXC_ROOTFS/root/.ssh
  cp $CONF_DIR/sshkey.pub $LXC_ROOTFS/root/.ssh/authorized_keys

  if ! cexe $LXC_NAME "bash $BOOTSTRAP_CDIR/install/install.sh" \
       2> $LOG_FILE.errors
  then
    error "Failed to bootstrap OpenStack"
    error "Tailing the last 5 lines of $LOG_FILE.errors:\n\n"
    >&2 tail -n5 $LOG_FILE.errors | \
      sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g"
    exit 1
  fi

  info "Done!"
fi
