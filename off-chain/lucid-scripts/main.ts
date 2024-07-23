import {
    checkAllValidators,
    checkValidatorAssets,
    checkWalletsAssets,
    createLucidInstance,
    generateAndSavePrivateKeys,
    generateVerificationKey,
} from "../utils/instance-lucid.ts";

async function main() {
    const args = Deno.args;

    if (args.length === 0) {
        console.log("Please provide a function to call: 'generate' or 'check'");
        return;
    }

    const command = args[0];

    const lucid = await createLucidInstance();
    if (command === "generate-Pkey") {
        if (args.length < 2) {
            console.log("Please provide a wallet name to generate.");
            return;
        }
        const walletName = args[1];
        await generateAndSavePrivateKeys(walletName);
        await checkWalletsAssets(lucid, walletName);
    } else if (command === "generate-Vkey") {
        if (args.length < 2) {
            console.log("Please provide at least one wallet name to check.");
            return;
        }
        for (let i = 1; i < args.length; i++) { // Start from index 1 to skip the "check" command
            const walletName = args[i];
            await generateVerificationKey(lucid, walletName);
        }
    } else if (command === "check-wallet") {
        if (args.length < 2) {
            console.log("Please provide at least one wallet name to check.");
            return;
        }
        for (let i = 1; i < args.length; i++) { // Start from index 1 to skip the "check" command
            const walletName = args[i];
            await checkWalletsAssets(lucid, walletName);
        }
    } else if (command === "check-validator") { // Add a new "validator" command
        if (args.length < 2) {
            await checkAllValidators(lucid);

            console.log(
                "Please provide a validator name to check a specific validator.",
            );
            return;
        }
        const validatorName = args[1];
        await checkValidatorAssets(lucid, validatorName);
    } else {
        console.log("Unknown command. Use 'generate' or 'check'.");
    }
}

main();
