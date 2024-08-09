use aiken/bytearray
use aiken/dict
use aiken/hash.{blake2b_256}
use aiken/interval.{Finite, Interval, IntervalBound}
// use aiken/list
use aiken/transaction.{
  InlineDatum, Input, Output, OutputReference, ScriptContext, Spend, Transaction,
  TransactionId,
}
use aiken/transaction/credential.{Address, ScriptCredential}
use aiken/transaction/value
use payment_subscription/types.{
  AccountDatum, AssetClass, POSIXTime, PaymentDatum, PenaltyDatum, ServiceDatum,
}

// Generate a bytearray with blake2b_256
pub fn test_224_01() {
  bytearray.take(blake2b_256(#"01"), 28)
}

// Generate a bytearray with blake2b_256
pub fn test_224_02() {
  bytearray.take(blake2b_256(#"02"), 28)
}

// Generate a bytearray with blake2b_256
pub fn test_224_03() {
  bytearray.take(blake2b_256(#"03"), 28)
}

pub fn test_224_04() {
  bytearray.take(blake2b_256(#"04"), 28)
}

// Generate a bytearray with blake2b_256
pub fn test_account_cs() {
  bytearray.take(blake2b_256(#"05"), 28)
}

pub fn test_service_cs() {
  bytearray.take(blake2b_256(#"06"), 28)
}

pub fn test_payment_cs() {
  bytearray.take(blake2b_256(#"07"), 28)
}

// Create a UTxO
pub fn test_utxo_01() {
  Output {
    address: Address {
      payment_credential: ScriptCredential(test_224_01()),
      stake_credential: None,
    },
    value: value.add(value.from_lovelace(2_000_000), test_224_01(), #"01", 1),
    datum: InlineDatum(1),
    reference_script: None,
  }
}

// Create a UTxO
pub fn test_utxo_02(own_cs, minted_value, datum) {
  Output {
    address: Address {
      payment_credential: ScriptCredential(own_cs),
      stake_credential: None,
    },
    value: value.add(
      minted_value,
      value.ada_policy_id,
      value.ada_asset_name,
      40_000_000,
    ),
    datum: InlineDatum(datum),
    reference_script: None,
  }
}

pub fn test_user_utxo(pubkey_hash: ByteArray, minted_value, datum) {
  Output {
    address: Address {
      payment_credential: credential.VerificationKeyCredential(pubkey_hash),
      stake_credential: None,
    },
    value: value.add(
      minted_value,
      value.ada_policy_id,
      value.ada_asset_name,
      4_000_000,
    ),
    datum: InlineDatum(datum),
    reference_script: None,
  }
}

pub fn test_input_utxo_01() {
  OutputReference {
    transaction_id: TransactionId { hash: test_224_01() },
    output_index: 1,
  }
}

pub fn test_input_utxo_02(utxo_hash) {
  OutputReference {
    transaction_id: TransactionId { hash: utxo_hash },
    output_index: 1,
  }
}

pub fn test_datum_01(fee_qty: Int, penalty_qty: Int, subsc_period: Int) {
  ServiceDatum {
    service_fee: AssetClass {
      policy_id: value.ada_policy_id,
      asset_name: value.ada_asset_name,
    },
    // Replace with actual AssetName
    service_fee_qty: fee_qty,
    penalty_fee: AssetClass {
      policy_id: value.ada_policy_id,
      asset_name: value.ada_asset_name,
    },
    penalty_fee_qty: penalty_qty,
    subscription_period: subsc_period,
  }
}

pub fn test_context_input_01(output_ref, own_cs, datum) {
  Input {
    output_reference: output_ref,
    output: Output {
      address: Address(credential.ScriptCredential(own_cs), None),
      value: value.from_lovelace(4_000_000),
      datum: InlineDatum(datum),
      reference_script: None,
    },
  }
}

pub fn test_context_input_02(output_ref, own_cs, minted_value, datum) {
  Input {
    output_reference: output_ref,
    output: Output {
      address: Address(credential.ScriptCredential(own_cs), None),
      value: value.add(
        minted_value,
        value.ada_policy_id,
        value.ada_asset_name,
        4_000_000,
      ),
      datum: InlineDatum(datum),
      reference_script: None,
    },
  }
}

pub fn test_datum_02(
  email: ByteArray,
  phone: ByteArray,
  account_start: POSIXTime,
  account_end: POSIXTime,
) {
  AccountDatum { email, phone, account_start, account_end }
}

pub fn test_datum_03(
  service_tn: ByteArray,
  account_tn: ByteArray,
  fee_qty: Int,
  subsc_start: POSIXTime,
  subsc_end: POSIXTime,
  subsc_period: POSIXTime,
  penalty_fee: Int,
) {
  PaymentDatum {
    service_nft_tn: service_tn,
    account_nft_tn: account_tn,
    subscription_fee: AssetClass {
      policy_id: value.ada_policy_id,
      asset_name: value.ada_asset_name,
    },
    subscription_fee_qty: fee_qty,
    subscription_start: subsc_start,
    subscription_end: subsc_end,
    subscription_period: subsc_period,
    penalty_fee: AssetClass {
      policy_id: value.ada_policy_id,
      asset_name: value.ada_asset_name,
    },
    penalty_fee_qty: penalty_fee,
  }
}

pub fn test_time_range(lower_bound: POSIXTime, upper_bound: POSIXTime) {
  Interval {
    lower_bound: IntervalBound {
      bound_type: Finite(lower_bound),
      is_inclusive: True,
    },
    upper_bound: IntervalBound {
      bound_type: Finite(upper_bound),
      is_inclusive: False,
    },
  }
}

pub fn test_penalty_datum(
  service_tn: ByteArray,
  account_tn: ByteArray,
  fee_qty: Int,
) {
  PenaltyDatum {
    service_nft_tn: service_tn,
    account_nft_tn: account_tn,
    penalty_fee: AssetClass {
      policy_id: value.ada_policy_id,
      asset_name: value.ada_asset_name,
    },
    penalty_fee_qty: fee_qty,
  }
}

pub fn test_spend_script_context(
  output_ref,
  // can be one or many
  main_inputs,
  // can be one or many
  ref_inputs,
  // can be one or many
  main_outputs,
  // can be one or many
  minted_value,
  time_range,
  tx_hash: ByteArray,
) {
  ScriptContext {
    purpose: Spend(output_ref),
    transaction: Transaction {
      inputs: main_inputs,
      reference_inputs: ref_inputs,
      outputs: main_outputs,
      // fee: value.from_lovelace(2_000_000),
      fee: value.zero(),
      mint: value.to_minted_value(minted_value),
      certificates: [],
      withdrawals: [],
      validity_range: time_range,
      extra_signatories: [],
      redeemers: [],
      datums: dict.new(),
      id: TransactionId { hash: tx_hash },
    },
  }
}
