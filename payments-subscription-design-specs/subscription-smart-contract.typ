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
      *Payments Subscription Smart Contract*
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
  #strong[Payments Subscription Smart Contract]]
#v(10pt)

#set heading(numbering: "1.")
= Overview
#v(10pt)

\ 
This Payments Subscription Smart Contract is developed using Aiken, to facilitate automated recurring payments between Subscribers and Merchants on the Cardano blockchain. This smart contract will enable users to set up, manage, and cancel subscriptions directly from their wallets.

\
= Architecture
\ 
#figure(
  image("./images/subscription-contract-image.png", width: 100%),
  caption: [Contract Architecture],
)
\

There are two contracts in this subscription system.

- *Subscribe Contract:* Is responsible for creating services they provide, holding the prepaid subscription fees for the respective service awaiting merchant withdrawal.
- *Auth Minting Policy:* Responsible for creating initial service, minting and burning MerchantNFT and SubscriberNFT as well as tracking and updating the respective tokens.

= Specification

== System Actors
\ 
- *Merchant:* An entity who interacts with the Subscribe Contract in order to create a service and receives subscription payments for the respective service/ services.

- *Subscriber:* An entity who wants to interact with the Subscribe Contract to deposit/withdraw prepaid subscription fees.
\
== Tokens
\
- *Merchant NFT:* Can only be minted by a merchant when creating a subscription service and burned when merchant removes their service/services from the system. Datum is updated when a subscription is paid or fees are withdrawn from Subscribe Contract.

 - Policy Id: Auth Minting Policy
 - TokenName: Defined in Auth Minting Policy parameters (e.g. "MERCHNFT")

- *Subscriber NFT:* Can only be minted when a subscription fee is paid to Subscribe Contract and burned when subscriber exits the system. Datum is updated when fees are withdrawn from Subscribe Contract.

 - Policy Id: Auth Minting Policy
 - TokenName: Defined in Auth Minting Policy parameters (e.g. "SUBNFT")
\

== Smart Contract
\
=== Subscribe Validator
\
Subscribe validator is responsible for validating subscriptions and holding "Subscriber Requests" funds and subscription details.

==== Parameters
\
None
\

==== Datum
\
- *`merchantNftTn`:* Merchant's token name encoding UTXO to be consumed when minting the token.
- *`merchant`:* Who should recieve the subscription fees.
- *`merchant_nft_id`:* Policy Id of the Merchant's NFT.
- *`subscriberNftTn`:* Subscriber's token name encoding UTXO to be consumed when minting the token.
- *`subscriber_nft_id`:* Policy Id of the Subscriber's NFT.
- *`subscriptionFee`:* AssetClass type for the subscription fee.
- *`subscriptionFeeAmnt`:* Amount of the subscription fee.
- *`subscriptionStart`:* Start of the subscription.
- *`subscriptionEnd`:* Expiry time of the subscription.
\

==== Redeemer
\
- CreateService
- CancelService
- Subscribe
- Unsubscribe
\

==== Validation
\
- *CreateService:* The redeemer will allow an entity to create a new subscription service.

  - validate that transaction has to be executed by a payment sinature.
  - validate the transaction mints one token of name MerchantNFT.

- *CancelService:* The redeemer allows any to spend Subscribe UTxO to get back locked funds.

  - validate payment signature is equal to merchant payment signature.  
  - validate that there is a single UTxO in the transaction input and contains a single merchentNFT token.
  - validate that unlocked funds are sent to   _`merchant`_
  - validate that transaction burns one token MerchantNFT.

- *Subscribe:* This redeemer allows spending Subscribe UTxO to subscribe to a service.

  - validate that the transaction must execute only after _`subscriptionStart`_
  - validate that transaction contains  _`subscriptionFee`_  fee amount equal or more than the amount in service datum.
  - validate that transaction contains the correct service owner / _`merchant`_ to withdraw the funds to.
  - validate that transaction mints or updates only one token of name SubscriberNFT.
  - validate that transaction mints or updates only one token of name MerchantNFT.

- *Unsubscribe:* The redeemer will allow anyone with a subscriberNFT to spend Subscribe UTxO to unlock funds back to their address.
 
  - validate that there is a single UTxO in the transaction input and contains a single subscriberNFT token.
  - validate that transaction burns one token of name SubscriberNFT.
\

=== Auth Minting Policy
\
Auth Minting Policy is responsible for creating and burning Subscriber and Merchant NFT Tokens

==== Parameter
\
- *out_ref:* is a Reference of an Unspent Transaction Output, which will only be spent on Subscribe and CreateService redeemer to make sure this redeemer can only be called once.

- *token_name:* is identified as the service name prefixed to the token name of the merchant or subscriber.

// 2) Service name already in datum, should it be in tokenname.

// Minting Purpose /Spend Purpose
==== Minting Purpose

===== Redeemer
\
- Mint

- Burn
\

====== Validation
\
- *Mint:* The redeemer allows creating of a new subscriprion sevice and a new subscription by minting only one unique 

  - validate that out_ref must be present in the Transaction Inputs
  - validate that the redeemer only mints:

    - a single CIP68 compliant Merchant Token
    - a single CIP68 compliant Subscriber Token

- *Burn:*
- validate that the redeemer only burns:

    - a single CIP68 compliant Merchant Token
    - a single CIP68 compliant Subscriber Token
\

==== Spend Purpose

===== Datum
===== Redeemer
\
- Update

- Remove
\

====== Validation
\
- *Update:* updates the metadata of the Reference NFT token and sends the token back to the address entity executing it.

- *Remove:* removes all the Reference NFT tokens to another external address.


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
