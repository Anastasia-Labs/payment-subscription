import { MintingPolicy, SpendingValidator } from "@lucid-evolution/lucid";

import blueprint from "../../plutus.json" assert { type: "json" };

export type Validators = {
    redeem: SpendingValidator;
    gitfCard: MintingPolicy;
};

export function readValidators(): Validators {
    const redeem = blueprint.validators.find((v) =>
        v.title === "oneshot.redeem"
    );

    if (!redeem) {
        throw new Error("Redeem validator not found");
    }

    const gitfCard = blueprint.validators.find(
        (v) => v.title === "oneshot.gift_card",
    );

    if (!gitfCard) {
        throw new Error("Mint NFT validator not found");
    }

    return {
        redeem: {
            type: "PlutusV2",
            script: redeem.compiledCode,
        },
        gitfCard: {
            type: "PlutusV2",
            script: gitfCard.compiledCode,
        },
    };
}
