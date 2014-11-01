#!/bin/bash
set -e

green()  { color "32" "$1"; }
yellow() { color "33" "$1"; }
red()    { color "31" "$1"; }
color()  {
  if [ "$LSTACK_NOCOLOR" = 1 ]; then
    echo "** $2";
  else
    >&2 echo -e "\e[${1}m**\e[0m $2";
  fi
}

info() {
  [ -n "$LSTACK_QUIET" ] || green "INFO: $1"
}

warn() {
  [ -n "$LSTACK_QUIET" ] || yellow "WARN: $1"
}

error() {
  red "ERROR: $1"
}

debug() {
  if [ -n "$LSTACK_DEBUG" ]; then
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

running?(){
  lxc-ls --running -1 | grep "$LSTACK_NAME" > /dev/null || {
    error "Container '$LSTACK_NAME' not running"
    return 1
  }
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
  local min=$2

  pkg_installed? $1 || {
    error "Package $1 doesn't seem to be installed."
    error "Run 'sudo apt-get install $1' first."
    return 1
  }

  # no minimum version specified, return
  [ -z "$min" ] && return 0

  local iver=$(dpkg-query -W --showformat='${Version}\n' $1)
  if dpkg --compare-versions $iver lt $min; then
    error "Package $1 version needs to be greater than $min"
    return 1
  fi
}

wait_for_container_ip() {
  local cname=$1

  local ip=""
  local n=0
  until [ $n -ge 5 ]; do
    sleep 5
    ip=$(lxc-ls --fancy $cname | tail -n1 | awk '{print $3}') || true
    [ -n "$ip" ] && break  # substitute your command here
    n=$[$n+1]
  done

  if [ -z "$ip" ]; then
    error "Error while waiting for the container to get an IP"
    return 1
  fi
}

cexe() {
  cname=$1
  shift

  running?

  # lxc-attach doesn't work in precise by default
  if lxc-attach -n "$cname" /bin/true 2>/dev/null; then
    lxc-attach -n "$cname" -- $@
  else
    ssh_port=$(config_get "lstack.ssh_port" "22")
    debug "lxc-attach doesn't work here, trying SSH"
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
  ostack_command nova $@
}

instance_ip() {
  local name=$1

  nova_command "list" | grep "$name" | \
               grep -o "private=.*\s" | cut -d= -f2 | tr -d ' '
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

glance_command() {
  ostack_command glance $@
}

glance_import() {
  local image_file=$1
  local image_name=$2
  local image_id=""

  local target_file=$(mktemp -u)
  ln -f "$image_file" "$LSTACK_ROOTFS$target_file"
  image_id=$(glance_command "image-create --name $image_name \
                                          --is-public true \
                                          --container-format bare \
                                          --disk-format qcow2 \
                                          --file $target_file" | \
                                          grep '\sid\s' | awk '{print $4}')

  rm -f "$LSTACK_ROOTFS$target_file"
  echo $image_id
}

glance_md5() {
  local image_id=$1

  if [ -z "$1" ]; then
    error "glance_md5: invalid image id"
    return 1
  fi

  glance_command "image-show $image_id" | grep 'checksum' | awk '{print $4}'
}

cinder_command() {
  ostack_command cinder $@
}

cinder_create() {
  local size=$1
  local vol_id=""

  vol_id=$(cinder_command "create $size" | grep '\sid\s' | awk '{print $4}')

  echo $vol_id
}

destroy_instances() {
  # We need to do this in case images have volumes attached
  # otherwise we can't destroy the volume group.
  info "Destroying all the instances (if any)..."
  local instances=$(nova_command "list" | grep -v ID | awk '{print $2}' | xargs)

  # no instances, return
  [ -z "$instances" ] && return 0

  for instance in $instances; do
    nova_command "delete $instance"
  done

  # Wait till all of the instances have been destroyed
  for i in $(seq 1 10); do
    lines=$(nova_command "list" | wc -l) || true
    # when there are only 4 lines in the output the table is empty, so we can
    # safely leave the loop
    [ "$lines" = "4" ] && break

    sleep 5
  done
}

columnize() {
  echo $@ | awk -F, '{ printf "%-20s %-40s\n", $1, $2}'
}

forward_port() {
  src_port=$1
  dst_ip=$2
  dst_port=$3

  ! [[ "$src_port" =~ \d+ ]] || {
    error "Invalid source port $src_port"
    return 1
  }

  if ! [[ $dst_ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    error "Invalid destination ip $dst_ip"
    return 1
  fi

  ! [[ "$dst_port" =~ \d+ ]] || {
    error "Invalid destination port $dst_port"
    return 1
  }

  cat > $LSTACK_ROOTFS/etc/xinetd.d/lstack$src_port << EOF
service $src_port
{
  flags = IPv4
  type = UNLISTED
  socket_type = stream
  wait = no
  user = root
  port = $src_port
  redirect = $dst_ip $dst_port
}
EOF

  cexe "$LSTACK_NAME" "service xinetd restart" > /dev/null
}

ostack_command() {
  local oscmd=$1

  if ! [[ "$oscmd" =~ cinder|nova|glance|keystone ]]; then
    error "OpenStack command $oscmd not supported"
    return 1
  fi

  if [ -z "$oscmd" ]; then
    error "${oscmd}_command: no command specified"
    return 1
  fi

  shift

  if ! [ -f $LSTACK_ROOTFS/root/creds.sh ]; then
    error "${oscmd}_command: OpenStack credentials not found!"
    return 1
  fi

  source $LSTACK_ROOTFS/root/creds.sh
  cexe "$LSTACK_NAME" "$oscmd --os-username=$OS_USERNAME \
                              --os-password=$OS_PASSWORD \
                              --os-tenant-name $OS_TENANT_NAME \
                              --os-auth-url $OS_AUTH_URL \
                              $@"
}
