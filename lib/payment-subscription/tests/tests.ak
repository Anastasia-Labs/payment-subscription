use aiken/collection/list
use aiken/crypto.{blake2b_256}
use aiken/interval.{Finite, Interval, IntervalBound}
use aiken/primitive/bytearray
use cardano/address.{Address, Script, VerificationKey}
use cardano/assets.{ada_asset_name, ada_policy_id, add, from_lovelace, zero}
use cardano/transaction.{InlineDatum, Input, NoDatum, Output, OutputReference}
use payment_subscription/common/types.{
  AccountDatum, Installment, PaymentDatum, PenaltyDatum, ServiceDatum,
}

pub const placeholder_output =
  Output {
    address: Address {
      payment_credential: VerificationKey(
        #"00000000000000000000000000000000000000000000000000000000",
      ),
      stake_credential: None,
    },
    value: zero,
    datum: NoDatum,
    reference_script: None,
  }

pub const placeholder_input =
  Input {
    output_reference: OutputReference {
      transaction_id: #"0000000000000000000000000000000000000000000000000000000000000000",
      output_index: 0,
    },
    output: placeholder_output,
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

pub fn test_wallet_addr() {
  bytearray.take(blake2b_256(#"08"), 28)
}

// Create a UTxO
pub fn test_utxo_01() {
  Output {
    address: Address {
      payment_credential: Script(test_224_01()),
      stake_credential: None,
    },
    value: add(from_lovelace(2_000_000), test_224_01(), #"01", 1),
    datum: InlineDatum(1),
    reference_script: None,
  }
}

// Create a UTxO
pub fn test_utxo_02(own_cs, minted_value, lovelace, datum) {
  Output {
    address: Address {
      payment_credential: Script(own_cs),
      stake_credential: None,
    },
    value: add(minted_value, ada_policy_id, ada_asset_name, lovelace),
    datum: InlineDatum(datum),
    reference_script: None,
  }
}

pub fn test_utxo_exact(own_cs, minted_value, datum) {
  Output {
    address: Address {
      payment_credential: Script(own_cs),
      stake_credential: None,
    },
    value: minted_value,
    datum: InlineDatum(datum),
    reference_script: None,
  }
}

pub fn test_user_utxo(pubkey_hash: ByteArray, minted_value, datum) {
  Output {
    address: Address {
      payment_credential: VerificationKey(pubkey_hash),
      stake_credential: None,
    },
    value: add(minted_value, ada_policy_id, ada_asset_name, 4_000_000),
    datum: InlineDatum(datum),
    reference_script: None,
  }
}

pub fn test_input_utxo_01() {
  OutputReference { transaction_id: test_224_01(), output_index: 1 }
}

pub fn test_input_utxo_02(utxo_hash) {
  OutputReference { transaction_id: utxo_hash, output_index: 1 }
}

pub fn test_service_datum(
  status: Bool,
  subsc_period: Int,
  intervals: Int,
  interval_amount: Int,
) {
  // let fee_qty = 100_000_000
  let penalty_qty = 1_000_000

  // 120 days in milliseconds
  // let subsc_period = 30 * 24 * 60 * 60 * 1000 * 4
  ServiceDatum {
    service_fee_policyid: ada_policy_id,
    service_fee_assetname: ada_asset_name,
    service_fee: interval_amount,
    penalty_fee_policyid: ada_policy_id,
    penalty_fee_assetname: ada_asset_name,
    penalty_fee: penalty_qty,
    interval_length: subsc_period,
    num_intervals: intervals,
    is_active: status,
  }
}

pub fn test_context_input_01(output_ref, own_cs, datum) {
  Input {
    output_reference: output_ref,
    output: Output {
      address: Address(Script(own_cs), None),
      value: from_lovelace(4_000_000),
      datum: InlineDatum(datum),
      reference_script: None,
    },
  }
}

pub fn test_context_input_02(output_ref, own_cs, minted_value, datum) {
  Input {
    output_reference: output_ref,
    output: Output {
      address: Address(Script(own_cs), None),
      value: add(minted_value, ada_policy_id, ada_asset_name, 0),
      datum: InlineDatum(datum),
      reference_script: None,
    },
  }
}

pub fn test_datum_02(email_hash: ByteArray, phone_hash: ByteArray) {
  AccountDatum { email_hash, phone_hash }
}

pub fn test_datum_03(
  service_tn: ByteArray,
  account_tn: ByteArray,
  subsc_start: Int,
  subsc_end: Int,
  original_subsc_end: Int,
  subsc_period: Int,
  interval_amount: Int,
  num_intervals: Int,
  start_at_interval: Int,
) {
  let installments =
    list.range(start_at_interval, num_intervals)
      |> list.map(
          fn(i) {
            Installment {
              claimable_at: subsc_start + i * subsc_period,
              claimable_amount: interval_amount,
            }
          },
        )
  PaymentDatum {
    service_reference_tokenname: service_tn,
    subscriber_reference_tokenname: account_tn,
    subscription_start: subsc_start,
    subscription_end: subsc_end,
    original_subscription_end: original_subsc_end,
    installments,
  }
}

pub fn test_time_range(lower_bound: Int, upper_bound: Int) {
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

pub fn test_penalty_datum(service_tn: ByteArray, account_tn: ByteArray) {
  PenaltyDatum {
    service_reference_tokenname: service_tn,
    subscriber_reference_tokenname: account_tn,
  }
}
