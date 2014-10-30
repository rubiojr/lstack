#!/bin/bash
set -e

BASE_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../" && pwd )"
CMD_PATH="${BASH_SOURCE[0]}"

UBUNTU_MIRROR=${UBUNTU_MIRROR:-archive.ubuntu.com}
source $BASE_PATH/lstack.sh

check_distro
needs_root

install() {
  exec > "$LSTACK_LOGFILE"
  if ! cexe $LSTACK_NAME "bash /root/lstack/install/install.sh" \
       2> $LSTACK_LOGFILE.errors
  then
    error "Failed to bootstrap OpenStack"
    error "Tailing the last 5 lines of $LSTACK_LOGFILE.errors:\n\n"
    >&2 tail -n5 $LSTACK_LOGFILE.errors | \
      sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g"
    exit 1
  else
    info "Done!"
    info "Horizon login: http://$(sshable_ip $LSTACK_NAME)"
    info "user:     admin"
    info "password: Seguridad101"
  fi
}

mkdir -p $LSTACK_CONF_DIR
[ -f $LSTACK_CONF_DIR/sshkey ] || {
  info "Creating container SSH keypair"
  echo y | ssh-keygen -f $LSTACK_CONF_DIR/sshkey -N "" -C lstack-key -q
}

found=$(lxc-ls -1 | grep $LSTACK_NAME) || true
if [ -n "$found" ]; then
  if lxc-info -n $LSTACK_NAME | grep RUNNING >/dev/null; then
    [ "$1" = "-q" ] || warn "Container already running."
  else
    error "Container has been created but it's currently stopped"
    error "Run 'sudo lxc-start -n $LSTACK_NAME -d' to start it first"
  fi
else

  debug "Using Ubuntu mirror: $UBUNTU_MIRROR"

  debug "Loading required kernel modules"
  modprobe nbd
  modprobe scsi_transport_iscsi
  modprobe ebtables
  modprobe iscsi_trgt

  info "Creating the LXC container"
  lxc-create -n $LSTACK_NAME -t ubuntu -- \
             -r precise \
             --mirror http://$UBUNTU_MIRROR/ubuntu >/dev/null 2>&1 || {
    error "Failed to create the container"
    exit 1
  }

  # Enable KVM support
  if check_kvm_reqs; then
    # /dev/kvm support
    lxc_config_set $LSTACK_NAME "lxc.cgroup.devices.allow = c 10:232 rwm"
    HYPERVISOR=kvm
  else
    warn "No KVM acceleration support detected, using QEMU (bad performance)."
  fi

  # /dev/net/tun support
  lxc_config_set $LSTACK_NAME "lxc.cgroup.devices.allow = c 10:200 rwm"
  lxc_config_set $LSTACK_NAME "lxc.cgroup.devices.allow = b 7:* rwm"

  # lvm support inside the container
  lxc_config_set $LSTACK_NAME "lxc.cgroup.devices.allow = c 10:236 rwm"
  lxc_config_set $LSTACK_NAME "lxc.cgroup.devices.allow = b 252:* rwm"

  # /dev/loop* for loop mounting
  lxc_config_set $LSTACK_NAME "lxc.cgroup.devices.allow = b 7:* rwm"
  lxc_config_set $LSTACK_NAME "lxc.cgroup.devices.allow = c 10:237 rwm"

  lxc-start -n $LSTACK_NAME -d

  debug "Waiting for the container to get an IP..."
  wait_for_container_ip $LSTACK_NAME

  mkdir $LSTACK_ROOTFS/$LSTACK_NAME
  cp -r $BASE_PATH/ $LSTACK_ROOTFS/root/lstack

  # Disable KVM support if not available
  kvm_ok? || sed -i "s/^virt_type.*/virt_type = qemu/" \
    $LSTACK_ROOTFS/root/lstack/configs/nova/nova*conf

  info "Run 'tail -f $LSTACK_LOGFILE' to follow progress"
  info "Error messages go to $LSTACK_LOGFILE.errors"
  info "Proceeding with the install (takes from 3 to 10 min)..."

  # Redirect stdout to log file
  mkdir -p $LSTACK_ROOTFS/var/lib/lstack/
  cat > $LSTACK_ROOTFS/var/lib/lstack/metadata << EOH
HYPERVISOR=$HYPERVISOR
VGNAME=$LSTACK_NAME-vg
EOH

  # Add the SSH public key to the container so we can SSH into it
  mkdir -p $LSTACK_ROOTFS/root/.ssh
  chmod 0700 $LSTACK_ROOTFS/root/.ssh
  cp $LSTACK_CONF_DIR/sshkey.pub $LSTACK_ROOTFS/root/.ssh/authorized_keys

  if [ -n "$LSTACK_QUIET" ] || [ -n "$LSTACK_NONYANCAT" ]; then
    install
  else
    install &
    source $BASE_PATH/nyancat.sh $!
  fi
fi
