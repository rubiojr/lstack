#!/bin/bash
set -e

# command boilerplate code
BASE_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../" && pwd )"
CMD_PATH="${BASH_SOURCE[0]}"
source $BASE_PATH/lstack.sh
source $BASE_PATH/install/creds.sh
image=$1
cname=lstack

if ! [ -f "$image" ]; then
  echo "Invalid image file '$image'."
  exit 1
fi

file "$image" | grep "QCOW Image" || {
  echo "Invalid image. Only QCOW images supported for now."
  exit 1
}

if [ `whoami` != "root" ]; then
  debug "Need to run as root, trying sudo"
  exec sudo bash $CMD_PATH $@
fi

image_name=$(basename "$image")

# hardlink the image to the container
ln "$image" "/var/lib/lxc/$cname/rootfs/tmp/$image_name"
info "Importing the image into Glance..."
cexe "$cname" "glance --os-username=$OS_USERNAME \
                      --os-password=$OS_PASSWORD \
                      --os-tenant-name $OS_TENANT_NAME \
                      --os-auth-url $OS_AUTH_URL \
                      image-create --name $image_name \
                      --is-public true \
                      --container-format bare \
                      --disk-format qcow2 \
                      --file /tmp/$image_name" || {
  error "Error importing the image"
  rm -f "/var/lib/lxc/$cname/rootfs/tmp/$image_name"
}

