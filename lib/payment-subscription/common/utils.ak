use aiken/bytearray
use aiken/interval.{Finite, Interval}
use aiken/list
use aiken/time.{PosixTime}
use aiken/transaction.{Input, Output, ValidityRange}
use aiken/transaction/credential.{Address, Credential}
use aiken/transaction/value.{AssetName, PolicyId}
use assist/types/cip68

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
  policy_id: PolicyId,
  token_name: AssetName,
) -> Output {
  when outputs is {
    [output, ..rest] ->
      if
      output.address == addr && value.quantity_of(
        output.value,
        policy_id,
        token_name,
      ) > 0{
      
        output
      } else {
        output_by_addr_value(rest, addr, policy_id, token_name)
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
) -> Bool {
  and {
    value.quantity_of(output.value, policy, token_name) == 1,
    output.address.payment_credential == credential,
  }
}

pub fn get_input_by_token(
  inputs: List<Input>,
  policy_id: PolicyId,
  token_name: AssetName,
) {
  list.find(
    inputs,
    fn(input) {
      value.quantity_of(input.output.value, policy_id, token_name) > 0
    },
  )
}

pub fn must_be_after_date(range: ValidityRange, date: PosixTime) {
  // Pattern match for the type of the lower bound
  when range.lower_bound.bound_type is {
    // If the lower bound is finite, check if it's after the date
    Finite(tx_earliest_time) -> date <= tx_earliest_time
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

pub fn convert_ref_tn_to_user(x: ByteArray) -> ByteArray {
  convert_token_name(x, bytearray.length(cip68.prefix_100), cip68.prefix_222)
}

pub fn convert_user_tn_to_ref(x: ByteArray) -> ByteArray {
  convert_token_name(x, bytearray.length(cip68.prefix_222), cip68.prefix_100)
}

fn convert_token_name(
  x: ByteArray,
  prefix_length: Int,
  prefix_to: ByteArray,
) -> ByteArray {
  bytearray.concat(prefix_to, bytearray.drop(x, prefix_length))
}
