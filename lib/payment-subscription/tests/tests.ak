use aiken/collection/list
use aiken/crypto.{blake2b_256}
use aiken/fuzz.{and_then}
use aiken/interval.{Finite, Interval, IntervalBound}
use aiken/primitive/bytearray
use cardano/address.{Address, Script, VerificationKey}
use cardano/assets.{
  AssetName, PolicyId, Value, ada_asset_name, ada_policy_id, add, from_lovelace,
  merge, zero,
}
use cardano/transaction.{InlineDatum, Input, NoDatum, Output, OutputReference}
use payment_subscription/common/cip68
use payment_subscription/common/types.{
  AccountDatum, Installment, PaymentDatum, PenaltyDatum, ServiceDatum,
}
use payment_subscription/common/values

pub fn create_account_datum_fuzzer() -> Fuzzer<AccountDatum> {
  let email_hash <- and_then(fuzz.bytearray_fixed(32))
  let phone_hash <- and_then(fuzz.bytearray_fixed(32))

  fuzz.constant(AccountDatum { email_hash, phone_hash })
}

pub fn create_account_fuzzer() -> Fuzzer<
  (PolicyId, Int, Int, Value, List<Input>, List<Output>),
> {
  let own_policy <- and_then(fuzz.bytearray_fixed(28))
  let tx_hash <- and_then(fuzz.bytearray_fixed(28))
  let input_output_ref =
    OutputReference { transaction_id: tx_hash, output_index: 1 }

  let ref_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_100)
  let user_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_222)

  let ref_value = add(zero, own_policy, ref_tkn, 1)
  let user_value = add(zero, own_policy, user_tkn, 1)
  let minted_value = merge(ref_value, user_value)

  let user_input =
    Input {
      output_reference: input_output_ref,
      output: Output {
        address: Address(Script(own_policy), None),
        value: from_lovelace(4_000_000),
        datum: InlineDatum(NoDatum),
        reference_script: None,
      },
    }

  let user_key_hash <- and_then(fuzz.bytearray_fixed(28))
  let user_output =
    Output {
      address: Address {
        payment_credential: VerificationKey(user_key_hash),
        stake_credential: None,
      },
      value: add(user_value, ada_policy_id, ada_asset_name, 100_000_000),
      datum: InlineDatum(NoDatum),
      reference_script: None,
    }

  let own_datum <- and_then(create_account_datum_fuzzer())
  let own_output =
    Output {
      address: Address {
        payment_credential: Script(own_policy),
        stake_credential: None,
      },
      value: add(ref_value, ada_policy_id, ada_asset_name, 100_000_000),
      datum: InlineDatum(own_datum),
      reference_script: None,
    }

  let in_idx = 0
  let out_idx = 1

  fuzz.constant(
    (
      own_policy,
      in_idx,
      out_idx,
      minted_value,
      [user_input],
      [user_output, own_output],
    ),
  )
}

pub fn delete_account_fuzzer() -> Fuzzer<(PolicyId, Value, AssetName)> {
  let own_policy <- and_then(fuzz.bytearray_fixed(28))
  let tx_hash <- and_then(fuzz.bytearray_fixed(28))

  let ref_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_100)
  let user_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_222)

  let ref_value = add(zero, own_policy, ref_tkn, -1)
  let user_value = add(zero, own_policy, user_tkn, -1)
  let minted_value = merge(ref_value, user_value)

  fuzz.constant((own_policy, minted_value, ref_tkn))
}

pub fn update_account_fuzzer() -> Fuzzer<
  (OutputReference, AssetName, Int, Int, Int, List<Input>, List<Output>),
> {
  let own_policy <- and_then(fuzz.bytearray_fixed(28))
  let tx_hash <- and_then(fuzz.bytearray_fixed(28))
  let input_output_ref =
    OutputReference { transaction_id: tx_hash, output_index: 1 }
  let account_output_ref =
    OutputReference { transaction_id: own_policy, output_index: 1 }

  let ref_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_100)
  let user_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_222)

  let ref_value = add(zero, own_policy, ref_tkn, 1)
  let user_value = add(zero, own_policy, user_tkn, 1)

  let user_input =
    Input {
      output_reference: input_output_ref,
      output: Output {
        address: Address(Script(own_policy), None),
        value: user_value,
        datum: InlineDatum(NoDatum),
        reference_script: None,
      },
    }

  let old_datum <- and_then(create_account_datum_fuzzer())
  let account_input =
    Input {
      output_reference: account_output_ref,
      output: Output {
        address: Address(Script(own_policy), None),
        value: ref_value,
        datum: InlineDatum(old_datum),
        reference_script: None,
      },
    }

  let user_key_hash <- and_then(fuzz.bytearray_fixed(28))
  let user_output =
    Output {
      address: Address {
        payment_credential: VerificationKey(user_key_hash),
        stake_credential: None,
      },
      value: add(user_value, ada_policy_id, ada_asset_name, 100_000_000),
      datum: InlineDatum(NoDatum),
      reference_script: None,
    }

  let new_datum <- and_then(create_account_datum_fuzzer())
  let own_output =
    Output {
      address: Address {
        payment_credential: Script(own_policy),
        stake_credential: None,
      },
      value: add(ref_value, ada_policy_id, ada_asset_name, 100_000_000),
      datum: InlineDatum(new_datum),
      reference_script: None,
    }

  let user_input_index = 0
  let account_input_index = 1
  let reference_output_index = 1

  fuzz.constant(
    (
      account_output_ref,
      ref_tkn,
      user_input_index,
      account_input_index,
      reference_output_index,
      [user_input, account_input],
      [user_output, own_output],
    ),
  )
}

pub fn remove_account_fuzzer() -> Fuzzer<
  (OutputReference, AssetName, Int, Int, List<Input>, Value),
> {
  let own_policy <- and_then(fuzz.bytearray_fixed(28))
  let tx_hash <- and_then(fuzz.bytearray_fixed(28))
  let input_output_ref =
    OutputReference { transaction_id: tx_hash, output_index: 1 }
  let account_output_ref =
    OutputReference { transaction_id: own_policy, output_index: 1 }

  let ref_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_100)
  let user_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_222)

  let ref_value = add(zero, own_policy, ref_tkn, 1)
  let user_value = add(zero, own_policy, user_tkn, 1)

  let mint_ref_value = add(zero, own_policy, ref_tkn, -1)
  let mint_user_value = add(zero, own_policy, user_tkn, -1)
  let minted_value = merge(mint_ref_value, mint_user_value)

  let user_input =
    Input {
      output_reference: input_output_ref,
      output: Output {
        address: Address(Script(own_policy), None),
        value: user_value,
        datum: InlineDatum(NoDatum),
        reference_script: None,
      },
    }

  let datum <- and_then(create_account_datum_fuzzer())
  let account_input =
    Input {
      output_reference: account_output_ref,
      output: Output {
        address: Address(Script(own_policy), None),
        value: ref_value,
        datum: InlineDatum(datum),
        reference_script: None,
      },
    }

  let user_input_index = 0
  let account_input_index = 1

  fuzz.constant(
    (
      account_output_ref,
      ref_tkn,
      user_input_index,
      account_input_index,
      [user_input, account_input],
      minted_value,
    ),
  )
}

pub fn service_datum_fuzzer(
  is_active: Bool,
  interval_length: Int,
  num_intervals: Int,
  service_fee: Int,
  penalty_fee: Int,
) -> Fuzzer<ServiceDatum> {
  fuzz.constant(
    ServiceDatum {
      service_fee_policyid: ada_policy_id,
      service_fee_assetname: ada_asset_name,
      service_fee,
      penalty_fee_policyid: ada_policy_id,
      penalty_fee_assetname: ada_asset_name,
      penalty_fee,
      interval_length,
      num_intervals,
      is_active,
    },
  )
}

pub fn create_service_fuzzer() -> Fuzzer<
  (PolicyId, Int, Int, Value, List<Input>, List<Output>),
> {
  let own_policy <- and_then(fuzz.bytearray_fixed(28))
  let tx_hash <- and_then(fuzz.bytearray_fixed(28))
  let input_output_ref =
    OutputReference { transaction_id: tx_hash, output_index: 1 }

  let ref_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_100)
  let user_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_222)

  let ref_value = add(zero, own_policy, ref_tkn, 1)
  let user_value = add(zero, own_policy, user_tkn, 1)
  let minted_value = merge(ref_value, user_value)

  let user_key_hash <- and_then(fuzz.bytearray_fixed(28))

  let user_input =
    Input {
      output_reference: input_output_ref,
      output: Output {
        address: Address {
          payment_credential: VerificationKey(user_key_hash),
          stake_credential: None,
        },
        value: from_lovelace(4_000_000),
        datum: InlineDatum(NoDatum),
        reference_script: None,
      },
    }

  let user_output =
    Output {
      address: Address {
        payment_credential: VerificationKey(user_key_hash),
        stake_credential: None,
      },
      value: add(user_value, ada_policy_id, ada_asset_name, 4_000_000),
      datum: InlineDatum(NoDatum),
      reference_script: None,
    }

  // 30 days in milliseconds
  let interval_length = 30 * 24 * 60 * 60 * 1000
  let num_intervals = 1
  let service_fee = 100_000_000
  let penalty_fee = 1_000_000
  let is_active = True

  let datum <-
    and_then(
      service_datum_fuzzer(
        is_active,
        interval_length,
        num_intervals,
        service_fee,
        penalty_fee,
      ),
    )

  let own_output =
    Output {
      address: Address {
        payment_credential: Script(own_policy),
        stake_credential: None,
      },
      value: add(ref_value, ada_policy_id, ada_asset_name, 100_000_000),
      datum: InlineDatum(datum),
      reference_script: None,
    }

  let in_idx = 0
  let out_idx = 1

  fuzz.constant(
    (
      own_policy,
      in_idx,
      out_idx,
      minted_value,
      [user_input],
      [user_output, own_output],
    ),
  )
}

pub fn update_service_fuzzer() -> Fuzzer<
  (
    OutputReference,
    ServiceDatum,
    AssetName,
    Int,
    Int,
    Int,
    List<Input>,
    List<Output>,
  ),
> {
  let own_policy <- and_then(fuzz.bytearray_fixed(28))
  let tx_hash <- and_then(fuzz.bytearray_fixed(28))
  let input_output_ref =
    OutputReference { transaction_id: tx_hash, output_index: 1 }
  let service_output_ref =
    OutputReference { transaction_id: own_policy, output_index: 1 }

  let ref_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_100)
  let user_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_222)

  let ref_value = add(zero, own_policy, ref_tkn, 1)
  let user_value = add(zero, own_policy, user_tkn, 1)

  let user_key_hash <- and_then(fuzz.bytearray_fixed(28))

  let user_input =
    Input {
      output_reference: input_output_ref,
      output: Output {
        address: Address {
          payment_credential: VerificationKey(user_key_hash),
          stake_credential: None,
        },
        value: user_value,
        datum: InlineDatum(NoDatum),
        reference_script: None,
      },
    }

  // 30 days in milliseconds
  let interval_length = 30 * 24 * 60 * 60 * 1000
  let num_intervals = 1
  let service_fee = 100_000_000
  let penalty_fee = 1_000_000
  let is_active = True

  let datum <-
    and_then(
      service_datum_fuzzer(
        is_active,
        interval_length,
        num_intervals,
        service_fee,
        penalty_fee,
      ),
    )

  let service_input =
    Input {
      output_reference: service_output_ref,
      output: Output {
        address: Address {
          payment_credential: Script(own_policy),
          stake_credential: None,
        },
        value: ref_value,
        datum: InlineDatum(datum),
        reference_script: None,
      },
    }

  let user_output =
    Output {
      address: Address {
        payment_credential: VerificationKey(user_key_hash),
        stake_credential: None,
      },
      value: add(user_value, ada_policy_id, ada_asset_name, 100_000_000),
      datum: InlineDatum(NoDatum),
      reference_script: None,
    }

  let new_datum <-
    and_then(
      service_datum_fuzzer(
        is_active,
        interval_length,
        num_intervals,
        service_fee,
        penalty_fee,
      ),
    )

  let service_output =
    Output {
      address: Address {
        payment_credential: Script(own_policy),
        stake_credential: None,
      },
      value: add(ref_value, ada_policy_id, ada_asset_name, 100_000_000),
      datum: InlineDatum(new_datum),
      reference_script: None,
    }

  let merchant_input_index = 0
  let service_input_index = 1
  let service_output_index = 1

  fuzz.constant(
    (
      service_output_ref,
      datum,
      ref_tkn,
      merchant_input_index,
      service_input_index,
      service_output_index,
      [user_input, service_input],
      [user_output, service_output],
    ),
  )
}

pub fn remove_service_fuzzer() -> Fuzzer<
  (
    OutputReference,
    ServiceDatum,
    AssetName,
    Int,
    Int,
    Int,
    List<Input>,
    List<Output>,
  ),
> {
  let own_policy <- and_then(fuzz.bytearray_fixed(28))
  let tx_hash <- and_then(fuzz.bytearray_fixed(28))
  let input_output_ref =
    OutputReference { transaction_id: tx_hash, output_index: 1 }
  let service_output_ref =
    OutputReference { transaction_id: own_policy, output_index: 1 }

  let ref_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_100)
  let user_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_222)

  let ref_value = add(zero, own_policy, ref_tkn, 1)
  let user_value = add(zero, own_policy, user_tkn, 1)

  let user_key_hash <- and_then(fuzz.bytearray_fixed(28))

  let user_input =
    Input {
      output_reference: input_output_ref,
      output: Output {
        address: Address {
          payment_credential: VerificationKey(user_key_hash),
          stake_credential: None,
        },
        value: user_value,
        datum: InlineDatum(NoDatum),
        reference_script: None,
      },
    }

  // 30 days in milliseconds
  let interval_length = 30 * 24 * 60 * 60 * 1000
  let num_intervals = 1
  let service_fee = 100_000_000
  let penalty_fee = 1_000_000
  let is_active = True

  let datum <-
    and_then(
      service_datum_fuzzer(
        is_active,
        interval_length,
        num_intervals,
        service_fee,
        penalty_fee,
      ),
    )

  let service_input =
    Input {
      output_reference: service_output_ref,
      output: Output {
        address: Address {
          payment_credential: Script(own_policy),
          stake_credential: None,
        },
        value: ref_value,
        datum: InlineDatum(datum),
        reference_script: None,
      },
    }

  let user_output =
    Output {
      address: Address {
        payment_credential: VerificationKey(user_key_hash),
        stake_credential: None,
      },
      value: add(user_value, ada_policy_id, ada_asset_name, 100_000_000),
      datum: InlineDatum(NoDatum),
      reference_script: None,
    }

  let disabled_datum <-
    and_then(
      service_datum_fuzzer(
        False,
        interval_length,
        num_intervals,
        service_fee,
        penalty_fee,
      ),
    )

  let service_output =
    Output {
      address: Address {
        payment_credential: Script(own_policy),
        stake_credential: None,
      },
      value: add(ref_value, ada_policy_id, ada_asset_name, 100_000_000),
      datum: InlineDatum(disabled_datum),
      reference_script: None,
    }

  let merchant_input_index = 0
  let service_input_index = 1
  let service_output_index = 1

  fuzz.constant(
    (
      service_output_ref,
      datum,
      ref_tkn,
      merchant_input_index,
      service_input_index,
      service_output_index,
      [user_input, service_input],
      [user_output, service_output],
    ),
  )
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
