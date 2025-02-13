use aiken/collection/dict
use aiken/collection/list
use aiken/primitive/bytearray
use cardano/address.{Address, Script}
use cardano/assets.{
  AssetName, PolicyId, Value, ada_policy_id, policies, quantity_of, tokens,
}
use cardano/transaction.{InlineDatum, Input, Output, OutputReference}
use payment_subscription/common/cip68
use payment_subscription/common/types.{AccountDatum}
use payment_subscription/common/utils as common_utils
use payment_subscription/common/values

pub fn is_account_metadata_valid(datum: AccountDatum) -> Bool {
  let email_valid = bytearray.length(datum.email_hash) == 32
  let phone_valid = bytearray.length(datum.phone_hash) == 32

  email_valid || phone_valid
}

// minting policy validator
pub fn validate_create_account(
  own_policy: PolicyId,
  input_index: Int,
  output_index: Int,
  minted_value: Value,
  inputs: List<Input>,
  outputs: List<Output>,
) -> Bool {
  expect Some(input) = list.at(inputs, input_index)
  let OutputReference { transaction_id, output_index: output_ix } =
    input.output_reference

  let ref_token_name =
    values.unique_token_name(transaction_id, output_ix, cip68.prefix_100)
  let user_token_name =
    values.unique_token_name(transaction_id, output_ix, cip68.prefix_222)

  expect Some(Output {
    address: output_address,
    value: output_value,
    datum: InlineDatum(output_datum),
    ..
  }) = list.at(outputs, output_index)
  let output_at_account_address =
    output_address.payment_credential == Script(own_policy)
  expect out_datum: AccountDatum = output_datum

  let output_policies_correct =
    policies(output_value) == [ada_policy_id, own_policy]
  expect [Pair(ref_tkn, 1)] = dict.to_pairs(tokens(output_value, own_policy))
  let output_token_correct = ref_tkn == ref_token_name

  let minted_tokens = tokens(minted_value, own_policy)
  expect [Pair(token1, amount1),
    Pair(token2, amount2)] = dict.to_pairs(minted_tokens)
  let minted_tokens_correct =
    ( token1 == ref_token_name && token2 == user_token_name ) && amount1 == 1 && amount2 == 1

  and {
    output_at_account_address?,
    is_account_metadata_valid(out_datum)?,
    output_policies_correct?,
    output_token_correct?,
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
  expect [Pair(token1, amount1),
    Pair(token2, amount2)] = tokens(minted_tokens, own_policy) |> dict.to_pairs
  and {
    token1 == ref_token_name && token2 == user_token_name,
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
  expect Script(own_policy) = account_payment_credential

  let reference_token_correct =
    quantity_of(account_input_utxo.value, own_policy, reference_token_name) == 1

  let user_token_name =
    common_utils.convert_ref_tn_to_user(reference_token_name)
  let user_token_at_input =
    quantity_of(user_input.output.value, own_policy, user_token_name) == 1

  expect Some(Output {
    address: output_address,
    value: output_value,
    datum: InlineDatum(output_datum),
    ..
  }) = list.at(outputs, reference_output_index)
  let output_at_account_address =
    output_address.payment_credential == account_payment_credential
  expect out_datum: AccountDatum = output_datum

  let output_policies_correct =
    policies(output_value) == [ada_policy_id, own_policy]
  let output_has_token =
    dict.to_pairs(tokens(output_value, own_policy)) == [
      Pair(reference_token_name, 1),
    ]

  and {
    reference_correct?,
    reference_token_correct?,
    user_token_at_input?,
    output_at_account_address?,
    is_account_metadata_valid(out_datum)?,
    output_policies_correct?,
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
  expect Script(own_policy) = account_addr.payment_credential

  let reference_input_correct =
    quantity_of(account_input_utxo.value, own_policy, reference_token_name) == 1

  let user_token_name =
    common_utils.convert_ref_tn_to_user(reference_token_name)
  let user_token_at_input =
    quantity_of(user_input.output.value, own_policy, user_token_name) == 1

  let mint_correct =
    quantity_of(minted_value, own_policy, reference_token_name) == -1

  and {
    reference_correct?,
    reference_input_correct?,
    user_token_at_input?,
    mint_correct?,
  }
}
