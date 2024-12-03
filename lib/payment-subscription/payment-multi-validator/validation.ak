use aiken/collection/list
use aiken/math
use cardano/address.{Script}
use cardano/assets.{PolicyId}
use cardano/transaction.{
  InlineDatum, Input, Output, OutputReference, Transaction,
}
use cardano/value
use payment_subscription/common/types.{
  Payment, PaymentDatum, PaymentValidatorDatum, Penalty, PenaltyDatum,
  ServiceDatum,
}
use payment_subscription/common/utils.{
  get_input_by_token, get_minimum_current_time_estimate,
  must_be_after_start_date, validate_single_nft_input, validate_token_output,
} as common_utils
use payment_subscription/payment_multi_validator/utils.{
  calculate_locked_amount, validate_extension_datum,
  validate_payment_against_service, validate_payment_datum_internal,
}

pub fn validate_initial_subscription(
  own_policy: PolicyId,
  service_policy_id: PolicyId,
  account_policy_id: PolicyId,
  output_reference: OutputReference,
  input_index: Int,
  tx: Transaction,
) -> Bool {
  let minted_tokens = tx.mint
  // |> from_minted_value()
  expect Some(subscriber_input) = list.at(tx.inputs, input_index)

  // Find the service reference input by searching for the token policy
  expect Some(service_ref_input) =
    get_input_by_token(tx.reference_inputs, service_policy_id)

  expect [user_output, payment_output, ..] = tx.outputs

  // Extract datums
  expect InlineDatum(out_utxo_inline_datum) = payment_output.datum
  expect Some(Payment(payment_datum)): Option<PaymentValidatorDatum> =
    out_utxo_inline_datum

  expect InlineDatum(service_inline_datum) = service_ref_input.output.datum
  expect service_datum: ServiceDatum = service_inline_datum

  let payment_payment_credential = Script(own_policy)

  // Create a unique token name
  let payment_tkn =
    value.unique_token_name(
      output_reference.transaction_id,
      output_reference.output_index,
      #"",
      "",
    )
  // Construct one Payment token value 
  let payment_value = assets.from_asset(own_policy, payment_tkn, 1)

  // Validate internal consistency of payment datum
  let internal_datum_valid = validate_payment_datum_internal(payment_datum)
  // Validate the datum from the Service Contract as a reference input.
  let datum_against_service_valid =
    validate_payment_against_service(payment_datum, service_datum)

  // Check to ensure the subscription period matches the service's requirements
  let interval_length_valid =
    payment_datum.interval_length == service_datum.interval_length
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
      subscriber_input,
      account_policy_id,
      payment_datum.account_nft_tn,
    )

  // Verify the correct amount is locked
  let locked_amount =
    assets.quantity_of(
      payment_output.value,
      payment_datum.subscription_fee.policy_id,
      payment_datum.subscription_fee.asset_name,
    )
  let expected_amount = payment_datum.interval_amount

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
    input_has_service_nft?,
    input_has_account_nft?,
    internal_datum_valid?,
    datum_against_service_valid?,
    (payment_value == minted_tokens)?,
    locked_amount_valid?,
    user_token_not_to_script?,
    payment_token_to_script?,
    interval_length_valid?,
  }
}

pub fn validate_terminate_subscription(
  own_policy: PolicyId,
  _service_policy_id: PolicyId,
  merchant_input_index: Int,
  payment_input_index: Int,
  tx: Transaction,
) -> Bool {
  // Find the input that's being spent (the one containing our NFT)
  // expect [subscriber_input, payment_input, ..] = tx.inputs
  expect Some(merchant_input) = list.at(tx.inputs, merchant_input_index)
  expect Some(payment_input) = list.at(tx.inputs, payment_input_index)
  let minted_tokens = tx.mint

  let merchant_nft =
    merchant_input.output.value |> assets.without_lovelace() |> assets.flatten()

  expect [(merchant_policy, merchant_token_name, _)] = merchant_nft

  let input_has_merchant_nft =
    validate_single_nft_input(
      merchant_input,
      merchant_policy,
      merchant_token_name,
    )
  // Extract the NFT from the input
  let payment_nft =
    payment_input.output.value
      |> assets.without_lovelace()
      |> assets.flatten()

  // Ensure there's exactly one token and extract its details
  expect [(token_policy, token_name, _)] = payment_nft

  // Get the tokens being minted (or burned) in this transaction
  expect [(pid, tkn, amt)] = assets.flatten(minted_tokens)

  // Verify all conditions are met
  and {
    input_has_merchant_nft?,
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

pub fn validate_extend_subscription(
  service_policy_id: ByteArray,
  _account_policy_id: ByteArray,
  datum: Option<PaymentValidatorDatum>,
  subscriber_input_index: Int,
  payment_input_index: Int,
  tx: Transaction,
) -> Bool {
  when datum is {
    Some(Payment(payment_datum)) -> {
      // Find the input being spent (current Payment Validator UTxO)
      expect Some(subscriber_input) = list.at(tx.inputs, subscriber_input_index)
      expect Some(payment_input) = list.at(tx.inputs, payment_input_index)
      // Find the service reference input by searching for the token policy
      expect Some(service_ref_input) =
        get_input_by_token(tx.reference_inputs, service_policy_id)
      // Find the new payment output
      expect [_account_output, payment_output, ..] = tx.outputs

      // The script credential is part of the address of the input being spent
      let payment_script_credential =
        payment_input.output.address.payment_credential
      // Extract the datums
      expect InlineDatum(service_inline_datum) = service_ref_input.output.datum
      expect service_datum: ServiceDatum = service_inline_datum

      expect InlineDatum(out_utxo_inline_datum) = payment_output.datum
      expect Payment(new_datum): PaymentValidatorDatum = out_utxo_inline_datum

      let payment_addr = payment_input.output.address

      // Extract the payment NFT from the input
      let payment_nft = payment_input.output.value |> assets.without_lovelace()
      expect [(policy_id, asset_name, 1)] = assets.flatten(payment_nft)

      // Validate the datum from the Service Contract as a reference input.
      let datum_against_service_valid =
        validate_payment_against_service(payment_datum, service_datum)

      // Verify the new payment output
      let original_amount = assets.lovelace_of(payment_input.output.value)
      let new_amount = assets.lovelace_of(payment_output.value)
      let amount_increased = new_amount >= original_amount
      let extension_amount = new_amount - original_amount

      // Calculate and validate the fee increase
      let extension_period =
        new_datum.subscription_end - payment_datum.subscription_end
      let service_fee_rate =
        service_datum.service_fee_qty / service_datum.interval_length
      let minimum_expected_fee_increase = extension_period * service_fee_rate

      // Fee increase validation
      let actual_fee_increase = new_amount - original_amount
      let fee_increase_valid =
        actual_fee_increase >= minimum_expected_fee_increase

      let subscriber_nft =
        subscriber_input.output.value
          |> assets.without_lovelace()
          |> assets.flatten()

      expect [(account_policy, subscriber_token_name, _)] = subscriber_nft

      // Verify the inputs contain 1 Account NFT Asset
      let input_has_account_nft =
        validate_single_nft_input(
          subscriber_input,
          account_policy,
          subscriber_token_name,
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
    Some(Penalty(_)) -> False
    None -> False
  }
}

pub fn validate_merchant_withdraw(
  service_policy_id: ByteArray,
  datum: Option<PaymentValidatorDatum>,
  merchant_input_index: Int,
  payment_input_index: Int,
  tx: Transaction,
) -> Bool {
  expect Some(merchant_input) = list.at(tx.inputs, merchant_input_index)
  expect Some(payment_input) = list.at(tx.inputs, payment_input_index)

  // Verify the Service datum from reference input
  expect Some(service_ref_input) =
    get_input_by_token(tx.reference_inputs, service_policy_id)

  let user_nft =
    merchant_input.output.value
      |> assets.without_lovelace()

  expect [(_, merchant_asset_name, _)] = assets.flatten(user_nft)

  let merchant_has_service_nft =
    validate_single_nft_input(
      merchant_input,
      service_policy_id,
      merchant_asset_name,
    )

  let payment_nft =
    payment_input.output.value
      |> assets.without_lovelace()

  expect [(payment_policy, payment_asset_name, _)] = assets.flatten(payment_nft)

  let payment_input_has_payment_nft =
    validate_single_nft_input(payment_input, payment_policy, payment_asset_name)

  when datum is {
    Some(Payment(payment_datum)) -> {
      let ref_has_service_nft =
        validate_single_nft_input(
          service_ref_input,
          service_policy_id,
          payment_datum.service_nft_tn,
        )

      expect InlineDatum(service_inline_datum) = service_ref_input.output.datum
      expect service_datum: ServiceDatum = service_inline_datum

      expect [merchant_output, payment_output, ..] = tx.outputs

      let ada_amount = assets.lovelace_of(merchant_input.output.value)
      let has_minimum_ada = ada_amount >= payment_datum.minimum_ada

      // Validate payment datum against service datum
      let payment_datum_valid =
        validate_payment_against_service(payment_datum, service_datum)

      // Get the current time
      let current_time = get_minimum_current_time_estimate(tx.validity_range)

      // Update the last_claimed field in the new datum
      expect InlineDatum(out_utxo_inline_datum) = payment_output.datum
      expect Payment(new_datum): PaymentValidatorDatum = out_utxo_inline_datum

      // Update the last_claimed field in the new datum
      let last_claimed_updated =
        new_datum.last_claimed >= payment_datum.subscription_start

      // Verify that the Service NFT is preserved
      let merchant_nft_preserved =
        assets.quantity_of(
          merchant_output.value,
          service_policy_id,
          merchant_asset_name,
        ) == 1

      let locked_amount =
        calculate_locked_amount(
          payment_datum.num_intervals,
          current_time,
          payment_datum.subscription_start,
          payment_datum.interval_length,
          payment_datum.interval_amount,
        )
      // Verify that any remaining funds are returned to the payment validator
      // This is the amount of funds that should be left in the payment script after the withdrawal.
      let actual_remaining_amount =
        assets.quantity_of(
          payment_output.value,
          payment_datum.subscription_fee.policy_id,
          payment_datum.subscription_fee.asset_name,
        )
      let remaining_funds_valid = actual_remaining_amount >= locked_amount
      let payment_addr = payment_input.output.address

      and {
        merchant_has_service_nft?,
        payment_input_has_payment_nft?,
        ref_has_service_nft?,
        payment_datum_valid?,
        must_be_after_start_date(
          tx.validity_range,
          payment_datum.subscription_start,
        )?,
        merchant_nft_preserved?,
        remaining_funds_valid?,
        last_claimed_updated?,
        has_minimum_ada?,
        (payment_output.address == payment_addr)?,
      }
    }

    Some(Penalty(penalty_datum)) -> {
      expect [merchant_output, ..] = tx.outputs

      let ref_has_service_nft =
        validate_single_nft_input(
          service_ref_input,
          service_policy_id,
          penalty_datum.service_nft_tn,
        )

      // Verify the penalty input
      let penalty_input_valid =
        validate_single_nft_input(
          payment_input,
          payment_policy,
          payment_asset_name,
        )

      // Verify the penalty amount in the input
      let penalty_input_amount_valid =
        assets.quantity_of(
          payment_input.output.value,
          penalty_datum.penalty_fee.policy_id,
          penalty_datum.penalty_fee.asset_name,
        ) >= penalty_datum.penalty_fee_qty

      // Verify withdrawal of penalty to merchant
      let penalty_withdrawal_valid =
        assets.quantity_of(
          merchant_output.value,
          penalty_datum.penalty_fee.policy_id,
          penalty_datum.penalty_fee.asset_name,
        ) >= penalty_datum.penalty_fee_qty

      // Verify the Penalty NFT is burned
      let penalty_nft_burned =
        assets.quantity_of(tx.mint, payment_policy, payment_asset_name) == -1

      and {
        // Verify that the merchant has the Service NFT
        merchant_has_service_nft?,
        ref_has_service_nft?,
        penalty_input_valid?,
        penalty_input_amount_valid?,
        penalty_withdrawal_valid?,
        penalty_nft_burned?,
      }
    }
    None -> {
      // Handle the case where datum is None
      trace @" No Penalty Datum"
      False
    }
  }
}

// Validate that the logic follows the Service provider rules / datum as a refernce input to ensure the
// penalty goes to the merchant when paying the penalty fees.
pub fn validate_unsubscribe(
  service_policy_id: ByteArray,
  account_policy_id: ByteArray,
  datum: Option<PaymentValidatorDatum>,
  subscriber_input_index: Int,
  payment_input_index: Int,
  tx: Transaction,
) -> Bool {
  when datum is {
    Some(Payment(payment_datum)) -> {
      // Find the inputs being spent (current Payment Validator UTxO)
      expect Some(subscriber_input) = list.at(tx.inputs, subscriber_input_index)
      expect Some(payment_input) = list.at(tx.inputs, payment_input_index)

      // Find the service reference input by searching for the token policy
      expect Some(service_ref_input) =
        get_input_by_token(tx.reference_inputs, service_policy_id)

      let payment_script_credential =
        payment_input.output.address.payment_credential

      // Verify the inputs contain 1 Account NFT Asset
      let input_has_account_nft =
        validate_single_nft_input(
          subscriber_input,
          account_policy_id,
          payment_datum.account_nft_tn,
        )
      let payment_nft = payment_input.output.value |> assets.without_lovelace()
      expect [(policy_id, asset_name, 1)] = assets.flatten(payment_nft)

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
        payment_datum.total_subscription_fee * (
          total_subscription_time - time_elapsed
        ) / total_subscription_time

      // Verify refund output to subscriber
      let refund_output_valid =
        assets.quantity_of(
          account_output.value,
          payment_datum.subscription_fee.policy_id,
          payment_datum.subscription_fee.asset_name,
        ) >= refund_amount - payment_datum.minimum_ada

      let payment_nft_in_penalty_output =
        assets.quantity_of(penalty_output.value, policy_id, asset_name) == 1

      // Extract the datums
      expect InlineDatum(service_inline_datum) = service_ref_input.output.datum
      expect service_datum: ServiceDatum = service_inline_datum

      let payment_datum_valid =
        validate_payment_against_service(payment_datum, service_datum)

      expect InlineDatum(out_utxo_inline_datum) = penalty_output.datum
      expect Penalty(penalty_datum): PaymentValidatorDatum =
        out_utxo_inline_datum

      // Verify Penalty UTxO
      let penalty_output_valid =
        penalty_datum.service_nft_tn == payment_datum.service_nft_tn && penalty_datum.account_nft_tn == payment_datum.account_nft_tn && payment_datum.penalty_fee_qty == penalty_datum.penalty_fee_qty && penalty_datum.penalty_fee_qty == service_datum.penalty_fee_qty

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
    Some(Penalty(_)) -> False
    None -> False
  }
}

pub fn validate_subscriber_withdraw(
  service_policy_id: ByteArray,
  account_policy_id: ByteArray,
  datum: Option<PaymentValidatorDatum>,
  subscriber_input_index: Int,
  payment_input_index: Int,
  tx: Transaction,
) -> Bool {
  when datum is {
    Some(Payment(payment_datum)) -> {
      // Find the payment input being spent
      expect Some(subscriber_input) = list.at(tx.inputs, subscriber_input_index)
      expect Some(payment_input) = list.at(tx.inputs, payment_input_index)

      // Find the service reference input
      expect Some(service_ref_input) =
        get_input_by_token(tx.reference_inputs, service_policy_id)

      let account_user_nft =
        subscriber_input.output.value
          |> assets.without_lovelace()

      expect [(_, account_asset_name, _)] = assets.flatten(account_user_nft)

      let subscriber_has_account_nft =
        validate_single_nft_input(
          subscriber_input,
          account_policy_id,
          account_asset_name,
        )
      expect [user_output, payment_output, ..] = tx.outputs

      // Extract the service datum
      expect InlineDatum(service_inline_datum) = service_ref_input.output.datum
      expect service_datum: ServiceDatum = service_inline_datum

      // Ensure the service is inactive
      let service_is_inactive = !service_datum.is_active

      // Ensure the payment is associated with this service
      let payment_datum_valid =
        validate_payment_against_service(payment_datum, service_datum)

      expect InlineDatum(out_utxo_inline_datum) = payment_output.datum
      expect Some(Payment(payment_datum)): Option<PaymentValidatorDatum> =
        out_utxo_inline_datum

      let penalty_output_valid =
        payment_datum.service_nft_tn == payment_datum.service_nft_tn && payment_datum.account_nft_tn == payment_datum.account_nft_tn && payment_datum.penalty_fee_qty == payment_datum.penalty_fee_qty && payment_datum.penalty_fee_qty == service_datum.penalty_fee_qty

      let payment_nft = payment_input.output.value |> assets.without_lovelace()
      expect [(payment_policy_id, payment_asset_name, 1)] =
        assets.flatten(payment_nft)

      // Calculate the refund amount (full remaining balance)
      let refund_amount =
        assets.quantity_of(
          payment_input.output.value,
          payment_datum.subscription_fee.policy_id,
          payment_datum.subscription_fee.asset_name,
        )

      // Ensure the user receives the full refund
      let full_refund_given =
        assets.quantity_of(
          user_output.value,
          payment_datum.subscription_fee.policy_id,
          payment_datum.subscription_fee.asset_name,
        ) >= refund_amount

      // Verify that the Account NFT is preserved in the user output
      let account_nft_preserved =
        assets.quantity_of(
          user_output.value,
          account_policy_id,
          payment_datum.account_nft_tn,
        ) == 1

      let payment_nft_in_penalty_output =
        assets.quantity_of(
          payment_output.value,
          payment_policy_id,
          payment_asset_name,
        ) == 1

      and {
        subscriber_has_account_nft?,
        payment_datum_valid?,
        service_is_inactive?,
        full_refund_given?,
        penalty_output_valid?,
        account_nft_preserved?,
        payment_nft_in_penalty_output?,
      }
    }
    Some(Penalty(_)) -> False
    None -> False
  }
}
