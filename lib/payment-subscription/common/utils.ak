use aiken/cbor
use aiken/interval.{Finite, Interval}
use aiken/list
use aiken/time.{PosixTime}
use aiken/transaction.{Input, Output, ValidityRange}
use aiken/transaction/credential.{Address, Credential}
use aiken/transaction/value.{PolicyId, Value}
use assist/values

// Check only one NFT is present in the utxo
pub fn check_nft_output_utxo(output: Output) -> Bool {
  let output_value =
    output.value
      |> value.without_lovelace()
      |> value.flatten()
  list.length(output_value) == 1
}

/// Return the first occurrence of an output that contains at least some specific
/// value at some address. If nothing is found then error. This function
/// does not search for an exact UTxO match.
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

// Helper function to validate if an input has 1 NFT
pub fn validate_single_nft_input(
  input: Input,
  policy: PolicyId,
  token_name: ByteArray,
) -> Bool {
  value.quantity_of(input.output.value, policy, token_name) == 1
}

// Helper function to validate where the NFT goes
pub fn validate_token_output(
  output: Output,
  policy: PolicyId,
  token_name: ByteArray,
  credential: Credential,
  is_credential: Bool,
) -> Bool {
  let token_quantity = value.quantity_of(output.value, policy, token_name)
  let payment_credential = output.address.payment_credential

  trace @"token_name"
  trace cbor.diagnostic(token_name)
  trace @"token_quantity"
  trace cbor.diagnostic(token_quantity)
  token_quantity == 1 && if is_credential {
    payment_credential == credential
  } else {
    payment_credential != credential
  }
}

pub fn get_input_by_token(inputs: List<Input>, policy_id: PolicyId) {
  list.find(
    inputs,
    fn(input) { list.has(value.policies(input.output.value), policy_id) },
  )
}

pub fn must_be_after_deadline(range: ValidityRange, deadline: PosixTime) {
  // Pattern match for the type of the lower bound
  when range.lower_bound.bound_type is {
    // If the lower bound is finite, check if it's after the deadline
    Finite(tx_earliest_time) -> deadline <= tx_earliest_time
    // Else, the lower bound is infinite, so we fail
    _ -> False
  }
}

pub fn get_minimum_current_time_estimate(
  range: Interval<PosixTime>,
) -> PosixTime {
  when range.lower_bound.bound_type is {
    Finite(current_time) -> current_time
    _ -> fail @"Invalid lower bound"
  }
}
