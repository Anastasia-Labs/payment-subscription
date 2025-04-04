use aiken/crypto.{sha2_256}
use aiken/fuzz.{and_then}
use cardano/address.{Address, Script, VerificationKey}
use cardano/assets.{
  AssetName, PolicyId, Value, ada_asset_name, ada_policy_id, add, from_lovelace,
  merge, zero,
}
use cardano/transaction.{InlineDatum, Input, NoDatum, Output, OutputReference}
use payment_subscription/account_multi_validator/validation.{
  validate_create_account, validate_delete_account, validate_remove_account,
  validate_update_account,
}
use payment_subscription/common/cip68
use payment_subscription/common/types.{AccountDatum}
use payment_subscription/common/values
use payment_subscription/tests/tests

pub fn create_account_datum_fuzzer() -> Fuzzer<AccountDatum> {
  let email_hash <- and_then(fuzz.bytearray_fixed(32))
  let phone_hash <- and_then(fuzz.bytearray_fixed(32))

  fuzz.constant(AccountDatum { email_hash, phone_hash })
}

pub fn create_account_fuzzer() -> Fuzzer<
  (PolicyId, Int, Int, Value, List<Input>, List<Output>),
> {
  let own_policy <- and_then(fuzz.bytearray_fixed(28))
  let tx_hash <- and_then(fuzz.bytearray_fixed(32))
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
        value: from_lovelace(0),
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
      value: add(user_value, ada_policy_id, ada_asset_name, 1),
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
      value: add(ref_value, ada_policy_id, ada_asset_name, 1),
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
  let tx_hash <- and_then(fuzz.bytearray_fixed(32))

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
  let tx_hash <- and_then(fuzz.bytearray_fixed(32))
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
      value: add(user_value, ada_policy_id, ada_asset_name, 1),
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
      value: add(ref_value, ada_policy_id, ada_asset_name, 1),
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
  let tx_hash <- and_then(fuzz.bytearray_fixed(32))
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

test success_create_account_fuzzy(test_values via create_account_fuzzer()) {
  let (own_policy, in_idx, out_idx, minted_value, inputs, outputs) = test_values
  validate_create_account(
    own_policy,
    in_idx,
    out_idx,
    minted_value,
    inputs,
    outputs,
  )
}

test success_delete_account_fuzzy(test_values via delete_account_fuzzer()) {
  let (own_policy, minted_value, ref_value) = test_values
  validate_delete_account(own_policy, minted_value, ref_value)
}

test success_update_account_fuzzy(test_values via update_account_fuzzer()) {
  let (
    account_output_ref,
    ref_tkn,
    user_input_index,
    account_input_index,
    reference_output_index,
    inputs,
    outputs,
  ) = test_values
  validate_update_account(
    account_output_ref,
    ref_tkn,
    user_input_index,
    account_input_index,
    reference_output_index,
    inputs,
    outputs,
  )
}

test success_remove_account_fuzzy(test_values via remove_account_fuzzer()) {
  let (
    account_output_ref,
    ref_tkn,
    user_input_index,
    account_input_index,
    inputs,
    minted_value,
  ) = test_values
  validate_remove_account(
    account_output_ref,
    ref_tkn,
    user_input_index,
    account_input_index,
    inputs,
    minted_value,
  )
}

//Happy Path Tests
test success_create_account() {
  let own_cs = tests.test_224_01()
  let tx_hash = tests.test_224_02()
  let init_output_ref = tests.test_input_utxo_02(tx_hash)
  let datum =
    tests.test_datum_02(sha2_256("you@mail.com"), sha2_256("(717) 550-1675"))

  let ref_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_100)
  let user_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_222)

  let ref_value = add(zero, own_cs, ref_tkn, 1)
  let user_value = add(zero, own_cs, user_tkn, 1)
  let minted_value = merge(ref_value, user_value)

  let user_pubkey_hash = tests.test_224_03()
  let user_output =
    tests.test_utxo_02(user_pubkey_hash, user_value, 100_000_000, NoDatum)
  let script_output = tests.test_utxo_02(own_cs, ref_value, 100_000_000, datum)

  let user_input = tests.test_context_input_01(init_output_ref, own_cs, NoDatum)

  let inputs = [user_input]
  let outputs = [user_output, script_output]

  validate_create_account(own_cs, 0, 1, minted_value, inputs, outputs)
}

test succeed_delete_account() {
  let own_cs = tests.test_224_01()
  let tx_hash = tests.test_224_02()

  let ref_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_100)
  let user_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_222)

  let ref_value = add(zero, own_cs, ref_tkn, -1)
  let user_value = add(zero, own_cs, user_tkn, -1)
  let minted_value = merge(ref_value, user_value)

  validate_delete_account(own_cs, minted_value, ref_tkn)
}

test succeed_update_account() {
  let own_cs = tests.test_224_01()
  let tx_hash = tests.test_224_02()
  let init_output_ref = tests.test_input_utxo_02(tx_hash)
  let account_output_ref = tests.test_input_utxo_02(tests.test_224_01())

  let datum =
    tests.test_datum_02(sha2_256("you@mail.com"), sha2_256("(717) 550-1675"))
  let new_datum =
    tests.test_datum_02(sha2_256("me@mail.com"), sha2_256("(717) 550-1675"))

  //   let redeemer = UpdateAccount
  let ref_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_100)
  let user_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_222)

  let ref_value = add(zero, own_cs, ref_tkn, 1)
  let user_value = add(zero, own_cs, user_tkn, 1)

  let user_input =
    tests.test_context_input_02(init_output_ref, own_cs, user_value, NoDatum)
  let account_input =
    tests.test_context_input_02(account_output_ref, own_cs, ref_value, datum)

  let user_output = tests.test_utxo_02(own_cs, user_value, 100_000_000, NoDatum)
  let script_output =
    tests.test_utxo_02(own_cs, ref_value, 100_000_000, new_datum)

  let inputs = [user_input, account_input]
  let outputs = [user_output, script_output]

  validate_update_account(account_output_ref, ref_tkn, 0, 1, 1, inputs, outputs)
}

test succeed_remove_account() {
  let own_cs = tests.test_224_01()
  let tx_hash = tests.test_224_02()
  let init_output_ref = tests.test_input_utxo_02(tx_hash)
  let account_output_ref = tests.test_input_utxo_02(tests.test_224_01())

  let datum = tests.test_datum_02("you@mail.com", "(717) 550-1675")

  //   let redeemer = RemoveAccount
  let ref_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_100)
  let user_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_222)

  let ref_value = add(zero, own_cs, ref_tkn, 1)
  let user_value = add(zero, own_cs, user_tkn, 1)

  let mint_ref_value = add(zero, own_cs, ref_tkn, -1)
  let mint_user_value = add(zero, own_cs, user_tkn, -1)
  let minted_value = merge(mint_ref_value, mint_user_value)

  let user_input =
    tests.test_context_input_02(init_output_ref, own_cs, user_value, NoDatum)
  let account_input =
    tests.test_context_input_02(account_output_ref, own_cs, ref_value, datum)

  let inputs = [user_input, account_input]

  validate_remove_account(
    account_output_ref,
    ref_tkn,
    0,
    1,
    inputs,
    minted_value,
  )
}

//TODO: Negative Tests

// If the minted value does not contain exactly one of each required token 
// (the “reference” and “user” tokens with amount 1), then the transaction must be rejected.
test fail_create_account_invalid_minted_tokens() fail {
  let own_cs = tests.test_224_01()
  let tx_hash = tests.test_224_02()
  let init_output_ref = tests.test_input_utxo_02(tx_hash)
  let datum =
    tests.test_datum_02(sha2_256("you@mail.com"), sha2_256("(717) 550-1675"))
  let ref_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_100)
  let user_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_222)
  // Create minted tokens with wrong amounts (e.g. amount 2 instead of 1)
  let ref_value = add(zero, own_cs, ref_tkn, 2)
  let user_value = add(zero, own_cs, user_tkn, 2)
  let minted_value = merge(ref_value, user_value)
  let user_pubkey_hash = tests.test_224_03()
  let user_output =
    tests.test_utxo_02(user_pubkey_hash, user_value, 100_000_000, NoDatum)
  let script_output = tests.test_utxo_02(own_cs, ref_value, 100_000_000, datum)
  let user_input = tests.test_context_input_01(init_output_ref, own_cs, NoDatum)
  let inputs = [user_input]
  let outputs = [user_output, script_output]
  validate_create_account(own_cs, 0, 1, minted_value, inputs, outputs)
}

// If the minted value does not “burn” (i.e. include –1 for both tokens), 
// then the deletion must fail.

test fail_delete_account_invalid_burn() fail {
  let own_cs = tests.test_224_01()
  let tx_hash = tests.test_224_02()

  let ref_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_100)
  let user_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_222)
  // Incorrect burn: amounts are not -1.
  let ref_value = add(zero, own_cs, ref_tkn, -2)
  let user_value = add(zero, own_cs, user_tkn, -1)
  let minted_value = merge(ref_value, user_value)
  validate_delete_account(own_cs, minted_value, ref_tkn)
}

// An update must preserve the correct reference and user tokens and the output 
// must be sent to the same account script address. If, for example,
// the output address is wrong, the update should be rejected.

test fail_update_account_wrong_output_address() fail {
  let own_cs = tests.test_224_01()
  let tx_hash = tests.test_224_02()
  let init_output_ref = tests.test_input_utxo_02(tx_hash)
  let account_output_ref = tests.test_input_utxo_02(tests.test_224_01())

  let datum =
    tests.test_datum_02(sha2_256("you@mail.com"), sha2_256("(717) 550-1675"))
  let new_datum =
    tests.test_datum_02(sha2_256("me@mail.com"), sha2_256("(717) 550-1675"))
  let ref_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_100)
  // Setup token values correctly...
  let ref_value = add(zero, own_cs, ref_tkn, 1)
  let user_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_222)
  let user_value = add(zero, own_cs, user_tkn, 1)
  let user_input =
    tests.test_context_input_02(init_output_ref, own_cs, user_value, NoDatum)
  let account_input =
    tests.test_context_input_02(account_output_ref, own_cs, ref_value, datum)
  // Force wrong output address: use a different credential (not Script(own_cs)).
  let wrong_address = tests.test_224_03()
  let user_output = tests.test_utxo_02(own_cs, user_value, 100_000_000, NoDatum)
  let script_output =
    tests.test_utxo_02(wrong_address, ref_value, 100_000_000, new_datum)
  let inputs = [user_input, account_input]
  let outputs = [user_output, script_output]
  validate_update_account(account_output_ref, ref_tkn, 0, 1, 1, inputs, outputs)
}

// If the updated datum does not have a valid email or phone hash 
// (length not equal to 32), then the update should be rejected.

test fail_update_account_invalid_metadata() fail {
  let own_cs = tests.test_224_01()
  let tx_hash = tests.test_224_02()
  let init_output_ref = tests.test_input_utxo_02(tx_hash)
  let account_output_ref = tests.test_input_utxo_02(tests.test_224_01())

  // Create datum with invalid email and phone hash lengths.
  let invalid_datum = tests.test_datum_02("you@mail.com", "(717) 550-1675")
  let new_datum = tests.test_datum_02("me@mail.com", "(717) 550-1675")

  let ref_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_100)
  let ref_value = add(zero, own_cs, ref_tkn, 1)
  let user_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_222)
  let user_value = add(zero, own_cs, user_tkn, 1)

  let user_input =
    tests.test_context_input_02(init_output_ref, own_cs, user_value, NoDatum)
  let account_input =
    tests.test_context_input_02(
      account_output_ref,
      own_cs,
      ref_value,
      invalid_datum,
    )
  let user_output = tests.test_utxo_02(own_cs, user_value, 100_000_000, NoDatum)
  let script_output =
    tests.test_utxo_02(own_cs, ref_value, 100_000_000, new_datum)
  let inputs = [user_input, account_input]
  let outputs = [user_output, script_output]
  validate_update_account(account_output_ref, ref_tkn, 0, 1, 1, inputs, outputs)
}

// For account removal, the minted value must “burn” the reference token 
// (amount –1). If it does not, then removal must be rejected.
test fail_remove_account_invalid_mint() fail {
  let own_cs = tests.test_224_01()
  let tx_hash = tests.test_224_02()
  let init_output_ref = tests.test_input_utxo_02(tx_hash)
  let account_output_ref = tests.test_input_utxo_02(tests.test_224_01())
  let datum = tests.test_datum_02("you@mail.com", "(717) 550-1675")
  let ref_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_100)
  let user_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_222)
  let ref_value = add(zero, own_cs, ref_tkn, 1)
  let user_value = add(zero, own_cs, user_tkn, 1)
  let mint_ref_value = add(zero, own_cs, ref_tkn, -2)
  // Incorrect burn amount
  let mint_user_value = add(zero, own_cs, user_tkn, -1)
  let minted_value = merge(mint_ref_value, mint_user_value)
  let user_input =
    tests.test_context_input_02(init_output_ref, own_cs, user_value, NoDatum)
  let account_input =
    tests.test_context_input_02(account_output_ref, own_cs, ref_value, datum)
  let inputs = [user_input, account_input]
  validate_remove_account(
    account_output_ref,
    ref_tkn,
    0,
    1,
    inputs,
    minted_value,
  )
}
