use aiken/collection/list
use aiken/fuzz.{and_then, such_that}
use aiken/interval
use aiken/math
use cardano/address.{Address, Script}
use cardano/assets.{
  AssetName, PolicyId, Value, add, from_asset, from_lovelace, zero,
}
use cardano/transaction.{
  InlineDatum, Input, NoDatum, Output, OutputReference, ValidityRange,
}
use payment_subscription/common/cip68
use payment_subscription/common/types.{
  Installment, Payment, PaymentDatum, PaymentValidatorDatum, Penalty,
  ServiceDatum,
}
use payment_subscription/common/values
use payment_subscription/payment_multi_validator/validation.{
  payment_tokenname, validate_extend_subscription, validate_initial_subscription,
  validate_merchant_withdraw, validate_subscriber_withdraw,
  validate_terminate_subscription, validate_unsubscribe,
}
use payment_subscription/tests/tests.{placeholder_input, placeholder_output}

fn setup_policy_ids() {
  let payment_cs = tests.test_payment_cs()
  let account_cs = tests.test_account_cs()
  let service_cs = tests.test_service_cs()

  (payment_cs, account_cs, service_cs)
}

fn setup_base_tx_hash() {
  let payment_tx_hash = tests.test_224_01()
  let service_tx_hash = tests.test_224_03()
  let account_tx_hash = tests.test_224_02()

  (payment_tx_hash, service_tx_hash, account_tx_hash)
}

fn setup_config(num_intervals) {
  // let current_time = 1737043903924
  // 30 days in milliseconds
  let interval_length = 30 * 24 * 60 * 60 * 1000
  let interval_amount = 10_000_000

  let subscription_start = 1737043736747
  let subscription_end = subscription_start + interval_length * num_intervals
  let last_claimed = 1737043736747
  let current_time = subscription_start + interval_length + 1000

  // Add buffer
  let total_subscription_fee_qty = interval_amount * num_intervals

  // Set current time to exactly 2 vesting periods (60 days) after start
  (
    current_time,
    interval_length,
    interval_amount,
    num_intervals,
    subscription_start,
    subscription_end,
    last_claimed,
    total_subscription_fee_qty,
  )
}

fn create_token_names() {
  let (_payment_tx_hash, service_tx_hash, account_tx_hash) =
    setup_base_tx_hash()

  let service_tkn =
    values.unique_token_name(service_tx_hash, 1, cip68.prefix_100)
  let merchant_tkn =
    values.unique_token_name(service_tx_hash, 1, cip68.prefix_222)

  let account_tkn =
    values.unique_token_name(account_tx_hash, 1, cip68.prefix_100)
  let subscriber_tkn =
    values.unique_token_name(account_tx_hash, 1, cip68.prefix_222)

  (service_tkn, merchant_tkn, account_tkn, subscriber_tkn)
}

fn create_base_token_values() -> (Value, Value, Value, Value, Value) {
  let (service_tkn, merchant_tkn, account_tkn, subscriber_tkn) =
    create_token_names()

  // Use zero as the default base value
  create_base_token_values_with_base(
    zero,
    service_tkn,
    merchant_tkn,
    account_tkn,
    subscriber_tkn,
  )
}

fn create_base_token_values_with_base(
  base_value: Value,
  service_tkn: AssetName,
  merchant_tkn: AssetName,
  account_tkn: AssetName,
  subscriber_tkn: AssetName,
) -> (Value, Value, Value, Value, Value) {
  let (payment_cs, account_cs, service_cs) = setup_policy_ids()

  // let (service_tkn, merchant_tkn, account_tkn, subscriber_tkn) =
  //   create_token_names()
  let payment_value = add(base_value, payment_cs, payment_tokenname, 1)
  let service_value = add(base_value, service_cs, service_tkn, 1)
  let merchant_value = add(base_value, service_cs, merchant_tkn, 1)
  let account_value = add(base_value, account_cs, account_tkn, 1)
  let subscriber_value = add(base_value, account_cs, subscriber_tkn, 1)

  (
    payment_value,
    service_value,
    merchant_value,
    account_value,
    subscriber_value,
  )
}

fn create_base_payment_datum(
  current_time,
  interval_length,
  interval_amount,
  num_intervals,
) {
  let subscription_end = current_time + interval_length * num_intervals
  let (service_tkn, _merchant_tkn, _account_tkn, subscriber_tkn) =
    create_token_names()

  let payment_datum =
    tests.test_datum_03(
      service_tkn,
      subscriber_tkn,
      current_time,
      subscription_end,
      subscription_end,
      interval_length,
      interval_amount,
      num_intervals,
      1,
    )

  payment_datum
}

fn create_base_service_datum(is_active: Bool) {
  let (
    _current_time,
    interval_length,
    interval_amount,
    num_intervals,
    _subscription_start,
    _subscription_end,
    _last_claimed,
    _total_subscription_fee_qty,
  ) = setup_config(12)

  // let is_active = True
  let service_datum =
    tests.test_service_datum(
      is_active,
      interval_length,
      num_intervals,
      interval_amount,
    )

  service_datum
}

fn create_base_inputs(
  init_output_ref,
  payment_datum,
  payment_value,
  service_value,
  merchant_value,
  account_value,
  subscriber_value,
) {
  let (payment_cs, account_cs, service_cs) = setup_policy_ids()

  let service_datum = create_base_service_datum(True)

  // Create the merchant input (to prove service ownership)
  let merchant_input =
    tests.test_context_input_02(
      init_output_ref,
      service_cs,
      merchant_value,
      NoDatum,
    )

  // Create the service input (to prove service ownership)
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
  let subscriber_input =
    tests.test_context_input_02(
      init_output_ref,
      account_cs,
      subscriber_value,
      NoDatum,
    )

  // Create the payment input (the one being spent)
  let payment_input =
    tests.test_context_input_02(
      init_output_ref,
      payment_cs,
      payment_value,
      Payment(payment_datum),
    )

  (
    payment_input,
    service_input,
    merchant_input,
    account_input,
    subscriber_input,
  )
}

fn create_base_outputs(
  payment_cs,
  interval_amount,
  total_subscription_fee_qty,
  payment_datum,
) {
  let user_pubkey_hash = tests.test_224_03()
  let (
    payment_value,
    _service_value,
    _merchant_tkn,
    _account_value,
    subscriber_value,
  ) = create_base_token_values()

  let subscriber_output =
    tests.test_utxo_02(
      user_pubkey_hash,
      subscriber_value,
      interval_amount,
      NoDatum,
    )

  let payment_output =
    tests.test_utxo_02(
      payment_cs,
      payment_value,
      total_subscription_fee_qty,
      Payment(payment_datum),
    )

  (payment_output, subscriber_output)
}

fn test_initiate_subscription(
  payment_cs,
  account_cs,
  service_cs,
  service_input,
  account_input,
  payment_output,
  subscriber_output,
  validity_range,
  mint,
) {
  let reference_inputs = [service_input]
  let inputs = [account_input, service_input]
  let outputs = [subscriber_output, payment_output]

  // let validity_range = insert_timerange
  validate_initial_subscription(
    payment_cs,
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

// Happy path tests
test succeed_initiate_subscription() {
  let (payment_cs, account_cs, service_cs) = setup_policy_ids()
  let (payment_tx_hash, _service_tx_hash, _account_tx_hash) =
    setup_base_tx_hash()
  let init_output_ref = tests.test_input_utxo_02(payment_tx_hash)

  let (
    current_time,
    interval_length,
    interval_amount,
    num_intervals,
    _subscription_start,
    _subscription_end,
    _last_claimed,
    total_subscription_fee_qty,
  ) = setup_config(12)

  let payment_datum =
    create_base_payment_datum(
      current_time,
      interval_length,
      interval_amount,
      num_intervals,
    )

  let (
    payment_value,
    service_value,
    merchant_value,
    account_value,
    subscriber_value,
  ) = create_base_token_values()

  let (
    _payment_input,
    service_input,
    _merchant_input,
    _account_input,
    subscriber_input,
  ) =
    create_base_inputs(
      init_output_ref,
      payment_datum,
      payment_value,
      service_value,
      merchant_value,
      account_value,
      subscriber_value,
    )

  let (payment_output, subscriber_output) =
    create_base_outputs(
      payment_cs,
      interval_amount,
      total_subscription_fee_qty,
      payment_datum,
    )

  let lower_bound = current_time - 5
  let upper_bound = current_time - 1
  let validity_range = tests.test_time_range(lower_bound, upper_bound)
  let mint = payment_value

  test_initiate_subscription(
    payment_cs,
    account_cs,
    service_cs,
    service_input,
    subscriber_input,
    payment_output,
    subscriber_output,
    validity_range,
    mint,
  )
}

type InitSubscriptionTestData {
  payment_policy: PolicyId,
  service_policy: PolicyId,
  account_policy: PolicyId,
  service_ref_input_index: Int,
  subscriber_input_index: Int,
  payment_output_index: Int,
  reference_inputs: List<Input>,
  inputs: List<Input>,
  outputs: List<Output>,
  minted_value: Value,
  validity_range: ValidityRange,
}

fn gen_output_ref() -> Fuzzer<OutputReference> {
  let transaction_id <- and_then(fuzz.bytearray_fixed(32))
  let output_index <- and_then(fuzz.int_between(0, 20))
  fuzz.constant(OutputReference { transaction_id, output_index })
}

fn gen_account_input(
  account_policy: PolicyId,
  account_token_seed: OutputReference,
) -> Fuzzer<Input> {
  let input_ref <- and_then(gen_output_ref())
  let account_token_name =
    values.unique_token_name(
      account_token_seed.transaction_id,
      account_token_seed.output_index,
      cip68.prefix_222,
    )
  fuzz.constant(
    Input {
      output_reference: input_ref,
      output: Output {
        address: Address(Script(account_policy), None),
        value: from_asset(account_policy, account_token_name, 1),
        datum: NoDatum,
        reference_script: None,
      },
    },
  )
}

fn gen_service_input(
  service_policy: PolicyId,
  service_datum: ServiceDatum,
  service_token_name: AssetName,
) -> Fuzzer<Input> {
  let input_ref <- and_then(gen_output_ref())
  fuzz.constant(
    Input {
      output_reference: input_ref,
      output: Output {
        address: Address(Script(service_policy), None),
        value: from_asset(service_policy, service_token_name, 1),
        datum: InlineDatum(service_datum),
        reference_script: None,
      },
    },
  )
}

fn valid_payment_output(
  payment_policy: PolicyId,
  payment_datum: PaymentValidatorDatum,
  service_datum: ServiceDatum,
) -> Output {
  let value =
    add(
      add(from_lovelace(2_000_000), payment_policy, payment_tokenname, 1),
      service_datum.service_fee_policyid,
      service_datum.service_fee_assetname,
      service_datum.num_intervals * service_datum.service_fee,
    )
  Output {
    address: Address(Script(payment_policy), None),
    value,
    datum: InlineDatum(payment_datum),
    reference_script: None,
  }
}

fn gen_list_single_index(default: a, indexed: a) -> Fuzzer<(Int, List<a>)> {
  let count <- and_then(fuzz.int_between(1, 20))
  let index <- and_then(fuzz.int_between(0, count - 1))
  fuzz.constant(
    (
      index,
      list.map(
        list.range(0, count - 1),
        fn(i) {
          if i == index {
            indexed
          } else {
            default
          }
        },
      ),
    ),
  )
}

fn gen_service_reference_token_name() -> Fuzzer<AssetName> {
  fuzz.bytearray_between(1, 32)
}

fn gen_valid_service_datum() -> Fuzzer<ServiceDatum> {
  let service_fee_policyid <- and_then(fuzz.bytearray_fixed(28))
  let service_fee_assetname <- and_then(fuzz.bytearray_between(1, 32))
  let service_fee <- and_then(fuzz.int_between(1, 100_000_000_000_000))
  let penalty_fee_policyid <- and_then(fuzz.bytearray_fixed(28))
  let penalty_fee_assetname <- and_then(fuzz.bytearray_between(1, 32))
  let penalty_fee <- and_then(fuzz.int_between(1, 100_000_000_000_000))
  let interval_length <- and_then(fuzz.int_between(1, 100_000_000_000_000))
  let num_intervals <- and_then(fuzz.int_between(1, 1_000))
  fuzz.constant(
    ServiceDatum {
      service_fee_policyid,
      service_fee_assetname,
      service_fee,
      penalty_fee_policyid,
      penalty_fee_assetname,
      penalty_fee,
      interval_length,
      num_intervals,
      is_active: True,
    },
  )
}

fn gen_valid_payment_datum(
  current_time: Int,
  service_datum: ServiceDatum,
  service_reference_tokenname: AssetName,
  subscriber_reference_tokenname: AssetName,
) -> Fuzzer<PaymentDatum> {
  let subscription_start <- and_then(fuzz.int_at_least(current_time))
  let subscription_end =
    subscription_start + service_datum.interval_length * service_datum.num_intervals
  let installments =
    list.map(
      list.range(1, service_datum.num_intervals),
      fn(i) {
        Installment {
          claimable_at: subscription_start + i * service_datum.interval_length,
          claimable_amount: service_datum.service_fee,
        }
      },
    )
  fuzz.constant(
    PaymentDatum {
      service_reference_tokenname,
      subscriber_reference_tokenname,
      subscription_start,
      subscription_end,
      original_subscription_end: subscription_end,
      installments,
    },
  )
}

fn policies_are_different(
  service_datum: ServiceDatum,
  policies_not_allowed: List<PolicyId>,
) -> Bool {
  and {
    !list.any(
      policies_not_allowed,
      fn(p) { service_datum.service_fee_policyid == p },
    ),
    !list.any(
      policies_not_allowed,
      fn(p) { service_datum.penalty_fee_policyid == p },
    ),
  }
}

fn gen_init_subscription_success() -> Fuzzer<InitSubscriptionTestData> {
  let (payment_policy, account_policy, service_policy) = setup_policy_ids()
  let account_token_seed <- and_then(gen_output_ref())
  let subscriber_reference_tokenname =
    values.unique_token_name(
      account_token_seed.transaction_id,
      account_token_seed.output_index,
      cip68.prefix_100,
    )
  let account_ref <-
    and_then(gen_account_input(account_policy, account_token_seed))
  let (subscriber_input_index, inputs) <-
    and_then(gen_list_single_index(placeholder_input, account_ref))
  let service_datum <-
    and_then(
      such_that(
        gen_valid_service_datum(),
        fn(s) {
          policies_are_different(
            s,
            [payment_policy, account_policy, service_policy],
          )
        },
      ),
    )
  let service_reference_tokenname <-
    and_then(gen_service_reference_token_name())
  let service_input <-
    and_then(
      gen_service_input(
        service_policy,
        service_datum,
        service_reference_tokenname,
      ),
    )
  let (service_ref_input_index, reference_inputs) <-
    and_then(gen_list_single_index(placeholder_input, service_input))
  let current_time <- and_then(fuzz.int())
  let payment_datum <-
    and_then(
      gen_valid_payment_datum(
        current_time,
        service_datum,
        service_reference_tokenname,
        subscriber_reference_tokenname,
      ),
    )
  let payment_output =
    valid_payment_output(payment_policy, Payment(payment_datum), service_datum)
  let (payment_output_index, outputs) <-
    and_then(gen_list_single_index(placeholder_output, payment_output))
  fuzz.constant(
    InitSubscriptionTestData {
      payment_policy,
      service_policy,
      account_policy,
      service_ref_input_index,
      subscriber_input_index,
      payment_output_index,
      reference_inputs,
      inputs,
      outputs,
      minted_value: from_asset(payment_policy, payment_tokenname, 1),
      validity_range: interval.entirely_before(payment_datum.subscription_start),
    },
  )
}

test prop_successful_initiate_subscription(
  test_values via gen_init_subscription_success(),
) {
  validate_initial_subscription(
    test_values.payment_policy,
    test_values.service_policy,
    test_values.account_policy,
    test_values.service_ref_input_index,
    test_values.subscriber_input_index,
    test_values.payment_output_index,
    test_values.reference_inputs,
    test_values.inputs,
    test_values.outputs,
    test_values.minted_value,
    test_values.validity_range,
  )
}

test succeed_terminate_subscription() {
  let payment_cs = tests.test_payment_cs()

  let mint = add(zero, payment_cs, payment_tokenname, -1)
  validate_terminate_subscription(payment_cs, mint)
}

test succeed_extend_subscription() {
  let (
    current_time,
    interval_length,
    interval_amount,
    num_intervals,
    _subscription_start,
    _subscription_end,
    _last_claimed,
    total_subscription_fee_qty,
  ) = setup_config(1)
  let (payment_cs, _account_cs, service_cs) = setup_policy_ids()
  let (payment_tx_hash, _service_tx_hash, _account_tx_hash) =
    setup_base_tx_hash()

  let extend_output_ref = tests.test_input_utxo_02(payment_tx_hash)

  let (service_tkn, merchant_tkn, account_tkn, subscriber_tkn) =
    create_token_names()

  let (
    payment_value,
    service_value,
    merchant_value,
    account_value,
    subscriber_value,
  ) =
    create_base_token_values_with_base(
      from_lovelace(total_subscription_fee_qty),
      service_tkn,
      merchant_tkn,
      account_tkn,
      subscriber_tkn,
    )

  // Create the initial payment datum
  let payment_datum =
    create_base_payment_datum(
      current_time,
      interval_length,
      interval_amount,
      num_intervals,
    )
  let payment_input =
    tests.test_context_input_02(
      extend_output_ref,
      payment_cs,
      payment_value,
      Payment(payment_datum),
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
      subscriber_tkn,
      current_time,
      payment_datum.subscription_end + extension_period,
      current_time + interval_length,
      interval_length,
      interval_amount,
      num_intervals + extension_intervals,
      1,
    )

  let payment_output =
    tests.test_utxo_02(
      payment_cs,
      payment_value,
      total_subscription_fee_qty + extension_fee,
      Payment(new_payment_datum),
    )
  // Create a mock subscriber input (to pay for the extension)
  let subscriber_pkh = tests.test_224_04()
  // Assuming this function exists to generate a different hash
  let (
    _payment_input,
    service_input,
    _merchant_input,
    _account_input,
    subscriber_input,
  ) =
    create_base_inputs(
      extend_output_ref,
      payment_datum,
      payment_value,
      service_value,
      merchant_value,
      account_value,
      subscriber_value,
    )

  // Create a user output for change
  let change_amount = 3_000_000
  let subscriber_output =
    tests.test_user_utxo(subscriber_pkh, from_lovelace(change_amount), NoDatum)
  let reference_inputs = [service_input]
  let inputs = [subscriber_input, payment_input]
  let outputs = [subscriber_output, payment_output]

  validate_extend_subscription(
    extend_output_ref,
    service_cs,
    0,
    1,
    1,
    extension_intervals,
    Payment(payment_datum),
    reference_inputs,
    inputs,
    outputs,
  )
}

fn merchant_withdraw_test(
  total_subscription_fee_qty,
  outputs,
  service_cs,
  payment_datum,
  timerange,
  service_tkn,
  merchant_tkn,
  account_tkn,
  subscriber_tkn,
) {
  let (payment_tx_hash, _service_tx_hash, _account_tx_hash) =
    setup_base_tx_hash()
  let script_output_ref = tests.test_input_utxo_02(payment_tx_hash)

  let (
    payment_value,
    service_value,
    merchant_value,
    account_value,
    subscriber_value,
  ) =
    create_base_token_values_with_base(
      from_lovelace(total_subscription_fee_qty),
      service_tkn,
      merchant_tkn,
      account_tkn,
      subscriber_tkn,
    )

  let (
    payment_input,
    service_input,
    merchant_input,
    _account_input,
    _subscriber_input,
  ) =
    create_base_inputs(
      script_output_ref,
      payment_datum,
      payment_value,
      service_value,
      merchant_value,
      account_value,
      subscriber_value,
    )

  let inputs = [merchant_input, payment_input]
  let reference_inputs = [service_input]

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
    timerange,
    zero,
  )
}

test succeed_merchant_withdraw() {
  let (
    current_time,
    interval_length,
    interval_amount,
    num_intervals,
    subscription_start,
    subscription_end,
    last_claimed,
    total_subscription_fee_qty,
  ) = setup_config(12)
  let (payment_cs, _account_cs, service_cs) = setup_policy_ids()

  // Calculate withdrawable amount using stepped vesting
  let time_since_last_claim = math.max(current_time - last_claimed, 0)

  let intervals_passed = time_since_last_claim / interval_length
  let claimable_intervals = math.min(intervals_passed, num_intervals)
  let withdrawable_amount = interval_amount * claimable_intervals

  let (service_tkn, merchant_tkn, account_tkn, subscriber_tkn) =
    create_token_names()

  let payment_datum =
    create_base_payment_datum(
      subscription_start,
      interval_length,
      interval_amount,
      num_intervals,
    )

  // Calculate withdrawable amount (assuming half of the subscription period has passed)
  let actual_withdrawal = withdrawable_amount
  let merchant_output_value =
    add(from_lovelace(actual_withdrawal), service_cs, merchant_tkn, 1)

  // Create withdrawal output
  let merchant_output =
    tests.test_utxo_exact(service_cs, merchant_output_value, NoDatum)

  // Create remaining funds output (if any)
  let remaining_amount = total_subscription_fee_qty - actual_withdrawal

  // let payment_output_value =
  //   add(from_lovelace(remaining_amount), payment_cs, payment_tokenname, 1)
  let new_payment_datum =
    tests.test_datum_03(
      service_tkn,
      subscriber_tkn,
      subscription_start,
      subscription_end,
      subscription_end,
      interval_length,
      interval_amount,
      num_intervals,
      2,
    )

  let (payment_output, _subscriber_output) =
    create_base_outputs(
      payment_cs,
      interval_amount,
      remaining_amount,
      new_payment_datum,
    )

  let outputs = [merchant_output, payment_output]
  let lower_bound = current_time
  let upper_bound = lower_bound + 1
  let insert_timerange = tests.test_time_range(lower_bound, upper_bound)

  merchant_withdraw_test(
    total_subscription_fee_qty,
    outputs,
    service_cs,
    payment_datum,
    insert_timerange,
    service_tkn,
    merchant_tkn,
    account_tkn,
    subscriber_tkn,
  )
}

test succeed_unsubscribe() {
  let (
    current_time,
    interval_length,
    interval_amount,
    num_intervals,
    subscription_start,
    _subscription_end,
    _last_claimed,
    _total_subscription_fee_qty,
  ) = setup_config(12)
  let (payment_cs, account_cs, service_cs) = setup_policy_ids()
  let (payment_tx_hash, _service_tx_hash, _account_tx_hash) =
    setup_base_tx_hash()

  let script_output_ref = tests.test_input_utxo_02(payment_tx_hash)

  let (service_tkn, merchant_tkn, account_tkn, subscriber_tkn) =
    create_token_names()

  let penalty_fee_qty = 1_000_000

  // Calculate refund based on unclaimed intervals (matching validator logic)
  let time_since_start = math.max(current_time - subscription_start, 0)
  let intervals_passed = time_since_start / interval_length
  let claimed_intervals = math.min(intervals_passed, num_intervals)
  let remaining_intervals = num_intervals - claimed_intervals
  let refundable_amount = remaining_intervals * interval_amount
  // Subscriber should get refundable amount minus penalty
  let subscriber_refund = refundable_amount - penalty_fee_qty - 2_000_000

  let (
    payment_value,
    service_value,
    merchant_value,
    account_value,
    subscriber_value,
  ) =
    create_base_token_values_with_base(
      from_lovelace(refundable_amount),
      service_tkn,
      merchant_tkn,
      account_tkn,
      subscriber_tkn,
    )

  // let service_datum = create_base_service_datum(True)
  let payment_datum =
    create_base_payment_datum(
      subscription_start,
      interval_length,
      interval_amount,
      remaining_intervals,
    )

  let (
    payment_input,
    service_input,
    _merchant_input,
    _account_input,
    subscriber_input,
  ) =
    create_base_inputs(
      script_output_ref,
      payment_datum,
      payment_value,
      service_value,
      merchant_value,
      account_value,
      subscriber_value,
    )

  // Create refund output
  let refund_output =
    tests.test_utxo_02(account_cs, from_lovelace(subscriber_refund), 0, NoDatum)

  let penalty_value =
    add(
      from_lovelace(penalty_fee_qty + 2_000_000),
      payment_cs,
      payment_tokenname,
      1,
    )

  // Create penalty output
  let penalty_datum = tests.test_penalty_datum(service_tkn, subscriber_tkn)
  let penalty_output =
    tests.test_utxo_02(payment_cs, penalty_value, 0, Penalty(penalty_datum))

  let lower_bound = current_time - 1
  let upper_bound = lower_bound + 1

  let insert_timerange = tests.test_time_range(lower_bound, upper_bound)

  let inputs = [subscriber_input, payment_input]
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
  let (
    _current_time,
    interval_length,
    interval_amount,
    num_intervals,
    subscription_start,
    subscription_end,
    _last_claimed,
    total_subscription_fee_qty,
  ) = setup_config(12)
  let (payment_cs, account_cs, service_cs) = setup_policy_ids()
  let (payment_tx_hash, service_tx_hash, _account_tx_hash) =
    setup_base_tx_hash()

  let script_output_ref = tests.test_input_utxo_02(payment_tx_hash)

  let (service_tkn, merchant_tkn, account_tkn, subscriber_tkn) =
    create_token_names()

  // After subscription end
  let payment_datum =
    tests.test_datum_03(
      service_tkn,
      subscriber_tkn,
      subscription_start,
      subscription_end,
      subscription_end,
      interval_length,
      interval_amount,
      num_intervals,
      1,
    )

  // Service is inactive
  let service_datum = create_base_service_datum(False)
  let (
    payment_value,
    service_value,
    merchant_value,
    account_value,
    subscriber_value,
  ) =
    create_base_token_values_with_base(
      from_lovelace(total_subscription_fee_qty),
      service_tkn,
      merchant_tkn,
      account_tkn,
      subscriber_tkn,
    )

  let service_input =
    tests.test_context_input_02(
      tests.test_input_utxo_02(service_tx_hash),
      service_cs,
      service_value,
      service_datum,
    )
  let (
    payment_input,
    _service_input,
    _merchant_input,
    _account_input,
    subscriber_input,
  ) =
    create_base_inputs(
      script_output_ref,
      payment_datum,
      payment_value,
      service_value,
      merchant_value,
      account_value,
      subscriber_value,
    )

  let inputs = [subscriber_input, payment_input]
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
    add(zero, payment_cs, payment_tokenname, -1),
  )
}

test fail_initiate_missing_service_ref() fail {
  let (payment_cs, account_cs, service_cs) = setup_policy_ids()
  let (payment_tx_hash, _service_tx_hash, _account_tx_hash) =
    setup_base_tx_hash()
  let init_output_ref = tests.test_input_utxo_02(payment_tx_hash)

  let (
    current_time,
    interval_length,
    interval_amount,
    num_intervals,
    _subscription_start,
    _subscription_end,
    _last_claimed,
    total_subscription_fee_qty,
  ) = setup_config(12)
  let payment_datum =
    create_base_payment_datum(
      current_time,
      interval_length,
      interval_amount,
      num_intervals,
    )

  let (
    payment_value,
    service_value,
    merchant_value,
    account_value,
    subscriber_value,
  ) = create_base_token_values()

  let (
    _payment_input,
    _service_input,
    _merchant_input,
    account_input,
    subscriber_input,
  ) =
    create_base_inputs(
      init_output_ref,
      payment_datum,
      payment_value,
      service_value,
      merchant_value,
      account_value,
      subscriber_value,
    )

  let (payment_output, subscriber_output) =
    create_base_outputs(
      payment_cs,
      interval_amount,
      total_subscription_fee_qty,
      payment_datum,
    )

  let lower_bound = current_time - 5
  let upper_bound = current_time - 1
  let validity_range = tests.test_time_range(lower_bound, upper_bound)

  let mint = payment_value

  test_initiate_subscription(
    payment_cs,
    account_cs,
    service_cs,
    // Put in the incorrect input (account_input instead of service_input)
    account_input,
    subscriber_input,
    payment_output,
    subscriber_output,
    validity_range,
    mint,
  )
}

test fail_initiate_insufficient_funds() fail {
  let (payment_cs, account_cs, service_cs) = setup_policy_ids()
  let (payment_tx_hash, _service_tx_hash, _account_tx_hash) =
    setup_base_tx_hash()
  let init_output_ref = tests.test_input_utxo_02(payment_tx_hash)

  let (
    current_time,
    interval_length,
    interval_amount,
    num_intervals,
    _subscription_start,
    _subscription_end,
    _last_claimed,
    total_subscription_fee_qty,
  ) = setup_config(12)
  let payment_datum =
    create_base_payment_datum(
      current_time,
      interval_length,
      interval_amount,
      num_intervals,
    )
  let (
    payment_value,
    service_value,
    merchant_value,
    account_value,
    subscriber_value,
  ) = create_base_token_values()

  let (
    _payment_input,
    service_input,
    _merchant_input,
    _account_input,
    subscriber_input,
  ) =
    create_base_inputs(
      init_output_ref,
      payment_datum,
      payment_value,
      service_value,
      merchant_value,
      account_value,
      subscriber_value,
    )

  let (payment_output, subscriber_output) =
    create_base_outputs(
      payment_cs,
      interval_amount,
      // Reduce the output amount
      total_subscription_fee_qty / 2,
      payment_datum,
    )

  let lower_bound = current_time - 5
  let upper_bound = current_time - 1
  let validity_range = tests.test_time_range(lower_bound, upper_bound)

  let mint = payment_value

  test_initiate_subscription(
    payment_cs,
    account_cs,
    service_cs,
    service_input,
    subscriber_input,
    payment_output,
    subscriber_output,
    validity_range,
    mint,
  )
}

test fail_initiate_invalid_range() fail {
  let (payment_cs, account_cs, service_cs) = setup_policy_ids()
  let (payment_tx_hash, _service_tx_hash, _account_tx_hash) =
    setup_base_tx_hash()
  let init_output_ref = tests.test_input_utxo_02(payment_tx_hash)

  let (
    current_time,
    interval_length,
    interval_amount,
    num_intervals,
    _subscription_start,
    _subscription_end,
    _last_claimed,
    total_subscription_fee_qty,
  ) = setup_config(12)
  let payment_datum =
    create_base_payment_datum(
      current_time,
      interval_length,
      interval_amount,
      num_intervals,
    )

  let (
    payment_value,
    service_value,
    merchant_value,
    account_value,
    subscriber_value,
  ) = create_base_token_values()

  let (
    _payment_input,
    service_input,
    _merchant_input,
    _account_input,
    subscriber_input,
  ) =
    create_base_inputs(
      init_output_ref,
      payment_datum,
      payment_value,
      service_value,
      merchant_value,
      account_value,
      subscriber_value,
    )

  let (payment_output, subscriber_output) =
    create_base_outputs(
      payment_cs,
      interval_amount,
      total_subscription_fee_qty,
      payment_datum,
    )

  let lower_bound = current_time - 5
  // Change the upperbound range
  let upper_bound = current_time + 1
  let validity_range = tests.test_time_range(lower_bound, upper_bound)

  let (
    payment_value,
    _service_value,
    _merchant_tkn,
    _account_value,
    _subscriber_value,
  ) = create_base_token_values()

  test_initiate_subscription(
    payment_cs,
    account_cs,
    service_cs,
    service_input,
    subscriber_input,
    payment_output,
    subscriber_output,
    validity_range,
    payment_value,
  )
}

test fail_terminate_token_burn() fail {
  let payment_cs = tests.test_payment_cs()

  // Burn two tokens instead on one 
  let mint = add(zero, payment_cs, payment_tokenname, -2)
  validate_terminate_subscription(payment_cs, mint)
}

test fail_extend_insufficient_extension_funds() fail {
  let (
    current_time,
    interval_length,
    interval_amount,
    num_intervals,
    _subscription_start,
    _subscription_end,
    _last_claimed,
    total_subscription_fee_qty,
  ) = setup_config(1)
  let (payment_cs, _account_cs, service_cs) = setup_policy_ids()
  let (payment_tx_hash, _service_tx_hash, _account_tx_hash) =
    setup_base_tx_hash()

  let extend_output_ref = tests.test_input_utxo_02(payment_tx_hash)

  let (service_tkn, merchant_tkn, account_tkn, subscriber_tkn) =
    create_token_names()

  let (
    payment_value,
    service_value,
    merchant_value,
    account_value,
    subscriber_value,
  ) =
    create_base_token_values_with_base(
      from_lovelace(total_subscription_fee_qty),
      service_tkn,
      merchant_tkn,
      account_tkn,
      subscriber_tkn,
    )

  // Create the initial payment datum
  let payment_datum =
    create_base_payment_datum(
      current_time,
      interval_length,
      interval_amount,
      num_intervals,
    )
  let payment_input =
    tests.test_context_input_02(
      extend_output_ref,
      payment_cs,
      payment_value,
      Payment(payment_datum),
    )

  // Define extension parameters
  // 30 more days
  let extension_intervals = 6
  let extension_period = interval_length * extension_intervals

  let extension_fee = interval_amount * extension_intervals

  // Same as initial fee for simplicity
  // Create the new payment datum with extended period and increased fee
  let new_payment_datum: PaymentDatum =
    tests.test_datum_03(
      service_tkn,
      subscriber_tkn,
      current_time,
      payment_datum.subscription_end + extension_period,
      current_time + interval_length,
      interval_length,
      interval_amount,
      num_intervals + extension_intervals,
      1,
    )

  // Create the new payment output
  let payment_output =
    tests.test_utxo_02(
      payment_cs,
      payment_value,
      // Divide the extension fee by 2 to simulate less extension fee
      total_subscription_fee_qty + extension_fee / 2,
      Payment(new_payment_datum),
    )
  // Create a mock subscriber input (to pay for the extension)
  let subscriber_pkh = tests.test_224_04()
  // Assuming this function exists to generate a different hash
  let (
    _payment_input,
    service_input,
    _merchant_input,
    _account_input,
    subscriber_input,
  ) =
    create_base_inputs(
      extend_output_ref,
      payment_datum,
      payment_value,
      service_value,
      merchant_value,
      account_value,
      subscriber_value,
    )

  // Create a user output for change
  let change_amount = 3_000_000
  let subscriber_output =
    tests.test_user_utxo(subscriber_pkh, from_lovelace(change_amount), NoDatum)
  let reference_inputs = [service_input]
  let inputs = [subscriber_input, payment_input]
  let outputs = [subscriber_output, payment_output]

  validate_extend_subscription(
    extend_output_ref,
    service_cs,
    0,
    1,
    1,
    extension_intervals,
    Payment(payment_datum),
    reference_inputs,
    inputs,
    outputs,
  )
}

test fail_vesting_interval_tampering() fail {
  let (
    current_time,
    interval_length,
    interval_amount,
    num_intervals,
    subscription_start,
    subscription_end,
    last_claimed,
    total_subscription_fee_qty,
  ) = setup_config(12)
  let (payment_cs, _account_cs, service_cs) = setup_policy_ids()

  // Calculate withdrawable amount using stepped vesting
  let time_since_last_claim = math.max(current_time - last_claimed, 0)

  let intervals_passed = time_since_last_claim / interval_length
  let claimable_intervals = math.min(intervals_passed, num_intervals)
  let withdrawable_amount = interval_amount * claimable_intervals

  let (service_tkn, merchant_tkn, account_tkn, subscriber_tkn) =
    create_token_names()

  let payment_datum =
    create_base_payment_datum(
      subscription_start,
      interval_length,
      interval_amount,
      num_intervals,
    )

  // Calculate withdrawable amount (assuming half of the subscription period has passed)
  let actual_withdrawal = withdrawable_amount
  let merchant_output_value =
    add(from_lovelace(actual_withdrawal), service_cs, merchant_tkn, 1)

  // Create withdrawal output
  let merchant_output =
    tests.test_utxo_exact(service_cs, merchant_output_value, NoDatum)

  // Create remaining funds output (if any)
  let remaining_amount = total_subscription_fee_qty - actual_withdrawal

  let new_payment_datum =
    tests.test_datum_03(
      service_tkn,
      subscriber_tkn,
      subscription_start,
      subscription_end,
      subscription_end,
      interval_length,
      interval_amount,
      // Try to influence the number of intervals
      16,
      2,
    )

  let (payment_output, _subscriber_output) =
    create_base_outputs(
      payment_cs,
      interval_amount,
      remaining_amount,
      new_payment_datum,
    )

  let outputs = [merchant_output, payment_output]
  let lower_bound = current_time
  let upper_bound = lower_bound + 1
  let insert_timerange = tests.test_time_range(lower_bound, upper_bound)

  merchant_withdraw_test(
    total_subscription_fee_qty,
    outputs,
    service_cs,
    payment_datum,
    insert_timerange,
    service_tkn,
    merchant_tkn,
    account_tkn,
    subscriber_tkn,
  )
}

test fail_merchant_withdraw_unauthorized() fail {
  let (
    current_time,
    interval_length,
    interval_amount,
    num_intervals,
    subscription_start,
    subscription_end,
    last_claimed,
    total_subscription_fee_qty,
  ) = setup_config(12)
  let (payment_cs, _account_cs, service_cs) = setup_policy_ids()
  let (payment_tx_hash, _service_tx_hash, _account_tx_hash) =
    setup_base_tx_hash()

  let script_output_ref = tests.test_input_utxo_02(payment_tx_hash)

  // Calculate withdrawable amount using stepped vesting
  let time_since_last_claim = math.max(current_time - last_claimed, 0)

  let intervals_passed = time_since_last_claim / interval_length
  let claimable_intervals = math.min(intervals_passed, num_intervals)
  let withdrawable_amount = interval_amount * claimable_intervals

  let (service_tkn, merchant_tkn, account_tkn, subscriber_tkn) =
    create_token_names()

  let payment_datum =
    create_base_payment_datum(
      subscription_start,
      interval_length,
      interval_amount,
      num_intervals,
    )

  let (
    payment_value,
    service_value,
    _merchant_value,
    account_value,
    subscriber_value,
  ) =
    create_base_token_values_with_base(
      from_lovelace(total_subscription_fee_qty),
      service_tkn,
      merchant_tkn,
      account_tkn,
      subscriber_tkn,
    )

  let merchant_value =
    add(
      from_lovelace(total_subscription_fee_qty),
      service_cs,
      // Incorrect token name merchant_tkn
      service_tkn,
      1,
    )

  let (
    payment_input,
    service_input,
    merchant_input,
    _account_input,
    _subscriber_value,
  ) =
    create_base_inputs(
      script_output_ref,
      payment_datum,
      payment_value,
      service_value,
      merchant_value,
      account_value,
      subscriber_value,
    )

  // Calculate withdrawable amount (assuming half of the subscription period has passed)
  let actual_withdrawal = withdrawable_amount
  let merchant_output_value =
    add(from_lovelace(actual_withdrawal), service_cs, merchant_tkn, 1)

  // Create withdrawal output
  let merchant_output =
    tests.test_utxo_exact(service_cs, merchant_output_value, NoDatum)

  // Create remaining funds output (if any)
  let remaining_amount = total_subscription_fee_qty - actual_withdrawal

  let new_payment_datum =
    tests.test_datum_03(
      service_tkn,
      subscriber_tkn,
      subscription_start,
      subscription_end,
      subscription_end,
      interval_length,
      interval_amount,
      num_intervals,
      2,
    )

  let (payment_output, _subscriber_output) =
    create_base_outputs(
      payment_cs,
      interval_amount,
      remaining_amount,
      new_payment_datum,
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

test fail_merchant_withdraw_early() fail {
  let (
    current_time,
    interval_length,
    interval_amount,
    num_intervals,
    subscription_start,
    subscription_end,
    last_claimed,
    total_subscription_fee_qty,
  ) = setup_config(12)
  let (payment_cs, _account_cs, service_cs) = setup_policy_ids()
  let (payment_tx_hash, service_tx_hash, _account_tx_hash) =
    setup_base_tx_hash()

  let script_output_ref = tests.test_input_utxo_02(payment_tx_hash)

  let (service_tkn, merchant_tkn, _account_tkn, subscriber_tkn) =
    create_token_names()

  let payment_datum =
    create_base_payment_datum(
      subscription_start,
      interval_length,
      interval_amount,
      num_intervals,
    )

  // Calculate withdrawable amount using stepped vesting
  let time_since_last_claim = math.max(current_time - last_claimed, 0)

  let intervals_passed = time_since_last_claim / interval_length
  let claimable_intervals = math.min(intervals_passed, num_intervals)
  let withdrawable_amount = interval_amount * claimable_intervals

  let service_datum = create_base_service_datum(True)

  let payment_value =
    add(
      from_lovelace(total_subscription_fee_qty),
      payment_cs,
      payment_tokenname,
      1,
    )
  let service_value =
    add(from_lovelace(total_subscription_fee_qty), service_cs, service_tkn, 1)

  let merchant_value =
    add(from_lovelace(total_subscription_fee_qty), service_cs, merchant_tkn, 1)

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
      payment_cs,
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
    add(from_lovelace(actual_withdrawal), service_cs, merchant_tkn, 1)

  // Create withdrawal output
  let merchant_output =
    tests.test_utxo_exact(service_cs, merchant_output_value, NoDatum)

  // Create remaining funds output (if any)
  let remaining_amount = total_subscription_fee_qty - actual_withdrawal

  let new_payment_datum =
    tests.test_datum_03(
      service_tkn,
      subscriber_tkn,
      subscription_start,
      subscription_end,
      subscription_end,
      interval_length,
      interval_amount,
      num_intervals,
      2,
    )

  let (payment_output, _subscriber_output) =
    create_base_outputs(
      payment_cs,
      interval_amount,
      remaining_amount,
      new_payment_datum,
    )

  // Try to withdraw before current_time
  let lower_bound = current_time - 10000
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

test fail_merchant_overwithdraw() fail {
  let (
    current_time,
    interval_length,
    interval_amount,
    num_intervals,
    subscription_start,
    subscription_end,
    last_claimed,
    total_subscription_fee_qty,
  ) = setup_config(12)
  let (payment_cs, _account_cs, service_cs) = setup_policy_ids()
  let (payment_tx_hash, _service_tx_hash, _account_tx_hash) =
    setup_base_tx_hash()

  let script_output_ref = tests.test_input_utxo_02(payment_tx_hash)

  let (service_tkn, merchant_tkn, account_tkn, subscriber_tkn) =
    create_token_names()

  let payment_datum =
    create_base_payment_datum(
      subscription_start,
      interval_length,
      interval_amount,
      num_intervals,
    )

  // Calculate withdrawable amount using stepped vesting
  let time_since_last_claim = math.max(current_time - last_claimed, 0)

  let intervals_passed = time_since_last_claim / interval_length
  let claimable_intervals = math.min(intervals_passed, num_intervals)
  let withdrawable_amount = interval_amount * claimable_intervals

  let (
    payment_value,
    service_value,
    merchant_value,
    account_value,
    subscriber_value,
  ) =
    create_base_token_values_with_base(
      from_lovelace(total_subscription_fee_qty),
      service_tkn,
      merchant_tkn,
      account_tkn,
      subscriber_tkn,
    )

  let (
    payment_input,
    service_input,
    merchant_input,
    _account_input,
    _subscriber_value,
  ) =
    create_base_inputs(
      script_output_ref,
      payment_datum,
      payment_value,
      service_value,
      merchant_value,
      account_value,
      subscriber_value,
    )

  // Set installments_withdrawn to more than available (overwithdraw).
  let overwithdraw_installments = num_intervals + 1

  // Calculate withdrawable amount (assuming half of the subscription period has passed)
  let actual_withdrawal = withdrawable_amount * overwithdraw_installments
  let merchant_output_value =
    add(from_lovelace(actual_withdrawal), service_cs, merchant_tkn, 1)

  // Create withdrawal output
  let merchant_output =
    tests.test_utxo_exact(service_cs, merchant_output_value, NoDatum)

  // Create remaining funds output (if any)
  let remaining_amount = total_subscription_fee_qty - actual_withdrawal

  let new_payment_datum =
    tests.test_datum_03(
      service_tkn,
      subscriber_tkn,
      subscription_start,
      subscription_end,
      subscription_end,
      interval_length,
      interval_amount,
      num_intervals,
      2,
    )

  let (payment_output, _subscriber_output) =
    create_base_outputs(
      payment_cs,
      interval_amount,
      remaining_amount,
      new_payment_datum,
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

//When unsubscribing early, the subscriber must pay a penalty. If that penalty output is missing or underfunded, the transaction must be rejected.
test fail_unsubscribe_penalty_not_paid() fail {
  let (
    current_time,
    interval_length,
    interval_amount,
    num_intervals,
    subscription_start,
    _subscription_end,
    _last_claimed,
    _total_subscription_fee_qty,
  ) = setup_config(12)
  let (payment_cs, account_cs, service_cs) = setup_policy_ids()
  let (payment_tx_hash, _service_tx_hash, _account_tx_hash) =
    setup_base_tx_hash()

  let script_output_ref = tests.test_input_utxo_02(payment_tx_hash)

  let (service_tkn, merchant_tkn, account_tkn, subscriber_tkn) =
    create_token_names()

  let penalty_fee_qty = 1_000_000

  // Calculate refund based on unclaimed intervals (matching validator logic)
  let time_since_start = math.max(current_time - subscription_start, 0)
  let intervals_passed = time_since_start / interval_length
  let claimed_intervals = math.min(intervals_passed, num_intervals)
  let remaining_intervals = num_intervals - claimed_intervals
  let refundable_amount = remaining_intervals * interval_amount
  // Subscriber should get refundable amount minus penalty
  let subscriber_refund = refundable_amount - penalty_fee_qty - 2_000_000

  let (
    payment_value,
    service_value,
    merchant_value,
    account_value,
    subscriber_value,
  ) =
    create_base_token_values_with_base(
      from_lovelace(refundable_amount),
      service_tkn,
      merchant_tkn,
      account_tkn,
      subscriber_tkn,
    )

  // let service_datum = create_base_service_datum(True)
  let payment_datum =
    create_base_payment_datum(
      subscription_start,
      interval_length,
      interval_amount,
      remaining_intervals,
    )

  let (
    payment_input,
    service_input,
    _merchant_input,
    _account_input,
    subscriber_input,
  ) =
    create_base_inputs(
      script_output_ref,
      payment_datum,
      payment_value,
      service_value,
      merchant_value,
      account_value,
      subscriber_value,
    )

  let refund_output =
    tests.test_utxo_02(account_cs, from_lovelace(subscriber_refund), 0, NoDatum)

  let penalty_value =
    add(
      // In this test, purposely omit or underfund the penalty output.
      from_lovelace(penalty_fee_qty - 500_000),
      payment_cs,
      payment_tokenname,
      1,
    )

  // Create penalty output
  let penalty_datum = tests.test_penalty_datum(service_tkn, subscriber_tkn)
  let penalty_output =
    tests.test_utxo_02(payment_cs, penalty_value, 0, Penalty(penalty_datum))

  let lower_bound = current_time - 1
  let upper_bound = lower_bound + 1

  let insert_timerange = tests.test_time_range(lower_bound, upper_bound)

  let inputs = [subscriber_input, payment_input]
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

test fail_unsubscribe_missing_subscriber_nft() fail {
  let (
    current_time,
    interval_length,
    interval_amount,
    num_intervals,
    subscription_start,
    _subscription_end,
    _last_claimed,
    _total_subscription_fee_qty,
  ) = setup_config(12)
  let (payment_cs, account_cs, service_cs) = setup_policy_ids()
  let (payment_tx_hash, _service_tx_hash, _account_tx_hash) =
    setup_base_tx_hash()

  let script_output_ref = tests.test_input_utxo_02(payment_tx_hash)

  let (service_tkn, merchant_tkn, account_tkn, subscriber_tkn) =
    create_token_names()

  let penalty_fee_qty = 1_000_000

  // Calculate refund based on unclaimed intervals (matching validator logic)
  let time_since_start = math.max(current_time - subscription_start, 0)
  let intervals_passed = time_since_start / interval_length
  let claimed_intervals = math.min(intervals_passed, num_intervals)
  let remaining_intervals = num_intervals - claimed_intervals
  let refundable_amount = remaining_intervals * interval_amount
  // Subscriber should get refundable amount minus penalty
  let subscriber_refund = refundable_amount - penalty_fee_qty - 2_000_000

  let (
    payment_value,
    service_value,
    merchant_value,
    account_value,
    subscriber_value,
  ) =
    create_base_token_values_with_base(
      from_lovelace(refundable_amount),
      service_tkn,
      merchant_tkn,
      account_tkn,
      //Input incorrect subscriber insead of merchant
      merchant_tkn,
    )

  // let service_datum = create_base_service_datum(True)
  let payment_datum =
    create_base_payment_datum(
      subscription_start,
      interval_length,
      interval_amount,
      remaining_intervals,
    )

  let (
    payment_input,
    service_input,
    _merchant_input,
    _account_input,
    subscriber_input,
  ) =
    create_base_inputs(
      script_output_ref,
      payment_datum,
      payment_value,
      service_value,
      merchant_value,
      account_value,
      subscriber_value,
    )

  // Create refund output
  let refund_output =
    tests.test_utxo_02(account_cs, from_lovelace(subscriber_refund), 0, NoDatum)

  let penalty_value =
    add(
      from_lovelace(penalty_fee_qty + 2_000_000),
      payment_cs,
      payment_tokenname,
      1,
    )

  // Create penalty output
  let penalty_datum = tests.test_penalty_datum(service_tkn, subscriber_tkn)
  let penalty_output =
    tests.test_utxo_02(payment_cs, penalty_value, 0, Penalty(penalty_datum))

  let lower_bound = current_time - 1
  let upper_bound = lower_bound + 1

  let insert_timerange = tests.test_time_range(lower_bound, upper_bound)

  let inputs = [subscriber_input, payment_input]
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

// Withdraw while service.active=True
test fail_subscriber_withdraw_active_service() fail {
  let (
    _current_time,
    interval_length,
    interval_amount,
    num_intervals,
    subscription_start,
    subscription_end,
    _last_claimed,
    total_subscription_fee_qty,
  ) = setup_config(12)
  let (payment_cs, account_cs, service_cs) = setup_policy_ids()
  let (payment_tx_hash, service_tx_hash, _account_tx_hash) =
    setup_base_tx_hash()

  let script_output_ref = tests.test_input_utxo_02(payment_tx_hash)

  let (service_tkn, merchant_tkn, account_tkn, subscriber_tkn) =
    create_token_names()

  // After subscription end
  let payment_datum =
    tests.test_datum_03(
      service_tkn,
      subscriber_tkn,
      subscription_start,
      subscription_end,
      subscription_end,
      interval_length,
      interval_amount,
      num_intervals,
      1,
    )

  // Change Service Active state to True to force a fail.
  let service_datum = create_base_service_datum(True)
  let (
    payment_value,
    service_value,
    merchant_value,
    account_value,
    subscriber_value,
  ) =
    create_base_token_values_with_base(
      from_lovelace(total_subscription_fee_qty),
      service_tkn,
      merchant_tkn,
      account_tkn,
      subscriber_tkn,
    )

  let service_input =
    tests.test_context_input_02(
      tests.test_input_utxo_02(service_tx_hash),
      service_cs,
      service_value,
      service_datum,
    )
  let (
    payment_input,
    _service_input,
    _merchant_input,
    _account_input,
    subscriber_input,
  ) =
    create_base_inputs(
      script_output_ref,
      payment_datum,
      payment_value,
      service_value,
      merchant_value,
      account_value,
      subscriber_value,
    )

  let inputs = [subscriber_input, payment_input]
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
    add(zero, payment_cs, payment_tokenname, -1),
  )
}
