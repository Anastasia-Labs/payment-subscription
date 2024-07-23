import {
  checkWalletsAssets,
  createLucidInstance,
  loadWalletInstance,
} from "../utils/instance-lucid.ts";
import {
  applyDoubleCborEncoding,
  applyParamsToScript,
  Constr,
  Data,
  fromText,
  mintingPolicyToId,
  SpendingValidator,
} from "@lucid-evolution/lucid";

const lucid = await createLucidInstance();

const wallet = await checkWalletsAssets(lucid, "Alice");
// Query UTxOs
const address = await wallet().address();
const utxos = await wallet().getUtxos();

console.log("Addr: ", address);

if (utxos.length < 1) {
  console.log("UTxOs NOT found at:", address);
  Deno.exit(0);
}
const utxo = utxos[0];
const outRef = new Constr(0, [
  new Constr(0, [utxo.txHash]),
  BigInt(utxo.outputIndex),
]); // Not sure why we're not using this parameter

const tokenName: string = "ABC-NFT";
const plutusJSON = JSON.parse(await Deno.readTextFile("../plutus.json"));
const script: SpendingValidator = {
  type: "PlutusV2",
  script: applyParamsToScript(
    plutusJSON.validators.filter((val: any) => val.title == "mint.mint_nft")[0]
      .compiledCode,
    [outRef, fromText(tokenName)],
  ),
};

console.log("Script: ", script.script);
const policy = mintingPolicyToId(script);
const token = policy + fromText(tokenName);

const mintRedeemer = Data.to(new Constr(0, []));

console.log("UTxO to be consumed:", utxo);
try {
  const tx = await lucid
    .newTx()
    .mintAssets({ [token]: 1n }, mintRedeemer)
    // .collectFrom([utxo])
    .attach.MintingPolicy(script);
  // .complete();

  console.log("Are we here?");

  // const completed = await (await tx.complete()).complete();
  // console.log(completed.toCBOR());
  const completed = await tx.complete();

  const txSigned = await completed.sign
    .withPrivateKey()
    .complete();
  const txHash = await txSigned.submit();

  console.log("Transaction Hash", txHash);

  // //  Sign the transaction
  // const signedTx = await tx.sign().complete();
  // // Submit transaction
  // const txHash = await signedTx.submit();
  // console.log("Transaction submitted with id:", txHash);
} catch (error) {
  console.log("Error:", error.stack);
}
