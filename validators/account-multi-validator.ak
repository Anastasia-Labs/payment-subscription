use aiken/list
use aiken/transaction.{Input, Mint, Output, ScriptContext, Spend, Transaction}
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
    let ScriptContext { transaction: tx, purpose } = ctx

    expect Spend(output_reference) = purpose
    // Validate that Account UTxO with a Account NFT is being spent.
    expect Some(own_input) = transaction.find_input(tx.inputs, output_reference)

    let account_addr = own_input.output.address
    let ref_nft =
      own_input.output.value
        |> value.without_lovelace()
    when rdmr is {
      UpdateAccount -> validate_update_account(account_addr, ref_nft, tx)

      // Removes the utxo entirely from the script address.
      RemoveAccount -> validate_remove_account(account_addr, ref_nft, tx)
    }
  }
}
