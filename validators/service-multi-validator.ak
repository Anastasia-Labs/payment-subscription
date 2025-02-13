use cardano/assets.{PolicyId}
use cardano/transaction.{OutputReference, Transaction}
use payment_subscription/common/types.{
  CreateService, RemoveService, ServiceDatum, SpendService, UpdateService,
}
use payment_subscription/service_multi_validator/validation.{
  validate_create_service, validate_remove_service, validate_update_service,
}

validator service {
  mint(r: CreateService, own_policy: PolicyId, tx: Transaction) {
    let Transaction { inputs, outputs, mint, .. } = tx

    let CreateService { input_index, service_output_index } = r

    validate_create_service(
      own_policy,
      input_index,
      service_output_index,
      mint,
      inputs,
      outputs,
    )
  }

  spend(
    datum_option: Option<ServiceDatum>,
    rdmr: SpendService,
    own_reference: OutputReference,
    tx: Transaction,
  ) {
    let Transaction { inputs, outputs, .. } = tx
    expect Some(datum) = datum_option

    when rdmr is {
      UpdateService {
        service_ref_token_name,
        merchant_input_index,
        service_input_index,
        service_output_index,
      } ->
        validate_update_service(
          own_reference,
          datum,
          service_ref_token_name,
          merchant_input_index,
          service_input_index,
          service_output_index,
          inputs,
          outputs,
        )?

      RemoveService {
        service_ref_token_name,
        merchant_input_index,
        service_input_index,
        service_output_index,
      } ->
        validate_remove_service(
          own_reference,
          datum,
          service_ref_token_name,
          merchant_input_index,
          service_input_index,
          service_output_index,
          inputs,
          outputs,
        )?
    }
  }

  else(_) {
    fail
  }
}
