#!/bin/bash
set -e

info() {
  >&2 echo "$1"
}

BASE_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export DEBIAN_FRONTEND=noninteractive

source $BASE_PATH/metadata
HYPERVISOR=${HYPERVISOR:-qemu}

info "Enabling icehouse cloud-archive repo"
apt-get update
apt-get install -y python-software-properties

add-apt-repository -y cloud-archive:icehouse
apt-get update
apt-get dist-upgrade -y

info "Installing OpenStack Icehouse"
# nova-compute upstart config tries to modprobe nbd and that doesn't
# work inside LXC: http://askubuntu.com/a/402433
apt-get install -y nova-compute || {
  sed -i "s/modprobe.*//" /etc/init/nova-compute.conf
  apt-get install -y nova-compute
}

apt-get install -y python-mysqldb mysql-server rabbitmq-server \
                   linux-image-generic-lts-trusty linux-generic-lts-trusty \
                   linux-headers-generic-lts-trusty ntp vlan bridge-utils \
                   keystone glance glance-api glance-registry \
                   libvirt-bin pm-utils nova-api \
                   nova-cert novnc nova-consoleauth nova-scheduler \
                   nova-novncproxy nova-doc nova-conductor \
                   nova-compute-$HYPERVISOR \
                   openstack-dashboard memcached nova-network \
                   nova-api cpu-checker qemu ebtables python-guestfs \
                   cinder-api cinder-scheduler cinder-volume

update-guestfs-appliance

info "Populating the database"
$BASE_PATH/populatedb.sh
#
# KEYSTONE
#
info "Setting up keystone"
cp $BASE_PATH/configs/keystone/* /etc/keystone/
rm -f /var/lib/keystone/keystone.db
service keystone restart
keystone-manage db_sync

$BASE_PATH/keystone_basic.sh
$BASE_PATH/keystone_endpoints_basic.sh

source $BASE_PATH/creds.sh
# Some basic checking that keystone works
keystone user-list

#
# GLANCE
#

info "Setting up glance"
cp $BASE_PATH/configs/glance/* /etc/glance/
rm -f /var/lib/glance/glance.sqlite
service glance-api restart; service glance-registry restart
glance-manage db_sync
glance image-create --name cirros0.3 --is-public true --container-format bare --disk-format qcow2 --location https://launchpad.net/cirros/trunk/0.3.0/+download/cirros-0.3.0-x86_64-disk.img
glance image-list

info "Setting up Cinder"
cp $BASE_PATH/configs/cinder/* /etc/cinder/
rm /var/lib/cinder/cinder.sqlite
cinder-manage db sync
dd if=/dev/zero of=/cinder-volumes bs=1 count=0 seek=55G
losetup /dev/loop6 /cinder-volumes
pvcreate /dev/loop6
vgcreate cinder-volumes /dev/loop6
lvcreate --name disk1 --size 10G cinder-volumes
lvcreate --name disk2 --size 10G cinder-volumes
lvcreate --name disk3 --size 10G cinder-volumes
lvcreate --name disk4 --size 10G cinder-volumes
lvcreate --name disk5 --size 10G cinder-volumes
cd /etc/init.d/; for i in $( ls cinder-* ); do sudo service $i restart; cd /root/; done

#
# Nova
#
info "Setting up Nova"
mkdir /dev/net
mknod /dev/net/tun c 10 200

if [ "$HYPERVISOR" = "kvm" ]; then
  # KVM support
  mknod /dev/kvm c 10 232
  chmod g+rw /dev/kvm
  chgrp kvm /dev/kvm
fi

cp $BASE_PATH/configs/libvirt/* /etc/libvirt/
virsh net-destroy default
virsh net-undefine default
cp $BASE_PATH/configs/default/* /etc/default/
cp $BASE_PATH/configs/nova/* /etc/nova/
service dbus restart && service libvirt-bin restart
for f in /etc/init.d/nova-*; do $f restart; done
rm -f /var/lib/nova/nova.sqlite
nova-manage db sync
for f in /etc/init.d/nova-*; do $f restart; done
nova-manage --config-file /etc/nova/nova.conf network create private 10.0.254.0/24 1 256

info "Creating a cirros 0.3 instance. user: cirros, password: cubswin:)"
nova secgroup-add-rule default tcp 1 65535 0.0.0.0/0
nova boot --image cirros0.3 --flavor m1.tiny test
