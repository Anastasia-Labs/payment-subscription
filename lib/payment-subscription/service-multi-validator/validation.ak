use aiken/collection/dict
use aiken/collection/list
use cardano/address.{Address, Script}
use cardano/assets.{
  AssetName, PolicyId, Value, ada_policy_id, policies, quantity_of, tokens,
}
use cardano/transaction.{InlineDatum, Input, Output, OutputReference}
use payment_subscription/common/cip68
use payment_subscription/common/types.{ServiceDatum}
use payment_subscription/common/utils as common_utils
use payment_subscription/common/values

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
  input_index: Int,
  service_output_index: Int,
  minted_value: Value,
  inputs: List<Input>,
  outputs: List<Output>,
) -> Bool {
  expect Some(Input { output_reference, .. }) = list.at(inputs, input_index)
  let OutputReference { transaction_id, output_index } = output_reference

  let ref_token_name =
    values.unique_token_name(transaction_id, output_index, cip68.prefix_100)
  let user_token_name =
    values.unique_token_name(transaction_id, output_index, cip68.prefix_222)
  expect Some(Output {
    address: output_address,
    value: output_value,
    datum: InlineDatum(output_datum),
    ..
  }) = list.at(outputs, service_output_index)
  let output_at_service_address =
    output_address.payment_credential == Script(own_policy)
  expect datum: ServiceDatum = output_datum

  let output_policies_correct =
    policies(output_value) == [ada_policy_id, own_policy]
  expect [Pair(ref_tkn, 1)] = dict.to_pairs(tokens(output_value, own_policy))
  let output_token_correct = ref_tkn == ref_token_name

  let minted_tokens = tokens(minted_value, own_policy)
  expect [Pair(token1, amount1),
    Pair(token2, amount2)] = dict.to_pairs(minted_tokens)
  let minted_tokens_correct =
    (
      token1 == ref_token_name && token2 == user_token_name || token1 == user_token_name && token2 == ref_token_name
    ) && amount1 == 1 && amount2 == 1

  and {
    output_at_service_address?,
    is_service_metadata_valid(datum)?,
    output_policies_correct?,
    output_token_correct?,
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
  expect Script(own_policy) = service_payment_credential

  let reference_input_correct =
    quantity_of(service_utxo.value, own_policy, service_ref_token_name) == 1

  let service_owner_asset_name =
    common_utils.convert_ref_tn_to_user(service_ref_token_name)
  let owner_token_at_input =
    quantity_of(
      merchant_input.output.value,
      own_policy,
      service_owner_asset_name,
    ) == 1

  expect Some(Output {
    address: output_address,
    value: output_value,
    datum: InlineDatum(output_datum),
    ..
  }) = list.at(outputs, service_output_index)
  let output_at_service_address =
    output_address.payment_credential == service_payment_credential
  expect out_datum: ServiceDatum = output_datum

  let output_policies_correct =
    policies(output_value) == [ada_policy_id, own_policy]
  let output_has_token =
    dict.to_pairs(tokens(output_value, own_policy)) == [
      Pair(service_ref_token_name, 1),
    ]

  let output_datum_correct = and {
      out_datum.service_fee_policyid == datum.service_fee_policyid,
      out_datum.service_fee_assetname == datum.service_fee_assetname,
      out_datum.penalty_fee_policyid == datum.penalty_fee_policyid,
      out_datum.penalty_fee_assetname == datum.penalty_fee_assetname,
    }

  and {
    reference_correct?,
    reference_input_correct?,
    owner_token_at_input?,
    output_at_service_address?,
    output_policies_correct?,
    output_has_token?,
    output_datum_correct?,
    is_service_metadata_valid(out_datum)?,
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
  expect Script(own_policy) = service_payment_credential

  let reference_input_correct =
    quantity_of(service_utxo.value, own_policy, service_ref_token_name) == 1

  let service_owner_asset_name =
    common_utils.convert_ref_tn_to_user(service_ref_token_name)
  let owner_token_at_input =
    quantity_of(
      merchant_input.output.value,
      own_policy,
      service_owner_asset_name,
    ) == 1

  expect Some(Output {
    address: output_address,
    value: output_value,
    datum: InlineDatum(output_datum),
    ..
  }) = list.at(outputs, service_output_index)
  let output_at_service_address =
    output_address.payment_credential == service_payment_credential
  expect out_datum: ServiceDatum = output_datum

  let output_policies_correct =
    policies(output_value) == [ada_policy_id, own_policy]
  let output_has_token =
    dict.to_pairs(tokens(output_value, own_policy)) == [
      Pair(service_ref_token_name, 1),
    ]

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
    out_datum == ServiceDatum {
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
    output_policies_correct?,
    output_has_token?,
    output_datum_correct?,
  }
}
