use cardano/transaction.{InlineDatum, Output}

pub fn output_datum(output: Output) -> Data {
  when output.datum is {
    InlineDatum(outbound_datum) -> outbound_datum
    _ -> fail @"No Output Datum"
  }
}
