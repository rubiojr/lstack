#!/bin/bash
set -e

BASE_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../" && pwd )"
CMD_PATH="${BASH_SOURCE[0]}"
source $BASE_PATH/lib.sh

need_pkg "lxc"
if [ `whoami` != "root" ]; then
  warn "Need to run as root, trying sudo"
  exec sudo bash $CMD_PATH $@
fi

lxc-ls --running -1 | grep lstack > /dev/null || {
  error "Container 'lstack' not runnig"
  exit 1
}

ip=$(lxc-info -i -n lstack | cut -d' ' -f2- | xargs | awk '{print $1}') || true
if [ -z "$ip" ]; then
  error "Container IP not found"
  exit 1
fi

ssh -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -l root \
    -i ~/.config/lstack/sshkey \
    $ip
