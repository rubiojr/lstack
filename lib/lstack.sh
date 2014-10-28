#!/bin/bash

info() {
  >&2 echo -e "\e[32m** \e[0m$1"
}

warn() {
  >&2 echo -e "\e[33m** \e[0mWARN: $1"
}

error() {
  >&2 echo -e "\e[31m** \e[0mERROR: $1"
}

quiet() {
  $1 > /dev/null
}

debug() {
  if [ -n "$VERBOSE" ]; then
    >&2 echo -e "\e[34m** \e[0mDEBUG: $1"
  fi
}

pkg_installed?(){
  dpkg -l $1 | egrep "^ii\s+$1\s" > /dev/null
}

kvm_ok?() {
  pkg_installed? "qemu-kvm" || return 1
  local virt=$(egrep -m1 -w '^flags[[:blank:]]*:' /proc/cpuinfo | egrep -wo '(vmx|svm)') || true
  [[ "$virt" =~ ^vmx|svm$ ]] || return 1
  [ -e /dev/kvm ] || return 1
}

check_kvm_reqs() {
  kvm_ok? || {
    pkg_installed? "qemu-kvm" || warn "Missing the qemu-kvm package."
    pkg_installed? "cpu-checker" || warn "Missing the cpu-checker package."
    kvm_ok? \
      || warn "KVM support not found. Is the kvm_intel (or kvm_amd) module loaded?"
    return 1
  }
}

lxc_config_set() {
  local cname=$1
  local string=$2

  if ! grep "$string" /var/lib/lxc/$LSTACK_NAME/config; then
    echo "$string" >> /var/lib/lxc/$LSTACK_NAME/config
  else
    warn "$string already present in the container configuration"
  fi
}

need_pkg() {
  pkg_installed? $1 || {
    error "Package $1 doesn't seem to be installed."
    error "Run 'sudo apt-get install $1' first."
    exit 1
  }
}

wait_for_container_ip() {
  local cname=$1

  n=0
  until [ $n -ge 5 ]; do
    sleep 5
    IP=$(lxc-ls --fancy $cname | tail -n1 | awk '{print $3}') || true
    [ -n "$IP" ] && break  # substitute your command here
    n=$[$n+1]
  done
}

cexe() {
  cname=$1
  shift

  lxc-ls --running -1 | grep "$cname" > /dev/null || {
    error "Container '$cname' not running"
    exit 1
  }

  # lxc-attach doesn't work in precise by default
  if lxc-attach -n "$cname" /bin/true 2>/dev/null; then
    lxc-attach -n "$cname" -- $@
  else
    ssh_port=$(config_get "lstack.ssh_port" "22")
    warn "lxc-attach doesn't work here, trying SSH"
    ip=$(sshable_ip $cname)
    if [ -z "$ip" ]; then
      error "Container IP not found"
      exit 1
    fi
    ssh -q -o StrictHostKeyChecking=no \
        -p "$ssh_port" \
        -o UserKnownHostsFile=/dev/null \
        -l root \
        -i ~/.config/lstack/sshkey \
        $ip $@
  fi
}

check_distro() {
  # Preflight check
  egrep -q "DISTRIB_CODENAME=(precise|utopic|trusty)" /etc/lsb-release || {
    error "Ubuntu Utopic, Trusty and Precise are the only releases supported."
    exit 1
  }
}

sshable_ip() {
  local cname=$1

  ips=$(lxc-info -i -n $cname | cut -d' ' -f2- | tac | xargs ) || true
  if [ -z "$ips" ]; then
    error "Container IP not found"
    echo ""
  fi
  ssh_port=$(config_get "lstack.ssh_port" "22")
  for ip in $ips; do
    ssh -q -o StrictHostKeyChecking=no \
        -p "$ssh_port" \
        -o ConnectTimeout=2 \
        -o UserKnownHostsFile=/dev/null \
        -l root \
        -i ~/.config/lstack/sshkey \
        $ip true || continue
    # We've found the IP
    echo $ip; break
  done
}

needs_root() {
  if [ `whoami` != "root" ]; then
    error "Need to run as root."
    exit 1
  fi
}

instance_running?() {
  local name="$1"

  if [ -z "$name" ]; then
    error "instance_running?: invalid instance name"
    exit 1
  fi

  nova_command "list" | grep "$name" > /dev/null
}

nova_command() {

  if [ -z "$@" ]; then
    error "nova_command: no command specified"
    exit 1
  fi

  local creds="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/install/creds.sh"
  source $creds
  cexe "$LSTACK_NAME" "nova --os-username $OS_USERNAME \
                      --os-password=$OS_PASSWORD \
                      --os-tenant-name $OS_TENANT_NAME \
                      --os-auth-url $OS_AUTH_URL $@"
}

instance_ip() {
  local name=$1

  ip=$(nova_command "list" | grep "$name" | \
            grep -o "private=.*\s" | cut -d= -f2 | tr -d ' ') || true
}

config_set() {
  local key=$1
  local value=$2

  if ! [[ "$key" =~ ^lstack\. ]]; then
    warn "Container config keys must start with 'lstack.<keyname>'. Ignoring."
    return 0
  fi

  if [ -z "$value" ]; then
    error "Value for $key is empty"
    return 1
  fi

  if ! grep "^$key" /var/lib/lxc/$LSTACK_NAME/config >/dev/null; then
    echo "$key=$value" >> /var/lib/lxc/$LSTACK_NAME/config
  else
    sed -i "s/^$key.*/$key=$value/" /var/lib/lxc/$LSTACK_NAME/config
  fi
}

config_get() {
  local key="$1"
  local default="$2"

  if ! [[ "$key" =~ ^lstack\. ]]; then
    warn "Container config keys must start with 'lstack.<keyname>'. Ignoring."
    return 0
  fi

  val=$(grep "^$key" /var/lib/lxc/$LSTACK_NAME/config | cut -d= -f2)

  if [ -z "$val" ] && [ -z "$default" ]; then
    error "Config key $key does not have a value and default is not provided"
    return 1
  fi

  [ -z "$val" ] && val="$default"
  echo $val
}
