use aiken/transaction.{Mint, ScriptContext, Spend, Transaction}
use aiken/transaction/value
use payment_subscription/common/types.{
  Extend, InitSubscripton, MerchantWithdraw, MintPayment, PaymentValidatorDatum,
  SpendPayment, SubscriberWithdraw, TerminateSubscription, Unsubscribe,
}
use payment_subscription/payment_multi_validator/validation.{
  validate_extend_subscription, validate_initial_subscription,
  validate_merchant_withdraw, validate_subscriber_withdraw,
  validate_terminate_subscription, validate_unsubscribe,
}

validator(service_policy_id: ByteArray, account_policy_id: ByteArray) {
  fn mint_payment(redeemer: MintPayment, ctx: ScriptContext) -> Bool {
    let ScriptContext { transaction: tx, purpose } = ctx
    expect Mint(own_policy) = purpose
    let Transaction {
      inputs,
      reference_inputs,
      outputs,
      mint,
      validity_range,
      ..
    } = tx

    let minted_value = mint |> value.from_minted_value()

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
          inputs,
          reference_inputs,
          outputs,
          minted_value,
          validity_range,
        )?

      TerminateSubscription ->
        validate_terminate_subscription(own_policy, minted_value)
    }
  }

  fn spend_payment(
    datum: PaymentValidatorDatum,
    redeemer: SpendPayment,
    ctx: ScriptContext,
  ) -> Bool {
    let ScriptContext { transaction: tx, purpose } = ctx
    expect Spend(output_reference) = purpose
    let Transaction {
      inputs,
      reference_inputs,
      outputs,
      mint,
      validity_range,
      ..
    } = tx
    let minted_value = mint |> value.from_minted_value()

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
          inputs,
          reference_inputs,
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
          inputs,
          reference_inputs,
          outputs,
          validity_range,
          minted_value,
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
          inputs,
          reference_inputs,
          outputs,
          validity_range,
          minted_value,
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
          inputs,
          reference_inputs,
          minted_value,
        )
    }
  }
}
