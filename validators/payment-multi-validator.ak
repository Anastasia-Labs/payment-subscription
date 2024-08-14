use aiken/bytearray.{length}
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
use payment_subscription/tests
use payment_subscription/types.{
  AssetClass, Extend, InitSubscripton, MintPayment, Payment, PaymentDatum,
  PaymentValidatorDatum, Penalty, PenaltyDatum, ServiceDatum, SpendPayment,
  TerminateSubscription, Unsubscribe, Withdraw,
}
use payment_subscription/utils.{
  get_current_time, must_be_after_deadline, validate_single_nft_input,
  validate_token_output,
}

// TODO: List of all the Transactions that are required.
// TODO: Multiplier for the Discount and the Penalty. The longer you pay, the less the penalty (Last).
// TODO: Ensure deadline  for withdrawing when Service NFT has been removed. (Later)
// TODO: Allow staking rewards for the subscriber (Later)
// TODO: Allow Deadline for dormant subscription fees (After 90 days, subscriber can collect the funds from the payment validator)
// TODO: Last Claimed in datum and Can't claim until one month has passed.(Add counter)
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
        expect [service_ref_input, ..] = reference_inputs
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

        trace @"payment_output"
        trace cbor.diagnostic(payment_output)

        // Validate internal consistency of payment datum
        let internal_datum_valid =
          validate_payment_datum_internal(payment_datum)
        // Validate the datum from the Service Contract as a reference input.
        let datum_against_service_valid =
          validate_payment_against_service(payment_datum, service_datum)
        let nfts_valid =
          validate_nfts(payment_datum, service_policy_id, account_policy_id)

        trace @"datum.service_nft_tn"
        trace cbor.diagnostic(payment_datum.service_nft_tn)
        trace @"datum.account_nft_tn"
        trace cbor.diagnostic(payment_datum.account_nft_tn)

        // Check to ensure the subscription period matches the service's requirements
        let subscription_period_valid =
          payment_datum.subscription_period == service_datum.subscription_period

        // Debug: Print the entire value of service_ref_input
        trace @"service_ref_input.output.value"
        trace cbor.diagnostic(service_ref_input.output.value)

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

        trace @"input_has_account_nft"
        trace cbor.diagnostic(input_has_account_nft)

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

        trace @"locked_amount"
        trace cbor.diagnostic(locked_amount)
        trace @"expected_amount"
        trace cbor.diagnostic(expected_amount)
        trace @"locked_amount_valid"
        trace cbor.diagnostic(locked_amount_valid)
        and {
          // Validate that out_ref must be present in the Transaction Inputs.
          (account_input.output_reference == output_reference)?,
          input_has_service_nft?,
          input_has_account_nft?,
          nfts_valid?,
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

        trace @"account_nft"
        trace cbor.diagnostic(account_nft)
        trace @"account_policy_id"
        trace cbor.diagnostic(account_policy_id)
        trace @"payment_datum.account_nft_tn"
        trace cbor.diagnostic(payment_datum.account_nft_tn)
        trace @"quantity_of"
        trace cbor.diagnostic(
          value.quantity_of(
            account_nft,
            account_policy_id,
            payment_datum.account_nft_tn,
          ),
        )

        // trace @"token_policy"
        // trace cbor.diagnostic(token_policy)
        // Extract the NFT from the input
        let payment_nft =
          payment_input.output.value
            |> value.without_lovelace()
            |> value.flatten()

        // Ensure there's exactly one token and extract its details
        expect [(token_policy, token_name, _)] = payment_nft

        trace @"own_policy"
        trace cbor.diagnostic(own_policy)
        trace @"token_policy"
        trace cbor.diagnostic(token_policy)

        // Get the tokens being minted (or burned) in this transaction
        // let minted_tokens = tx.mint |> value.from_minted_value()
        // Ensure exactly one token is affected and extract its details
        expect [(pid, tkn, amt)] = value.flatten(minted_tokens)

        // Calculate refund amount
        let current_time = get_current_time(tx.validity_range)
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

        trace @"refund_amount"
        trace cbor.diagnostic(refund_amount)

        // Verify all conditions are met
        and {
          has_account_nft?,
          // The token in the input must be from our policy
          (token_policy == own_policy)?,
          // The token being burned must be from our policy
          (pid == own_policy)?,
          // The token being burned must match the one from the input
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
    // let Transaction { inputs, reference_inputs, outputs, .. } = tx
    expect Spend(_output_reference) = purpose

    when redeemer is {
      Extend -> validate_extend(account_policy_id, datum, tx)
      Unsubscribe -> validate_unsubscribe(account_policy_id, datum, tx)
      Withdraw -> validate_withdraw(service_policy_id, datum, tx)
    }
  }
}

fn validate_extend(
  account_policy_id: ByteArray,
  datum: PaymentValidatorDatum,
  tx: Transaction,
) -> Bool {
  when datum is {
    Payment(payment_datum) -> {
      // Find the input being spent (current Payment Validator UTxO)
      expect [account_input, payment_input, ..] = tx.inputs
      expect [service_ref_input, ..] = tx.reference_inputs

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

      trace @"service_ref_input"
      trace cbor.diagnostic(service_ref_input)

      trace @"account_input"
      trace cbor.diagnostic(account_input)
      trace @"payment_input"
      trace cbor.diagnostic(payment_input)

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

      trace @"valid_extension"
      trace cbor.diagnostic(valid_extension)
      trace @"fee_increase_valid"
      trace cbor.diagnostic(fee_increase_valid)
      // trace @"account_nft_preserved"
      // trace cbor.diagnostic(account_nft_preserved)
      trace @"fee_increase_valid"
      trace cbor.diagnostic(fee_increase_valid)
      // trace @"service_nft_present"
      // trace cbor.diagnostic(service_nft_present)
      trace @"correct_output_address"
      trace cbor.diagnostic(correct_output_address)

      and {
        // validate_account_policy?,
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

    // payout.at_least(payment_addr, payment_input.output.value, tx.outputs)?,
    Penalty(_) -> False
  }
}

// Validate that the logic follows the Service provider rules / datum as a refernce input to ensure the
// penalty goes to the merchant when paying the penalty fees.
fn validate_unsubscribe(
  account_policy_id: ByteArray,
  datum: PaymentValidatorDatum,
  tx: Transaction,
) -> Bool {
  when datum is {
    Payment(payment_datum) -> {
      // Find the inputs being spent (current Payment Validator UTxO)
      expect [account_input, payment_input, ..] = tx.inputs
      expect [service_ref_input, ..] = tx.reference_inputs

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

      let current_time = get_current_time(tx.validity_range)
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
  // let ScriptContext { transaction: tx, purpose } = ctx
  // expect Spend(output_reference) = purpose

  when datum is {
    Payment(payment_datum) -> {
      expect [merchant_input, payment_input, ..] = tx.inputs
      let payment_addr = payment_input.output.address

      trace @"merchant_input"
      trace cbor.diagnostic(merchant_input)
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

      trace @"service_datum.service_fee"
      trace cbor.diagnostic(service_datum.service_fee_qty)
      trace @"service_datum"
      trace cbor.diagnostic(service_datum)
      // Validate payment datum against service datum
      let payment_datum_valid =
        validate_payment_datum(payment_datum, service_datum)
      trace @"payment_datum.subscription_fee"
      trace cbor.diagnostic(payment_datum.subscription_fee)

      // Get the current time
      let current_time = get_current_time(tx.validity_range)

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

      // Add debug traces
      trace @"current_time"
      trace cbor.diagnostic(current_time)
      trace @"total_subscription_time"
      trace cbor.diagnostic(total_subscription_time)
      trace @"time_elapsed"
      trace cbor.diagnostic(time_elapsed)
      trace @"payment_datum.subscription_fee_qty"
      trace cbor.diagnostic(payment_datum.subscription_fee_qty)
      trace @"calculated_withdrawable_amount"
      trace cbor.diagnostic(withdrawable_amount)
      trace @"actual_withdrawal_amount"
      trace cbor.diagnostic(actual_withdrawal_amount)
      trace @"new_datum.last_claimed"
      trace cbor.diagnostic(new_datum.last_claimed)
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

      trace @"withdrawable_amount"
      trace cbor.diagnostic(withdrawable_amount)
      trace @"actual_withdrawal_amount"
      trace cbor.diagnostic(actual_withdrawal_amount)
      trace @"remaining_amount"
      trace cbor.diagnostic(remaining_amount)
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

// TODO: Validate All fields from Service Datum.
fn validate_payment_datum(
  payment_datum: PaymentDatum,
  service_datum: ServiceDatum,
) -> Bool {
  payment_datum.subscription_fee == service_datum.service_fee && payment_datum.subscription_period == service_datum.subscription_period && payment_datum.penalty_fee_qty == service_datum.penalty_fee_qty
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

  //   let period_increased =
  //     new_datum.subscription_period > old_datum.subscription_period
  // Updated calculation
  let expected_fee_increase =
    extension_period * service_datum.service_fee_qty / service_datum.subscription_period

  let fee_increase_valid = extension_amount >= expected_fee_increase
  trace @"extension_amount"
  trace cbor.diagnostic(extension_amount)
  trace @"expected_fee_increase"
  trace cbor.diagnostic(expected_fee_increase)

  let valid_end_date = new_datum.subscription_end > new_datum.subscription_start

  // Validate that the extension follows the Service provider rules
  let follows_service_rules =
    new_datum.subscription_fee == service_datum.service_fee && new_datum.subscription_period % service_datum.subscription_period == 0

  trace @"unchanged_fields_valid"
  trace cbor.diagnostic(unchanged_fields_valid)
  trace @"period_extension_valid"
  trace cbor.diagnostic(period_extension_valid)
  trace @"fee_increase_valid"
  trace cbor.diagnostic(fee_increase_valid)
  trace @"valid_end_date"
  trace cbor.diagnostic(valid_end_date)
  trace @"follows_service_rules"
  trace cbor.diagnostic(follows_service_rules)

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

fn validate_nfts(
  payment: PaymentDatum,
  service_policy_id: ByteArray,
  account_policy_id: ByteArray,
) -> Bool {
  let service_nft_valid =
    bytearray.take(payment.service_nft_tn, length(service_policy_id)) == service_policy_id
  let account_nft_valid =
    bytearray.take(payment.account_nft_tn, length(account_policy_id)) == account_policy_id

  service_nft_valid && account_nft_valid
}

// Happy path tests
test succeed_initiate_subscription() {
  let own_cs = tests.test_payment_cs()
  let account_cs = tests.test_account_cs()
  let service_cs = tests.test_service_cs()

  trace @"service_cs"
  trace cbor.diagnostic(service_cs)
  trace @"account_cs"
  trace cbor.diagnostic(account_cs)

  let tx_hash = tests.test_224_01()
  let account_tx_hash = tests.test_224_02()
  let service_tx_hash = tests.test_224_03()

  let init_output_ref = tests.test_input_utxo_02(tx_hash)
  let input_index = 0

  //   trace @"tx_hash"
  //   trace cbor.diagnostic(tx_hash)
  //   trace @"init_output_ref"
  //   trace cbor.diagnostic(init_output_ref)
  let payment_tkn = values.unique_token_name(tx_hash, 1, #"")
  let service_tkn =
    values.unique_token_name(service_tx_hash, 1, cip68.prefix_100)
  let user_account_tkn =
    values.unique_token_name(account_tx_hash, 1, cip68.prefix_222)

  // TODO: No need for this.
  let service_full_tn = bytearray.concat(service_cs, service_tkn)
  let account_full_tn = bytearray.concat(account_cs, user_account_tkn)

  trace @"service_full_tn"
  trace cbor.diagnostic(service_full_tn)
  trace @"account_full_tn"
  trace cbor.diagnostic(account_full_tn)

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
      service_full_tn,
      account_full_tn,
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
  let service_value = value.add(value.zero(), service_cs, service_full_tn, 1)
  let account_value = value.add(value.zero(), account_cs, account_full_tn, 1)

  //   let minted_value = value.merge(service_value, user_value)
  // trace @"user_output"
  // trace cbor.diagnostic(user_output)
  // trace @"script_output"
  // trace cbor.diagnostic(script_output)
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

  trace @"payment_datum"
  trace cbor.diagnostic(payment_datum)

  trace @"service_datum"
  trace cbor.diagnostic(service_datum)

  trace @"account_input"
  trace cbor.diagnostic(account_input)

  trace @"service_input"
  trace cbor.diagnostic(service_input)

  trace @"payment_output"
  trace cbor.diagnostic(payment_output)
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

  // let payment_tkn = bytearray.concat(own_cs, payment_tkn)
  // let account_full_tn = bytearray.concat(account_cs, user_account_tkn)
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

  trace @"own_cs"
  trace cbor.diagnostic(own_cs)
  trace @"payment_tkn"
  trace cbor.diagnostic(payment_tkn)
  trace @"payment_input"
  trace cbor.diagnostic(payment_input)
  trace @"minted_tokens"
  trace cbor.diagnostic(context.transaction.mint)

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
  trace @"Initial Payment Datum"
  trace cbor.diagnostic(initial_payment_datum)
  trace @"New Payment Datum"
  trace cbor.diagnostic(new_payment_datum)
  trace @"Payment Input"
  trace cbor.diagnostic(payment_input)
  trace @"New Payment Output"
  trace cbor.diagnostic(payment_output)
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

  spend_payment(
    service_cs,
    account_cs,
    Payment(payment_datum),
    redeemer,
    context,
  )
}
