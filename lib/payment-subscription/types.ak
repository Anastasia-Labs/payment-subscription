use aiken/transaction.{OutputReference}
// use aiken/transaction.{OutputReference}
use aiken/transaction/value.{AssetName, PolicyId}

/// Consider: wrapping this further for safety.
pub type POSIXTime =
  Int

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
  // Subscription period Min 1
  subscription_period: Int,
}

// Service Mint Purpose Redeemer
pub type MintService {
  CreateService { output_reference: OutputReference, input_index: Int }
  DeleteService
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
  account_created: POSIXTime,
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
  Withdraw
}

// Datum type 
pub type PaymentDatum {
  //Hash Policy ID
  service_nft_tn: AssetName,
  account_nft_tn: AssetName,
  subscription_fee: AssetClass,
  subscription_fee_qty: Int,
  subscription_start: POSIXTime,
  subscription_end: POSIXTime,
  subscription_period: Int,
  // last Claimed in datum so that merchant can't claim until 
  // one month has passed.(Add counter)
  last_claimed: POSIXTime,
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
