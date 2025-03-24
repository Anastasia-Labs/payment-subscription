use cardano/assets.{PolicyId}
use cardano/transaction.{OutputReference, Transaction}
use payment_subscription/account_multi_validator/validation.{
  validate_create_account, validate_delete_account, validate_remove_account,
  validate_update_account,
}
use payment_subscription/common/types.{
  AccountDatum, CreateAccount, DeleteAccount, MintAccount, RemoveAccount,
  SpendAccount, UpdateAccount,
}

// This validator script handles minting and spending of the account NFTs
validator account {
  mint(r: MintAccount, own_policy: PolicyId, tx: Transaction) {
    let Transaction { inputs, outputs, mint, .. } = tx

    when r is {
      CreateAccount { input_index, output_index } ->
        validate_create_account(
          own_policy,
          input_index,
          output_index,
          mint,
          inputs,
          outputs,
        )

      DeleteAccount { reference_token_name } ->
        validate_delete_account(own_policy, mint, reference_token_name)
    }
  }

  spend(
    _datum: Option<AccountDatum>,
    rdmr: SpendAccount,
    own_reference: OutputReference,
    tx: Transaction,
  ) {
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
          mint,
        )
    }
  }

  else(_) {
    fail
  }
}
