use aiken/collection/list
use cardano/address.{Address, Script}
use cardano/assets.{PolicyId}
use cardano/transaction.{
  InlineDatum, Input, Output, OutputReference, Transaction,
}
use cardano/value
use payment_subscription/common/types.{ServiceDatum}
use payment_subscription/common/utils.{validate_token_output} as common_utils
use payment_subscription/service_multi_validator/utils.{
  is_fee_change_valid, is_service_metadata_valid,
}
use types/cip68.{prefix_100, prefix_222}
use validation/payout

pub fn validate_create_service(
  own_policy: PolicyId,
  output_reference: OutputReference,
  input_index: Int,
  tx: Transaction,
) -> Bool {
  let service_payment_credential = Script(own_policy)

  let OutputReference { transaction_id, output_index } = output_reference
  expect Some(input) = list.at(tx.inputs, input_index)

  let is_outref_spent = input.output_reference == output_reference

  let ref_tkn =
    value.unique_token_name(transaction_id, output_index, prefix_100, "")
  let user_tkn =
    value.unique_token_name(transaction_id, output_index, prefix_222, "")

  let ref_value = assets.from_asset(own_policy, ref_tkn, 1)
  let user_value = assets.from_asset(own_policy, user_tkn, 1)
  let merged_mint = assets.merge(ref_value, user_value)

  // Expect two ouptuts user_output @ index 0 && ref_output @ index 1
  expect [user_output, ref_output, ..] = tx.outputs

  // Validate user token
  let user_token_not_to_script =
    validate_token_output(
      user_output,
      own_policy,
      user_tkn,
      service_payment_credential,
      False,
    )

  // Validate reference token
  let ref_token_to_script =
    validate_token_output(
      ref_output,
      own_policy,
      ref_tkn,
      service_payment_credential,
      True,
    )

  // Extract and validate the ServiceDatum
  expect InlineDatum(service_inline_datum) = ref_output.datum
  expect service_datum: ServiceDatum = service_inline_datum
  let metadata_valid = is_service_metadata_valid(service_datum)

  and {
    is_outref_spent?,
    // Validate the Datum meets Service Provider requirements.
    metadata_valid?,
    // Validate that the redeemer only mints a single CIP68 compliant
    (merged_mint == tx.mint)?,
    // Ensure that the User NFT doesn't go to the Script 
    user_token_not_to_script?,
    // Ensure ref_nft goes back to the script.
    ref_token_to_script?,
  }
}

pub fn validate_update_service(
  datum: Option<ServiceDatum>,
  merchant_input_index: Int,
  service_input_index: Int,
  tx: Transaction,
) -> Bool {
  expect Some(merchant_input) = list.at(tx.inputs, merchant_input_index)
  expect Some(service_input) = list.at(tx.inputs, service_input_index)

  let service_addr: Address = service_input.output.address

  let service_ref_nft =
    service_input.output.value
      |> assets.without_lovelace()

  let merchant_nft =
    merchant_input.output.value
      |> assets.without_lovelace()

  expect [(spolicy_id, ref_asset_name, _)] = assets.flatten(service_ref_nft)
  expect [(mpolicy_id, usr_asset_name, _)] = assets.flatten(merchant_nft)

  let validating_output =
    common_utils.output_by_addr_value(tx.outputs, service_addr, service_ref_nft)

  // Extract the new datum from the validating output
  expect Some(option_datum) = datum
  expect InlineDatum(service_inline_datum) = validating_output.datum
  expect new_datum: ServiceDatum = service_inline_datum

  // Validate service fee changes are within acceptable range
  let service_fee_change_valid =
    is_fee_change_valid(option_datum.service_fee_qty, new_datum.service_fee_qty)

  and {
    // Check that service input has a reference nft,
    (assets.quantity_of(service_input.output.value, spolicy_id, ref_asset_name) == 1)?,
    // Check that merchant input has a user nft,
    (assets.quantity_of(merchant_input.output.value, mpolicy_id, usr_asset_name) == 1)?,
    // Validate that the metadata of the Reference NFT is updated within acceptable bounds .
    is_service_metadata_valid(new_datum)?,
    //  Validate that the service fee should be limited to a range to prevent extreme flucutation in service
    // fee by the service provider e.g +/-10%
    service_fee_change_valid?,
    payout.at_least(service_addr, service_ref_nft, tx.outputs)?,
    common_utils.check_nft_output_utxo(validating_output)?,
  }
}

pub fn validate_remove_service(
  datum: Option<ServiceDatum>,
  merchant_input_index: Int,
  service_input_index: Int,
  tx: Transaction,
) -> Bool {
  // Validate that there are two script inputs 
  expect Some(merchant_input) = list.at(tx.inputs, merchant_input_index)
  expect Some(service_input) = list.at(tx.inputs, service_input_index)

  let service_addr: Address = service_input.output.address

  let service_ref_nft =
    service_input.output.value
      |> assets.without_lovelace()

  let merchant_nft =
    merchant_input.output.value
      |> assets.without_lovelace()

  expect [(spolicy_id, ref_asset_name, _)] = assets.flatten(service_ref_nft)
  expect [(mpolicy_id, usr_asset_name, _)] = assets.flatten(merchant_nft)

  let validating_output =
    common_utils.output_by_addr_value(tx.outputs, service_addr, service_ref_nft)

  expect Some(option_datum) = datum
  expect InlineDatum(service_inline_datum) = validating_output.datum
  expect new_datum: ServiceDatum = service_inline_datum

  // Ensure the service is being inactivated
  let service_is_inactive = option_datum.is_active && !new_datum.is_active

  let validating_output =
    common_utils.output_by_addr_value(tx.outputs, service_addr, service_ref_nft)
  let other_fields_unchanged =
    option_datum.service_fee == new_datum.service_fee && option_datum.service_fee_qty == new_datum.service_fee_qty && option_datum.penalty_fee == new_datum.penalty_fee && option_datum.penalty_fee_qty == new_datum.penalty_fee_qty && option_datum.num_intervals == new_datum.num_intervals
  and {
    // Check that user input has a user nft,
    (assets.quantity_of(merchant_input.output.value, mpolicy_id, usr_asset_name) == 1)?,
    // Check that service input has a service nft,
    (assets.quantity_of(service_input.output.value, spolicy_id, ref_asset_name) == 1)?,
    // Check that the reference NFT is burned
    service_is_inactive?,
    other_fields_unchanged?,
    // Ensure the NFT is still present in the output
    payout.at_least(service_addr, service_ref_nft, tx.outputs)?,
    common_utils.check_nft_output_utxo(validating_output)?,
  }
}
