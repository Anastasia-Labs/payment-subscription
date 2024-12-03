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
  mint(r: MintPayment, policy_id: PolicyId, self: Transaction) {
    when r is {
      InitSubscripton { output_reference, input_index } ->
        // Ensure this outref is spent in this transaction

        validate_initial_subscription(
          policy_id,
          service_policy_id,
          account_policy_id,
          output_reference,
          input_index,
          self,
        )

      TerminateSubscription { merchant_input_index, payment_input_index } ->
        validate_terminate_subscription(
          policy_id,
          service_policy_id,
          merchant_input_index,
          payment_input_index,
          self,
        )
    }
  }

  spend(
    datum: Option<PaymentValidatorDatum>,
    redeemer: SpendPayment,
    _own_ref: OutputReference,
    self: Transaction,
  ) {
    when redeemer is {
      Extend { subscriber_input_index, payment_input_index } ->
        validate_extend_subscription(
          service_policy_id,
          account_policy_id,
          datum,
          subscriber_input_index,
          payment_input_index,
          self,
        )
      MerchantWithdraw { merchant_input_index, payment_input_index } ->
        validate_merchant_withdraw(
          service_policy_id,
          datum,
          merchant_input_index,
          payment_input_index,
          self,
        )
      Unsubscribe { subscriber_input_index, payment_input_index } ->
        validate_unsubscribe(
          service_policy_id,
          account_policy_id,
          datum,
          subscriber_input_index,
          payment_input_index,
          self,
        )
      SubscriberWithdraw { subscriber_input_index, payment_input_index } ->
        validate_subscriber_withdraw(
          service_policy_id,
          account_policy_id,
          datum,
          subscriber_input_index,
          payment_input_index,
          self,
        )
    }
  }

  else(_) {
    fail
  }
}
