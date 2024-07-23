// use aiken/bytearray
// use aiken/cbor
// use aiken/hash.{Blake2b_224, Hash}
// // use aiken/dict.{to_pairs}
// use aiken/list
// use aiken/transaction.{
//   InlineDatum, Mint, Output, OutputReference, ScriptContext, Transaction,
// }
// use aiken/transaction/credential.{ScriptCredential, VerificationKey}
// use aiken/transaction/value.{AssetName, flatten, from_minted_value}
// // use assist/count
// use assist/find
// use assist/minting
// use assist/payout
// use assist/signing
// use assist/types/cip68
// use assist/values
// use payment_subscription/types.{
//   InitSubscripton, MintPayment, PaymentDatum, TerminateSubscription,
// }
// use payment_subscription/utils

// // Use redeemer to burn or mint
// validator(
//   issuer: Hash<Blake2b_224, VerificationKey>,
//   utxo_ref: OutputReference,
//   store: Hash<Blake2b_224, VerificationKey>,
// ) {
//   fn mint(r: MintPayment, ctx: ScriptContext) -> Bool {
//     let ScriptContext { transaction: tx, purpose } = ctx
//     expect Mint(own_policy) = purpose

//     let Transaction { inputs, mint, outputs, .. } = tx

//     // TODO: Convert to expect
//     // Ensure only one NFT is being minted.
//     let mint_flat =
//       mint
//         |> from_minted_value()
//         |> flatten()

//     when r is {
//       types.InitSubscripton -> {
//         let first_txid = find.first_input_txid(inputs)
//         let first_idx = find.first_input_index(inputs)

//         let ref_tkn =
//           values.unique_token_name(first_txid, first_idx, cip68.prefix_100)
//         let ref_value = value.from_asset(own_policy, ref_tkn, 1)

//         let user_tkn =
//           values.unique_token_name(first_txid, first_idx, cip68.prefix_222)

//         let store_address = credential.from_script(store)
//         trace cbor.diagnostic(ref_value)

//         let output_utxo =
//           utils.output_by_addr_value(outputs, store_address, ref_value)

//         // Only one UTxO must be produced at the script address.
//         //Ensure that the value carries a propper NFT.
//         // expect [
//         //   Output {
//         //     datum: InlineDatum(list_head_datum),
//         //     value: list_head_value,
//         //     ..
//         //   },
//         // ] =
//         //   list.filter(
//         //     outputs,
//         //     fn(output) {
//         //       output.address.payment_credential == ScriptCredential(own_policy)
//         //     },
//         //   )
//         // trace cbor.diagnostic(ref_value)
//         and {
//           signing.verify_sig(tx.extra_signatories, issuer)?,
//           // Allow only two nfts to be minted at once
//           (list.length(mint_flat) == 2)?,
//           // Prevent byte overflow leading to duplicate asset names
//           first_idx < 256,
//           // Check reference nft being minted
//           minting.exact(mint_flat, own_policy, ref_tkn, 1)?,
//           // Check user nft being minted
//           minting.exact(mint_flat, own_policy, user_tkn, 1)?,
//           // Must send the reference nft to store address
//           payout.at_least(store_address, ref_value, outputs)?,
//           utils.check_output_utxo(output_utxo)?,
//         }
//       }
//       // expect
//       //   list.any(inputs, fn(input) { input.output_reference == utxo_ref })
//       // expect (1 == amount)?
//       // expect (asset_name == token_name)?
//       // True
//       types.TerminateSubscription -> and {
//           signing.verify_sig(tx.extra_signatories, issuer)?,
//           // Check nfts with ref and user token prefixes are burnt
//           minting.by_prefix(mint_flat, own_policy, cip68.prefix_100, -1)?,
//           minting.by_prefix(mint_flat, own_policy, cip68.prefix_222, -1)?,
//           // Must burn exactly one nft pair. Check token names to ensure the nft pairs are correct
//           when mint_flat is {
//             [(_pid1, tkn1, _amt1), (_pid2, tkn2, _amt2)] ->
//               bytearray.compare(
//                 bytearray.drop(tkn1, 4),
//                 bytearray.drop(tkn2, 4),
//               ) == Equal
//             _ -> False
//           },
//         }
//     }
//   }

//   fn spend(datum: PaymentDatum, _redeemer: Void, ctx: ScriptContext) -> Bool {
//     todo
//   }
// }
