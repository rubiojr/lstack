#!/bin/bash
set -e

BASE_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../" && pwd )"
CMD_PATH="${BASH_SOURCE[0]}"
source $BASE_PATH/lstack.sh

needs_root

lxc-ls --running -1 | grep $LSTACK_NAME > /dev/null || {
  error "Container '$LSTACK_NAME' not running"
  exit 1
}

info "Retrieving container info"
lxc-info -n $LSTACK_NAME
