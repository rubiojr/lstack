#!/bin/bash

lstack(){
  sudo ./lstack --nocolor --quiet $@
}

@test "bootstrap" {
  lstack bootstrap
}

@test "bootstrap fails" {
  lstack bootstrap 2>&1 | grep "Container already running"
}

@test "bootstrap --force" {
  lstack bootstrap --force
}
