use aiken/transaction.{OutputReference}
use aiken/transaction/value.{AssetName, PolicyId}

/// There's got to be some functional way to do efficient checks on this.
/// Consider experimenting after testnet.
pub type AssetClass {
  policy_id: PolicyId,
  asset_name: AssetName,
}

pub type ServiceDatum {
  service_fee: AssetClass,
  service_fee_qty: Int,
  // non-negative
  penalty_fee: AssetClass,
  penalty_fee_qty: Int,
  interval_length: Int,
  num_intervals: Int,
  minimum_ada: Int,
  is_active: Bool,
}

// Service Mint Purpose Redeemer
pub type CreateService {
  output_reference: OutputReference,
  input_index: Int,
}

// Service Spend Purpose Redeemer
pub type SpendService {
  UpdateService { merchant_input_index: Int, service_input_index: Int }
  RemoveService { merchant_input_index: Int, service_input_index: Int }
}

// Account Mint Purpose Redeemer
pub type MintAccount {
  CreateAccount { output_reference: OutputReference, input_index: Int }
  DeleteAccount
}

pub type SpendAccount {
  UpdateAccount { subscriber_input_index: Int, account_input_index: Int }
  RemoveAccount { subscriber_input_index: Int, account_input_index: Int }
}

pub type AccountDatum {
  email: ByteArray,
  phone: ByteArray,
  account_created: Int,
}

// Payment Mint Purpose Redeemer
pub type MintPayment {
  InitSubscripton { output_reference: OutputReference, input_index: Int }
  TerminateSubscription { merchant_input_index: Int, payment_input_index: Int }
}

// Payment Spend Purpose Redeemer
pub type SpendPayment {
  Extend { subscriber_input_index: Int, payment_input_index: Int }
  MerchantWithdraw { merchant_input_index: Int, payment_input_index: Int }
  Unsubscribe { subscriber_input_index: Int, payment_input_index: Int }
  SubscriberWithdraw { subscriber_input_index: Int, payment_input_index: Int }
}

// Datum type 
pub type PaymentDatum {
  service_nft_tn: AssetName,
  subscriber_nft_tn: AssetName,
  subscription_fee: AssetClass,
  total_subscription_fee: Int,
  subscription_start: Int,
  subscription_end: Int,
  interval_length: Int,
  interval_amount: Int,
  num_intervals: Int,
  last_claimed: Int,
  penalty_fee: AssetClass,
  penalty_fee_qty: Int,
  minimum_ada: Int,
}

// penalty_datum
pub type PenaltyDatum {
  service_nft_tn: AssetName,
  subscriber_nft_tn: AssetName,
  penalty_fee: AssetClass,
  penalty_fee_qty: Int,
}

pub type PaymentValidatorDatum {
  Payment(PaymentDatum)
  Penalty(PenaltyDatum)
}
