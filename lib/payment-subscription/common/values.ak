use aiken/crypto.{Blake2b_256, Hash, sha3_256}
use aiken/primitive/bytearray
use cardano/assets.{AssetName}
use cardano/transaction.{Transaction}

/// Calculate a unique token name from a `TxId#Idx` and prefix. Can be combined
/// with the `find` module to create unique token names from the first input
/// utxo inside the transaction.
///
/// ```aiken
/// values.unique_token_name(tx_id, tx_idx, cip68.prefix_333)
/// ```
pub fn unique_token_name(
  txid: Hash<Blake2b_256, Transaction>,
  idx: Int,
  prefix: ByteArray,
) -> AssetName {
  let txid_hash: ByteArray = sha3_256(txid)
  let prepend_index: ByteArray = bytearray.push(txid_hash, idx)
  let prepend_prefix: ByteArray = bytearray.concat(prefix, prepend_index)
  bytearray.slice(prepend_prefix, 0, 31)
}
