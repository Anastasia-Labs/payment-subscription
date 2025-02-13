use aiken/collection/list
use payment_subscription/common/types.{Installment, PaymentDatum, ServiceDatum}

pub fn validate_initial_payment_against_service(
  payment: PaymentDatum,
  service: ServiceDatum,
  current_time_estimate: Int,
) -> Bool {
  let PaymentDatum {
    subscription_start,
    subscription_end,
    original_subscription_end,
    installments,
    ..
  } = payment
  let ServiceDatum { num_intervals, interval_length, service_fee, .. } = service
  let start_correct = subscription_start >= current_time_estimate
  let end_correct =
    subscription_end - subscription_start == num_intervals * interval_length
  let original_end_correct = original_subscription_end == subscription_end
  let installments_correct =
    list.foldr(
      installments,
      subscription_end,
      fn(i, end) {
        let Installment { claimable_at, claimable_amount } = i
        let installment_correct =
          claimable_at == end && claimable_amount == service_fee
        if installment_correct {
          end - interval_length
        } else {
          -1
        }
      },
    ) == subscription_start
  and {
    start_correct?,
    end_correct?,
    original_end_correct?,
    installments_correct?,
  }
}

pub fn validate_extension_datum(
  payment_old: PaymentDatum,
  payment_new: PaymentDatum,
  service: ServiceDatum,
  additional_amount: Int,
  additional_intervals: Int,
) -> Bool {
  let input_sane = additional_amount > 0 && additional_intervals > 0

  let PaymentDatum {
    service_reference_tokenname,
    subscriber_reference_tokenname,
    subscription_start,
    subscription_end,
    original_subscription_end,
    installments: installments_old,
  } = payment_old
  let PaymentDatum { installments: installments_new, .. } = payment_new
  let ServiceDatum { interval_length, service_fee, .. } = service

  let subscription_end_expected =
    subscription_end + additional_intervals * interval_length
  let payment_new_correct =
    payment_new == PaymentDatum {
      service_reference_tokenname,
      subscriber_reference_tokenname,
      subscription_start,
      subscription_end: subscription_end_expected,
      original_subscription_end,
      installments: installments_new,
    }

  let additional_amount_correct =
    additional_amount >= additional_intervals * service_fee

  let installments_additional =
    list.drop(installments_new, list.length(installments_old))
  let installments_new_correct =
    list.foldr(
      installments_additional,
      subscription_end_expected,
      fn(i, end) {
        let Installment { claimable_at, claimable_amount } = i
        let installment_correct =
          claimable_at == end && claimable_amount == service_fee
        if installment_correct {
          end - interval_length
        } else {
          -1
        }
      },
    ) == subscription_end

  and {
    input_sane?,
    payment_new_correct?,
    additional_amount_correct?,
    installments_new_correct?,
  }
}
