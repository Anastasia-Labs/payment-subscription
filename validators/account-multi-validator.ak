use aiken/bytearray
use aiken/cbor
use aiken/dict
use aiken/interval
use aiken/list
use aiken/transaction.{
  Input, Mint, NoDatum, Output, OutputReference, ScriptContext, Spend,
  Transaction, TransactionId,
}
use aiken/transaction/credential
use aiken/transaction/value.{from_minted_value}
use assist/count
use assist/data
use assist/payout
use assist/types/cip68
use assist/values
use payment_subscription/tests/tests
use payment_subscription/types.{
  AccountDatum, CreateAccount, DeleteAccount, MintAccount, RemoveAccount,
  SpendAccount, UpdateAccount,
}
use payment_subscription/utils.{validate_token_output}

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

        let account_payment_credential = credential.ScriptCredential(own_policy)

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
        // Validate the Datum has valid account inputs.
        let metadata_valid = is_account_metadata_valid(datum)

        and {
          is_outref_spent?,
          // Validate the Datum has valid account inputs.
          metadata_valid?,
          // Validate that the redeemer only mints a single CIP68 compliant
          (merged_mint == minted_tokens)?,
          // Ensure that the User NFT doesn't go to the Script 
          user_token_not_to_script?,
          // Ensure ref_nft goes back to the script.
          ref_token_to_script?,
        }
      }

      DeleteAccount -> {
        let mint_flat =
          minted_tokens
            |> value.flatten()

        when mint_flat is {
          [(_pid1, tkn1, amt1), (_pid2, tkn2, amt2)] -> and {
              amt1 == -1,
              amt2 == -1,
              bytearray.compare(
                bytearray.drop(tkn1, 4),
                bytearray.drop(tkn2, 4),
              ) == Equal,
            }
          _ -> False
        }
      }
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
      UpdateAccount -> {
        // Find the output containing the reference NFT being sent back to this script itself
        let validating_output =
          utils.output_by_addr_value(tx.outputs, account_addr, ref_nft)

        // Extract the new datum from the validating output
        expect new_datum: AccountDatum = data.output_datum(validating_output)

        let metadata_valid = is_account_metadata_valid(new_datum)

        and {
          // Validate that the metadata of the Reference NFT is updated within acceptable bounds .
          metadata_valid?,
          payout.at_least(account_addr, ref_nft, tx.outputs)?,
          utils.check_nft_output_utxo(validating_output)?,
        }
      }
      // Removes the utxo entirely from the script address.
      RemoveAccount -> {
        expect [(policy_id, asset_name, _)] = value.flatten(ref_nft)

        // Check that the reference NFT is burned
        let minted_value = value.from_minted_value(tx.mint)
        let burn_quantity =
          value.quantity_of(minted_value, policy_id, asset_name)
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
            fn(output) {
              value.quantity_of(output.value, policy_id, asset_name) == 0
            },
          )?,
        }
      }
    }
  }
}

// Helper function to validate tha account metadata
pub fn is_account_metadata_valid(datum: AccountDatum) -> Bool {
  let email_valid = bytearray.length(datum.email) > 0
  let phone_valid = bytearray.length(datum.phone) > 0

  email_valid || phone_valid
}

test succeed_create_account() {
  let own_cs = tests.test_224_01()
  let tx_hash = tests.test_224_02()
  let init_output_ref = tests.test_input_utxo_02(tx_hash)
  let input_index = 0
  let datum = tests.test_datum_02("you@mail.com", "(717) 550-1675", 1)
  let redeemer =
    CreateAccount { output_reference: init_output_ref, input_index }

  let ref_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_100)
  let user_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_222)

  let ref_value = value.add(value.zero(), own_cs, ref_tkn, 1)
  let user_value = value.add(value.zero(), own_cs, user_tkn, 1)
  let minted_value = value.merge(ref_value, user_value)

  let user_pubkey_hash = tests.test_224_03()
  let user_output = tests.test_utxo_02(user_pubkey_hash, user_value, NoDatum)
  let script_output = tests.test_utxo_02(own_cs, ref_value, datum)

  let user_input = tests.test_context_input_01(init_output_ref, own_cs, NoDatum)

  let context =
    ScriptContext {
      purpose: Mint(own_cs),
      transaction: Transaction {
        inputs: [user_input],
        reference_inputs: [],
        // There should be two outputs.
        outputs: [user_output, script_output],
        fee: value.zero(),
        mint: value.to_minted_value(minted_value),
        certificates: [],
        withdrawals: [],
        validity_range: interval.everything(),
        extra_signatories: [],
        redeemers: [],
        datums: dict.new(),
        id: TransactionId { hash: tx_hash },
      },
    }

  trace @"Test: Creating a New Account"
  trace @"-------------------------------------"

  trace @"Step 1: Account Details"
  trace @"-------------------------------------"
  trace @"Email:"
  trace cbor.diagnostic(datum.email)
  trace @"Phone:"
  trace cbor.diagnostic(datum.phone)

  trace @"Step 2: Minting Account Tokens"
  trace @"-------------------------------------"
  trace @"Reference Token:"
  trace cbor.diagnostic(ref_tkn)
  trace @"User Token:"
  trace cbor.diagnostic(user_tkn)

  trace @"Step 3: Preparing Outputs"
  trace @"-------------------------------------"
  trace @"User Output:"
  trace cbor.diagnostic(user_output)
  trace @"Script Output:"
  trace cbor.diagnostic(script_output)

  trace @"Step 4: Validating Transaction"
  trace @"-------------------------------------"
  trace @"Transaction Inputs:"
  trace cbor.diagnostic(context.transaction.inputs)
  trace @"Transaction Outputs:"
  trace cbor.diagnostic(context.transaction.outputs)
  trace @"Minted Tokens:"
  trace cbor.diagnostic(context.transaction.mint)

  trace @"Step 5: Execution Result"
  trace @"-------------------------------------"
  trace @"Account Successfully Created!"
  trace @"-------------------------------------"
  trace @"Test Completed!"
  mint_account(redeemer, context)
}

test succeed_delete_account() {
  let own_cs = tests.test_224_01()
  let tx_hash = tests.test_224_02()
  let init_output_ref = tests.test_input_utxo_02(tx_hash)
  let account_output_ref = tests.test_input_utxo_02(tests.test_224_01())

  let datum = tests.test_datum_02("you@mail.com", "(717) 550-1675", 1)
  let redeemer = DeleteAccount

  let ref_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_100)
  let user_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_222)

  //   let ref_value = value.from_asset(own_cs, ref_tkn, 1)
  let ref_value = value.add(value.zero(), own_cs, ref_tkn, -1)
  let user_value = value.add(value.zero(), own_cs, user_tkn, -1)
  let minted_value = value.merge(ref_value, user_value)

  let user_input =
    tests.test_context_input_02(init_output_ref, own_cs, user_value, NoDatum)
  let account_input =
    tests.test_context_input_02(account_output_ref, own_cs, ref_value, datum)

  let user_output = tests.test_utxo_02(own_cs, user_value, datum)

  let context =
    ScriptContext {
      purpose: Mint(own_cs),
      transaction: Transaction {
        // Should have two inputs
        inputs: [user_input, account_input],
        reference_inputs: [],
        // Should have one output
        outputs: [user_output],
        fee: value.zero(),
        mint: value.to_minted_value(minted_value),
        certificates: [],
        withdrawals: [],
        validity_range: interval.everything(),
        extra_signatories: [],
        redeemers: [],
        datums: dict.new(),
        id: TransactionId { hash: tx_hash },
      },
    }

  trace @"Test: Deleting an Existing Account"
  trace @"-------------------------------------"

  trace @"Step 1: Account Details"
  trace @"-------------------------------------"
  trace @"Email:"
  trace cbor.diagnostic(datum.email)
  trace @"Phone:"
  trace cbor.diagnostic(datum.phone)

  trace @"Step 2: Burning Account Tokens"
  trace @"-------------------------------------"
  trace @"Reference Token to Burn:"
  trace cbor.diagnostic(ref_tkn)
  trace @"User Token to Burn:"
  trace cbor.diagnostic(user_tkn)

  trace @"Step 3: Preparing Inputs"
  trace @"-------------------------------------"
  trace @"User Input:"
  trace cbor.diagnostic(user_input)
  trace @"Account Input:"
  trace cbor.diagnostic(account_input)

  trace @"Step 4: Validating Transaction"
  trace @"-------------------------------------"
  trace @"Transaction Inputs:"
  trace cbor.diagnostic(context.transaction.inputs)
  trace @"Transaction Outputs:"
  trace cbor.diagnostic(context.transaction.outputs)
  trace @"Burned Tokens:"
  trace cbor.diagnostic(context.transaction.mint)

  trace @"Step 5: Execution Result"
  trace @"-------------------------------------"
  trace @"Account Successfully Deleted!"
  trace @"-------------------------------------"
  trace @"Test Completed!"
  mint_account(redeemer, context)
}

test succeed_update_account() {
  let own_cs = tests.test_224_01()
  let tx_hash = tests.test_224_02()
  let init_output_ref = tests.test_input_utxo_02(tx_hash)
  let account_output_ref = tests.test_input_utxo_02(tests.test_224_01())

  let datum = tests.test_datum_02("you@mail.com", "(717) 550-1675", 1)
  let new_datum = tests.test_datum_02("you@mail.com", "(717) 550-1675", 1)

  let redeemer = UpdateAccount

  let ref_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_100)
  let user_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_222)

  let ref_value = value.add(value.zero(), own_cs, ref_tkn, 1)
  let user_value = value.add(value.zero(), own_cs, user_tkn, 1)
  let minted_value = value.merge(ref_value, user_value)

  let user_input =
    tests.test_context_input_02(init_output_ref, own_cs, user_value, NoDatum)
  let account_input =
    tests.test_context_input_02(account_output_ref, own_cs, ref_value, datum)

  let user_output = tests.test_utxo_02(own_cs, user_value, NoDatum)
  let script_output = tests.test_utxo_02(own_cs, ref_value, new_datum)

  let context =
    ScriptContext {
      purpose: Spend(account_output_ref),
      transaction: Transaction {
        inputs: [user_input, account_input],
        // Should have two inputs.
        reference_inputs: [],
        outputs: [user_output, script_output],
        fee: value.zero(),
        mint: value.to_minted_value(minted_value),
        certificates: [],
        withdrawals: [],
        validity_range: interval.everything(),
        extra_signatories: [],
        redeemers: [],
        datums: dict.new(),
        id: TransactionId { hash: tx_hash },
      },
    }

  trace @"Test: Updating an Existing Account"
  trace @"-------------------------------------"

  trace @"Step 1: Current Account Details"
  trace @"-------------------------------------"
  trace @"Current Email:"
  trace cbor.diagnostic(datum.email)
  trace @"Current Phone:"
  trace cbor.diagnostic(datum.phone)

  trace @"Step 2: Updated Account Details"
  trace @"-------------------------------------"
  trace @"New Email:"
  trace cbor.diagnostic(new_datum.email)
  trace @"New Phone:"
  trace cbor.diagnostic(new_datum.phone)

  trace @"Step 3: Preparing Inputs and Outputs"
  trace @"-------------------------------------"
  trace @"User Input:"
  trace cbor.diagnostic(user_input)
  trace @"Account Input:"
  trace cbor.diagnostic(account_input)
  trace @"User Output:"
  trace cbor.diagnostic(user_output)
  trace @"Script Output:"
  trace cbor.diagnostic(script_output)

  trace @"Step 4: Validating Transaction"
  trace @"-------------------------------------"
  trace @"Transaction Inputs:"
  trace cbor.diagnostic(context.transaction.inputs)
  trace @"Transaction Outputs:"
  trace cbor.diagnostic(context.transaction.outputs)

  trace @"Step 5: Execution Result"
  trace @"-------------------------------------"
  trace @"Account Successfully Updated!"
  trace @"-------------------------------------"
  trace @"Test Completed!"

  spend_account(datum, redeemer, context)
}

test succeed_remove_account() {
  let own_cs = tests.test_224_01()
  let tx_hash = tests.test_224_02()
  let init_output_ref = tests.test_input_utxo_02(tx_hash)
  let account_output_ref = tests.test_input_utxo_02(tests.test_224_01())

  let datum = tests.test_datum_02("you@mail.com", "(717) 550-1675", 1)
  let redeemer = RemoveAccount

  let ref_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_100)
  let user_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_222)

  let ref_value = value.add(value.zero(), own_cs, ref_tkn, -1)
  let user_value = value.add(value.zero(), own_cs, user_tkn, -1)
  let minted_value = value.merge(ref_value, user_value)

  let user_input =
    tests.test_context_input_02(init_output_ref, own_cs, user_value, NoDatum)
  let account_input =
    tests.test_context_input_02(account_output_ref, own_cs, ref_value, datum)

  let user_output = tests.test_utxo_02(own_cs, user_value, NoDatum)

  trace @"user_input"
  trace cbor.diagnostic(user_input)
  trace @"account_input"
  trace cbor.diagnostic(account_input)
  trace @"user_output"
  trace cbor.diagnostic(user_output)

  let context =
    ScriptContext {
      purpose: Spend(account_output_ref),
      transaction: Transaction {
        inputs: [user_input, account_input],
        // Should have two inputs.
        reference_inputs: [],
        outputs: [user_output],
        fee: value.zero(),
        mint: value.to_minted_value(minted_value),
        certificates: [],
        withdrawals: [],
        validity_range: interval.everything(),
        extra_signatories: [],
        redeemers: [],
        datums: dict.new(),
        id: TransactionId { hash: tx_hash },
      },
    }

  trace @"Test: Removing an Existing Account"
  trace @"-------------------------------------"

  trace @"Step 1: Account Details"
  trace @"-------------------------------------"
  trace @"Email:"
  trace cbor.diagnostic(datum.email)
  trace @"Phone:"
  trace cbor.diagnostic(datum.phone)

  trace @"Step 2: Tokens to Remove"
  trace @"-------------------------------------"
  trace @"Reference Token:"
  trace cbor.diagnostic(ref_tkn)
  trace @"User Token:"
  trace cbor.diagnostic(user_tkn)

  trace @"Step 3: Preparing Inputs and Outputs"
  trace @"-------------------------------------"
  trace @"User Input:"
  trace cbor.diagnostic(user_input)
  trace @"Account Input:"
  trace cbor.diagnostic(account_input)
  trace @"User Output:"
  trace cbor.diagnostic(user_output)

  trace @"Step 4: Validating Transaction"
  trace @"-------------------------------------"
  trace @"Transaction Inputs:"
  trace cbor.diagnostic(context.transaction.inputs)
  trace @"Transaction Outputs:"
  trace cbor.diagnostic(context.transaction.outputs)
  trace @"Burned Tokens:"
  trace cbor.diagnostic(context.transaction.mint)

  trace @"Step 5: Execution Result"
  trace @"-------------------------------------"
  trace @"Account Successfully Removed!"
  trace @"-------------------------------------"
  trace @"Test Completed!"

  spend_account(datum, redeemer, context)
}
