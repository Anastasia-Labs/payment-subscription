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

// Initialize page counter
#counter(page).update(0)

#outline(depth:4, indent: 1em)
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
      // Copyright © 
      // #set text(fill: black)
      // Anastasia Labs
    ]
    #v(-6mm)
    #align(right)[
      #counter(page).display(  // Page numbering
        "1/1",
        both: true,
      )
      ]
  ] 
)

// Display project details
#set terms(separator:[: ],hanging-indent: 18mm)
#align(center)[
  #set text(size: 20pt)
  #strong[Payment Subscription Smart Contract]]
#v(10pt)

#set heading(numbering: "1.")
= Overview
#v(10pt)

\ 
This Payment Subscription Smart Contract is developed using Aiken to facilitate automated recurring payments between Subscribers and Merchants on the Cardano blockchain. This smart contract enables users to set up, manage, and cancel subscriptions directly from their wallets.

\
= Architecture
\ 
#figure(
  image("./images/Payment Subscription Architecture.png", width: 100%),
  caption: [Contract Architecture],
)
\

There are three contracts in this subscription system.

- *Merchant Contract:* A multi-validator responsible for creating an initial service by minting a single CIP-68 compliant MerchantNFT and sending it to the merchant while sending the reference NFT to the spending end point. It also updates the metadata for the merchant and deletes the service by burning the MerchantNFT.

- *Subscriber Contract:* A multi-validator responsible for creating the initial subscription to a service by minting a SubscriberNFT and sending it to the user, while sending the reference NFT to the spending endpoint. It also updating the metadata for the subscriber and deletes the user account by burning a SubscriberNFT.

- *Subscribe Contract:* Responsible for holding the prepaid subscription fees for a service, renewing a subscription to a service, unsubscribing from a service and withdrawing subscription fees. This could also be a multi-validator to authenticate the UTxO.

= Specification
\
== System Actors
\ 
- *Merchant:* An entity who interacts with the Merchant Contract in order to create a service and receives subscription payments for the respective service or services.

- *Subscriber:* An entity who interacts with the Subscriber Contract in order to create an account and deposit prepaid subscription fees to the Subscribe Contract.
\
== Tokens
\
- *Merchant NFT:* Can only be minted by a merchant when creating a subscription service and burned when merchant removes their service/services from the system. Datum is updated when a subscription is paid or the merchant withdraws from the Subscribe Contract.

 - TokenName: Defined in Merchant Minting Policy parameters with the hash of the Merchant Minting Policy OutputReference

- *Subscriber NFT:* Can only be minted when a subscription fee is paid to Subscribe Contract and burned when subscriber exits the system. Datum is updated when fees are deposited and withdrawn from Subscribe Contract.

 - TokenName: Defined in Subscriber Minting Policy parameters with hash of the Subscriber Minting Policy OutputReference
\

== Smart Contract
\
=== Subscribe Validator
\
Subscribe validator is responsible for holding subscription fees and validating subscriptions.

==== Parameters
\
- *`merchant_policy_id`* : Hash of the PolicyId

- *`subscriber_policy_id`* : Hash of the PolicyId
\

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
\

===== Penalty datum
\

- *`merchant_nft_tn`:* Merchant's token name encoding UTxO to be consumed when minting the NFT.
\

==== Redeemer
\
- Extend

- Unsubscribe
- Withdraw

\

==== Validation
\
- *Extend:* The redeemer will allow anyone to increase the subscription funds. 

  - validate that the value of the UTxO is increased as long as the Datum is updated with the Merchant Token Name.

- *Unsubscribe:* The redeemer will allow anyone with a subscriberNFT to spend Subscribe UTxO to unlock funds back to their address.
 
  - validate the subscriberNFT is being spent.

  - validate that the penalty UTxO is being produced with the merchants Token Name.

- *Withdraw:* The redeemer will allow anyone with a merchantNFT to withdraw funds from the Subscribe contract 
 
  - validate merchantNFT is being spent

  - validate whether the transaction contains a penalty datum or a normal datum.
\

=== Merchant Minting Policy
\
Merchant Minting Policy is responsible for registering a service creating, updating and removing a service for a merchant.

==== Parameter
\

Nothing

==== Minting Purpose

===== Redeemer
\

- CreateService

- RemoveAccount
\

====== Validation
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
\

====== Validation
\
- *UpdateMetaData:* The redeemer allows for updating the metadata attached to the UTxO sitting at the script address. 

  - validate that merchantNFT is being spent.

  - updates the metadata of the Reference NFT token and sends the token to the spending end point

- *RemoveService:* The redeemer allows the removal of a service by a merchant from the subscription system. 

  - validate merchentNFT is being spent.
  - Removes all the Reference NFT tokens to another external address.
\

=== Subscriber Minting Policy

==== Parameter
\  

Nothing
\

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

=== Spend Purpose

===== Datum
\

- cip-68 requirements
\
===== Redeemer
\
- UpdateMetaData

- RemoveAccount
\

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

// = Transactions
// == UTxO Diagram

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