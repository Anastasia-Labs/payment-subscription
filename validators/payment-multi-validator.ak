use aiken/cbor
use aiken/dict
use aiken/interval.{Finite, Interval, IntervalBound}
use aiken/list
use aiken/math
use aiken/transaction.{
  Input, Mint, NoDatum, Output, OutputReference, ScriptContext, Spend,
  Transaction, TransactionId,
}
use aiken/transaction/credential
use aiken/transaction/value.{from_minted_value}
use assist/data
use assist/types/cip68
use assist/values
use payment_subscription/tests/tests
use payment_subscription/types.{
  AssetClass, Extend, InitSubscripton, MintPayment, Payment, PaymentDatum,
  PaymentValidatorDatum, Penalty, PenaltyDatum, ServiceDatum, SpendPayment,
  TerminateSubscription, Unsubscribe, Withdraw,
}
use payment_subscription/utils.{
  get_minimum_current_time_estimate, get_reference_input_by_token,
  must_be_after_deadline, validate_single_nft_input, validate_token_output,
}

// TODO: Multiplier for the Discount and the Penalty. The longer you pay, the less the penalty (Last).
// TODO: Ensure deadline for withdrawing when Service NFT has been removed. (Later)
// TODO: Allow staking rewards for the subscriber (Later)
// TODO: Allow Deadline for dormant subscription fees (After 90 days, subscriber can collect the funds from the payment validator)
// TODO: Update with stake validator, multi-utxo-indexer-example (withdraw-zero trick) 
validator(service_policy_id: ByteArray, account_policy_id: ByteArray) {
  fn mint_payment(redeemer: MintPayment, ctx: ScriptContext) -> Bool {
    let ScriptContext { transaction: tx, purpose } = ctx
    expect Mint(own_policy) = purpose
    let Transaction { inputs, reference_inputs, mint, outputs, .. } = tx

    let minted_tokens = mint |> from_minted_value()
    let payment_payment_credential = credential.ScriptCredential(own_policy)
    when redeemer is {
      InitSubscripton { output_reference, input_index } -> {
        // Ensure this outref is spent in this transaction
        expect Some(account_input) = list.at(inputs, input_index)
        // Find the service reference input by searching for the token policy
        expect Some(service_ref_input) =
          get_reference_input_by_token(reference_inputs, service_policy_id)
        expect [user_output, payment_output, ..] = outputs

        // Extract datums
        expect payment_datum: PaymentDatum = data.output_datum(payment_output)
        expect service_datum: ServiceDatum =
          data.output_datum(service_ref_input.output)

        // Create a unique token name
        let payment_tkn =
          values.unique_token_name(
            output_reference.transaction_id.hash,
            output_reference.output_index,
            #"",
          )
        // Construct one Payment token value 
        let payment_value = value.from_asset(own_policy, payment_tkn, 1)

        // Validate internal consistency of payment datum
        let internal_datum_valid =
          validate_payment_datum_internal(payment_datum)
        // Validate the datum from the Service Contract as a reference input.
        let datum_against_service_valid =
          validate_payment_against_service(payment_datum, service_datum)

        // Check to ensure the subscription period matches the service's requirements
        let subscription_period_valid =
          payment_datum.subscription_period == service_datum.subscription_period

        // Verify the inputs contain 1 Service NFT Asset
        let input_has_service_nft =
          validate_single_nft_input(
            service_ref_input,
            service_policy_id,
            payment_datum.service_nft_tn,
          )

        // Verify the inputs contain 1 Account NFT Asset
        let input_has_account_nft =
          validate_single_nft_input(
            account_input,
            account_policy_id,
            payment_datum.account_nft_tn,
          )

        // Verify the correct amount is locked
        let locked_amount =
          value.quantity_of(
            payment_output.value,
            payment_datum.subscription_fee.policy_id,
            payment_datum.subscription_fee.asset_name,
          )
        let expected_amount = payment_datum.subscription_fee_qty

        let locked_amount_valid = locked_amount >= expected_amount
        // Ensure user output DOES NOT go back to the script
        let user_token_not_to_script =
          validate_token_output(
            user_output,
            account_policy_id,
            payment_datum.account_nft_tn,
            payment_payment_credential,
            False,
          )

        // Ensure token output goes back to the script
        let payment_token_to_script =
          validate_token_output(
            payment_output,
            own_policy,
            payment_tkn,
            payment_payment_credential,
            True,
          )

        and {
          // Validate that out_ref must be present in the Transaction Inputs.
          (account_input.output_reference == output_reference)?,
          input_has_service_nft?,
          input_has_account_nft?,
          internal_datum_valid?,
          datum_against_service_valid?,
          (payment_value == minted_tokens)?,
          locked_amount_valid?,
          user_token_not_to_script?,
          payment_token_to_script?,
          subscription_period_valid?,
        }
      }

      TerminateSubscription -> {
        // Find the input that's being spent (the one containing our NFT)
        expect [account_input, payment_input, ..] = tx.inputs

        // Extract the payment datum from the input
        expect payment_datum: PaymentDatum =
          data.output_datum(payment_input.output)

        // Verify the account NFT
        let account_nft = account_input.output.value |> value.without_lovelace()

        let has_account_nft =
          value.quantity_of(
            account_nft,
            account_policy_id,
            payment_datum.account_nft_tn,
          ) == 1

        // Extract the NFT from the input
        let payment_nft =
          payment_input.output.value
            |> value.without_lovelace()
            |> value.flatten()

        // Ensure there's exactly one token and extract its details
        expect [(token_policy, token_name, _)] = payment_nft

        // Get the tokens being minted (or burned) in this transaction
        expect [(pid, tkn, amt)] = value.flatten(minted_tokens)

        // Verify all conditions are met
        and {
          has_account_nft?,
          // The token in the input must be from our policy
          (token_policy == own_policy)?,
          // The token being burned must be from our policy
          (pid == own_policy)?,
          // The token name being burned must match the one from the input
          (tkn == token_name)?,
          // Exactly one token must be burned (negative amount)
          (amt == -1)?,
        }
      }
    }
  }

  fn spend_payment(
    datum: PaymentValidatorDatum,
    redeemer: SpendPayment,
    ctx: ScriptContext,
  ) -> Bool {
    let ScriptContext { transaction: tx, purpose } = ctx
    expect Spend(_output_reference) = purpose

    when redeemer is {
      Extend -> validate_extend(service_policy_id, account_policy_id, datum, tx)
      Unsubscribe ->
        validate_unsubscribe(service_policy_id, account_policy_id, datum, tx)
      Withdraw -> validate_withdraw(service_policy_id, datum, tx)
    }
  }
}

fn validate_extend(
  service_policy_id: ByteArray,
  account_policy_id: ByteArray,
  datum: PaymentValidatorDatum,
  tx: Transaction,
) -> Bool {
  when datum is {
    Payment(payment_datum) -> {
      // Find the input being spent (current Payment Validator UTxO)
      expect [account_input, payment_input, ..] = tx.inputs
      // Find the service reference input by searching for the token policy
      expect Some(service_ref_input) =
        get_reference_input_by_token(tx.reference_inputs, service_policy_id)
      // Find the new payment output
      expect [_account_output, payment_output, ..] = tx.outputs

      // The script credential is part of the address of the input being spent
      let payment_script_credential =
        payment_input.output.address.payment_credential
      // Extract the datums
      expect service_datum: ServiceDatum =
        data.output_datum(service_ref_input.output)
      expect new_datum: PaymentDatum = data.output_datum(payment_output)

      let payment_addr = payment_input.output.address

      // Extract the payment NFT from the input
      let payment_nft = payment_input.output.value |> value.without_lovelace()
      expect [(policy_id, asset_name, 1)] = value.flatten(payment_nft)

      // Validate the datum from the Service Contract as a reference input.
      let datum_against_service_valid =
        validate_payment_against_service(payment_datum, service_datum)

      // Verify the new payment output
      let original_amount = value.lovelace_of(payment_input.output.value)
      let new_amount = value.lovelace_of(payment_output.value)
      let amount_increased = new_amount >= original_amount
      let extension_amount = new_amount - original_amount

      // Calculate and validate the fee increase
      let extension_period =
        new_datum.subscription_end - payment_datum.subscription_end
      let service_fee_rate =
        service_datum.service_fee_qty / service_datum.subscription_period
      let minimum_expected_fee_increase = extension_period * service_fee_rate

      // Fee increase validation
      let actual_fee_increase = new_amount - original_amount
      let fee_increase_valid =
        actual_fee_increase >= minimum_expected_fee_increase

      // Verify the inputs contain 1 Account NFT Asset
      let input_has_account_nft =
        validate_single_nft_input(
          account_input,
          account_policy_id,
          payment_datum.account_nft_tn,
        )

      let script_input_has_payment_nft =
        validate_single_nft_input(payment_input, policy_id, asset_name)

      // Validate that the extension follows the Service provider rules
      let valid_extension =
        validate_extension_datum(
          payment_datum,
          new_datum,
          extension_amount,
          service_datum,
        )

      let correct_output_address = payment_output.address == payment_addr

      // Ensure token output goes back to the script
      let payment_token_to_script =
        validate_token_output(
          payment_output,
          policy_id,
          asset_name,
          payment_script_credential,
          True,
        )

      and {
        input_has_account_nft?,
        script_input_has_payment_nft?,
        datum_against_service_valid?,
        amount_increased?,
        valid_extension?,
        fee_increase_valid?,
        payment_token_to_script?,
        correct_output_address?,
      }
    }
    Penalty(_) -> False
  }
}

// Validate that the logic follows the Service provider rules / datum as a refernce input to ensure the
// penalty goes to the merchant when paying the penalty fees.
fn validate_unsubscribe(
  service_policy_id: ByteArray,
  account_policy_id: ByteArray,
  datum: PaymentValidatorDatum,
  tx: Transaction,
) -> Bool {
  when datum is {
    Payment(payment_datum) -> {
      // Find the inputs being spent (current Payment Validator UTxO)
      expect [account_input, payment_input, ..] = tx.inputs
      // Find the service reference input by searching for the token policy
      expect Some(service_ref_input) =
        get_reference_input_by_token(tx.reference_inputs, service_policy_id)

      let payment_script_credential =
        payment_input.output.address.payment_credential

      // Verify the inputs contain 1 Account NFT Asset
      let input_has_account_nft =
        validate_single_nft_input(
          account_input,
          account_policy_id,
          payment_datum.account_nft_tn,
        )
      let payment_nft = payment_input.output.value |> value.without_lovelace()
      expect [(policy_id, asset_name, 1)] = value.flatten(payment_nft)

      // Verify Penalty UTxO is created
      expect [account_output, penalty_output, ..] = tx.outputs

      let current_time = get_minimum_current_time_estimate(tx.validity_range)
      let total_subscription_time =
        payment_datum.subscription_end - payment_datum.subscription_start
      let time_elapsed =
        math.min(
          current_time - payment_datum.subscription_start,
          total_subscription_time,
        )
      let refund_amount =
        payment_datum.subscription_fee_qty * (
          total_subscription_time - time_elapsed
        ) / total_subscription_time

      // Verify refund output to subscriber
      let refund_output_valid =
        value.quantity_of(
          account_output.value,
          payment_datum.subscription_fee.policy_id,
          payment_datum.subscription_fee.asset_name,
        ) >= refund_amount
      let payment_nft_in_penalty_output =
        value.quantity_of(penalty_output.value, policy_id, asset_name) == 1
      // Extract the datums
      expect service_datum: ServiceDatum =
        data.output_datum(service_ref_input.output)

      let payment_datum_valid =
        validate_payment_against_service(payment_datum, service_datum)

      // Verify Penalty UTxO
      expect penalty: PenaltyDatum = data.output_datum(penalty_output)
      let penalty_output_valid =
        penalty.service_nft_tn == payment_datum.service_nft_tn && penalty.account_nft_tn == payment_datum.account_nft_tn && payment_datum.penalty_fee_qty == penalty.penalty_fee_qty && penalty.penalty_fee_qty == service_datum.penalty_fee_qty

      // Ensure token output goes back to the script
      let payment_token_to_script =
        validate_token_output(
          penalty_output,
          policy_id,
          asset_name,
          payment_script_credential,
          True,
        )
      and {
        input_has_account_nft?,
        payment_datum_valid?,
        refund_output_valid?,
        penalty_output_valid?,
        payment_nft_in_penalty_output?,
        payment_token_to_script?,
      }
    }
    Penalty(_) -> False
  }
}

// Updated validate_withdraw function with linear vesting
fn validate_withdraw(
  service_policy_id: ByteArray,
  datum: PaymentValidatorDatum,
  tx: Transaction,
) -> Bool {
  when datum is {
    Payment(payment_datum) -> {
      expect [merchant_input, payment_input, ..] = tx.inputs
      let payment_addr = payment_input.output.address

      let has_service_nft =
        value.quantity_of(
          merchant_input.output.value,
          service_policy_id,
          payment_datum.service_nft_tn,
        ) == 1

      // Verify the Service datum from reference input
      expect [service_input, ..] = tx.reference_inputs
      expect service_datum: ServiceDatum =
        data.output_datum(service_input.output)

      // Validate payment datum against service datum
      let payment_datum_valid =
        validate_payment_against_service(payment_datum, service_datum)
      // Get the current time
      let current_time = get_minimum_current_time_estimate(tx.validity_range)

      // Calculate vesting-related values
      let total_subscription_time =
        payment_datum.subscription_end - payment_datum.subscription_start
      let time_elapsed =
        math.min(
          current_time - payment_datum.last_claimed,
          total_subscription_time,
        )
      // Calculate withdrawable amount using linear vesting
      let withdrawable_amount =
        payment_datum.subscription_fee_qty * time_elapsed / total_subscription_time

      expect [merchant_output, payment_output, ..] = tx.outputs

      // Verify withdrawal amount
      // This is the amount of funds that the merchant is actually withdrawing in the current transaction.
      // It represents the portion of the vested funds that the merchant chooses to withdraw.
      let actual_withdrawal_amount =
        value.quantity_of(
          merchant_output.value,
          payment_datum.subscription_fee.policy_id,
          payment_datum.subscription_fee.asset_name,
        )
      let withdrawal_amount_valid =
        actual_withdrawal_amount <= withdrawable_amount

      // Update the last_claimed field in the new datum
      expect new_datum: PaymentDatum = data.output_datum(payment_output)
      let last_claimed_updated = new_datum.last_claimed == current_time

      // Verify that the Payment NFT is preserved
      let payment_nft_preserved =
        value.quantity_of(
          merchant_output.value,
          service_policy_id,
          payment_datum.service_nft_tn,
        ) == 1

      // Verify that any remaining funds are returned to the payment validator
      // This is the amount of funds that should be left in the payment script after the withdrawal.
      let remaining_amount =
        payment_datum.subscription_fee_qty - actual_withdrawal_amount
      let remaining_funds_returned =
        value.quantity_of(
          payment_output.value,
          payment_datum.subscription_fee.policy_id,
          payment_datum.subscription_fee.asset_name,
        ) >= remaining_amount

      and {
        has_service_nft?,
        payment_datum_valid?,
        must_be_after_deadline(
          tx.validity_range,
          payment_datum.subscription_start,
        )?,
        withdrawal_amount_valid?,
        payment_nft_preserved?,
        remaining_funds_returned?,
        last_claimed_updated?,
        (payment_output.address == payment_addr)?,
      }
    }

    Penalty(penalty_datum) -> {
      expect [merchant_input, payment_input, ..] = tx.inputs
      expect [merchant_output, ..] = tx.outputs
      let payment_nft = payment_input.output.value |> value.without_lovelace()
      expect [(policy_id, asset_name, 1)] = value.flatten(payment_nft)

      // Verify that the merchant has the Service NFT
      let has_service_nft =
        value.quantity_of(
          merchant_input.output.value,
          service_policy_id,
          penalty_datum.service_nft_tn,
        ) == 1

      // Verify the penalty input
      let penalty_input_valid =
        validate_single_nft_input(payment_input, policy_id, asset_name)

      // Verify the penalty amount in the input
      let penalty_input_amount_valid =
        value.quantity_of(
          payment_input.output.value,
          penalty_datum.penalty_fee.policy_id,
          penalty_datum.penalty_fee.asset_name,
        ) == penalty_datum.penalty_fee_qty

      // Verify withdrawal of penalty to merchant
      let penalty_withdrawal_valid =
        value.quantity_of(
          merchant_output.value,
          penalty_datum.penalty_fee.policy_id,
          penalty_datum.penalty_fee.asset_name,
        ) == penalty_datum.penalty_fee_qty

      // Verify the Penalty NFT is burned
      let penalty_nft_burned =
        value.quantity_of(
          value.from_minted_value(tx.mint),
          service_policy_id,
          penalty_datum.service_nft_tn,
        ) == -1

      and {
        has_service_nft?,
        penalty_input_valid?,
        penalty_input_amount_valid?,
        penalty_withdrawal_valid?,
        penalty_nft_burned?,
      }
    }
  }
}

fn validate_extension_datum(
  old_datum: PaymentDatum,
  new_datum: PaymentDatum,
  extension_amount: Int,
  service_datum: ServiceDatum,
) -> Bool {
  let unchanged_fields_valid =
    old_datum.service_nft_tn == new_datum.service_nft_tn && old_datum.account_nft_tn == new_datum.account_nft_tn && old_datum.subscription_start == new_datum.subscription_start

  let extension_period = new_datum.subscription_end - old_datum.subscription_end
  let period_extension_valid =
    extension_period >= service_datum.subscription_period

  // Updated calculation
  let expected_fee_increase =
    extension_period * service_datum.service_fee_qty / service_datum.subscription_period

  let fee_increase_valid = extension_amount >= expected_fee_increase

  let valid_end_date = new_datum.subscription_end > new_datum.subscription_start

  // Validate that the extension follows the Service provider rules
  let follows_service_rules =
    new_datum.subscription_fee == service_datum.service_fee && new_datum.subscription_period % service_datum.subscription_period == 0

  and {
    unchanged_fields_valid?,
    period_extension_valid?,
    fee_increase_valid?,
    valid_end_date?,
    follows_service_rules?,
  }
}

// Helper function to validate internal payment datum
fn validate_payment_datum_internal(datum: PaymentDatum) -> Bool {
  let time_valid =
    datum.subscription_start < datum.subscription_end && datum.last_claimed <= datum.subscription_start

  let amounts_valid =
    datum.subscription_fee_qty > 0 && datum.penalty_fee_qty >= 0

  let period_valid =
    datum.subscription_end - datum.subscription_start == datum.subscription_period && datum.subscription_period > 0

  time_valid && amounts_valid && period_valid
}

// Helper function to validate payment datum against Service contract
fn validate_payment_against_service(
  payment: PaymentDatum,
  service: ServiceDatum,
) -> Bool {
  let subscription_period_valid =
    payment.subscription_period == service.subscription_period
  let service_fee_valid =
    payment.subscription_fee == service.service_fee && payment.subscription_fee_qty == service.service_fee_qty
  let penalty_fee_valid =
    payment.penalty_fee == service.penalty_fee && payment.penalty_fee_qty == service.penalty_fee_qty

  subscription_period_valid && service_fee_valid && penalty_fee_valid
}

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
  let subscription_period = 30 * 24 * 60 * 60 * 1000

  // let service_fee_qty = 10_000_000
  let penalty_qty = 1_000_000
  // 30 days in milliseconds
  let service_datum = tests.test_service_datum()

  let payment_fee_qty = 10_000_000

  let payment_datum =
    tests.test_datum_03(
      service_tkn,
      user_account_tkn,
      payment_fee_qty,
      current_time,
      current_time + subscription_period,
      subscription_period,
      last_claimed,
      penalty_qty,
    )
  let redeemer =
    InitSubscripton { output_reference: init_output_ref, input_index }

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
  let user_output = tests.test_utxo_02(user_pubkey_hash, account_value, NoDatum)
  let payment_output = tests.test_utxo_02(own_cs, payment_value, payment_datum)

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

  trace @"Test: Initiating a New Subscription"
  trace @"-------------------------------------"

  trace @"Step 1: Setting up the subscription"
  trace @"-------------------------------------"
  trace @"Service Currency Symbol:"
  trace cbor.diagnostic(service_cs)
  trace @"Account Currency Symbol:"
  trace cbor.diagnostic(account_cs)
  trace @"Subscription Fee: (lovelace)"
  trace cbor.diagnostic(payment_fee_qty)
  trace @"Subscription Period: (days)"
  trace cbor.diagnostic(subscription_period / ( 24 * 60 * 60 * 1000 ))
  trace @"Penalty Fee: (lovelace)"
  trace cbor.diagnostic(penalty_qty)

  trace @"Step 2: Creating Payment Datum"
  trace @"-------------------------------------"
  trace @"Service NFT:"
  trace cbor.diagnostic(service_tkn)
  trace @"Account NFT:"
  trace cbor.diagnostic(user_account_tkn)
  trace @"Subscription Start:"
  trace cbor.diagnostic(current_time)
  trace @"Subscription End:"
  trace cbor.diagnostic(current_time + subscription_period)

  trace @"Step 3: Preparing Inputs"
  trace @"-------------------------------------"
  trace @"Account Input:"
  trace cbor.diagnostic(account_input)
  trace @"Service Input:"
  trace cbor.diagnostic(service_input)

  trace @"Step 4: Preparing Outputs"
  trace @"-------------------------------------"
  trace @"User Output:"
  trace cbor.diagnostic(user_output)
  trace @"Payment Output:"
  trace cbor.diagnostic(payment_output)

  trace @"Step 5: Execution Result"
  trace @"-------------------------------------"
  trace @"Subscription Successfully Initiated!"
  trace @"-------------------------------------"
  trace @"Test Completed!"

  mint_payment(service_cs, account_cs, redeemer, context)
}

test succeed_terminate_subscription() {
  let own_cs = tests.test_payment_cs()
  let account_cs = tests.test_account_cs()
  let service_cs = tests.test_service_cs()

  let tx_hash = tests.test_224_01()
  let payment_tx_hash = tests.test_224_02()

  let init_output_ref = tests.test_input_utxo_02(tx_hash)
  let script_output_ref = tests.test_input_utxo_02(payment_tx_hash)

  let current_time = 1000000
  let last_claimed = 500000
  // 30 days in milliseconds
  let subscription_period = 30 * 24 * 60 * 60 * 1000
  let payment_fee_qty = 10_000_000
  let penalty_fee_qty = 1_000_000

  let user_account_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_222)
  let service_tkn = values.unique_token_name(service_cs, 1, cip68.prefix_222)
  let payment_tkn = values.unique_token_name(payment_tx_hash, 1, #"")

  let payment_datum =
    tests.test_datum_03(
      service_tkn,
      user_account_tkn,
      payment_fee_qty,
      current_time,
      current_time + subscription_period,
      subscription_period,
      last_claimed,
      penalty_fee_qty,
    )

  let payment_value = value.add(value.zero(), own_cs, payment_tkn, 1)
  let account_value = value.add(value.zero(), account_cs, user_account_tkn, 1)

  // Create the payment input (the one being spent)
  let user_input =
    tests.test_context_input_02(init_output_ref, own_cs, account_value, NoDatum)
  let payment_input =
    tests.test_context_input_02(
      script_output_ref,
      own_cs,
      payment_value,
      payment_datum,
    )

  // Calculate refund amount (assuming half of the subscription period has passed)
  let time_elapsed = subscription_period / 2
  let refund_amount = payment_fee_qty / 2

  // Create refund output
  let refund_output =
    tests.test_utxo_02(account_cs, value.from_lovelace(refund_amount), NoDatum)

  // Create penalty output
  let penalty_fee_qty = 1_000_000
  let penalty_datum =
    PenaltyDatum {
      service_nft_tn: service_tkn,
      account_nft_tn: user_account_tkn,
      penalty_fee: AssetClass {
        policy_id: value.ada_policy_id,
        asset_name: value.ada_asset_name,
      },
      penalty_fee_qty,
    }
  let penalty_output =
    tests.test_utxo_02(
      service_cs,
      value.from_lovelace(penalty_fee_qty),
      penalty_datum,
    )
  // Create the redeemer
  let redeemer = TerminateSubscription

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
        inputs: [user_input, payment_input],
        reference_inputs: [],
        outputs: [refund_output, penalty_output],
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

  trace @"Test: Terminating a Subscription"
  trace @"-------------------------------------"

  trace @"Step 1: Subscription Details"
  trace @"-------------------------------------"
  trace @"Service Currency Symbol:"
  trace cbor.diagnostic(service_cs)
  trace @"Account Currency Symbol:"
  trace cbor.diagnostic(account_cs)
  trace @"Payment Currency Symbol:"
  trace cbor.diagnostic(own_cs)
  trace @"Original Subscription Start:"
  trace cbor.diagnostic(current_time)
  trace @"Original Subscription End:"
  trace cbor.diagnostic(current_time + subscription_period)
  trace @"Termination Time (mid-subscription):"
  trace cbor.diagnostic(current_time + time_elapsed)

  trace @"Step 2: Calculating Refund and Penalty"
  trace @"-------------------------------------"
  trace @"Total Subscription Time:"
  trace cbor.diagnostic(subscription_period)
  trace @"Time Elapsed:"
  trace cbor.diagnostic(time_elapsed)
  trace @"Original Payment Amount:"
  trace cbor.diagnostic(payment_fee_qty)
  trace @"Refund Amount:"
  trace cbor.diagnostic(refund_amount)
  trace @"Penalty Applied:"
  trace cbor.diagnostic(penalty_fee_qty)

  trace @"Step 3: Processing Termination"
  trace @"-------------------------------------"
  trace @"Payment NFT to be burned:"
  trace cbor.diagnostic(payment_tkn)
  trace @"Refund Output:"
  trace cbor.diagnostic(refund_output)
  trace @"Penalty Output:"
  trace cbor.diagnostic(penalty_output)

  trace @"Step 4: Verifying Transaction"
  trace @"-------------------------------------"
  trace @"Transaction Inputs:"
  trace cbor.diagnostic(context.transaction.inputs)
  trace @"Transaction Outputs:"
  trace cbor.diagnostic(context.transaction.outputs)
  trace @"Burned Tokens:"
  trace cbor.diagnostic(context.transaction.mint)

  trace @"Step 5: Execution Result"
  trace @"-------------------------------------"
  trace @"Subscription Successfully Terminated"

  trace @"-------------------------------------"
  trace @"Test Completed!"

  mint_payment(service_cs, account_cs, redeemer, context)
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
  let initial_subscription_period = 30 * 24 * 60 * 60 * 1000
  let initial_payment_fee_qty = 10_000_000
  let penalty_fee_qty = 1_000_000

  // Create the initial payment datum
  let initial_payment_datum =
    tests.test_datum_03(
      service_tkn,
      user_account_tkn,
      initial_payment_fee_qty,
      current_time,
      current_time + initial_subscription_period,
      initial_subscription_period,
      last_claimed,
      penalty_fee_qty,
    )
  // Create the payment input (the one being spent)
  let initial_payment_value =
    value.add(
      value.from_lovelace(initial_payment_fee_qty),
      own_cs,
      payment_tkn,
      1,
    )
  let payment_input =
    tests.test_context_input_02(
      extend_output_ref,
      own_cs,
      initial_payment_value,
      initial_payment_datum,
    )
  // Define extension parameters
  // 30 more days
  let extension_period = 30 * 24 * 60 * 60 * 1000
  let extension_fee = 10_000_000
  // Same as initial fee for simplicity
  // Create the new payment datum with extended period and increased fee
  let new_payment_datum =
    tests.test_datum_03(
      service_tkn,
      user_account_tkn,
      initial_payment_fee_qty + extension_fee,
      current_time,
      initial_payment_datum.subscription_end + extension_period,
      initial_subscription_period + extension_period,
      last_claimed,
      penalty_fee_qty,
    )
  // Create the new payment output
  let new_payment_value =
    value.add(
      value.from_lovelace(initial_payment_fee_qty + extension_fee),
      own_cs,
      payment_tkn,
      1,
    )
  let payment_output =
    tests.test_utxo_02(own_cs, new_payment_value, new_payment_datum)
  // Create a mock subscriber input (to pay for the extension)
  let subscriber_pkh = tests.test_224_04()
  // Assuming this function exists to generate a different hash
  let account_input =
    tests.test_context_input_02(
      tests.test_input_utxo_02(tx_hash),
      account_cs,
      user_value,
      // Extra for fees
      NoDatum,
    )
  // Create the service datum and input
  let service_datum = tests.test_service_datum()
  let service_input =
    tests.test_context_input_02(
      tests.test_input_utxo_02(service_cs),
      service_cs,
      service_value,
      service_datum,
    )
  // Create the redeemer
  let redeemer = Extend
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
        inputs: [account_input, payment_input],
        reference_inputs: [service_input],
        outputs: [user_change_output, payment_output],
        // fee: value.from_lovelace(2_000_000),
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

  trace @"Test: Extending an Existing Subscription"
  trace @"-------------------------------------"

  trace @"Step 1: Current Subscription Details"
  trace @"-------------------------------------"
  trace @"Service Currency Symbol:"
  trace cbor.diagnostic(service_cs)
  trace @"Account Currency Symbol:"
  trace cbor.diagnostic(account_cs)
  trace @"Current Subscription Start:"
  trace cbor.diagnostic(current_time)
  trace @"Current Subscription End:"
  trace cbor.diagnostic(current_time + initial_subscription_period)
  trace @"Current Subscription Fee: (lovelace)"
  trace cbor.diagnostic(initial_payment_fee_qty)

  trace @"Step 2: Extension Details"
  trace @"-------------------------------------"
  trace @"Extension Period: (days)"
  trace cbor.diagnostic(extension_period / ( 24 * 60 * 60 * 1000 ))
  trace @"New Subscription End:"
  trace cbor.diagnostic(
    initial_payment_datum.subscription_end + extension_period,
  )
  trace @"Additional Fee for Extension: (lovelace)"
  trace cbor.diagnostic(extension_fee)

  trace @"Step 3: Updating Payment Datum"
  trace @"-------------------------------------"
  trace @"Original Payment Datum:"
  trace cbor.diagnostic(initial_payment_datum)
  trace @"Updated Payment Datum:"
  trace cbor.diagnostic(new_payment_datum)

  trace @"Step 4: Verifying Transaction"
  trace @"-------------------------------------"
  trace @"Transaction Inputs:"
  trace cbor.diagnostic(context.transaction.inputs)
  trace @"Transaction Outputs:"
  trace cbor.diagnostic(context.transaction.outputs)
  trace @"Reference Inputs:"
  trace cbor.diagnostic(context.transaction.reference_inputs)

  trace @"Step 5: Execution Result"
  trace @"-------------------------------------"
  trace @"Subscription Successfully Extended!"
  trace @"-------------------------------------"
  trace @"Test Completed!"

  spend_payment(
    service_cs,
    account_cs,
    Payment(initial_payment_datum),
    redeemer,
    context,
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

  let current_time = 1000000
  let last_claimed = 500000
  // 30 days in milliseconds
  let subscription_period = 30 * 24 * 60 * 60 * 1000
  let payment_fee_qty = 10_000_000
  let penalty_fee_qty = 1_000_000

  let payment_datum =
    tests.test_datum_03(
      service_tkn,
      user_account_tkn,
      payment_fee_qty,
      current_time,
      current_time + subscription_period,
      subscription_period,
      last_claimed,
      penalty_fee_qty,
    )

  let payment_value =
    value.add(value.from_lovelace(payment_fee_qty), own_cs, payment_tkn, 1)
  let account_value = value.add(value.zero(), account_cs, user_account_tkn, 1)
  let service_value = value.add(value.zero(), service_cs, service_tkn, 1)

  let service_datum = tests.test_service_datum()

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
  let time_elapsed = subscription_period / 2
  let refund_amount = payment_fee_qty / 2

  // Create refund output
  let refund_output =
    tests.test_utxo_02(account_cs, value.from_lovelace(refund_amount), NoDatum)

  let penalty_value =
    value.add(value.from_lovelace(penalty_fee_qty), own_cs, payment_tkn, 1)

  // Create penalty output
  let penalty_datum =
    tests.test_penalty_datum(service_tkn, user_account_tkn, penalty_fee_qty)
  let penalty_output = tests.test_utxo_02(own_cs, penalty_value, penalty_datum)
  let redeemer = Unsubscribe

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

  trace @"Test: Unsubscribing from a Service"
  trace @"-------------------------------------"

  trace @"Step 1: Current Subscription Details"
  trace @"-------------------------------------"
  trace @"Original Subscription Fee: (lovelace)"
  trace cbor.diagnostic(payment_fee_qty)
  trace @"Subscription period: (days)"
  trace cbor.diagnostic(subscription_period / ( 24 * 60 * 60 * 1000 ))

  trace @"Unsubscribe Details:"
  trace @"Time elapsed: (days)"
  trace cbor.diagnostic(time_elapsed / ( 24 * 60 * 60 * 1000 ))
  trace @"Refund Amount: (lovelace)"
  trace cbor.diagnostic(refund_amount)
  trace @"Penalty Fee: (lovelace)"
  trace cbor.diagnostic(penalty_fee_qty)

  trace @"Refunded to user:"
  trace cbor.diagnostic(refund_amount)
  trace @"Penalty retained:"
  trace cbor.diagnostic(penalty_fee_qty)

  trace @"Step 2: Unsubscribe Process"
  trace @"-------------------------------------"
  trace @"Time of Unsubscription:"
  trace cbor.diagnostic(current_time)
  trace @"Refund Amount:"
  trace cbor.diagnostic(refund_amount)
  trace @"Penalty Amount:"
  trace cbor.diagnostic(penalty_fee_qty)

  trace @"Step 3: Verifying Outputs"
  trace @"-------------------------------------"
  trace @"Refund Output:"
  trace cbor.diagnostic(refund_output)
  trace @"Penalty Output:"
  trace cbor.diagnostic(penalty_output)

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
  trace @"Unsubscription Successfully Processed!"
  trace @"-------------------------------------"
  trace @"Test Completed!"

  spend_payment(
    service_cs,
    account_cs,
    Payment(payment_datum),
    redeemer,
    context,
  )
}

test succeed_withdraw() {
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
  let subscription_period = 30 * 24 * 60 * 60 * 1000
  // 30 days in milliseconds
  let subscription_end = subscription_start + subscription_period
  let payment_fee_qty = 10_000_000
  let penalty_fee_qty = 1_000_000
  let last_claimed = subscription_start
  let current_time = subscription_start + subscription_period / 2

  // Half-way through
  let payment_datum =
    tests.test_datum_03(
      service_tkn,
      user_account_tkn,
      payment_fee_qty,
      subscription_start,
      subscription_end,
      subscription_period,
      last_claimed,
      penalty_fee_qty,
    )

  let service_datum = tests.test_service_datum()

  let payment_value =
    value.add(value.from_lovelace(payment_fee_qty), own_cs, payment_tkn, 1)
  let service_value =
    value.add(value.from_lovelace(payment_fee_qty), service_cs, service_tkn, 1)

  // Create the merchant input (to prove service ownership)
  let merchant_input =
    tests.test_context_input_02(
      tests.test_input_utxo_02(service_tx_hash),
      service_cs,
      service_value,
      NoDatum,
    )
  // Create the payment input (the one being spent)
  let payment_input =
    tests.test_context_input_02(
      script_output_ref,
      own_cs,
      payment_value,
      payment_datum,
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
  let time_elapsed = math.min(current_time - last_claimed, subscription_period)
  let withdrawable_amount = payment_fee_qty * time_elapsed / subscription_period

  // Let's withdraw half of the withdrawable amount for this test
  let actual_withdrawal = withdrawable_amount / 2
  let merchant_output_value =
    value.add(
      value.from_lovelace(actual_withdrawal),
      service_cs,
      service_tkn,
      1,
    )

  // Create withdrawal output
  let merchant_output =
    tests.test_utxo_exact(service_cs, merchant_output_value, NoDatum)

  // Create remaining funds output (if any)
  let remaining_amount = payment_fee_qty - actual_withdrawal
  let payment_output_value =
    value.add(value.from_lovelace(remaining_amount), own_cs, payment_tkn, 1)

  let new_payment_datum =
    tests.test_datum_03(
      service_tkn,
      user_account_tkn,
      remaining_amount,
      subscription_start,
      subscription_end,
      subscription_period,
      current_time,
      penalty_fee_qty,
    )

  let payment_output =
    tests.test_utxo_02(own_cs, payment_output_value, new_payment_datum)

  let redeemer = Withdraw

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

  trace @"Test: Withdrawing Subscription Fees"
  trace @"-------------------------------------"

  trace @"Step 1: Current Contract State"
  trace @"-------------------------------------"
  trace @"Service Currency Symbol:"
  trace cbor.diagnostic(service_cs)
  trace @"Payment Currency Symbol:"
  trace cbor.diagnostic(own_cs)
  trace @"Subscription Start:"
  trace cbor.diagnostic(subscription_start)
  trace @"Subscription End:"
  trace cbor.diagnostic(subscription_end)
  trace @"Total Subscription Fee: (lovelace)"
  trace cbor.diagnostic(payment_fee_qty)
  trace @"Last Claimed:"
  trace cbor.diagnostic(last_claimed)
  trace @"Current Time:"
  trace cbor.diagnostic(current_time)

  trace @"Step 2: Withdrawal Calculation"
  trace @"-------------------------------------"
  trace @"Time Elapsed: (days)"
  trace cbor.diagnostic(time_elapsed / ( 24 * 60 * 60 * 1000 ))
  trace @"Withdrawable Amount: (lovelace)"
  trace cbor.diagnostic(withdrawable_amount)
  trace @"Actual Withdrawal: (lovelace)"
  trace cbor.diagnostic(actual_withdrawal)

  trace @"Step 3: Verifying Outputs"
  trace @"-------------------------------------"
  trace @"Merchant Output:"
  trace cbor.diagnostic(merchant_output)
  trace @"Remaining Payment Output:"
  trace cbor.diagnostic(payment_output)

  trace @"Step 4: Updating Payment Datum"
  trace @"-------------------------------------"
  trace @"Original Last Claimed:"
  trace cbor.diagnostic(last_claimed)
  trace @"Updated Last Claimed:"
  trace cbor.diagnostic(current_time)

  trace @"Step 5: Execution Result"
  trace @"-------------------------------------"
  trace @"Withdrawal Successfully Processed!"
  trace @"-------------------------------------"
  trace @"Test Completed!"

  spend_payment(
    service_cs,
    account_cs,
    Payment(payment_datum),
    redeemer,
    context,
  )
}
