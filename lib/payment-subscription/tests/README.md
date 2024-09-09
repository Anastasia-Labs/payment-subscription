# Payment Subscription Smart Contract: Test Documentation

## Overview

This document presents comprehensive evidence of the successful implementation
and testing of the Payment Subscription Smart Contract addressing the effortless
management of recurring payments

Each section provides detailed insights into the functionality, security, and
usability of the smart contract, demonstrating its readiness for real-world
application.

Our rigorous testing suite demonstrates the contract's ability to manage
recurring payments effectively and with ease.

### 1 Test Suite Details

The test suite for the Payment Subscription Smart Contract consists of thirteen
critical test cases, each designed to verify specific aspects of the contract's
functionality.

## 1.1 Test Execution Results

```
  ┍━ account_multi_validator ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    │ PASS [mem:  944885, cpu: 472517537] succeed_create_account
    │ · with traces
    │ | token_name
    │ | h'000DE14001A4028049AFDC47FB302ED59459582CB6D0545B7C6AC22504E98492'
    │ | token_quantity
    │ | 1
    │ | token_name
    │ | h'000643B001A4028049AFDC47FB302ED59459582CB6D0545B7C6AC22504E98492'
    │ | token_quantity
    │ | 1
    │ PASS [mem:  254727, cpu:  96259918] succeed_delete_account
    │ PASS [mem:  833446, cpu: 362978673] succeed_update_account
    │ · with traces
    │ | 123([_ 121([_ h'796F75406D61696C2E636F6D', h'2837313729203535302D31363735', 1])])
    │ PASS [mem:  314213, cpu: 123952193] succeed_remove_account
    ┕━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 4 tests | 4 passed | 0 failed

    ┍━ payment_multi_validator ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    │ PASS [mem: 1207619, cpu: 571235281] succeed_initiate_subscription
    │ · with traces
    │ | token_name
    │ | h'000DE14001A4028049AFDC47FB302ED59459582CB6D0545B7C6AC22504E98492'
    │ | token_quantity
    │ | 1
    │ | token_name
    │ | h'015F47F8F1A3D0FB2B1B3E9858E3AB77725785678981507D8920A19DA4A720EA'
    │ | token_quantity
    │ | 1
    │ PASS [mem:  434317, cpu: 162159511] succeed_terminate_subscription
    │ PASS [mem: 1078933, cpu: 464222983] succeed_extend_subscription
    │ · with traces
    │ | token_name
    │ | h'01A4028049AFDC47FB302ED59459582CB6D0545B7C6AC22504E984922830968A'
    │ | token_quantity
    │ | 1
    │ PASS [mem:  990940, cpu: 431215863] succeed_unsubscribe
    │ · with traces
    │ | token_name
    │ | h'01A4028049AFDC47FB302ED59459582CB6D0545B7C6AC22504E984922830968A'
    │ | token_quantity
    │ | 1
    │ PASS [mem:  710218, cpu: 270797201] succeed_withdraw
    ┕━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 5 tests | 5 passed | 0 failed

    ┍━ service_multi_validator ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    │ PASS [mem:  984693, cpu: 486750965] success_create_service
    │ · with traces
    │ | token_name
    │ | h'000DE14001A4028049AFDC47FB302ED59459582CB6D0545B7C6AC22504E98492'
    │ | token_quantity
    │ | 1
    │ | token_name
    │ | h'000643B001A4028049AFDC47FB302ED59459582CB6D0545B7C6AC22504E98492'
    │ | token_quantity
    │ | 1
    │ PASS [mem:  254995, cpu:  96198932] success_delete_service
    │ PASS [mem:  863048, cpu: 359322332] success_update_service
    │ · with traces
    │ | 123([_ 121([_ 121([_ h'', h'']), 10000000, 121([_ h'', h'']), 1000000, 2592000000])])
    │ PASS [mem:  310820, cpu: 122633481] success_remove_service
    ┕━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 4 tests | 4 passed | 0 failed

      Summary 13 checks, 0 errors, 0 warnings
```

## 1.2 Test Execution Results

#### 1.2.1 Test Case: Initiating a Subscription (succeed_initiate_subscription)

```
   Testing ...

    ┍━ payment_multi_validator ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    │ PASS [mem: 8832241, cpu: 4646399535] succeed_initiate_subscription
    │ · with traces
    │ | Test: Initiating a New Subscription
    │ | -------------------------------------
    │ | Step 1: Setting up the subscription
    │ | -------------------------------------
    │ | Service Currency Symbol:
    │ | h'BFA726C3C149165B108E6FF550CB1A1C4F0FDC2E9F26A9A16F48BABE'
    │ | Account Currency Symbol:
    │ | h'FB3D635C7CB573D1B9E9BFF4A64AB4F25190D29B6FD8DB94C605A218'
    │ | Subscription Fee: (lovelace)
    │ | 10000000
    │ | Subscription Period: (days)
    │ | 30
    │ | Penalty Fee: (lovelace)
    │ | 1000000
    │ | Step 2: Creating Payment Datum
    │ | -------------------------------------
    │ | Service NFT:
    │ | h'000643B00136752529784C15E638DA2A27FB1C00C9C8B92277913A8DC40A86D4'
    │ | Account NFT:
    │ | h'000DE14001A4028049AFDC47FB302ED59459582CB6D0545B7C6AC22504E98492'
    │ | Subscription Start:
    │ | 1000000
    │ | Subscription End:
    │ | 2593000000
    │ | Step 3: Preparing Inputs
    │ | -------------------------------------
    │ | Account Input:
    │ | 121([_ 121([_ 121([_ h'EE155ACE9C40292074CB6AFF8C9CCDD273C81648FF1149EF36BCEA6E']), 1]), 121([_ 121([_ 122([_ h'FB3D635C7CB573D1B9E9BFF4A64AB4F25190D29B6FD8DB94C605A218']), 122([])]), {_ h'': {_ h'': 4000000 }, h'FB3D635C7CB573D1B9E9BFF4A64AB4F25190D29B6FD8DB94C605A218': {_ h'000DE14001A4028049AFDC47FB302ED59459582CB6D0545B7C6AC22504E98492': 1 } }, 123([_ 121([])]), 122([])])])
    │ | Service Input:
    │ | 121([_ 121([_ 121([_ h'EE155ACE9C40292074CB6AFF8C9CCDD273C81648FF1149EF36BCEA6E']), 1]), 121([_ 121([_ 122([_ h'BFA726C3C149165B108E6FF550CB1A1C4F0FDC2E9F26A9A16F48BABE']), 122([])]), {_ h'': {_ h'': 4000000 }, h'BFA726C3C149165B108E6FF550CB1A1C4F0FDC2E9F26A9A16F48BABE': {_ h'000643B00136752529784C15E638DA2A27FB1C00C9C8B92277913A8DC40A86D4': 1 } }, 123([_ 121([_ 121([_ h'', h'']), 10000000, 121([_ h'', h'']), 1000000, 2592000000])]), 122([])])])
    │ | Step 4: Preparing Outputs
    │ | -------------------------------------
    │ | User Output:
    │ | 121([_ 121([_ 122([_ h'E88BD757AD5B9BEDF372D8D3F0CF6C962A469DB61A265F6418E1FFED']), 122([])]), {_ h'': {_ h'': 40000000 }, h'FB3D635C7CB573D1B9E9BFF4A64AB4F25190D29B6FD8DB94C605A218': {_ h'000DE14001A4028049AFDC47FB302ED59459582CB6D0545B7C6AC22504E98492': 1 } }, 123([_ 121([])]), 122([])])
    │ | Payment Output:
    │ | 121([_ 121([_ 122([_ h'873E4FE9E41E924911BBA3EC53FF4782EFC8C0F244FB75C879F8A432']), 122([])]), {_ h'': {_ h'': 40000000 }, h'873E4FE9E41E924911BBA3EC53FF4782EFC8C0F244FB75C879F8A432': {_ h'015F47F8F1A3D0FB2B1B3E9858E3AB77725785678981507D8920A19DA4A720EA': 1 } }, 123([_ 121([_ h'000643B00136752529784C15E638DA2A27FB1C00C9C8B92277913A8DC40A86D4', h'000DE14001A4028049AFDC47FB302ED59459582CB6D0545B7C6AC22504E98492', 121([_ h'', h'']), 10000000, 1000000, 2593000000, 2592000000, 500000, 121([_ h'', h'']), 1000000])]), 122([])])
    │ | Step 5: Execution Result
    │ | -------------------------------------
    │ | Subscription Successfully Initiated!
    │ | -------------------------------------
    │ | Test Completed!
    │ | token_name
    │ | h'000DE14001A4028049AFDC47FB302ED59459582CB6D0545B7C6AC22504E98492'
    │ | token_quantity
    │ | 1
    │ | token_name
    │ | h'015F47F8F1A3D0FB2B1B3E9858E3AB77725785678981507D8920A19DA4A720EA'
    │ | token_quantity
    │ | 1
    ┕━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 1 tests | 1 passed | 0 failed

      Summary 1 check, 0 errors, 0 warnings
```

This test validates the contract's ability to initiate a new subscription. It
demonstrates:

- Correct setup of subscription parameters
- Proper creation of the Payment Datum
- Accurate handling of inputs and outputs
- Successful minting of the Payment NFT

#### 1.2.2 Test Case: Terminate Subscription (succeed_terminate_subscription)

```
 Testing ...

    ┍━ payment_multi_validator ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    │ PASS [mem: 9962346, cpu: 5223596236] succeed_terminate_subscription
    │ · with traces
    │ | Test: Terminating a Subscription
    │ | -------------------------------------
    │ | Step 1: Subscription Details
    │ | -------------------------------------
    │ | Service Currency Symbol:
    │ | h'BFA726C3C149165B108E6FF550CB1A1C4F0FDC2E9F26A9A16F48BABE'
    │ | Account Currency Symbol:
    │ | h'FB3D635C7CB573D1B9E9BFF4A64AB4F25190D29B6FD8DB94C605A218'
    │ | Payment Currency Symbol:
    │ | h'873E4FE9E41E924911BBA3EC53FF4782EFC8C0F244FB75C879F8A432'
    │ | Original Subscription Start:
    │ | 1000000
    │ | Original Subscription End:
    │ | 2593000000
    │ | Termination Time (mid-subscription):
    │ | 1297000000
    │ | Step 2: Calculating Refund and Penalty
    │ | -------------------------------------
    │ | Total Subscription Time:
    │ | 2592000000
    │ | Time Elapsed:
    │ | 1296000000
    │ | Original Payment Amount:
    │ | 10000000
    │ | Refund Amount:
    │ | 5000000
    │ | Penalty Applied:
    │ | 1000000
    │ | Step 3: Processing Termination
    │ | -------------------------------------
    │ | Payment NFT to be burned:
    │ | h'01A4028049AFDC47FB302ED59459582CB6D0545B7C6AC22504E984922830968A'
    │ | Refund Output:
    │ | 121([_ 121([_ 122([_ h'FB3D635C7CB573D1B9E9BFF4A64AB4F25190D29B6FD8DB94C605A218']), 122([])]), {_ h'': {_ h'': 45000000 } }, 123([_ 121([])]), 122([])])
    │ | Penalty Output:
    │ | 121([_ 121([_ 122([_ h'BFA726C3C149165B108E6FF550CB1A1C4F0FDC2E9F26A9A16F48BABE']), 122([])]), {_ h'': {_ h'': 41000000 } }, 123([_ 121([_ h'000DE1400181B381ABA09DE9E68F292174345482D81DD6AA29520E0D4D837057', h'000DE140015F47F8F1A3D0FB2B1B3E9858E3AB77725785678981507D8920A19D', 121([_ h'', h'']), 1000000])]), 122([])])
    │ | Step 4: Verifying Transaction
    │ | -------------------------------------
    │ | Transaction Inputs:
    │ | [_ 121([_ 121([_ 121([_ h'EE155ACE9C40292074CB6AFF8C9CCDD273C81648FF1149EF36BCEA6E']), 1]), 121([_ 121([_ 122([_ h'873E4FE9E41E924911BBA3EC53FF4782EFC8C0F244FB75C879F8A432']), 122([])]), {_ h'': {_ h'': 4000000 }, h'FB3D635C7CB573D1B9E9BFF4A64AB4F25190D29B6FD8DB94C605A218': {_ h'000DE140015F47F8F1A3D0FB2B1B3E9858E3AB77725785678981507D8920A19D': 1 } }, 123([_ 121([])]), 122([])])]), 121([_ 121([_ 121([_ h'BB30A42C1E62F0AFDA5F0A4E8A562F7A13A24CEA00EE81917B86B89E']), 1]), 121([_ 121([_ 122([_ h'873E4FE9E41E924911BBA3EC53FF4782EFC8C0F244FB75C879F8A432']), 122([])]), {_ h'': {_ h'': 4000000 }, h'873E4FE9E41E924911BBA3EC53FF4782EFC8C0F244FB75C879F8A432': {_ h'01A4028049AFDC47FB302ED59459582CB6D0545B7C6AC22504E984922830968A': 1 } }, 123([_ 121([_ h'000DE1400181B381ABA09DE9E68F292174345482D81DD6AA29520E0D4D837057', h'000DE140015F47F8F1A3D0FB2B1B3E9858E3AB77725785678981507D8920A19D', 121([_ h'', h'']), 10000000, 1000000, 2593000000, 2592000000, 500000, 121([_ h'', h'']), 1000000])]), 122([])])])]
    │ | Transaction Outputs:
    │ | [_ 121([_ 121([_ 122([_ h'FB3D635C7CB573D1B9E9BFF4A64AB4F25190D29B6FD8DB94C605A218']), 122([])]), {_ h'': {_ h'': 45000000 } }, 123([_ 121([])]), 122([])]), 121([_ 121([_ 122([_ h'BFA726C3C149165B108E6FF550CB1A1C4F0FDC2E9F26A9A16F48BABE']), 122([])]), {_ h'': {_ h'': 41000000 } }, 123([_ 121([_ h'000DE1400181B381ABA09DE9E68F292174345482D81DD6AA29520E0D4D837057', h'000DE140015F47F8F1A3D0FB2B1B3E9858E3AB77725785678981507D8920A19D', 121([_ h'', h'']), 1000000])]), 122([])])]
    │ | Burned Tokens:
    │ | {_ h'': {_ h'': 0 }, h'873E4FE9E41E924911BBA3EC53FF4782EFC8C0F244FB75C879F8A432': {_ h'01A4028049AFDC47FB302ED59459582CB6D0545B7C6AC22504E984922830968A': -1 } }
    │ | Step 5: Execution Result
    │ | -------------------------------------
    │ | Subscription Successfully Terminated
    │ | -------------------------------------
    │ | Test Completed!
    ┕━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 1 tests | 1 passed | 0 failed

      Summary 1 check, 0 errors, 0 warnings
```

This test verifies the contract's ability to handle early termination, applying
appropriate refunds and penalties.

#### 1.2.3 Test Case: Extend Subscription (succeed_extend_subscription)

```
   Testing ...

    ┍━ payment_multi_validator ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    │ PASS [mem: 12273923, cpu: 6360327560] succeed_extend_subscription
    │ · with traces
    │ | Test: Extending an Existing Subscription
    │ | -------------------------------------
    │ | Step 1: Current Subscription Details
    │ | -------------------------------------
    │ | Service Currency Symbol:
    │ | h'BFA726C3C149165B108E6FF550CB1A1C4F0FDC2E9F26A9A16F48BABE'
    │ | Account Currency Symbol:
    │ | h'FB3D635C7CB573D1B9E9BFF4A64AB4F25190D29B6FD8DB94C605A218'
    │ | Current Subscription Start:
    │ | 1000000
    │ | Current Subscription End:
    │ | 2593000000
    │ | Current Subscription Fee: (lovelace)
    │ | 10000000
    │ | Step 2: Extension Details
    │ | -------------------------------------
    │ | Extension Period: (days)
    │ | 30
    │ | New Subscription End:
    │ | 5185000000
    │ | Additional Fee for Extension: (lovelace)
    │ | 10000000
    │ | Step 3: Updating Payment Datum
    │ | -------------------------------------
    │ | Original Payment Datum:
    │ | 121([_ h'000643B00136752529784C15E638DA2A27FB1C00C9C8B92277913A8DC40A86D4', h'000DE140015F47F8F1A3D0FB2B1B3E9858E3AB77725785678981507D8920A19D', 121([_ h'', h'']), 10000000, 1000000, 2593000000, 2592000000, 500000, 121([_ h'', h'']), 1000000])
    │ | Updated Payment Datum:
    │ | 121([_ h'000643B00136752529784C15E638DA2A27FB1C00C9C8B92277913A8DC40A86D4', h'000DE140015F47F8F1A3D0FB2B1B3E9858E3AB77725785678981507D8920A19D', 121([_ h'', h'']), 20000000, 1000000, 5185000000, 5184000000, 500000, 121([_ h'', h'']), 1000000])
    │ | Step 4: Verifying Transaction
    │ | -------------------------------------
    │ | Transaction Inputs:
    │ | [_ 121([_ 121([_ 121([_ h'EE155ACE9C40292074CB6AFF8C9CCDD273C81648FF1149EF36BCEA6E']), 1]), 121([_ 121([_ 122([_ h'FB3D635C7CB573D1B9E9BFF4A64AB4F25190D29B6FD8DB94C605A218']), 122([])]), {_ h'': {_ h'': 4000000 }, h'FB3D635C7CB573D1B9E9BFF4A64AB4F25190D29B6FD8DB94C605A218': {_ h'000DE140015F47F8F1A3D0FB2B1B3E9858E3AB77725785678981507D8920A19D': 1 } }, 123([_ 121([])]), 122([])])]), 121([_ 121([_ 121([_ h'BB30A42C1E62F0AFDA5F0A4E8A562F7A13A24CEA00EE81917B86B89E']), 1]), 121([_ 121([_ 122([_ h'873E4FE9E41E924911BBA3EC53FF4782EFC8C0F244FB75C879F8A432']), 122([])]), {_ h'': {_ h'': 14000000 }, h'873E4FE9E41E924911BBA3EC53FF4782EFC8C0F244FB75C879F8A432': {_ h'01A4028049AFDC47FB302ED59459582CB6D0545B7C6AC22504E984922830968A': 1 } }, 123([_ 121([_ h'000643B00136752529784C15E638DA2A27FB1C00C9C8B92277913A8DC40A86D4', h'000DE140015F47F8F1A3D0FB2B1B3E9858E3AB77725785678981507D8920A19D', 121([_ h'', h'']), 10000000, 1000000, 2593000000, 2592000000, 500000, 121([_ h'', h'']), 1000000])]), 122([])])])]
    │ | Transaction Outputs:
    │ | [_ 121([_ 121([_ 121([_ h'642206314F534B29AD297D82440A5F9F210E30CA5CED805A587CA402']), 122([])]), {_ h'': {_ h'': 7000000 } }, 123([_ 121([])]), 122([])]), 121([_ 121([_ 122([_ h'873E4FE9E41E924911BBA3EC53FF4782EFC8C0F244FB75C879F8A432']), 122([])]), {_ h'': {_ h'': 60000000 }, h'873E4FE9E41E924911BBA3EC53FF4782EFC8C0F244FB75C879F8A432': {_ h'01A4028049AFDC47FB302ED59459582CB6D0545B7C6AC22504E984922830968A': 1 } }, 123([_ 121([_ h'000643B00136752529784C15E638DA2A27FB1C00C9C8B92277913A8DC40A86D4', h'000DE140015F47F8F1A3D0FB2B1B3E9858E3AB77725785678981507D8920A19D', 121([_ h'', h'']), 20000000, 1000000, 5185000000, 5184000000, 500000, 121([_ h'', h'']), 1000000])]), 122([])])]
    │ | Reference Inputs:
    │ | [_ 121([_ 121([_ 121([_ h'BFA726C3C149165B108E6FF550CB1A1C4F0FDC2E9F26A9A16F48BABE']), 1]), 121([_ 121([_ 122([_ h'BFA726C3C149165B108E6FF550CB1A1C4F0FDC2E9F26A9A16F48BABE']), 122([])]), {_ h'': {_ h'': 4000000 }, h'BFA726C3C149165B108E6FF550CB1A1C4F0FDC2E9F26A9A16F48BABE': {_ h'000643B00136752529784C15E638DA2A27FB1C00C9C8B92277913A8DC40A86D4': 1 } }, 123([_ 121([_ 121([_ h'', h'']), 10000000, 121([_ h'', h'']), 1000000, 2592000000])]), 122([])])])]
    │ | Step 5: Execution Result
    │ | -------------------------------------
    │ | Subscription Successfully Extended!
    │ | -------------------------------------
    │ | Test Completed!
    │ | token_name
    │ | h'01A4028049AFDC47FB302ED59459582CB6D0545B7C6AC22504E984922830968A'
    │ | token_quantity
    │ | 1
    ┕━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 1 tests | 1 passed | 0 failed

      Summary 1 check, 0 errors, 0 warnings
```

This test demonstrates the contract's ability to extend an existing
subscription, showcasing the flexibility offered to subscribers. It shows:

- Accurate calculation of the new subscription end date
- Correct fee adjustment for the extension
- Proper updating of the Payment Datum
- Successful execution of the extension transaction

#### 1.2.4 Test Case: Unsubscribe (succeed_unsubscribe)

```
 Testing ...

    ┍━ payment_multi_validator ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    │ PASS [mem: 10762648, cpu: 5561032434] succeed_unsubscribe
    │ · with traces
    │ | Test: Unsubscribing from a Service
    │ | -------------------------------------
    │ | Step 1: Current Subscription Details
    │ | -------------------------------------
    │ | Original Subscription Fee: (lovelace)
    │ | 10000000
    │ | Subscription period: (days)
    │ | 30
    │ | Unsubscribe Details:
    │ | Time elapsed: (days)
    │ | 15
    │ | Refund Amount: (lovelace)
    │ | 5000000
    │ | Penalty Fee: (lovelace)
    │ | 1000000
    │ | Refunded to user:
    │ | 5000000
    │ | Penalty retained:
    │ | 1000000
    │ | Step 2: Unsubscribe Process
    │ | -------------------------------------
    │ | Time of Unsubscription:
    │ | 1000000
    │ | Refund Amount:
    │ | 5000000
    │ | Penalty Amount:
    │ | 1000000
    │ | Step 3: Verifying Outputs
    │ | -------------------------------------
    │ | Refund Output:
    │ | 121([_ 121([_ 122([_ h'FB3D635C7CB573D1B9E9BFF4A64AB4F25190D29B6FD8DB94C605A218']), 122([])]), {_ h'': {_ h'': 45000000 } }, 123([_ 121([])]), 122([])])
    │ | Penalty Output:
    │ | 121([_ 121([_ 122([_ h'873E4FE9E41E924911BBA3EC53FF4782EFC8C0F244FB75C879F8A432']), 122([])]), {_ h'': {_ h'': 41000000 }, h'873E4FE9E41E924911BBA3EC53FF4782EFC8C0F244FB75C879F8A432': {_ h'01A4028049AFDC47FB302ED59459582CB6D0545B7C6AC22504E984922830968A': 1 } }, 123([_ 121([_ h'000DE140012D206CCB81FDF7C4138C04D3AB3336B925D8A22432B292AD97AF6F', h'000DE1400136752529784C15E638DA2A27FB1C00C9C8B92277913A8DC40A86D4', 121([_ h'', h'']), 1000000])]), 122([])])
    │ | Step 4: Validating Transaction
    │ | -------------------------------------
    │ | Transaction Inputs:
    │ | [_ 121([_ 121([_ 121([_ h'EE155ACE9C40292074CB6AFF8C9CCDD273C81648FF1149EF36BCEA6E']), 1]), 121([_ 121([_ 122([_ h'FB3D635C7CB573D1B9E9BFF4A64AB4F25190D29B6FD8DB94C605A218']), 122([])]), {_ h'': {_ h'': 4000000 }, h'FB3D635C7CB573D1B9E9BFF4A64AB4F25190D29B6FD8DB94C605A218': {_ h'000DE1400136752529784C15E638DA2A27FB1C00C9C8B92277913A8DC40A86D4': 1 } }, 123([_ 121([])]), 122([])])]), 121([_ 121([_ 121([_ h'BB30A42C1E62F0AFDA5F0A4E8A562F7A13A24CEA00EE81917B86B89E']), 1]), 121([_ 121([_ 122([_ h'873E4FE9E41E924911BBA3EC53FF4782EFC8C0F244FB75C879F8A432']), 122([])]), {_ h'': {_ h'': 14000000 }, h'873E4FE9E41E924911BBA3EC53FF4782EFC8C0F244FB75C879F8A432': {_ h'01A4028049AFDC47FB302ED59459582CB6D0545B7C6AC22504E984922830968A': 1 } }, 123([_ 121([_ h'000DE140012D206CCB81FDF7C4138C04D3AB3336B925D8A22432B292AD97AF6F', h'000DE1400136752529784C15E638DA2A27FB1C00C9C8B92277913A8DC40A86D4', 121([_ h'', h'']), 10000000, 1000000, 2593000000, 2592000000, 500000, 121([_ h'', h'']), 1000000])]), 122([])])])]
    │ | Transaction Outputs:
    │ | [_ 121([_ 121([_ 122([_ h'FB3D635C7CB573D1B9E9BFF4A64AB4F25190D29B6FD8DB94C605A218']), 122([])]), {_ h'': {_ h'': 45000000 } }, 123([_ 121([])]), 122([])]), 121([_ 121([_ 122([_ h'873E4FE9E41E924911BBA3EC53FF4782EFC8C0F244FB75C879F8A432']), 122([])]), {_ h'': {_ h'': 41000000 }, h'873E4FE9E41E924911BBA3EC53FF4782EFC8C0F244FB75C879F8A432': {_ h'01A4028049AFDC47FB302ED59459582CB6D0545B7C6AC22504E984922830968A': 1 } }, 123([_ 121([_ h'000DE140012D206CCB81FDF7C4138C04D3AB3336B925D8A22432B292AD97AF6F', h'000DE1400136752529784C15E638DA2A27FB1C00C9C8B92277913A8DC40A86D4', 121([_ h'', h'']), 1000000])]), 122([])])]
    │ | Minted Tokens:
    │ | {_ h'': {_ h'': 0 }, h'873E4FE9E41E924911BBA3EC53FF4782EFC8C0F244FB75C879F8A432': {_ h'01A4028049AFDC47FB302ED59459582CB6D0545B7C6AC22504E984922830968A': 1 } }
    │ | Step 5: Execution Result
    │ | -------------------------------------
    │ | Unsubscription Successfully Processed!
    │ | -------------------------------------
    │ | Test Completed!
    │ | token_name
    │ | h'01A4028049AFDC47FB302ED59459582CB6D0545B7C6AC22504E984922830968A'
    │ | token_quantity
    │ | 1
    ┕━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 1 tests | 1 passed | 0 failed

      Summary 1 check, 0 errors, 0 warnings
```

This test verifies the contract's ability to process an unsubscription. It
demonstrates:

- Accurate calculation of refund and penalty amounts
- Proper distribution of funds (refund to subscriber, penalty to designated
  UTxO)
- Correct burning of the Payment NFT

#### 1.2.5 Test Case: Withdrawing Subscription Fees by Merchant (succeed_merchant_withdraw)

```
    Testing ...

    ┍━ payment_multi_validator ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    │ PASS [mem: 4860677, cpu: 2504579953] succeed_merchant_withdraw
    │ · with traces
    │ | Test: Withdrawing Subscription Fees
    │ | -------------------------------------
    │ | Step 1: Current Contract State
    │ | -------------------------------------
    │ | Service Currency Symbol:
    │ | h'BFA726C3C149165B108E6FF550CB1A1C4F0FDC2E9F26A9A16F48BABE'
    │ | Payment Currency Symbol:
    │ | h'873E4FE9E41E924911BBA3EC53FF4782EFC8C0F244FB75C879F8A432'
    │ | Subscription Start:
    │ | 1000000
    │ | Subscription End:
    │ | 10369000000
    │ | Total Subscription Fee: (lovelace)
    │ | 10000000
    │ | Last Claimed:
    │ | 1000000
    │ | Current Time:
    │ | 5185000000
    │ | Step 2: Withdrawal Calculation
    │ | -------------------------------------
    │ | Time Elapsed: (days)
    │ | 60
    │ | Withdrawable Amount: (lovelace)
    │ | 5000000
    │ | Actual Withdrawal: (lovelace)
    │ | 5000000
    │ | Step 3: Verifying Outputs
    │ | -------------------------------------
    │ | Merchant Output:
    │ | 121([_ 121([_ 122([_ h'BFA726C3C149165B108E6FF550CB1A1C4F0FDC2E9F26A9A16F48BABE']), 122([])]), {_ h'': {_ h'': 5000000 }, h'BFA726C3C149165B108E6FF550CB1A1C4F0FDC2E9F26A9A16F48BABE': {_ h'000DE1400136752529784C15E638DA2A27FB1C00C9C8B92277913A8DC40A86D4': 1 } }, 123([_ 121([])]), 122([])])
    │ | Remaining Payment Output:
    │ | 121([_ 121([_ 122([_ h'873E4FE9E41E924911BBA3EC53FF4782EFC8C0F244FB75C879F8A432']), 122([])]), {_ h'': {_ h'': 45000000 }, h'873E4FE9E41E924911BBA3EC53FF4782EFC8C0F244FB75C879F8A432': {_ h'01A4028049AFDC47FB302ED59459582CB6D0545B7C6AC22504E984922830968A': 1 } }, 123([_ 121([_ h'000DE1400136752529784C15E638DA2A27FB1C00C9C8B92277913A8DC40A86D4', h'000DE140015F47F8F1A3D0FB2B1B3E9858E3AB77725785678981507D8920A19D', 121([_ h'', h'']), 5000000, 1000000, 10369000000, 10368000000, 5185000000, 121([_ h'', h'']), 1000000])]), 122([])])
    │ | Step 4: Updating Payment Datum
    │ | -------------------------------------
    │ | Original Last Claimed:
    │ | 1000000
    │ | Updated Last Claimed:
    │ | 5185000000
    │ | Step 5: Execution Result
    │ | -------------------------------------
    │ | Withdrawal Successfully Processed!
    │ | -------------------------------------
    │ | Test Completed!
    ┕━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 1 tests | 1 passed | 0 failed

      Summary 1 check, 0 errors, 0 warnings
```

This test confirms the contract's ability to process withdrawals of subscription
fees by a merchant. It shows:

- Correct calculation of withdrawable amounts based on elapsed time
- Proper distribution of funds to the merchant
- Accurate updating of the Payment Datum with new 'last claimed' time

#### 1.2.6 Test Case: Withdrawing Subscription Fees by Subscriber (succeed_subscriber_withdraw)

```
 Testing ...

    ┍━ payment_multi_validator ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    │ PASS [mem: 11870419, cpu: 6158777563] succeed_subscriber_withdraw
    │ · with traces
    │ | Test: Withdrawing from Inactive Service
    │ | -------------------------------------
    │ | Step 1: Current Contract State
    │ | -------------------------------------
    │ | Service Active Status:
    │ | 121([])
    │ | Payment Amount:
    │ | 10000000
    │ | Step 2: Withdrawal Process
    │ | -------------------------------------
    │ | Refund Amount:
    │ | 10000000
    │ | Step 3: Verifying Outputs
    │ | -------------------------------------
    │ | User Output:
    │ | 121([_ 121([_ 122([_ h'FB3D635C7CB573D1B9E9BFF4A64AB4F25190D29B6FD8DB94C605A218']), 122([])]), {_ h'': {_ h'': 50000000 }, h'FB3D635C7CB573D1B9E9BFF4A64AB4F25190D29B6FD8DB94C605A218': {_ h'000DE140015F47F8F1A3D0FB2B1B3E9858E3AB77725785678981507D8920A19D': 1 } }, 123([_ 121([])]), 122([])])
    │ | Payment Output:
    │ | 121([_ 121([_ 122([_ h'873E4FE9E41E924911BBA3EC53FF4782EFC8C0F244FB75C879F8A432']), 122([])]), {_ h'': {_ h'': 40000000 }, h'873E4FE9E41E924911BBA3EC53FF4782EFC8C0F244FB75C879F8A432': {_ h'01A4028049AFDC47FB302ED59459582CB6D0545B7C6AC22504E984922830968A': 1 } }, 123([_ 121([_ h'000DE1400136752529784C15E638DA2A27FB1C00C9C8B92277913A8DC40A86D4', h'000DE140015F47F8F1A3D0FB2B1B3E9858E3AB77725785678981507D8920A19D', 121([_ h'', h'']), 10000000, 1000000, 2593000000, 2592000000, 1000000, 121([_ h'', h'']), 1000000])]), 122([])])
    │ | Step 4: Validating Transaction
    │ | -------------------------------------
    │ | Transaction Inputs:
    │ | [_ 121([_ 121([_ 121([_ h'EE155ACE9C40292074CB6AFF8C9CCDD273C81648FF1149EF36BCEA6E']), 1]), 121([_ 121([_ 122([_ h'FB3D635C7CB573D1B9E9BFF4A64AB4F25190D29B6FD8DB94C605A218']), 122([])]), {_ h'': {_ h'': 4000000 }, h'FB3D635C7CB573D1B9E9BFF4A64AB4F25190D29B6FD8DB94C605A218': {_ h'000DE140015F47F8F1A3D0FB2B1B3E9858E3AB77725785678981507D8920A19D': 1 } }, 123([_ 121([])]), 122([])])]), 121([_ 121([_ 121([_ h'BB30A42C1E62F0AFDA5F0A4E8A562F7A13A24CEA00EE81917B86B89E']), 1]), 121([_ 121([_ 122([_ h'873E4FE9E41E924911BBA3EC53FF4782EFC8C0F244FB75C879F8A432']), 122([])]), {_ h'': {_ h'': 14000000 }, h'873E4FE9E41E924911BBA3EC53FF4782EFC8C0F244FB75C879F8A432': {_ h'01A4028049AFDC47FB302ED59459582CB6D0545B7C6AC22504E984922830968A': 1 } }, 123([_ 121([_ h'000DE1400136752529784C15E638DA2A27FB1C00C9C8B92277913A8DC40A86D4', h'000DE140015F47F8F1A3D0FB2B1B3E9858E3AB77725785678981507D8920A19D', 121([_ h'', h'']), 10000000, 1000000, 2593000000, 2592000000, 1000000, 121([_ h'', h'']), 1000000])]), 122([])])])]
    │ | Transaction Outputs:
    │ | [_ 121([_ 121([_ 122([_ h'FB3D635C7CB573D1B9E9BFF4A64AB4F25190D29B6FD8DB94C605A218']), 122([])]), {_ h'': {_ h'': 50000000 }, h'FB3D635C7CB573D1B9E9BFF4A64AB4F25190D29B6FD8DB94C605A218': {_ h'000DE140015F47F8F1A3D0FB2B1B3E9858E3AB77725785678981507D8920A19D': 1 } }, 123([_ 121([])]), 122([])]), 121([_ 121([_ 122([_ h'873E4FE9E41E924911BBA3EC53FF4782EFC8C0F244FB75C879F8A432']), 122([])]), {_ h'': {_ h'': 40000000 }, h'873E4FE9E41E924911BBA3EC53FF4782EFC8C0F244FB75C879F8A432': {_ h'01A4028049AFDC47FB302ED59459582CB6D0545B7C6AC22504E984922830968A': 1 } }, 123([_ 121([_ h'000DE1400136752529784C15E638DA2A27FB1C00C9C8B92277913A8DC40A86D4', h'000DE140015F47F8F1A3D0FB2B1B3E9858E3AB77725785678981507D8920A19D', 121([_ h'', h'']), 10000000, 1000000, 2593000000, 2592000000, 1000000, 121([_ h'', h'']), 1000000])]), 122([])])]
    │ | Tokens:
    │ | {_ h'': {_ h'': 0 }, h'873E4FE9E41E924911BBA3EC53FF4782EFC8C0F244FB75C879F8A432': {_ h'01A4028049AFDC47FB302ED59459582CB6D0545B7C6AC22504E984922830968A': -1 } }
    │ | Step 5: Execution Result
    │ | -------------------------------------
    │ | Withdrawal from Inactive Service Successfully Processed!
    │ | -------------------------------------
    │ | Test Completed!
    ┕━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 1 tests | 1 passed | 0 failed

      Summary 1 check, 0 errors, 0 warnings
```

This test verifies the contract's ability to process withdrawals of subscription
fees by a subscriber when the service becomes inactive. It demonstrates:

- Correct identification of an inactive service
- Full refund of the subscription amount to the subscriber
- Proper burning of the Payment NFT
- Accurate updating of the Payment UTxO

### 1.3 User Workflow for Managing Recurring Payments

The following outlines the user workflow for managing recurring payments:

1. **Initiate Subscription:**
   - User selects a service and subscription period
   - Smart contract mints a Payment NFT and locks the subscription fee
   - User receives confirmation of successful subscription
2. **Extend Subscription:**
   - User chooses to extend their subscription
   - Smart contract calculates additional fee and new end date
   - User approves the extension
   - Contract updates the Payment Datum with new details
3. **Unsubscribe:**
   - User requests to end their subscription
   - Contract calculates refund and penalty amounts
   - User receives refund, minus any applicable penalties
   - Payment NFT is burned, ending the subscription
4. **Merchant Withdrawal:**
   - Merchant can withdraw accrued fees at any time
   - Contract calculates withdrawable amount based on elapsed time
   - Remaining funds stay locked until the next withdrawal or end of
     subscription
5. **Subscriber Withdrawal:**

- Subscriber can withdraw remaining funds if the service becomes inactive
- Contract verifies the inactive status of the service
- Full remaining subscription amount is refunded to the subscriber
- Payment NFT is burned, finalizing the withdrawal

This workflow demonstrates the ease with which users can manage their recurring
payments, from initiation to termination, directly from their wallets.

## Conclusion

The Payment Subscription Smart Contract demonstrates robust functionality and
ease of use. Through comprehensive testing and thoughtful implementation, it
effectively manages recurring payments, allowing users to initiate, extend, and
terminate subscriptions directly from their preferred wallet applications.

These features collectively ensure that the contract meets the needs of both
service providers and subscribers, offering a secure and user-friendly solution
for managing subscription-based services on the Cardano blockchain.
