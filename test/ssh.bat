load test_helper

@test "ssh works" {
  lstack ssh ls /etc/nova/nova.conf
}
