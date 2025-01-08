use aiken/list
use aiken/transaction.{Input, Mint, Output, ScriptContext, Spend, Transaction}
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
    let ScriptContext { transaction: tx, purpose } = ctx

    expect Spend(output_reference) = purpose
    // Validate that Service UTxO with a Service NFT is being spent.
    expect Some(own_input) = transaction.find_input(tx.inputs, output_reference)

    let service_addr = own_input.output.address
    let ref_nft =
      own_input.output.value
        |> value.without_lovelace()

    when rdmr is {
      UpdateService -> validate_update_service(datum, service_addr, ref_nft, tx)

      // Convert the Service from active to inactive.
      RemoveService -> validate_remove_service(datum, service_addr, ref_nft, tx)
    }
  }
}
