use aiken/cbor
use aiken/dict
use aiken/interval
use aiken/transaction.{
  Mint, NoDatum, ScriptContext, Spend, Transaction, TransactionId,
}
use aiken/transaction/value.{from_minted_value}
use assist/types/cip68
use assist/values
use payment_subscription/account_multi_validator/validation.{
  validate_create_account, validate_delete_account, validate_remove_account,
  validate_update_account,
}
use payment_subscription/tests/tests

test succeed_create_account() {
  let own_cs = tests.test_224_01()
  let tx_hash = tests.test_224_02()
  let init_output_ref = tests.test_input_utxo_02(tx_hash)
  let datum = tests.test_datum_02("you@mail.com", "(717) 550-1675", 1)

  let ref_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_100)
  let user_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_222)

  let ref_value = value.add(value.zero(), own_cs, ref_tkn, 1)
  let user_value = value.add(value.zero(), own_cs, user_tkn, 1)
  let minted_value = value.merge(ref_value, user_value)

  let user_pubkey_hash = tests.test_224_03()
  let user_output =
    tests.test_utxo_02(user_pubkey_hash, user_value, 100_000_000, NoDatum)
  let script_output = tests.test_utxo_02(own_cs, ref_value, 100_000_000, datum)

  let user_input = tests.test_context_input_01(init_output_ref, own_cs, NoDatum)

  let context =
    ScriptContext {
      purpose: Mint(own_cs),
      transaction: Transaction {
        inputs: [user_input],
        reference_inputs: [],
        // There should be two outputs.
        outputs: [user_output, script_output],
        fee: value.zero(),
        mint: value.to_minted_value(minted_value),
        certificates: [],
        withdrawals: [],
        validity_range: interval.everything(),
        extra_signatories: [],
        redeemers: [],
        datums: dict.new(),
        id: TransactionId { hash: tx_hash },
      },
    }

  trace @"Test: Creating a New Account"
  trace @"-------------------------------------"

  trace @"Step 1: Account Details"
  trace @"-------------------------------------"
  trace @"Email:"
  trace cbor.diagnostic(datum.email)
  trace @"Phone:"
  trace cbor.diagnostic(datum.phone)

  trace @"Step 2: Minting Account Tokens"
  trace @"-------------------------------------"
  trace @"Reference Token:"
  trace cbor.diagnostic(ref_tkn)
  trace @"User Token:"
  trace cbor.diagnostic(user_tkn)

  trace @"Step 3: Preparing Outputs"
  trace @"-------------------------------------"
  trace @"User Output:"
  trace cbor.diagnostic(user_output)
  trace @"Script Output:"
  trace cbor.diagnostic(script_output)

  trace @"Step 4: Validating Transaction"
  trace @"-------------------------------------"
  trace @"Transaction Inputs:"
  trace cbor.diagnostic(context.transaction.inputs)
  trace @"Transaction Outputs:"
  trace cbor.diagnostic(context.transaction.outputs)
  trace @"Minted Tokens:"
  trace cbor.diagnostic(context.transaction.mint)

  trace @"Step 5: Execution Result"
  trace @"-------------------------------------"
  trace @"Account Successfully Created!"
  trace @"-------------------------------------"
  trace @"Test Completed!"

  //   mint_account(redeemer, context)
  let minted_tokens = context.transaction.mint |> from_minted_value()

  validate_create_account(
    own_cs,
    user_input,
    minted_tokens,
    init_output_ref,
    context.transaction.outputs,
  )
}

test succeed_delete_account() {
  let own_cs = tests.test_224_01()
  let tx_hash = tests.test_224_02()
  let init_output_ref = tests.test_input_utxo_02(tx_hash)
  let account_output_ref = tests.test_input_utxo_02(tests.test_224_01())

  let datum = tests.test_datum_02("you@mail.com", "(717) 550-1675", 1)

  //   let redeemer = DeleteAccount
  let ref_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_100)
  let user_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_222)

  //   let ref_value = value.from_asset(own_cs, ref_tkn, 1)
  let ref_value = value.add(value.zero(), own_cs, ref_tkn, -1)
  let user_value = value.add(value.zero(), own_cs, user_tkn, -1)
  let minted_value = value.merge(ref_value, user_value)

  let user_input =
    tests.test_context_input_02(init_output_ref, own_cs, user_value, NoDatum)
  let account_input =
    tests.test_context_input_02(account_output_ref, own_cs, ref_value, datum)

  let user_output = tests.test_utxo_02(own_cs, user_value, 100_000_000, datum)

  let context =
    ScriptContext {
      purpose: Mint(own_cs),
      transaction: Transaction {
        // Should have two inputs
        inputs: [user_input, account_input],
        reference_inputs: [],
        // Should have one output
        outputs: [user_output],
        fee: value.zero(),
        mint: value.to_minted_value(minted_value),
        certificates: [],
        withdrawals: [],
        validity_range: interval.everything(),
        extra_signatories: [],
        redeemers: [],
        datums: dict.new(),
        id: TransactionId { hash: tx_hash },
      },
    }

  trace @"Test: Deleting an Existing Account"
  trace @"-------------------------------------"

  trace @"Step 1: Account Details"
  trace @"-------------------------------------"
  trace @"Email:"
  trace cbor.diagnostic(datum.email)
  trace @"Phone:"
  trace cbor.diagnostic(datum.phone)

  trace @"Step 2: Burning Account Tokens"
  trace @"-------------------------------------"
  trace @"Reference Token to Burn:"
  trace cbor.diagnostic(ref_tkn)
  trace @"User Token to Burn:"
  trace cbor.diagnostic(user_tkn)

  trace @"Step 3: Preparing Inputs"
  trace @"-------------------------------------"
  trace @"User Input:"
  trace cbor.diagnostic(user_input)
  trace @"Account Input:"
  trace cbor.diagnostic(account_input)

  trace @"Step 4: Validating Transaction"
  trace @"-------------------------------------"
  trace @"Transaction Inputs:"
  trace cbor.diagnostic(context.transaction.inputs)
  trace @"Transaction Outputs:"
  trace cbor.diagnostic(context.transaction.outputs)
  trace @"Burned Tokens:"
  trace cbor.diagnostic(context.transaction.mint)

  trace @"Step 5: Execution Result"
  trace @"-------------------------------------"
  trace @"Account Successfully Deleted!"
  trace @"-------------------------------------"
  trace @"Test Completed!"

  //   mint_account(redeemer, context)
  let minted_tokens = context.transaction.mint |> from_minted_value()

  validate_delete_account(minted_tokens)
}

test succeed_update_account() {
  let own_cs = tests.test_224_01()
  let tx_hash = tests.test_224_02()
  let init_output_ref = tests.test_input_utxo_02(tx_hash)
  let account_output_ref = tests.test_input_utxo_02(tests.test_224_01())

  let datum = tests.test_datum_02("you@mail.com", "(717) 550-1675", 1)
  let new_datum = tests.test_datum_02("me@mail.com", "(717) 550-1675", 1)

  //   let redeemer = UpdateAccount
  let ref_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_100)
  let user_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_222)

  let ref_value = value.add(value.zero(), own_cs, ref_tkn, 1)
  let user_value = value.add(value.zero(), own_cs, user_tkn, 1)
  let minted_value = value.merge(ref_value, user_value)

  let user_input =
    tests.test_context_input_02(init_output_ref, own_cs, user_value, NoDatum)
  let account_input =
    tests.test_context_input_02(account_output_ref, own_cs, ref_value, datum)

  let user_output = tests.test_utxo_02(own_cs, user_value, 100_000_000, NoDatum)
  let script_output =
    tests.test_utxo_02(own_cs, ref_value, 100_000_000, new_datum)

  let context =
    ScriptContext {
      purpose: Spend(account_output_ref),
      transaction: Transaction {
        inputs: [user_input, account_input],
        // Should have two inputs.
        reference_inputs: [],
        outputs: [user_output, script_output],
        fee: value.zero(),
        mint: value.to_minted_value(minted_value),
        certificates: [],
        withdrawals: [],
        validity_range: interval.everything(),
        extra_signatories: [],
        redeemers: [],
        datums: dict.new(),
        id: TransactionId { hash: tx_hash },
      },
    }

  trace @"Test: Updating an Existing Account"
  trace @"-------------------------------------"

  trace @"Step 1: Current Account Details"
  trace @"-------------------------------------"
  trace @"Current Email:"
  trace cbor.diagnostic(datum.email)
  trace @"Current Phone:"
  trace cbor.diagnostic(datum.phone)

  trace @"Step 2: Updated Account Details"
  trace @"-------------------------------------"
  trace @"New Email:"
  trace cbor.diagnostic(new_datum.email)
  trace @"New Phone:"
  trace cbor.diagnostic(new_datum.phone)

  trace @"Step 3: Preparing Inputs and Outputs"
  trace @"-------------------------------------"
  trace @"User Input:"
  trace cbor.diagnostic(user_input)
  trace @"Account Input:"
  trace cbor.diagnostic(account_input)
  trace @"User Output:"
  trace cbor.diagnostic(user_output)
  trace @"Script Output:"
  trace cbor.diagnostic(script_output)

  trace @"Step 4: Validating Transaction"
  trace @"-------------------------------------"
  trace @"Transaction Inputs:"
  trace cbor.diagnostic(context.transaction.inputs)
  trace @"Transaction Outputs:"
  trace cbor.diagnostic(context.transaction.outputs)

  trace @"Step 5: Execution Result"
  trace @"-------------------------------------"
  trace @"Account Successfully Updated!"
  trace @"-------------------------------------"
  trace @"Test Completed!"

  //   spend_account(datum, redeemer, context)
  let account_addr = account_input.output.address
  let ref_nft =
    account_input.output.value
      |> value.without_lovelace()
  validate_update_account(account_addr, ref_nft, context.transaction)
}

test success_remove_account() {
  let own_cs = tests.test_224_01()
  let tx_hash = tests.test_224_02()
  let init_output_ref = tests.test_input_utxo_02(tx_hash)
  let account_output_ref = tests.test_input_utxo_02(tests.test_224_01())

  let datum = tests.test_datum_02("you@mail.com", "(717) 550-1675", 1)

  //   let redeemer = RemoveAccount
  let ref_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_100)
  let user_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_222)

  let ref_value = value.add(value.zero(), own_cs, ref_tkn, 1)
  let user_value = value.add(value.zero(), own_cs, user_tkn, 1)

  let mint_ref_value = value.add(value.zero(), own_cs, ref_tkn, -1)
  let mint_user_value = value.add(value.zero(), own_cs, user_tkn, -1)
  let minted_value = value.merge(mint_ref_value, mint_user_value)

  let user_input =
    tests.test_context_input_02(init_output_ref, own_cs, user_value, NoDatum)
  let account_input =
    tests.test_context_input_02(account_output_ref, own_cs, ref_value, datum)

  let user_output =
    tests.test_utxo_02(own_cs, mint_user_value, 100_000_000, NoDatum)

  let context =
    ScriptContext {
      purpose: Spend(account_output_ref),
      transaction: Transaction {
        inputs: [user_input, account_input],
        // Should have two inputs.
        reference_inputs: [],
        outputs: [user_output],
        fee: value.zero(),
        mint: value.to_minted_value(minted_value),
        certificates: [],
        withdrawals: [],
        validity_range: interval.everything(),
        extra_signatories: [],
        redeemers: [],
        datums: dict.new(),
        id: TransactionId { hash: tx_hash },
      },
    }

  trace @"Test: Removing an Existing Account"
  trace @"-------------------------------------"

  trace @"Step 1: Account Details"
  trace @"-------------------------------------"
  trace @"Email:"
  trace cbor.diagnostic(datum.email)
  trace @"Phone:"
  trace cbor.diagnostic(datum.phone)

  trace @"Step 2: Tokens to Remove"
  trace @"-------------------------------------"
  trace @"Reference Token:"
  trace cbor.diagnostic(ref_tkn)
  trace @"User Token:"
  trace cbor.diagnostic(user_tkn)

  trace @"Step 3: Preparing Inputs and Outputs"
  trace @"-------------------------------------"
  trace @"User Input:"
  trace cbor.diagnostic(user_input)
  trace @"Account Input:"
  trace cbor.diagnostic(account_input)
  trace @"User Output:"
  trace cbor.diagnostic(user_output)

  trace @"Step 4: Validating Transaction"
  trace @"-------------------------------------"
  trace @"Transaction Inputs:"
  trace cbor.diagnostic(context.transaction.inputs)
  trace @"Transaction Outputs:"
  trace cbor.diagnostic(context.transaction.outputs)
  trace @"Burned Tokens:"
  trace cbor.diagnostic(context.transaction.mint)

  trace @"Step 5: Execution Result"
  trace @"-------------------------------------"
  trace @"Account Successfully Removed!"
  trace @"-------------------------------------"
  trace @"Test Completed!"

  let account_addr = account_input.output.address
  let ref_nft =
    account_input.output.value
      |> value.without_lovelace()
  validate_remove_account(account_addr, ref_nft, context.transaction)
}
