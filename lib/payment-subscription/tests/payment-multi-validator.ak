use aiken/dict
use aiken/interval.{Finite, Interval, IntervalBound}
use aiken/math
use aiken/transaction.{
  Mint, NoDatum, ScriptContext, Spend, Transaction, TransactionId,
}
use aiken/transaction/value
use assist/types/cip68
use assist/values
use payment_subscription/common/types.{
  AssetClass, Payment, PaymentDatum, Penalty, PenaltyDatum,
}
use payment_subscription/payment_multi_validator/validation.{
  validate_extend_subscription, validate_initial_subscription,
  validate_merchant_withdraw, validate_subscriber_withdraw,
  validate_terminate_subscription, validate_unsubscribe,
}
use payment_subscription/tests/tests

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

  let payment_tkn = values.unique_token_name(tx_hash, 1, #"")
  let service_tkn =
    values.unique_token_name(service_tx_hash, 1, cip68.prefix_100)
  let user_account_tkn =
    values.unique_token_name(account_tx_hash, 1, cip68.prefix_222)

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

  let total_total_subscription_fee_qty = 1_000_000_000
  let subscription_end = current_time + interval_length * num_intervals

  let payment_datum =
    tests.test_datum_03(
      service_tkn,
      user_account_tkn,
      total_total_subscription_fee_qty,
      current_time,
      subscription_end,
      interval_length,
      interval_amount,
      num_intervals,
      last_claimed,
      penalty_qty,
    )

  let payment_value = value.add(value.zero(), own_cs, payment_tkn, 1)
  let service_value = value.add(value.zero(), service_cs, service_tkn, 1)
  let account_value = value.add(value.zero(), account_cs, user_account_tkn, 1)

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
      total_total_subscription_fee_qty,
      Payment(payment_datum),
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
      purpose: Mint(own_cs),
      transaction: Transaction {
        inputs: [account_input, service_input],
        // Normally used to read Datum
        reference_inputs: [service_input],
        // There should be two outputs.
        outputs: [user_output, payment_output],
        fee: value.zero(),
        mint: value.to_minted_value(payment_value),
        certificates: [],
        withdrawals: [],
        validity_range: insert_timerange,
        extra_signatories: [],
        redeemers: [],
        datums: dict.new(),
        id: TransactionId { hash: tx_hash },
      },
    }

  validate_initial_subscription(
    own_cs,
    account_cs,
    service_cs,
    init_output_ref,
    input_index,
    context.transaction,
  )
}

test succeed_terminate_subscription() {
  let own_cs = tests.test_payment_cs()
  let service_cs = tests.test_service_cs()

  let tx_hash = tests.test_224_01()
  let payment_tx_hash = tests.test_224_02()
  let service_tx_hash = tests.test_224_03()

  let init_output_ref = tests.test_input_utxo_02(tx_hash)
  let script_output_ref = tests.test_input_utxo_02(payment_tx_hash)

  let current_time = 1000000
  // 30 days in milliseconds
  let interval_length = 30 * 24 * 60 * 60 * 1000

  // let total_subscription_fee_qty = 1_000_000_000
  let user_account_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_222)
  let user_service_tkn =
    values.unique_token_name(service_cs, 1, cip68.prefix_222)
  let payment_tkn = values.unique_token_name(payment_tx_hash, 1, #"")
  let service_tkn =
    values.unique_token_name(service_tx_hash, 1, cip68.prefix_100)

  let service_value = value.add(value.zero(), service_cs, user_service_tkn, 1)

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
      subscriber_nft_tn: user_account_tkn,
      penalty_fee: AssetClass {
        policy_id: value.ada_policy_id,
        asset_name: value.ada_asset_name,
      },
      penalty_fee_qty,
    }
  let penalty_value =
    value.add(value.from_lovelace(penalty_fee_qty), own_cs, payment_tkn, 1)

  let merchant_output =
    tests.test_utxo_02(service_cs, value.zero(), penalty_fee_qty, NoDatum)

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
      purpose: Mint(own_cs),
      transaction: Transaction {
        inputs: [merchant_input, penalty_input],
        reference_inputs: [],
        outputs: [merchant_output],
        fee: value.zero(),
        mint: value.to_minted_value(
          value.add(value.zero(), own_cs, payment_tkn, -1),
        ),
        certificates: [],
        withdrawals: [],
        validity_range: insert_timerange,
        extra_signatories: [],
        redeemers: [],
        datums: dict.new(),
        id: TransactionId { hash: tx_hash },
      },
    }

  validate_terminate_subscription(own_cs, context.transaction)
}

test succeed_extend_subscription() {
  let own_cs = tests.test_payment_cs()
  let account_cs = tests.test_account_cs()
  let service_cs = tests.test_service_cs()

  let tx_hash = tests.test_224_01()
  let payment_tx_hash = tests.test_224_02()
  let service_tx_hash = tests.test_224_03()

  let extend_output_ref = tests.test_input_utxo_02(payment_tx_hash)

  let payment_tkn = values.unique_token_name(payment_tx_hash, 1, #"")
  let service_tkn =
    values.unique_token_name(service_tx_hash, 1, cip68.prefix_100)
  let user_account_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_222)

  let service_value = value.add(value.zero(), service_cs, service_tkn, 1)
  let user_value = value.add(value.zero(), account_cs, user_account_tkn, 1)

  let current_time = 1000000
  let last_claimed = 500000
  // 30 days in milliseconds
  let interval_amount = 10_000_000
  let num_intervals = 1
  let interval_length = 30 * 24 * 60 * 60 * 1000
  let total_total_subscription_fee_qty = interval_amount * num_intervals
  let penalty_fee_qty = 1_000_000

  // Create the initial payment datum
  let initial_payment_datum =
    tests.test_datum_03(
      service_tkn,
      user_account_tkn,
      total_total_subscription_fee_qty,
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
    value.add(
      value.from_lovelace(total_total_subscription_fee_qty),
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
      total_total_subscription_fee_qty + extension_fee,
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
    value.add(
      value.from_lovelace(total_total_subscription_fee_qty + extension_fee),
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
      value.from_lovelace(change_amount),
      NoDatum,
    )
  // Create the transaction
  let context =
    ScriptContext {
      purpose: Spend(extend_output_ref),
      transaction: Transaction {
        inputs: [subscriber_input, payment_input],
        reference_inputs: [service_input],
        outputs: [user_change_output, payment_output],
        fee: value.zero(),
        mint: value.to_minted_value(value.zero()),
        certificates: [],
        withdrawals: [],
        validity_range: insert_timerange,
        extra_signatories: [],
        redeemers: [],
        datums: dict.new(),
        id: TransactionId { hash: tx_hash },
      },
    }

  validate_extend_subscription(
    extend_output_ref,
    service_cs,
    Payment(initial_payment_datum),
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

  let payment_tkn = values.unique_token_name(payment_tx_hash, 1, #"")
  let service_tkn =
    values.unique_token_name(service_tx_hash, 1, cip68.prefix_100)
  let service_user_tkn =
    values.unique_token_name(service_tx_hash, 1, cip68.prefix_222)
  let user_account_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_222)

  let subscription_start = 1737043736747
  // 30 days in milliseconds
  let interval_length = 120000
  //30 * 24 * 60 * 60 * 1000
  // 120 days total
  let num_intervals = 12
  let interval_amount = 100_000_000
  let total_total_subscription_fee_qty = 1_200_000_000
  let penalty_fee_qty = 1_000_000
  let subscription_end = 1737045176747
  let last_claimed = 1737043736747
  // Set current time to exactly 2 vesting periods (60 days) after start
  let current_time = 1737043903924

  // Half-way through
  let payment_datum =
    tests.test_datum_03(
      service_tkn,
      user_account_tkn,
      total_total_subscription_fee_qty,
      subscription_start,
      subscription_end,
      interval_length,
      interval_amount,
      num_intervals,
      last_claimed,
      penalty_fee_qty,
    )

  // Calculate withdrawable amount using stepped vesting
  let time_since_last_claim =
    math.max(current_time - payment_datum.last_claimed, 0)

  let intervals_passed = time_since_last_claim / payment_datum.interval_length
  let claimable_intervals =
    math.min(intervals_passed, payment_datum.num_intervals)
  let withdrawable_amount = interval_amount * claimable_intervals

  let is_active = True
  let service_datum =
    tests.test_service_datum(
      is_active,
      interval_length,
      num_intervals,
      interval_amount,
    )

  let payment_value =
    value.add(
      value.from_lovelace(total_total_subscription_fee_qty),
      own_cs,
      payment_tkn,
      1,
    )
  let service_value =
    value.add(
      value.from_lovelace(total_total_subscription_fee_qty),
      service_cs,
      service_tkn,
      1,
    )

  let merchant_value =
    value.add(
      value.from_lovelace(total_total_subscription_fee_qty),
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
      Payment(payment_datum),
    )

  // Create the service input (to prove service ownership)
  let service_input =
    tests.test_context_input_02(
      tests.test_input_utxo_02(service_tx_hash),
      service_cs,
      service_value,
      service_datum,
    )

  // Calculate withdrawable amount (assuming half of the subscription period has passed)
  let actual_withdrawal = withdrawable_amount
  let merchant_output_value =
    value.add(
      value.from_lovelace(actual_withdrawal),
      service_cs,
      service_user_tkn,
      1,
    )

  // Create withdrawal output
  let merchant_output =
    tests.test_utxo_exact(service_cs, merchant_output_value, NoDatum)

  // Create remaining funds output (if any)
  let remaining_amount = total_total_subscription_fee_qty - actual_withdrawal

  let payment_output_value =
    value.add(value.from_lovelace(remaining_amount), own_cs, payment_tkn, 1)

  let new_payment_datum =
    tests.test_datum_03(
      service_tkn,
      user_account_tkn,
      remaining_amount,
      subscription_start,
      subscription_end,
      interval_length,
      interval_amount,
      num_intervals - 1,
      current_time,
      penalty_fee_qty,
    )

  let payment_output =
    tests.test_utxo_02(
      own_cs,
      payment_output_value,
      0,
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
      value.zero(),
      insert_timerange,
      tx_hash,
    )

  validate_merchant_withdraw(
    script_output_ref,
    service_cs,
    Payment(payment_datum),
    0,
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

  let payment_tkn = values.unique_token_name(payment_tx_hash, 1, #"")
  let service_tkn =
    values.unique_token_name(service_tx_hash, 1, cip68.prefix_222)
  let user_account_tkn =
    values.unique_token_name(account_tx_hash, 1, cip68.prefix_222)

  let subscription_start = 1737043736747
  // 30 days in milliseconds
  let interval_length = 120000
  let interval_amount = 10_000_000
  //30 * 24 * 60 * 60 * 1000
  // 120 days total
  let num_intervals = 12
  let subscription_end = 1737045176747
  let total_subscription_fee_qty = interval_amount * num_intervals
  let penalty_fee_qty = 1_000_000
  let last_claimed = 1737043736747
  // Set current time to exactly 2 vesting periods (60 days) after start
  let current_time = 1737043903924

  // Calculate refund based on unclaimed intervals (matching validator logic)
  let time_since_start = math.max(current_time - subscription_start, 0)
  let intervals_passed = time_since_start / interval_length
  let claimed_intervals = math.min(intervals_passed, num_intervals)
  let remaining_intervals = num_intervals - claimed_intervals
  let refundable_amount = remaining_intervals * interval_amount

  // Subscriber should get refundable amount minus penalty
  let subscriber_refund = refundable_amount - penalty_fee_qty - 2_000_000

  let account_value = value.add(value.zero(), account_cs, user_account_tkn, 1)
  let service_value = value.add(value.zero(), service_cs, service_tkn, 1)

  let is_active = True
  let service_datum =
    tests.test_service_datum(
      is_active,
      interval_length,
      num_intervals,
      interval_amount,
    )

  let payment_datum =
    tests.test_datum_03(
      service_tkn,
      user_account_tkn,
      total_subscription_fee_qty,
      subscription_start,
      subscription_end,
      interval_length,
      interval_amount,
      remaining_intervals,
      last_claimed,
      penalty_fee_qty,
    )

  let payment_value =
    value.add(value.from_lovelace(refundable_amount), own_cs, payment_tkn, 1)
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

  // Create refund output
  let refund_output =
    tests.test_utxo_02(
      account_cs,
      value.from_lovelace(subscriber_refund),
      0,
      NoDatum,
    )

  let penalty_value =
    value.add(
      value.from_lovelace(penalty_fee_qty + 2_000_000),
      own_cs,
      payment_tkn,
      1,
    )

  // Create penalty output
  let penalty_datum =
    tests.test_penalty_datum(service_tkn, user_account_tkn, penalty_fee_qty)
  let penalty_output =
    tests.test_utxo_02(own_cs, penalty_value, 0, Penalty(penalty_datum))

  let lower_bound = current_time - 1
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
    script_output_ref,
    account_cs,
    Payment(payment_datum),
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

  let payment_tkn = values.unique_token_name(payment_tx_hash, 1, #"")
  let service_tkn =
    values.unique_token_name(service_tx_hash, 1, cip68.prefix_222)
  let user_account_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_222)

  let subscription_start = 1000000
  let interval_length = 30 * 24 * 60 * 60 * 1000
  let subscription_end = subscription_start + interval_length
  let total_subscription_fee_qty = 1_000_000_000
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
      total_subscription_fee_qty,
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

  let account_value = value.add(value.zero(), account_cs, user_account_tkn, 1)
  let payment_value =
    value.add(
      value.from_lovelace(total_subscription_fee_qty),
      own_cs,
      payment_tkn,
      1,
    )
  let service_value =
    value.add(
      value.from_lovelace(total_subscription_fee_qty),
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
    value.add(
      value.from_lovelace(total_subscription_fee_qty),
      account_cs,
      user_account_tkn,
      1,
    )

  let user_output =
    tests.test_utxo_02(account_cs, account_output_value, 100_000_000, NoDatum)

  // Create remaining funds output (if any)
  // let penalty_value =
  //   value.add(value.from_lovelace(penalty_fee_qty), own_cs, payment_tkn, 1)
  // Create penalty output
  // let penalty_datum =
  //   tests.test_penalty_datum(service_tkn, user_account_tkn, penalty_fee_qty)
  let penalty_output =
    tests.test_utxo_02(
      own_cs,
      payment_value,
      100_000_000,
      Payment(payment_datum),
    )

  let insert_timerange = tests.test_time_range(current_time, current_time + 1)

  let context =
    tests.test_spend_script_context(
      script_output_ref,
      [account_input, payment_input],
      [service_input],
      [user_output, penalty_output],
      value.add(value.zero(), own_cs, payment_tkn, -1),
      // Burning payment NFT
      insert_timerange,
      tx_hash,
    )

  validate_subscriber_withdraw(
    script_output_ref,
    service_cs,
    account_cs,
    Payment(payment_datum),
    0,
    1,
    context.transaction,
  )
}
