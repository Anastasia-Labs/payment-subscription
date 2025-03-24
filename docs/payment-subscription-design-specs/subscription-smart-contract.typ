#let image-background = image("../images/background-1.jpg", height: 100%, fit: "cover")
#let image-foreground = image("../images/Logo-Anastasia-Labs-V-Color02.png", width: 100%, fit: "contain")
#let image-header = image("../images/Logo-Anastasia-Labs-V-Color01.png", height: 75%, fit: "contain")
#let fund-link = link("https://projectcatalyst.io/funds/10/f10-osde-open-source-dev-ecosystem/anastasia-labs-the-trifecta-of-data-structures-merkle-trees-tries-and-linked-lists-for-cutting-edge-contracts")[Catalyst Proposal]
#let git-link = link("https://github.com/Anastasia-Labs/data-structures")[Main Github Repo]

#set page(
  background: image-background,
  paper :"a4",
  margin: (left : 20mm,right : 20mm,top : 40mm,bottom : 30mm)
)

// Set default text style
#set text(15pt, font: "Barlow")

#v(3cm) // Add vertical space

#align(center)[
  #box(
    width: 60%,
    stroke: none,
    image-foreground,
  )
]

#v(1cm) // Add vertical space

// Set text style for the report title
#set text(22pt, fill: white)

// Center-align the report title
#align(center)[#strong[Payment Subscription Smart Contract]]
#set text(20pt, fill: white)
#align(center)[#strong[Design Specification]]

#v(5cm)

// Set text style for project details
#set text(13pt, fill: white)


// Reset text style to default
#set text(fill: luma(0%))

// Display project details
#show link: underline
#set terms(separator:[: ],hanging-indent: 18mm)

#set par(justify: true)
#set page(
  paper: "a4",
  margin: (left: 20mm, right: 20mm, top: 40mm, bottom: 35mm),
  background: none,
  header: [
    #align(right)[
      #image("../images/Logo-Anastasia-Labs-V-Color01.png", width: 25%, fit: "contain")
    ]
    #v(-0.5cm)
    #line(length: 100%, stroke: 0.5pt)
  ],
)

#v(20mm)
#show link: underline
#show outline.entry.where(level: 1): it => {
  v(6mm, weak: true)
  strong(it)
}

#outline(depth:3, indent: 1em)
#pagebreak()
#set text(size: 11pt)  // Reset text size to 10pt
#set page(
   footer: [
    #line(length: 100%, stroke: 0.5pt)
    #v(-3mm)
    #align(center)[ 
      #set text(size: 11pt, fill: black)
      *Anastasia Labs – *
      #set text(size: 11pt, fill: gray)
      *Payment Subscription Smart Contract*
      #v(-3mm)
      Project Design Specification
      #v(-3mm)
    ]
    #v(-6mm)
    #align(right)[
      #context counter(page).display( "1/1",both: true)]
  ] 
)

// Initialize page counter
#counter(page).update(1)
#v(100pt)
// Display project details
#set terms(separator:[: ],hanging-indent: 18mm)
#align(center)[
  #set text(size: 20pt)
  #strong[Payment Subscription Smart Contract]]
#v(20pt)
\

#set heading(numbering: "1.")
#show heading: set text(rgb("#c41112"))

= Overview
\

This Payment Subscription Smart Contract is developed using Aiken. It is designed to facilitate automated recurring payments between subscribers and merchants on the Cardano blockchain. This contract empowers users to seamlessly set up, manage, and cancel their subscriptions directly from their wallets. It ensures secure and efficient transactions by automating the process of paying subscription fees, updating service metadata, and handling cancellations, all within a decentralized framework.

#pagebreak()
\
= Architecture

\
#figure(
  image("./images/payment-subscription-architecture.png", width: 100%),
  caption: [Payment Subscription Architecture],
)
\

There are three contracts in this subscription system.

+ *Service Contract* 
  
  A validator responsible for creating an initial service by minting a single CIP-68 compliant Service NFT Asset and sending it to the user while sending the reference NFT to the spending endpoint. It also allows the wallet address with the user(merchant) NFT to update the metadata as well as deactivate the service.

+ *Account Contract*
  
  A validator responsible for creating an account for the user by minting a CIP-68 compliant Account NFT Asset and sending it to the user, while sending the reference NFT to the Account contract address. It also alows the wallet address containing the user(subscriber) NFT to update the metadata for the Account and deletes the user account by burning the Account NFTs.

+ *Payment Contract*
  
  This is the core validator. The validator responsible for holding the prepaid subscription fees for a service, renewing a subscription to a service, unsubscribing from a service and withdrawing subscription fees. The contract incorporates a linear vesting mechanism to gradually release subscription fees to the merchant over a subscriber specified subscription period.

#pagebreak()

\
= Specification

\
== System Actors
\ 
+ *Merchant*
  
  This is the entity who interacts with the Service Contract to create a service and receive subscription payments for the respective service(s). A user becomes a merchant when they mint and receive a Service NFT in their wallet.

+ *Subscriber*

  This is the entity who interacts with the Account Contract to create an account and deposit prepaid subscription fees to the Payment Contract. A user becomes a subscriber when they mint an Account NFT and lock funds to the Payment Contract.
\
== Tokens
\
+ *Service NFT*

  Can only be minted by a user when creating a service and burned when the user deletes their service(s) from the system.

  - *TokenName:* Defined in Service validator while creating a Service with the transaction ID and the output index and prefix for the specific token i.e prefix_100 for the reference NFT and prefix_222 for the user NFT.

+ *Account NFT:*

  Can only be minted by a user when creating an account for the subscription system and burned when the user deletes their account from the system. A check must be included to verify that there are no payments in the Payment Contract before burning.

  - *TokenName:* Defined in Account validator while creating an Account with the transaction ID and the output index and prefix for the specific token i.e prefix_100 for the reference NFT and prefix_222 for the user NFT.

+ *Payment NFT:* 

  Can only be minted when a subscription fee is paid to the Payment Contract and burned when a subscriber exits the system.

  - *TokenName:* Defined in Payment validator with a static string i.e. "payment-subscription".

#pagebreak()

\
== Smart Contracts
\
=== Payment Multi-validator
\
The Payment Contract is responsible for managing the prepaid subscription fees, validating subscriptions, and ensuring the proper distribution of these fees over the subscription period given the *`installments`*. It facilitates the creation, extension, and cancellation of subscriptions, allowing both subscribers and merchants to interact with the contract in a secure and automated manner. This contract ensures that subscription payments are correctly handled and that any penalties for early cancellation may be appropriately enforced.

\
==== Parameters
\
- *`service_policy_id`* : Hash of the PolicyId

- *`account_policy_id`* : Hash of the PolicyId
\

==== Minting Purpose
\
===== Redeemer
\
- *```rust
  InitSubscripton {
    service_ref_input_index: Int,
    subscriber_input_index: Int,
    payment_output_index: Int,
  }
  ```*

- *```rs 
  TerminateSubscription
  ```*

\
===== Validation
\
+ *InitSubscripton* 
  
  The redeemer allows creating of a new subscription  by minting only one unique Payment Token.

  - A reference input must provide the Service datum from the Service Contract.

  - The subscriber’s transaction input must contain the correct Account NFT (derived from the subscriber reference token name).
  - The payment output must be sent to the Payment Script’s address and contain a Payment datum that is consistent with the Service datum.
  - Exactly one Payment Token (with token name "subscription") is minted.



  - Ensure that the User NFT doesn't go to the Script
  - Ensure Payment token goes back to the script
  \

+ *TerminateSubscription*
  
  - The redeemer must burn exactly one Payment Token (i.e. a single token with the token name "subscription" is burned).

\

==== Spend Purpose
\
==== Datum
\
This is a Sum type datum where one represents the payment datum and the other one represents a penalty datum.

\
===== Payment datum <payment-datum>
\
- *`service_reference_tokenname`: ```rs AssetName```* – Links to the Service Contract.

- *`subscriber_reference_tokenname`: ```rs AssetName```* – Identifies the subscriber’s Account NFT.
- *`subscription_start`: ```rs Int```*  – The start time of the subscription.
- *`subscription_end`: ```rs Int```*  – The current expiry time of the subscription.
- *`original_subscription_end`:* The originally agreed subscription end time.
- *`installments`:* List of Installment – Each installment specifies when and how much of the fee becomes withdrawable.

  - *`Installment`*:
    - *`claimable_at` : ```rs Int```*  – Time after which the installment can be claimed.
    - *`claimable_amount` : ```rs Int```*  – The amount available for withdrawal at that time.


===== Penalty datum <penalty-datum>

\
- *`service_reference_tokenname`: ```rs AssetName```* – Links to the Service Contract.

- *`subscriber_reference_tokenname`: ```rs AssetName```* – Identifies the subscriber’s Account 

\
==== Redeemer

\
- *```rust 
  Extend {
    service_ref_input_index: Int,
    payment_input_index: Int,
    payment_output_index: Int,
    additional_intervals: Int,
  }
  ```*

- *```rust 
  MerchantWithdraw {
    service_ref_input_index: Int,
    merchant_input_index: Int,
    payment_input_index: Int,
    payment_output_index: Int,
    installments_withdrawn: Int,
  }
  ```*

- *```rust
  Unsubscribe {
    service_ref_input_index: Int,
    subscriber_input_index: Int,
    payment_input_index: Int,
    penalty_output_index: Int,
  }
  ```*
- *```rust
  SubscriberWithdraw {
    service_ref_input_index: Int,
    subscriber_input_index: Int,
    payment_input_index: Int,
  } 
  ```*

\
==== Validation

\
+ *Extend* 
  
  This redeemer/ endpoint will allow anyone to increase the subscription funds by locking the funds in the Payment Contract. 

  - The Payment UTxO being extended must be identified by its output reference matching the provided reference.

  - A Service datum must be supplied as a reference input (at *`service_ref_input_index`*), ensuring that the Service NFT (using the *`service_reference_tokenname`*) is present.

  - The output UTxO (at payment_output_index) must remain at the Payment Script’s address and include an updated Payment datum.

  - The new Payment datum is validated by comparing it with the current Payment datum to check that the additional locked funds correspond to the specified *`additional_intervals`*.

  \
+ *MerchantWithdraw* 

  The redeemer has two variants based on the datum. It allow anyone with a merchant to withdraw funds from the Payment UTxO or Penalty UTxO of their Service depending on the respective Payment and Penalty datums. 

    \
  + *Payment*

    - The merchant must provide an input (at *`merchant_input_index`)* that proves ownership of the Service NFT (derived from the *`service_reference_tokenname`*).

    - The Payment UTxO (from payment_input_index) must have a valid Payment datum which is validated against the service datum passed from *`service_reference_tokenname`*
    - Implement linear vesting for fund release by:

      - Dropping the first *`installments_withdrawn`* elements from the original installments list to form the new Payment datum.
      
      - Verifying that the difference in the service fee value (calculated from the UTxO’s value) between the input and output does not exceed the sum of the *`claimable_amount`* of installments that are past their *`claimable_at`* time.

    - The output UTxO (at *`payment_output_index`*) must be sent to the Payment Script’s address.
    \
  + *Penalty*

    - If a penalty is being applied, the Payment Token must be burned (verified by checking that the mint value includes a burn of one token with the specific Payment NFT token name).

    - The merchant must similarly prove ownership of the Service NFT in one of the inputs ( *`merchant_input_index`*).

  \
+ *Unsubscribe* 

  The redeemer will allow anyone with an Account NFT to spend an Account UTxO to unlock funds back to their address.
 
  - The subscriber must provide an input (at *`subscriber_input_index`*) containing the appropriate Account NFT.

  - The Payment UTxO being spent (from *`payment_input_index`*) must carry a valid Payment datum.

  - A Service datum is provided as a reference input to verify service conditions.

    - The decision branch is based on the subscription’s timing:

      - *Without Penalty:* If the current time is past the *`original_subscription_end`* or if the Service is inactive, the Payment Token is burned.

      - *With Penalty:* If unsubscribing early (active service), the transaction must produce an output (at penalty_output_index) carrying a Penalty datum. This output must include at least the minimum penalty fee as defined by the Service datum.

  \
+ *SubscriberWithdraw* 
  
  The redeemer will allow anyone with an Account NFT to withdraw funds from the Payment validator. 

    - The subscriber’s input (at subscriber_input_index) must contain the correct Account NFT.
    
    - The Payment UTxO (from payment_input_index) must have a valid Payment datum.

    - The Service datum (from the reference input at service_ref_input_index) must indicate that the Service is inactive.

    - The Payment Token is burned (ensuring exactly one token with token name "subscription" is burned).  

#pagebreak()

=== Service Validator
\
The Service Multi-validator is responsible for, creating, updating and removing a service.

==== Parameter
\
Nothing

\
==== Minting Purpose

===== Redeemer
\
- CreateService
\
===== Validation
\
+ *CreateService* 

  The redeemer allows creating of a new subscription sevice by minting only one unique CIP-68 compliant Service Token.

    - An input (at *`input_index`*) must be present to derive unique token names (using CIP68 prefixes).

    - Validate that exactly one Reference Token and one User Token are minted as per the CIP68 compliance standards.
    - The unique tokens are derived from the transaction ID and output index of the input.
    - The output at *`service_output_index`* must be sent to the Service Script’s address.
    - The output must contain a Service datum with the following requirements:

      - *service_fee*: Must be greater than 0.
      - *penalty_fee*: Must be ≥ 0.
      - *interval_length*: Must be greater than 0.
      - *num_intervals*: Must be > 0 and within a reasonable bound (e.g. ≤ 100).
      - *is_active*: Must be set to true. 

\

==== Spend Purpose
\
===== Datum <service-datum>
\

  - *`service_fee_policyid: PolicyId`* The PolicyId governing the asset used for the service fee.
  - *`service_fee_assetname: AssetName`* The AssetName of the service fee.
  - *`service_fee: Int`* An Int representing the fee amount for the service.
  - *`penalty_fee_policyid: PolicyId`* The PolicyId governing the asset used for the penalty fee.
  - *`penalty_fee_assetname: AssetName`* The AssetName of the penalty fee.
  - *`penalty_fee: Int`* An Int representing the fee deducted when a subscriber cancels early.
  - *`interval_length: Int`* An Int defining the duration of one subscription interval.
  - *`num_intervals: Int`* An Int representing the total number of intervals in the subscription period.
  - *`is_active: Bool`* A Bool indicating whether the service is active.
  
*Note:* Subscription fees can be based on length of period the subscriber pays for e.g. If they pay for one month, the fees are more than if they pay for 12 months. This introduces the need for a `min_sub_period`.

\

===== Redeemer
\
-  *```rust
  UpdateService {
    service_ref_token_name: AssetName,
    merchant_input_index: Int,
    service_input_index: Int,
    service_output_index: Int,
  }
  ```*
  

- *```rust
  RemoveService {
    service_ref_token_name: AssetName,
    merchant_input_index: Int,
    service_input_index: Int,
    service_output_index: Int,
  }
  ```*
\
====== Validation
\
+ *UpdateService*

  This redeemer endpoint allows anyone to update the metadata attached to a Service UTxO.

  - A Service UTxO containing the Service NFT must be provided (at service_input_index) with its output reference matching the provided reference.

  - A merchant input (at merchant_input_index) must be present to prove ownership of the Service NFT (derived from service_ref_token_name).
  - The output at service_output_index must be sent to the Service Script’s address and must include an updated Service datum.
  - Validate that the metadata of the Reference NFT token is updated within acceptable bounds.
  - Metadata changes must be within acceptable bounds (for example, service fee adjustments limited to within +/-10%).
  - The reference token must be spent back to its own address, ensuring that the Service NFT remains intact.

  \
+ *RemoveService*

  This redeemer endpoint allows a merchant to remove a service from the subscription system.


  - The transaction must include two script inputs:

    - One input containing the Service UTxO with the Service NFT (at *`service_input_index`*).

    - A merchant input (at *`merchant_input_index`*) proving ownership of the Service NFT.

  - Two script outputs must be produced, with one of them (at *`service_output_index`*) sent to the Service Script’s address.
  - The output Service datum must indicate that the service is inactivated by setting is_active to false.
  - The Service NFT must still be present in the output to maintain correct state tracking.

#pagebreak()

=== Account Validator

\
The Account Multi-validator handles the creation, update, and removal of subscriber accounts.

\
==== Parameter
\  
Nothing

\
==== Minting Purpose

===== Redeemer
\
- *```rust 
  CreateAccount { input_index: Int, output_index: Int }
  ```*

- *```rust 
  DeleteAccount { reference_token_name: AssetName }
  ```*

\
====== Validation
\
+ *CreateAccount*
  
  The redeemer allows creating of a new subscription service account by minting only one unique CIP-68 compliant Account Token.

  - An input must be present to derive unique token names using CIP68 prefixes.

  - Validate that exactly one Account Reference Token and one Account User Token are minted and the unique tokens are generated from the transaction’s ID and output index.
  - Ensure the output (at* `output_index`*) must be sent to the Account Script’s address and must carry an Account datum.
  - Ensure the datum includes valid account detail:

    - *`email_hash`:* Must be 32 bytes long, or

    - *`phone_hash`:* Must be 32 bytes long.  
  - The User NFT must not be sent to the script.
  - The Reference NFT must be preserved at the script address.

  \
+ *DeleteAccount*

  This redeemer endpoint allows for the removal of a subscriber account by burning the associated Account Tokens.

  _A Check That there's no payment for the delete account should be done off-chain._

  - Validate that the redeemer only burns one Account Reference Token and one Account User Token.

  - There should be no remaining account-related tokens in the transaction after burning.

\

==== Spend Purpose

===== Datum <account-datum>
\
- *`email_hash: Hash<ByteArray, Sha2_256>`:* A hash (using Sha2_256) of the subscriber’s email as a ByteArray. This must be exactly 32 bytes long.

- *`phone_hash: Hash<ByteArray, Sha2_256>`:* A hash (using Sha2_256) of the subscriber’s phone number as a ByteArray. This must also be exactly 32 bytes long.
\
===== Redeemer
\
- *```rust
  UpdateAccount {
    reference_token_name: AssetName,
    user_input_index: Int,
    account_input_index: Int,
    account_output_index: Int,
  }
  ```*

- *```rust
  RemoveAccount {
    reference_token_name: AssetName,
    user_input_index: Int,
    account_input_index: Int,
  }
  ```*

\
====== Validation
\
+ *UpdateAccount*

  This redeemer endpoint allows a subscriber to update the metadata attached to an Account UTxO.

  - Validate that an Account UTxO containing the Account NFT must be present in the inputs (at *`account_input_index`*).

  - A user input (at *`user_input_index`*) must include the Account User Token, proving ownership.
  - The output (at *`account_output_index`*) must be sent to the Account Script’s address and it must carry an updated Account datum.
  - The updated Account datum must satisfy metadata validation, ensuring that contact details remain correctly formatted.
  - The Reference NFT must be forwarded correctly to the spending endpoint. 
  
  \
+ *RemoveAccount*
  
  The redeemer allows the removal of an account by a subscriber from the subscription system. 
  
  _Must Check That there's no ADA in the payment UTxO in the off-chain code._
 
  - The transaction must include an Account UTxO (at *`account_input_index`*) containing the Account NFT.

  - A user input (at *`user_input_index`*) must be present to prove ownership via the Account User Token.

  - The redeemer must burn the Account Reference NFT, which is validated by confirming that the minted value includes a burn (i.e. a negative quantity) for the reference token.

#pagebreak()

= Transactions
\
This section outlines the various transactions involved in the Payment Subscription Smart Contract on the Cardano blockchain.

\
== Service Validator
\
=== Mint :: CreateService
\
This transaction creates a new service by minting a Merchant NFT. This transaction is performed by the merchant to indicate that a new service is available.

\
#figure(
  image("./images/create-service-image.png", width: 100%),
  caption: [Create Service UTxO diagram]
)

\
==== Inputs
\
  + *Merchant Wallet UTxO.*
    - Address: Merchant’s wallet address

    - Value:

      - Minimum ADA

      - Any ADA required for the transaction.
\
==== Mints
\
  + *Service Multi-validator*
    - Redeemer: CreateService

    - Value: 

      - +1 Service NFT Asset

      - +1 Reference NFT Asset
\
==== Outputs
\
  + *Merchant Wallet UTxO:*

    - Address: Merchant wallet address

      - minimum ADA

      - 1 Service NFT Asset
  
  + *Service Validator UTxO:*

    - Address: Service Multi-validator Address (Mint)
    - Datum:

      - *`service_fee_policyid: PolicyId`* The PolicyId governing the asset used for the service fee.
      - *`service_fee_assetname: AssetName`* The AssetName of the service fee.
      - *`service_fee: Int`* An Int representing the fee amount for the service.
      - *`penalty_fee_policyid: PolicyId`* The PolicyId governing the asset used for the penalty fee.
      - *`penalty_fee_assetname: AssetName`* The AssetName of the penalty fee.
      - *`penalty_fee: Int`* An Int representing the fee deducted when a subscriber cancels early.
      - *`interval_length: Int`* An Int defining the duration of one subscription interval.
      - *`num_intervals: Int`* An Int representing the total number of intervals in the subscription period.
      - *`is_active: Bool`* A Bool indicating whether the service is active.
    
    - Value:     

      - 1 Service Reference NFT Asset
#pagebreak()

  === Spend :: UpdateService
\

This transaction updates the metadata attached to the UTxO at the script address in accordance with CIP-68 standards. It consumes both the Service NFT and the Service Reference NFT, then sends the updated Service NFT to the user's wallet and the updated Reference NFT to the spending endpoint.

\
#figure(
  image("./images/update-metadata-image.png", width: 100%),
  caption: [Update Service MetaData UTxO diagram]
)
\

==== Inputs
\
  + *Merchant Wallet UTxO*

    - Address: Merchant’s wallet address

    - Value:
    
      - Minimum ADA

      - 1 Service NFT Asset

  + *Service Validator UTxO*

    - Address: Service validator script address

    - Datum:

      - existing_metadata: listed in @service-datum
.
    - Value:

      - Minimum ADA

      - 1 Reference NFT Asset
\
==== Outputs
\
  + *Merchant Wallet UTxO*
    - Address: Merchant wallet address

    - Datum:
      - updated_metadata: New metadata for the subscription.
    - Value:

      - Minimum ADA

      - 1 Service NFT Asset

  + *Service Validator UTxO:*
    - Address: Service validator script address

    - Datum:
      - updated_metadata: New metadata for the subscription    
    - Value:

      - Minimum ADA

      - 1 Reference NFT Asset

#pagebreak()

=== Spend :: RemoveService
  \

  This transaction spends the Reference UTxO and the Service NFT to remove a service from the system.

  \
  #figure(
  image("./images/remove-service-image-01.png", width: 100%),
  caption: [Remove Service UTxO diagram]
  )
  \

==== Inputs
\
   + *Merchant Wallet UTxO*

    - Address: Merchant’s wallet address

    - Value:

      - Minimum ADA

      - 1 Service NFT Asset

  + *Service Validator UTxO*

    - Address: Service validator script address

    - Datum:

      - service_metadata: Current metadata listed in @service-datum.
      - is_active: True

    - Value:

      - Minimum ADA

      - 1 Reference NFT Asset
\
==== Outputs
\
  + *Merchant Wallet UTxO*

    - Address: Merchant wallet address

    - Value: 

      - Minimum ADA

      - 1 Service NFT Asset

+ *Service Validator UTxO*

    - Address: Service validator script address

    - Datum:

      - service_metadata: Current metadata listed in @service-datum.

      - is_active: False

    - Value:

      - Minimum ADA

      - 1 Reference NFT Asset
#pagebreak()


== Account Validator
\
=== Mint :: CreateAccount
\
This endpoint mints a new subscription NFT for a subscriber, establishing a new subscription account.

\
 #figure(
  image("./images/create-account-image.png", width: 100%),
  caption: [Create Account UTxO diagram],
)
\

==== Inputs
\
  + *Subscriber Wallet UTxO.*
    - Address: Subscriber’s wallet address

    - Value:

      - Minimum ADA

      - Any additional ADA required for the transaction
\
==== Mints
\
  + *Account Multi-validator*

    - Redeemer: CreateAccount
    
    - Value:

      - +1 Account NFT Asset

      - +1 Reference NFT Asset
\
==== Outputs
\
  + *Subscriber Wallet UTxO:*

    - Address: Subscriber wallet address

    - Value:

      - minimum ADA

      - 1 Account NFT Asset
  
  + *Account Validator UTxO:*

    - Address: Account validator script address

    - Datum:

      - *`email_hash: Hash<ByteArray, Sha2_256>`:* A hash (using Sha2_256) of the subscriber’s email as a ByteArray. This must be exactly 32 bytes long.
      - *`phone_hash: Hash<ByteArray, Sha2_256>`:* A hash (using Sha2_256) of the subscriber’s phone number as a ByteArray. This must also be exactly 32 bytes long.

    - Value:

      - 1 Reference NFT Asset
#pagebreak()
 
=== Mint :: DeleteAccount<delete-account>
\
This transaction allows a subscriber to burn an Account NFT, effectively removing the user from the subscription system. An off-chain check is required to ensure that there are no pending subscription fees in the Payment UTxO.

\
#figure(
  image("./images/delete-account-image.png", width: 100%),
  caption: [Delete Account UTxO diagram],
)
\

==== Inputs
\
  + *Subscriber Wallet UTxO*

    - Address: Subscriber’s wallet address

    - Value: 
        - Minimum ADA 

        - 1 Account NFT Asset

  + *Account Validator UTxO*

    - Address: Account Multi-validator script address

    - Datum:

      - account_details: Arbitrary ByteArray

    - Value: 

      - 1 Reference NFT Asset
\
==== Mints
\
  + *Account Validator*

    - Redeemer: DeleteAccount
    
    - Value:

      - -1 Account NFT Asset

      - -1 Reference NFT Asset
\
==== Outputs
\
  + *Subscriber Wallet UTxO*

    - Address: Subscriber’s wallet address

    - Value:

      - Remaining ADA and other tokens, if any
#pagebreak()


=== Spend :: UpdateAccount
\

This transaction updates the metadata attached to the Account UTxO at the script address. It consumes both the Account NFT and the Reference NFT, then sends the updated Subscriber NFT to the user's wallet and the updated Reference NFT to the spending endpoint. 

*Note:* The service provider must query UTxOs regularly to facilitate data sync when datum is updated

\
#figure(
  image("./images/update-subscriber-metadata.png", width: 100%),
  caption: [Update Account Metadata UTxO diagram],
)
\

==== Inputs
\
  + *Subscriber Wallet UTxO*

    - Address: Subscriber’s wallet address

    - Value:
     
      - Minimum ADA 

      - Account NFT Asset

  + *Account Validator UTxO*

    - Address: Account validator script addres

    - Datum:

      - existing_metadata: Current metadata listed in @account-datum.

    - Value: 

      - Minimum ADA

      - 1 Reference NFT Asset
\
==== Outputs
\
  + *Subscriber Wallet UTxO*
    - Address: Subscriber’s wallet address

    - Value:

      - Minimum ADA

      - 1 Account NFT Asset

  + *Account Validator UTxO*
    - Address: Account validator script address

    - Datum:

      - updated_metadata: updated metadata for the account listed in @account-datum

    - Value:

      - Minimum ADA

      - 1 Reference NFT Asset
#pagebreak()

== Payment Validator
\
=== Mint :: InitiateSubscription
\
This transaction occurs when a Subscriber locks funds in the Payment validator script address.

\
#figure(
  image("./images/initiate-subscription-image.png", width: 100%),
  caption: [Initiate Subscription UTxO diagram],
)
\

==== Inputs
\
  + *Subscriber Wallet UTxO*

    - Address: Subscriber’s wallet address

    - Value: 

      - 100 ADA: Amount of ADA to Add to the Payment Contract.

      - 1 Account NFT Asset

  + *Service Reference UTxO*

    - Address: Service Contract Address

    - Datum:

      - service_datum: listed in @service-datum

    - Value: 

      - 1 Service NFT Asset
      - Minimum Ada
\
==== Mints
\
  + *Payment Validator*
    - Redeemer: InitiateSubscription

    - Value: 

      - +1 Payment NFT Asset
      
\
==== Outputs
\
  + *Subscriber Wallet UTxO*

    - Address: Subscriber's wallet address

    - Value:

      - Change ADA

      - 1 Account NFT Asset

  + *Payment Validator UTxO*

    - Address: Payment validator script address

    - Datum: 
      - payment datum as listed in @payment-datum

    - Value:
    
      - 100 ADA: Subscription funds to be withdrawn by merchant

      - 1 Payment NFT Asset
#pagebreak()

=== Spend :: Extend
\
This transaction allows anyone to extend their subscription period by adding more funds to the Payment contract to cover additional time.

\
#figure(
  image("./images/extend-plan-image.png", width: 100%),
  caption: [Extend Plan UTxO diagram],
)
\

==== Inputs
\
  + *Subscriber Wallet UTxO*

    - Address: Subscriber’s wallet address

    - Value: 

      - 100 ADA: Amount of ADA to Add to the Contract to extend the payment plan 

  + *Payment Validator UTxO*

    - Address: Payment validator script address

    - Datum:
      - datum listed in @payment-datum

    - Value:

      - 10 ADA: Original amount of ADA before Extending

      - 1 Payment NFT Asset

  + *Service Reference UTxO*

    - Address: Service Contract Address

    - Datum:

      - service_datum: listed in @service-datum

    - Value: 

      - 1 Service NFT Asset
      - Minimum Ada
\
==== Outputs
\
  + *Subscriber Wallet UTxO*

    - Address: Subscriber’s wallet address

    - Value:
      - -100 ADA

  + *Payment Validator UTxO*

    - Address: Payment validator script address

    - Datum:

      - datum listed in @payment-datum + extended installments

    - Value:
    
      - 110 ADA: Increased ADA to cover the extended subscription period

      - 1 Payment NFT Asset

#pagebreak()

=== Spend :: Unsubscribe
\
This transaction allows the owner of an Account NFT to unsubscribe from a particular service by spending a Payment UTxO, unlocking the remainig pre-paid subscription fee to their own wallet address and creating a Penalty UTxO. 

\
#figure(
  image("./images/unsubscribe-image.png", width: 100%),
  caption: [Unsubscribe UTxO diagram],
)
\

==== Inputs
\
  + *Subscriber Wallet UTxO*

    - Address: Subscriber’s wallet address

    - Value: 

      - Minimum ADA 

      - 1 Account NFT Asset

  + *Payment Validator UTxO*

    - Address: Payment validator script address

    - Datum:

      - current_datum: Current payment metadata listed in @payment-datum

    - Value:

      - Minimum ADA

      - Reference NFT Asset

  + *Service Reference UTxO*

    - Address: Service Contract Address

    - Datum:

      - service_datum: listed in @service-datum

    - Value: 

      - 1 Service NFT Asset
      - Minimum Ada
\
==== Outputs
\
  + *Subscriber Wallet UTxO*

    - Address: Subscriber’s wallet address

    - Value:

      - Minimum ADA

      - Unspent portion of the subscription fee (minus any penalties)

      - 1 Account Token Asset

  + *Payment Validator UTxO*

    - Address: Payment validator script address

    - Datum:

      - penalty_datum: Metadata indicating the penalty for early unsubscription in @penalty-datum

    - Value:
    
      - Penalty ADA

      - Reference NFT Asset
#pagebreak()

=== Spend :: Merchant Withdraw
\
This transaction allows anyone with a Service NFT to unlock subscription funds from the Payment UTxO in repect to the specified subscription start and end dates.

\
#figure(
  image("./images/merchant-withdraw-image.png", width: 100%),
  caption: [Merchant Withdraw UTxO diagram],
)
\

==== Inputs:
\
+ *Merchant Wallet UTxO*

  - Address: Merchant’s wallet address
  - Value:

    - Minimum ADA

    - 1 Service NFT Asset

+ *Payment Validator UTxO*

  - Address: Payment validator script address

  - Datum:

    - payment_datum: listed in @payment-datum

  - Value:

    - Minimum ADA

    - 1 Payment NFT Asset

+ *Service Reference UTxO*

    - Address: Service Contract Address

    - Datum:

      - service_datum: listed in @service-datum

    - Value: 

      - 1 Service NFT Asset
      - Minimum Ada
\
==== Outputs:
\
+* Merchant Wallet UTxO*

  - Address: Merchant’s wallet address

  - Value:

    - Minimum ADA

    - Withdrawn subscription fee for the installment
    - 1 Service NFT Asset

+ *Payment Validator UTxO*

  - Address: Payment validator script address

  - Datum:

    - updated_datum: Metadata reflecting the withdrawal
  - Value:

    - Remaining ADA after withdrawal

    - 1 Payment NFT Asset
#pagebreak()


=== Spend :: Penalty Withdraw
\
This transaction allows anyone with a Service NFT to unlock penalty funds associated to the service from the Penalty UTxO, in turn burning the Payment NFT attached to the UTxO.

\
#figure(
  image("./images/penalty-withdraw-image.png", width: 100%),
  caption: [Penalty Withdraw UTxO diagram],
)
\

==== Inputs:
\
+ *Merchant Wallet UTxO*

  - Address: Merchant’s wallet address

  - Value:

    - Minimum ADA

    - Service NFT Asset

+ *Payment Validator UTxO*

  - Address: Payment validator script address

  - Penalty Datum: as @penalty-datum

  - Value:

    - Minimum ADA

    - Payment NFT Asset

  + *Service Reference UTxO*

    - Address: Service Contract Address

    - Datum:

      - service_datum: listed in @service-datum

    - Value: 

      - 1 Service NFT Asset
      - Minimum Ada
\
==== Mints
\
  + *Payment Validator*
    - Redeemer: TerminateSubscription

    - Value: 

      - -1 Payment NFT Asset

\
==== Outputs:
\
+ *Merchant Wallet UTxO*

  - Address: Merchant’s wallet address

  - Value:

    - Minimum ADA

    - Withdrawn subscription fee for the installment
    
    - Service NFT Asset

+ *Payment Validator UTxO*

  - Address: Payment validator script address

  - Value:

    - Remaining ADA after withdrawal


=== Spend :: Subscriber Withdraw
\
This transaction allows anyone with an Accoun NFT to unlock subscription funds from the Payment UTxO only if the status in the ServiceDatum is inactive.

\
#figure(
  image("./images/subscriber-withdraw.png", width: 100%),
  caption: [Subscriber Withdraw UTxO diagram],
)
\

==== Inputs:
\
+ *Subscriber Wallet UTxO*

  - Address: Subscriber’s wallet address

  - Value:

    - ADA

    - Account NFT Asset

+ *Payment Validator UTxO*

  - Address: Payment validator script address

  - Payment Datum:

    - existing_datum 
    
  - Value:

    - Subscription ADA

    - Payment NFT Asset

+ *Service Reference UTxO*

    - Address: Service Contract Address

    - Datum:

      - service_datum: listed in @service-datum

    - Value: 

      - 1 Service NFT Asset
      - Minimum Ada
\

==== Outputs:
\
+ *Subscriber Wallet UTxO*

  - Address: Subscriber’s wallet address

  - Value:

    - Withdrawn Subscription ADA
    
    - Account NFT Asset

+ *Payment Validator UTxO*

  - Address: Payment validator script address

  - Payment Datum:

    - existing_datum

  - Value:

    - Remaining ADA after subscriber withdrawal




// Additional Features

// - A subscriber funds, should be associated with his own staking credentials so that he can get staking rewards even if funds are locked in the contract.

// Update the Datums for the Service in diagrams.

// TODO:(V2) Multiplier for the Discount and the Penalty. The longer you pay, the less the penalty (Last).

// TODO:(V2) The service /service NFT should be deletable after a specified time period (after inactivation).
