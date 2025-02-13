use aiken/builtin
use aiken/collection/dict
use aiken/collection/list
use aiken/collection/pairs
use aiken/interval.{Finite}
use cardano/address.{Script}
use cardano/assets.{
  AssetName, PolicyId, Value, ada_policy_id, quantity_of, to_dict, tokens,
}
use cardano/transaction.{
  InlineDatum, Input, Output, OutputReference, ValidityRange,
}
use payment_subscription/common/types.{
  Installment, Payment, PaymentDatum, PaymentValidatorDatum, Penalty,
  PenaltyDatum, ServiceDatum,
}
use payment_subscription/common/utils as common_utils
use payment_subscription/payment_multi_validator/utils.{
  validate_extension_datum, validate_initial_payment_against_service,
}

pub const payment_tokenname = "subscription"

pub fn tx_time_upperbound(range: ValidityRange) -> Int {
  expect Finite(u) = range.upper_bound.bound_type
  u
}

pub fn tx_time_lowerbound(range: ValidityRange) -> Int {
  expect Finite(l) = range.lower_bound.bound_type
  l
}

fn check_correct(condition: Bool, acc: Int) -> Int {
  if condition {
    acc + 1
  } else {
    -1
  }
}

fn check_correct_tell(condition: Bool, acc: Int, x: Int) -> Pair<Int, Int> {
  if condition {
    Pair(acc + 1, x)
  } else {
    Pair(-1, x)
  }
}

fn calculate_service_fee_in_value(
  x: Value,
  service_fee_policyid: PolicyId,
  service_fee_assetname: AssetName,
  payment_policy: PolicyId,
) -> Int {
  let fold_result =
    pairs.foldr(
      x |> to_dict() |> dict.to_pairs(),
      Pair(0, 0),
      fn(k, v, r) {
        let Pair(checks, service_fee_amount) = r
        if checks >= 0 {
          if k == service_fee_policyid {
            expect [Pair(token, amount)] = dict.to_pairs(v)
            check_correct_tell(token == service_fee_assetname, checks, amount)
          } else if k == payment_policy {
            expect [Pair(token, amount)] = dict.to_pairs(v)
            check_correct_tell(
              token == payment_tokenname && amount == 1,
              checks,
              service_fee_amount,
            )
          } else if k == ada_policy_id {
            Pair(checks + 1, service_fee_amount)
          } else {
            Pair(-1, service_fee_amount)
          }
        } else {
          Pair(-1, service_fee_amount)
        }
      },
    )

  let service_fee_is_ada = service_fee_policyid == ada_policy_id
  let payment_value_correct =
    if service_fee_is_ada {
      builtin.fst_pair(fold_result) == 2
    } else {
      builtin.fst_pair(fold_result) == 3
    }
  expect payment_value_correct?
  builtin.snd_pair(fold_result)
}

// minting policy validator
pub fn validate_initial_subscription(
  own_policy: PolicyId,
  service_policy: PolicyId,
  account_policy: PolicyId,
  service_ref_input_index: Int,
  subscriber_input_index: Int,
  payment_output_index: Int,
  reference_inputs: List<Input>,
  inputs: List<Input>,
  outputs: List<Output>,
  minted_value: Value,
  validity_range: ValidityRange,
) -> Bool {
  expect Some(subscriber_input) = list.at(inputs, subscriber_input_index)
  let subscriber_utxo_value = subscriber_input.output.value

  expect Some(Output {
    address: output_address,
    value: output_value,
    datum: InlineDatum(output_datum),
    ..
  }) = list.at(outputs, payment_output_index)
  expect Payment(payment_datum): PaymentValidatorDatum = output_datum

  expect Some(Input {
    output: Output {
      value: service_utxo_value,
      datum: InlineDatum(service_utxo_datum),
      ..
    },
    ..
  }) = list.at(reference_inputs, service_ref_input_index)
  expect service_datum: ServiceDatum = service_utxo_datum

  let subscriber_user_tokenname =
    common_utils.convert_ref_tn_to_user(
      payment_datum.subscriber_reference_tokenname,
    )
  let subscriber_token_correct =
    quantity_of(
      subscriber_utxo_value,
      account_policy,
      subscriber_user_tokenname,
    ) == 1

  let service_token_correct =
    quantity_of(
      service_utxo_value,
      service_policy,
      payment_datum.service_reference_tokenname,
    ) == 1

  let payment_at_correct_address =
    output_address.payment_credential == Script(own_policy)
  let current_time_estimate = tx_time_upperbound(validity_range)
  let payment_datum_correct =
    validate_initial_payment_against_service(
      payment_datum,
      service_datum,
      current_time_estimate,
    )

  let ServiceDatum {
    service_fee_policyid,
    service_fee_assetname,
    service_fee,
    num_intervals,
    is_active,
    ..
  } = service_datum

  let payment_value_successful_checks =
    pairs.foldr(
      output_value |> to_dict() |> dict.to_pairs(),
      0,
      fn(k, v, acc) {
        if acc >= 0 {
          if k == service_fee_policyid {
            expect [Pair(token, amount)] = dict.to_pairs(v)
            let amount_correct = amount == num_intervals * service_fee
            check_correct(token == service_fee_assetname && amount_correct, acc)
          } else if k == own_policy {
            expect [Pair(token, amount)] = dict.to_pairs(v)
            check_correct(token == payment_tokenname && amount == 1, acc)
          } else if k == ada_policy_id {
            acc + 1
          } else {
            -1
          }
        } else {
          -1
        }
      },
    )

  let service_fee_is_ada = service_fee_policyid == ada_policy_id
  let payment_value_correct =
    if service_fee_is_ada {
      payment_value_successful_checks == 2
    } else {
      payment_value_successful_checks == 3
    }

  expect [Pair(tkn, 1)] = dict.to_pairs(tokens(minted_value, own_policy))
  let mint_correct = tkn == payment_tokenname

  and {
    subscriber_token_correct?,
    service_token_correct?,
    is_active?,
    payment_at_correct_address?,
    payment_datum_correct?,
    payment_value_correct?,
    mint_correct?,
  }
}

// minting policy validator
pub fn validate_terminate_subscription(
  own_policy: PolicyId,
  minted_value: Value,
) -> Bool {
  expect [Pair(tkn, -1)] = dict.to_pairs(tokens(minted_value, own_policy))
  (tkn == payment_tokenname)?
}

// spending validation
pub fn validate_extend_subscription(
  own_reference: OutputReference,
  service_policy: ByteArray,
  service_ref_input_index: Int,
  payment_input_index: Int,
  payment_output_index: Int,
  additional_intervals: Int,
  datum: PaymentValidatorDatum,
  reference_inputs: List<Input>,
  inputs: List<Input>,
  outputs: List<Output>,
) -> Bool {
  when datum is {
    Payment(payment_datum) -> {
      expect Some(Input {
        output: Output { address: payment_addr, value: payment_input_value, .. },
        output_reference: payment_input_output_reference,
      }) = list.at(inputs, payment_input_index)
      let reference_correct = payment_input_output_reference == own_reference
      let payment_script_credential = payment_addr.payment_credential
      expect Script(own_policy) = payment_script_credential

      expect Some(Input {
        output: Output {
          value: service_ref_input_value,
          datum: InlineDatum(service_ref_input_datum),
          ..
        },
        ..
      }) = list.at(reference_inputs, service_ref_input_index)
      let service_token_correct =
        quantity_of(
          service_ref_input_value,
          service_policy,
          payment_datum.service_reference_tokenname,
        ) == 1
      expect service_datum: ServiceDatum = service_ref_input_datum

      expect Some(Output {
        address: payment_output_address,
        datum: InlineDatum(payment_output_datum),
        value: payment_output_value,
        ..
      }) = list.at(outputs, payment_output_index)
      expect Payment(payment_datum_new): PaymentValidatorDatum =
        payment_output_datum

      let payment_output_address_correct =
        payment_output_address.payment_credential == payment_script_credential

      let ServiceDatum {
        service_fee_policyid,
        service_fee_assetname,
        is_active,
        ..
      } = service_datum

      let service_fee_value_new =
        calculate_service_fee_in_value(
          payment_output_value,
          service_fee_policyid,
          service_fee_assetname,
          own_policy,
        )
      let additional_amount =
        service_fee_value_new - quantity_of(
          payment_input_value,
          service_fee_policyid,
          service_fee_assetname,
        )
      let payment_datum_correct =
        validate_extension_datum(
          payment_datum,
          payment_datum_new,
          service_datum,
          additional_amount,
          additional_intervals,
        )

      and {
        reference_correct?,
        service_token_correct?,
        is_active?,
        payment_output_address_correct?,
        payment_datum_correct?,
      }
    }
    Penalty(_) -> False
  }
}

// spending validator
pub fn validate_merchant_withdraw(
  own_reference: OutputReference,
  service_policy_id: PolicyId,
  service_ref_input_index: Int,
  merchant_input_index: Int,
  payment_input_index: Int,
  payment_output_index: Int,
  installments_withdrawn: Int,
  datum: PaymentValidatorDatum,
  reference_inputs: List<Input>,
  inputs: List<Input>,
  outputs: List<Output>,
  validity_range: ValidityRange,
  mint: Value,
) -> Bool {
  expect Some(Input { output: Output { value: merchant_input_value, .. }, .. }) =
    list.at(inputs, merchant_input_index)

  expect Some(Input {
    output: Output { address: payment_addr, value: payment_input_value, .. },
    output_reference: payment_input_reference,
  }) = list.at(inputs, payment_input_index)
  let reference_correct = payment_input_reference == own_reference
  let payment_script_credential = payment_addr.payment_credential
  expect Script(own_policy) = payment_script_credential

  let payment_token_correct =
    quantity_of(payment_input_value, own_policy, payment_tokenname) == 1

  expect Some(Input {
    output: Output {
      datum: InlineDatum(service_ref_input_datum),
      value: service_ref_input_value,
      ..
    },
    ..
  }) = list.at(reference_inputs, service_ref_input_index)
  expect service_datum: ServiceDatum = service_ref_input_datum
  let ServiceDatum {
    service_fee_policyid,
    service_fee_assetname,
    is_active,
    ..
  } = service_datum

  when datum is {
    Payment(payment_datum) -> {
      let PaymentDatum {
        service_reference_tokenname,
        subscriber_reference_tokenname,
        subscription_start,
        subscription_end,
        original_subscription_end,
        installments,
      } = payment_datum

      let service_token_correct =
        quantity_of(
          service_ref_input_value,
          service_policy_id,
          service_reference_tokenname,
        ) == 1

      let service_owner_asset_name =
        common_utils.convert_ref_tn_to_user(service_reference_tokenname)
      let service_owner_token_at_input =
        quantity_of(
          merchant_input_value,
          service_policy_id,
          service_owner_asset_name,
        ) == 1

      expect Some(Output {
        address: payment_output_address,
        datum: InlineDatum(payment_output_datum),
        value: payment_output_value,
        ..
      }) = list.at(outputs, payment_output_index)
      expect Payment(payment_datum_new): PaymentValidatorDatum =
        payment_output_datum

      let payment_output_address_correct =
        payment_output_address.payment_credential == payment_script_credential

      let service_fee_value_old =
        quantity_of(
          payment_input_value,
          service_fee_policyid,
          service_fee_assetname,
        )
      let service_fee_value_new =
        calculate_service_fee_in_value(
          payment_output_value,
          service_fee_policyid,
          service_fee_assetname,
          own_policy,
        )

      let installments_withdrawn_correct = installments_withdrawn > 0

      let payment_output_datum_correct =
        payment_datum_new == PaymentDatum {
          service_reference_tokenname,
          subscriber_reference_tokenname,
          subscription_start,
          subscription_end,
          original_subscription_end,
          installments: list.drop(installments, installments_withdrawn),
        }
      let current_time = tx_time_lowerbound(validity_range)
      let expected_removal =
        list.foldr(
          list.take(installments, installments_withdrawn),
          0,
          fn(i, acc) {
            let Installment { claimable_at, claimable_amount } = i
            expect claimable_at < current_time
            acc + claimable_amount
          },
        )
      let value_removal_correct =
        service_fee_value_old - service_fee_value_new <= expected_removal

      and {
        reference_correct?,
        service_token_correct?,
        is_active?,
        service_owner_token_at_input?,
        payment_token_correct?,
        payment_output_address_correct?,
        installments_withdrawn_correct?,
        payment_output_datum_correct?,
        value_removal_correct?,
      }
    }

    Penalty(penalty_datum) -> {
      let PenaltyDatum { service_reference_tokenname, .. } = penalty_datum
      let service_token_correct =
        quantity_of(
          service_ref_input_value,
          service_policy_id,
          service_reference_tokenname,
        ) == 1
      let service_owner_asset_name =
        common_utils.convert_ref_tn_to_user(service_reference_tokenname)
      let service_owner_token_at_input =
        quantity_of(
          merchant_input_value,
          service_policy_id,
          service_owner_asset_name,
        ) == 1
      let payment_token_burnt =
        quantity_of(mint, own_policy, payment_tokenname) == -1

      and {
        reference_correct?,
        service_token_correct?,
        is_active?,
        service_owner_token_at_input?,
        payment_token_correct?,
        payment_token_burnt?,
      }
    }
  }
}

// spending validator
pub fn validate_unsubscribe(
  own_reference: OutputReference,
  account_policy_id: PolicyId,
  service_policy_id: PolicyId,
  service_ref_input_index: Int,
  subscriber_input_index: Int,
  payment_input_index: Int,
  penalty_output_index: Int,
  datum: PaymentValidatorDatum,
  reference_inputs: List<Input>,
  inputs: List<Input>,
  outputs: List<Output>,
  validity_range: ValidityRange,
  mint: Value,
) -> Bool {
  when datum is {
    Payment(payment_datum) -> {
      let PaymentDatum {
        service_reference_tokenname,
        subscriber_reference_tokenname,
        original_subscription_end,
        ..
      } = payment_datum

      expect Some(Input {
        output: Output { value: subscriber_input_value, .. },
        ..
      }) = list.at(inputs, subscriber_input_index)
      let user_token_name =
        common_utils.convert_ref_tn_to_user(subscriber_reference_tokenname)
      let user_token_at_input =
        quantity_of(subscriber_input_value, account_policy_id, user_token_name) == 1

      expect Some(Input {
        output: Output { address: payment_addr, value: payment_input_value, .. },
        output_reference: payment_input_reference,
      }) = list.at(inputs, payment_input_index)
      let reference_correct = payment_input_reference == own_reference
      let payment_script_credential = payment_addr.payment_credential
      expect Script(own_policy) = payment_script_credential

      let payment_token_correct =
        quantity_of(payment_input_value, own_policy, payment_tokenname) == 1

      expect Some(Input {
        output: Output {
          value: service_ref_input_value,
          datum: InlineDatum(service_ref_input_datum),
          ..
        },
        ..
      }) = list.at(reference_inputs, service_ref_input_index)
      let service_token_correct =
        quantity_of(
          service_ref_input_value,
          service_policy_id,
          service_reference_tokenname,
        ) == 1
      expect service_datum: ServiceDatum = service_ref_input_datum

      let ServiceDatum {
        penalty_fee_policyid,
        penalty_fee_assetname,
        penalty_fee,
        is_active,
        ..
      } = service_datum

      let current_time = tx_time_lowerbound(validity_range)
      let can_unsubscribe_without_penalty =
        original_subscription_end <= current_time

      if can_unsubscribe_without_penalty || !is_active {
        let token_burned =
          dict.to_pairs(tokens(mint, own_policy)) == [
            Pair(payment_tokenname, -1),
          ]

        and {
          user_token_at_input?,
          reference_correct?,
          service_token_correct?,
          payment_token_correct?,
          token_burned?,
        }
      } else {
        expect Some(Output {
          address: payment_output_address,
          datum: InlineDatum(payment_output_datum),
          value: payment_output_value,
          ..
        }) = list.at(outputs, penalty_output_index)
        expect Penalty(payment_datum_new): PaymentValidatorDatum =
          payment_output_datum

        let payment_output_address_correct =
          payment_output_address.payment_credential == payment_script_credential
        let payment_output_datum_correct =
          payment_datum_new == PenaltyDatum {
            service_reference_tokenname,
            subscriber_reference_tokenname,
          }
        let penalty_value_correct =
          quantity_of(
            payment_output_value,
            penalty_fee_policyid,
            penalty_fee_assetname,
          ) >= penalty_fee
        and {
          user_token_at_input?,
          reference_correct?,
          service_token_correct?,
          payment_token_correct?,
          payment_output_address_correct?,
          payment_output_datum_correct?,
          penalty_value_correct?,
        }
      }
    }
    Penalty(_) -> False
  }
}

// spending validator
pub fn validate_subscriber_withdraw(
  own_reference: OutputReference,
  service_policy_id: PolicyId,
  account_policy_id: PolicyId,
  service_ref_input_index: Int,
  subscriber_input_index: Int,
  payment_input_index: Int,
  datum: PaymentValidatorDatum,
  reference_inputs: List<Input>,
  inputs: List<Input>,
  mint: Value,
) -> Bool {
  let service_reference_tokenname, subscriber_reference_tokenname <-
    fn(return) {
      when datum is {
        Payment(payment_datum) -> {
          let PaymentDatum {
            service_reference_tokenname,
            subscriber_reference_tokenname,
            ..
          } = payment_datum
          return(service_reference_tokenname, subscriber_reference_tokenname)
        }
        Penalty(penalty_datum) -> {
          let PenaltyDatum {
            service_reference_tokenname,
            subscriber_reference_tokenname,
          } = penalty_datum
          return(service_reference_tokenname, subscriber_reference_tokenname)
        }
      }
    }

  expect Some(Input { output: Output { value: subscriber_input_value, .. }, .. }) =
    list.at(inputs, subscriber_input_index)
  let user_token_name =
    common_utils.convert_ref_tn_to_user(subscriber_reference_tokenname)
  let user_token_at_input =
    quantity_of(subscriber_input_value, account_policy_id, user_token_name) == 1

  expect Some(Input {
    output: Output { address: payment_addr, value: payment_input_value, .. },
    output_reference: payment_input_reference,
  }) = list.at(inputs, payment_input_index)
  let reference_correct = payment_input_reference == own_reference
  let payment_script_credential = payment_addr.payment_credential
  expect Script(own_policy) = payment_script_credential

  let payment_token_correct =
    quantity_of(payment_input_value, own_policy, payment_tokenname) == 1

  expect Some(Input {
    output: Output {
      value: service_ref_input_value,
      datum: InlineDatum(service_ref_input_datum),
      ..
    },
    ..
  }) = list.at(reference_inputs, service_ref_input_index)
  let service_token_correct =
    quantity_of(
      service_ref_input_value,
      service_policy_id,
      service_reference_tokenname,
    ) == 1
  expect service_datum: ServiceDatum = service_ref_input_datum
  let service_is_inactive = !service_datum.is_active

  let payment_token_burnt =
    quantity_of(mint, own_policy, payment_tokenname) == -1

  and {
    user_token_at_input?,
    reference_correct?,
    payment_token_correct?,
    service_token_correct?,
    service_is_inactive?,
    payment_token_burnt?,
  }
}
