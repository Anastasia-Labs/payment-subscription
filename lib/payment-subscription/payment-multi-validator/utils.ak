use aiken/math
use payment_subscription/common/types.{AssetClass, PaymentDatum, ServiceDatum}

// Helper function to validate internal payment datum
pub fn validate_payment_datum_internal(datum: PaymentDatum) -> Bool {
  let time_valid =
    datum.subscription_start < datum.subscription_end && datum.last_claimed <= datum.subscription_start

  let amounts_valid =
    datum.total_subscription_fee > 0 && datum.interval_amount > 0 && datum.penalty_fee_qty >= 0

  let intervals_valid = datum.interval_length > 0 && datum.num_intervals > 0

  let subscription_period_valid =
    datum.subscription_end - datum.subscription_start == datum.interval_length * datum.num_intervals

  let total_fee_valid =
    datum.total_subscription_fee == datum.interval_amount * datum.num_intervals

  let sane_values =
    datum.subscription_start >= 0 && datum.interval_length > 0 && datum.interval_amount > 0 && datum.num_intervals > 0 && datum.minimum_ada >= 0
  time_valid? && amounts_valid? && intervals_valid? && subscription_period_valid? && total_fee_valid? && sane_values?
}

fn is_ada(asset: AssetClass) -> Bool {
  asset.policy_id == "" && asset.asset_name == ""
}

// Helper function to validate payment datum against Service contract
pub fn validate_payment_against_service(
  payment: PaymentDatum,
  service: ServiceDatum,
) -> Bool {
  let interval_length_valid = payment.interval_length == service.interval_length
  let service_fee_valid =
    payment.subscription_fee == service.service_fee && payment.interval_amount == service.service_fee_qty
  let penalty_fee_valid =
    payment.penalty_fee == service.penalty_fee && payment.penalty_fee_qty == service.penalty_fee_qty
  let minimum_ada_valid =
    is_ada(payment.subscription_fee) && payment.minimum_ada >= 0

  interval_length_valid? && service_fee_valid? && penalty_fee_valid? && minimum_ada_valid?
}

pub fn validate_extension_datum(
  old_datum: PaymentDatum,
  new_datum: PaymentDatum,
  extension_amount: Int,
  service_datum: ServiceDatum,
) -> Bool {
  let unchanged_fields_valid =
    old_datum.service_nft_tn == new_datum.service_nft_tn && old_datum.account_nft_tn == new_datum.account_nft_tn && old_datum.subscription_start == new_datum.subscription_start && old_datum.interval_amount == new_datum.interval_amount && old_datum.interval_length == new_datum.interval_length

  // Extension period calculation
  let extension_period = new_datum.subscription_end - old_datum.subscription_end
  let extension_intervals = extension_period / old_datum.interval_length
  // Validate extension period
  let period_extension_valid = extension_intervals > 0

  // Fee increase validation
  let expected_fee_increase = extension_intervals * new_datum.interval_amount
  let fee_increase_valid = extension_amount >= expected_fee_increase

  let valid_end_date = new_datum.subscription_end > new_datum.subscription_start

  let updated_fields_valid =
    new_datum.num_intervals == old_datum.num_intervals + extension_intervals && new_datum.total_subscription_fee == old_datum.total_subscription_fee + expected_fee_increase

  // Validate that the extension follows the Service provider rules
  let follows_service_rules =
    new_datum.subscription_fee == service_datum.service_fee && new_datum.interval_length == service_datum.interval_length && new_datum.minimum_ada >= service_datum.minimum_ada

  let sane_values =
    new_datum.subscription_start >= 0 && new_datum.subscription_end > new_datum.subscription_start && new_datum.interval_length > 0 && new_datum.interval_amount > 0 && new_datum.num_intervals > 0 && new_datum.minimum_ada >= 0

  and {
    unchanged_fields_valid?,
    period_extension_valid?,
    fee_increase_valid?,
    valid_end_date?,
    follows_service_rules?,
    updated_fields_valid?,
    sane_values?,
  }
}

pub fn calculate_locked_amount(
  num_intervals: Int,
  current_time: Int,
  subscription_start: Int,
  interval_length: Int,
  interval_amount: Int,
) -> Int {
  let elapsed = math.max(current_time - subscription_start, 0)
  let intervals_passed = elapsed / interval_length
  let remaining_intervals = math.max(num_intervals - intervals_passed, 0)
  remaining_intervals * interval_amount
}
