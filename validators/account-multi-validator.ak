use aiken/bytearray
// use aiken/bytearray
use aiken/cbor
use aiken/dict
// use aiken/hash.{blake2b_256}
use aiken/interval
use aiken/list
use aiken/math.{abs}
// use aiken/string
use aiken/transaction.{
  Input, Mint, NoDatum, Output, OutputReference, ScriptContext, Spend,
  Transaction, TransactionId,
}
use aiken/transaction/credential
use aiken/transaction/value.{from_minted_value}
use assist/count
use assist/data
use assist/find
use assist/minting
use assist/payout
use assist/types/cip68
use assist/values
use payment_subscription/tests
use payment_subscription/types.{
  AccountDatum, CreateAccount, DeleteAccount, MintAccount, RemoveAccount,
  SpendAccount, UpdateAccount,
}
use payment_subscription/utils

// This validator script handles minting and spending of service NFTs
validator {
  // Minting function: handles creation and deletion of service NFTs
  fn mint_account(r: MintAccount, ctx: ScriptContext) -> Bool {
    let ScriptContext { transaction: tx, purpose } = ctx
    expect Mint(own_policy) = purpose

    let Transaction { inputs, mint, outputs, .. } = tx

    // Generate unique token names for reference and user tokens
    // let first_txid = find.first_input_txid(inputs)
    // let first_idx = find.first_input_index(inputs)
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

        trace @"merged_mint"
        trace cbor.diagnostic(merged_mint)
        // let account_address = credential.from_script(own_policy)
        let account_payment_credential = credential.ScriptCredential(own_policy)

        // Find the output UTxO containing the reference token
        expect [user_output, ref_output, ..] = outputs

        // Validate user token
        let user_token_quantity =
          value.quantity_of(user_output.value, own_policy, user_tkn)
        let user_payment_credential = user_output.address.payment_credential

        let user_token_not_to_script =
          user_token_quantity == 1 && user_payment_credential != account_payment_credential

        // Validate reference token
        let ref_token_quantity =
          value.quantity_of(ref_output.value, own_policy, ref_tkn)
        let ref_payment_credential = ref_output.address.payment_credential

        let ref_token_to_script =
          ref_token_quantity == 1 && ref_payment_credential == account_payment_credential

        // Validate the Datum meets Service Provider requirements.
        // Extract and validate the AccountDatum
        expect datum: AccountDatum = data.output_datum(ref_output)
        let metadata_valid = is_account_metadata_valid(datum)

        and {
          is_outref_spent?,
          // Validate the Datum meets Service Provider requirements.
          metadata_valid?,
          //  Validate that the redeemer only mints a single CIP68 compliant
          (merged_mint == minted_tokens)?,
          // TODO: Ensure that the User NFT doesn't go to the Script 
          user_token_not_to_script?,
          // (Filter through index 0 & 1. Expect at index 0.) 
          // Check index 1/user NFT and credential is not of the service address
          // TODO: Ensure ref_nft goes back to the script.
          ref_token_to_script?,
        }
      }

      DeleteAccount -> {
        let mint_flat =
          minted_tokens
            |> value.flatten()

        // TODO: Grab the two tokens from inputs and then check if the token names are the same
        // expect Some(own_input) =
        //   transaction.find_input(tx.inputs, output_reference)
        // let merged_burn = value.merge(ref_value_burn, user_value_burn)
        // let ref_nft =
        //   own_input.output.value
        //     |> value.without_lovelace()
        // trace @"merged_burn"
        // trace cbor.diagnostic(merged_burn)
        // trace @"minted_tokens"
        // trace cbor.diagnostic(minted_tokens)
        // trace @"merged_burn"
        // trace cbor.diagnostic(merged_burn)
        // trace @"mint_flat"
        // trace cbor.diagnostic(mint_flat)
        and {
          // TODO: Grab the two tokens from inputs and then check if the token names are the same
          // Check nfts with ref and user token prefixes are burnt
          minting.by_prefix(mint_flat, own_policy, cip68.prefix_100, -1)?,
          minting.by_prefix(mint_flat, own_policy, cip68.prefix_222, -1)?,
          when mint_flat is {
            [(_pid1, tkn1, _amt1), (_pid2, tkn2, _amt2)] ->
              bytearray.compare(
                bytearray.drop(tkn1, 4),
                bytearray.drop(tkn2, 4),
              ) == Equal
            _ -> False
          },
          // (merged_burn == minted_tokens)?,
          True,
        }
      }
    }
    // Check nfts with ref and user token prefixes are burnt
    // minting.by_prefix(mint_flat, own_policy, cip68.prefix_100, -1)?,
    // minting.by_prefix(mint_flat, own_policy, cip68.prefix_222, -1)?,
  }

  fn spend_account(
    datum: AccountDatum,
    rdmr: SpendAccount,
    ctx: ScriptContext,
  ) -> Bool {
    let ScriptContext { transaction: tx, purpose } = ctx

    expect Spend(output_reference) = purpose
    // Validate that Service UTxO with a Service NFT is being spent.
    expect Some(own_input) = transaction.find_input(tx.inputs, output_reference)
    trace @"own_input"
    trace cbor.diagnostic(own_input)

    // let minted_tokens = mint |> from_minted_value()
    let service_addr = own_input.output.address
    let ref_nft =
      own_input.output.value
        |> value.without_lovelace()
    trace @"ref_value"
    trace cbor.diagnostic(ref_nft)

    // Find and trace the User NFT
    let user_input =
      list.find(
        tx.inputs,
        fn(input) { input.output_reference != output_reference },
      )

    trace @"user_input"
    trace cbor.diagnostic(user_input)
    trace @"output_reference"
    trace cbor.diagnostic(output_reference)
    when rdmr is {
      UpdateAccount -> {
        // trace @"output_address"
        // trace cbor.diagnostic(output.address)
        trace @"account_address"
        trace cbor.diagnostic(service_addr)

        // trace @"Output"
        // trace cbor.diagnostic(output)
        // Find the output containing the reference NFT being sent back to this script itself
        let validating_output =
          utils.output_by_addr_value(tx.outputs, service_addr, ref_nft)

        // Extract the new datum from the validating output
        expect new_datum: AccountDatum = data.output_datum(validating_output)

        trace @"new_datum"
        trace cbor.diagnostic(new_datum)
        // Validate that the metadata of the Reference NFT is updated within acceptable bounds
        let metadata_valid = is_account_metadata_valid(new_datum)

        and {
          // Validate that the metadata of the Reference NFT is updated within acceptable bounds .
          metadata_valid?,
          payout.at_least(service_addr, ref_nft, tx.outputs)?,
          utils.check_output_utxo(validating_output)?,
          True,
        }
      }
      // Removes the utxo entirely from the script address.
      RemoveAccount -> {
        // this doesn't check for burn or destination for more of an open ended approach
        let validating_output =
          utils.output_by_addr_value(tx.outputs, service_addr, ref_nft)

        and {
          // Validate that there's a single script input and No Script output back to the script address.
          // single script input
          count.inputs_by_addr(tx.inputs, service_addr, 2)?,
          // no script output
          count.outputs_by_addr(tx.outputs, service_addr, 1)?,
          // Validate UTxO with Reference NFT is being spent.
          utils.check_output_utxo(validating_output)?,
          True,
        }
      }
    }
  }
}

// Helper function to validate service fee changes
pub fn is_account_metadata_valid(datum: AccountDatum) -> Bool {
  let email_valid = bytearray.length(datum.email) > 0
  let phone_valid = bytearray.length(datum.phone) > 0
  let account_duration_valid = datum.account_start < datum.account_end

  email_valid && phone_valid && account_duration_valid
}

test can_create_service() {
  let own_cs = tests.test_224_01()
  let tx_hash = tests.test_224_02()
  let init_output_ref = tests.test_input_utxo_02(tx_hash)
  let input_index = 0
  // trace @"tx_hash"
  // trace cbor.diagnostic(tx_hash)
  // trace @"init_output_ref"
  // trace cbor.diagnostic(init_output_ref)
  let datum = tests.test_datum_02("you@mail.com", "(717) 550-1675", 1, 2)
  let redeemer =
    CreateAccount { output_reference: init_output_ref, input_index }

  let ref_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_100)
  let user_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_222)

  let ref_value = value.add(value.zero(), own_cs, ref_tkn, 1)
  let user_value = value.add(value.zero(), own_cs, user_tkn, 1)
  let minted_value = value.merge(ref_value, user_value)

  let user_pubkey_hash = tests.test_224_03()
  let user_output = tests.test_utxo_02(user_pubkey_hash, user_value, NoDatum)
  let service_output = tests.test_utxo_02(own_cs, ref_value, datum)

  // trace @"user_output"
  // trace cbor.diagnostic(user_output)
  // trace @"service_output"
  // trace cbor.diagnostic(service_output)
  let user_input = tests.test_context_input_01(init_output_ref, own_cs, NoDatum)

  let context =
    ScriptContext {
      purpose: Mint(own_cs),
      transaction: Transaction {
        inputs: [user_input],
        reference_inputs: [],
        // There should be two outputs.
        outputs: [user_output, service_output],
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

  // trace @"context"
  // trace cbor.diagnostic(context)
  mint_account(redeemer, context)
}

test can_delete_service() {
  let own_cs = tests.test_224_01()
  let tx_hash = tests.test_224_02()
  let init_output_ref = tests.test_input_utxo_02(tx_hash)
  let account_output_ref = tests.test_input_utxo_02(tests.test_224_01())

  let datum = tests.test_datum_02("you@mail.com", "(717) 550-1675", 1, 1)
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

  // trace @"user_input"
  // trace cbor.diagnostic(user_input)
  // trace @"account_input"
  // trace cbor.diagnostic(account_input)
  // trace @"user_output"
  // trace cbor.diagnostic(user_output)
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
  mint_account(redeemer, context)
}

test can_update_service() {
  let own_cs = tests.test_224_01()
  let tx_hash = tests.test_224_02()
  let init_output_ref = tests.test_input_utxo_02(tx_hash)
  let account_output_ref = tests.test_input_utxo_02(tests.test_224_01())

  let datum = tests.test_datum_02("you@mail.com", "(717) 550-1675", 1, 2)
  let new_datum = tests.test_datum_02("you@mail.com", "(717) 550-1675", 1, 2)

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
  let service_output = tests.test_utxo_02(own_cs, ref_value, new_datum)

  trace @"user_input"
  trace cbor.diagnostic(user_input)
  trace @"account_input"
  trace cbor.diagnostic(account_input)
  trace @"user_output"
  trace cbor.diagnostic(user_output)
  trace @"service_output"
  trace cbor.diagnostic(service_output)

  let context =
    ScriptContext {
      purpose: Spend(account_output_ref),
      transaction: Transaction {
        inputs: [user_input, account_input],
        // Should have two inputs.
        reference_inputs: [],
        outputs: [user_output, service_output],
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
  spend_account(datum, redeemer, context)
}

test can_remove_service() {
  let own_cs = tests.test_224_01()
  let tx_hash = tests.test_224_02()
  let init_output_ref = tests.test_input_utxo_02(tx_hash)
  let account_output_ref = tests.test_input_utxo_02(tests.test_224_01())

  let datum = tests.test_datum_02("you@mail.com", "(717) 550-1675", 1, 1)

  // let new_datum = tests.test_datum_02("you@mail.com", "(717) 550-1675", 1, 1)
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

  // let service_output = tests.test_utxo_02(own_cs, ref_value, new_datum)
  trace @"user_input"
  trace cbor.diagnostic(user_input)
  trace @"account_input"
  trace cbor.diagnostic(account_input)
  trace @"user_output"
  trace cbor.diagnostic(user_output)

  // trace @"service_output"
  // trace cbor.diagnostic(service_output)
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
  spend_account(datum, redeemer, context)
}
