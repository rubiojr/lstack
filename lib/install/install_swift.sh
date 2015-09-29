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
BASE_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

info "Setting up swift"

apt-get install -y python-swiftclient memcached swift swift-account swift-container swift-object swift-proxy
mkdir -p $DIR/1
chown -R swift:swift $DIR

cd /etc/swift
cp $BASE_PATH/../configs/swift/* /etc/swift/

cat <<EOF | tee swift.conf
[swift-hash]
swift_hash_path_suffix = mystuff
EOF

# https://launchpad.net/bugs/1290813
/bin/echo -e '\n[container-sync]' >> container-server.conf

# add devices and ports to configuration and create rings
for i in "object 6000" "container 6001" "account 6002"; do
    what=${i% *}
    port=${i#* }
    sed -i "/\[DEFAULT\]/ a devices = $DIR\nmount_check = false" ${what}-server.conf

   swift-ring-builder ${what}.builder create 18 3 1
   swift-ring-builder ${what}.builder add z1-127.0.0.1:$port/1 1
   swift-ring-builder ${what}.builder rebalance
done

# exits with 1 even if everything succeeded
service swift-proxy start || true
service swift-container start || true
service swift-account start || true
service swift-object start || true
swift-init restart all || true

swift --os-auth-url http://127.0.0.1:5000/v2.0/ -U admin:admin -K Seguridad101 stat -v
