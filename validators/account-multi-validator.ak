use aiken/cbor
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
  // Minting function: handles creation and deletion of account NFTs
  mint(r: MintAccount, policy_id: PolicyId, self: Transaction) {
    when r is {
      CreateAccount { output_reference, input_index } -> {
        // Ensure this outref is spent in this transaction 
        trace @" CreateAccount output_reference:"
        trace cbor.diagnostic(output_reference)

        validate_create_account(policy_id, output_reference, input_index, self)
      }

      DeleteAccount -> validate_delete_account(self)
    }
  }

  spend(
    _datum: Option<AccountDatum>,
    rdmr: SpendAccount,
    _own_ref: OutputReference,
    self: Transaction,
  ) {
    when rdmr is {
      UpdateAccount { subscriber_input_index, account_input_index } ->
        validate_update_account(
          subscriber_input_index,
          account_input_index,
          self,
        )

      // Removes the utxo entirely from the script address.
      RemoveAccount { subscriber_input_index, account_input_index } ->
        validate_remove_account(
          subscriber_input_index,
          account_input_index,
          self,
        )
    }
  }

  else(_) {
    fail
  }
}
