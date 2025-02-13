use aiken/crypto.{Hash, Sha2_256}
use cardano/assets.{AssetName, PolicyId}

// Account

pub type AccountDatum {
  email_hash: Hash<ByteArray, Sha2_256>,
  phone_hash: Hash<ByteArray, Sha2_256>,
}

pub type MintAccount {
  CreateAccount { input_index: Int, output_index: Int }
  DeleteAccount { reference_token_name: AssetName }
}

pub type SpendAccount {
  UpdateAccount {
    reference_token_name: AssetName,
    user_input_index: Int,
    account_input_index: Int,
    account_output_index: Int,
  }
  RemoveAccount {
    reference_token_name: AssetName,
    user_input_index: Int,
    account_input_index: Int,
  }
}

// Payment

pub type Installment {
  claimable_at: Int,
  claimable_amount: Int,
}

pub type PaymentDatum {
  service_reference_tokenname: AssetName,
  subscriber_reference_tokenname: AssetName,
  subscription_start: Int,
  subscription_end: Int,
  original_subscription_end: Int,
  installments: List<Installment>,
}

pub type PenaltyDatum {
  service_reference_tokenname: AssetName,
  subscriber_reference_tokenname: AssetName,
}

pub type PaymentValidatorDatum {
  Payment(PaymentDatum)
  Penalty(PenaltyDatum)
}

pub type MintPayment {
  InitSubscripton {
    service_ref_input_index: Int,
    subscriber_input_index: Int,
    payment_output_index: Int,
  }
  TerminateSubscription
}

pub type SpendPayment {
  Extend {
    service_ref_input_index: Int,
    payment_input_index: Int,
    payment_output_index: Int,
    additional_intervals: Int,
  }
  MerchantWithdraw {
    service_ref_input_index: Int,
    merchant_input_index: Int,
    payment_input_index: Int,
    payment_output_index: Int,
    installments_withdrawn: Int,
  }
  Unsubscribe {
    service_ref_input_index: Int,
    subscriber_input_index: Int,
    payment_input_index: Int,
    penalty_output_index: Int,
  }
  SubscriberWithdraw {
    service_ref_input_index: Int,
    subscriber_input_index: Int,
    payment_input_index: Int,
  }
}

// Service

pub type ServiceDatum {
  service_fee_policyid: PolicyId,
  service_fee_assetname: AssetName,
  service_fee: Int,
  penalty_fee_policyid: PolicyId,
  penalty_fee_assetname: AssetName,
  penalty_fee: Int,
  interval_length: Int,
  num_intervals: Int,
  is_active: Bool,
}

pub type CreateService {
  input_index: Int,
  service_output_index: Int,
}

pub type SpendService {
  UpdateService {
    service_ref_token_name: AssetName,
    merchant_input_index: Int,
    service_input_index: Int,
    service_output_index: Int,
  }
  RemoveService {
    service_ref_token_name: AssetName,
    merchant_input_index: Int,
    service_input_index: Int,
    service_output_index: Int,
  }
}
