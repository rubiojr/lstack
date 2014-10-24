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

ips=$(lxc-info -i -n lstack | cut -d' ' -f2- | tac | xargs ) || true
if [ -z "$ips" ]; then
  error "Container IP not found"
  exit 1
fi

# The container will have multiple IPs because nova-network so we wanna
# try them all till we find the one that is reachable from the host.
for ip in $ips; do
  su - $SUDO_USER -c "ssh -q -o StrictHostKeyChecking=no \
      -o ConnectTimeout=2 \
      -o UserKnownHostsFile=/dev/null \
      -l root \
      -i ~/.config/lstack/sshkey \
      $ip $@" || continue
  # We've found the IP
  break
done
