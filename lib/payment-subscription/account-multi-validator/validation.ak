use aiken/builtin
use aiken/bytearray
use aiken/dict
use aiken/list
use aiken/transaction.{Input, Output, OutputReference, Transaction}
use aiken/transaction/credential.{Address, ScriptCredential}
use aiken/transaction/value.{PolicyId, Value}
use assist/data
use assist/types/cip68
use assist/values
use payment_subscription/account_multi_validator/utils.{
  is_account_metadata_valid,
}
use payment_subscription/common/types.{AccountDatum}
use payment_subscription/common/utils as common_utils

// minting policy validator
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
  expect Some(ref_output) =
    list.find(
      outputs,
      fn(x) { x.address.payment_credential == account_payment_credential },
    )

  // Validate reference token goes to the script
  let ref_token_to_script =
    value.quantity_of(ref_output.value, own_policy, ref_tkn) == 1
  // Extract and validate the AccountDatum
  expect datum: AccountDatum = data.output_datum(ref_output)

  and {
    is_outref_spent?,
    // Validate the Datum has valid account inputs.
    is_account_metadata_valid(datum)?,
    // Validate that the redeemer only mints a single CIP68 compliant
    (merged_mint == minted_tokens)?,
    // Ensure ref_nft goes back to the script.
    ref_token_to_script?,
  }
}

// minting policy validator
pub fn validate_delete_account(
  own_policy: PolicyId,
  minted_tokens: Value,
) -> Bool {
  when value.tokens(minted_tokens, own_policy) |> dict.to_pairs is {
    [Pair(tkn1, amt1), Pair(tkn2, amt2)] -> and {
        amt1 == -1,
        amt2 == -1,
        bytearray.compare(bytearray.drop(tkn1, 4), bytearray.drop(tkn2, 4)) == Equal,
      }
    _ -> False
  }
}

// spending validator
pub fn validate_update_account(
  own_reference: OutputReference,
  subscriber_input_index: Int,
  account_input_index: Int,
  tx: Transaction,
) -> Bool {
  // Validate that there are two script inputs 
  expect Some(subscriber_input) = list.at(tx.inputs, subscriber_input_index)
  expect Some(account_input) = list.at(tx.inputs, account_input_index)
  let reference_correct = account_input.output_reference == own_reference

  let account_input_utxo = account_input.output
  let account_addr = account_input_utxo.address
  expect ScriptCredential(own_policy) = account_addr.payment_credential

  let ref_asset_name =
    when
      value.tokens(account_input_utxo.value, own_policy) |> dict.to_pairs
    is {
      [Pair(ref_tn, 1)] -> ref_tn
      _ -> fail @"reference token not found"
    }
  let user_token_name = common_utils.convert_ref_tn_to_user(ref_asset_name)
  let user_token_at_subscriber_input =
    value.tokens(subscriber_input.output.value, own_policy)
      |> dict.to_pairs
      |> list.any(fn(x) { and {
              builtin.snd_pair(x) == 1,
              builtin.fst_pair(x) == user_token_name,
            } })

  // Find the output containing the reference NFT being sent back to this script itself
  let validating_output =
    common_utils.output_by_addr_value(
      tx.outputs,
      account_addr,
      own_policy,
      ref_asset_name,
    )

  // Extract the new datum from the validating output
  expect new_datum: AccountDatum = data.output_datum(validating_output)

  and {
    reference_correct?,
    is_account_metadata_valid(new_datum)?,
    (value.quantity_of(validating_output.value, own_policy, ref_asset_name) == 1)?,
    user_token_at_subscriber_input?,
  }
}

// spending validator
pub fn validate_remove_account(
  own_reference: OutputReference,
  subscriber_input_index: Int,
  account_input_index: Int,
  tx: Transaction,
) -> Bool {
  // Validate that there are two script inputs 
  expect Some(subscriber_input) = list.at(tx.inputs, subscriber_input_index)
  expect Some(account_input) = list.at(tx.inputs, account_input_index)
  let reference_correct = account_input.output_reference == own_reference

  let account_input_utxo = account_input.output
  let account_addr = account_input_utxo.address
  expect ScriptCredential(own_policy) = account_addr.payment_credential

  let ref_asset_name =
    when
      value.tokens(account_input_utxo.value, own_policy) |> dict.to_pairs
    is {
      [Pair(ref_tn, 1)] -> ref_tn
      _ -> fail @"reference token not found"
    }
  let user_token_name = common_utils.convert_ref_tn_to_user(ref_asset_name)
  let user_token_at_subscriber_input =
    value.tokens(subscriber_input.output.value, own_policy)
      |> dict.to_pairs
      |> list.any(fn(x) { and {
              builtin.snd_pair(x) == 1,
              builtin.fst_pair(x) == user_token_name,
            } })

  and {
    reference_correct?,
    // Check that the reference NFT is burned
    (value.quantity_of(
      tx.mint |> value.from_minted_value(),
      own_policy,
      ref_asset_name,
    ) == -1)?,
    // Check that the user NFT is burned
    user_token_at_subscriber_input?,
  }
}
