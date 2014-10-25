#!/bin/bash
#
# This is mostly based on https://github.com/fornyx/OpenStack-Havana-Install-Guide/blob/master/OpenStack-Havana-Install-Guide.rst
#
# Tweaked a bit to work inside LXC.
#
# Needs module scsi_transport_iscsi and nbd loaded in the host
#
set -e
[ -n "$DEBUG" ] && set -x

LSTACK_VERSION=1.0
INSTALL_DIR=/usr/share/
BASE_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if ! [ -f "$BASE_PATH/lstack/lib.sh" ]; then
  # lib goes here when installing from a package
  BASE_PATH=$INSTALL_DIR
fi
source $BASE_PATH/lstack/dispatch.sh

lstack_command_bootstrap() ( source $BASE_PATH/lstack/commands/bootstrap.sh )
lstack_command_destroy() ( source $BASE_PATH/lstack/commands/destroy.sh )
lstack_command_nova() ( source $BASE_PATH/lstack/commands/nova.sh )
lstack_command_ssh() ( source $BASE_PATH/lstack/commands/ssh.sh )
lstack_command_help() ( source $BASE_PATH/lstack/commands/help.sh )
lstack_command_info() ( source $BASE_PATH/lstack/commands/info.sh )

lstack_option_help() ( echo "Usage: lstack [options] [command]" )
lstack_option_version() ( echo lstack v$LSTACK_VERSION )
lstack_ () ( source $BASE_PATH/lstack/commands/help.sh )

dispatch lstack "$@"
