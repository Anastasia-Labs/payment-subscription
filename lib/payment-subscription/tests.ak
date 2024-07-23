// use aiken/bytearray
// use aiken/hash.{blake2b_256}
// use aiken/list
// use aiken/transaction.{
//   InlineDatum, Mint, Output, OutputReference, ScriptContext, Spend,
//   TransactionId,
// }
// use aiken/transaction/credential.{Address, ScriptCredential}
// use aiken/transaction/value.{AssetName}

// // Generate a bytearray with blake2b_256
// fn test_224_01() {
//   bytearray.take(blake2b_256(#"01"), 28)
// }

// // Generate a bytearray with blake2b_256
// fn test_224_02() {
//   bytearray.take(blake2b_256(#"02"), 28)
// }

// // Create a UTxO
// fn test_utxo_01() {
//   Output {
//     address: Address {
//       payment_credential: ScriptCredential(test_224_01()),
//       stake_credential: None,
//     },
//     value: value.add(value.from_lovelace(2_000_000), test_224_01(), #"01", 1),
//     datum: InlineDatum(1),
//     reference_script: None,
//   }
// }

// // Create a UTxO
// fn test_utxo_02() {
//   Output {
//     address: Address {
//       payment_credential: ScriptCredential(test_224_02()),
//       stake_credential: None,
//     },
//     value: value.add(value.from_lovelace(2_000_000), test_224_02(), #"02", 1),
//     datum: InlineDatum(1),
//     reference_script: None,
//   }
// }
