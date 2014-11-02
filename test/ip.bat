#!/bin/bash

load test_helper

@test "ip returns an ip" {
  ip=$(lstack ip)
  [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]
}
