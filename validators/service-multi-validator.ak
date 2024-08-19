use aiken/bytearray
use aiken/cbor
use aiken/dict
use aiken/interval
use aiken/list
use aiken/math.{abs}
use aiken/transaction.{
  Input, Mint, NoDatum, Output, OutputReference, ScriptContext, Spend,
  Transaction, TransactionId,
}
use aiken/transaction/credential
use aiken/transaction/value.{from_minted_value}
use assist/count
use assist/data
use assist/minting
use assist/payout
use assist/types/cip68
use assist/values
use payment_subscription/tests
use payment_subscription/types.{
  CreateService, DeleteService, MintService, RemoveService, ServiceDatum,
  SpendService, UpdateService,
}
use payment_subscription/utils.{validate_token_output}

// This validator script handles minting and spending of service NFTs
validator {
  // Minting function: handles creation and deletion of service NFTs
  fn mint_service(r: MintService, ctx: ScriptContext) -> Bool {
    let ScriptContext { transaction: tx, purpose } = ctx
    expect Mint(own_policy) = purpose
    let Transaction { inputs, mint, outputs, .. } = tx

    let minted_tokens = mint |> from_minted_value()
    let service_payment_credential = credential.ScriptCredential(own_policy)
    // Provide the OutRef as the Redeemer
    when r is {
      CreateService { output_reference, input_index } -> {
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

        trace @"user_tkn"
        trace cbor.diagnostic(user_tkn)
        trace @"service_payment_credential"
        trace cbor.diagnostic(service_payment_credential)

        // Expect two ouptuts user_output @ index 0 && ref_output @ index 1
        expect [user_output, ref_output, ..] = outputs

        // Validate user token
        let user_token_not_to_script =
          validate_token_output(
            user_output,
            own_policy,
            user_tkn,
            service_payment_credential,
            False,
          )

        // Validate reference token
        let ref_token_to_script =
          validate_token_output(
            ref_output,
            own_policy,
            ref_tkn,
            service_payment_credential,
            True,
          )

        // Extract and validate the ServiceDatum
        expect datum: ServiceDatum = data.output_datum(ref_output)
        let metadata_valid = is_metadata_valid(datum)

        trace @"user_output"
        trace cbor.diagnostic(user_output)
        and {
          is_outref_spent?,
          // Validate the Datum meets Service Provider requirements.
          metadata_valid?,
          // Validate that the redeemer only mints a single CIP68 compliant
          (merged_mint == minted_tokens)?,
          // Ensure that the User NFT doesn't go to the Script 
          user_token_not_to_script?,
          // Ensure ref_nft goes back to the script.
          ref_token_to_script?,
        }
      }
      DeleteService -> {
        let mint_flat =
          minted_tokens
            |> value.flatten()

        and {
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
        }
      }
    }
  }

  fn spend_service(
    datum: ServiceDatum,
    rdmr: SpendService,
    ctx: ScriptContext,
  ) -> Bool {
    let ScriptContext { transaction: tx, purpose } = ctx

    expect Spend(output_reference) = purpose
    // Validate that Service UTxO with a Service NFT is being spent.
    expect Some(own_input) = transaction.find_input(tx.inputs, output_reference)

    let service_addr = own_input.output.address
    let ref_nft =
      own_input.output.value
        |> value.without_lovelace()

    trace @"own_input"
    trace cbor.diagnostic(own_input)
    trace @"ref_value"
    trace cbor.diagnostic(ref_nft)
    trace @"output_reference"
    trace cbor.diagnostic(output_reference)
    when rdmr is {
      UpdateService -> {
        // Find the output containing the reference NFT being sent back to this script itself
        let validating_output =
          utils.output_by_addr_value(tx.outputs, service_addr, ref_nft)

        // Extract the new datum from the validating output
        expect new_datum: ServiceDatum = data.output_datum(validating_output)

        // Validate that the metadata of the Reference NFT is updated within acceptable bounds
        let metadata_valid = is_metadata_valid(new_datum)

        // Validate service fee changes are within acceptable range
        let service_fee_change_valid =
          is_fee_change_valid(datum.service_fee_qty, new_datum.service_fee_qty)

        trace @"service_address"
        trace cbor.diagnostic(service_addr)
        trace @"new_datum"
        trace cbor.diagnostic(new_datum)
        and {
          // Validate that the metadata of the Reference NFT is updated within acceptable bounds .
          metadata_valid?,
          //  Validate that the service fee should be limited to a range to prevent extreme flucutation in service
          // fee by the service provider e.g +/-10%
          service_fee_change_valid?,
          payout.at_least(service_addr, ref_nft, tx.outputs)?,
          utils.check_output_utxo(validating_output)?,
        }
      }

      // Removes the utxo entirely from the script address.
      RemoveService -> {
        // Extract policy_id and asset_name from ref_nft
        expect [(policy_id, asset_name, _)] = value.flatten(ref_nft)
        expect [output, ..] = tx.outputs

        // Check that the reference NFT is burned
        let minted_value = value.from_minted_value(tx.mint)
        let burn_quantity =
          value.quantity_of(minted_value, policy_id, asset_name)
        let is_ref_nft_burned = burn_quantity == -1

        let no_output_has_reference_nft =
          value.quantity_of(output.value, policy_id, asset_name) == 0
        trace @"is_ref_nft_burned"
        trace cbor.diagnostic(burn_quantity)

        and {
          // Validate that there are two script input and one Script output back to the script address.
          // two script input
          count.inputs_by_addr(tx.inputs, service_addr, 2)?,
          // one script output
          count.outputs_by_addr(tx.outputs, service_addr, 1)?,
          // Check that the reference NFT is burned
          is_ref_nft_burned?,
          // Ensure no output contains the reference NFT
          no_output_has_reference_nft?,
        }
      }
    }
  }
}

// Helper function to validate service fee changes
fn is_metadata_valid(datum: ServiceDatum) -> Bool {
  let service_fee_valid =
    datum.service_fee_qty >= 1 && datum.service_fee_qty < 1_000_000_000_000
  let penalty_fee_valid =
    datum.penalty_fee_qty >= 0 && datum.penalty_fee_qty < 1_000_000_000_000
  let subscription_period_valid =
    datum.subscription_period >= 1 && datum.subscription_period < 1_000_000_000_000
  service_fee_valid && penalty_fee_valid && subscription_period_valid
}

// Helper function to validate service fee changes
fn is_fee_change_valid(old_fee: Int, new_fee: Int) -> Bool {
  // Implement logic to ensure fee changes are within acceptable range
  // For example, limit changes to ±10%
  let max_change = old_fee / 10

  trace @"old_fee"
  trace cbor.diagnostic(old_fee)
  trace @"new_fee"
  trace cbor.diagnostic(new_fee)
  trace @"max_change"
  trace cbor.diagnostic(max_change)

  abs(new_fee - old_fee) <= max_change
}

test success_create_service() {
  let own_cs = tests.test_224_01()
  let tx_hash = tests.test_224_02()
  let init_output_ref = tests.test_input_utxo_02(tx_hash)

  let input_index = 0
  let datum = tests.test_service_datum()
  let redeemer =
    CreateService { output_reference: init_output_ref, input_index }

  let ref_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_100)
  let user_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_222)

  let ref_value = value.add(value.zero(), own_cs, ref_tkn, 1)
  let user_value = value.add(value.zero(), own_cs, user_tkn, 1)
  let minted_value = value.merge(ref_value, user_value)

  let user_pubkey_hash = tests.test_224_03()
  let user_output = tests.test_user_utxo(user_pubkey_hash, user_value, NoDatum)
  let service_output = tests.test_utxo_02(own_cs, ref_value, datum)

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

  mint_service(redeemer, context)
}

// TODO: Token Spam Attacks
// TODO: Unbounded datums
// TODO: Staking theft attack (Change Staking Credentials)
test success_delete_service() {
  let own_cs = tests.test_224_01()
  let tx_hash = tests.test_224_02()
  let init_output_ref = tests.test_input_utxo_02(tx_hash)
  let script_output_ref = tests.test_input_utxo_02(tests.test_224_01())

  let ref_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_100)
  let user_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_222)

  let datum = tests.test_service_datum()
  let redeemer = DeleteService

  let ref_value = value.add(value.zero(), own_cs, ref_tkn, -1)
  let user_value = value.add(value.zero(), own_cs, user_tkn, -1)
  let minted_value = value.merge(ref_value, user_value)

  let user_input =
    tests.test_context_input_02(init_output_ref, own_cs, user_value, NoDatum)
  let service_input =
    tests.test_context_input_02(script_output_ref, own_cs, ref_value, datum)

  let user_output = tests.test_utxo_02(own_cs, user_value, datum)

  let context =
    ScriptContext {
      purpose: Mint(own_cs),
      transaction: Transaction {
        // Should have two inputs
        inputs: [user_input, service_input],
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
  mint_service(redeemer, context)
}

test success_update_service() {
  let own_cs = tests.test_224_01()
  let tx_hash = tests.test_224_02()
  let init_output_ref = tests.test_input_utxo_02(tx_hash)
  let script_output_ref = tests.test_input_utxo_02(tests.test_224_01())

  let datum = tests.test_service_datum()
  let new_datum = tests.test_service_datum()

  let redeemer = UpdateService

  let ref_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_100)
  let user_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_222)

  let ref_value = value.add(value.zero(), own_cs, ref_tkn, 1)
  let user_value = value.add(value.zero(), own_cs, user_tkn, 1)
  let minted_value = value.merge(ref_value, user_value)

  let user_input =
    tests.test_context_input_02(init_output_ref, own_cs, user_value, NoDatum)
  let service_input =
    tests.test_context_input_02(script_output_ref, own_cs, ref_value, datum)

  let user_output = tests.test_utxo_02(own_cs, user_value, NoDatum)
  let service_output = tests.test_utxo_02(own_cs, ref_value, new_datum)

  trace @"user_input"
  trace cbor.diagnostic(user_input)
  trace @"service_input"
  trace cbor.diagnostic(service_input)
  trace @"user_output"
  trace cbor.diagnostic(user_output)
  trace @"service_output"
  trace cbor.diagnostic(service_output)

  let context =
    ScriptContext {
      purpose: Spend(script_output_ref),
      transaction: Transaction {
        inputs: [user_input, service_input],
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
  spend_service(datum, redeemer, context)
}

test success_remove_service() {
  let own_cs = tests.test_224_01()
  let tx_hash = tests.test_224_02()
  let init_output_ref = tests.test_input_utxo_02(tx_hash)
  let script_output_ref = tests.test_input_utxo_02(tests.test_224_01())

  let datum = tests.test_service_datum()

  // let new_datum = tests.test_service_datum(1, 1, 1, 1)
  let redeemer = RemoveService

  let ref_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_100)
  let user_tkn = values.unique_token_name(tx_hash, 1, cip68.prefix_222)

  let ref_value = value.add(value.zero(), own_cs, ref_tkn, -1)
  let user_value = value.add(value.zero(), own_cs, user_tkn, -1)
  let minted_value = value.merge(ref_value, user_value)

  let user_input =
    tests.test_context_input_02(init_output_ref, own_cs, user_value, NoDatum)
  let service_input =
    tests.test_context_input_02(script_output_ref, own_cs, ref_value, datum)

  let user_output = tests.test_utxo_02(own_cs, user_value, NoDatum)

  // let service_output = tests.test_utxo_02(own_cs, ref_value, new_datum)
  trace @"user_input"
  trace cbor.diagnostic(user_input)
  trace @"service_input"
  trace cbor.diagnostic(service_input)
  trace @"user_output"
  trace cbor.diagnostic(user_output)

  // trace @"service_output"
  // trace cbor.diagnostic(service_output)
  let context =
    ScriptContext {
      purpose: Spend(script_output_ref),
      transaction: Transaction {
        inputs: [user_input, service_input],
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
  spend_service(datum, redeemer, context)
}
