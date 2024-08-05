use aiken/bytearray
use aiken/hash.{blake2b_256}
// use aiken/list
use aiken/transaction.{
  InlineDatum, Input, Output, OutputReference, TransactionId,
}
use aiken/transaction/credential.{Address, ScriptCredential}
use aiken/transaction/value
use payment_subscription/types.{
  AccountDatum, AssetClass, POSIXTime, ServiceDatum,
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
      4_000_000,
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

pub fn test_datum_01(
  fee_qty: Int,
  penalty_qty: Int,
  installments: Int,
  min_period: Int,
) {
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
    total_installments: installments,
    min_sub_period: min_period,
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
