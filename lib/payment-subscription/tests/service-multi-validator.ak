use aiken/fuzz.{and_then}
use cardano/address.{Address, Script, VerificationKey}
use cardano/assets.{
  AssetName, PolicyId, Value, ada_asset_name, ada_policy_id, add, from_lovelace,
  merge, zero,
}
use cardano/transaction.{InlineDatum, Input, NoDatum, Output, OutputReference}
use payment_subscription/common/cip68
use payment_subscription/common/types.{ServiceDatum}
use payment_subscription/common/values
use payment_subscription/service_multi_validator/validation.{
  validate_create_service, validate_remove_service, validate_update_service,
}
use payment_subscription/tests/tests

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

test success_create_service_fuzzy(test_values via create_service_fuzzer()) {
  let (own_policy, in_idx, out_idx, minted_value, inputs, outputs) = test_values
  validate_create_service(
    own_policy,
    in_idx,
    out_idx,
    minted_value,
    inputs,
    outputs,
  )
}

test success_update_service_fuzzy(test_values via update_service_fuzzer()) {
  let (
    service_output_ref,
    datum,
    ref_tkn,
    merchant_input_index,
    service_input_index,
    service_output_index,
    inputs,
    outputs,
  ) = test_values
  validate_update_service(
    service_output_ref,
    datum,
    ref_tkn,
    merchant_input_index,
    service_input_index,
    service_output_index,
    inputs,
    outputs,
  )
}

test success_remove_service_fuzzy(test_values via remove_service_fuzzer()) {
  let (
    service_output_ref,
    datum,
    ref_tkn,
    merchant_input_index,
    service_input_index,
    service_output_index,
    inputs,
    outputs,
  ) = test_values
  validate_remove_service(
    service_output_ref,
    datum,
    ref_tkn,
    merchant_input_index,
    service_input_index,
    service_output_index,
    inputs,
    outputs,
  )
}

test success_create_service() {
  let own_cs = tests.test_224_01()
  let tx_hash = tests.test_224_02()
  let init_output_ref = tests.test_input_utxo_02(tx_hash)
  // 30 days in milliseconds
  let interval_length = 30 * 24 * 60 * 60 * 1000
  let num_intervals = 1
  let interval_amount = 100_000_000

  let is_active = True
  let datum =
    tests.test_service_datum(
      is_active,
      interval_length,
      num_intervals,
      interval_amount,
    )

  let ref_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_100)
  let user_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_222)

  let ref_value = add(zero, own_cs, ref_tkn, 1)
  let user_value = add(zero, own_cs, user_tkn, 1)
  let minted_value = merge(ref_value, user_value)

  let user_pubkey_hash = tests.test_224_03()
  let user_output = tests.test_user_utxo(user_pubkey_hash, user_value, NoDatum)
  let service_output = tests.test_utxo_02(own_cs, ref_value, 100_000_000, datum)

  let user_input = tests.test_context_input_01(init_output_ref, own_cs, NoDatum)

  let inputs = [user_input]
  let outputs = [user_output, service_output]
  let mint = minted_value

  validate_create_service(own_cs, 0, 1, mint, inputs, outputs)
}

test succeed_update_service() {
  let own_cs = tests.test_224_01()
  let tx_hash = tests.test_224_02()
  let init_output_ref = tests.test_input_utxo_02(tx_hash)
  let script_output_ref = tests.test_input_utxo_02(tests.test_224_01())
  // 30 days in milliseconds
  let subscription_period = 30 * 24 * 60 * 60 * 1000
  let num_intervals = 1
  let interval_amount = 100_000_000

  let is_active = True
  let datum =
    tests.test_service_datum(
      is_active,
      subscription_period,
      num_intervals,
      interval_amount,
    )
  let new_datum =
    tests.test_service_datum(
      is_active,
      subscription_period,
      num_intervals,
      interval_amount,
    )

  let ref_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_100)
  let user_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_222)

  let ref_value = add(zero, own_cs, ref_tkn, 1)
  let user_value = add(zero, own_cs, user_tkn, 1)

  let user_input =
    tests.test_context_input_02(init_output_ref, own_cs, user_value, NoDatum)
  let service_input =
    tests.test_context_input_02(script_output_ref, own_cs, ref_value, datum)

  let user_output = tests.test_utxo_02(own_cs, user_value, 100_000_000, NoDatum)
  let service_output =
    tests.test_utxo_02(own_cs, ref_value, 100_000_000, new_datum)

  let inputs = [user_input, service_input]
  let outputs = [user_output, service_output]

  validate_update_service(
    script_output_ref,
    datum,
    ref_tkn,
    0,
    1,
    1,
    inputs,
    outputs,
  )
}

test succeed_remove_service() {
  let own_cs = tests.test_224_01()
  let tx_hash = tests.test_224_02()
  let init_output_ref = tests.test_input_utxo_02(tx_hash)
  let script_output_ref = tests.test_input_utxo_02(tests.test_224_01())
  // 30 days in milliseconds
  let subscription_period = 30 * 24 * 60 * 60 * 1000
  let num_intervals = 1
  let interval_amount = 100_000_000

  let is_active = True
  let datum =
    tests.test_service_datum(
      is_active,
      subscription_period,
      num_intervals,
      interval_amount,
    )

  let ref_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_100)
  let user_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_222)

  let ref_value = add(zero, own_cs, ref_tkn, 1)
  let user_value = add(zero, own_cs, user_tkn, 1)

  let user_input =
    tests.test_context_input_02(
      init_output_ref,
      tests.test_wallet_addr(),
      user_value,
      NoDatum,
    )
  let service_input =
    tests.test_context_input_02(script_output_ref, own_cs, ref_value, datum)

  let new_datum =
    tests.test_service_datum(
      False,
      subscription_period,
      num_intervals,
      interval_amount,
    )

  let user_output =
    tests.test_utxo_02(
      tests.test_wallet_addr(),
      user_value,
      100_000_000,
      NoDatum,
    )
  let service_output =
    tests.test_utxo_02(own_cs, ref_value, 100_000_000, new_datum)

  let inputs = [user_input, service_input]
  let outputs = [user_output, service_output]

  validate_remove_service(
    script_output_ref,
    datum,
    ref_tkn,
    0,
    1,
    1,
    inputs,
    outputs,
  )
}
