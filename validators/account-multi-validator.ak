use aiken/transaction.{Mint, ScriptContext, Spend, Transaction}
use aiken/transaction/value
use payment_subscription/account_multi_validator/validation.{
  validate_create_account, validate_delete_account, validate_remove_account,
  validate_update_account,
}
use payment_subscription/common/types.{
  AccountDatum, CreateAccount, DeleteAccount, MintAccount, RemoveAccount,
  SpendAccount, UpdateAccount,
}

// This validator script handles minting and spending of the account NFTs
validator {
  // Minting function: handles creation and deletion of account NFTs
  fn mint_account(r: MintAccount, ctx: ScriptContext) -> Bool {
    let ScriptContext { transaction: tx, purpose } = ctx
    expect Mint(own_policy) = purpose

    let Transaction { inputs, outputs, mint, .. } = tx
    let minted_value = mint |> value.from_minted_value()

    when r is {
      CreateAccount { output_reference, input_index, output_index } ->
        validate_create_account(
          own_policy,
          output_reference,
          input_index,
          output_index,
          minted_value,
          inputs,
          outputs,
        )

      DeleteAccount { reference_token_name } ->
        validate_delete_account(own_policy, minted_value, reference_token_name)
    }
  }

  fn spend_account(
    _datum: AccountDatum,
    rdmr: SpendAccount,
    ctx: ScriptContext,
  ) -> Bool {
    let ScriptContext { transaction: tx, purpose } = ctx
    expect Spend(own_reference) = purpose
    let Transaction { inputs, outputs, mint, .. } = tx

    when rdmr is {
      UpdateAccount {
        reference_token_name,
        user_input_index,
        account_input_index,
        account_output_index,
      } ->
        validate_update_account(
          own_reference,
          reference_token_name,
          user_input_index,
          account_input_index,
          account_output_index,
          inputs,
          outputs,
        )

      // Removes the utxo entirely from the script address.
      RemoveAccount {
        reference_token_name,
        user_input_index,
        account_input_index,
      } ->
        validate_remove_account(
          own_reference,
          reference_token_name,
          user_input_index,
          account_input_index,
          inputs,
          mint |> value.from_minted_value(),
        )
    }
  }
}
