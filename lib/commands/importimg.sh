#!/bin/bash
set -e

# command boilerplate code
BASE_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../" && pwd )"
CMD_PATH="${BASH_SOURCE[0]}"
source $BASE_PATH/lstack.sh
source $BASE_PATH/install/creds.sh
image=$1

needs_root

if ! [ -f "$image" ]; then
  error "Invalid image file '$image'."
  exit 1
fi

file "$image" | grep "QCOW Image" > /dev/null 2>&1 || {
  error "Invalid image. Only QCOW images supported for now."
  exit 1
}

fifo=$(mktemp -u)
mkfifo $fifo
{
  md5sum "$image" | awk '{print $1}' > $fifo
} &

image_name=$(basename "$image")

# hardlink the image to the container
info "Importing the image into Glance..."
__gid=$(glance_import "$image" "$image_name")
if [ -z "$__gid " ]; then
  error "Error importing the image"
  rm -f "/var/lib/lxc/$LSTACK_NAME/rootfs/tmp/$image_name"
fi

__gmd5=$(glance_md5 "$__gid")

while true; do
  if read md5 < $fifo; then
    break;
  fi
  sleep 1
done

rm -f $fifo
if [ "$md5" = "$__gmd5" ]; then
  info "Image imported"
else
  error "The MD5 of the imported image does not match the source MD5"
  exit 1
fi
