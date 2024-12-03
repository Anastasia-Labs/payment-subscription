// use aiken/cbor
use aiken/collection/dict
use aiken/interval
use cardano/assets.{zero}
use cardano/script_context.{Minting, ScriptContext, Spending}
use cardano/transaction.{NoDatum, Transaction}
use cardano/value
use payment_subscription/common/types.{
  CreateService, RemoveService, UpdateService,
}
use payment_subscription/service_multi_validator/validation.{
  validate_create_service, validate_remove_service, validate_update_service,
}
use payment_subscription/tests/tests
use types/cip68.{prefix_100, prefix_222}

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

  let ref_tkn = value.unique_token_name(tx_hash, 1, prefix_100, "")
  let user_tkn = value.unique_token_name(tx_hash, 1, prefix_222, "")

  let ref_value = assets.add(zero, own_cs, ref_tkn, 1)
  let user_value = assets.add(zero, own_cs, user_tkn, 1)
  let minted_value = assets.merge(ref_value, user_value)

  let user_pubkey_hash = tests.test_224_03()
  let user_output = tests.test_user_utxo(user_pubkey_hash, user_value, NoDatum)
  let service_output = tests.test_utxo_02(own_cs, ref_value, 100_000_000, datum)

  let user_input = tests.test_context_input_01(init_output_ref, own_cs, NoDatum)

  let context =
    ScriptContext {
      // purpose: Mint(own_cs),
      transaction: Transaction {
        inputs: [user_input],
        reference_inputs: [],
        // There should be two outputs.
        outputs: [user_output, service_output],
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
      redeemer: CreateService {
        output_reference: init_output_ref,
        input_index: 0,
      },
      // Added the missing 'redeemer' field
      info: Minting(own_cs),
    }

  // |> from_minted_value()
  validate_create_service(own_cs, init_output_ref, 0, context.transaction)
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

  let ref_tkn = value.unique_token_name(tx_hash, 1, prefix_100, "")
  let user_tkn = value.unique_token_name(tx_hash, 1, prefix_222, "")

  let ref_value = assets.add(zero, own_cs, ref_tkn, 1)
  let user_value = assets.add(zero, own_cs, user_tkn, 1)
  let minted_value = assets.merge(ref_value, user_value)

  let user_input =
    tests.test_context_input_02(init_output_ref, own_cs, user_value, NoDatum)
  let service_input =
    tests.test_context_input_02(script_output_ref, own_cs, ref_value, datum)

  let user_output = tests.test_utxo_02(own_cs, user_value, 100_000_000, NoDatum)
  let service_output =
    tests.test_utxo_02(own_cs, ref_value, 100_000_000, new_datum)

  let as_data: Data = datum
  let context =
    ScriptContext {
      transaction: Transaction {
        inputs: [user_input, service_input],
        // Should have two inputs.
        reference_inputs: [],
        outputs: [user_output, service_output],
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
      redeemer: UpdateService {
        merchant_input_index: 0,
        service_input_index: 0,
      },
      // Added the missing 'redeemer' field
      info: Spending(script_output_ref, Some(as_data)),
    }

  validate_update_service(Some(datum), 0, 1, context.transaction)
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

  let ref_tkn = value.unique_token_name(tx_hash, 1, prefix_100, "")
  let user_tkn = value.unique_token_name(tx_hash, 1, prefix_222, "")

  let ref_value = assets.add(zero, own_cs, ref_tkn, 1)
  let user_value = assets.add(zero, own_cs, user_tkn, 1)

  let minted_value = assets.merge(ref_value, user_value)

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
  let as_data: Data = datum

  let context =
    ScriptContext {
      transaction: Transaction {
        inputs: [user_input, service_input],
        // Should have two inputs.
        reference_inputs: [],
        outputs: [user_output, service_output],
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
      redeemer: RemoveService {
        merchant_input_index: 0,
        service_input_index: 0,
      },
      // Added the missing 'redeemer' field
      info: Spending(script_output_ref, Some(as_data)),
    }

  validate_remove_service(Some(datum), 0, 1, context.transaction)
}
