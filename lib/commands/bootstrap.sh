#!/bin/bash
set -e

BASE_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../" && pwd )"
CMD_PATH="${BASH_SOURCE[0]}"

UBUNTU_MIRROR=${UBUNTU_MIRROR:-archive.ubuntu.com}
source $BASE_PATH/lstack.sh

install() {
  exec > "$LSTACK_LOGFILE"
  if ! cexe $LSTACK_NAME "bash /root/lstack/install/install.sh" \
       2> $LSTACK_LOGFILE.errors
  then
    error "Failed to bootstrap OpenStack"
    error "Tailing the last 5 lines of $LSTACK_LOGFILE.errors:\n\n"
    >&2 tail -n5 $LSTACK_LOGFILE.errors | \
      sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g"
    return 1
  else
    info "Done!"
    info "Horizon login: http://$(sshable_ip $LSTACK_NAME)/horizon"
    info 'user:     admin\e[K'
    info 'password: Seguridad101\e[K'
  fi
  return 0
}

main() {

  check_distro
  needs_root

  info "Bootstrapping OpenStack release: $LSTACK_OSRELEASE"
  #
  # Create the SSH key pair that will be used by lstack to SSH to the container
  # and to run remote commands.
  #
  mkdir -p $LSTACK_CONF_DIR
  [ -f $LSTACK_CONF_DIR/sshkey ] || {
    debug "Creating container SSH keypair"
    echo y | ssh-keygen -f $LSTACK_CONF_DIR/sshkey -N "" -C lstack-key -q
  }

  local found=$(lxc-ls -1 | grep $LSTACK_NAME) || true
  # --force being used, destroy the existing container first
  if [ -n "$bootstrap_force" ] && [ -n "$found" ]; then
    ( source $BASE_PATH/commands/destroy.sh )
    found=""
  fi

  if [ -n "$found" ]; then
    if lxc-info -n $LSTACK_NAME | grep RUNNING >/dev/null; then
      error "Container already running. Use --force to destroy the current one."
    else
      error "Container has been created but it's currently stopped"
      error "Run 'sudo lxc-start -n $LSTACK_NAME -d' to start it first"
    fi
    exit 1
  fi

  debug "Using Ubuntu mirror: $UBUNTU_MIRROR"

  debug "Loading required kernel modules"
  modprobe nbd
  modprobe ebtables

  __extra_args=""
  # Old version of LXC 0.7 installed, doesn't support --mirror
  if [ -f /usr/bin/lxc-version ]; then
    warn "Old lxc version $(/usr/bin/lxc-version) installed, --mirror disabled."
  else
    __extra_args="--mirror http://$UBUNTU_MIRROR/ubuntu"
  fi

  info "Creating the LXC container"
  lxc-create -n $LSTACK_NAME -t ubuntu -- \
             -r trusty \
             $__extra_args >/dev/null 2>&1 || {
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
LSTACK_OSRELEASE=$LSTACK_OSRELEASE
EOH

  # Add the SSH public key to the container so we can SSH into it
  mkdir -p $LSTACK_ROOTFS/root/.ssh
  chmod 0700 $LSTACK_ROOTFS/root/.ssh
  cp $LSTACK_CONF_DIR/sshkey.pub $LSTACK_ROOTFS/root/.ssh/authorized_keys

  install

}

usage() {
  echo
  echo "Usage: lstack bootstrap [options]"
  echo
  echo FLAGS
  echo
  columnize "--release <name>", "OpenStack release (default: juno)"
  columnize "--force",          "Destroy the container first if it already exists"
  echo
}

bootstrap_option_release()   (
  case $1 in
    '')
      error "Missing release name: juno, icehouse"
      exit 1
      ;;
    juno)
      ;;
    icehouse)
      ;;
    *)
      error "OpenStack release '$1' not supported"
      error "Currently supported releases: icehouse, juno"
      exit 1
      ;;
  esac
  export LSTACK_OSRELEASE=$1; shift; dispatch "$@"
)
bootstrap_option_help()      ( usage; )
bootstrap_option_force()     ( export bootstrap_force=1; dispatch bootstrap "$@" )
bootstrap_command_help()     ( usage; )
bootstrap_ ()                ( main )

dispatch bootstrap "$@"
