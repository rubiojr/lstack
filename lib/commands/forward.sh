#!/bin/bash
set -e

BASE_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../" && pwd )"
CMD_PATH="${BASH_SOURCE[0]}"
source $BASE_PATH/lstack.sh

instance="$1"

instance_running? "$instance" || {
  error "Instance $instance is not running"
  exit 1
}

shift
ip=$(instance_ip "$instance")
if [ -z "$ip" ]; then
  error "Could not find instance $instance private IP"
  exit 1
fi

if [ -z "$@" ]; then
  error "No ports to forward"
  exit 1
fi

for port in $@; do
  if [ "$port" = 22 ]; then
    warn "Trying to remap port 22 which is being used by the container SSH daemon"
    warn "Changing container SSH daemon port to 2200"
    sed -i 's/^Port.*/Port 2200/' $LSTACK_ROOTFS/etc/ssh/sshd_config
    cexe "$LSTACK_NAME" "service ssh restart" > /dev/null
    config_set "lstack.ssh_port" "2200"
  fi

  ! [[ "$port" =~ \d+ ]] || {
    warn "Invalid port $port, ignoring"
    continue
  }

  cat > $LSTACK_ROOTFS/etc/xinetd.d/$port << EOF
service $port
{
  flags = IPv4
  type = UNLISTED
  socket_type = stream
  wait = no
  user = root
  port = $port
  redirect = $ip $port
}
EOF

done

cexe "$LSTACK_NAME" "service xinetd restart" > /dev/null
