use aiken/collection/list
use aiken/primitive/bytearray
use cardano/address.{Address, Script}
use cardano/assets.{PolicyId}
use cardano/transaction.{
  InlineDatum, Input, Output, OutputReference, Transaction,
}
use cardano/value
use payment_subscription/account_multi_validator/utils.{
  is_account_metadata_valid,
}
use payment_subscription/common/types.{AccountDatum}
use payment_subscription/common/utils.{validate_token_output} as common_utils
use types/cip68.{prefix_100, prefix_222}
use validation/payout

pub fn validate_create_account(
  own_policy: PolicyId,
  output_reference: OutputReference,
  input_index: Int,
  tx: Transaction,
) -> Bool {
  expect Some(input) = list.at(tx.inputs, input_index)

  let account_payment_credential = Script(own_policy)

  // Ensure this outref is spent in this transaction
  let is_outref_spent = input.output_reference == output_reference

  let OutputReference { transaction_id, output_index } = output_reference

  let ref_tkn =
    value.unique_token_name(transaction_id, output_index, prefix_100, "")
  let user_tkn =
    value.unique_token_name(transaction_id, output_index, prefix_222, "")

  let ref_value = assets.from_asset(own_policy, ref_tkn, 1)
  let user_value = assets.from_asset(own_policy, user_tkn, 1)
  let merged_mint = assets.merge(ref_value, user_value)

  // Find the output UTxO containing the reference token
  expect [user_output, ref_output, ..] = tx.outputs

  // Validate user token doesn't go back to the script
  let user_token_not_to_script =
    validate_token_output(
      user_output,
      own_policy,
      user_tkn,
      account_payment_credential,
      False,
    )

  // Validate reference token goes to the script
  let ref_token_to_script =
    validate_token_output(
      ref_output,
      own_policy,
      ref_tkn,
      account_payment_credential,
      True,
    )

  // Extract and validate the AccountDatum
  expect InlineDatum(account_inline_datum) = ref_output.datum
  expect account_datum: AccountDatum = account_inline_datum

  and {
    is_outref_spent?,
    // Validate the Datum has valid account inputs.
    is_account_metadata_valid(account_datum)?,
    // Validate that the redeemer only mints a single CIP68 compliant
    (merged_mint == tx.mint)?,
    // Ensure that the User NFT doesn't go to the Script 
    user_token_not_to_script?,
    // Ensure ref_nft goes back to the script.
    ref_token_to_script?,
  }
}

pub fn validate_delete_account(tx: Transaction) -> Bool {
  let mint_flat =
    tx.mint
      |> assets.flatten()

  when mint_flat is {
    [(_pid1, tkn1, amt1), (_pid2, tkn2, amt2)] -> and {
        amt1 == -1,
        amt2 == -1,
        bytearray.compare(bytearray.drop(tkn1, 4), bytearray.drop(tkn2, 4)) == Equal,
      }
    _ -> False
  }
}

pub fn validate_update_account(
  subscriber_input_index: Int,
  account_input_index: Int,
  tx: Transaction,
) -> Bool {
  // Validate that there are two script inputs 
  expect Some(subscriber_input) = list.at(tx.inputs, subscriber_input_index)
  expect Some(account_input) = list.at(tx.inputs, account_input_index)

  let account_addr: Address = account_input.output.address

  let ref_nft =
    account_input.output.value
      |> assets.without_lovelace()

  let user_nft =
    subscriber_input.output.value
      |> assets.without_lovelace()

  expect [(apolicy_id, ref_asset_name, _)] = assets.flatten(ref_nft)
  expect [(upolicy_id, usr_asset_name, _)] = assets.flatten(user_nft)

  // Find the output containing the reference NFT being sent back to this script itself
  let validating_output =
    common_utils.output_by_addr_value(tx.outputs, account_addr, ref_nft)

  // Extract the new datum from the validating output
  expect InlineDatum(account_inline_datum) = validating_output.datum
  expect new_datum: AccountDatum = account_inline_datum

  and {
    // Check that user input has a user nft,
    (assets.quantity_of(
      subscriber_input.output.value,
      upolicy_id,
      usr_asset_name,
    ) == 1)?,
    // Check that script input has a user nft,
    (assets.quantity_of(account_input.output.value, apolicy_id, ref_asset_name) == 1)?,
    // Validate that the metadata of the Reference NFT is updated within acceptable bounds .
    is_account_metadata_valid(new_datum)?,
    payout.at_least(account_addr, ref_nft, tx.outputs)?,
    common_utils.check_nft_output_utxo(validating_output)?,
  }
}

pub fn validate_remove_account(
  subscriber_input_index: Int,
  account_input_index: Int,
  tx: Transaction,
) -> Bool {
  // Validate that there are two script inputs 
  expect Some(subscriber_input) = list.at(tx.inputs, subscriber_input_index)
  expect Some(account_input) = list.at(tx.inputs, account_input_index)

  let ref_nft =
    account_input.output.value
      |> assets.without_lovelace()

  // expect [subscriber_input, account_input, ..] = tx.inputs
  let minted_value = tx.mint

  let user_nft =
    subscriber_input.output.value
      |> assets.without_lovelace()

  // Extract and validate the AccountDatum
  expect InlineDatum(account_inline_datum) = account_input.output.datum
  expect account_datum: AccountDatum = account_inline_datum

  expect [(apolicy_id, ref_asset_name, _)] = assets.flatten(ref_nft)
  expect [(upolicy_id, usr_asset_name, _)] = assets.flatten(user_nft)

  and {
    // Check that user input has a user nft,
    (assets.quantity_of(
      subscriber_input.output.value,
      upolicy_id,
      usr_asset_name,
    ) == 1)?,
    // Check that account input has a reference nft,
    (assets.quantity_of(account_input.output.value, apolicy_id, ref_asset_name) == 1)?,
    // Validate the Datum has valid account inputs.
    is_account_metadata_valid(account_datum)?,
    // Check that the reference NFT is burned
    (assets.quantity_of(minted_value, apolicy_id, ref_asset_name) == -1)?,
    // Check that the user NFT is burned
    (assets.quantity_of(minted_value, upolicy_id, usr_asset_name) == -1)?,
    // Ensure no output contains the reference NFT
    list.all(
      tx.outputs,
      fn(output) {
        assets.quantity_of(output.value, apolicy_id, ref_asset_name) == 0
      },
    )?,
  }
}
