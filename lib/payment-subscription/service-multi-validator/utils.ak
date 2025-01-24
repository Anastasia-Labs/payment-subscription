use payment_subscription/common/types.{ServiceDatum}

// Helper function to validate service fee changes
pub fn is_service_metadata_valid(datum: ServiceDatum) -> Bool {
  and {
    (datum.service_fee_qty >= 0)?,
    (datum.penalty_fee_qty >= 0)?,
    (datum.interval_length >= 1)?,
    (datum.num_intervals >= 1)?,
    (datum.minimum_ada >= 0)?,
    datum.is_active?,
  }
}
