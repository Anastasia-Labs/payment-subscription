use aiken/dict
use aiken/list
use aiken/math
use aiken/transaction.{Input, Output, OutputReference, Transaction}
use aiken/transaction/credential.{ScriptCredential}
use aiken/transaction/value.{PolicyId, from_minted_value}
use assist/data
use assist/values
use payment_subscription/common/types.{
  Payment, PaymentDatum, PaymentValidatorDatum, Penalty, PenaltyDatum,
  ServiceDatum,
}
use payment_subscription/common/utils.{
  get_input_by_token, get_minimum_current_time_estimate, must_be_after_date,
  validate_single_nft_input, validate_token_output,
} as common_utils
use payment_subscription/payment_multi_validator/utils.{
  validate_extension_datum, validate_initial_payment_against_service,
  validate_initial_payment_datum_internal,
}

// minting policy validator
pub fn validate_initial_subscription(
  own_policy: PolicyId,
  account_policy_id: PolicyId,
  service_policy_id: PolicyId,
  output_reference: OutputReference,
  input_index: Int,
  tx: Transaction,
) -> Bool {
  let minted_tokens = tx.mint |> from_minted_value()
  expect Some(subscriber_input) = list.at(tx.inputs, input_index)

  let payment_payment_credential = credential.ScriptCredential(own_policy)

  expect Some(payment_output) =
    list.find(
      tx.outputs,
      fn(x) { x.address.payment_credential == payment_payment_credential },
    )

  // Create a unique token name
  let payment_tkn =
    values.unique_token_name(
      output_reference.transaction_id.hash,
      output_reference.output_index,
      #"",
    )
  // Construct one Payment token value 
  let payment_value = value.from_asset(own_policy, payment_tkn, 1)

  // Extract datums
  expect Payment(payment_datum): PaymentValidatorDatum =
    data.output_datum(payment_output)
  // Find the service reference input by searching for the token policy
  expect Some(service_ref_input) =
    get_input_by_token(
      tx.reference_inputs,
      service_policy_id,
      payment_datum.service_nft_tn,
    )

  expect service_datum: ServiceDatum =
    data.output_datum(service_ref_input.output)

  // Validate internal consistency of payment datum
  let internal_datum_valid =
    validate_initial_payment_datum_internal(payment_datum)
  // Validate the datum from the Service Contract as a reference input.
  let datum_against_service_valid =
    validate_initial_payment_against_service(payment_datum, service_datum)

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
      payment_datum.subscriber_nft_tn,
    )

  // Verify the correct amount is locked
  let locked_amount =
    value.quantity_of(
      payment_output.value,
      payment_datum.subscription_fee.policy_id,
      payment_datum.subscription_fee.asset_name,
    )
  let expected_amount = payment_datum.total_subscription_fee_qty

  let locked_amount_valid = locked_amount >= expected_amount

  // Ensure token output goes back to the script
  let payment_token_to_script =
    value.quantity_of(payment_output.value, own_policy, payment_tkn) == 1

  and {
    // Validate that out_ref must be present in the Transaction Inputs.
    input_has_service_nft?,
    input_has_account_nft?,
    internal_datum_valid?,
    datum_against_service_valid?,
    (payment_value == minted_tokens)?,
    locked_amount_valid?,
    payment_token_to_script?,
  }
}

// minting policy validator
pub fn validate_terminate_subscription(
  own_policy: PolicyId,
  tx: Transaction,
) -> Bool {
  let minted_tokens = tx.mint |> from_minted_value()
  expect [(pid, _tkn, -1)] = value.flatten(minted_tokens)
  (pid == own_policy)?
}

// spending validation
pub fn validate_extend_subscription(
  own_reference: OutputReference,
  service_policy_id: ByteArray,
  datum: PaymentValidatorDatum,
  payment_input_index: Int,
  tx: Transaction,
) -> Bool {
  when datum is {
    Payment(payment_datum) -> {
      expect Some(payment_input) = list.at(tx.inputs, payment_input_index)
      let reference_correct = payment_input.output_reference == own_reference
      let payment_input_utxo = payment_input.output
      let payment_addr = payment_input.output.address
      let payment_script_credential = payment_addr.payment_credential
      expect ScriptCredential(own_policy) = payment_script_credential
      // Find the service reference input by searching for the token policy
      expect Some(service_ref_input) =
        get_input_by_token(
          tx.reference_inputs,
          service_policy_id,
          payment_datum.service_nft_tn,
        )
      expect Some(payment_output) =
        list.find(
          tx.outputs,
          fn(x) { x.address.payment_credential == payment_script_credential },
        )

      // Extract the datums
      expect service_datum: ServiceDatum =
        data.output_datum(service_ref_input.output)

      expect Payment(new_datum): PaymentValidatorDatum =
        data.output_datum(payment_output)

      // Extract the payment NFT from the input
      let asset_name =
        when
          value.tokens(payment_input_utxo.value, own_policy) |> dict.to_pairs
        is {
          [Pair(payment_tn, 1)] -> payment_tn
          _ -> fail @"payment token not found"
        }

      // Verify the new payment output
      let original_amount = value.lovelace_of(payment_input_utxo.value)
      let new_amount = value.lovelace_of(payment_output.value)
      let amount_increased = new_amount >= original_amount
      let extension_amount = new_amount - original_amount

      // Calculate and validate the fee increase
      let extension_period =
        new_datum.subscription_end - payment_datum.subscription_end
      let minimum_expected_fee_increase =
        extension_period * service_datum.service_fee_qty / service_datum.interval_length

      // Fee increase validation
      let fee_increase_valid = extension_amount >= minimum_expected_fee_increase

      // Validate that the extension follows the Service provider rules
      let valid_extension =
        validate_extension_datum(
          payment_datum,
          new_datum,
          extension_amount,
          service_datum,
          extension_period,
          minimum_expected_fee_increase,
        )

      // Ensure token output goes back to the script
      let payment_token_to_script =
        validate_token_output(
          payment_output,
          own_policy,
          asset_name,
          payment_script_credential,
        )

      and {
        reference_correct?,
        amount_increased?,
        valid_extension?,
        fee_increase_valid?,
        payment_token_to_script?,
      }
    }
    Penalty(_) -> False
  }
}

// spending validator
pub fn validate_merchant_withdraw(
  own_reference: OutputReference,
  service_policy_id: ByteArray,
  datum: PaymentValidatorDatum,
  merchant_input_index: Int,
  payment_input_index: Int,
  tx: Transaction,
) -> Bool {
  expect Some(merchant_input) = list.at(tx.inputs, merchant_input_index)
  // let merchant_input_utxo = merchant_input.output
  expect Some(payment_input) = list.at(tx.inputs, payment_input_index)
  let reference_correct = payment_input.output_reference == own_reference
  let payment_input_utxo = payment_input.output
  let payment_addr = payment_input.output.address
  let payment_script_credential = payment_addr.payment_credential
  expect ScriptCredential(own_policy) = payment_script_credential

  let merchant_input_utxo = merchant_input.output

  let merchant_token_name =
    when
      value.tokens(merchant_input_utxo.value, service_policy_id)
        |> dict.to_pairs
    is {
      [Pair(merchant_tn, 1)] -> merchant_tn
      _ -> fail @"merchant token not found"
    }
  let service_token_name =
    common_utils.convert_user_tn_to_ref(merchant_token_name)

  // Extract NFT info from payment input
  let payment_asset_name =
    when
      value.tokens(payment_input_utxo.value, own_policy) |> dict.to_pairs
    is {
      [Pair(payment_tn, 1)] -> payment_tn
      _ -> fail @"payment token not found"
    }

  when datum is {
    Payment(payment_datum) -> {
      let outputs = tx.outputs
      expect Some(payment_output) =
        list.find(
          outputs,
          fn(x) { x.address.payment_credential == payment_script_credential },
        )
      expect Payment(new_datum): PaymentValidatorDatum =
        data.output_datum(payment_output)

      // Get current time and calculate amounts
      let current_time = get_minimum_current_time_estimate(tx.validity_range)

      // Calculate withdrawable amount inline
      let time_since_last_claim =
        math.max(current_time - payment_datum.last_claimed, 0)
      let intervals_passed =
        time_since_last_claim / payment_datum.interval_length
      let claimable_intervals =
        math.min(intervals_passed, payment_datum.num_intervals)
      let withdrawable_amount =
        payment_datum.interval_amount * claimable_intervals

      let ada_amount = value.lovelace_of(merchant_input_utxo.value)
      let has_minimum_ada = ada_amount >= payment_datum.minimum_ada

      let payment_nft_preserved =
        value.quantity_of(payment_output.value, own_policy, payment_asset_name) == 1

      // Amount being withdrawn
      let payment_input_value =
        value.quantity_of(
          payment_input.output.value,
          payment_datum.subscription_fee.policy_id,
          payment_datum.subscription_fee.asset_name,
        )

      // Verify that any remaining funds are returned to the payment validator
      // This is the amount of funds that should be left in the payment script after the withdrawal.
      let payment_output_value =
        value.quantity_of(
          payment_output.value,
          payment_datum.subscription_fee.policy_id,
          payment_datum.subscription_fee.asset_name,
        )
      let withdrawn_amount = payment_input_value - payment_output_value

      // Update the last_claimed field in the new datum
      let last_claimed_updated =
        new_datum.last_claimed >= payment_datum.subscription_start && new_datum.last_claimed >= payment_datum.last_claimed
      let payment_datum_valid =
        new_datum == PaymentDatum {
          service_nft_tn: payment_datum.service_nft_tn,
          subscriber_nft_tn: payment_datum.subscriber_nft_tn,
          subscription_fee: payment_datum.subscription_fee,
          total_subscription_fee_qty: payment_datum.total_subscription_fee_qty - withdrawn_amount,
          subscription_start: payment_datum.subscription_start,
          subscription_end: payment_datum.subscription_end,
          interval_length: payment_datum.interval_length,
          interval_amount: payment_datum.interval_amount,
          num_intervals: payment_datum.num_intervals - intervals_passed,
          last_claimed: new_datum.last_claimed,
          penalty_fee: payment_datum.penalty_fee,
          penalty_fee_qty: payment_datum.penalty_fee_qty,
          minimum_ada: payment_datum.minimum_ada,
        }
      and {
        reference_correct?,
        (service_token_name == payment_datum.service_nft_tn)?,
        (withdrawn_amount <= withdrawable_amount)?,
        payment_nft_preserved?,
        must_be_after_date(tx.validity_range, payment_datum.subscription_start)?,
        payment_datum_valid?,
        last_claimed_updated?,
        has_minimum_ada?,
      }
    }

    Penalty(penalty_datum) -> {
      let penalty_nft_burned =
        value.quantity_of(
          value.from_minted_value(tx.mint),
          own_policy,
          payment_asset_name,
        ) == -1

      and {
        reference_correct?,
        (service_token_name == penalty_datum.service_nft_tn)?,
        penalty_nft_burned?,
      }
    }
  }
}

// Validate that the logic follows the Service provider rules / datum as a refernce input to ensure the
// penalty goes to the merchant when paying the penalty fees.
// spending validator
pub fn validate_unsubscribe(
  own_reference: OutputReference,
  account_policy_id: ByteArray,
  datum: PaymentValidatorDatum,
  subscriber_input_index: Int,
  payment_input_index: Int,
  tx: Transaction,
) -> Bool {
  when datum is {
    Payment(payment_datum) -> {
      // Find the inputs being spent (current Payment Validator UTxO)
      expect Some(subscriber_input) = list.at(tx.inputs, subscriber_input_index)
      expect Some(payment_input) = list.at(tx.inputs, payment_input_index)
      let reference_correct = payment_input.output_reference == own_reference
      let payment_input_utxo = payment_input.output
      let payment_addr = payment_input.output.address
      let payment_script_credential = payment_addr.payment_credential
      expect ScriptCredential(own_policy) = payment_script_credential

      // Verify the inputs contain 1 Account NFT Asset
      let input_has_subscriber_nft =
        validate_single_nft_input(
          subscriber_input,
          account_policy_id,
          payment_datum.subscriber_nft_tn,
        )

      let payment_asset_name =
        when
          value.tokens(payment_input_utxo.value, own_policy) |> dict.to_pairs
        is {
          [Pair(payment_tn, 1)] -> payment_tn
          _ -> fail @"payment token not found"
        }

      let outputs = tx.outputs

      expect Some(penalty_output) =
        list.find(
          outputs,
          fn(x) { x.address.payment_credential == payment_script_credential },
        )

      // Get amount going to penalty UTxO
      let penalty_fee_asset = payment_datum.penalty_fee
      let penalty_output_value =
        value.quantity_of(
          penalty_output.value,
          penalty_fee_asset.policy_id,
          penalty_fee_asset.asset_name,
        )

      // Verify Penalty UTxO
      expect Penalty(penalty_datum): PaymentValidatorDatum =
        data.output_datum(penalty_output)

      // Validate outputs
      let is_penalty_fee_in_ada =
        penalty_fee_asset.policy_id == value.ada_policy_id && penalty_fee_asset.asset_name == value.ada_asset_name
      let penalty_amount_valid =
        penalty_output_value >= if is_penalty_fee_in_ada {
          math.max(payment_datum.penalty_fee_qty, payment_datum.minimum_ada)
        } else {
          payment_datum.penalty_fee_qty
        }

      let penalty_output_valid =
        penalty_datum == PenaltyDatum {
          service_nft_tn: payment_datum.service_nft_tn,
          subscriber_nft_tn: payment_datum.subscriber_nft_tn,
          penalty_fee: payment_datum.penalty_fee,
          penalty_fee_qty: payment_datum.penalty_fee_qty,
        }

      // Ensure token output goes back to the script
      let payment_token_to_script =
        value.quantity_of(penalty_output.value, own_policy, payment_asset_name) == 1

      and {
        reference_correct?,
        input_has_subscriber_nft?,
        penalty_amount_valid?,
        penalty_output_valid?,
        payment_token_to_script?,
      }
    }
    Penalty(_) -> False
  }
}

// spending validator
pub fn validate_subscriber_withdraw(
  own_reference: OutputReference,
  service_policy_id: ByteArray,
  account_policy_id: ByteArray,
  datum: PaymentValidatorDatum,
  subscriber_input_index: Int,
  payment_input_index: Int,
  tx: Transaction,
) -> Bool {
  when datum is {
    Payment(payment_datum) -> {
      expect Some(subscriber_input) = list.at(tx.inputs, subscriber_input_index)
      expect Some(payment_input) = list.at(tx.inputs, payment_input_index)
      let reference_correct = payment_input.output_reference == own_reference
      let payment_input_utxo = payment_input.output
      let payment_addr = payment_input.output.address
      let payment_script_credential = payment_addr.payment_credential
      expect ScriptCredential(own_policy) = payment_script_credential

      let subscriber_nft_valid =
        value.quantity_of(
          subscriber_input.output.value,
          account_policy_id,
          payment_datum.subscriber_nft_tn,
        ) == 1
      // Find the service reference input
      expect Some(service_ref_input) =
        get_input_by_token(
          tx.reference_inputs,
          service_policy_id,
          payment_datum.service_nft_tn,
        )

      let payment_asset_name =
        when
          value.tokens(payment_input_utxo.value, own_policy) |> dict.to_pairs
        is {
          [Pair(payment_tn, 1)] -> payment_tn
          _ -> fail @"payment token not found"
        }

      expect Some(payment_output) =
        list.find(
          tx.outputs,
          fn(x) { x.address.payment_credential == payment_script_credential },
        )

      // Extract the service datum
      expect service_datum: ServiceDatum =
        data.output_datum(service_ref_input.output)

      expect Payment(payment_output_datum): PaymentValidatorDatum =
        data.output_datum(payment_output)

      // Maybe the datum should be changed?
      let payment_output_valid = payment_datum == payment_output_datum

      let payment_nft_in_output =
        value.quantity_of(payment_output.value, own_policy, payment_asset_name) == 1

      let service_is_inactive = !service_datum.is_active
      and {
        reference_correct?,
        subscriber_nft_valid?,
        service_is_inactive?,
        payment_output_valid?,
        payment_nft_in_output?,
      }
    }
    Penalty(_) -> False
  }
}
