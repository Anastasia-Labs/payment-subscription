use cardano/transaction.{Datum, OutputReference, Redeemer, Transaction}
use payment_subscription/common/always_fails_validator/validation.{
  validate_always_fails,
}

validator always_fails {
  spend(
    _dat: Option<Datum>,
    _red: Redeemer,
    _own_ref: OutputReference,
    _self: Transaction,
  ) {
    validate_always_fails(Void)
  }

  else(_) {
    fail
  }
}
