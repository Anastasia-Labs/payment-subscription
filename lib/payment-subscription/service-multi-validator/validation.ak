use aiken/dict
use aiken/list
use aiken/transaction.{Input, Output, OutputReference}
use aiken/transaction/credential.{Address, ScriptCredential}
use aiken/transaction/value.{AssetName, PolicyId, Value}
use assist/data
use assist/types/cip68
use assist/values
use payment_subscription/common/types.{ServiceDatum}
use payment_subscription/common/utils as common_utils

pub fn is_service_metadata_valid(datum: ServiceDatum) -> Bool {
  let num_intervals = datum.num_intervals
  and {
    (datum.service_fee > 0)?,
    (datum.penalty_fee >= 0)?,
    (datum.interval_length > 0)?,
    (num_intervals > 0)?,
    (num_intervals <= 100)?,
    datum.is_active?,
  }
}

// minting policy validator
pub fn validate_create_service(
  own_policy: PolicyId,
  output_reference: OutputReference,
  input_index: Int,
  service_output_index: Int,
  minted_value: Value,
  inputs: List<Input>,
  outputs: List<Output>,
) -> Bool {
  expect Some(input) = list.at(inputs, input_index)
  let is_outref_spent = input.output_reference == output_reference
  let OutputReference { transaction_id, output_index } = output_reference

  let ref_token_name =
    values.unique_token_name(
      transaction_id.hash,
      output_index,
      cip68.prefix_100,
    )
  let user_token_name =
    values.unique_token_name(
      transaction_id.hash,
      output_index,
      cip68.prefix_222,
    )
  expect Some(output) = list.at(outputs, service_output_index)
  let output_at_service_address =
    output.address.payment_credential == credential.ScriptCredential(own_policy)
  expect datum: ServiceDatum = data.output_datum(output)
  let output_has_token =
    value.quantity_of(output.value, own_policy, ref_token_name) == 1

  let minted_tokens = value.tokens(minted_value, own_policy)
  expect [Pair(token1, amount1), Pair(token2, amount2)] =
    dict.to_pairs(minted_tokens)
  let minted_tokens_correct =
    (
      token1 == ref_token_name && token2 == user_token_name || token1 == user_token_name && token2 == ref_token_name
    ) && amount1 == 1 && amount2 == 1

  and {
    is_outref_spent?,
    output_at_service_address?,
    is_service_metadata_valid(datum)?,
    output_has_token?,
    minted_tokens_correct?,
  }
}

// spending validator
pub fn validate_update_service(
  own_reference: OutputReference,
  datum: ServiceDatum,
  service_ref_token_name: AssetName,
  merchant_input_index: Int,
  service_input_index: Int,
  service_output_index: Int,
  inputs: List<Input>,
  outputs: List<Output>,
) -> Bool {
  expect Some(merchant_input) = list.at(inputs, merchant_input_index)
  expect Some(service_input) = list.at(inputs, service_input_index)
  let reference_correct = service_input.output_reference == own_reference

  let service_utxo = service_input.output
  let service_addr = service_utxo.address
  let service_payment_credential = service_addr.payment_credential
  expect ScriptCredential(own_policy) = service_payment_credential

  let reference_input_correct =
    value.quantity_of(service_utxo.value, own_policy, service_ref_token_name) == 1

  let service_owner_asset_name =
    common_utils.convert_ref_tn_to_user(service_ref_token_name)
  let owner_token_at_input =
    value.quantity_of(
      merchant_input.output.value,
      own_policy,
      service_owner_asset_name,
    ) == 1

  expect Some(output) = list.at(outputs, service_output_index)
  let output_at_service_address =
    output.address.payment_credential == service_payment_credential
  expect output_datum: ServiceDatum = data.output_datum(output)
  let output_has_token =
    value.quantity_of(output.value, own_policy, service_ref_token_name) == 1

  let output_datum_correct = and {
      output_datum.service_fee_policyid == datum.service_fee_policyid,
      output_datum.service_fee_assetname == datum.service_fee_assetname,
      output_datum.penalty_fee_policyid == datum.penalty_fee_policyid,
      output_datum.penalty_fee_assetname == datum.penalty_fee_assetname,
    }

  and {
    reference_correct?,
    reference_input_correct?,
    owner_token_at_input?,
    output_at_service_address?,
    output_has_token?,
    output_datum_correct?,
    is_service_metadata_valid(output_datum)?,
  }
}

// spending validator
pub fn validate_remove_service(
  own_reference: OutputReference,
  datum: ServiceDatum,
  service_ref_token_name: AssetName,
  merchant_input_index: Int,
  service_input_index: Int,
  service_output_index: Int,
  inputs: List<Input>,
  outputs: List<Output>,
) -> Bool {
  expect Some(merchant_input) = list.at(inputs, merchant_input_index)
  expect Some(service_input) = list.at(inputs, service_input_index)
  let reference_correct = service_input.output_reference == own_reference

  let service_utxo = service_input.output
  let service_addr = service_utxo.address
  let service_payment_credential = service_addr.payment_credential
  expect ScriptCredential(own_policy) = service_payment_credential

  let reference_input_correct =
    value.quantity_of(service_utxo.value, own_policy, service_ref_token_name) == 1

  let service_owner_asset_name =
    common_utils.convert_ref_tn_to_user(service_ref_token_name)
  let owner_token_at_input =
    value.quantity_of(
      merchant_input.output.value,
      own_policy,
      service_owner_asset_name,
    ) == 1

  expect Some(output) = list.at(outputs, service_output_index)
  let output_at_service_address =
    output.address.payment_credential == service_payment_credential
  expect output_datum: ServiceDatum = data.output_datum(output)
  let output_has_token =
    value.quantity_of(output.value, own_policy, service_ref_token_name) == 1

  let ServiceDatum {
    service_fee_policyid,
    service_fee_assetname,
    service_fee,
    penalty_fee_policyid,
    penalty_fee_assetname,
    penalty_fee,
    interval_length,
    num_intervals,
    ..
  } = datum

  let output_datum_correct =
    output_datum == ServiceDatum {
      service_fee_policyid,
      service_fee_assetname,
      service_fee,
      penalty_fee_policyid,
      penalty_fee_assetname,
      penalty_fee,
      interval_length,
      num_intervals,
      is_active: False,
    }
  and {
    reference_correct?,
    reference_input_correct?,
    owner_token_at_input?,
    output_at_service_address?,
    output_has_token?,
    output_datum_correct?,
  }
}
