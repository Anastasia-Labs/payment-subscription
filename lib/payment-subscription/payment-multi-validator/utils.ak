use aiken/math
use payment_subscription/common/types.{PaymentDatum, ServiceDatum}

// Helper function to validate internal payment datum
pub fn validate_initial_payment_datum_internal(datum: PaymentDatum) -> Bool {
  let time_valid =
    0 <= datum.subscription_start && datum.subscription_start < datum.subscription_end && 0 <= datum.last_claimed && datum.last_claimed <= datum.subscription_start

  let amounts_valid = datum.total_subscription_fee_qty > 0

  let subscription_period_valid =
    datum.subscription_end - datum.subscription_start == datum.interval_length * datum.num_intervals

  let total_fee_valid =
    datum.total_subscription_fee_qty == datum.interval_amount * datum.num_intervals

  and {
    time_valid?,
    amounts_valid?,
    subscription_period_valid?,
    total_fee_valid?,
  }
}

// Helper function to validate payment datum against Service contract
pub fn validate_initial_payment_against_service(
  payment: PaymentDatum,
  service: ServiceDatum,
) -> Bool {
  let datum_correct =
    service == ServiceDatum {
      service_fee: payment.subscription_fee,
      service_fee_qty: payment.interval_amount,
      penalty_fee: payment.penalty_fee,
      penalty_fee_qty: payment.penalty_fee_qty,
      interval_length: payment.interval_length,
      num_intervals: payment.num_intervals,
      minimum_ada: payment.minimum_ada,
      is_active: True,
    }
  and {
    datum_correct?,
    (payment.total_subscription_fee_qty == payment.interval_amount * payment.num_intervals)?,
  }
}

pub fn validate_extension_datum(
  old_datum: PaymentDatum,
  new_datum: PaymentDatum,
  extension_amount: Int,
  service_datum: ServiceDatum,
  extension_period: Int,
  expected_fee_increase: Int,
) -> Bool {
  // Extension period calculation
  let extension_intervals = extension_period / old_datum.interval_length

  // Fee increase validation
  let fee_increase_valid = extension_amount >= expected_fee_increase

  let valid_end_date =
    new_datum.subscription_end > new_datum.subscription_start && new_datum.subscription_end > old_datum.subscription_end

  let new_datum_valid =
    new_datum == PaymentDatum {
      service_nft_tn: old_datum.service_nft_tn,
      subscriber_nft_tn: old_datum.subscriber_nft_tn,
      subscription_fee: service_datum.service_fee,
      total_subscription_fee_qty: old_datum.total_subscription_fee_qty + expected_fee_increase,
      subscription_start: old_datum.subscription_start,
      subscription_end: new_datum.subscription_end,
      interval_length: service_datum.interval_length,
      interval_amount: old_datum.interval_amount,
      num_intervals: old_datum.num_intervals + extension_intervals,
      last_claimed: old_datum.last_claimed,
      penalty_fee: service_datum.penalty_fee,
      penalty_fee_qty: service_datum.penalty_fee_qty,
      minimum_ada: service_datum.minimum_ada,
    }

  and {
    fee_increase_valid?,
    valid_end_date?,
    new_datum_valid?,
  }
}

pub fn calculate_withdrawable_amount(
  payment_datum: PaymentDatum,
  current_time: Int,
) -> Int {
  let time_since_last_claim =
    math.max(current_time - payment_datum.last_claimed, 0)
  let intervals_passed = time_since_last_claim / payment_datum.interval_length
  let claimable_intervals =
    math.min(intervals_passed, payment_datum.num_intervals)
  let withdrawable = claimable_intervals * payment_datum.interval_amount
  withdrawable
}
