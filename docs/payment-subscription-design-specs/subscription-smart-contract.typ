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
      #counter(page).display( "1/1",both: true)]
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

This Payment Subscription Smart Contract is developed using Aiken it is designed to facilitate automated recurring payments between subscribers and merchants on the Cardano blockchain. This contract empowers users to seamlessly set up, manage, and cancel their subscriptions directly from their wallets. It ensures secure and efficient transactions by automating the process of paying subscription fees, updating service metadata, and handling cancellations, all within a decentralized framework.
#pagebreak()

= Architecture
\
#figure(
  image("./images/payment-subscription-architecture.png", width: 100%),
  caption: [Payment Subscription Architecture],
)
\

There are three contracts in this subscription system.

+ *Service Contract* 
  
  A multi-validator responsible for creating an initial service by minting a single CIP-68 compliant Service NFT Asset and sending it to the user while sending the reference NFT to the spending endpoint. It also updates the metadata for the user and deletes the service by burning the Service NFT.

+ *Account Contract*
  
  A multi-validator responsible for creating an account for the user by minting a CIP-68 compliant Account NFT Asset and sending it to the user, while sending the reference NFT to the spending endpoint. It also updates the metadata for the Account and deletes the user account by burning a Account NFT.

+ *Payment Contract*
  
  This is the core validator. A multi-validator responsible for holding the prepaid subscription fees for a service, renewing a subscription to a service, unsubscribing from a service and withdrawing subscription fees. The contract incorporates a linear vesting mechanism to gradually release subscription fees to the merchant over the subscription period.
#pagebreak()

= Specification


== System Actors
\ 
+ *Merchant*
  
  - An entity who interacts with the *Service Contract* to create a service and receive subscription payments for the respective service(s). 
  
  - A user becomes a merchant when they mint a *Service NFT*.

+ *Subscriber*

  - An entity who interacts with the *Account Contract* to create an account and deposit prepaid subscription fees to the *Payment Contract*. 
  
  - A user becomes a subscriber when they mint an *Account NFT* and lock funds to the *Payment Contract*.
\
== Tokens
\
+ *Service NFT*

  - Can only be minted by a user when creating a service 
  
  - Burned when the user deletes their service(s) from the system.
  - *TokenName:* Defined in *Service Multi-validator* parameters using a unique token name derived from the transaction ID and output index (using CIP-68 standards).

+ *Account NFT:*

  - Can only be minted by a user when creating an account for the subscription system.

  - Burned when the user deletes their account from the system. 
  - A check must be included to verify that there are no payments in the Payment Contract before burning.
  - *TokenName:* Defined in *Account Multi-validator* parameters using a unique token name derived from the transaction ID and output index (using CIP-68 standards).

+ *Payment NFT:* 

  - Can only be minted when a subscription fee is paid to the *Payment Contract*

  - Burned when a merchant withdraws the Penalty Fee or Subscription ends.

  - *TokenName:* Defined in *Payment Multi-validator*  parameters using a unique token name derived from the transaction ID and output index.

#pagebreak()

== Smart Contracts
\
=== Payment Multi-validator
\
  The Payment Contract is responsible for managing the prepaid subscription fees, validating subscriptions, and ensuring the proper distribution of these fees over the subscription period given the `total_installments`. It facilitates the creation, extension, and cancellation of subscriptions, allowing both subscribers and merchants to interact with the contract in a secure and automated manner. This contract ensures that subscription payments are correctly handled and that any penalties for early cancellation are appropriately enforced.

==== Parameters
\
- *`service_policy_id`* : Hash of the PolicyId

- *`account_policy_id`* : Hash of the PolicyId
\

==== Minting Purpose
\
===== Redeemer
\
- *InitiateSubscription*

- *TerminateSubscription*

#pagebreak()

\
===== Validation
\
+ *InitiateSubscription* 
  
  The redeemer allows creating of a new subscription  by minting only one unique *Payment Token*.
  
  - *Validation Steps:*

    - *Presence of Required Inputs:* Validate that the output_reference (the specific UTxO reference) is present in the transaction inputs.

    - *Single Payment NFT Minted:* Ensure that only one unique Payment NFT is minted.
    - *Service Datum Validation:* Validate the datum from the Service Contract as a reference input to ensure it matches the subscription details.
    - *Account NFT Handling:* Ensure that the Account NFT does not go to the script address (i.e., it remains with the subscriber).
    - *Payment NFT Output:* Ensure that the Payment NFT goes back to the script address.
    - *Datum Consistency:* Validate internal consistency of the Payment Datum.
    - *Subscription Details Validation:* Ensure that the subscription details (e.g., interval length, fee amount) match the service parameters.
    - *Locked Amount Validation:* Verify that the correct amount is locked in the contract (e.g., locked_amount >= expected_amount).
  \

+ *TerminateSubscription*
  
  - *Merchant Ownership Validation:* Validate that the merchant possesses the correct Service NFT.

  - *Single Payment NFT Burned:* Ensure that exactly one Payment NFT is burned during the transaction.
  - *Payment NFT Matching:* Verify that the Payment NFT being burned matches the one from the input.
  - *Service Datum Validation:* Validate the datum from the Service Contract as a reference input.

#pagebreak()

==== Spend Purpose
\
This involves the validation logic when spending UTxOs from the Payment Contract. Actions include:

- *Extend Subscription*

- *Merchant Withdraw*
- *Unsubscribe*
- *Subscriber Withdraw*

Each action has specific validation requirements to ensure the integrity and correctness of the subscription process.

\
===== Redeemer
\
- *Extend*

- *Unsubscribe*
- *MerchantWithdraw*
- *SubscriberWithdraw*


#pagebreak()

===== Validation

\
+ *Extend* 
  
  Allows subscribers to extend their subscription by locking additional funds.

  - *Validation Steps:*

    - Presence of Required Inputs: Validate that the subscriber's account input and the payment input are present.

    - Service Datum Validation: Validate the datum from the Service Contract as a reference input.
    - Subscription Extension Validity: Ensure that the extension aligns with the service parameters (e.g., maximum subscription length).
    - Fee Increase Validation: Verify that the fee increase corresponds to the extension period.
    - Payment Datum Update: Validate that the new Payment Datum reflects the extended subscription correctly.
    - Token Handling: Ensure that the Payment NFT remains at the script address.

  \
+ *MerchantWithdraw* 

  Allows merchants to withdraw accumulated subscription fees corresponding to the elapsed time.

  - *Payment UTxO validation:* (When the datum is a Payment Datum)

    - Merchant Ownership Validation: Validate that the merchant possesses the correct Service NFT.

    - *Service Datum Validation:* Validate the datum from the Service Contract as a reference input.
    - *Withdrawal Amount Calculation:* Calculate the withdrawable amount based on the elapsed subscription period (using linear vesting).
    - *Payment Datum Update:* Update the last_claimed timestamp in the Payment Datum.
    - *Remaining Funds Validation:* Ensure that the remaining funds in the contract are correct.
    - *Minimum ADA Requirement:* Verify that the merchant receives at least the minimum ADA required.
    - *Token Handling:* Ensure that the Payment NFT remains at the script address.
    \
  - *Penalty UTxO validation:* (When the datum is a Penalty Datum)

    - *Merchant Ownership Validation:* Validate that the merchant possesses the correct Service NFT.

    - *Service Datum Validation:* Validate the datum from the Service Contract as a reference input.
    - *Penalty Input Validation:* Ensure that the input UTxO contains the correct Penalty Datum.
    - Penalty Fee Validation: Verify that the penalty fee amount in the input matches the expected amount.
    - Penalty Withdrawal: Ensure that the penalty fee is transferred to the merchant.
    - Payment NFT Burned: Validate that the associated Payment NFT is burned.
    - Token Handling: Ensure that the Service NFT remains with the merchant.
  \
+ *Unsubscribe* 

  Allows subscribers to cancel their subscription before the end date.

  - *Validation Steps:*

    - Presence of Required Inputs: Validate that the subscriber's account input and the payment input - are present.

    - Service Datum Validation: Validate the datum from the Service Contract as a reference input.
    - Refund Calculation: Calculate any refundable amount based on the elapsed subscription time.
    - Penalty Fee Handling: Apply any penalty fees as defined in the service parameters.
    - Payment Datum Update: Update the contract state to reflect the unsubscription.
    - Penalty Datum Creation: Create a new Penalty Datum representing the penalty to be paid.
    - Token Handling: Ensure that the Payment NFT is transferred to the new penalty UTxO at the script address.
  \
+ *SubscriberWithdraw* 
  
Allows subscribers to withdraw funds if the service becomes inactive (e.g., the merchant has deleted the service).

  - *Validation Steps:*

    - Service Inactivity Validation: Validate that the service is inactive.

    - Full Refund: Ensure the subscriber receives a full refund of remaining funds.
    - Payment NFT Handling: Burn the associated Payment NFT.
    - Token Handling: Ensure that the Account NFT remains with the subscriber.

#pagebreak()

\
==== Datum
\
The datum is a sum type with two constructors, representing different states of the subscription.

  - *Payment Datum*

  - *Penalty Datum*
\
===== Payment datum <payment-datum>
\
Represents the state of an active subscription.

- *`service_nft_tn`:* Service token name encoding UTxO to be consumed when minting the NFT.

- *`account_nft_tn`:* Accont token name encoding UTxO to be consumed when minting the NFT.
- *`subscription_fee`:* AssetClass type for the subscription fee.
- *`total_subscription_fee`:* Total amount of the subscription fee for the entire subscription period.
- *`subscription_start`:* Starting time of the withdrawal period.
- *`subscription_end`:* Expiry time of the subscription.

- *`interval_length`:* Length of an interval,
- *`interval_amount`:* Amount withdrawable at each interval,
- *`num_intervals`:* Number of intervals in the subscription,

- *`last_claimed`:* The last time the merchant withdrew from the contract.
- *`penalty_fee`:* AssetClass type of the penalty.
- *`penalty_fee_qty`:* Amount the merchant wishes to penalies for early withdrawal. This is optional and can be `0`.
- *`minimum_ada`:* Least amount of Ada required to complete the transaction,

\
===== Penalty datum <penalty-datum>
\
- *`service_nft_tn`:* Service token name encoding UTxO to be consumed when minting the NFT.

- *`account_nft_tn`:* Account token name encoding the UTxO to be consumed when minting the NFT.
- *`penalty_fee`:* AssetClass type for the amount of fees to be deducted when subscriber cancels the subscription (optional).
- *`penalty_fee_qty`:* Amount of the penalty fees (optional).
\

=== Account Multi-validator
\
Responsible for managing user accounts within the subscription system.

\
==== Parameter
\  
Nothing

\
==== Minting Purpose

===== Redeemer
\
- *CreateAccount*

- *DeleteAccount*

#pagebreak()

====== Validation
\
+ *CreateAccount*
  
  Allows a user to create a new account by minting an Account NFT and a reference NFT.
    
  - *Validation Steps:*

    - Presence of Required Inputs: Ensure the output_reference is spent in the transaction.

    - Minting Tokens: Validate that exactly one Account NFT and one reference NFT are minted using CIP-68 standards.
    - Account Datum Validation: Validate the Account Datum for correctness (e.g., valid email, phone number).
    - Token Handling: Ensure that the Account NFT does not go to the script address and the reference NFT goes to the script address.
  \
+ *DeleteAccount*

  Allows a user to delete their account, burning the Account NFT and reference NFT.
  
  A Check That there's no payment for the delete account should be done off-chain.

  - *Validation Steps:*

    - Burning Tokens: Validate that the Account NFT and reference NFT are both burned.

\

==== Spend Purpose
\
===== Datum <account-datum>
\
  - *`email`:* ByteArray

  - *`phone`:* ByteArray
  - *`account_created`:* Int

\
===== Redeemer
\
- *UpdateAccount*

- *RemoveAccount*
\
====== Validation
\
+ *UpdateAccount*

  The redeemer allows for updating the metadata attached to the UTxO sitting at the script address. 

  - Validate that the Account UTxO with the Account NFT is being spent.

  - Validate that the metadata of the Reference NFT is updated within acceptable bounds
  - Validate that the UTxO with the Reference NFT of is sent to the spending endpoint. 

+ *RemoveAccount*
  
  The redeemer allows the removal of an account by a subscriber from the subscription system. Must Check That there's no ADA in the payment UTxO in the off-chain code.
 
    - No Active Subscriptions: Check that there are no active subscriptions in the Payment Contract.

    - Validate that Account NFT and Account Reference NFT is spent.
    - Burning Tokens: Validate that the Account NFT and reference NFT are both burned.
    - Token Handling: Ensure that no outputs contain the reference NFT after burning.

#pagebreak()

=== Service Multi-validator
\
The Service Multi-Validator is responsible for managing services offered by merchants. It allows the creation, update, and deletion of services through specific actions.


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

  Allows a merchant to create a new service by minting a Service NFT and a reference NFT.

  - *Validation Steps:*

    - Presence of Required Inputs: Ensure the output_reference is spent in the transaction.

    - Minting Tokens: Validate that exactly one Service NFT and one reference NFT are minted using CIP-68 standards.
    - Service Datum Validation: Validate the Service Datum for correctness (e.g., valid service fee, penalty fee).
    - Token Handling: Ensure that the Service NFT does not go to the script address and the reference NFT goes to the script address.

\

==== Spend Purpose
\
Handles operations involving spending UTxOs associated with services.

\
===== Redeemer
\
  - *UpdateService*

  - *RemoveService*

#pagebreak()

====== Validation
\
+ *UpdateService*

  Allows a merchant to update their service details.

    - *Validation Steps:*

      - Presence of Required Inputs: Validate that the merchant's service input and the service reference input are present.

      - Service Datum Update: Validate that the updated Service Datum is within acceptable bounds (e.g., service fee changes are within a permitted range).
      - Token Handling: Ensure that the reference NFT is sent back to the script address.
  \
+ *RemoveService*

Allows a merchant to deactivate their service without burning the Service NFT.

  - *Validation Steps:*

    - Service Inactivation: Ensure the service's is_active field is set to False.

    - Service Datum Consistency: Validate that other fields in the Service Datum remain unchanged.
    - Token Handling: Ensure that the reference NFT is being spent and is sent back to the script address.
\
===== Datum <service-datum>
\

  - *`service_fee`:* AssetClass type for the amount to pay for a subscription service

  - *`service_fee_qty`:* Amount of the funds to pay for a service.
  - *`penalty_fee`:* AssetClass type for the amount of fees to be deducted when subscriber cancels the subscription (Optional).
  - *`penalty_fee_qty`:* Amount of the penalty fees (Optional).
  - *`interval_length`:* Length of an interval for the subscription,
  - *`num_intervals`:*  Number of intervals in the subscription period (e.g. 12 for monthly withdraws for a year),
  - *`minimum_ada`:* Least amount of Ada required to complete the transaction,
  - *`is_active`:* Boolean indicating if the service is active
  
*Note:* Subscription fees can be based on length of period the subscriber pays for e.g. If they pay for one month, the fees are more than if they pay for 12 months. This introduces the need for a `min_sub_period`.

// minimum_subscription_period: Subscription fees can be based on length of period the subscriber pays for e.g. If the y pay for one month, the fees are more than if they pay for 12 months.

#pagebreak()


= Transactions
\
This section outlines the various transactions involved in the Payment Subscription Smart Contract on the Cardano blockchain.

\
== Service Multi-validator
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

      - *`service_nft_tn`:* Service NFT token name encoding UTxO to be consumed when minting the NFT.
      - *`subscription_fee`:* AssetClass type for the subscription fee.
      - *`total_subscription_fee`:* Amount of the subscription fee.
      - *`penalty_fee`*: AssetClass type for the amount of funds to be deducted when subscriber cancels the subscription.
      - *`penalty_fee_qty`*: Amount of the penalty fees.

    - Value:     

      - 1 Service Reference NFT Asset
#pagebreak()

  === Spend :: UpdateMetaData
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


== Account Multi-validator
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

      - account_details: Arbitrary ByteArray

    - Value:

      - 1 Reference NFT Asset
#pagebreak()
 
=== Mint :: DeleteAccount
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
  + *Account Multi-validator*

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


=== Spend :: UpdateMetaData
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

=== Spend :: RemoveAccount
\

This transaction effectively terminates the subscription and removes the subscriber's account from the system by consuming the Account NFT and the Reference NFT.

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

      - Account NFT Asset

  + *Account Policy UTxO*

  - Address: Account Multi-validator Address (Spend)

  - Datum:

    - account_datum: listed in @account-datum

  - Value: 

    - Minimum ADA

    - 1 Reference NFT Asset
\
==== Mints
\
  + *Account Multi-validator*

    - Redeemer: RemoveAccount
    
    - Value:

      - -1 Account NFT Asset

      - -1 Reference NFT Asset    
\
==== Outputs
\
  + *Subscriber UTxO*

    - Address: Subscriber wallet address

    - Value: 

      - Minimum ADA (remaining after burning the NFT)

#pagebreak()


== Payment Multi-validator
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
\
==== Mints
\
  + *Service Multi-validator*
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

=== Spend :: Withdraw
\
This transaction allows anyone with a Service NFT to unlock subscription funds from the Payment UTxO in repect to the specified subscription start and end dates.

\
#figure(
  image("./images/withdraw-image.png", width: 100%),
  caption: [Merchant Withdraw UTxO diagram],
)
\

==== Inputs:
\
+ *Merchant Wallet UTxO*

  - Address: Merchant’s wallet address
total_subscription_fee
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

  - Penalty Datum:

    - service-nft-tn: Service AssetName
  - Value:

    - Minimum ADA

    - Payment NFT Asset
\
==== Mints
\
  + *Service Multi-validator*
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
