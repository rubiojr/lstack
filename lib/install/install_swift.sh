#!/bin/bash
# Set up a totally insecure swift instance. This is meant to be run in a
# freshly created Ubuntu container or VM, for locally testing software that
# talks to swift.
# Author: Martin Pitt <martin.pitt@ubuntu.com>
# 
# From https://www.piware.de/2014/03/creating-a-local-swift-server-on-ubuntu-for-testing/
# Some tweaks from Sergio Rubio <rubiojr@frameos.org>
set -e

DIR=/srv/swift

[ `id -u` = 0 ] || {
    echo "You need to run this script as root" >&2
    exit 1
}

apt-get install -y python-swiftclient memcached swift swift-account swift-container swift-object swift-proxy
mkdir -p $DIR/1
chown -R swift:swift $DIR

cd /etc/swift
cat <<EOF | tee proxy-server.conf
[DEFAULT]
bind_port = 8080
log_facility = LOG_LOCAL1

[pipeline:main]
pipeline = healthcheck cache tempauth proxy-server

[app:proxy-server]
use = egg:swift#proxy
allow_account_management = true
account_autocreate = true

[filter:tempauth]
use = egg:swift#tempauth
user_admin_admin = admin .admin .reseller_admin
user_testproj_testuser = testpwd .admin

[filter:healthcheck]
use = egg:swift#healthcheck

[filter:cache]
use = egg:swift#memcache
EOF

cat <<EOF | tee swift.conf
[swift-hash]
swift_hash_path_suffix = mystuff
EOF

# https://launchpad.net/bugs/1290813
/bin/echo -e '\n[container-sync]' >> container-server.conf

# add devices and ports to configuration and create rings
for i in "object 6010" "account 6020" "container 6030"; do
    what=${i% *}
    port=${i#* }
    sed -i "/\[DEFAULT\]/ a devices = $DIR\nmount_check = false\nbind_port = $port" ${what}-server.conf

   swift-ring-builder ${what}.builder create 18 3 1
   swift-ring-builder ${what}.builder add z1-127.0.0.1:$port/1 1
   swift-ring-builder ${what}.builder rebalance
done

# exits with 1 even if everything succeeded
swift-init restart all || true

# create user account
cat <<EOF
Now check that it works with

    swift -A http://127.0.0.1:8080/auth/v1.0 -U testproj:testuser -K testpwd stat -v
EOF
