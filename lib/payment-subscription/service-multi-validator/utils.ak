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
  let minimum_ada_valid = datum.minimum_ada > 0

  service_fee_valid && penalty_fee_valid && subscription_period_valid && datum.is_active && minimum_ada_valid
}

// Helper function to validate service fee changes
pub fn is_fee_change_valid(old_fee: Int, new_fee: Int) -> Bool {
  // Implement logic to ensure fee changes are within acceptable range
  // For example, limit changes to ±10%
  let max_change = old_fee / 10
  abs(new_fee - old_fee) <= max_change
}
