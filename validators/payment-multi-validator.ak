use cardano/assets.{PolicyId}
use cardano/transaction.{OutputReference, Transaction}
use payment_subscription/common/types.{
  Extend, InitSubscripton, MerchantWithdraw, MintPayment, PaymentValidatorDatum,
  SpendPayment, SubscriberWithdraw, TerminateSubscription, Unsubscribe,
}
use payment_subscription/payment_multi_validator/validation.{
  validate_extend_subscription, validate_initial_subscription,
  validate_merchant_withdraw, validate_subscriber_withdraw,
  validate_terminate_subscription, validate_unsubscribe,
}

validator payment(service_policy_id: ByteArray, account_policy_id: ByteArray) {
  mint(redeemer: MintPayment, own_policy: PolicyId, tx: Transaction) {
    let Transaction {
      inputs,
      reference_inputs,
      outputs,
      mint,
      validity_range,
      ..
    } = tx

    when redeemer is {
      InitSubscripton {
        service_ref_input_index,
        subscriber_input_index,
        payment_output_index,
      } ->
        validate_initial_subscription(
          own_policy,
          service_policy_id,
          account_policy_id,
          service_ref_input_index,
          subscriber_input_index,
          payment_output_index,
          reference_inputs,
          inputs,
          outputs,
          mint,
          validity_range,
        )?

      TerminateSubscription -> validate_terminate_subscription(own_policy, mint)
    }
  }

  spend(
    datum_option: Option<PaymentValidatorDatum>,
    redeemer: SpendPayment,
    output_reference: OutputReference,
    tx: Transaction,
  ) {
    expect Some(datum) = datum_option
    let Transaction {
      inputs,
      reference_inputs,
      outputs,
      mint,
      validity_range,
      ..
    } = tx

    when redeemer is {
      Extend {
        service_ref_input_index,
        payment_input_index,
        payment_output_index,
        additional_intervals,
      } ->
        validate_extend_subscription(
          output_reference,
          service_policy_id,
          service_ref_input_index,
          payment_input_index,
          payment_output_index,
          additional_intervals,
          datum,
          reference_inputs,
          inputs,
          outputs,
        )
      MerchantWithdraw {
        service_ref_input_index,
        merchant_input_index,
        payment_input_index,
        payment_output_index,
        installments_withdrawn,
      } ->
        validate_merchant_withdraw(
          output_reference,
          service_policy_id,
          service_ref_input_index,
          merchant_input_index,
          payment_input_index,
          payment_output_index,
          installments_withdrawn,
          datum,
          reference_inputs,
          inputs,
          outputs,
          validity_range,
          mint,
        )
      Unsubscribe {
        service_ref_input_index,
        subscriber_input_index,
        payment_input_index,
        penalty_output_index,
      } ->
        validate_unsubscribe(
          output_reference,
          account_policy_id,
          service_policy_id,
          service_ref_input_index,
          subscriber_input_index,
          payment_input_index,
          penalty_output_index,
          datum,
          reference_inputs,
          inputs,
          outputs,
          validity_range,
          mint,
        )
      SubscriberWithdraw {
        service_ref_input_index,
        subscriber_input_index,
        payment_input_index,
      } ->
        validate_subscriber_withdraw(
          output_reference,
          service_policy_id,
          account_policy_id,
          service_ref_input_index,
          subscriber_input_index,
          payment_input_index,
          datum,
          reference_inputs,
          inputs,
          mint,
        )
    }
  }

  else(_) {
    fail
  }
}
