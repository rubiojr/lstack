load test_helper

@test "destroy the container" {
  lstack destroy
  sudo bash -c "lxc-ls -1 | grep '$(container_name)'" && return 1

  return 0
}
