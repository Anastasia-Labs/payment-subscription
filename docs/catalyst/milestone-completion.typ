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

= Introduction
\

This document presents comprehensive evidence of the successful implementation
and testing of the Payment Subscription Smart Contract addressing the effortless
management of recurring payments

Each section provides detailed insights into the functionality, security, and
usability of the smart contract, demonstrating its readiness for real-world
application.

Our rigorous testing suite demonstrates the contract's ability to manage
recurring payments effectively and with ease.

#pagebreak()

= Test Suite Details

The test suite for the Payment Subscription Smart Contract consists of thirteen
critical test cases, each designed to verify specific aspects of the contract's
functionality.

== Test Execution Results

\
#figure(
  image("./test-images/all-tests.png", width: 100%),
  caption: [All Payment Subscription Tests],
)
\

This test validates the contract's ability to initiate a new subscription. It
demonstrates:

- Correct setup of subscription parameters
- Proper creation of the Payment Datum
- Accurate handling of inputs and outputs
- Successful minting of the Payment NFT

#pagebreak()
= Managing Recurring Payments Tests

This process comprises of six checks:

- succeed_initiate_subscription
-  succeed_terminate_subscription
-  succeed_extend_subscription
-  succeed_unsubscribe
-  succeed_merchant_withdraw
-  succeed_subscriber_withdraw
== Test Case: Initiating a Subscription (succeed_initiate_subscription)

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

== Test Case: Terminate Subscription (succeed_terminate_subscription)

\
#figure(
  image("./test-images/succeed_terminate_subscription.png", width: 100%),
  caption: [Succeed Terminate Subscription Test],
)
\

This test verifies the contract's ability to handle early termination, applying
appropriate refunds and penalties.

#pagebreak()

== Test Case: Extend Subscription (succeed_extend_subscription)

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

== Test Case: Unsubscribe (succeed_unsubscribe)

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
== Test Case: Withdrawing Subscription Fees by Merchant (succeed_merchant_withdraw)
\
#figure(
  image("./test-images/succeed_merchant_withdraw.png", width: 100%),
  caption: [Succeed Unsubscribe Test],
)
\

This test confirms the contract's ability to process withdrawals of subscription
fees by a merchant. It shows:

- Correct calculation of withdrawable amounts based on elapsed time
- Proper distribution of funds to the merchant
- Accurate updating of the Payment Datum with new 'last claimed' time

#pagebreak()
== Test Case: Withdrawing Subscription Fees by Subscriber (succeed_subscriber_withdraw)
\
#figure(
  image("./test-images/succeed_subscriber_withdraw.png", width: 100%),
  caption: [Succeed Unsubscribe Test],
)
\

This test verifies the contract's ability to process withdrawals of subscription
fees by a subscriber when the service becomes inactive. It demonstrates:

- Correct identification of an inactive service
- Full refund of the subscription amount to the subscriber
- Proper burning of the Payment NFT
- Accurate updating of the Payment UTxO

= User Workflow for Managing Recurring Payments

The following outlines the user workflow for managing recurring payments:

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

= Conclusion
\
The Payment Subscription Smart Contract demonstrates robust functionality and
ease of use. Through comprehensive testing and thoughtful implementation, it
effectively manages recurring payments, allowing users to initiate, extend, and
terminate subscriptions directly from their preferred wallet applications.

These features collectively ensure that the contract meets the needs of both
service providers and subscribers, offering a secure and user-friendly solution
for managing subscription-based services on the Cardano blockchain.
