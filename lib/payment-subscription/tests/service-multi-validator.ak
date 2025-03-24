use cardano/assets.{add, merge, zero}
use cardano/transaction.{NoDatum}
use payment_subscription/common/cip68
use payment_subscription/common/values
use payment_subscription/service_multi_validator/validation.{
  validate_create_service, validate_remove_service, validate_update_service,
}
use payment_subscription/tests/tests

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
  let merchant_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_222)

  let ref_value = add(zero, own_cs, ref_tkn, 1)
  let merchant_value = add(zero, own_cs, merchant_tkn, 1)
  let minted_value = merge(ref_value, merchant_value)

  let merchant_pubkey_hash = tests.test_224_03()
  let merchant_output =
    tests.test_user_utxo(merchant_pubkey_hash, merchant_value, NoDatum)
  let service_output = tests.test_utxo_02(own_cs, ref_value, 100_000_000, datum)

  let merchant_input =
    tests.test_context_input_01(init_output_ref, own_cs, NoDatum)

  let inputs = [merchant_input]
  let outputs = [merchant_output, service_output]
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
  let merchant_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_222)

  let ref_value = add(zero, own_cs, ref_tkn, 1)
  let merchant_value = add(zero, own_cs, merchant_tkn, 1)

  let merchant_input =
    tests.test_context_input_02(
      init_output_ref,
      own_cs,
      merchant_value,
      NoDatum,
    )
  let service_input =
    tests.test_context_input_02(script_output_ref, own_cs, ref_value, datum)

  let merchant_output =
    tests.test_utxo_02(own_cs, merchant_value, 100_000_000, NoDatum)
  let service_output =
    tests.test_utxo_02(own_cs, ref_value, 100_000_000, new_datum)

  let inputs = [merchant_input, service_input]
  let outputs = [merchant_output, service_output]

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
  let merchant_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_222)

  let ref_value = add(zero, own_cs, ref_tkn, 1)
  let merchant_value = add(zero, own_cs, merchant_tkn, 1)

  let merchant_input =
    tests.test_context_input_02(
      init_output_ref,
      tests.test_wallet_addr(),
      merchant_value,
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

  let merchant_output =
    tests.test_utxo_02(
      tests.test_wallet_addr(),
      merchant_value,
      100_000_000,
      NoDatum,
    )
  let service_output =
    tests.test_utxo_02(own_cs, ref_value, 100_000_000, new_datum)

  let inputs = [merchant_input, service_input]
  let outputs = [merchant_output, service_output]

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

// Negative tests:

// If the minted value does not contain exactly one pair for the reference token 
// and one for the merchant token, then the service creation must fail.
test fail_create_service_invalid_minted_tokens() fail {
  let own_cs = tests.test_224_01()
  let tx_hash = tests.test_224_02()
  let init_output_ref = tests.test_input_utxo_02(tx_hash)
  // Use valid service metadata.
  let datum =
    tests.test_service_datum(True, 30 * 24 * 60 * 60 * 1000, 1, 100_000_000)

  let ref_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_100)
  let merchant_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_222)

  // Minted tokens with wrong amounts: for example, mint 2 of the reference token instead of 1.
  let ref_value = add(zero, own_cs, ref_tkn, 2)
  let merchant_value = add(zero, own_cs, merchant_tkn, 1)
  let minted_value = merge(ref_value, merchant_value)

  let merchant_pubkey_hash = tests.test_224_03()
  let merchant_output =
    tests.test_user_utxo(merchant_pubkey_hash, merchant_value, NoDatum)
  let service_output = tests.test_utxo_02(own_cs, ref_value, 100_000_000, datum)

  let merchant_input =
    tests.test_context_input_01(init_output_ref, own_cs, NoDatum)
  let inputs = [merchant_input]
  let outputs = [merchant_output, service_output]

  validate_create_service(own_cs, 0, 1, minted_value, inputs, outputs)
}

// If the ServiceDatum fails basic validity (for example, a nonpositive service fee or 
// interval, or num_intervals out of range), then creation must fail.
test fail_create_service_invalid_metadata() fail {
  let own_cs = tests.test_224_01()
  let tx_hash = tests.test_224_02()
  let init_output_ref = tests.test_input_utxo_02(tx_hash)
  // Create a datum with invalid metadata (e.g. interval_length = 0)
  let datum = tests.test_service_datum(True, 0, 1, 100_000_000)

  let ref_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_100)
  let merchant_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_222)

  let ref_value = add(zero, own_cs, ref_tkn, 1)
  let merchant_value = add(zero, own_cs, merchant_tkn, 1)
  let minted_value = merge(ref_value, merchant_value)

  let merchant_pubkey_hash = tests.test_224_03()
  let merchant_output =
    tests.test_user_utxo(merchant_pubkey_hash, merchant_value, NoDatum)
  let service_output = tests.test_utxo_02(own_cs, ref_value, 100_000_000, datum)

  let merchant_input =
    tests.test_context_input_01(init_output_ref, own_cs, NoDatum)
  let inputs = [merchant_input]
  let outputs = [merchant_output, service_output]

  validate_create_service(own_cs, 0, 1, minted_value, inputs, outputs)
}

// If the output’s address does not use the service’s script credential, then the creation should fail.
test fail_create_service_wrong_output_address() fail {
  let own_cs = tests.test_224_01()
  let tx_hash = tests.test_224_02()
  let init_output_ref = tests.test_input_utxo_02(tx_hash)
  let datum =
    tests.test_service_datum(True, 30 * 24 * 60 * 60 * 1000, 1, 100_000_000)

  let ref_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_100)
  let merchant_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_222)

  let ref_value = add(zero, own_cs, ref_tkn, 1)
  let merchant_value = add(zero, own_cs, merchant_tkn, 1)
  let minted_value = merge(ref_value, merchant_value)

  // Force a wrong output address by using a different credential.
  let wrong_address = tests.test_224_03()
  let service_output =
    tests.test_utxo_02(wrong_address, ref_value, 100_000_000, datum)
  let merchant_pubkey_hash = tests.test_224_03()
  let merchant_output =
    tests.test_user_utxo(merchant_pubkey_hash, merchant_value, NoDatum)
  let merchant_input =
    tests.test_context_input_01(init_output_ref, own_cs, NoDatum)

  let inputs = [merchant_input]
  let outputs = [merchant_output, service_output]

  validate_create_service(own_cs, 0, 1, minted_value, inputs, outputs)
}

// In an update, if the output does not go to the same service script address as the input, 
// then the update must be rejected.
test fail_update_service_wrong_output_address() fail {
  let own_cs = tests.test_224_01()
  let tx_hash = tests.test_224_02()
  let init_output_ref = tests.test_input_utxo_02(tx_hash)
  let script_output_ref = tests.test_input_utxo_02(tests.test_224_01())

  let datum =
    tests.test_service_datum(True, 30 * 24 * 60 * 60 * 1000, 1, 100_000_000)
  let new_datum =
    tests.test_service_datum(True, 30 * 24 * 60 * 60 * 1000, 1, 100_000_000)
  let ref_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_100)
  let merchant_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_222)

  let ref_value = add(zero, own_cs, ref_tkn, 1)
  let merchant_value = add(zero, own_cs, merchant_tkn, 1)

  let merchant_input =
    tests.test_context_input_02(
      init_output_ref,
      own_cs,
      merchant_value,
      NoDatum,
    )
  let service_input =
    tests.test_context_input_02(script_output_ref, own_cs, ref_value, datum)

  // Force wrong output address.
  let wrong_address = tests.test_224_03()
  let service_output =
    tests.test_utxo_02(wrong_address, ref_value, 100_000_000, new_datum)
  let merchant_output =
    tests.test_utxo_02(own_cs, merchant_value, 100_000_000, NoDatum)

  let inputs = [merchant_input, service_input]
  let outputs = [merchant_output, service_output]

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

// The updated datum must reflect the correct service parameters (e.g. is active state). 
// If any field doesn’t match, then the update should fail.
test fail_update_service_invalid_datum() fail {
  let own_cs = tests.test_224_01()
  let tx_hash = tests.test_224_02()
  let init_output_ref = tests.test_input_utxo_02(tx_hash)
  let script_output_ref = tests.test_input_utxo_02(tests.test_224_01())

  let datum =
    tests.test_service_datum(True, 30 * 24 * 60 * 60 * 1000, 1, 100_000_000)
  // Create new_datum that does not match datum in critical fields.
  let new_datum =
    tests.test_service_datum(False, 30 * 24 * 60 * 60 * 1000, 2, 100_000_000)
  let ref_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_100)

  let ref_value = add(zero, own_cs, ref_tkn, 1)
  let merchant_value =
    add(zero, own_cs, values.unique_token_name(tx_hash, 1, cip68.prefix_222), 1)
  let merchant_input =
    tests.test_context_input_02(
      init_output_ref,
      own_cs,
      merchant_value,
      NoDatum,
    )
  let service_input =
    tests.test_context_input_02(script_output_ref, own_cs, ref_value, datum)

  let merchant_output =
    tests.test_utxo_02(own_cs, merchant_value, 100_000_000, NoDatum)
  let service_output =
    tests.test_utxo_02(own_cs, ref_value, 100_000_000, new_datum)

  let inputs = [merchant_input, service_input]
  let outputs = [merchant_output, service_output]

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

// The update requires that the merchant input includes the “owner” token 
// (derived from converting the service reference token name). 
// If that token is missing, the update should fail.
test fail_update_service_missing_merchant_token() fail {
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

  // let _merchant_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_222)
  let ref_value = add(zero, own_cs, ref_tkn, 1)

  // Create Incorrect token( Should be merchant token)
  let merchant_value = add(zero, own_cs, ref_tkn, 1)

  let merchant_input =
    tests.test_context_input_02(
      init_output_ref,
      own_cs,
      merchant_value,
      NoDatum,
    )
  let service_input =
    tests.test_context_input_02(script_output_ref, own_cs, ref_value, datum)

  let merchant_output =
    tests.test_utxo_02(own_cs, merchant_value, 100_000_000, NoDatum)
  let service_output =
    tests.test_utxo_02(own_cs, ref_value, 100_000_000, new_datum)

  let inputs = [merchant_input, service_input]
  let outputs = [merchant_output, service_output]

  validate_update_service(
    script_output_ref,
    datum,
    ref_tkn,
    0,
    // merchant input index
    1,
    // service input index
    1,
    // service output index
    inputs,
    outputs,
  )
}

// When removing a service, the updated datum must mark the service as inactive. 
// If it remains active, the removal is invalid.
test fail_remove_service_not_inactive() fail {
  let own_cs = tests.test_224_01()
  let tx_hash = tests.test_224_02()
  let init_output_ref = tests.test_input_utxo_02(tx_hash)
  let script_output_ref = tests.test_input_utxo_02(tests.test_224_01())

  let datum =
    tests.test_service_datum(True, 30 * 24 * 60 * 60 * 1000, 1, 100_000_000)
  let ref_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_100)

  let ref_value = add(zero, own_cs, ref_tkn, 1)
  let user_value =
    add(zero, own_cs, values.unique_token_name(tx_hash, 1, cip68.prefix_222), 1)
  let user_input =
    tests.test_context_input_02(
      init_output_ref,
      tests.test_wallet_addr(),
      user_value,
      NoDatum,
    )
  let service_input =
    tests.test_context_input_02(script_output_ref, own_cs, ref_value, datum)
  // Produce an output datum that is still active.
  let new_datum =
    tests.test_service_datum(True, 30 * 24 * 60 * 60 * 1000, 1, 100_000_000)
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

// If the tokens in the output UTXO do not exactly match the expected pair 
// (i.e. the reference token with amount 1), then removal must be rejected.
test fail_remove_service_wrong_tokens() fail {
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
  let merchant_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_222)

  // Set incorrect token amount (should be 1) to force a fail!
  let ref_value = add(zero, own_cs, ref_tkn, 2)
  let merchant_value = add(zero, own_cs, merchant_tkn, 1)

  let merchant_input =
    tests.test_context_input_02(
      init_output_ref,
      tests.test_wallet_addr(),
      merchant_value,
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

  let merchant_output =
    tests.test_utxo_02(
      tests.test_wallet_addr(),
      merchant_value,
      100_000_000,
      NoDatum,
    )
  let service_output =
    tests.test_utxo_02(own_cs, ref_value, 100_000_000, new_datum)

  let inputs = [merchant_input, service_input]
  let outputs = [merchant_output, service_output]

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
