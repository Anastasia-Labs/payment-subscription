use aiken/cbor
use aiken/list
use aiken/transaction.{Mint, ScriptContext, Transaction}
use aiken/transaction/value.{from_minted_value}
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
    let Transaction { inputs, mint, outputs, .. } = tx

    let minted_tokens = mint |> from_minted_value()

    let CreateService { output_reference, input_index } = r
    expect Some(input) = list.at(inputs, input_index)
    trace @" CreateService output_reference:"
    trace cbor.diagnostic(output_reference)

    // let OutputReference { transaction_id, output_index } = output_reference
    validate_create_service(
      own_policy,
      input,
      minted_tokens,
      output_reference,
      outputs,
    )
  }

  fn spend_service(
    datum: ServiceDatum,
    rdmr: SpendService,
    ctx: ScriptContext,
  ) -> Bool {
    let ScriptContext { transaction: tx, .. } = ctx

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
}
