use aiken/bytearray
use aiken/cbor
use aiken/dict
use aiken/hash.{Blake2b_224, Hash}
use aiken/interval
// use aiken/dict.{to_pairs}
use aiken/list
use aiken/math.{abs}
use aiken/transaction.{
  Datum, InlineDatum, Input, Mint, NoDatum, Output, OutputReference,
  ScriptContext, Spend, Transaction, TransactionId,
}
use aiken/transaction/credential.{Address, ScriptCredential, VerificationKey}
use aiken/transaction/value.{
  AssetName, PolicyId, Value, flatten, from_minted_value,
}
use assist/count
use assist/data
use assist/find
use assist/minting
use assist/payout
use assist/signing
use assist/types/cip68
use assist/values
use payment_subscription/constants.{service_token_name}
use payment_subscription/types.{
  AssetClass, CreateService, DeleteService, MintService, PaymentDatum,
  RemoveService, ServiceDatum, SpendService, UpdateService,
}
use payment_subscription/utils.{output_by_value}

// This validator script handles minting and spending of service NFTs

validator {
  // Minting function: handles creation and deletion of service NFTs
  fn mint_service(r: MintService, ctx: ScriptContext) -> Bool {
    let ScriptContext { transaction: tx, purpose } = ctx
    expect Mint(own_policy) = purpose

    let Transaction { inputs, mint, outputs, .. } = tx

    // Generate unique token names for reference and user tokens
    let first_txid = find.first_input_txid(inputs)
    let first_idx = find.first_input_index(inputs)
    let ref_tkn =
      values.unique_token_name(first_txid, first_idx, cip68.prefix_100)
    let user_tkn =
      values.unique_token_name(first_txid, first_idx, cip68.prefix_222)

    let minted_tokens = mint |> value.from_minted_value()

    when r is {
      CreateService -> {
        let service_address = credential.from_script(own_policy)

        // expect [output, ..] = outputs
        // expect [input, ..] = inputs
        let ref_value = value.from_asset(own_policy, ref_tkn, 1)
        let user_value = value.from_asset(own_policy, user_tkn, 1)
        let merged_mint = value.merge(ref_value, user_value)

        trace @"merged_mint"
        trace cbor.diagnostic(merged_mint)

        // Find the output UTxO containing the reference token
        let output_utxo =
          utils.output_by_addr_value(outputs, service_address, ref_value)

        // Validate the Datum meets Service Provider requirements.
        // Extract and validate the ServiceDatum
        expect datum: ServiceDatum = data.output_datum(output_utxo)

        trace @"ServiceDatum"
        trace cbor.diagnostic(datum)

        let metadata_valid = is_metadata_valid(datum)

        // trace @"output_address"
        // trace cbor.diagnostic(output.address)
        trace @"service_address"
        trace cbor.diagnostic(service_address)
        // trace @"ref_value"
        // trace cbor.diagnostic(ref_value)
        // trace @"Output"
        // trace cbor.diagnostic(output)
        // let service_fee_valid = datum.service_fee_qty >= 1
        // let penalty_fee_valid = datum.penalty_fee_qty >= 0
        // let total_installments_valid = datum.total_installments >= 1
        // let min_sub_period_valid = datum.min_sub_period >= 1
        and {
          // Validate the Datum meets Service Provider requirements.
          // Ensure all datum validations pass
          // service_fee_valid?,
          // penalty_fee_valid?,
          // total_installments_valid?,
          metadata_valid?,
          //  Validate that the redeemer only mints a single CIP68 compliant
          (merged_mint == minted_tokens)?,
          payout.at_least(service_address, ref_value, outputs)?,
        }
      }

      DeleteService -> {
        let ref_value_burn = value.from_asset(own_policy, ref_tkn, -1)
        let user_value_burn = value.from_asset(own_policy, user_tkn, -1)
        let merged_burn = value.merge(ref_value_burn, user_value_burn)

        trace @"merged_burn"
        trace cbor.diagnostic(merged_burn)

        // let mint_flat =
        //   minted_tokens
        //     |> value.flatten()
        // trace @"minted_tokens"
        // trace cbor.diagnostic(minted_tokens)
        // trace @"merged_burn"
        // trace cbor.diagnostic(merged_burn)
        // trace @"mint_flat"
        // trace cbor.diagnostic(mint_flat)
        and {
          // Validate that the redeemer only burns a single CIP68 compliant Service NFT.
          (merged_burn == minted_tokens)?,
          True,
        }
      }
    }
    // Check nfts with ref and user token prefixes are burnt
    // minting.by_prefix(mint_flat, own_policy, cip68.prefix_100, -1)?,
    // minting.by_prefix(mint_flat, own_policy, cip68.prefix_222, -1)?,
  }

  fn spend_service(
    datum: ServiceDatum,
    rdmr: SpendService,
    ctx: ScriptContext,
  ) -> Bool {
    let ScriptContext { transaction: tx, purpose } = ctx

    expect Spend(output_reference) = purpose
    // Validate that Service UTxO with a Service NFT is being spent.
    let Transaction { outputs, .. } = ctx.transaction
    expect Some(own_input) = transaction.find_input(tx.inputs, output_reference)
    trace @"own_input"
    trace cbor.diagnostic(own_input)

    expect [output, ..] = outputs
    // let service_addr: Address = own_input.output.address
    // let service_addr: Address = own_input.output.address
    let service_addr = own_input.output.address
    let ref_nft =
      own_input.output.value
        |> value.without_lovelace()
    trace @"ref_value"
    trace cbor.diagnostic(ref_nft)
    trace @"output_reference"
    trace cbor.diagnostic(output_reference)
    when rdmr is {
      UpdateService -> {
        // trace @"output_address"
        // trace cbor.diagnostic(output.address)
        // let service_addr = own_input.output.address
        trace @"service_address"
        trace cbor.diagnostic(service_addr)

        // trace @"Output"
        // trace cbor.diagnostic(output)
        // Find the output containing the reference NFT being sent back to this script itself
        let validating_output =
          utils.output_by_addr_value(tx.outputs, service_addr, ref_nft)

        // Extract the new datum from the validating output
        expect new_datum: ServiceDatum = data.output_datum(validating_output)

        trace @"new_datum"
        trace cbor.diagnostic(new_datum)
        // Validate that the metadata of the Reference NFT is updated within acceptable bounds
        let metadata_valid = is_metadata_valid(new_datum)

        // Validate service fee changes are within acceptable range
        let service_fee_change_valid =
          is_fee_change_valid(datum.service_fee_qty, new_datum.service_fee_qty)
        and {
          // Validate that the metadata of the Reference NFT is updated within acceptable bounds .
          metadata_valid?,
          //  Validate that the service fee should be limited to a range to prevent extreme flucutation in service
          // fee by the service provider e.g +/-10%
          service_fee_change_valid?,
          payout.at_least(service_addr, ref_nft, tx.outputs)?,
          utils.check_output_utxo(validating_output)?,
          True,
        }
      }
      // Removes the utxo entirely from the script address.
      RemoveService -> {
        // this doesn't check for burn or destination for more of an open ended approach
        let validating_output = utils.output_by_value(tx.outputs, ref_nft)

        and {
          // Validate that there's a single script input and No Script output back to the script address.
          // single script input
          count.inputs_by_addr(tx.inputs, service_addr, 1)?,
          // no script output
          count.outputs_by_addr(tx.outputs, service_addr, 0)?,
          // Validate UTxO with Reference NFT is being spent.
          utils.check_output_utxo(validating_output)?,
          True,
        }
      }
    }
  }
}

// Helper function to validate service fee changes
fn is_metadata_valid(datum: ServiceDatum) -> Bool {
  // Implement logic to ensure fee changes are within acceptable range
  // For example, limit changes to ±10%
  let service_fee_valid = datum.service_fee_qty >= 1
  let penalty_fee_valid = datum.penalty_fee_qty >= 0
  let total_installments_valid = datum.total_installments >= 1
  let min_sub_period_valid = datum.min_sub_period >= 1
  service_fee_valid && penalty_fee_valid && total_installments_valid && min_sub_period_valid
}

// Helper function to validate service fee changes
fn is_fee_change_valid(old_fee: Int, new_fee: Int) -> Bool {
  // Implement logic to ensure fee changes are within acceptable range
  // For example, limit changes to ±10%
  trace @"old_fee"
  trace cbor.diagnostic(old_fee)
  trace @"new_fee"
  trace cbor.diagnostic(new_fee)

  let max_change = old_fee / 10

  trace @"max_change"
  trace cbor.diagnostic(max_change)

  abs(new_fee - old_fee) <= max_change
}

test can_create_service() {
  let own_cs = #"746fa3ba2daded6ab9ccc1e39d3835aa1dfcb9b5a54acc2ebe6b79a4"
  let init_output_ref =
    OutputReference {
      transaction_id: TransactionId {
        hash: #"2c6dbc95c1e96349c4131a9d19b029362542b31ffd2340ea85dd8f28e271ff6d",
      },
      output_index: 1,
    }

  let datum =
    ServiceDatum {
      service_fee: AssetClass {
        policy_id: value.ada_policy_id,
        asset_name: value.ada_asset_name,
      },
      // Replace with actual AssetName
      service_fee_qty: 1,
      penalty_fee: AssetClass {
        policy_id: value.ada_policy_id,
        asset_name: value.ada_asset_name,
      },
      penalty_fee_qty: 1,
      total_installments: 1,
      min_sub_period: 1,
    }

  let redeemer = CreateService

  let ref_tkn =
    values.unique_token_name(
      #"2c6dbc95c1e96349c4131a9d19b029362542b31ffd2340ea85dd8f28e271ff6d",
      1,
      cip68.prefix_100,
    )

  let user_tkn =
    values.unique_token_name(
      #"2c6dbc95c1e96349c4131a9d19b029362542b31ffd2340ea85dd8f28e271ff6d",
      1,
      cip68.prefix_222,
    )

  let ref_value = value.add(value.zero(), own_cs, ref_tkn, 1)
  let user_value = value.add(value.zero(), own_cs, user_tkn, 1)
  let minted_value = value.merge(ref_value, user_value)
  //   let placeholder_utxo =
  //     OutputReference { transaction_id: TransactionId(""), output_index: 0 }
  let user_output =
    Output {
      address: Address(
        credential.ScriptCredential(
          #"746fa3ba2daded6ab9ccc1e39d3835aa1dfcb9b5a54acc2ebe6b79a4",
        ),
        None,
      ),
      value: value.add(
        minted_value,
        value.ada_policy_id,
        value.ada_asset_name,
        4_000_000,
      ),
      datum: InlineDatum(datum),
      reference_script: None,
    }
  let context =
    ScriptContext {
      purpose: Mint(own_cs),
      transaction: Transaction {
        inputs: [
          Input {
            output_reference: init_output_ref,
            output: Output {
              address: Address(credential.ScriptCredential(own_cs), None),
              value: value.from_lovelace(4_000_000),
              datum: NoDatum,
              reference_script: None,
            },
          },
        ],
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
        id: TransactionId {
          hash: #"2c6dbc95c1e96349c4131a9d19b029362542b31ffd2340ea85dd8f28e271ff6d",
        },
      },
    }
  mint_service(redeemer, context)
}

test can_delete_service() {
  let own_cs = #"746fa3ba2daded6ab9ccc1e39d3835aa1dfcb9b5a54acc2ebe6b79a4"
  let init_output_ref =
    OutputReference {
      transaction_id: TransactionId {
        hash: #"2c6dbc95c1e96349c4131a9d19b029362542b31ffd2340ea85dd8f28e271ff6d",
      },
      output_index: 1,
    }

  let datum =
    ServiceDatum {
      service_fee: AssetClass {
        policy_id: value.ada_policy_id,
        asset_name: value.ada_asset_name,
      },
      // Replace with actual AssetName
      service_fee_qty: 1,
      penalty_fee: AssetClass {
        policy_id: value.ada_policy_id,
        asset_name: value.ada_asset_name,
      },
      penalty_fee_qty: 1,
      total_installments: 1,
      min_sub_period: 1,
    }

  let redeemer = DeleteService

  let ref_tkn =
    values.unique_token_name(
      #"2c6dbc95c1e96349c4131a9d19b029362542b31ffd2340ea85dd8f28e271ff6d",
      1,
      cip68.prefix_100,
    )

  let user_tkn =
    values.unique_token_name(
      #"2c6dbc95c1e96349c4131a9d19b029362542b31ffd2340ea85dd8f28e271ff6d",
      1,
      cip68.prefix_222,
    )

  //   let ref_value = value.from_asset(own_cs, ref_tkn, 1)
  let ref_value = value.add(value.zero(), own_cs, ref_tkn, -1)
  let user_value = value.add(value.zero(), own_cs, user_tkn, -1)
  let minted_value = value.merge(ref_value, user_value)
  //   let placeholder_utxo =
  //     OutputReference { transaction_id: TransactionId(""), output_index: 0 }
  let user_output =
    Output {
      address: Address(
        credential.ScriptCredential(
          #"746fa3ba2daded6ab9ccc1e39d3835aa1dfcb9b5a54acc2ebe6b79a4",
        ),
        None,
      ),
      value: value.add(
        minted_value,
        value.ada_policy_id,
        value.ada_asset_name,
        4_000_000,
      ),
      datum: InlineDatum(datum),
      reference_script: None,
    }
  let context =
    ScriptContext {
      purpose: Mint(own_cs),
      transaction: Transaction {
        inputs: [
          Input {
            output_reference: init_output_ref,
            output: Output {
              address: Address(credential.ScriptCredential(own_cs), None),
              value: value.from_lovelace(4_000_000),
              datum: NoDatum,
              reference_script: None,
            },
          },
        ],
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
        id: TransactionId {
          hash: #"2c6dbc95c1e96349c4131a9d19b029362542b31ffd2340ea85dd8f28e271ff6d",
        },
      },
    }
  mint_service(redeemer, context)
}

test can_update_service() {
  let own_cs = #"746fa3ba2daded6ab9ccc1e39d3835aa1dfcb9b5a54acc2ebe6b79a4"
  let init_output_ref =
    OutputReference {
      transaction_id: TransactionId {
        hash: #"2c6dbc95c1e96349c4131a9d19b029362542b31ffd2340ea85dd8f28e271ff6d",
      },
      output_index: 1,
    }

  let datum =
    ServiceDatum {
      service_fee: AssetClass {
        policy_id: value.ada_policy_id,
        asset_name: value.ada_asset_name,
      },
      // Replace with actual AssetName
      service_fee_qty: 100,
      penalty_fee: AssetClass {
        policy_id: value.ada_policy_id,
        asset_name: value.ada_asset_name,
      },
      penalty_fee_qty: 1,
      total_installments: 1,
      min_sub_period: 1,
    }

  let new_datum =
    ServiceDatum {
      service_fee: AssetClass {
        policy_id: value.ada_policy_id,
        asset_name: value.ada_asset_name,
      },
      // Replace with actual AssetName
      service_fee_qty: 90,
      penalty_fee: AssetClass {
        policy_id: value.ada_policy_id,
        asset_name: value.ada_asset_name,
      },
      penalty_fee_qty: 1,
      total_installments: 1,
      min_sub_period: 1,
    }

  let redeemer = UpdateService

  let ref_tkn =
    values.unique_token_name(
      #"2c6dbc95c1e96349c4131a9d19b029362542b31ffd2340ea85dd8f28e271ff6d",
      1,
      cip68.prefix_100,
    )

  let ref_value = value.from_asset(own_cs, ref_tkn, 1)

  // Create an input UTxO that includes the reference NFT
  let input_value =
    value.add(ref_value, value.ada_policy_id, value.ada_asset_name, 4_000_000)

  // Create an input with the correct output reference and value
  let input =
    Input {
      output_reference: init_output_ref,
      output: Output {
        address: Address(
          credential.ScriptCredential(own_cs),
          // Match the script's address
          None,
        ),
        value: input_value,
        datum: InlineDatum(datum),
        // Include the correct datum
        reference_script: None,
      },
    }
  let user_output =
    Output {
      address: Address(
        credential.ScriptCredential(
          #"746fa3ba2daded6ab9ccc1e39d3835aa1dfcb9b5a54acc2ebe6b79a4",
        ),
        None,
      ),
      value: input_value,
      datum: InlineDatum(new_datum),
      reference_script: None,
    }
  let context =
    ScriptContext {
      purpose: Spend(init_output_ref),
      transaction: Transaction {
        inputs: [input],
        reference_inputs: [],
        outputs: [user_output],
        fee: value.zero(),
        mint: value.to_minted_value(ref_value),
        certificates: [],
        withdrawals: [],
        validity_range: interval.everything(),
        extra_signatories: [],
        redeemers: [],
        datums: dict.new(),
        id: TransactionId {
          hash: #"2c6dbc95c1e96349c4131a9d19b029362542b31ffd2340ea85dd8f28e271ff6d",
        },
      },
    }
  spend_service(datum, redeemer, context)
}
