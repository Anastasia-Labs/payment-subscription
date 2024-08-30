# Payment Subscription Smart Contract

## Overview

The Payment Subscription Smart Contract is developed using Aiken and is designed
to facilitate automated recurring payments between subscribers and merchants on
the Cardano blockchain. This contract enables users to seamlessly set up,
manage, and cancel their subscriptions directly from their wallets. It ensures
secure and efficient transactions by automating the payment of subscription
fees, updating service metadata, and handling cancellations, all within a
decentralized framework.

## Design Documentation

For a comprehensive understanding of the contract's architecture, design
decisions, and implementation details, please refer to the
[Design Documentation](https://github.com/Anastasia-Labs/payment-subscription/blob/service-multi-validator/docs/payment-subscription-design-specs/subscription-smart-contract.pdf).
This documentation provides in-depth insights into the contract's design,
including its components, and detailed explanations of its functionality.

## Contract Functionality

### Service Contract

A multi-validator is responsible for creating an initial service by minting a
single CIP-68 compliant Service NFT asset and sending it to the user, while also
sending the reference NFT to the spending endpoint. It also updates the metadata
for the user and deletes the service by burning the Service NFT.

### Account Contract

A multi-validator is responsible for creating an account for the user by minting
a CIP-68 compliant Account NFT asset and sending it to the user, while also
sending the reference NFT to the spending endpoint. It also updates the metadata
for the account and deletes the user account by burning the Account NFT.

### Payment Contract

This is the core validator. It is responsible for holding prepaid subscription
fees for a service, renewing a subscription, unsubscribing from a service, and
withdrawing subscription fees. The contract incorporates a linear vesting
mechanism to gradually release subscription fees to the merchant over the
subscription period.

## Getting Started

### Prerequisites

Before you can deploy and test this payment subscription contract, ensure that
you have the Aiken compiler installed to write and compile your contract. Follow
the
[Aiken installation instructions](https://aiken-lang.org/installation-instructions)
to get started.

### Building and developing

Follow these steps to compile the project and run the included tests:

1. **Clone the repository and navigate into the directory:**

   ```bash
   git clone https://github.com/Anastasia-Labs/payment-subscription
   cd payment-subscription
   ```

2. **Run the build command to compile all functions and execute the unit
   tests:**

   ```bash
   aiken build
   ```

## Testing

Several test cases for each contract are provided to ensure the contract behaves
as expected:

### Test cases for Service Multi Validator

1. **`success_create_service`**: Tests the successful creation of a new service.
   This involves minting new tokens, setting up the initial service datum, and
   creating the necessary outputs to establish the service. The test ensures
   that the service is correctly initialized with the appropriate token values
   and service details, and validates that the tokens are minted and outputs are
   prepared as expected.

2. **`success_delete_service`**: Tests the successful deletion of an existing
   service. This includes burning the associated service tokens, updating the
   service datum to reflect the removal, and ensuring that the service is
   properly deleted from the contract. The test verifies that tokens are burned
   correctly, inputs are processed, and the final state of the contract reflects
   the service deletion.

3. **`success_update_service`**: Tests the successful update of an existing
   service. This scenario involves modifying the service details, such as the
   service fee and subscription period, and updating the service datum
   accordingly. The test ensures that the service is updated correctly, tokens
   are managed properly, and the new service details are reflected in the
   contract.

4. **`success_remove_service`**: Tests the successful removal of a service from
   the contract. This involves burning the service tokens and updating the
   contract state to reflect the removal. The test ensures that tokens are
   removed as expected, inputs and outputs are correctly handled, and the
   contract state is updated to indicate that the service has been removed.

### Test cases for Account Multi Validator

1. `succeed_create_account`: Tests the successful creation of a new user
   account. This involves minting a CIP-68 compliant Account NFT and sending it
   to the user while also sending the reference NFT to the spending endpoint.
   The test ensures that the tokens are minted as expected, the outputs are
   correctly prepared, and the transaction reflects the creation of a new
   account with the provided details.

2. `succeed_delete_account`: Tests the successful deletion of an existing user
   account. This involves burning the Account NFT tokens and updating the
   contract state to reflect the account’s removal. The test verifies that the
   tokens are removed as expected, the inputs and outputs are correctly handled,
   and the contract state is updated to indicate that the account has been
   deleted.

3. `succeed_update_account`: Tests the successful update of an existing user
   account. This involves updating the account details while ensuring that the
   Account NFT tokens are managed correctly. The test checks that the account
   details are updated as expected, the inputs and outputs are accurately
   handled, and the contract reflects the updated account information.

4. `succeed_remove_account`: Tests the successful removal of a user account.
   This involves burning the Account NFT tokens and updating the contract state
   to reflect the removal of the account. The test ensures that the tokens are
   burned as expected, inputs and outputs are processed correctly, and the
   contract state is updated to show that the account has been removed.

### Test cases for Payment Multi Validator

<!-- //TODO - update after review -->

1. **`succeed_initiate_subscription`**: This test includes setting up a
   subscription with payment, creating the required datum and redeemer, and
   ensuring that the subscription is correctly recorded in the contract. It
   involves preparing inputs and outputs for the transaction and confirming that
   the subscription is successfully initiated.

2. **`succeed_terminate_subscription`**: This scenario covers the case where a
   subscription is terminated before its end date. It involves calculating and
   distributing the refund and penalty fees based on the elapsed subscription
   time and ensuring that the contract correctly reflects the termination and
   payment of fees.

3. **`succeed_extend_subscription`**: Tests the successful extension of an
   existing subscription. This scenario involves updating the subscription end
   date and adjusting the payment and datum to reflect the extended period. The
   test ensures that the contract properly accommodates the extension and that
   the subscription details are updated accordingly.

4. **`succeed_unsubscribe`**: This test covers the scenario where a user
   unsubscribes before the end of the subscription period, including handling
   any remaining funds, refunds, or penalties. It verifies that the contract
   correctly processes the unsubscription and updates the state to reflect the
   change.

5. **`succeed_withdraw`**: Tests the successful withdrawal of subscription fees
   partway through the subscription period. The test involves calculating the
   withdrawable amount based on elapsed time, preparing transaction inputs and
   outputs, and ensuring that the funds are correctly withdrawn and recorded.
   The focus is on verifying that the withdrawal process works as intended.

### Running Tests

We have prepared comprehensive test cases. For detailed evidence and to view the
test cases associated with these criteria, please refer to the
[Test Documentation](https://github.com/Anastasia-Labs/payment-subscription/blob/service-multi-validator/lib/payment-subscription/tests/README.md)

To run all tests, simply do:

```sh
aiken check
```

Each test case is designed to validate specific aspects of the multi-signature
contract,To run only specific tests, do:

```sh
aiken check -m `test_case_function_name`
```
