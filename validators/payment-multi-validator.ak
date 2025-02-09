use aiken/transaction.{Mint, ScriptContext, Spend, Transaction}
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
    let Transaction { .. } = tx

    when redeemer is {
      InitSubscripton { output_reference, input_index } ->
        // Ensure this outref is spent in this transaction

        validate_initial_subscription(
          own_policy,
          account_policy_id,
          service_policy_id,
          output_reference,
          input_index,
          tx,
        )?

      TerminateSubscription { .. } ->
        validate_terminate_subscription(own_policy, tx)
    }
  }

  fn spend_payment(
    datum: PaymentValidatorDatum,
    redeemer: SpendPayment,
    ctx: ScriptContext,
  ) -> Bool {
    let ScriptContext { transaction: tx, purpose } = ctx
    expect Spend(output_reference) = purpose

    when redeemer is {
      Extend { payment_input_index, .. } ->
        validate_extend_subscription(
          output_reference,
          service_policy_id,
          datum,
          payment_input_index,
          tx,
        )
      MerchantWithdraw { merchant_input_index, payment_input_index } ->
        validate_merchant_withdraw(
          output_reference,
          service_policy_id,
          datum,
          merchant_input_index,
          payment_input_index,
          tx,
        )
      Unsubscribe { subscriber_input_index, payment_input_index } ->
        validate_unsubscribe(
          output_reference,
          account_policy_id,
          datum,
          subscriber_input_index,
          payment_input_index,
          tx,
        )
      SubscriberWithdraw { subscriber_input_index, payment_input_index } ->
        validate_subscriber_withdraw(
          output_reference,
          service_policy_id,
          account_policy_id,
          datum,
          subscriber_input_index,
          payment_input_index,
          tx,
        )
    }
  }
}
