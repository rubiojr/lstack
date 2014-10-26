#!/bin/bash
set -e

# command boilerplate code
BASE_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../" && pwd )"
CMD_PATH="${BASH_SOURCE[0]}"
source $BASE_PATH/lstack.sh
image=$1
cname=lstack

source $BASE_PATH/commands/bootstrap.sh

if ! [ -f "$image" ]; then
  echo "Invalid image file $image."
  exit 1
fi

file "$image" | grep "QCOW Image" || {
  echo "Invalid image. Only QCOW images supported for now."
  exit 1
}

image_name=$(basename "$image")
mount -o bind $(dirname "$image") /var/lib/lxc/$cname/rootfs/mnt/
cexe "$cname" "glance image-create --name $image_name --is-public true --container-format bare --disk-format qcow2 --file /mnt/$image_name"

