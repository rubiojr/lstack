#!/bin/bash
set -e

# command boilerplate code
BASE_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../" && pwd )"
CMD_PATH="${BASH_SOURCE[0]}"
source $BASE_PATH/lstack.sh
source $BASE_PATH/install/creds.sh

main() {
  local image=$1

  running? || exit $?

  if [ ! -f "$image" ]; then
    error "Invalid image file '$image'."
    usage
    exit 1
  fi

  file "$image" | grep "QCOW Image" > /dev/null 2>&1 || {
    error "Invalid image. Only QCOW images supported for now."
    usage
    exit 1
  }

  if [ ! -r "$image" ]; then
    error "The image '$image' is not readable."
    exit 1
  fi

  needs_root

  fifo=$(mktemp -u)
  mkfifo $fifo
  {
    md5sum "$image" | awk '{print $1}' > $fifo
  } &

  # hardlink the image to the container
  info "Importing the image into Glance..."
  __gid=$(glance_import "$image" "$importimg_name")
  if [ -z "$__gid " ]; then
    error "Error importing the image"
    exit 1
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
}

usage() {
  echo
  echo "Usage: lstack importimg [options] <image-file>"
  echo
  echo FLAGS
  echo
  columnize "--name",      "Instance name   (default: lstack-%timestamp)"
  echo
}

importimg_name="lstack-$(date +%s)"
importimg_option_name()   ( importimg_name="$1"; shift; d "$@" )
importimg_option_help()   ( usage; )
importimg_command_help()  ( usage; )
importimg_ () ( main )

d() {
  # Assume there are no flags if there's only one argument
  if [ $# = 1 ]; then
    main $@
  else
    dispatch importimg "$@"
  fi
}

dispatch importimg "$@"
