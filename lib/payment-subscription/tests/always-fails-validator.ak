use payment_subscription/common/always_fails_validator/validation.{
  validate_always_fails,
}

test always_fails() fail {
  validate_always_fails(Void)
}
