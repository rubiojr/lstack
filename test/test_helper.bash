#!/bin/bash

lstack(){
  sudo ./lstack --nocolor --nonyancat $@
}

container_name(){
  echo lstack-$SUDO_USER
}

