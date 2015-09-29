load test_helper

@test "swift-proxy is listening" {
  ip=$(lstack ip)
  curl -s http://$ip:8080 | grep -q "Authentication required"
}

@test "swift list" {
  lstack ssh 'source /root/creds.sh && swift list'
}

@test "swift post" {
  lstack ssh 'source /root/creds.sh && swift post foo'
}
