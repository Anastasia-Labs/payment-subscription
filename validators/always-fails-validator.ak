use aiken/transaction.{Datum, Redeemer, ScriptContext}

validator {
  pub fn always_fails(_dat: Datum, _red: Redeemer, _ctx: ScriptContext) -> Bool {
    False
  }
}
