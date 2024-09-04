use aiken/bytearray
use aiken/list
use aiken/transaction.{Input, Output, OutputReference, Transaction}
use aiken/transaction/credential.{Address}
use aiken/transaction/value.{PolicyId, Value}
use assist/count
use assist/data
use assist/payout
use assist/types/cip68
use assist/values
use payment_subscription/account_multi_validator/utils.{
  is_account_metadata_valid,
}
use payment_subscription/common/types.{AccountDatum}
use payment_subscription/common/utils.{validate_token_output} as common_utils

pub fn validate_create_account(
  own_policy: PolicyId,
  input: Input,
  minted_tokens: Value,
  output_reference: OutputReference,
  outputs: List<Output>,
) -> Bool {
  let account_payment_credential = credential.ScriptCredential(own_policy)

  // Ensure this outref is spent in this transaction
  let is_outref_spent = input.output_reference == output_reference

  let OutputReference { transaction_id, output_index } = output_reference

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

  // Find the output UTxO containing the reference token
  expect [user_output, ref_output, ..] = outputs

  // Validate user token
  let user_token_not_to_script =
    validate_token_output(
      user_output,
      own_policy,
      user_tkn,
      account_payment_credential,
      False,
    )

  // Validate reference token
  let ref_token_to_script =
    validate_token_output(
      ref_output,
      own_policy,
      ref_tkn,
      account_payment_credential,
      True,
    )
  // Extract and validate the AccountDatum
  expect datum: AccountDatum = data.output_datum(ref_output)

  and {
    is_outref_spent?,
    // Validate the Datum has valid account inputs.
    is_account_metadata_valid(datum)?,
    // Validate that the redeemer only mints a single CIP68 compliant
    (merged_mint == minted_tokens)?,
    // Ensure that the User NFT doesn't go to the Script 
    user_token_not_to_script?,
    // Ensure ref_nft goes back to the script.
    ref_token_to_script?,
  }
}

pub fn validate_delete_account(minted_tokens: Value) -> Bool {
  let mint_flat =
    minted_tokens
      |> value.flatten()

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
  // datum: AccountDatum,
  account_addr: Address,
  ref_nft: Value,
  tx: Transaction,
) -> Bool {
  // Find the output containing the reference NFT being sent back to this script itself
  let validating_output =
    common_utils.output_by_addr_value(tx.outputs, account_addr, ref_nft)

  // Extract the new datum from the validating output
  expect new_datum: AccountDatum = data.output_datum(validating_output)

  and {
    // Validate that the metadata of the Reference NFT is updated within acceptable bounds .
    is_account_metadata_valid(new_datum)?,
    payout.at_least(account_addr, ref_nft, tx.outputs)?,
    common_utils.check_nft_output_utxo(validating_output)?,
  }
}

pub fn validate_remove_account(
  account_addr: Address,
  ref_nft: Value,
  tx: Transaction,
) -> Bool {
  expect [(policy_id, asset_name, _)] = value.flatten(ref_nft)

  // Check that the reference NFT is burned
  let minted_value = value.from_minted_value(tx.mint)
  let burn_quantity = value.quantity_of(minted_value, policy_id, asset_name)
  let is_ref_nft_burned = burn_quantity == -1

  and {
    // Validate that there are two script input and one Script output back to the script address.
    // two script input
    count.inputs_by_addr(tx.inputs, account_addr, 2)?,
    // one script output
    count.outputs_by_addr(tx.outputs, account_addr, 1)?,
    // Check that the reference NFT is burned
    is_ref_nft_burned?,
    // Ensure no output contains the reference NFT
    list.all(
      tx.outputs,
      fn(output) { value.quantity_of(output.value, policy_id, asset_name) == 0 },
    )?,
  }
}
