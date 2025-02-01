use aiken/bytearray
use aiken/dict
use aiken/list
use aiken/transaction.{Input, Output, OutputReference}
use aiken/transaction/credential.{Address, ScriptCredential}
use aiken/transaction/value.{AssetName, PolicyId, Value}
use assist/data
use assist/types/cip68
use assist/values
use payment_subscription/common/types.{AccountDatum}
use payment_subscription/common/utils as common_utils

// !!! TODO: validate account creation time

pub fn is_account_metadata_valid(datum: AccountDatum) -> Bool {
  let email_valid = bytearray.length(datum.email_hash) > 0
  let phone_valid = bytearray.length(datum.phone_hash) > 0

  email_valid || phone_valid
}

// minting policy validator
pub fn validate_create_account(
  own_policy: PolicyId,
  output_reference: OutputReference,
  input_index: Int,
  output_index: Int,
  minted_value: Value,
  inputs: List<Input>,
  outputs: List<Output>,
) -> Bool {
  expect Some(input) = list.at(inputs, input_index)
  let is_outref_spent = input.output_reference == output_reference
  let OutputReference { transaction_id, output_index: output_ix } =
    output_reference

  let ref_token_name =
    values.unique_token_name(transaction_id.hash, output_ix, cip68.prefix_100)
  let user_token_name =
    values.unique_token_name(transaction_id.hash, output_ix, cip68.prefix_222)

  expect Some(output) = list.at(outputs, output_index)
  let output_at_account_address =
    output.address.payment_credential == credential.ScriptCredential(own_policy)
  expect output_datum: AccountDatum = data.output_datum(output)
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
    output_at_account_address?,
    is_account_metadata_valid(output_datum)?,
    output_has_token?,
    minted_tokens_correct?,
  }
}

// minting policy validator
pub fn validate_delete_account(
  own_policy: PolicyId,
  minted_tokens: Value,
  ref_token_name: AssetName,
) -> Bool {
  let user_token_name = common_utils.convert_ref_tn_to_user(ref_token_name)
  expect [Pair(token1, amount1), Pair(token2, amount2)] =
    value.tokens(minted_tokens, own_policy) |> dict.to_pairs
  and {
    token1 == ref_token_name && token2 == user_token_name || token1 == user_token_name && token2 == ref_token_name,
    amount1 == -1,
    amount2 == -1,
  }
}

// spending validator
pub fn validate_update_account(
  own_reference: OutputReference,
  reference_token_name: AssetName,
  user_input_index: Int,
  account_input_index: Int,
  reference_output_index: Int,
  inputs: List<Input>,
  outputs: List<Output>,
) -> Bool {
  expect Some(user_input) = list.at(inputs, user_input_index)
  expect Some(account_input) = list.at(inputs, account_input_index)
  let reference_correct = account_input.output_reference == own_reference

  let account_input_utxo = account_input.output
  let account_addr = account_input_utxo.address
  let account_payment_credential = account_addr.payment_credential
  expect ScriptCredential(own_policy) = account_payment_credential

  let reference_token_correct =
    value.quantity_of(
      account_input_utxo.value,
      own_policy,
      reference_token_name,
    ) == 1

  let user_token_name =
    common_utils.convert_ref_tn_to_user(reference_token_name)
  let user_token_at_input =
    value.quantity_of(user_input.output.value, own_policy, user_token_name) == 1

  expect Some(output) = list.at(outputs, reference_output_index)
  let output_at_account_address =
    output.address.payment_credential == account_payment_credential
  expect output_datum: AccountDatum = data.output_datum(output)
  let output_has_token =
    value.quantity_of(output.value, own_policy, reference_token_name) == 1

  and {
    reference_correct?,
    reference_token_correct?,
    user_token_at_input?,
    output_at_account_address?,
    is_account_metadata_valid(output_datum)?,
    output_has_token?,
  }
}

// spending validator
pub fn validate_remove_account(
  own_reference: OutputReference,
  reference_token_name: AssetName,
  user_input_index: Int,
  account_input_index: Int,
  inputs: List<Input>,
  minted_value: Value,
) -> Bool {
  expect Some(user_input) = list.at(inputs, user_input_index)
  expect Some(account_input) = list.at(inputs, account_input_index)
  let reference_correct = account_input.output_reference == own_reference

  let account_input_utxo = account_input.output
  let account_addr = account_input_utxo.address
  expect ScriptCredential(own_policy) = account_addr.payment_credential

  let reference_input_correct =
    value.quantity_of(
      account_input_utxo.value,
      own_policy,
      reference_token_name,
    ) == 1

  let user_token_name =
    common_utils.convert_ref_tn_to_user(reference_token_name)
  let user_token_at_input =
    value.quantity_of(user_input.output.value, own_policy, user_token_name) == 1

  let mint_correct =
    value.quantity_of(minted_value, own_policy, reference_token_name) == -1

  and {
    reference_correct?,
    reference_input_correct?,
    user_token_at_input?,
    mint_correct?,
  }
}
