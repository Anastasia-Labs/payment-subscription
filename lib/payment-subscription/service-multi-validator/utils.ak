use aiken/cbor
use aiken/math.{abs}
use payment_subscription/common/types.{ServiceDatum}

// Helper function to validate service fee changes
pub fn is_service_metadata_valid(datum: ServiceDatum) -> Bool {
  let service_fee_valid =
    datum.service_fee_qty >= 1 && datum.service_fee_qty < 1_000_000_000_000
  let penalty_fee_valid =
    datum.penalty_fee_qty >= 0 && datum.penalty_fee_qty < 1_000_000_000_000
  let subscription_period_valid =
    datum.num_intervals >= 1 && datum.num_intervals < 1_000_000_000_000
  service_fee_valid && penalty_fee_valid && subscription_period_valid && datum.is_active
}

// Helper function to validate service fee changes
pub fn is_fee_change_valid(old_fee: Int, new_fee: Int) -> Bool {
  // Implement logic to ensure fee changes are within acceptable range
  // For example, limit changes to ±10%
  let max_change = old_fee / 10

  trace @"old_fee"
  trace cbor.diagnostic(old_fee)
  trace @"new_fee"
  trace cbor.diagnostic(new_fee)
  trace @"max_change"
  trace cbor.diagnostic(max_change)

  abs(new_fee - old_fee) <= max_change
}
