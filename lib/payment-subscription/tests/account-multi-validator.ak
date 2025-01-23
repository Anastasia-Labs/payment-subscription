// use aiken/cbor
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

test success_create_account() {
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
  let minted_tokens = context.transaction.mint |> from_minted_value()

  validate_delete_account(own_cs, minted_tokens)
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

  validate_update_account(account_output_ref, 0, 1, context.transaction)
}

test succeed_remove_account() {
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

  validate_remove_account(account_output_ref, 0, 1, context.transaction)
}
