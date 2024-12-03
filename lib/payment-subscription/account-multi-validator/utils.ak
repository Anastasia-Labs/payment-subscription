use aiken/primitive/bytearray
use payment_subscription/common/types.{AccountDatum}

// Helper function to validate tha account metadata
pub fn is_account_metadata_valid(datum: AccountDatum) -> Bool {
  let email_valid = bytearray.length(datum.email) > 0
  let phone_valid = bytearray.length(datum.phone) > 0

  email_valid || phone_valid
}
