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

  echo "$string" >> /var/lib/lxc/$cname/config
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
    error "Container '$cname' not runnig"
    exit 1
  }

  # lxc-attach doesn't work in precise by default
  if lxc-attach -n "$cname" /bin/true 2>/dev/null; then
    lxc-attach -n "$cname" -- $@
  else
    warn "lxc-attach doesn't work here, trying SSH"
    ip=$(lxc-info -i -n "$cname" | cut -d' ' -f2- | xargs | awk '{print $1}') || true
    if [ -z "$ip" ]; then
      error "Container IP not found"
      exit 1
    fi
    ssh -q -o StrictHostKeyChecking=no \
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
