use cardano/assets.{PolicyId}
use cardano/transaction.{OutputReference, Transaction}
use payment_subscription/common/types.{
  CreateService, RemoveService, ServiceDatum, SpendService, UpdateService,
}
use payment_subscription/service_multi_validator/validation.{
  validate_create_service, validate_remove_service, validate_update_service,
}

// This validator script handles minting and spending of service NFTs
validator service {
  // Minting function: handles creation and deletion of service NFTs
  mint(r: CreateService, policy_id: PolicyId, self: Transaction) {
    let CreateService { output_reference, input_index } = r

    validate_create_service(policy_id, output_reference, input_index, self)
  }

  spend(
    datum: Option<ServiceDatum>,
    rdmr: SpendService,
    _own_ref: OutputReference,
    tx: Transaction,
  ) {
    when rdmr is {
      UpdateService { merchant_input_index, service_input_index } ->
        validate_update_service(
          datum,
          merchant_input_index,
          service_input_index,
          tx,
        )?

      // Convert the Service from active to inactive.
      RemoveService { merchant_input_index, service_input_index } ->
        validate_remove_service(
          datum,
          merchant_input_index,
          service_input_index,
          tx,
        )?
    }
  }

  else(_) {
    fail
  }
}
