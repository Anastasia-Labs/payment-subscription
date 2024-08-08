use aiken/cbor
use aiken/list
use aiken/transaction.{Output}
use aiken/transaction/credential.{Address, Credential}
use aiken/transaction/value.{PolicyId, Value}
use assist/values

// use payment_subscription/types.{MetaDatum}

// Check the output utxo containing the reference nft
pub fn check_output_utxo(output: Output) -> Bool {
  // Check inline datum exists and conforms to MetaDatum as per CIP68
  trace cbor.diagnostic(output.datum)

  //   expect InlineDatum(data) = output.datum
  //   expect _metadatum: MetaDatum = data
  let output_value =
    output.value
      |> value.without_lovelace()
      |> value.flatten()
  // Check no other token is present in the utxo containing reference nft
  list.length(output_value) == 1
}

/// Return the first occurrence of an output that contains at least some specific
/// value at some address. If nothing is found then error. This function
/// does not search for an exact UTxO match.
///
/// ```aiken
/// find.output_by_addr_value(tx.outputs, wallet_addr, just_token_value)
/// ```
pub fn output_by_addr_value(
  outputs: List<Output>,
  addr: Address,
  value: Value,
) -> Output {
  when outputs is {
    [output, ..rest] ->
      if output.address == addr && values.contains(output.value, value) {
        output
      } else {
        output_by_addr_value(rest, addr, value)
      }
    // nothing was found
    [] -> fail @"No Output found"
  }
}

/// Return the first occurrence of an output that contains at least some specific
/// value. If nothing is found then error. This function
/// does not search for an exact UTxO match.
///
/// ```aiken
/// find.output_by_value(tx.outputs, just_token_value)
/// ```
pub fn output_by_value(outputs: List<Output>, value: Value) -> Output {
  when outputs is {
    [output, ..rest] ->
      if values.contains(value, output.value) {
        output
      } else {
        output_by_value(rest, value)
      }
    // nothing was found
    [] -> fail @"No Output found"
  }
}

// Helper function to validate where the NFT goes
pub fn validate_token_output(
  output: Output,
  policy: PolicyId,
  token_name: ByteArray,
  expected_credential: Credential,
  expect_script: Bool,
) -> Bool {
  let token_quantity = value.quantity_of(output.value, policy, token_name)
  let payment_credential = output.address.payment_credential

  trace @"token_name"
  trace cbor.diagnostic(token_name)
  trace @"token_quantity"
  trace cbor.diagnostic(token_quantity)

  token_quantity == 1 && if expect_script {
    payment_credential == expected_credential
  } else {
    payment_credential != expected_credential
  }
}
