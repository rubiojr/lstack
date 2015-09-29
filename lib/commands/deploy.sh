#!/bin/bash
set -e

# command boilerplate code
BASE_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../" && pwd )"
CMD_PATH="${BASH_SOURCE[0]}"
source $BASE_PATH/lstack.sh
source $BASE_PATH/install/creds.sh

main(){

  if ! [ -f "$deploy_file" ]; then
    usage
    exit 1
  fi

  file "$deploy_file" | grep "QCOW Image" > /dev/null 2>&1 || {
    error "Invalid image. Only QCOW images supported for now."
    exit 1
  }

  image_name=$(basename $deploy_file)

  info "Importing the image (may take some time)..."
  local gid=$(glance_import "$deploy_file" "$image_name")

  info "Deploying $deploy_name..."
  info "Instance name:   $deploy_name"
  info "Instance flavor: $deploy_flavor"

  if [ -z "$deploy_volume" ]; then
    source $BASE_PATH/commands/nova.sh boot \
                                        --image "$gid" \
                                        --flavor $deploy_flavor \
                                        "$deploy_name" > /dev/null
  else
    __volid=$(cinder_create "$deploy_volume")
    if [ -z "$__volid" ]; then
      error "Could not create the Cinder volume!"
      exit 1
    fi
    source $BASE_PATH/commands/nova.sh boot \
                                        --image "$gid" \
                                        --block-device source=volume,id=$__volid,dest=volume,shutdown=preserve \
                                        --flavor $deploy_flavor \
                                        "$deploy_name" > /dev/null
  fi
}

columnize() {
  echo $@ | awk -F, '{ printf "%-20s %-40s\n", $1, $2}'
}

usage() {
  echo "Usage: lstack deploy [options] <image-file>"
  echo
  echo FLAGS
  echo
  columnize "--name",      "Instance name   (default: lstack-%timestamp)"
  columnize "--flavor",    "Instance flavor ('lstack nova flavor-list' to list)"
  columnize "--file",      "QCOW2 image to deploy (required)"
  echo
}

needs_root

deploy_name=lstack-$(date +%s)
deploy_flavor="m1.tiny"
deploy_file=
deploy_volume=

deploy_option_name()   ( deploy_name="$1"; shift; dispatch deploy "$@" )
deploy_option_flavor() ( deploy_flavor="$1"; shift; dispatch deploy "$@" )
deploy_option_file()   ( deploy_file="$1"; shift; dispatch deploy "$@" )
deploy_option_volume() ( deploy_volume="$1"; shift; dispatch deploy "$@" )
deploy_option_help()   ( usage; )
deploy_command_help()  ( usage; )
deploy_ () ( main )

dispatch deploy "$@"
