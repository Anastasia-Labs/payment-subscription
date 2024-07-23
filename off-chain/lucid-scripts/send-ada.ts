import { lucid } from "../utils/instance-lucid.ts";
import { Data } from "./lucid/mod.ts";

// const aliceAddrress = await lucid.wallet.address();

const bobPK = await Deno.readTextFile("./assets/bob-pk");
lucid.selectWalletFromPrivateKey(bobPK);
const bobAddrress = await lucid.wallet.address();

const alicePK = await Deno.readTextFile("./assets/alice-pk");
lucid.selectWalletFromPrivateKey(alicePK);
const utxos = await lucid.wallet.getUtxos();

console.log("utxos:.." + utxos);

const tx = await lucid.newTx()
  .collectFrom([utxos[0]])
  .payToAddress(bobAddrress, { lovelace: 4000000000n })
  .complete();

const signedTx = await tx.sign().complete();
const txHash = await signedTx.submit();

console.log("Transaction submitted with id:", txHash);
