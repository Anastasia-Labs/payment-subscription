use aiken/transaction.{Datum, Redeemer, ScriptContext}
use payment_subscription/common/always_fails_validator/validation.{
  validate_always_fails,
}

validator {
  pub fn always_fails(_dat: Datum, _red: Redeemer, _ctx: ScriptContext) -> Bool {
    validate_always_fails(Void)
  }
}
