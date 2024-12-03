// use aiken/cbor
use aiken/collection/dict
use aiken/interval.{Finite, Interval, IntervalBound}
use cardano/assets.{zero}
use cardano/script_context.{Minting, ScriptContext, Spending}
use cardano/transaction.{NoDatum, Transaction}
use cardano/value
use payment_subscription/common/types.{
  AssetClass, InitSubscripton, Payment, PaymentDatum, Penalty, PenaltyDatum,
}
use payment_subscription/payment_multi_validator/validation.{
  validate_extend_subscription, validate_initial_subscription,
  validate_merchant_withdraw, validate_subscriber_withdraw,
  validate_terminate_subscription, validate_unsubscribe,
}
use payment_subscription/tests/tests
use types/cip68.{prefix_100, prefix_222}

// Happy path tests
test succeed_initiate_subscription() {
  let own_cs = tests.test_payment_cs()
  let account_cs = tests.test_account_cs()
  let service_cs = tests.test_service_cs()

  let tx_hash = tests.test_224_01()
  let account_tx_hash = tests.test_224_02()
  let service_tx_hash = tests.test_224_03()

  let init_output_ref = tests.test_input_utxo_02(tx_hash)
  let input_index = 0

  let payment_tkn = value.unique_token_name(tx_hash, 1, #"", "")
  let service_tkn = value.unique_token_name(service_tx_hash, 1, prefix_100, "")
  let user_account_tkn =
    value.unique_token_name(account_tx_hash, 1, prefix_222, "")

  let current_time = 1000000
  let last_claimed = 500000
  // 30 days in milliseconds
  let interval_length = 30 * 24 * 60 * 60 * 1000
  let interval_amount = 100_000_000
  let num_intervals = 10

  let penalty_qty = 1_000_000
  // 30 days in milliseconds
  let is_active = True
  let service_datum =
    tests.test_service_datum(
      is_active,
      interval_length,
      num_intervals,
      interval_amount,
    )

  let total_subscription_fee = 1_000_000_000
  let subscription_end = current_time + interval_length * num_intervals

  let payment_datum =
    tests.test_datum_03(
      service_tkn,
      user_account_tkn,
      total_subscription_fee,
      current_time,
      subscription_end,
      interval_length,
      interval_amount,
      num_intervals,
      last_claimed,
      penalty_qty,
    )

  let payment_value = assets.add(zero, own_cs, payment_tkn, 1)
  let service_value = assets.add(zero, service_cs, service_tkn, 1)
  let account_value = assets.add(zero, account_cs, user_account_tkn, 1)

  let service_input =
    tests.test_context_input_02(
      init_output_ref,
      service_cs,
      service_value,
      service_datum,
    )
  let account_input =
    tests.test_context_input_02(
      init_output_ref,
      account_cs,
      account_value,
      NoDatum,
    )

  let user_pubkey_hash = tests.test_224_03()
  let user_output =
    tests.test_utxo_02(
      user_pubkey_hash,
      account_value,
      interval_amount,
      NoDatum,
    )
  let payment_output =
    tests.test_utxo_02(
      own_cs,
      payment_value,
      interval_amount,
      Some(Payment(payment_datum)),
    )

  let insert_timerange =
    Interval {
      lower_bound: IntervalBound {
        bound_type: Finite(current_time),
        is_inclusive: True,
      },
      upper_bound: IntervalBound {
        bound_type: Finite(current_time + 1),
        is_inclusive: False,
      },
    }
  let context =
    ScriptContext {
      transaction: Transaction {
        inputs: [account_input, service_input],
        // Normally used to read Datum
        reference_inputs: [service_input],
        // There should be two outputs.
        outputs: [user_output, payment_output],
        fee: 0,
        mint: payment_value,
        certificates: [],
        withdrawals: [],
        validity_range: insert_timerange,
        extra_signatories: [],
        redeemers: [],
        datums: dict.empty,
        id: tx_hash,
        votes: [],
        proposal_procedures: [],
        current_treasury_amount: None,
        treasury_donation: None,
      },
      redeemer: InitSubscripton {
        output_reference: init_output_ref,
        input_index: 0,
      },
      // Added the missing 'redeemer' field
      info: Minting(own_cs),
    }

  validate_initial_subscription(
    own_cs,
    service_cs,
    account_cs,
    init_output_ref,
    input_index,
    context.transaction,
  )
}

test succeed_terminate_subscription() {
  let own_cs = tests.test_payment_cs()
  let account_cs = tests.test_account_cs()
  let service_cs = tests.test_service_cs()

  let tx_hash = tests.test_224_01()
  let payment_tx_hash = tests.test_224_02()
  let service_tx_hash = tests.test_224_03()

  let init_output_ref = tests.test_input_utxo_02(tx_hash)
  let script_output_ref = tests.test_input_utxo_02(payment_tx_hash)

  let current_time = 1000000
  // 30 days in milliseconds
  let interval_length = 30 * 24 * 60 * 60 * 1000

  let user_account_tkn = value.unique_token_name(tx_hash, 1, prefix_222, "")
  let user_service_tkn = value.unique_token_name(service_cs, 1, prefix_222, "")
  let payment_tkn = value.unique_token_name(payment_tx_hash, 1, #"", "")
  let service_tkn = value.unique_token_name(service_tx_hash, 1, prefix_100, "")

  let service_value = assets.add(zero, service_cs, user_service_tkn, 1)

  // Create the payment input (the one being spent)
  let merchant_input =
    tests.test_context_input_02(init_output_ref, own_cs, service_value, NoDatum)

  // Calculate refund amount (assuming half of the subscription period has passed)
  let time_elapsed = interval_length / 2

  // Create penalty output
  let penalty_fee_qty = 1_000_000
  let penalty_datum =
    PenaltyDatum {
      service_nft_tn: service_tkn,
      account_nft_tn: user_account_tkn,
      penalty_fee: AssetClass {
        policy_id: assets.ada_policy_id,
        asset_name: assets.ada_asset_name,
      },
      penalty_fee_qty,
    }
  let penalty_value =
    assets.add(assets.from_lovelace(penalty_fee_qty), own_cs, payment_tkn, 1)

  let merchant_output =
    tests.test_utxo_02(service_cs, zero, penalty_fee_qty, NoDatum)

  let penalty_input =
    tests.test_context_input_02(
      script_output_ref,
      own_cs,
      penalty_value,
      penalty_datum,
    )

  let insert_timerange =
    Interval {
      lower_bound: IntervalBound {
        bound_type: Finite(current_time + time_elapsed),
        is_inclusive: True,
      },
      upper_bound: IntervalBound {
        bound_type: Finite(current_time + time_elapsed + 1),
        is_inclusive: False,
      },
    }
  // Create the transaction
  let context =
    ScriptContext {
      transaction: Transaction {
        inputs: [merchant_input, penalty_input],
        reference_inputs: [],
        outputs: [merchant_output],
        fee: 0,
        mint: assets.add(zero, own_cs, payment_tkn, -1),
        certificates: [],
        withdrawals: [],
        validity_range: insert_timerange,
        extra_signatories: [],
        redeemers: [],
        datums: dict.empty,
        id: tx_hash,
        votes: [],
        proposal_procedures: [],
        current_treasury_amount: None,
        treasury_donation: None,
      },
      redeemer: InitSubscripton {
        output_reference: init_output_ref,
        input_index: 0,
      },
      // Added the missing 'redeemer' field
      info: Minting(own_cs),
    }

  validate_terminate_subscription(own_cs, account_cs, 0, 1, context.transaction)
}

test succeed_extend_subscription() {
  let own_cs = tests.test_payment_cs()
  let account_cs = tests.test_account_cs()
  let service_cs = tests.test_service_cs()

  let tx_hash = tests.test_224_01()
  let payment_tx_hash = tests.test_224_02()
  let service_tx_hash = tests.test_224_03()

  let extend_output_ref = tests.test_input_utxo_02(payment_tx_hash)

  let payment_tkn = value.unique_token_name(payment_tx_hash, 1, #"", "")
  let service_tkn = value.unique_token_name(service_tx_hash, 1, prefix_100, "")
  let user_account_tkn = value.unique_token_name(tx_hash, 1, prefix_222, "")

  let service_value = assets.add(zero, service_cs, service_tkn, 1)
  let user_value = assets.add(zero, account_cs, user_account_tkn, 1)

  let current_time = 1000000
  let last_claimed = 500000
  // 30 days in milliseconds
  let interval_amount = 10_000_000
  let num_intervals = 1
  let interval_length = 30 * 24 * 60 * 60 * 1000
  let total_subscription_fee = interval_amount * num_intervals
  let penalty_fee_qty = 1_000_000

  // Create the initial payment datum
  let initial_payment_datum =
    tests.test_datum_03(
      service_tkn,
      user_account_tkn,
      total_subscription_fee,
      current_time,
      current_time + interval_length,
      interval_length,
      interval_amount,
      num_intervals,
      last_claimed,
      penalty_fee_qty,
    )
  // Create the payment input (the one being spent)
  let initial_payment_value =
    assets.add(
      assets.from_lovelace(total_subscription_fee),
      own_cs,
      payment_tkn,
      1,
    )
  let payment_input =
    tests.test_context_input_02(
      extend_output_ref,
      own_cs,
      initial_payment_value,
      Payment(initial_payment_datum),
    )

  // Define extension parameters
  // 30 more days
  let extension_period = interval_length
  let extension_intervals = 1
  let extension_fee = interval_amount * extension_intervals

  // Same as initial fee for simplicity
  // Create the new payment datum with extended period and increased fee
  let new_payment_datum: PaymentDatum =
    tests.test_datum_03(
      service_tkn,
      user_account_tkn,
      total_subscription_fee + extension_fee,
      current_time,
      initial_payment_datum.subscription_end + extension_period,
      interval_length,
      interval_amount,
      num_intervals + extension_intervals,
      last_claimed,
      penalty_fee_qty,
    )

  // Create the new payment output
  let new_payment_value =
    assets.add(
      assets.from_lovelace(total_subscription_fee + extension_fee),
      own_cs,
      payment_tkn,
      1,
    )
  let payment_output =
    tests.test_utxo_02(
      own_cs,
      new_payment_value,
      100_000_000,
      Payment(new_payment_datum),
    )
  // Create a mock subscriber input (to pay for the extension)
  let subscriber_pkh = tests.test_224_04()
  // Assuming this function exists to generate a different hash
  let subscriber_input =
    tests.test_context_input_02(
      tests.test_input_utxo_02(tx_hash),
      account_cs,
      user_value,
      // Extra for fees
      NoDatum,
    )
  // Create the service datum and input
  let is_active = True
  let service_datum =
    tests.test_service_datum(
      is_active,
      interval_length,
      num_intervals,
      interval_amount,
    )
  let service_input =
    tests.test_context_input_02(
      tests.test_input_utxo_02(service_cs),
      service_cs,
      service_value,
      service_datum,
    )

  let insert_timerange =
    Interval {
      lower_bound: IntervalBound {
        bound_type: Finite(current_time),
        is_inclusive: True,
      },
      upper_bound: IntervalBound {
        bound_type: Finite(current_time + 1),
        is_inclusive: False,
      },
    }
  // Create a user output for change
  let change_amount = 3_000_000
  // Assuming 2_000_000 for fees
  let user_change_output =
    tests.test_user_utxo(
      subscriber_pkh,
      assets.from_lovelace(change_amount),
      NoDatum,
    )

  let as_data: Data = Payment(initial_payment_datum)

  // Create the transaction
  let context =
    ScriptContext {
      transaction: Transaction {
        inputs: [subscriber_input, payment_input],
        reference_inputs: [service_input],
        outputs: [user_change_output, payment_output],
        fee: 0,
        mint: zero,
        certificates: [],
        withdrawals: [],
        validity_range: insert_timerange,
        extra_signatories: [],
        redeemers: [],
        datums: dict.empty,
        id: tx_hash,
        votes: [],
        proposal_procedures: [],
        current_treasury_amount: None,
        treasury_donation: None,
      },
      redeemer: InitSubscripton {
        output_reference: extend_output_ref,
        input_index: 0,
      },
      // Added the missing 'redeemer' field
      info: Spending(extend_output_ref, Some(as_data)),
    }

  validate_extend_subscription(
    service_cs,
    account_cs,
    Some(Payment(initial_payment_datum)),
    0,
    1,
    context.transaction,
  )
}

test succeed_merchant_withdraw() {
  let own_cs = tests.test_payment_cs()
  let service_cs = tests.test_service_cs()

  let tx_hash = tests.test_224_01()
  let payment_tx_hash = tests.test_224_02()
  let service_tx_hash = tests.test_224_03()

  let script_output_ref = tests.test_input_utxo_02(payment_tx_hash)

  let payment_tkn = value.unique_token_name(payment_tx_hash, 1, #"", "")
  let service_tkn = value.unique_token_name(service_tx_hash, 1, prefix_100, "")
  let service_user_tkn =
    value.unique_token_name(service_tx_hash, 1, prefix_222, "")
  let user_account_tkn = value.unique_token_name(tx_hash, 1, prefix_222, "")

  let subscription_start = 1000000
  // 30 days in milliseconds
  let interval_length = 30 * 24 * 60 * 60 * 1000
  // 120 days total
  let num_intervals = 1
  let subscription_end = subscription_start + interval_length * num_intervals
  let total_subscription_fee = 1_000_000_000
  let penalty_fee_qty = 1_000_000
  let last_claimed = subscription_start
  // Set current time to exactly 2 vesting periods (60 days) after start
  let current_time = subscription_start + 2 * interval_length
  let interval_amount = 100_000_000

  // Half-way through
  let payment_datum =
    tests.test_datum_03(
      service_tkn,
      user_account_tkn,
      total_subscription_fee,
      subscription_start,
      subscription_end,
      interval_length,
      interval_amount,
      num_intervals,
      last_claimed,
      penalty_fee_qty,
    )

  let is_active = True
  let service_datum =
    tests.test_service_datum(
      is_active,
      interval_length,
      num_intervals,
      interval_amount,
    )

  let payment_value =
    assets.add(
      assets.from_lovelace(total_subscription_fee),
      own_cs,
      payment_tkn,
      1,
    )
  let service_value =
    assets.add(
      assets.from_lovelace(total_subscription_fee),
      service_cs,
      service_tkn,
      1,
    )

  let merchant_value =
    assets.add(
      assets.from_lovelace(total_subscription_fee),
      service_cs,
      service_user_tkn,
      1,
    )

  // Create the merchant input (to prove service ownership)
  let merchant_input =
    tests.test_context_input_02(
      tests.test_input_utxo_02(service_tx_hash),
      service_cs,
      merchant_value,
      NoDatum,
    )
  // Create the payment input (the one being spent)
  let payment_input =
    tests.test_context_input_02(
      script_output_ref,
      own_cs,
      payment_value,
      Some(Payment(payment_datum)),
    )

  // Create the service input (to prove service ownership)
  let service_input =
    tests.test_context_input_02(
      tests.test_input_utxo_02(service_tx_hash),
      service_cs,
      service_value,
      service_datum,
    )

  // Calculate withdrawable amount using stepped vesting
  let withdrawable_amount = 2 * interval_amount
  let minimum_ada = 2_000_000

  // Calculate withdrawable amount (assuming half of the subscription period has passed)
  let actual_withdrawal = withdrawable_amount
  let merchant_output_value =
    assets.add(
      assets.from_lovelace(actual_withdrawal + minimum_ada),
      service_cs,
      service_user_tkn,
      1,
    )

  // Create withdrawal output
  let merchant_output =
    tests.test_utxo_exact(service_cs, merchant_output_value, NoDatum)

  // Create remaining funds output (if any)
  let remaining_amount = total_subscription_fee - actual_withdrawal
  let payment_output_value =
    assets.add(assets.from_lovelace(remaining_amount), own_cs, payment_tkn, 1)

  let interval_amount = 100_000_000
  let num_intervals = 1

  let new_payment_datum =
    tests.test_datum_03(
      service_tkn,
      user_account_tkn,
      remaining_amount,
      subscription_start,
      subscription_end,
      interval_length,
      interval_amount,
      num_intervals,
      current_time,
      penalty_fee_qty,
    )

  let payment_output =
    tests.test_utxo_02(
      own_cs,
      payment_output_value,
      100_000_000,
      Payment(new_payment_datum),
    )

  let lower_bound = current_time
  let upper_bound = lower_bound + 1

  let insert_timerange = tests.test_time_range(lower_bound, upper_bound)

  // Create the transaction
  let context =
    tests.test_spend_script_context(
      script_output_ref,
      [merchant_input, payment_input],
      [service_input],
      [merchant_output, payment_output],
      zero,
      insert_timerange,
      tx_hash,
    )

  validate_merchant_withdraw(
    service_cs,
    Some(Payment(payment_datum)),
    // merchant input_index
    0,
    // payment input_index
    1,
    context.transaction,
  )
}

test succeed_unsubscribe() {
  let own_cs = tests.test_payment_cs()
  let account_cs = tests.test_account_cs()
  let service_cs = tests.test_service_cs()

  let tx_hash = tests.test_224_01()
  let payment_tx_hash = tests.test_224_02()
  let account_tx_hash = tests.test_224_03()
  let service_tx_hash = tests.test_224_04()

  let script_output_ref = tests.test_input_utxo_02(payment_tx_hash)

  let payment_tkn = value.unique_token_name(payment_tx_hash, 1, #"", "")
  let service_tkn = value.unique_token_name(service_tx_hash, 1, prefix_222, "")
  let user_account_tkn =
    value.unique_token_name(account_tx_hash, 1, prefix_222, "")

  let current_time = 1000000
  let last_claimed = 500000
  // 30 days in milliseconds
  let interval_length = 30 * 24 * 60 * 60 * 1000
  let total_subscription_fee = 1_000_000_000
  let penalty_fee_qty = 1_000_000
  let interval_amount = 100_000_000
  let num_intervals = 1

  let payment_datum =
    tests.test_datum_03(
      service_tkn,
      user_account_tkn,
      total_subscription_fee,
      current_time,
      current_time + interval_length,
      interval_length,
      interval_amount,
      num_intervals,
      last_claimed,
      penalty_fee_qty,
    )

  let payment_value =
    assets.add(
      assets.from_lovelace(total_subscription_fee),
      own_cs,
      payment_tkn,
      1,
    )
  let account_value = assets.add(zero, account_cs, user_account_tkn, 1)
  let service_value = assets.add(zero, service_cs, service_tkn, 1)

  let is_active = True
  let service_datum =
    tests.test_service_datum(
      is_active,
      interval_length,
      num_intervals,
      interval_amount,
    )

  // Create the payment input (the one being spent)
  let payment_input =
    tests.test_context_input_02(
      script_output_ref,
      own_cs,
      payment_value,
      payment_datum,
    )

  // Create the account input
  let account_input =
    tests.test_context_input_02(
      tests.test_input_utxo_02(tx_hash),
      account_cs,
      account_value,
      NoDatum,
    )

  let service_input =
    tests.test_context_input_02(
      tests.test_input_utxo_02(service_cs),
      service_cs,
      service_value,
      service_datum,
    )
  // Calculate refund amount (assuming half of the subscription period has passed)
  let time_elapsed = interval_length / 2
  let refund_amount = total_subscription_fee / 2

  // Create refund output
  let refund_output =
    tests.test_utxo_02(
      account_cs,
      assets.from_lovelace(refund_amount),
      100_000_000,
      NoDatum,
    )

  let penalty_value =
    assets.add(assets.from_lovelace(penalty_fee_qty), own_cs, payment_tkn, 1)

  // Create penalty output
  let penalty_datum =
    tests.test_penalty_datum(service_tkn, user_account_tkn, penalty_fee_qty)
  let penalty_output =
    tests.test_utxo_02(
      own_cs,
      penalty_value,
      100_000_000,
      Penalty(penalty_datum),
    )

  let lower_bound = current_time + time_elapsed
  let upper_bound = lower_bound + 1

  let insert_timerange = tests.test_time_range(lower_bound, upper_bound)

  // Create the transaction
  let context =
    tests.test_spend_script_context(
      script_output_ref,
      [account_input, payment_input],
      [service_input],
      [refund_output, penalty_output],
      payment_value,
      insert_timerange,
      tx_hash,
    )

  validate_unsubscribe(
    service_cs,
    account_cs,
    Some(Payment(payment_datum)),
    0,
    1,
    context.transaction,
  )
}

test succeed_subscriber_withdraw() {
  let own_cs = tests.test_payment_cs()
  let account_cs = tests.test_account_cs()
  let service_cs = tests.test_service_cs()

  let tx_hash = tests.test_224_01()
  let payment_tx_hash = tests.test_224_02()
  let service_tx_hash = tests.test_224_03()

  let script_output_ref = tests.test_input_utxo_02(payment_tx_hash)

  let payment_tkn = value.unique_token_name(payment_tx_hash, 1, #"", "")
  let service_tkn = value.unique_token_name(service_tx_hash, 1, prefix_222, "")
  let user_account_tkn = value.unique_token_name(tx_hash, 1, prefix_222, "")

  let subscription_start = 1000000
  let interval_length = 30 * 24 * 60 * 60 * 1000
  let subscription_end = subscription_start + interval_length
  let total_subscription_fee = 1_000_000_000
  let penalty_fee_qty = 1_000_000
  let last_claimed = subscription_start
  let current_time = subscription_end + 1
  let interval_amount = 100_000_000
  let num_intervals = 1

  // After subscription end
  let payment_datum =
    tests.test_datum_03(
      service_tkn,
      user_account_tkn,
      total_subscription_fee,
      subscription_start,
      subscription_end,
      interval_length,
      interval_amount,
      num_intervals,
      last_claimed,
      penalty_fee_qty,
    )

  let is_active = False
  // Service is inactive
  let service_datum =
    tests.test_service_datum(
      is_active,
      interval_length,
      num_intervals,
      interval_amount,
    )

  let account_value = assets.add(zero, account_cs, user_account_tkn, 1)
  let payment_value =
    assets.add(
      assets.from_lovelace(total_subscription_fee),
      own_cs,
      payment_tkn,
      1,
    )
  let service_value =
    assets.add(
      assets.from_lovelace(total_subscription_fee),
      service_cs,
      service_tkn,
      1,
    )

  // Create the account input
  let account_input =
    tests.test_context_input_02(
      tests.test_input_utxo_02(tx_hash),
      account_cs,
      account_value,
      NoDatum,
    )

  let payment_input =
    tests.test_context_input_02(
      script_output_ref,
      own_cs,
      payment_value,
      payment_datum,
    )

  let service_input =
    tests.test_context_input_02(
      tests.test_input_utxo_02(service_tx_hash),
      service_cs,
      service_value,
      service_datum,
    )
  let account_output_value =
    assets.add(
      assets.from_lovelace(total_subscription_fee),
      account_cs,
      user_account_tkn,
      1,
    )

  let user_output =
    tests.test_utxo_02(account_cs, account_output_value, 100_000_000, NoDatum)

  // Create remaining funds output (if any)
  let penalty_output =
    tests.test_utxo_02(
      own_cs,
      payment_value,
      100_000_000,
      Some(Payment(payment_datum)),
    )

  let insert_timerange = tests.test_time_range(current_time, current_time + 1)

  let context =
    tests.test_spend_script_context(
      script_output_ref,
      [account_input, payment_input],
      [service_input],
      [user_output, penalty_output],
      assets.add(zero, own_cs, payment_tkn, -1),
      // Burning payment NFT
      insert_timerange,
      tx_hash,
    )

  validate_subscriber_withdraw(
    service_cs,
    account_cs,
    Some(Payment(payment_datum)),
    0,
    1,
    context.transaction,
  )
}
