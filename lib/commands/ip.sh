#!/bin/bash
set -e

BASE_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../" && pwd )"
CMD_PATH="${BASH_SOURCE[0]}"
source $BASE_PATH/lstack.sh

needs_root

ips=$(lxc-info -i -n $LSTACK_NAME | cut -d' ' -f2- | tac | xargs ) || true
if [ -z "$ips" ]; then
  error "Container IP not found"
  exit 1
fi

# The container will have multiple IPs because nova-network so we wanna
# try them all till we find the one that is reachable from the host.
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
  echo $ip
  break
done
