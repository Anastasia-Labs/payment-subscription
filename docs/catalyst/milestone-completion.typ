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
#set text(15pt, font: "Montserrat")

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
#align(center)[#strong[Proof of Achievement - Milestone 1]]
#set text(20pt, fill: white)
#align(center)[Payment Subscription Smart Contract]

#v(5cm)

// Set text style for project details
#set text(13pt, fill: white)

// Display project details
#table(
  columns: 2,
  stroke: none,
  [*Project Number*],
  [1100025],
  [*Project Manager*],
  [Jonathan Rodriguez],
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
      Proof of Achievement - Milestone 1
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

= Introduction
\

The Payment Subscription Smart Contract project aims to develop a robust and user-friendly system for managing recurring payments on the Cardano blockchain. This contract enables users to effortlessly set up, manage, and cancel recurring payments directly from their wallets, providing a seamless experience for both subscribers and merchants.

Key features include:

- Initiating subscriptions with customizable terms

- Extending or terminating subscriptions
- Automated recurring payments
- Secure withdrawal of funds for both merchants and subscribers
- Seamless integration with popular wallet applications

This report demonstrates our progress in implementing the contract and meeting the acceptance criteria, focusing on effortless management of recurring payments and integration with wallets.

#pagebreak()
= Contract Functionality
\
The Payment Subscription Smart Contract consists of three main validators:

\
== Service Contract
\
A multi-validator responsible for:

- Creating an initial service by minting a single CIP-68 compliant Service NFT asset

- Sending the Service NFT to the user and the reference NFT to the spending endpoint
- Updating the metadata for the user
- Deleting the service by setting it to inactive.

\
== Account Contract
\
A multi-validator responsible for:

- Creating an account for the user by minting a CIP-68 compliant Account NFT asset

- Sending the Account NFT to the user and the reference NFT to the spending endpoint
- Updating the metadata for the account
- Deleting the user account by burning the Account NFT

\
== Payment Contract
\
This is the core validator and is responsible for:

- Holding prepaid subscription fees for a service

- Renewing a subscription
- Unsubscribing from a service
- Withdrawing subscription fees

\
The contract incorporates a linear vesting mechanism to gradually release subscription fees to the merchant over the subscription period.


#pagebreak()

= Effortlessly Manage Recurring Payments
\
Our smart contract enables users to easily manage their recurring payments through a series of intuitive operations. We've implemented and tested various scenarios to ensure a smooth user experience.

\
== Test Suite Details
\

We've developed a comprehensive test suite consisting of thirteen critical test cases, to validate the contract's functionality. These tests cover all aspects of subscription management, from initiation to termination and fund withdrawal.

Here's an overview of the test execution results:

\
== Test Execution Results

\
#figure(
  image("./test-images/all-tests.png", width: 100%),
  caption: [ Payment Subscription Tests Overview],
)
\

This test validates the contract's ability to initiate a new subscription. It
demonstrates:

- Correct setup of subscription parameters

- Proper creation of the Payment Datum
- Accurate handling of inputs and outputs
- Successful minting of the Payment NFT

#pagebreak()
= Detailed Test Case Scenarios
\
This process comprises of six checks all from the Payments Contract which are:

\
- succeed_initiate_subscription

- succeed_terminate_subscription
- succeed_extend_subscription
- succeed_unsubscribe
- succeed_merchant_withdraw
- succeed_subscriber_withdraw


#pagebreak()

== Initiating a Subscription (succeed_initiate_subscription)

\
#figure(
  image("./test-images/succeed_initiate_subscription.png", width: 100%),
  caption: [Succeed Initialize Subscription Test],
)
\

This test validates the contract's ability to initiate a new subscription. It
demonstrates:

- Correct setup of subscription parameters

- Proper creation of the Payment Datum
- Accurate handling of inputs and outputs
- Successful minting of the Payment NFT

#pagebreak()

== Terminate Subscription (succeed_terminate_subscription)

\
#figure(
  image("./test-images/succeed_terminate_subscription.png", width: 100%),
  caption: [Succeed Terminate Subscription Test],
)
\

This test verifies the contract's ability to handle early termination, applying
appropriate refunds and penalties.

#pagebreak()

== Extend Subscription (succeed_extend_subscription)

\
#figure(
  image("./test-images/succeed_extend_subscription.png", width: 100%),
  caption: [Succeed Extend Subscription Test],
)
\

This test demonstrates the contract's ability to extend an existing
subscription, showcasing the flexibility offered to subscribers. It shows:

- Accurate calculation of the new subscription end date

- Correct fee adjustment for the extension
- Proper updating of the Payment Datum
- Successful execution of the extension transaction

#pagebreak()

== Unsubscribe (succeed_unsubscribe)

\
#figure(
  image("./test-images/succeed_unsubscribe.png", width: 100%),
  caption: [Succeed Unsubscribe Test],
)
\

This test verifies the contract's ability to process an unsubscription. It
demonstrates:

- Accurate calculation of refund and penalty amounts

- Proper distribution of funds (refund to subscriber, penalty to designated
  UTxO)
- Correct burning of the Payment NFT

#pagebreak()
== Merchant Withdrawing Fees (succeed_merchant_withdraw)
\
#figure(
  image("./test-images/succeed_merchant_withdraw.png", width: 100%),
  caption: [Succeed Merchant Withdraw Test],
)
\

This test confirms the contract's ability to process withdrawals of subscription
fees by a merchant. It shows:

- Correct calculation of withdrawable amounts based on elapsed time

- Proper distribution of funds to the merchant
- Accurate updating of the Payment Datum with new 'last claimed' time

#pagebreak()
== Subscriber Withdrawing Fees (succeed_subscriber_withdraw)
\
#figure(
  image("./test-images/succeed_subscriber_withdraw.png", width: 100%),
  caption: [Succeed Subscriber Withdraw Test],
)
\

This test verifies the contract's ability to process withdrawals of subscription
fees by a subscriber when the service becomes inactive. It demonstrates:

- Correct identification of an inactive service

- Full refund of the subscription amount to the subscriber
- Proper burning of the Payment NFT
- Accurate updating of the Payment UTxO

#pagebreak()
= User Workflow for Managing Recurring Payments
\
The following outlines the user workflow for managing recurring payments:

\
+ *Initiate Subscription:*

   - User selects a service and subscription period

   - Smart contract mints a Payment NFT and locks the subscription fee
   - User receives confirmation of successful subscription

+ *Extend Subscription:*

   - User chooses to extend their subscription

   - Smart contract calculates additional fee and new end date
   - User approves the extension
   - Contract updates the Payment Datum with new details

+ *Unsubscribe:*
   - User requests to end their subscription

   - Contract calculates refund and penalty amounts
   - User receives refund, minus any applicable penalties
   - Payment NFT is burned, ending the subscription

+ *Merchant Withdrawal*
   - Merchant can withdraw accrued fees at any time

   - Contract calculates withdrawable amount based on elapsed time
   - Remaining funds stay locked until the next withdrawal or end of
     subscription

+ *Subscriber Withdrawal*

- Subscriber can withdraw remaining funds if the service becomes inactive

- Contract verifies the inactive status of the service
- Full remaining subscription amount is refunded to the subscriber
- Payment NFT is burned, finalizing the withdrawal

This workflow demonstrates the ease with which users can manage their recurring
payments, from initiation to termination, directly from their wallets.

#pagebreak()

= Conclusion
\
The Payment Subscription Smart Contract demonstrates robust functionality and
ease of use. Through comprehensive testing and thoughtful implementation, it
effectively manages recurring payments, allowing users to initiate, extend, and
terminate subscriptions efficiently.

Key achievements include:

- Successful implementation of subscription initiation, extension, and termination processes

- Accurate handling of fee calculations, including prorated refunds and penalties
- Secure management of funds through the payment contract
- Flexible service and account management through dedicated contracts

These features collectively ensure that the contract meets the needs of both
service providers and subscribers, offering a secure and user-friendly solution
for managing subscription-based services on the Cardano blockchain.

All documentation, including detailed test cases and explanations, is available in our GitHub repository: https://github.com/Anastasia-Labs/plug-n-play-contracts