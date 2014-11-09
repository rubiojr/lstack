#!/bin/bash

export LSTACK_OSRELEASE=${LSTACK_OSRELEASE:-juno}

lstack(){
  sudo ./lstack --nocolor --nonyancat $@
}

container_name(){
  echo lstack-$SUDO_USER
}
