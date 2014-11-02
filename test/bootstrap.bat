#!/bin/bash

load test_helper

@test "bootstrap" {
  lstack bootstrap
}

@test "bootstrapping when already running fails" {
  lstack bootstrap 2>&1 | grep "Container already running"
}

@test "bootstrap --force" {
  lstack bootstrap --force
}
