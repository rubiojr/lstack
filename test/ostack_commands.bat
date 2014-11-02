load test_helper

@test "nova command works" {
  lstack nova list
}

@test "glance command works" {
  lstack glance index
}

@test "keystone command works" {
  lstack keystone user-list
}

@test "cinder command works" {
  lstack cinder list
}
