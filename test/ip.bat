#!/bin/bash

load test_helper

@test "ip returns an ip" {
  ip=$(lstack ip)
  [ -n "$ip" ]
}
