# Aqua0 Cross-Chain Swap - Mermaid Sequence Diagram

## Complete Cross-Chain Swap Flow (World → Base → World)

```mermaid
sequenceDiagram
    participant Frontend as Frontend<br/>(World App)
    participant Wallet as User Wallet<br/>(World Chain)
    participant IntentPool as IntentPool<br/>(World Chain)
    participant Stargate as Stargate<br/>(OFT Bridge)
    participant LZ as LayerZero<br/>(DVN + Executor)
    participant Composer as CrossChainSwap<br/>Composer (Base)
    participant Aqua as Aqua<br/>(Base Chain)
    participant AMM as StableswapAMM<br/>(Base Chain)
    participant LP as LP Wallet<br/>(World Chain)

    Note over Frontend,LP: 1. World ID Authentication & Setup
    Frontend->>Wallet: 1. World ID verification (Orb level)
    Wallet-->>Frontend: Verified + nullifier_hash
    Frontend->>Wallet: 2. walletAuth() to get address
    Wallet-->>Frontend: Wallet address

    Note over Frontend,LP: 2. Intent Submission
    Frontend->>Frontend: 3. Query available strategies<br/>from Supabase
    Frontend->>Wallet: 4. User selects quote & submits intent
    Wallet->>IntentPool: 5. submitIntent(<br/>strategyHash, tokenIn,<br/>tokenOut, amountIn, minOut)
    IntentPool->>IntentPool: 6. transferFrom(trader, pool, USDT, 100e6)
    IntentPool->>IntentPool: 7. Store intent (status: PENDING)
    IntentPool-->>Frontend: Event: IntentSubmitted(intentId)

    Note over Frontend,LP: 3. LP Fulfills Intent
    LP->>IntentPool: 8. fulfillIntent(intentId, actualOut)
    IntentPool->>IntentPool: 9. transferFrom(LP, pool, rUSD, 99.7e6)
    IntentPool->>IntentPool: 10. Update status: MATCHED
    IntentPool-->>Frontend: Event: IntentFulfilled

    Note over Frontend,LP: 4. Settlement & Dual Bridge
    Frontend->>IntentPool: 11. settleIntent(intentId)
    IntentPool->>IntentPool: 12. Build compose payload:<br/>(intentId, trader, LP,<br/>strategyHash, amounts)
    
    IntentPool->>Stargate: 13. Stargate.send() Part 1<br/>(LP's rUSD for trader)
    Stargate->>LZ: 14. Bridge rUSD World → Base
    LZ->>Composer: 15. Deliver rUSD to Composer
    Composer->>Composer: 16. lzCompose() receives rUSD<br/>Store in pendingSwaps

    IntentPool->>Stargate: 17. Stargate.send() Part 2<br/>(Trader's USDT for swap)
    Stargate->>LZ: 18. Bridge USDT World → Base
    LZ->>Composer: 19. Deliver USDT to Composer
    Composer->>Composer: 20. lzCompose() receives USDT<br/>Check both tokens arrived

    Note over Frontend,LP: 5. Execute Swap on Base
    Composer->>Aqua: 21. pullOnBehalfOf(<br/>LP, composer, strategyHash,<br/>rUSD, 99.7e6, composer)
    Aqua->>Aqua: 22. Reduce LP's virtual balance
    Aqua->>LP: 23. transferFrom(LP, composer, rUSD, 99.7e6)
    Aqua-->>Composer: rUSD tokens received

    Composer->>AMM: 24. swapExactIn(<br/>strategy, zeroForOne: true,<br/>amountIn: 100e6, minOut: 99.5e6,<br/>to: composer, takerData)
    
    AMM->>Aqua: 25. safeBalances() get virtual balances
    Aqua-->>AMM: balanceIn, balanceOut
    AMM->>AMM: 26. Calculate amountOut<br/>using Stableswap formula
    
    AMM->>Aqua: 27. pull(LP, strategyHash,<br/>USDT, 99.7e6, composer)
    Aqua->>Aqua: 28. Reduce LP's virtual USDT balance
    Aqua->>LP: 29. transferFrom(LP, composer, USDT, 99.7e6)
    Aqua-->>AMM: USDT tokens transferred

    AMM->>Composer: 30. stableswapCallback()
    Composer->>Aqua: 31. pushOnBehalfOf(<br/>LP, composer, AMM,<br/>strategyHash, rUSD, 100e6)
    Aqua->>Aqua: 32. transferFrom(composer, Aqua, rUSD)
    Aqua->>Aqua: 33. Increase LP's virtual rUSD balance
    Aqua-->>Composer: Push complete
    Composer-->>AMM: Callback complete
    AMM-->>Composer: Swap complete (amountOut: 99.7e6)

    Note over Frontend,LP: 6. Bridge Back & Distribute
    Composer->>Stargate: 34. Bridge USDT back to World (to LP)
    Stargate->>LZ: 35. Bridge USDT Base → World
    LZ->>IntentPool: 36. Deliver USDT to IntentPool
    IntentPool->>LP: 37. Transfer USDT to LP

    Composer->>Stargate: 38. Bridge rUSD back to World (to Trader)
    Stargate->>LZ: 39. Bridge rUSD Base → World
    LZ->>IntentPool: 40. Deliver rUSD to IntentPool
    IntentPool->>Wallet: 41. Transfer rUSD to Trader

    IntentPool->>IntentPool: 42. Update status: SETTLED
    IntentPool-->>Frontend: Event: IntentSettled
    Frontend->>Frontend: 43. Display success UI
```

## LP Creates Cross-Chain Strategy Flow

```mermaid
sequenceDiagram
    participant Frontend as Frontend<br/>(World App)
    participant Wallet as User Wallet<br/>(World Chain)
    participant Composer as AquaStrategy<br/>Composer (World)
    participant LZ as LayerZero<br/>(DVN + Executor)
    participant Aqua as Aqua<br/>(Base Chain)
    participant AMM as StableswapAMM<br/>(Base Chain)

    Note over Frontend,AMM: 1. Authentication & Strategy Setup
    Frontend->>Wallet: 1. World ID verification
    Wallet-->>Frontend: Verified
    Frontend->>Wallet: 2. walletAuth() get address
    Wallet-->>Frontend: LP address

    Frontend->>Frontend: 3. Build strategy struct:<br/>- maker (LP address)<br/>- token0, token1<br/>- feeBps<br/>- amplificationFactor<br/>- salt

    Note over Frontend,AMM: 2. Quote & Send Transaction
    Frontend->>Composer: 4. quoteShipStrategy(<br/>dstEid: BASE_EID,<br/>targetApp: StableswapAMM,<br/>strategy, tokenIds, amounts)
    Composer-->>Frontend: nativeFee (LayerZero cost)

    Frontend->>Wallet: 5. sendTransaction()
    Wallet->>Composer: 6. shipStrategyToChain(<br/>dstEid, targetApp,<br/>encodedStrategy, tokenIds,<br/>amounts, options)<br/>{value: nativeFee}

    Note over Frontend,AMM: 3. Cross-Chain Messaging
    Composer->>Composer: 7. Verify tokens in registry
    Composer->>Composer: 8. Encode LZ message:<br/>(maker, app, strategy,<br/>tokenIds, amounts)
    
    Composer->>LZ: 9. _lzSend() to Base chain
    LZ->>LZ: 10. DVN verifies message<br/>across multiple nodes
    LZ->>LZ: 11. Executor delivers message
    LZ->>Aqua: 12. lzReceive() on Base Composer

    Note over Frontend,AMM: 4. Strategy Deployment on Base
    Aqua->>Aqua: 13. Decode message<br/>Resolve token IDs to addresses
    Aqua->>Aqua: 14. aqua.shipOnBehalfOf(<br/>maker, StableswapAMM,<br/>strategy, [USDC, USDT],<br/>[1000e6, 1000e6])
    
    Aqua->>Aqua: 15. Verify composer is<br/>trusted delegate
    Aqua->>Aqua: 16. Calculate strategyHash:<br/>keccak256(strategy)
    Aqua->>Aqua: 17. Store virtual balances:<br/>_balances[maker][app]<br/>[hash][token] = amount
    
    Aqua-->>Composer: strategyHash
    Composer-->>Frontend: Event: CrossChainShipExecuted
    Frontend->>Frontend: 18. Display success UI
```

## Direct Swap on Base Chain (Local)

```mermaid
sequenceDiagram
    participant Trader as Trader<br/>Contract
    participant AMM as StableswapAMM<br/>(Base Chain)
    participant Aqua as Aqua<br/>(Base Chain)
    participant LP as LP Wallet<br/>(Base Chain)
    participant Recipient as Recipient<br/>Wallet

    Note over Trader,Recipient: 1. Initiate Swap
    Trader->>AMM: 1. swapExactIn(<br/>strategy, zeroForOne,<br/>amountIn, amountOutMin,<br/>recipient, takerData)

    Note over Trader,Recipient: 2. Calculate & Verify
    AMM->>AMM: 2. Calculate strategyHash:<br/>keccak256(strategy)
    AMM->>AMM: 3. Lock strategy<br/>(reentrancy guard)
    
    AMM->>Aqua: 4. safeBalances(<br/>maker, app, strategyHash,<br/>tokenIn, tokenOut)
    Aqua-->>AMM: balanceIn, balanceOut

    AMM->>AMM: 5. Calculate amountOut:<br/>weight = A/(A+1)<br/>out = weight*constantSum +<br/>(1-weight)*constantProduct
    AMM->>AMM: 6. Verify amountOut >= amountOutMin

    Note over Trader,Recipient: 3. Pull Output Tokens
    AMM->>Aqua: 7. pull(maker, strategyHash,<br/>tokenOut, amountOut, recipient)
    Aqua->>Aqua: 8. Reduce virtual balance
    Aqua->>LP: 9. transferFrom(LP, recipient,<br/>tokenOut, amountOut)
    LP->>Recipient: 10. Transfer tokenOut
    Aqua-->>AMM: Pull complete

    Note over Trader,Recipient: 4. Push Input Tokens (Callback)
    AMM->>Trader: 11. stableswapCallback(<br/>tokenIn, tokenOut, amountIn,<br/>amountOut, maker, app,<br/>strategyHash, takerData)
    
    Trader->>Aqua: 12. Approve tokenIn to Aqua
    Trader->>Aqua: 13. push(maker, app,<br/>strategyHash, tokenIn, amountIn)
    
    Aqua->>Trader: 14. transferFrom(trader, Aqua,<br/>tokenIn, amountIn)
    Aqua->>Aqua: 15. Increase virtual balance
    Aqua-->>Trader: Push complete
    Trader-->>AMM: Callback complete

    Note over Trader,Recipient: 5. Finalize
    AMM->>Aqua: 16. _safeCheckAquaPush()<br/>Verify balance increased
    Aqua-->>AMM: Verified
    AMM->>AMM: 17. Unlock strategy
    AMM-->>Trader: amountOut
```

## Architecture Overview

```mermaid
graph TB
    subgraph "World Chain"
        Frontend[Frontend<br/>World App]
        WorldID[World ID<br/>Verification]
        Wallet1[User Wallet]
        IntentPool[IntentPool<br/>Intent Matching]
        Composer1[AquaStrategy<br/>Composer]
        Stargate1[Stargate OFT]
    end

    subgraph "LayerZero Infrastructure"
        DVN[DVN<br/>Verification]
        Executor[Executor<br/>Delivery]
    end

    subgraph "Base Chain"
        Composer2[CrossChainSwap<br/>Composer]
        Aqua[Aqua Protocol<br/>Virtual Balances]
        AMM1[StableswapAMM]
        AMM2[ConcentratedLiquidity<br/>Swap]
        Stargate2[Stargate OFT]
        Wallet2[LP Wallet]
    end

    subgraph "Off-Chain"
        Supabase[Supabase<br/>Strategy Index]
    end

    Frontend -->|1. Auth| WorldID
    Frontend -->|2. Query| Supabase
    Frontend -->|3. Submit| IntentPool
    Frontend -->|4. Ship Strategy| Composer1
    
    Composer1 -->|5. Send Message| DVN
    DVN -->|6. Verify| Executor
    Executor -->|7. Deliver| Composer2
    
    IntentPool -->|8. Bridge Tokens| Stargate1
    Stargate1 -->|9. Cross-Chain| Stargate2
    Stargate2 -->|10. Deliver| Composer2
    
    Composer2 -->|11. Execute| Aqua
    Aqua -->|12. Pull/Push| Wallet2
    Aqua -->|13. Swap| AMM1
    Aqua -->|14. Swap| AMM2
    
    Composer2 -->|15. Bridge Back| Stargate2
    Stargate2 -->|16. Return| Stargate1
    Stargate1 -->|17. Distribute| Wallet1

    style Frontend fill:#e1f5ff
    style WorldID fill:#ffe1e1
    style Aqua fill:#e1ffe1
    style DVN fill:#fff5e1
    style Executor fill:#fff5e1
```

## Component Interaction Matrix

```mermaid
graph LR
    subgraph "User Layer"
        A[LP] -->|Creates Strategy| B[Frontend]
        C[Trader] -->|Submits Intent| B
    end

    subgraph "World Chain Layer"
        B -->|Ships Strategy| D[AquaStrategyComposer]
        B -->|Submits Intent| E[IntentPool]
        E -->|Bridges Tokens| F[Stargate World]
    end

    subgraph "Cross-Chain Layer"
        D -->|Sends Message| G[LayerZero]
        F -->|Bridges Tokens| G
    end

    subgraph "Base Chain Layer"
        G -->|Delivers Message| H[Aqua Base]
        G -->|Delivers Tokens| I[CrossChainSwapComposer]
        I -->|Executes Swap| H
        H -->|Manages Liquidity| J[StableswapAMM]
        H -->|Manages Liquidity| K[ConcentratedLiquiditySwap]
    end

    subgraph "Settlement Layer"
        I -->|Bridges Back| L[Stargate Base]
        L -->|Returns Tokens| G
        G -->|Distributes| E
    end

    style A fill:#ffcccc
    style C fill:#ccffcc
    style B fill:#ccccff
    style H fill:#ffffcc
```

---

## Key Features

- **No Token Custody**: LP tokens stay in wallets, only virtual balances tracked
- **Cross-Chain Liquidity**: Single LP position serves traders on multiple chains
- **Intent-Based Architecture**: Async matching between traders and LPs
- **Trusted Delegates**: Composers can act on behalf of LPs
- **Atomic Execution**: All-or-nothing swaps with reentrancy protection
- **Immutable Strategies**: Parameters locked after deployment for safety

---

*Generated for Aqua0 Protocol - Cross-Chain Liquidity Infrastructure*


