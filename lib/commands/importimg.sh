#!/bin/bash
set -e

# command boilerplate code
BASE_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../" && pwd )"
CMD_PATH="${BASH_SOURCE[0]}"
source $BASE_PATH/lstack.sh
source $BASE_PATH/install/creds.sh
image=$1
cname=lstack

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
ln -f "$image" "/var/lib/lxc/$cname/rootfs/tmp/$image_name"
info "Importing the image into Glance..."
glance_md5=$(cexe "$cname" "glance --os-username=$OS_USERNAME \
                      --os-password=$OS_PASSWORD \
                      --os-tenant-name $OS_TENANT_NAME \
                      --os-auth-url $OS_AUTH_URL \
                      image-create --name $image_name \
                      --is-public true \
                      --container-format bare \
                      --disk-format qcow2 \
                      --file /tmp/$image_name" | grep checksum | awk '{print $4}') || {
  error "Error importing the image"
  rm -f "/var/lib/lxc/$cname/rootfs/tmp/$image_name"
}

while true; do
  if read md5 < $fifo; then
    break;
  fi
  sleep 1
done

rm -f $fifo
if [ "$md5" = "$glance_md5" ]; then
  info "Image imported"
else
  error "The MD5 of the imported image does not match the source MD5"
fi

