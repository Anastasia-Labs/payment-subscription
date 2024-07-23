use aiken/bytearray
use aiken/cbor
use aiken/dict
use aiken/hash.{Blake2b_224, Hash}
use aiken/interval
// use aiken/dict.{to_pairs}
use aiken/list
use aiken/transaction.{
  InlineDatum, Input, Mint, NoDatum, Output, OutputReference, ScriptContext,
  Spend, Transaction, TransactionId,
}
use aiken/transaction/credential.{Address, ScriptCredential, VerificationKey}
use aiken/transaction/value.{
  AssetName, PolicyId, Value, flatten, from_minted_value,
}
// use assist/count
use assist/find
use assist/minting
use assist/payout
use assist/signing
use assist/types/cip68
use assist/values
use payment_subscription/constants.{service_token_name}
use payment_subscription/types.{
  CreateService, DeleteService, MintService, PaymentDatum, SpendService,
}
use payment_subscription/utils.{output_by_value}

// Use redeemer to burn or mint
validator {
  fn mint(r: MintService, ctx: ScriptContext) -> Bool {
    let ScriptContext { transaction: tx, purpose } = ctx
    expect Mint(own_policy) = purpose

    let Transaction { inputs, mint, outputs, .. } = tx

    // Ensure only one NFT is being minted.
    expect [mint_triplet] =
      mint
        |> from_minted_value()
        |> flatten()

    let (mint_policy, mint_name, mint_quantity) = mint_triplet
    expect (mint_policy == own_policy)?
    trace cbor.diagnostic(mint_policy)

    when r is {
      types.CreateService -> {
        // To enforce a single initiation, the specified UTxO must be spent.
        let first_txid = find.first_input_txid(inputs)
        let first_idx = find.first_input_index(inputs)

        let ref_tkn =
          values.unique_token_name(first_txid, first_idx, cip68.prefix_100)
        let ref_value = value.from_asset(own_policy, ref_tkn, 1)

        let user_tkn =
          values.unique_token_name(first_txid, first_idx, cip68.prefix_222)

        // expect [Output { value: service_value, address: service_address, .. }] =
        //   list.filter(
        //     outputs,
        //     fn(output) {
        //       output.address.payment_credential == ScriptCredential(own_policy)
        //     },
        //   )
        let output_utxo =
          utils.output_by_addr_value(outputs, service_address, ref_value)

        // List head UTxO must contain only one other asset apart from Lovelaces.
        // let service_asset = get_single_asset_from_value(service_value)
        // List head's asset must match the minted asset.
        // (service_asset == mint_triplet)?
        and {
          // signing.verify_sig(tx.extra_signatories, issuer)?,
          // Allow only two nfts to be minted at once
          (list.length([mint_triplet]) == 2)?,
          // Prevent byte overflow leading to duplicate asset names
          first_idx < 256,
          // Check reference nft being minted
          minting.exact([mint_triplet], own_policy, ref_tkn, 1)?,
          // Check user nft being minted
          minting.exact([mint_triplet], own_policy, user_tkn, 1)?,
          // Must send the reference nft to store address
          payout.at_least(service_address, ref_value, outputs)?,
          utils.check_output_utxo(output_utxo)?,
        }
      }

      // Must send the reference nft to service address
      //   payout.at_least(service_address, ref_value, outputs)?,
      //   utils.check_output_utxo(output)?,
      // expect
      //   list.any(inputs, fn(input) { input.output_reference == utxo_ref })
      // expect (1 == amount)?
      // expect (asset_name == token_name)?
      // True
      types.DeleteService -> and {
          //   signing.verify_sig(tx.extra_signatories, issuer)?,
          // Check nfts with ref and user token prefixes are burnt
          minting.by_prefix([mint_triplet], own_policy, cip68.prefix_100, -1)?,
          minting.by_prefix([mint_triplet], own_policy, cip68.prefix_222, -1)?,
          // Must burn exactly one nft pair. Check token names to ensure the nft pairs are correct
          when [mint_triplet] is {
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

  fn spend(datum: PaymentDatum, rdmr: SpendService, ctx: ScriptContext) -> Bool {
    expect ScriptContext { transaction: tx, purpose } = ctx

    expect Spend(output_reference) = purpose
    // The input being spent containing the reference nft.
    // Assumption being that this contract only has CIP68 reference nfts locked in it
    // and each utxo holds exactly one refrence nft.
    expect Some(input) = transaction.find_input(tx.inputs, output_reference)
    let ref_nft =
      input.output.value
        |> value.without_lovelace()

    when rdmr is {
      types.UpdateService -> {
        let script_addr = input.output.address

        // Find the output containing reference nft being sent back to this script itself
        // Fail if no such output is found. Reference nft must never leave the contract 
        // if the intention was to just update the nft metadata
        let validating_output =
          utils.output_by_addr_value(tx.outputs, script_addr, ref_nft)

        and {
          //   signing.verify_sig(tx.extra_signatories, issuer)?,
          utils.check_output_utxo(validating_output)?,
          True,
        }
      }
      types.RemoveService -> {
        let validating_output = utils.output_by_value(tx.outputs, ref_nft)

        and {
          // Check if the transaction is signed by issuer and allow them to remove
          // any asset that they wish.
          //   signing.verify_sig(tx.extra_signatories, issuer)?,
          utils.check_output_utxo(validating_output)?,
          True,
        }
      }
    }
  }
}

fn get_single_asset_from_value(v: Value) -> (PolicyId, AssetName, Int) {
  // A single asset was expected.
  expect [triplet] =
    v
      |> value.without_lovelace
      |> value.flatten
  triplet
}
// test mint_validator_init() {
//   let own_cs = #"746fa3ba2daded6ab9ccc1e39d3835aa1dfcb9b5a54acc2ebe6b79a4"
//   let init_output_ref =
//     OutputReference {
//       transaction_id: TransactionId {
//         hash: #"2c6dbc95c1e96349c4131a9d19b029362542b31ffd2340ea85dd8f28e271ff6d",
//       },
//       output_index: 1,
//     }
//   //   let config =
//   //     Config { utxo_ref: init_output_ref, token_name: token_name }
//   let redeemer = CreateService
//   let minted_value = value.add(value.zero(), own_cs, service_token_name, 1)
//   let placeholder_utxo =
//     OutputReference { transaction_id: TransactionId(""), output_index: 0 }

//   let user_output =
//     Output {
//       address: Address(credential.ScriptCredential("B"), None),
//       value: value.add(
//         minted_value,
//         value.ada_policy_id,
//         value.ada_asset_name,
//         4_000_000,
//       ),
//       datum: NoDatum,
//       reference_script: None,
//     }
//   let context =
//     ScriptContext {
//       purpose: Mint(own_cs),
//       transaction: Transaction {
//         inputs: [
//           Input {
//             output_reference: init_output_ref,
//             output: Output {
//               address: Address(credential.ScriptCredential("C"), None),
//               value: value.from_lovelace(4_000_000),
//               datum: NoDatum,
//               reference_script: None,
//             },
//           },
//         ],
//         reference_inputs: [],
//         outputs: [user_output],
//         fee: value.zero(),
//         mint: value.to_minted_value(minted_value),
//         certificates: [],
//         withdrawals: [],
//         validity_range: interval.everything(),
//         extra_signatories: [],
//         redeemers: [],
//         datums: dict.new(),
//         id: TransactionId {
//           hash: #"2c6dbc95c1e96349c4131a9d19b029362542b31ffd2340ea85dd8f28e271ff6d",
//         },
//       },
//     }
//   mint(redeemer, context)
// }
