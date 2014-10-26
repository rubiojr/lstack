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

file "$image" | grep "QCOW Image" > /dev/null 2>&1 || {
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
img_id=$(cexe "$cname" "glance --os-username=$OS_USERNAME \
                      --os-password=$OS_PASSWORD \
                      --os-tenant-name $OS_TENANT_NAME \
                      --os-auth-url $OS_AUTH_URL \
                      image-create --name $image_name \
                      --is-public true \
                      --container-format bare \
                      --disk-format qcow2 \
                      --file /tmp/$image_name | grep '\sid\s' | awk '{print \$4}'") || {
  error "Error importing the image"
  rm -f "/var/lib/lxc/$cname/rootfs/tmp/$image_name"
}

md5=$(md5sum "$image" | awk '{print $1}')
glance_md5=$(cexe "$cname" "glance image-show $image_name | grep checksum | awk '{print \$4}'")
if [ "$md5" = "$glance_md5" ]; then
  info "Image imported"
else
  error "The MD5 of the imported image does not match the source MD5"
fi

