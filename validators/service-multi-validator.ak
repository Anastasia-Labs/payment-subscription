use aiken/transaction.{Mint, ScriptContext, Spend, Transaction}
use aiken/transaction/value
use payment_subscription/common/types.{
  CreateService, RemoveService, ServiceDatum, SpendService, UpdateService,
}
use payment_subscription/service_multi_validator/validation.{
  validate_create_service, validate_remove_service, validate_update_service,
}

// This validator script handles minting and spending of service NFTs
validator {
  // Minting function: handles creation and deletion of service NFTs
  fn mint_service(r: CreateService, ctx: ScriptContext) -> Bool {
    let ScriptContext { transaction: tx, purpose } = ctx
    expect Mint(own_policy) = purpose
    let Transaction { inputs, outputs, mint, .. } = tx

    let CreateService { output_reference, input_index, service_output_index } =
      r

    validate_create_service(
      own_policy,
      output_reference,
      input_index,
      service_output_index,
      mint |> value.from_minted_value(),
      inputs,
      outputs,
    )
  }

  fn spend_service(
    datum: ServiceDatum,
    rdmr: SpendService,
    ctx: ScriptContext,
  ) -> Bool {
    let ScriptContext { transaction: tx, purpose } = ctx
    expect Spend(own_reference) = purpose
    let Transaction { inputs, outputs, .. } = tx

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
}
