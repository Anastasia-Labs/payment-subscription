use aiken/cbor
use aiken/list
use aiken/transaction.{Mint, ScriptContext, Transaction}
use aiken/transaction/value.{from_minted_value}
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

    let Transaction { inputs, mint, outputs, .. } = tx

    let minted_tokens = mint |> from_minted_value()

    when r is {
      CreateAccount { output_reference, input_index } -> {
        // Ensure this outref is spent in this transaction 
        trace @" CreateAccount output_reference:"
        trace cbor.diagnostic(output_reference)

        expect Some(input) = list.at(inputs, input_index)
        validate_create_account(
          own_policy,
          input,
          minted_tokens,
          output_reference,
          outputs,
        )
      }

      DeleteAccount -> validate_delete_account(minted_tokens)
    }
  }

  fn spend_account(
    _datum: AccountDatum,
    rdmr: SpendAccount,
    ctx: ScriptContext,
  ) -> Bool {
    let ScriptContext { transaction: tx, .. } = ctx

    when rdmr is {
      UpdateAccount { subscriber_input_index, account_input_index } ->
        validate_update_account(subscriber_input_index, account_input_index, tx)

      // Removes the utxo entirely from the script address.
      RemoveAccount { subscriber_input_index, account_input_index } ->
        validate_remove_account(subscriber_input_index, account_input_index, tx)
    }
  }
}
