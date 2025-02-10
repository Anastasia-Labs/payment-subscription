use aiken/interval.{Finite, Interval, IntervalBound}
use aiken/math
use cardano/assets.{add, from_lovelace, zero}
use cardano/transaction.{NoDatum}
use payment_subscription/common/cip68
use payment_subscription/common/types.{Payment, PaymentDatum, Penalty}
use payment_subscription/common/values
use payment_subscription/payment_multi_validator/validation.{
  payment_tokenname, validate_extend_subscription, validate_initial_subscription,
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

  let service_tkn =
    values.unique_token_name(service_tx_hash, 1, cip68.prefix_100)
  let user_account_tkn =
    values.unique_token_name(account_tx_hash, 1, cip68.prefix_222)

  let current_time = 1000000
  // 30 days in milliseconds
  let interval_length = 30 * 24 * 60 * 60 * 1000
  let interval_amount = 100_000_000
  let num_intervals = 10

  // 30 days in milliseconds
  let is_active = True
  let service_datum =
    tests.test_service_datum(
      is_active,
      interval_length,
      num_intervals,
      interval_amount,
    )

  let total_total_subscription_fee_qty = interval_amount * num_intervals
  let subscription_end = current_time + interval_length * num_intervals

  let payment_datum =
    tests.test_datum_03(
      service_tkn,
      user_account_tkn,
      current_time,
      subscription_end,
      subscription_end,
      interval_length,
      interval_amount,
      num_intervals,
      1,
    )

  let payment_value = add(zero, own_cs, payment_tokenname, 1)
  let service_value = add(zero, service_cs, service_tkn, 1)
  let account_value = add(zero, account_cs, user_account_tkn, 1)

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
        bound_type: Finite(current_time - 5),
        is_inclusive: True,
      },
      upper_bound: IntervalBound {
        bound_type: Finite(current_time - 1),
        is_inclusive: False,
      },
    }
  let reference_inputs = [service_input]
  let inputs = [account_input, service_input]
  let outputs = [user_output, payment_output]
  let mint = payment_value
  let validity_range = insert_timerange

  validate_initial_subscription(
    own_cs,
    service_cs,
    account_cs,
    0,
    0,
    1,
    reference_inputs,
    inputs,
    outputs,
    mint,
    validity_range,
  )
}

test succeed_terminate_subscription() {
  let own_cs = tests.test_payment_cs()

  let mint = add(zero, own_cs, payment_tokenname, -1)
  validate_terminate_subscription(own_cs, mint)
}

test succeed_extend_subscription() {
  let own_cs = tests.test_payment_cs()
  let account_cs = tests.test_account_cs()
  let service_cs = tests.test_service_cs()

  let tx_hash = tests.test_224_01()
  let payment_tx_hash = tests.test_224_02()
  let service_tx_hash = tests.test_224_03()

  let extend_output_ref = tests.test_input_utxo_02(payment_tx_hash)

  let service_tkn =
    values.unique_token_name(service_tx_hash, 1, cip68.prefix_100)
  let user_account_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_222)

  let service_value = add(zero, service_cs, service_tkn, 1)
  let user_value = add(zero, account_cs, user_account_tkn, 1)

  let current_time = 1000000
  // 30 days in milliseconds
  let interval_amount = 10_000_000
  let num_intervals = 1
  let interval_length = 30 * 24 * 60 * 60 * 1000
  let total_total_subscription_fee_qty = interval_amount * num_intervals

  // Create the initial payment datum
  let initial_payment_datum =
    tests.test_datum_03(
      service_tkn,
      user_account_tkn,
      current_time,
      current_time + interval_length,
      current_time + interval_length,
      interval_length,
      interval_amount,
      num_intervals,
      1,
    )
  // Create the payment input (the one being spent)
  let initial_payment_value =
    add(
      from_lovelace(total_total_subscription_fee_qty),
      own_cs,
      payment_tokenname,
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
      current_time,
      initial_payment_datum.subscription_end + extension_period,
      current_time + interval_length,
      interval_length,
      interval_amount,
      num_intervals + extension_intervals,
      1,
    )

  // Create the new payment output
  let new_payment_value =
    add(
      from_lovelace(total_total_subscription_fee_qty + extension_fee),
      own_cs,
      payment_tokenname,
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

  // Create a user output for change
  let change_amount = 3_000_000
  // Assuming 2_000_000 for fees
  let user_change_output =
    tests.test_user_utxo(subscriber_pkh, from_lovelace(change_amount), NoDatum)
  let inputs = [subscriber_input, payment_input]
  let reference_inputs = [service_input]
  let outputs = [user_change_output, payment_output]

  validate_extend_subscription(
    extend_output_ref,
    service_cs,
    0,
    1,
    1,
    extension_intervals,
    Payment(initial_payment_datum),
    reference_inputs,
    inputs,
    outputs,
  )
}

test succeed_merchant_withdraw() {
  let own_cs = tests.test_payment_cs()
  let service_cs = tests.test_service_cs()

  let tx_hash = tests.test_224_01()
  let payment_tx_hash = tests.test_224_02()
  let service_tx_hash = tests.test_224_03()

  let script_output_ref = tests.test_input_utxo_02(payment_tx_hash)

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
  let subscription_end = 1737045176747
  let last_claimed = 1737043736747
  // Set current time to exactly 2 vesting periods (60 days) after start
  let current_time = 1737043903924

  // Half-way through
  let payment_datum =
    tests.test_datum_03(
      service_tkn,
      user_account_tkn,
      subscription_start,
      subscription_end,
      subscription_end,
      interval_length,
      interval_amount,
      num_intervals,
      1,
    )

  // Calculate withdrawable amount using stepped vesting
  let time_since_last_claim = math.max(current_time - last_claimed, 0)

  let intervals_passed = time_since_last_claim / interval_length
  let claimable_intervals = math.min(intervals_passed, num_intervals)
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
    add(
      from_lovelace(total_total_subscription_fee_qty),
      own_cs,
      payment_tokenname,
      1,
    )
  let service_value =
    add(
      from_lovelace(total_total_subscription_fee_qty),
      service_cs,
      service_tkn,
      1,
    )

  let merchant_value =
    add(
      from_lovelace(total_total_subscription_fee_qty),
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
    add(from_lovelace(actual_withdrawal), service_cs, service_user_tkn, 1)

  // Create withdrawal output
  let merchant_output =
    tests.test_utxo_exact(service_cs, merchant_output_value, NoDatum)

  // Create remaining funds output (if any)
  let remaining_amount = total_total_subscription_fee_qty - actual_withdrawal

  let payment_output_value =
    add(from_lovelace(remaining_amount), own_cs, payment_tokenname, 1)

  let new_payment_datum =
    tests.test_datum_03(
      service_tkn,
      user_account_tkn,
      subscription_start,
      subscription_end,
      subscription_end,
      interval_length,
      interval_amount,
      num_intervals,
      2,
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

  let inputs = [merchant_input, payment_input]
  let reference_inputs = [service_input]
  let outputs = [merchant_output, payment_output]

  validate_merchant_withdraw(
    script_output_ref,
    service_cs,
    0,
    0,
    1,
    1,
    1,
    Payment(payment_datum),
    reference_inputs,
    inputs,
    outputs,
    insert_timerange,
    zero,
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
  let penalty_fee_qty = 1_000_000
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

  let account_value = add(zero, account_cs, user_account_tkn, 1)
  let service_value = add(zero, service_cs, service_tkn, 1)

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
      subscription_start,
      subscription_end,
      subscription_end,
      interval_length,
      interval_amount,
      remaining_intervals,
      1,
    )

  let payment_value =
    add(from_lovelace(refundable_amount), own_cs, payment_tokenname, 1)
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
    tests.test_utxo_02(account_cs, from_lovelace(subscriber_refund), 0, NoDatum)

  let penalty_value =
    add(
      from_lovelace(penalty_fee_qty + 2_000_000),
      own_cs,
      payment_tokenname,
      1,
    )

  // Create penalty output
  let penalty_datum = tests.test_penalty_datum(service_tkn, user_account_tkn)
  let penalty_output =
    tests.test_utxo_02(own_cs, penalty_value, 0, Penalty(penalty_datum))

  let lower_bound = current_time - 1
  let upper_bound = lower_bound + 1

  let insert_timerange = tests.test_time_range(lower_bound, upper_bound)

  let inputs = [account_input, payment_input]
  let reference_inputs = [service_input]
  let outputs = [refund_output, penalty_output]

  validate_unsubscribe(
    script_output_ref,
    account_cs,
    service_cs,
    0,
    0,
    1,
    1,
    Payment(payment_datum),
    reference_inputs,
    inputs,
    outputs,
    insert_timerange,
    zero,
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

  let service_tkn =
    values.unique_token_name(service_tx_hash, 1, cip68.prefix_222)
  let user_account_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_222)

  let subscription_start = 1000000
  let interval_length = 30 * 24 * 60 * 60 * 1000
  let subscription_end = subscription_start + interval_length
  let total_subscription_fee_qty = 1_000_000_000
  let interval_amount = 100_000_000
  let num_intervals = 1

  // After subscription end
  let payment_datum =
    tests.test_datum_03(
      service_tkn,
      user_account_tkn,
      subscription_start,
      subscription_end,
      subscription_end,
      interval_length,
      interval_amount,
      num_intervals,
      1,
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

  let account_value = add(zero, account_cs, user_account_tkn, 1)
  let payment_value =
    add(from_lovelace(total_subscription_fee_qty), own_cs, payment_tokenname, 1)
  let service_value =
    add(from_lovelace(total_subscription_fee_qty), service_cs, service_tkn, 1)

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

  let inputs = [account_input, payment_input]
  let reference_inputs = [service_input]

  validate_subscriber_withdraw(
    script_output_ref,
    service_cs,
    account_cs,
    0,
    0,
    1,
    Payment(payment_datum),
    reference_inputs,
    inputs,
    add(zero, own_cs, payment_tokenname, -1),
  )
}
