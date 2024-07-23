// use aiken/cbor
// use aiken/dict
// use aiken/interval
// use aiken/list
// use aiken/transaction.{
//   Input, Mint, NoDatum, Output, OutputReference, ScriptContext, Transaction,
//   TransactionId,
// }
// use aiken/transaction/credential.{Address, ScriptCredential}
// use aiken/transaction/value.{
//   AssetName, PolicyId, Value, from_minted_value, tokens,
// }
// use payment_subscription/constants.{origin_node_token_name}
// use payment_subscription/utils

// type Action {
//   Minting
//   Burning
// }

// pub type Config {
//   utxo_ref: OutputReference,
//   token_name: AssetName,
// }

// // Use redeemer to burn or mint
// validator {
//   fn mint_nft(cfg: Config, r: Action, ctx: ScriptContext) -> Bool {
//     let ScriptContext { transaction: tx, purpose } = ctx
//     expect Mint(own_policy) = purpose

//     let Transaction { inputs, mint, outputs, .. } = tx
//     expect [Pair(asset_name, amount)] =
//       mint |> from_minted_value() |> tokens(own_policy) |> dict.to_pairs()

//     when r is {
//       Minting -> {
//         expect
//           list.any(inputs, fn(input) { input.output_reference == cfg.utxo_ref })
//         expect (1 == amount)?
//         expect (asset_name == cfg.token_name)?

//         expect [Output { value: list_head_value, .. }] =
//           list.filter(
//             outputs,
//             fn(output) {
//               output.address.payment_credential == ScriptCredential(own_policy)
//             },
//           )

//         // let list_head_asset = get_single_asset_from_value(list_head_value)
//         trace cbor.diagnostic(inputs)
//         trace cbor.diagnostic(cfg.utxo_ref)
//         trace cbor.diagnostic(list_head_value)

//         True
//       }
//       Burning -> {
//         expect (-1 == amount)?
//         expect (asset_name == cfg.token_name)?
//         True
//       }
//     }
//   }
// }

// fn get_single_asset_from_value(v: Value) -> (PolicyId, AssetName, Int) {
//   // A single asset was expected.
//   expect [triplet] =
//     v
//       |> value.without_lovelace
//       |> value.flatten
//   triplet
// }

// test mint_validator_init() {
//   let own_cs = #"746fa3ba2daded6ab9ccc1e39d3835aa1dfcb9b5a54acc2ebe6b79a4"
//   let init_output_ref =
//     OutputReference {
//       transaction_id: TransactionId {
//         hash: #"2c6dbc95c1e96349c4131a9d19b029362542b31ffd2340ea85dd8f28e271ff6d",
//       },
//       output_index: 1,
//     }
//   let config =
//     Config { utxo_ref: init_output_ref, token_name: origin_node_token_name }
//   let redeemer = Minting
//   let minted_value = value.add(value.zero(), own_cs, origin_node_token_name, 1)
//   let head_output =
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
//         outputs: [head_output],
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

//   mint_nft(config, redeemer, context)
// }
