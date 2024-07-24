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

// /// Redeemer type for minting validator
pub type MintAction {
  Mint
  Burn
}

// pub type StoreAction {
//   Update
//   Remove
// }

pub type ServiceDatum {
  service_fee: AssetClass,
  service_fee_qty: Int,
  penalty_fee: Int,
  penalty_fee_qty: Int,
  total_installments: Int,
  min_sub_period: Int,
}

// Service Mint Purpose Redeemer
pub type MintService {
  CreateService
  DeleteService
}

// Service Spend Purpose Redeemer
pub type SpendService {
  UpdateService
  RemoveService
}

// Account Mint Purpose Redeemer
pub type MintAccount {
  CreateAccount
  DeleteAccount
}

// Account Mint Purpose Redeemer
pub type MintPayment {
  InitSubscripton
  TerminateSubscription
}

// Datum type 
pub type PaymentDatum {
  service_nft_tn: AssetName,
  account_nft_tn: AssetName,
  subscription_fee: AssetClass,
  subscription_fee_qty: Int,
  subscription_start: POSIXTime,
  subscription_end: POSIXTime,
  total_installments: Int,
}
// // Datum type 
// pub type MetaDatum {
//   metadata: Dict<ByteArray, Data>,
//   version: Int,
//   extra: ByteArray,
// }
