#let image-background = image("./images/background-1.jpg", height: 100%, fit: "cover")
#let image-foreground = image("./images/Logo-Anastasia-Labs-V-Color02.png", width: 100%, fit: "contain")
#let image-header = image("./images/Logo-Anastasia-Labs-V-Color01.png", height: 75%, fit: "contain")
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
#set text(20pt, fill: white)

// Center-align the report title
#align(center)[#strong[Project Design Specification]]

#v(5cm)

// Set text style for project details
#set text(13pt, fill: white)

// Display project details
#table(
  columns: 2,
  stroke: none,
  [*Project Number*], [1000013],
  [*Project manager*], [Philip DiSarro],
  [*Date Started*], [February 24, 2024],
  [*Date Completed*], [...],
)

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
      #image("./images/Logo-Anastasia-Labs-V-Color01.png", width: 25%, fit: "contain")
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
      #counter(page).display( "1/1",both: true)]
  ] 
)

// Initialize page counter
#counter(page).update(1)

// Display project details
#set terms(separator:[: ],hanging-indent: 18mm)
#align(center)[
  #set text(size: 20pt)
  #strong[Payment Subscription Smart Contract]]
#v(10pt)

#set heading(numbering: "1.")

= Overview
\

This Payment Subscription Smart Contract is developed using Aiken to facilitate automated recurring payments between Subscribers and Merchants on the Cardano blockchain. This smart contract enables users to set up, manage, and cancel subscriptions directly from their wallets.

= Architecture

\
#figure(
  image("./images/payment-subscription-architecture.png", width: 100%),
  caption: [Payment Subscription Architecture],
)
\

There are three contracts in this subscription system.

- *Merchant Contract:* A multi-validator responsible for creating an initial service by minting a single CIP-68 compliant MerchantNFT and sending it to the merchant while sending the reference NFT to the spending end point. It also updates the metadata for the merchant and deletes the service by burning the MerchantNFT.

- *Subscriber Contract:* A multi-validator responsible for creating the initial subscription to a service by minting a SubscriberNFT and sending it to the user, while sending the reference NFT to the spending endpoint. It also updates the metadata for the subscriber and deletes the user account by burning a SubscriberNFT.

- *Payments Contract:* Responsible for holding the prepaid subscription fees for a service, renewing a subscription to a service, unsubscribing from a service and withdrawing subscription fees. The contract incorporates a linear vesting mechanism to gradually release subscription fees to the merchant over the subscription period. This could also be a multi-validator to authenticate the UTxO.

= Specification

== System Actors
\ 
- *Merchant:* An entity who interacts with the Merchant Contract in order to create a service and receives subscription payments for the respective service or services. A user becomes a merchant when they mint a Merchant NFT.

- *Subscriber:* An entity who interacts with the Subscriber Contract in order to create an account and deposit prepaid subscription fees to the Payments Contract. A user becomes a subscriber when they mint a Subscribe NFT.
\

== Tokens
\
- *Merchant NFT:* Can only be minted by a merchant when creating a subscription service and burned when merchant removes their service/services from the system. Datum is updated when a subscription is paid or the merchant withdraws from the Payments Contract.

 - TokenName: Defined in Merchant Multi-validator parameters with the hash of the Merchant Policy Id

- *Subscriber NFT:* Can only be minted when a subscription fee is paid to Payments Contract and burned when subscriber exits the system. Datum is updated when fees are deposited and withdrawn from Payments Contract.

 - TokenName: Defined in Subscriber Multi-validator parameters with hash of the Subscriber Policy Id
\

== Smart Contracts

=== Payments Validator
\
The Payments Contract is responsible for managing the prepaid subscription fees, validating subscriptions, and ensuring the proper distribution of these fees over the subscription period. It facilitates the creation, extension, and cancellation of subscriptions, allowing both subscribers and merchants to interact with the contract in a secure and automated manner. This contract ensures that subscription payments are correctly handled and that any penalties for early cancellation are appropriately enforced.

==== Parameters
\
- *`merchant_policy_id`* : Hash of the PolicyId
- *`subscriber_policy_id`* : Hash of the PolicyId

==== Datum

\
This is a Sum type datum where one represents the main datum and the other one represents a penalty datum.

===== Main datum
\
- *`merchant_nft_tn`:* Merchant's token name encoding UTxO to be consumed when minting the NFT.

- *`subscriber_nft_tn`:* Subscriber's token name encoding UTxO to be consumed when minting the NFT.
- *`subscription_fee`:* AssetClass type for the subscription fee.
- *`subscription_fee_qty`:* Amount of the subscription fee.
- *`subscription_start`:* Start of the subscription.
- *`subscription_end`:* Expiry time of the subscription.
- *`total_installments`:* The number of periodic intervals over which to release subscription fees.

===== Penalty datum
\
- *`merchant_nft_tn`:* Merchant's token name encoding UTxO to be consumed when minting the NFT.

==== Redeemer
\
- Extend

- Unsubscribe
- Withdraw

==== Validation
\
- *Extend:* The redeemer will allow anyone to increase the subscription funds. 

  - validate that the value of the UTxO is increased as long as the Datum is updated with the Merchant Token Name.

- *Unsubscribe:* The redeemer will allow anyone with a subscriberNFT to spend Subscribe UTxO to unlock funds back to their address.
 
  - validate the subscriberNFT is being spent.

  - validate that the penalty UTxO is being produced with the merchants Token Name.

- *Withdraw:* The redeemer will allow anyone with a merchantNFT to withdraw funds from the Payments contract 
 
  - validate merchantNFT is being spent

  - validate whether the transaction contains a penalty datum or a normal datum.
\

=== Merchant Multi-validator
\
Merchant Multi-validator is responsible for registering a service creating, updating and removing a service for a merchant.

==== Parameter
\
Nothing

==== Minting Purpose

===== Redeemer
\
- CreateService
- RemoveAccount


===== Validation
\
- *CreateService:* The redeemer allows creating of a new subscription sevice by minting only one unique Token.

  - validate that out_ref must be present in the Transaction Inputs

  - validate that the redeemer only mints a single CIP68 compliant merchant Token

- *RemoveAccount:*

  - validate that the redeemer only burns a single CIP68 compliant merchant NFT Token.
\

==== Spend Purpose

===== Datum
\
- `penalty_fee`: AssetClass type for the amount of fees to be deducted when subscriber cancels the subscription.
- `penalty_fee_qty`: Amount of the penalty fees.
- cip-68 requirements
\

===== Redeemer
\
- UpdateMetaData
- RemoveService

====== Validation
\
- *UpdateMetaData:* The redeemer allows for updating the metadata attached to the UTxO sitting at the script address. 

  - validate that merchantNFT is being spent.
  - updates the metadata of the Reference NFT token and sends the token to the spending end point

- *RemoveService:* The redeemer allows the removal of a service by a merchant from the subscription system. 

  - validate merchentNFT is being spent.
  - Removes all the Reference NFT tokens to another external address.
\

=== Subscriber Multi-validator

==== Parameter
\  
Nothing

==== Minting Purpose

===== Redeemer
\
- CreateAccount
- DeleteAccount

====== Validation
\
- *CreateAccount:* The redeemer allows creating of a new subscription service account by minting only one unique Token.

  - validate that out_ref must be present in the Transaction Inputs
  - validate that the redeemer only mints a single CIP68 compliant SubscriberNFT Token

- *DeleteAccount:*

  - validate that the redeemer only burns a single CIP68 compliant SubscriberNFT Token
\

==== Spend Purpose

===== Datum
\
- cip-68 requirements

===== Redeemer
\
- UpdateMetaData
- RemoveAccount

====== Validation
\
- *UpdateMetaData:* The redeemer allows for updating the metadata attached to the UTxO sitting at the script address. 

  - validate that SubscriberNFT is being spent.
  - updates the metadata of the Reference NFT token and sends the token to the spending end point. 

- *RemoveAccount:* The redeemer allows the removal of an account by a subscriber from the subscription system.  

  - validate that SubscriberNFT is being spent.
  - validate that unlocked funds are sent back to the subscriber address
  - validate that penalty is calculated accurately and fees are in the penalty UTxO
  - Removes all the Reference NFT tokens to athe spending endpoint.
\

= Transactions
\
This section outlines the various transactions involved in the Payment Subscription Smart Contract on the Cardano blockchain.


== Merchant Multi-validator

=== Mint :: CreateService
\
This transaction creates a new service by minting a Merchant NFT. This transaction is performed by the merchant to indicate that a new service is available.

\
#figure(
  image("./images/create-service-image.png", width: 100%),
  caption: [Create Service UTxO diagram],
)

\
==== Inputs
\
  + *Merchant Wallet UTxO.*
    - Address: Merchant’s wallet address

    - Value:

      - Minimum ADA
      - Any additional ADA required for the transaction //(see @out_ref of Merchant Multi-validator in Section 3.3.2.2.1)

==== Outputs
\
  + *Merchant Wallet UTxO:*

    - Address: Merchant wallet address
    - Datum:
    
      - *`merchant_nft_tn`:* Merchant's token name encoding UTxO to be consumed when minting the NFT.
      - *`subscription_fee`:* AssetClass type for the subscription fee.
      - *`subscription_fee_qty`:* Amount of the subscription fee.
      - *`penalty_fee`*: AssetClass type for the amount of funds to be deducted when subscriber cancels the subscription.
      - *`penalty_fee_qty`*: Amount of the penalty fees.

    - Value:

      - minimum ADA
      - 1 Merchant NFT Asset
  
  + *Merchant Validator UTxO:*

    - Address: Merchant Multi-validator Address (Mint)
    - Datum:

      - *`merchant_nft_tn`:* Merchant's token name encoding UTxO to be consumed when minting the NFT.
      - *`subscription_fee`:* AssetClass type for the subscription fee.
      - *`subscription_fee_qty`:* Amount of the subscription fee.
      - *`penalty_fee`*: AssetClass type for the amount of funds to be deducted when subscriber cancels the subscription.
      - *`penalty_fee_qty`*: Amount of the penalty fees.

    - Value:     
      - 1 Reference NFT Asset
\

  === Mint :: DeleteService
\
  This transaction deletes an existing service by burning the associated Merchant NFT by the merchant.
\

  #figure(
  image("./images/delete-service-image.png", width: 100%),
  caption: [Delete Service UTxO diagram],
)
\

==== Inputs
\
  + *Merchant Wallet UTxO* 

    - Address: Merchant’s wallet address

    - Value:

      - Minimum ADA
      - 1 Merchant NFT Asset

  + *Merchant Validator UTxO*

    - Address: Merchant validator script address

    - Value:

      - Minimum ADA
      - 1 Reference NFT Asset

==== Outputs
\
  + *Merchant Wallet UTxO*

    - Address: Merchant wallet address

    - Value: 
      - Minimum ADA (remaining after burning the NFT)
\

  === Spend :: UpdateMetaData
\

This transaction updates the metadata attached to the UTxO at the script address, in accordance with CIP-68 standards. It consumes both the Merchant NFT and the Reference NFT, then sends the updated Merchant NFT to the user's wallet and the updated Reference NFT to the spending endpoint.

\
#figure(
  image("./images/update-metadata-image.png", width: 100%),
  caption: [Update Merchant MetaData UTxO diagram],
)
\

==== Inputs
\
  + *Merchant Wallet UTxO*

    - Address: Merchant’s wallet address

    - Value:
    
      - Minimum ADA
      - Merchant NFT Asset

  + *Merchant Validator UTxO*

    - Address: Merchant validator script address

    - Datum:
      - existing_metadata: Current metadata for the service.
    - Value:

      - Minimum ADA
      - Reference NFT Asset

==== Outputs
\
  + *Merchant Wallet UTxO*
    - Address: Merchant wallet address

    - Datum:
      - updated_metadata: New metadata for the subscription.
    - Value:

      - Minimum ADA
      - Updated Merchant NFT Asset

  + *Merchant Validator UTxO:*
    - Address: Spending endpoint address

    - Datum:
      - updated_metadata: New metadata for the subscription.     
    - Value:

      - Minimum ADA
      - 1 Updated Reference Merchant NFT Asset

\
  === Spend :: RemoveService
  \

  This transaction spends the Reference UTxO with the Merchant NFT to remove the service.

  \
  #figure(
  image("./images/remove-service-image.png", width: 100%),
  caption: [Remove Service UTxO diagram],
)
\

==== Inputs
\
   + *Merchant Wallet UTxO*

    - Address: Merchant’s wallet address

    - Value:

      - Minimum ADA
      - Merchant NFT Asset

  + *Merchant Validator UTxO*

    - Address: Merchant validator script address
    - Datum:
      - service_metadata: Current metadata for the service.
    - Value:

      - Minimum ADA
      - Reference NFT Asset
      
==== Mints

  - Merchant Multi-validator

    - Redeemer: DeleteService
    - Value: 
      - -1 Merchant NFT Asset
      - -1 Reference NFT Asset

==== Outputs
\
  + *Merchant Wallet UTxO*

    - Address: Merchant wallet address

    - Value: 
      - Minimum ADA (remaining after burning the NFT)
\

== Subscriber Multi-validator

=== Mint :: CreateAccount
\
This endpoint mints a new subscription NFT for a subscriber, establishing a new subscription account. It transfers the subscription fee to the Payments Contract and provides the subscriber with a unique subscription token.

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
      - Any additional ADA required for the transaction //(see @out_ref of Subscriber Multi-validator in Section 3.3.2.2.1)

==== Outputs
\
  + *Subscriber Wallet UTxO:*

    - Address: Subscriber wallet address

    - Value:

      - minimum ADA
      - 1 Subscriber NFT Asset
  
  + *Subscriber Validator UTxO:*

    - Address: Merchant Multi-validator Address (Mint)

    - Datum:

      - *`subscription_token_name`:* Subscriber's token name encoding UTxO to be consumed when minting the NFT.
      - *`subscription_fee`:* AssetClass type for the subscription fee.
      - *`subscription_fee_qty`:* Amount of the subscription fee.
      - *`start_date:`* Subscription start date
      - *`end_date:`* Subscription end date

    - Value:
          
      - 1 Reference NFT Asset
\
=== Mint :: DeleteAccount
\

This endpoint burns the subscription NFT, effectively canceling the subscription. It deducts a penalty fee from the subscriber’s balance and transfers it to the merchant.

\
#figure(
  image("./images/delete-account-image.png", width: 100%),
  caption: [Delete Account UTxO diagram],
)
\

==== Inputs
\
  + *Subscriber UTxO*

    - Address: Subscriber’s wallet address
    - Value: 
        - Minimum ADA 
        - 1 Subscriber NFT Asset

  + *Subscriber Validator UTxO*

    - Address: Subscriber Multi-validator Address (Mint)

    - Datum:

      - subscriber_nft_tn: Subscriber's token name encoding UTxO to be consumed when burning the NFT.
      - subscription_fee: AssetClass type for the subscription fee.
      - subscription_fee_qty: Amount of the subscription fee.
      - penalty_fee: AssetClass type for the amount of funds to be deducted when - subscriber cancels the subscription.
      - penalty_fee_qty: Amount of the penalty fees.

    - Value: 

      - 1 Reference NFT Asset

==== Outputs
\
  + Subscriber Wallet UTxO:

    - Address: Subscriber’s wallet address

    - Value:
      - Minimum ADA
      // - Penalty fee amount
      
  + Change UTxO:

    Any remaining ADA or other tokens from the transaction inputs that are not used in the transaction are returned to the subscriber’s address as change.
\

=== Spend :: UpdateMetaData
\

This transaction updates the metadata attached to the subscriber UTxO at the script address. It consumes both the Subscriber NFT and the Reference NFT, then sends the updated Subscriber NFT to the user's wallet and the updated Reference NFT to the spending endpoint.


#figure(
  image("./images/update-subscriber-metadata.png", width: 100%),
  caption: [Update Subscriber Metadata UTxO diagram],
)
\

==== Inputs
\
  + *Subscriber UTxO*

    - Address: Subscriber’s wallet address

    - Value:
     
      - Minimum ADA 
      - Subscriber NFT Asset

  + *Subscriber Validator UTxO*

    - Address: Subscriber validator script addres

    - Datum:

      - existing_metadata: Current metadata for the Subscriber.

    - Value: 

      - Minimum ADA
      - 1 Reference NFT Asset

==== Outputs
\
  + *Subscriber UTxO*
    - Address: Subscriber’s wallet address

    - Datum:

      - updated_metadata: New metadata for the subscriber

    - Value:

      - Minimum ADA
      - Updated Subscriber NFT Asset

  + *Subscriber Validator UTxO*
    - Address: Subscriber validator script address

    - Datum:

      - updated_metadata: New metadata for the subscriber

    - Value:

      - Minimum ADA
      - Updated Reference NFT Asset

\
=== Spend :: RemoveAccount
\

This transaction effectively terminates the subscription and removes the subscriber's account from the system by consuming the Subscriber NFT and the Reference NFT. The inputs include a UTxO from the subscriber’s wallet containing the Subscriber NFT and a UTxO from the Merchant Multi-validator containing the Reference NFT and relevant metadata. The outputs return the minimum ADA to the merchant's wallet and any remaining ADA or other tokens to the subscriber’s wallet.

\
#figure(
  image("./images/remove-account-image.png", width: 100%),
  caption: [Remove Account Metadata UTxO diagram],
)
\

==== Inputs
\
  + *Subscriber Wallet UTxO*

    - Address: Subscriber’s wallet address
    - Value: 
      - Minimum ADA 
      - Subscriber NFT Asset

  + *Subscriber Policy UTxO*

  - Address: Merchant Multi-validator Address (Spend)

  - Datum:

    - merchant_nft_tn: Merchant’s token name encoding UTxO to be consumed when spending the NFT.
    - subscription_fee: AssetClass type for the subscription fee.
    - subscription_fee_qty: Amount of the subscription fee.
    - penalty_fee: AssetClass type for the amount of funds to be deducted when subscriber - cancels the subscription.
    - penalty_fee_qty: Amount of the penalty fees.

  - Value: 

    - Minimum ADA
    - 1 Reference NFT Asset

==== Outputs
\
  + *Merchant UTxO*

    - Address: Merchant’s wallet address

    - Value: 
      - Minimum ADA (remaining after burning the NFT)

  + *Subscriber Validator UTxO*

    - Address: Subscriber Validator address

    - Datum: None
    - Value:None
    
  + *Change UTxO*

    - Address: Subscriber’s wallet address

    - Value:
      - Remaining ADA and other tokens, if any
\

== Payments Validator

=== Spend :: Extend
\
This transaction allows subscribers to extend their subscription period by adding more funds to cover additional time.

==== Inputs
\
  + *Subscriber Wallet UTxO*

    - Address: Subscriber’s wallet address

    - Value: 

      - Minimum ADA 
      - Subscription Token Asset (if any additional ADA is required)

  + *Payments Validator UTxO*

    - Address: Payments validator script address

    - Datum:
      - current_datum: Current metadata for the subscription
    - Value:

      - Minimum ADA
      - Reference NFT Asset

==== Outputs
\
  + *Subscriber Wallet UTxO*

    - Address: Subscriber’s wallet address

    - Value:

      - Minimum ADA
      - Subscription Token Asset (if applicable)

  + *Payments Validator UTxO*

    - Address: Payments validator script address

    - Datum:
      - updated_datum: Updated metadata with extended subscription details
    - Value:
      - Increased ADA to cover the extended subscription period
      - Reference NFT Asset

=== Spend :: Unsubscribe

==== Inputs
\
  + *Subscriber Wallet UTxO*

    - Address: Subscriber’s wallet address

    - Value: 

      - Minimum ADA 
      - Subscriber NFT Asset

  + *Payments Validator UTxO*

    - Address: Payments validator script address

    - Datum:
      - current_datum: Current metadata for the subscription
    - Value:

      - Minimum ADA
      - Reference NFT Asset

==== Outputs
\
  + *Subscriber Wallet UTxO*

    - Address: Subscriber’s wallet address

    - Value:

      - Minimum ADA
      - Unspent portion of the subscription fee (minus any penalties)
      - Subscription Token Asset (if applicable)

  + *Payments Validator UTxO*

    - Address: Payments validator script address

    - Datum:
      - penalty_datum: Metadata indicating the penalty for early unsubscription
    - Value:
    
      - Minimum ADA
      - Penalty Reference NFT Asset (if applicable)

=== Spend :: Withdraw
\
The Withdraw endpoint allows merchants to withdraw accumulated subscription fees from the contract.

==== Inputs:
\
+ Merchant Wallet UTxO

  - Address: Merchant’s wallet address
  - Value:

    - Minimum ADA
    - Merchant NFT Asset

+ Payments Validator UTxO

  - Address: Payments validator script address

  - Datum:
    - current_datum: Current metadata for the subscription
  - Value:

    - Minimum ADA
    - Reference NFT Asset

==== Outputs:
\
+ Merchant Wallet UTxO

  - Address: Merchant’s wallet address

  - Value:

    - Minimum ADA
    - Withdrawn subscription fee portion
    - Merchant NFT Asset

+ Payments Validator UTxO

  - Address: Payments validator script address

  - Datum:
    - updated_datum: Metadata reflecting the withdrawal
  - Value:

    - Remaining ADA after withdrawal
    - Reference NFT Asset









// = Additional Features

// \
// == Sketch of the payment plan

// \
// - Recurring Payments:
//   - Supports recurring payments with defined start, end, interval, and amount.
// - Structured Payments:
//   - Can handle structured payments with a series of payouts.
// - Conditional Payments:
//   - Allows additional conditions (e.g., an NFT requirement, third-party certification) to be attached to payments.
// - Integration with Multisig:
//   - Supports ownership by a single user, multisig address, or script.
// - Incentivized Payment Processing:
//   - Allows setting a fee greater than 0 to incentivize the processing of payouts.
// - Composable Function:
//   - The payment plan script is provided as a function rather than a validator, allowing it to be a component of larger protocols.

// - A subscriber funds, should be associated with his own staking credentials so that he can get staking rewards even if funds are locked in the contract.