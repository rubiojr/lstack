#!/bin/bash
set -e

BASE_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export DEBIAN_FRONTEND=noninteractive

source /var/lib/lstack/metadata
source $BASE_PATH/../lstack.sh

HYPERVISOR=${HYPERVISOR:-qemu}

apt-get update
apt-get install -y software-properties-common openssh-server curl
if [ "$LSTACK_OSRELEASE" = "juno" ]; then
  sudo add-apt-repository -y cloud-archive:juno
  apt-get update
fi
apt-get dist-upgrade -y

# FIXME
# open-iscsi service fails to start if iscsi_trgt kernel module isn't
# loaded in the host. We don't need the iSCSI functionality but we have
# to workaround it because it's a dependency of the OpenStack packages.
debug "Workaround open-iscsi modprobe issue"
apt-get install -y open-iscsi || {
  # this will prevent the service from being started
  chmod -x /etc/init.d/open-iscsi
  apt-get install -y open-iscsi
}

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
                   cpu-checker qemu ebtables python-guestfs libguestfs-tools \
                   cinder-api cinder-scheduler cinder-volume xinetd \
                   swift

update-guestfs-appliance

cp $BASE_PATH/../files/usr/local/sbin/* /usr/local/sbin/

# Tweak MySQL max_connections
sed -i s/#max_connections.*/max_connections\ =\ 200/ /etc/mysql/my.cnf
service mysql restart

info "Populating the database"
$BASE_PATH/populatedb.sh
#
# KEYSTONE
#
info "Setting up keystone"
cp $BASE_PATH/../configs/keystone/* /etc/keystone/
rm -f /var/lib/keystone/keystone.db
service keystone stop
chown keystone:keystone -R /var/log/keystone
service keystone start
keystone-manage db_sync

$BASE_PATH/keystone_basic.sh
$BASE_PATH/keystone_endpoints_basic.sh

source $BASE_PATH/creds.sh
cp $BASE_PATH/creds.sh /root
# Some basic checking that keystone works
keystone user-list

#
# GLANCE
#

info "Setting up glance"
cp $BASE_PATH/../configs/glance/* /etc/glance/
rm -f /var/lib/glance/glance.sqlite
service glance-api restart; service glance-registry restart
glance-manage db_sync
curl -L --retry 3 https://launchpad.net/cirros/trunk/0.3.0/+download/cirros-0.3.0-x86_64-disk.img -o /tmp/cirros-0.3.0.img
md5=$(md5sum /tmp/cirros-0.3.0.img | awk '{print $1}')
if [ "$md5" != "50bdc35edb03a38d91b1b071afb20a3c" ]; then
  error "Error downloading Cirros 0.3.0 from Launchpad. Aborting."
  exit 1
fi
glance image-create --name cirros0.3 --is-public true --container-format bare --disk-format qcow2 --file /tmp/cirros-0.3.0.img || {
  error "Could not create the image in glance"
  exit 1
}
glance image-list

info "Setting up Cinder"
# VGNAME comes from the metadata file
dd if=/dev/zero of=/$VGNAME bs=1 count=0 seek=55G
loopdev=$(losetup -f)
# retry if fails to avoid race conditions
losetup $loopdev /$VGNAME || {
  loopdev=$(losetup -f)
  losetup $loopdev /$VGNAME || {
    error "Failed to setup the loop device"
    exit 1
  }
}
# Save the loop dev for later cleanup
echo "LOOPDEV=$loopdev" >> /var/lib/lstack/metadata

pvcreate $loopdev || {
  error "Could not pvcreate loop device '$loopdev'"
  exit 1
}

vgcreate $VGNAME $loopdev || {
  error "Could not create volume group '$VGNAME' using loop device '$loopdev'"
  exit 1
}

# create the dm devices, required when using a Trusty container but
# not with Precise for some reason
for i in 0 1 2 3 4 5 6 7 8 9 10; do
  mknod /dev/dm-$i b 252 $i
done
chgrp disk /dev/dm-*

lvcreate --name disk1 --size 10G $VGNAME
lvcreate --name disk2 --size 10G $VGNAME
lvcreate --name disk3 --size 10G $VGNAME
lvcreate --name disk4 --size 10G $VGNAME
lvcreate --name disk5 --size 10G $VGNAME

cp $BASE_PATH/../configs/cinder/* /etc/cinder/
sed -i "s/cinder-volumes/$VGNAME/g" /etc/cinder/cinder.conf
rm /var/lib/cinder/cinder.sqlite
cinder-manage db sync
cd /etc/init/; for i in $( ls cinder-* ); do
  service `basename $i .conf` restart
done

#
# Nova
#
info "Setting up Nova"
mkdir /dev/net
mknod /dev/net/tun c 10 200

if [ "$HYPERVISOR" = "kvm" ] && [ ! -c /dev/kvm ]; then
  # KVM support
  mknod /dev/kvm c 10 232
  chmod g+rw /dev/kvm
  chgrp kvm /dev/kvm
fi

cp $BASE_PATH/../configs/libvirt/* /etc/libvirt/
virsh net-destroy default
virsh net-undefine default
cp $BASE_PATH/../configs/default/* /etc/default/
cp $BASE_PATH/../configs/nova/* /etc/nova/
service dbus restart && service libvirt-bin restart
rm -f /var/lib/nova/nova.sqlite
cd /etc/init/; for i in $( ls nova-* ); do
  service `basename $i .conf` restart
done
nova-manage db sync
cd /etc/init/; for i in $( ls nova-* ); do
  service `basename $i .conf` restart
done
nova-manage --config-file /etc/nova/nova.conf network create private 10.0.254.0/24 1 256

info "Creating a cirros 0.3 instance. user: cirros, password: cubswin:)"
nova secgroup-add-rule default tcp 1 65535 0.0.0.0/0
nova flavor-create --is-public true m1.pico auto 64 0 1
nova flavor-create --is-public true m1.nano auto 128 0 1
nova flavor-create --is-public true m1.micro auto 256 0 1
nova boot --image cirros0.3 --flavor m1.pico test

## Install openstack swift
$BASE_PATH/install_swift.sh
