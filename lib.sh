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

kvm_ok?() {
  quiet "dpkg -s qemu-kvm" || return 1
  local virt=$(egrep -m1 -w '^flags[[:blank:]]*:' /proc/cpuinfo | egrep -wo '(vmx|svm)') || true
  [[ "$virt" =~ ^vmx|svm$ ]] || return 1
  [ -e /dev/kvm ] || return 1
}

check_kvm_reqs() {
  kvm_ok? || {
    quiet "dpkg -s qemu-kvm" || warn "Missing the qemu-kvm package."
    quiet "dpkg -s cpu-checker" || warn "Missing the cpu-checker package."
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
  quiet "dpkg -s $1" || {
    info "Package $1 doesn't seem to be installed."
    info "Run 'sudo apt-get install $1' first."
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
