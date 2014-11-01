#!/bin/bash
set -e

BASE_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../" && pwd )"
CMD_PATH="${BASH_SOURCE[0]}"
source $BASE_PATH/lstack.sh

needs_root

running? || exit $?

ssh_port=$(config_get "lstack.ssh_port" "22")
ssh -q -o StrictHostKeyChecking=no \
    -p "$ssh_port" \
    -o ConnectTimeout=2 \
    -o UserKnownHostsFile=/dev/null \
    -l root \
    -i ~/.config/lstack/sshkey \
    $(sshable_ip $LSTACK_NAME) "$@"
