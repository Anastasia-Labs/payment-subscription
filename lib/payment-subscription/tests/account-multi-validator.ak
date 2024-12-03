// use aiken/cbor
use aiken/collection/dict
use aiken/interval
use cardano/assets.{zero}
use cardano/script_context.{Minting, ScriptContext, Spending}
use cardano/transaction.{NoDatum, Transaction}
use cardano/value
use payment_subscription/account_multi_validator/validation.{
  validate_create_account, validate_delete_account, validate_remove_account,
  validate_update_account,
}
use payment_subscription/common/types.{
  CreateAccount, DeleteAccount, RemoveAccount, UpdateAccount,
}
use payment_subscription/tests/tests
use types/cip68.{prefix_100, prefix_222}

test success_create_account() {
  let own_cs = tests.test_224_01()
  let tx_hash = tests.test_224_02()
  let init_output_ref = tests.test_input_utxo_02(tx_hash)
  let datum = tests.test_datum_02("you@mail.com", "(717) 550-1675", 1)

  let ref_tkn = value.unique_token_name(tx_hash, 1, prefix_100, "")
  let user_tkn = value.unique_token_name(tx_hash, 1, prefix_222, "")

  let ref_value = assets.add(zero, own_cs, ref_tkn, 1)
  let user_value = assets.add(zero, own_cs, user_tkn, 1)
  let minted_value = assets.merge(ref_value, user_value)

  let user_pubkey_hash = tests.test_224_03()
  let user_output =
    tests.test_utxo_02(user_pubkey_hash, user_value, 100_000_000, NoDatum)
  let script_output = tests.test_utxo_02(own_cs, ref_value, 100_000_000, datum)

  let user_input = tests.test_context_input_01(init_output_ref, own_cs, NoDatum)

  let context =
    ScriptContext {
      // purpose: Mint(own_cs),
      transaction: Transaction {
        inputs: [user_input],
        reference_inputs: [],
        // There should be two outputs.
        outputs: [user_output, script_output],
        fee: 0,
        mint: minted_value,
        certificates: [],
        withdrawals: [],
        validity_range: interval.everything,
        extra_signatories: [],
        redeemers: [],
        datums: dict.empty,
        id: tx_hash,
        votes: [],
        proposal_procedures: [],
        current_treasury_amount: None,
        treasury_donation: None,
      },
      redeemer: CreateAccount {
        output_reference: init_output_ref,
        input_index: 0,
      },
      // Added the missing 'redeemer' field
      info: Minting(own_cs),
    }

  validate_create_account(own_cs, init_output_ref, 0, context.transaction)
}

test succeed_delete_account() {
  let own_cs = tests.test_224_01()
  let tx_hash = tests.test_224_02()
  let init_output_ref = tests.test_input_utxo_02(tx_hash)
  let account_output_ref = tests.test_input_utxo_02(tests.test_224_01())

  let datum = tests.test_datum_02("you@mail.com", "(717) 550-1675", 1)

  let ref_tkn = value.unique_token_name(tx_hash, 1, cip68.prefix_100, "")
  let user_tkn = value.unique_token_name(tx_hash, 1, cip68.prefix_222, "")

  let ref_value = assets.add(zero, own_cs, ref_tkn, -1)
  let user_value = assets.add(zero, own_cs, user_tkn, -1)
  let minted_value = assets.merge(ref_value, user_value)

  let user_input =
    tests.test_context_input_02(init_output_ref, own_cs, user_value, NoDatum)
  let account_input =
    tests.test_context_input_02(account_output_ref, own_cs, ref_value, datum)

  let user_output = tests.test_utxo_02(own_cs, user_value, 100_000_000, datum)

  let context =
    ScriptContext {
      // purpose: Mint(own_cs),
      transaction: Transaction {
        // Should have two inputs
        inputs: [user_input, account_input],
        reference_inputs: [],
        // Should have one output
        outputs: [user_output],
        fee: 0,
        mint: minted_value,
        certificates: [],
        withdrawals: [],
        validity_range: interval.everything,
        extra_signatories: [],
        redeemers: [],
        datums: dict.empty,
        id: tx_hash,
        votes: [],
        proposal_procedures: [],
        current_treasury_amount: None,
        treasury_donation: None,
      },
      redeemer: DeleteAccount,
      // Added the missing 'redeemer' field
      info: Minting(own_cs),
    }
  validate_delete_account(context.transaction)
}

test succeed_update_account() {
  let own_cs = tests.test_224_01()
  let tx_hash = tests.test_224_02()
  let init_output_ref = tests.test_input_utxo_02(tx_hash)
  let account_output_ref = tests.test_input_utxo_02(tests.test_224_01())

  let datum = tests.test_datum_02("you@mail.com", "(717) 550-1675", 1)
  let new_datum = tests.test_datum_02("me@mail.com", "(717) 550-1675", 1)

  let ref_tkn = value.unique_token_name(tx_hash, 1, cip68.prefix_100, "")
  let user_tkn = value.unique_token_name(tx_hash, 1, cip68.prefix_222, "")

  let ref_value = assets.add(zero, own_cs, ref_tkn, 1)
  let user_value = assets.add(zero, own_cs, user_tkn, 1)
  let minted_value = assets.merge(ref_value, user_value)

  let user_input =
    tests.test_context_input_02(init_output_ref, own_cs, user_value, NoDatum)
  let account_input =
    tests.test_context_input_02(account_output_ref, own_cs, ref_value, datum)

  let user_output = tests.test_utxo_02(own_cs, user_value, 100_000_000, NoDatum)
  let script_output =
    tests.test_utxo_02(own_cs, ref_value, 100_000_000, new_datum)

  let as_data: Data = datum
  let context =
    ScriptContext {
      // purpose: Spend(account_output_ref),
      transaction: Transaction {
        inputs: [user_input, account_input],
        // Should have two inputs.
        reference_inputs: [],
        outputs: [user_output, script_output],
        fee: 0,
        mint: minted_value,
        certificates: [],
        withdrawals: [],
        validity_range: interval.everything,
        extra_signatories: [],
        redeemers: [],
        datums: dict.empty,
        id: tx_hash,
        votes: [],
        proposal_procedures: [],
        current_treasury_amount: None,
        treasury_donation: None,
      },
      redeemer: UpdateAccount {
        subscriber_input_index: 0,
        account_input_index: 0,
      },
      // Added the missing 'redeemer' field
      info: Spending(account_output_ref, Some(as_data)),
    }

  validate_update_account(0, 1, context.transaction)
}

test succeed_remove_account() {
  let own_cs = tests.test_224_01()
  let tx_hash = tests.test_224_02()
  let init_output_ref = tests.test_input_utxo_02(tx_hash)
  let account_output_ref = tests.test_input_utxo_02(tests.test_224_01())

  let datum = tests.test_datum_02("you@mail.com", "(717) 550-1675", 1)

  //   let redeemer = RemoveAccount
  let ref_tkn = value.unique_token_name(tx_hash, 1, cip68.prefix_100, "")
  let user_tkn = value.unique_token_name(tx_hash, 1, cip68.prefix_222, "")

  let ref_value = assets.add(zero, own_cs, ref_tkn, 1)
  let user_value = assets.add(zero, own_cs, user_tkn, 1)

  let mint_ref_value = assets.add(zero, own_cs, ref_tkn, -1)
  let mint_user_value = assets.add(zero, own_cs, user_tkn, -1)
  let minted_value = assets.merge(mint_ref_value, mint_user_value)

  let user_input =
    tests.test_context_input_02(init_output_ref, own_cs, user_value, NoDatum)
  let account_input =
    tests.test_context_input_02(account_output_ref, own_cs, ref_value, datum)

  let user_output =
    tests.test_utxo_02(own_cs, mint_user_value, 100_000_000, NoDatum)
  let as_data: Data = datum

  let context =
    ScriptContext {
      // purpose: Spend(account_output_ref),
      transaction: Transaction {
        inputs: [user_input, account_input],
        // Should have two inputs.
        reference_inputs: [],
        outputs: [user_output],
        fee: 0,
        mint: minted_value,
        certificates: [],
        withdrawals: [],
        validity_range: interval.everything,
        extra_signatories: [],
        redeemers: [],
        datums: dict.empty,
        id: tx_hash,
        votes: [],
        proposal_procedures: [],
        current_treasury_amount: None,
        treasury_donation: None,
      },
      redeemer: RemoveAccount {
        subscriber_input_index: 0,
        account_input_index: 0,
      },
      // Added the missing 'redeemer' field
      info: Spending(account_output_ref, Some(as_data)),
    }

  validate_remove_account(0, 1, context.transaction)
}
