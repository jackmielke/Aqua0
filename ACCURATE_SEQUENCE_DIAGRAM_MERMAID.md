# Aqua0 Cross-Chain AMM - Mermaid Sequence Diagrams

## Phase 1: LP Strategy Setup (Cross-Chain Shipping)

```mermaid
sequenceDiagram
    participant LP as LP Wallet<br/>(Ethereum)
    participant Composer as AquaStrategyComposer<br/>(Ethereum)
    participant LZ as LayerZero<br/>Network
    participant BaseComposer as AquaStrategyComposer<br/>(Base)
    participant Aqua as Aqua Protocol<br/>(Base)
    participant AMM as StableswapAMM<br/>(Base)

    Note over LP,AMM: LP ships strategy from Ethereum to Base (no tokens transferred)
    
    LP->>Composer: shipStrategyToChain()<br/>dstEid: Base<br/>dstApp: StableswapAMM<br/>strategy: {maker, token0Id, token1Id, feeBps, A}<br/>tokenIds: [USDT, WGC]<br/>amounts: [2e6, 2e6]
    
    Composer->>LZ: _lzSend()<br/>Cross-chain message
    Note over Composer: Emit CrossChainShipInitiated
    
    LZ->>BaseComposer: _lzReceive()<br/>payload: {maker, app, strategy, tokenIds, amounts}
    
    BaseComposer->>BaseComposer: Resolve token IDs<br/>USDT → 0x...<br/>WGC → 0x...
    
    BaseComposer->>Aqua: shipOnBehalfOf()<br/>maker: LP address<br/>app: StableswapAMM<br/>tokens: [USDT, WGC]<br/>amounts: [2e6, 2e6]
    
    Aqua->>Aqua: Store virtual balances<br/>_balances[LP][AMM][hash][USDT] = 2e6<br/>_balances[LP][AMM][hash][WGC] = 2e6
    Note over Aqua: strategyHash = keccak256(strategy)
    
    Aqua-->>BaseComposer: strategyHash
    BaseComposer-->>LZ: CrossChainShipExecuted event
    LZ-->>LP: Strategy live on Base!
```

---

## Phase 2: Intent Submission (World Chain)

```mermaid
sequenceDiagram
    participant Trader as Trader<br/>(World Chain)
    participant USDT as USDT Token<br/>(World Chain)
    participant IntentPool as IntentPool<br/>(World Chain)
    
    Note over Trader,IntentPool: Trader submits intent to swap USDT for WGC
    
    Trader->>USDT: approve(IntentPool, 1e6)
    USDT-->>Trader: Approved
    
    Trader->>IntentPool: submitIntent()<br/>strategyHash: 0xabc...<br/>tokenIn: USDT<br/>tokenOut: WGC<br/>amountIn: 1e6<br/>expectedOut: 999600<br/>minOut: 994602<br/>deadline: now + 1h
    
    IntentPool->>USDT: transferFrom(Trader, IntentPool, 1e6)
    USDT-->>IntentPool: 1 USDT locked
    
    IntentPool->>IntentPool: Create intent<br/>intentId = keccak256(...)<br/>status = PENDING<br/>trader = 0xTrader<br/>LP = 0xLP (from strategyOwners)
    
    IntentPool-->>Trader: intentId: 0x123...<br/>Status: PENDING
    Note over IntentPool: Emit IntentSubmitted
```

---

## Phase 3: Intent Fulfillment (World Chain)

```mermaid
sequenceDiagram
    participant LP as LP<br/>(World Chain)
    participant WGC as WGC Token<br/>(World Chain)
    participant IntentPool as IntentPool<br/>(World Chain)
    
    Note over LP,IntentPool: LP fulfills trader's intent by locking WGC
    
    LP->>WGC: approve(IntentPool, 999600)
    WGC-->>LP: Approved
    
    LP->>IntentPool: fulfillIntent(intentId)
    
    IntentPool->>IntentPool: Validate<br/>status == PENDING<br/>msg.sender == LP<br/>deadline not passed
    
    IntentPool->>WGC: transferFrom(LP, IntentPool, 999600)
    WGC-->>IntentPool: 999600 WGC locked
    
    IntentPool->>IntentPool: Update intent<br/>status = MATCHED<br/>actualOut = 999600
    
    IntentPool-->>LP: Intent fulfilled!<br/>Status: MATCHED
    Note over IntentPool: Emit IntentFulfilled
```

---

## Phase 4: Settlement - Dual Token Bridge (World → Base)

```mermaid
sequenceDiagram
    participant Settler as Settler<br/>(World Chain)
    participant IntentPool as IntentPool<br/>(World Chain)
    participant WGC_OFT as WGC OFT<br/>(World Chain)
    participant USDT_OFT as USDT OFT<br/>(World Chain)
    participant LZ as LayerZero +<br/>Stargate
    participant Composer as CrossChainSwapComposer<br/>(Base)
    
    Note over Settler,Composer: Settler triggers dual token bridge to Base
    
    Settler->>IntentPool: settleIntent(intentId, gasLimit)<br/>{value: 0.01 ETH}
    
    IntentPool->>IntentPool: Build Part 1 compose message<br/>(uint8(1), intentId, LP, 999600)
    IntentPool->>IntentPool: Build Part 2 compose message<br/>(uint8(2), intentId, trader, LP, 1e6, hash, minOut)
    
    IntentPool->>WGC_OFT: approve(999600)
    IntentPool->>USDT_OFT: approve(1e6)
    
    IntentPool->>WGC_OFT: send()<br/>to: Composer<br/>amount: 999600<br/>composeMsg: Part 1
    Note over IntentPool,WGC_OFT: Part 1: LP's WGC for trader
    
    IntentPool->>USDT_OFT: send()<br/>to: Composer<br/>amount: 1e6<br/>composeMsg: Part 2
    Note over IntentPool,USDT_OFT: Part 2: Trader's USDT for swap
    
    IntentPool->>IntentPool: Update status: SETTLING
    
    WGC_OFT->>LZ: Bridge WGC to Base
    USDT_OFT->>LZ: Bridge USDT to Base
    
    LZ->>Composer: Deliver WGC + Part 1 message
    LZ->>Composer: Deliver USDT + Part 2 message
    
    Note over Composer: Both tokens + messages<br/>arrive at Composer
```

---

## Phase 5: Swap Execution on Base

```mermaid
sequenceDiagram
    participant Composer as CrossChainSwapComposer<br/>(Base)
    participant AMM as StableswapAMM<br/>(Base)
    participant Aqua as Aqua Protocol<br/>(Base)
    participant LP_Wallet as LP Wallet<br/>(Base)
    
    Note over Composer,LP_Wallet: Composer executes swap after both tokens arrive
    
    Composer->>Composer: lzCompose() - Part 1<br/>WGC arrives (999600)
    Composer->>Composer: _handlePart1()<br/>Store: tokenOutAmount = 999600<br/>partsReceived = 1
    
    Composer->>Composer: lzCompose() - Part 2<br/>USDT arrives (1e6)
    Composer->>Composer: _handlePart2()<br/>Store: tokenInAmount = 1e6<br/>partsReceived = 2
    
    Note over Composer: Both parts received!
    
    Composer->>Composer: _executeDualSwap()<br/>Build strategy struct
    
    Composer->>AMM: swapExactIn()<br/>strategy: {LP, USDT, WGC, 4bps, A:100}<br/>amountIn: 1e6<br/>minOut: 994602<br/>to: Composer
    
    AMM->>AMM: Calculate swap output<br/>Stableswap formula<br/>amountOut ≈ 999200
    
    AMM->>Aqua: pullOnBehalfOf()<br/>Pull WGC from LP's virtual balance<br/>token: WGC, amount: 999200
    
    Aqua->>Aqua: Update virtual balance<br/>_balances[LP][AMM][hash][WGC] -= 999200
    
    Aqua->>LP_Wallet: transferFrom()<br/>Pull 999200 WGC from LP wallet
    LP_Wallet-->>Aqua: WGC transferred
    
    Aqua->>AMM: Transfer WGC to Composer
    AMM-->>Composer: Received 999200 WGC
    
    AMM->>Composer: stableswapCallback()<br/>Expects USDT push
    
    Composer->>Aqua: pushOnBehalfOf()<br/>Push USDT to LP's virtual balance<br/>token: USDT, amount: 1e6
    
    Aqua->>Aqua: Update virtual balance<br/>_balances[LP][AMM][hash][USDT] += 1e6
    
    Aqua->>LP_Wallet: transferFrom()<br/>Push 1e6 USDT to LP wallet
    Composer-->>Aqua: USDT transferred
    
    AMM-->>Composer: Swap complete!<br/>Composer has 999200 WGC
    
    Note over Composer: Emit SwapExecuted
```

---

## Phase 6: Bridge Tokens Back to World Chain

```mermaid
sequenceDiagram
    participant Composer as CrossChainSwapComposer<br/>(Base)
    participant WGC_OFT as WGC OFT<br/>(Base)
    participant USDT_OFT as USDT OFT<br/>(Base)
    participant LZ as LayerZero +<br/>Stargate
    participant Trader as Trader<br/>(World Chain)
    participant LP as LP<br/>(World Chain)
    
    Note over Composer,LP: Composer bridges tokens back to World Chain
    
    Composer->>WGC_OFT: _sendTokenToWorld()<br/>Send WGC to Trader<br/>amount: 999200
    
    WGC_OFT->>LZ: Bridge WGC to World Chain<br/>recipient: Trader
    
    LZ->>Trader: Deliver 999200 WGC
    Note over Trader: Trader receives WGC!
    
    Composer->>USDT_OFT: _sendTokenToWorld()<br/>Send USDT to LP<br/>amount: 1e6
    
    USDT_OFT->>LZ: Bridge USDT to World Chain<br/>recipient: LP
    
    LZ->>LP: Deliver 1e6 USDT
    Note over LP: LP receives USDT!
    
    Note over Trader,LP: Swap complete!<br/>Trader: +999200 WGC<br/>LP: +1e6 USDT
```

---

## Complete End-to-End Flow (Simplified)

```mermaid
sequenceDiagram
    participant LP as LP
    participant Trader as Trader
    participant World as World Chain<br/>(IntentPool)
    participant LZ as LayerZero +<br/>Stargate
    participant Base as Base Chain<br/>(Aqua + AMM)
    
    Note over LP,Base: Phase 1: Setup
    LP->>Base: Ship strategy via LayerZero<br/>(virtual liquidity: 2 USDT, 2 WGC)
    Base-->>LP: Strategy live!
    
    LP->>World: Register strategy in IntentPool
    World-->>LP: Strategy registered
    
    Note over LP,Base: Phase 2: Intent Matching
    Trader->>World: Submit intent<br/>(swap 1 USDT for WGC)
    World-->>Trader: Intent created (PENDING)
    
    LP->>World: Fulfill intent<br/>(lock 0.9996 WGC)
    World-->>LP: Intent matched (MATCHED)
    
    Note over LP,Base: Phase 3: Settlement & Execution
    World->>LZ: Bridge USDT + WGC to Base<br/>(dual Stargate send)
    LZ->>Base: Deliver both tokens
    
    Base->>Base: Execute swap<br/>(USDT → WGC via LP's strategy)
    Note over Base: Aqua virtual balances updated<br/>LP: USDT +1, WGC -0.9992
    
    Base->>LZ: Bridge tokens back to World
    LZ->>Trader: Deliver 0.9992 WGC
    LZ->>LP: Deliver 1 USDT
    
    Note over Trader,LP: Complete!<br/>Trader: +0.9992 WGC<br/>LP: +1 USDT (earned 0.0004 WGC fee)
```

---

## Aqua Virtual Balance State Changes

```mermaid
stateDiagram-v2
    [*] --> Shipped: ship() / shipOnBehalfOf()
    
    Shipped: Virtual Balances Initialized
    Shipped: USDT: 2e6
    Shipped: WGC: 2e6
    
    Shipped --> Active: Strategy ready for swaps
    
    Active --> Pulled: pull() / pullOnBehalfOf()
    Pulled: Decrease virtual balance
    Pulled: Transfer from LP wallet
    
    Pulled --> Active: Balance updated
    
    Active --> Pushed: push() / pushOnBehalfOf()
    Pushed: Increase virtual balance
    Pushed: Transfer to LP wallet
    
    Pushed --> Active: Balance updated
    
    Active --> Docked: dock() / dockOnBehalfOf()
    Docked: Strategy closed
    Docked: Balances set to 0
    
    Docked --> [*]
    
    note right of Shipped
        No tokens transferred
        Only virtual accounting
    end note
    
    note right of Pulled
        Real tokens pulled
        from LP wallet
    end note
    
    note right of Pushed
        Real tokens pushed
        to LP wallet
    end note
```

---

## Intent State Machine

```mermaid
stateDiagram-v2
    [*] --> PENDING: submitIntent()
    
    PENDING: Trader locked tokenIn
    PENDING: Waiting for LP
    
    PENDING --> MATCHED: fulfillIntent()
    MATCHED: LP locked tokenOut
    MATCHED: Ready to settle
    
    MATCHED --> SETTLING: settleIntent()
    SETTLING: Tokens bridging to Base
    SETTLING: Swap executing
    
    SETTLING --> SETTLED: Swap complete
    SETTLED: Tokens bridged back
    SETTLED: Intent complete
    
    PENDING --> CANCELLED: cancelIntent()
    MATCHED --> CANCELLED: cancelIntent()
    CANCELLED: Refund both parties
    
    SETTLED --> [*]
    CANCELLED --> [*]
    
    note right of PENDING
        Deadline enforced
        Can be cancelled
    end note
    
    note right of SETTLING
        Atomic execution
        Try-catch for safety
    end note
```

---

## Architecture Overview

```mermaid
graph TB
    subgraph "Ethereum Sepolia (Optional)"
        LP1[LP Wallet]
        SC1[AquaStrategyComposer]
    end
    
    subgraph "World Chain"
        Trader[Trader Wallet]
        LP2[LP Wallet]
        IntentPool[IntentPool]
        USDT_W[USDT OFT]
        WGC_W[WGC OFT]
    end
    
    subgraph "LayerZero Network"
        LZ[LayerZero Relayers]
        Stargate[Stargate Bridge]
    end
    
    subgraph "Base Sepolia"
        LP3[LP Wallet]
        Aqua[Aqua Protocol]
        AMM1[StableswapAMM]
        AMM2[ConcentratedLiquiditySwap]
        Composer1[AquaStrategyComposer]
        Composer2[CrossChainSwapComposer]
        USDT_B[USDT OFT]
        WGC_B[WGC OFT]
    end
    
    LP1 -->|1. Ship Strategy| SC1
    SC1 -->|2. LayerZero Message| LZ
    LZ -->|3. Receive & Ship| Composer1
    Composer1 -->|4. shipOnBehalfOf| Aqua
    
    Trader -->|5. Submit Intent| IntentPool
    LP2 -->|6. Fulfill Intent| IntentPool
    IntentPool -->|7. Settle| USDT_W
    IntentPool -->|7. Settle| WGC_W
    
    USDT_W -->|8. Bridge| Stargate
    WGC_W -->|8. Bridge| Stargate
    Stargate -->|9. Deliver| Composer2
    
    Composer2 -->|10. Execute Swap| AMM1
    AMM1 -->|11. Pull/Push| Aqua
    Aqua -->|12. Transfer| LP3
    
    Composer2 -->|13. Bridge Back| USDT_B
    Composer2 -->|13. Bridge Back| WGC_B
    USDT_B -->|14. Return| Stargate
    WGC_B -->|14. Return| Stargate
    Stargate -->|15. Deliver| LP2
    Stargate -->|15. Deliver| Trader
    
    style Aqua fill:#f9f,stroke:#333,stroke-width:4px
    style IntentPool fill:#bbf,stroke:#333,stroke-width:4px
    style Composer2 fill:#bfb,stroke:#333,stroke-width:4px
```

---

## Token Flow Diagram

```mermaid
graph LR
    subgraph "World Chain"
        T1[Trader: 1 USDT]
        L1[LP: 0.9996 WGC]
        IP[IntentPool]
    end
    
    subgraph "Bridge"
        SG1[Stargate →]
        SG2[← Stargate]
    end
    
    subgraph "Base Chain"
        C[Composer]
        A[Aqua]
        LPW[LP Wallet]
    end
    
    T1 -->|Lock| IP
    L1 -->|Lock| IP
    IP -->|Bridge| SG1
    SG1 -->|Deliver| C
    
    C -->|Swap| A
    A -->|Pull WGC| LPW
    LPW -->|Push USDT| A
    A -->|Return WGC| C
    
    C -->|Bridge Back| SG2
    SG2 -->|0.9992 WGC| T1
    SG2 -->|1 USDT| L1
    
    style IP fill:#bbf
    style C fill:#bfb
    style A fill:#f9f
```

---

## Key Formulas

### Stableswap AMM (Curve-style)

**Invariant:**
```
An^n ∑x_i + D = An^n D + D^(n+1)/(n^n ∏x_i)
```

**Simplified Output Calculation:**
```
weight = (A * PRECISION) / (A + 1)
amountOut = (weight * constantSumOut + (1 - weight) * constantProductOut)
```

Where:
- `A = 100` (high amplification for stablecoins)
- `constantSumOut = amountIn` (1:1 swap)
- `constantProductOut = (amountIn * balanceOut) / (balanceIn + amountIn)`

### Concentrated Liquidity (Uniswap V3-style)

**Virtual Reserves:**
```
x_virtual × y_virtual = L²
```

**Range Multiplier:**
```
if rangeWidth ≤ 10%: multiplier = 2x
if rangeWidth ≤ 50%: multiplier = 1.5x
else: multiplier = 1x
```

**Effective Output:**
```
effectiveBalanceIn = balanceIn * rangeMultiplier
effectiveBalanceOut = balanceOut * rangeMultiplier
amountOut = (amountIn * effectiveBalanceOut) / (effectiveBalanceIn + amountIn)
```

---

## Summary

This accurate sequence diagram shows:

1. **Virtual Liquidity**: LPs ship strategies without transferring tokens
2. **Intent Matching**: Traders and LPs lock tokens on World Chain
3. **Dual Bridge**: Both tokens bridge to Base via Stargate
4. **Atomic Execution**: Swap executes on Base using Aqua's virtual balances
5. **Return Bridge**: Output tokens bridge back to World Chain

**Key Innovation**: Aqua's virtual balance system allows LPs to provide liquidity without locking tokens in pools, enabling cross-chain AMM strategies with minimal capital requirements.


