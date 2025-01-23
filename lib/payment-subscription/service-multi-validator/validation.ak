use aiken/dict
use aiken/list
use aiken/transaction.{Input, Output, OutputReference, Transaction}
use aiken/transaction/credential.{Address, ScriptCredential}
use aiken/transaction/value.{PolicyId, Value}
use assist/data
use assist/types/cip68
use assist/values
use payment_subscription/common/types.{ServiceDatum}
use payment_subscription/common/utils as common_utils
use payment_subscription/service_multi_validator/utils.{
  is_service_metadata_valid,
}

pub fn validate_create_service(
  own_policy: PolicyId,
  input: Input,
  minted_tokens: Value,
  output_reference: OutputReference,
  outputs: List<Output>,
) -> Bool {
  let service_payment_credential = credential.ScriptCredential(own_policy)

  let OutputReference { transaction_id, output_index } = output_reference
  let is_outref_spent = input.output_reference == output_reference

  let ref_tkn =
    values.unique_token_name(
      transaction_id.hash,
      output_index,
      cip68.prefix_100,
    )
  let user_tkn =
    values.unique_token_name(
      transaction_id.hash,
      output_index,
      cip68.prefix_222,
    )

  let ref_value = value.from_asset(own_policy, ref_tkn, 1)
  let user_value = value.from_asset(own_policy, user_tkn, 1)
  let merged_mint = value.merge(ref_value, user_value)

  expect Some(ref_output) =
    list.find(
      outputs,
      fn(x) { x.address.payment_credential == service_payment_credential },
    )

  let ref_token_to_script =
    value.quantity_of(ref_output.value, own_policy, ref_tkn) == 1
  expect datum: ServiceDatum = data.output_datum(ref_output)
  let metadata_valid = is_service_metadata_valid(datum)
  and {
    is_outref_spent?,
    metadata_valid?,
    (merged_mint == minted_tokens)?,
    ref_token_to_script?,
  }
}

pub fn validate_update_service(
  datum: ServiceDatum,
  merchant_input_index: Int,
  service_input_index: Int,
  tx: Transaction,
  own_reference: OutputReference,
) -> Bool {
  expect Some(merchant_input) = list.at(tx.inputs, merchant_input_index)
  expect Some(service_input) = list.at(tx.inputs, service_input_index)
  let reference_correct = service_input.output_reference == own_reference
  let service_utxo = service_input.output
  let service_addr = service_utxo.address
  let service_script_credential = service_addr.payment_credential
  expect ScriptCredential(own_policy) = service_script_credential

  let service_asset_name =
    when value.tokens(service_utxo.value, own_policy) |> dict.to_pairs is {
      [Pair(service_tn, 1)] -> service_tn
      _ -> fail @"payment token not found"
    }
  let service_owner_asset_name =
    common_utils.convert_ref_tn_to_user(service_asset_name)
  let merchant_nft_valid =
    value.quantity_of(
      merchant_input.output.value,
      own_policy,
      service_owner_asset_name,
    ) == 1

  let validating_output =
    common_utils.output_by_addr_value(
      tx.outputs,
      service_addr,
      own_policy,
      service_asset_name,
    )
  expect new_datum: ServiceDatum = data.output_datum(validating_output)
  let assets_preserved =
    datum.service_fee == new_datum.service_fee && datum.penalty_fee == new_datum.penalty_fee
  and {
    reference_correct?,
    merchant_nft_valid?,
    (value.quantity_of(validating_output.value, own_policy, service_asset_name) == 1)?,
    is_service_metadata_valid(new_datum)?,
    assets_preserved?,
  }
}

pub fn validate_remove_service(
  datum: ServiceDatum,
  merchant_input_index: Int,
  service_input_index: Int,
  tx: Transaction,
  own_reference: OutputReference,
) -> Bool {
  expect Some(merchant_input) = list.at(tx.inputs, merchant_input_index)
  expect Some(service_input) = list.at(tx.inputs, service_input_index)
  let reference_correct = service_input.output_reference == own_reference
  let service_utxo = service_input.output
  let service_addr = service_utxo.address
  let service_script_credential = service_addr.payment_credential
  expect ScriptCredential(own_policy) = service_script_credential

  let service_asset_name =
    when value.tokens(service_utxo.value, own_policy) |> dict.to_pairs is {
      [Pair(service_tn, 1)] -> service_tn
      _ -> fail @"payment token not found"
    }
  let service_owner_asset_name =
    common_utils.convert_ref_tn_to_user(service_asset_name)
  let merchant_nft_valid =
    value.quantity_of(
      merchant_input.output.value,
      own_policy,
      service_owner_asset_name,
    ) == 1

  let validating_output =
    common_utils.output_by_addr_value(
      tx.outputs,
      service_addr,
      own_policy,
      service_asset_name,
    )
  expect new_datum: ServiceDatum = data.output_datum(validating_output)
  let new_datum_valid =
    new_datum == ServiceDatum {
      service_fee: datum.service_fee,
      service_fee_qty: datum.service_fee_qty,
      penalty_fee: datum.penalty_fee,
      penalty_fee_qty: datum.penalty_fee_qty,
      interval_length: datum.interval_length,
      num_intervals: datum.num_intervals,
      minimum_ada: datum.minimum_ada,
      is_active: False,
    }
  and {
    reference_correct?,
    merchant_nft_valid?,
    datum.is_active?,
    new_datum_valid?,
    (value.quantity_of(validating_output.value, own_policy, service_asset_name) == 1)?,
  }
}
