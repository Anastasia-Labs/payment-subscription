use aiken/transaction.{OutputReference}
use aiken/transaction/value.{AssetName, PolicyId}

/// There's got to be some functional way to do efficient checks on this.
/// Consider experimenting after testnet.
pub type AssetClass {
  policy_id: PolicyId,
  asset_name: AssetName,
}

// pub type ServiceDatum {
//   service_fee: AssetClass,
//   service_fee_qty: Int,
//   // non-negative
//   penalty_fee: AssetClass,
//   penalty_fee_qty: Int,
//   //TODO: Add interval_length

//   // Subscription period Min 1
//   // Should  be num_intervals
//   subscription_period: Int,
//   is_active: Bool,
// }

pub type ServiceDatum {
  service_fee: AssetClass,
  service_fee_qty: Int,
  // non-negative
  penalty_fee: AssetClass,
  penalty_fee_qty: Int,
  interval_length: Int,
  num_intervals: Int,
  is_active: Bool,
}

// Service Mint Purpose Redeemer
pub type CreateService {
  output_reference: OutputReference,
  input_index: Int,
}

// Service Spend Purpose Redeemer
pub type SpendService {
  UpdateService
  RemoveService
}

// Account Mint Purpose Redeemer
pub type MintAccount {
  CreateAccount { output_reference: OutputReference, input_index: Int }
  DeleteAccount
}

pub type SpendAccount {
  UpdateAccount
  RemoveAccount
}

pub type AccountDatum {
  email: ByteArray,
  phone: ByteArray,
  account_created: Int,
}

// Payment Mint Purpose Redeemer
pub type MintPayment {
  InitSubscripton { output_reference: OutputReference, input_index: Int }
  TerminateSubscription
}

// Payment Spend Purpose Redeemer
pub type SpendPayment {
  Extend
  Unsubscribe
  MerchantWithdraw
  SubscriberWithdraw
}

// Datum type 
pub type PaymentDatum {
  service_nft_tn: AssetName,
  account_nft_tn: AssetName,
  subscription_fee: AssetClass,
  total_subscription_fee: Int,
  subscription_start: Int,
  subscription_end: Int,
  //TODO: Allow to be customisable
  interval_length: Int,
  interval_amount: Int,
  num_intervals: Int,
  last_claimed: Int,
  penalty_fee: AssetClass,
  penalty_fee_qty: Int,
}

// penalty_datum
pub type PenaltyDatum {
  service_nft_tn: AssetName,
  account_nft_tn: AssetName,
  penalty_fee: AssetClass,
  penalty_fee_qty: Int,
}

pub type PaymentValidatorDatum {
  Payment(PaymentDatum)
  Penalty(PenaltyDatum)
}
