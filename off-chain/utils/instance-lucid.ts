import {
  generatePrivateKey,
  Lucid,
  Maestro,
  makeWalletFromPrivateKey,
  SpendingValidator,
  validatorToAddress,
  Wallet,
} from "@lucid-evolution/lucid";

// const lucid = await createLucidInstance();

export async function createLucidInstance(): Promise<Lucid> {
  const maestroToken = Deno.env.get("MAESTRO_TOKEN")!;
  // const mTok = process.env.MAESTRO_TOKEN;

  // console.log("DotEnv", mTok);

  const maestro = new Maestro({
    network: "Preprod",
    apiKey: maestroToken,
    // turboSubmit: false,
  });

  console.log("Maestro: ", maestroToken);
  return await Lucid(maestro, "Preprod");
}

// Function to generate and save private keys for
export async function generateAndSavePrivateKeys(walletName: string) {
  const privateKey = await generatePrivateKey();
  const filename = `../assets/${walletName.toLowerCase()}-pk`;

  await Deno.writeTextFile(filename, privateKey);
  console.log(`${walletName} private key saved on ${filename}`);
  return privateKey;
}

// Function to check wallet assets
export async function checkWalletsAssets(lucid: Lucid, walletName: string) {
  const lucidI = await loadWalletInstance(lucid, walletName);

  console.log(`${walletName}'s address:\n`, await lucidI.wallet().address());
  console.log(`${walletName}'s utxos:\n`, await lucidI.wallet().getUtxos());
  console.log("\n");
  return lucidI.wallet;
}

export async function loadWalletInstance(lucid: Lucid, walletName: string) {
  try {
    const privateKey = await Deno.readTextFile(
      `../assets/${walletName.toLowerCase()}-pk`,
    );

    await lucid.selectWallet.fromPrivateKey(privateKey);

    console.log("loadWalletInstance: ", lucid.wallet().address());

    // const wallet: Wallet = await makeWalletFromPrivateKey(
    //   lucid.config().provider,
    //   "Preprod",
    //   privateKey,
    // );

    return lucid;
  } catch (error) {
    console.error("Error:", error);
  }
}

export async function generateVerificationKey(
  lucid: Lucid,
  walletName: string,
) {
  const filename = `../assets/${walletName.toLowerCase()}-vk`;
  const wallet = await loadWalletInstance(lucid, walletName);

  // Generate the verification key
  const verificationKey = await wallet.verificationKey();

  // Save the verification key to a file
  await Deno.writeTextFile(filename, verificationKey);

  console.log("Verification key generated and saved to file.");
}

export async function checkValidatorAssets(
  lucid: Lucid,
  validatorName: string,
) {
  try {
    const plutusJSON = JSON.parse(await Deno.readTextFile("../plutus.json"));

    // NOTE: Use hard coded validator in production
    const validator: SpendingValidator = {
      type: "PlutusV2",
      script: plutusJSON.validators.filter((val: any) =>
        val.title == validatorName
      )[0].compiledCode,
    };

    // Query utxos at vesting validator
    const validatorAddr = await validatorToAddress("Preprod", validator);
    const utxos = await lucid.utxosAt(validatorAddr);
    console.log(`\nValidator: ${validatorName}`);
    console.log("Address:", validatorAddr);
    console.log("UTXOs:", utxos);
  } catch (error) {
    console.error("Error:", error);
  }
}

export async function checkAllValidators(lucid: Lucid) {
  try {
    const plutusJSON = JSON.parse(await Deno.readTextFile("../plutus.json"));

    for (const validatorData of plutusJSON.validators) {
      const validator: SpendingValidator = {
        type: "PlutusV2",
        script: validatorData.compiledCode,
      };

      const validatorAddr = await validatorToAddress("Preprod", validator);
      const utxos = await lucid.utxosAt(validatorAddr);
      console.log(`\nValidator: ${validatorData.title}`);
      console.log("Address:", validatorAddr);
      console.log("UTXOs:", utxos, "\n");
    }
  } catch (error) {
    console.error("Error:", error);
  }
}
