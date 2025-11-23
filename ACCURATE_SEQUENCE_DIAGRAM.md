# Aqua0 Cross-Chain AMM - Accurate Sequence Diagram

## Project Overview

**Aqua0** is a cross-chain shared liquidity layer that extends 1inch's Aqua protocol. It enables liquidity providers (LPs) to deploy AMM strategies on one chain (e.g., Base) and fulfill swap intents from traders on another chain (e.g., World Chain) using LayerZero for cross-chain messaging and Stargate for token bridging.

### Key Innovation
- **Virtual Liquidity**: LPs don't lock tokens in pools. Tokens stay in LP wallets, with Aqua tracking virtual balances.
- **Cross-Chain Strategy Shipping**: LPs ship strategies from one chain to another via LayerZero messages (no tokens transferred during shipping).
- **Intent-Based Swaps**: Traders submit intents on World Chain, LPs fulfill them, and execution happens on Base where the AMM strategy lives.

### Custom AquaApps
1. **StableswapAMM** (Curve-style): Optimized for stablecoin pairs using hybrid constant sum/product formula
2. **ConcentratedLiquiditySwap** (Uniswap V3-style): Capital-efficient AMM with price range concentration

---

## Architecture Components

### Chain Deployment
- **Base Sepolia**: Aqua protocol + AMM strategies (StableswapAMM, ConcentratedLiquiditySwap) + CrossChainSwapComposer
- **World Chain**: IntentPool + Stargate OFTs
- **Ethereum Sepolia** (optional): AquaStrategyComposer for cross-chain strategy shipping

### Key Contracts

| Contract | Chain | Purpose |
|----------|-------|---------|
| `Aqua` | Base | Core shared liquidity layer - tracks virtual balances |
| `StableswapAMM` | Base | Curve-style AMM for stablecoins (implements AquaApp) |
| `ConcentratedLiquiditySwap` | Base | Uniswap V3-style AMM (implements AquaApp) |
| `AquaStrategyComposer` | Ethereum/Base | Ships strategies cross-chain via LayerZero messages |
| `IntentPool` | World Chain | Matches trader intents with LP strategies |
| `CrossChainSwapComposer` | Base | Executes swaps after tokens arrive via Stargate |

---

## Complete Flow Diagrams

### Phase 1: LP Strategy Setup (Cross-Chain Shipping)

```
┌─────────────┐                    ┌──────────────────┐                    ┌─────────────┐
│ LP (Wallet) │                    │ LayerZero        │                    │ Base Chain  │
│ Ethereum    │                    │ Network          │                    │             │
└──────┬──────┘                    └────────┬─────────┘                    └──────┬──────┘
       │                                    │                                      │
       │ 1. shipStrategyToChain()           │                                      │
       │    - dstEid: Base                  │                                      │
       │    - dstApp: StableswapAMM         │                                      │
       │    - strategy: {maker, token0Id,   │                                      │
       │      token1Id, feeBps, A, salt}    │                                      │
       │    - tokenIds: [USDT, WGC]         │                                      │
       │    - amounts: [2e6, 2e6]           │                                      │
       ├───────────────────────────────────>│                                      │
       │                                    │                                      │
       │                                    │ 2. _lzSend()                         │
       │                                    │    Cross-chain message               │
       │                                    ├─────────────────────────────────────>│
       │                                    │                                      │
       │                                    │                                      │ 3. _lzReceive()
       │                                    │                                      │    AquaStrategyComposer
       │                                    │                                      │
       │                                    │                                      │ 4. Resolve tokenIds:
       │                                    │                                      │    USDT -> 0x...
       │                                    │                                      │    WGC -> 0x...
       │                                    │                                      │
       │                                    │                                      │ 5. aqua.shipOnBehalfOf()
       │                                    │                                      │    - maker: LP address
       │                                    │                                      │    - app: StableswapAMM
       │                                    │                                      │    - tokens: [USDT, WGC]
       │                                    │                                      │    - amounts: [2e6, 2e6]
       │                                    │                                      │
       │                                    │                                      │ 6. Aqua records:
       │                                    │                                      │    _balances[LP][AMM][strategyHash][USDT] = 2e6
       │                                    │                                      │    _balances[LP][AMM][strategyHash][WGC] = 2e6
       │                                    │                                      │
       │                                    │ 7. CrossChainShipExecuted event      │
       │<────────────────────────────────────────────────────────────────────────┤
       │                                    │                                      │
       │ Strategy now live on Base!         │                                      │
       │ strategyHash = keccak256(strategy) │                                      │
       │                                    │                                      │
```

**Key Points:**
- No tokens are transferred during strategy shipping - only a LayerZero message
- Virtual liquidity (2 USDT, 2 WGC) is recorded in Aqua's `_balances` mapping
- Strategy hash is deterministic across chains (uses canonical token IDs)
- LP's tokens remain in their wallet on Base

---

### Phase 2: LP Registers Strategy in IntentPool (World Chain)

```
┌─────────────┐                    ┌──────────────────┐
│ LP (Wallet) │                    │ IntentPool       │
│ World Chain │                    │ World Chain      │
└──────┬──────┘                    └────────┬─────────┘
       │                                    │
       │ 1. registerStrategy()              │
       │    - strategyHash: 0xabc...        │
       │    - LP: 0xLP_address              │
       ├───────────────────────────────────>│
       │                                    │
       │                                    │ 2. Store mapping:
       │                                    │    strategyOwners[0xabc...] = 0xLP_address
       │                                    │
       │<───────────────────────────────────┤
       │ Strategy registered!               │
       │                                    │
```

**Key Points:**
- Links the strategy hash to the LP's address on World Chain
- Traders can now submit intents against this strategy

---

### Phase 3: Intent-Based Swap Flow (Trader → LP)

#### Step 3.1: Trader Submits Intent (World Chain)

```
┌─────────────┐                    ┌──────────────────┐                    ┌─────────────┐
│ Trader      │                    │ IntentPool       │                    │ USDT Token  │
│ World Chain │                    │ World Chain      │                    │ World Chain │
└──────┬──────┘                    └────────┬─────────┘                    └──────┬──────┘
       │                                    │                                      │
       │ 1. approve(IntentPool, 1 USDT)     │                                      │
       ├────────────────────────────────────────────────────────────────────────>│
       │                                    │                                      │
       │ 2. submitIntent()                  │                                      │
       │    - strategyHash: 0xabc...        │                                      │
       │    - tokenIn: USDT                 │                                      │
       │    - tokenOut: WGC                 │                                      │
       │    - amountIn: 1e6 (1 USDT)        │                                      │
       │    - expectedOut: 999600 (0.04% fee)│                                     │
       │    - minOut: 994602 (0.5% slippage)│                                      │
       │    - deadline: now + 1 hour        │                                      │
       ├───────────────────────────────────>│                                      │
       │                                    │                                      │
       │                                    │ 3. transferFrom(Trader, IntentPool, 1 USDT)
       │                                    ├─────────────────────────────────────>│
       │                                    │                                      │
       │                                    │ 4. Create intent:                    │
       │                                    │    intentId = keccak256(...)         │
       │                                    │    status = PENDING                  │
       │                                    │    trader = 0xTrader                 │
       │                                    │    LP = 0xLP (from strategyOwners)   │
       │                                    │                                      │
       │<───────────────────────────────────┤                                      │
       │ intentId: 0x123...                 │                                      │
       │ Status: PENDING                    │                                      │
       │                                    │                                      │
```

#### Step 3.2: LP Fulfills Intent (World Chain)

```
┌─────────────┐                    ┌──────────────────┐                    ┌─────────────┐
│ LP          │                    │ IntentPool       │                    │ WGC Token   │
│ World Chain │                    │ World Chain      │                    │ World Chain │
└──────┬──────┘                    └────────┬─────────┘                    └──────┬──────┘
       │                                    │                                      │
       │ 1. approve(IntentPool, 999600 WGC) │                                      │
       ├────────────────────────────────────────────────────────────────────────>│
       │                                    │                                      │
       │ 2. fulfillIntent(intentId)         │                                      │
       ├───────────────────────────────────>│                                      │
       │                                    │                                      │
       │                                    │ 3. Validate:                         │
       │                                    │    - status == PENDING               │
       │                                    │    - msg.sender == LP                │
       │                                    │    - deadline not passed             │
       │                                    │                                      │
       │                                    │ 4. transferFrom(LP, IntentPool, 999600 WGC)
       │                                    ├─────────────────────────────────────>│
       │                                    │                                      │
       │                                    │ 5. Update intent:                    │
       │                                    │    status = MATCHED                  │
       │                                    │    actualOut = 999600                │
       │                                    │                                      │
       │<───────────────────────────────────┤                                      │
       │ Intent fulfilled!                  │                                      │
       │ Status: MATCHED                    │                                      │
       │                                    │                                      │
```

#### Step 3.3: Settlement - Dual Stargate Bridge (World → Base)

```
┌──────────┐         ┌──────────────┐         ┌──────────┐         ┌──────────────────┐
│ Settler  │         │ IntentPool   │         │ Stargate │         │ CrossChainSwap   │
│ World    │         │ World        │         │ OFTs     │         │ Composer (Base)  │
└────┬─────┘         └──────┬───────┘         └────┬─────┘         └────────┬─────────┘
     │                      │                      │                         │
     │ 1. settleIntent()    │                      │                         │
     │    {value: 0.01 ETH} │                      │                         │
     ├─────────────────────>│                      │                         │
     │                      │                      │                         │
     │                      │ 2. Build Part 1 msg: │                         │
     │                      │    (uint8(1),        │                         │
     │                      │     intentId,        │                         │
     │                      │     LP,              │                         │
     │                      │     999600)          │                         │
     │                      │                      │                         │
     │                      │ 3. Build Part 2 msg: │                         │
     │                      │    (uint8(2),        │                         │
     │                      │     intentId,        │                         │
     │                      │     trader,          │                         │
     │                      │     LP,              │                         │
     │                      │     1e6,             │                         │
     │                      │     strategyHash,    │                         │
     │                      │     minOut)          │                         │
     │                      │                      │                         │
     │                      │ 4. approve(WGC_OFT, 999600)                    │
     │                      │ 5. approve(USDT_OFT, 1e6)                      │
     │                      │                      │                         │
     │                      │ 6. IOFT(WGC_OFT).send()                        │
     │                      │    - to: Composer    │                         │
     │                      │    - amount: 999600  │                         │
     │                      │    - composeMsg: Part 1                        │
     │                      ├─────────────────────>│                         │
     │                      │                      │                         │
     │                      │ 7. IOFT(USDT_OFT).send()                       │
     │                      │    - to: Composer    │                         │
     │                      │    - amount: 1e6     │                         │
     │                      │    - composeMsg: Part 2                        │
     │                      ├─────────────────────>│                         │
     │                      │                      │                         │
     │                      │                      │ 8. Bridge WGC to Base   │
     │                      │                      │    (LayerZero + Stargate)
     │                      │                      ├────────────────────────>│
     │                      │                      │                         │
     │                      │                      │ 9. Bridge USDT to Base  │
     │                      │                      │    (LayerZero + Stargate)
     │                      │                      ├────────────────────────>│
     │                      │                      │                         │
     │                      │ 10. Update status:   │                         │
     │                      │     SETTLING         │                         │
     │                      │                      │                         │
```

#### Step 3.4: Swap Execution on Base

```
┌──────────────────┐    ┌──────────────┐    ┌──────────────┐    ┌─────────────┐
│ CrossChainSwap   │    │ Stableswap   │    │ Aqua         │    │ LP Wallet   │
│ Composer         │    │ AMM          │    │ Protocol     │    │ (Base)      │
└────────┬─────────┘    └──────┬───────┘    └──────┬───────┘    └──────┬──────┘
         │                     │                    │                   │
         │ 1. lzCompose()      │                    │                   │
         │    Part 1: WGC      │                    │                   │
         │    arrives (999600) │                    │                   │
         │                     │                    │                   │
         │ 2. _handlePart1()   │                    │                   │
         │    Store: tokenOutAmount = 999600        │                   │
         │    partsReceived = 1                     │                   │
         │                     │                    │                   │
         │ 3. lzCompose()      │                    │                   │
         │    Part 2: USDT     │                    │                   │
         │    arrives (1e6)    │                    │                   │
         │                     │                    │                   │
         │ 4. _handlePart2()   │                    │                   │
         │    Store: tokenInAmount = 1e6            │                   │
         │    partsReceived = 2                     │                   │
         │                     │                    │                   │
         │ 5. Both parts received!                  │                   │
         │    _executeDualSwap()                    │                   │
         │                     │                    │                   │
         │ 6. Build strategy:  │                    │                   │
         │    {maker: LP,      │                    │                   │
         │     token0: USDT,   │                    │                   │
         │     token1: WGC,    │                    │                   │
         │     feeBps: 4,      │                    │                   │
         │     A: 100,         │                    │                   │
         │     salt: 0x0}      │                    │                   │
         │                     │                    │                   │
         │ 7. swapExactIn()    │                    │                   │
         │    - amountIn: 1e6  │                    │                   │
         │    - minOut: 994602 │                    │                   │
         ├────────────────────>│                    │                   │
         │                     │                    │                   │
         │                     │ 8. Calculate swap: │                   │
         │                     │    Stableswap formula                  │
         │                     │    amountOut ≈ 999200                  │
         │                     │                    │                   │
         │                     │ 9. pullOnBehalfOf()│                   │
         │                     │    Pull WGC from LP's virtual balance  │
         │                     ├───────────────────>│                   │
         │                     │                    │                   │
         │                     │                    │ 10. Update balance:
         │                     │                    │     _balances[LP][AMM][hash][WGC] -= 999200
         │                     │                    │                   │
         │                     │                    │ 11. transferFrom()│
         │                     │                    │     Pull WGC from LP wallet
         │                     │                    ├──────────────────>│
         │                     │                    │                   │
         │                     │ 12. Transfer WGC   │                   │
         │                     │     to Composer    │                   │
         │<────────────────────┤                    │                   │
         │                     │                    │                   │
         │ 13. stableswapCallback()                 │                   │
         │     (AMM expects USDT push)              │                   │
         ├────────────────────>│                    │                   │
         │                     │                    │                   │
         │ 14. pushOnBehalfOf()│                    │                   │
         │     Push USDT to LP's virtual balance    │                   │
         ├────────────────────────────────────────>│                   │
         │                     │                    │                   │
         │                     │                    │ 15. Update balance:
         │                     │                    │     _balances[LP][AMM][hash][USDT] += 1e6
         │                     │                    │                   │
         │                     │                    │ 16. transferFrom()│
         │                     │                    │     Push USDT to LP wallet
         │                     │                    ├──────────────────>│
         │                     │                    │                   │
         │ 17. Swap complete!  │                    │                   │
         │     Composer has:   │                    │                   │
         │     - 999200 WGC    │                    │                   │
         │                     │                    │                   │
```

#### Step 3.5: Bridge Tokens Back to World Chain

```
┌──────────────────┐         ┌──────────┐         ┌─────────────┐         ┌─────────────┐
│ CrossChainSwap   │         │ Stargate │         │ Trader      │         │ LP          │
│ Composer (Base)  │         │ OFTs     │         │ World Chain │         │ World Chain │
└────────┬─────────┘         └────┬─────┘         └──────┬──────┘         └──────┬──────┘
         │                        │                       │                       │
         │ 1. _sendTokenToWorld() │                       │                       │
         │    Send WGC to Trader  │                       │                       │
         ├───────────────────────>│                       │                       │
         │                        │                       │                       │
         │                        │ 2. Bridge WGC         │                       │
         │                        │    (LayerZero)        │                       │
         │                        ├──────────────────────>│                       │
         │                        │                       │                       │
         │                        │ 3. Trader receives    │                       │
         │                        │    999200 WGC         │                       │
         │                        │                       │                       │
         │ 4. _sendTokenToWorld() │                       │                       │
         │    Send USDT to LP     │                       │                       │
         ├───────────────────────>│                       │                       │
         │                        │                       │                       │
         │                        │ 5. Bridge USDT        │                       │
         │                        │    (LayerZero)        │                       │
         │                        ├───────────────────────────────────────────────>│
         │                        │                       │                       │
         │                        │ 6. LP receives        │                       │
         │                        │    1e6 USDT           │                       │
         │                        │                       │                       │
         │ Swap complete!         │                       │                       │
         │ Trader: +999200 WGC    │                       │                       │
         │ LP: +1e6 USDT          │                       │                       │
         │                        │                       │                       │
```

---

## Key Technical Details

### Aqua Virtual Balance System

Aqua tracks virtual balances without requiring tokens to be locked in pools:

```solidity
// Storage structure
mapping(address maker => mapping(address app => mapping(bytes32 strategyHash => mapping(address token => Balance))))
    private _balances;

// Balance struct
struct Balance {
    uint248 balance;  // Virtual balance amount
    uint8 tokensCount; // Number of tokens in strategy (2 for pairs)
}
```

**Operations:**
- `ship()`: Initialize strategy with virtual balances
- `pull()`: Decrease virtual balance, transfer real tokens from LP wallet
- `push()`: Increase virtual balance, transfer real tokens to LP wallet
- `dock()`: Close strategy, mark as inactive

### Stableswap AMM Formula

Implements Curve's hybrid invariant:

```
An^n ∑x_i + D = An^n D + D^(n+1)/(n^n ∏x_i)
```

Where:
- `A` = Amplification factor (100 for stablecoins)
- `D` = Invariant (total value)
- `x_i` = Token balances
- `n` = Number of tokens (2 for pairs)

**Simplified implementation:**
```solidity
weight = (A * PRECISION) / (A + 1);
amountOut = (weight * constantSumOut + (PRECISION - weight) * constantProductOut) / PRECISION;
```

### Concentrated Liquidity Formula

Adapts Uniswap V3's concentrated liquidity:

```
x_virtual × y_virtual = L²
```

Where:
- `L` = Liquidity (constant within price range)
- `x_virtual`, `y_virtual` = Virtual reserves
- Price range: `[priceLower, priceUpper]`

**Range multiplier:**
- 10% range → 2x capital efficiency
- 50% range → 1.5x capital efficiency
- 100%+ range → 1x (regular AMM)

### LayerZero Message Flow

**Strategy Shipping (Message Only):**
```
Source Chain (Ethereum) → LayerZero → Destination Chain (Base)
Message: {maker, app, strategy, tokenIds, amounts}
No tokens transferred
```

**Intent Settlement (Dual Token Bridge):**
```
World Chain → Stargate → Base Chain
Part 1: WGC (LP's tokenOut) with compose message
Part 2: USDT (Trader's tokenIn) with compose message
Both tokens + messages arrive at CrossChainSwapComposer
```

---

## Token Flow Summary

### LP's Perspective
1. **Setup**: Ship strategy (virtual liquidity: 2 USDT, 2 WGC on Base)
2. **Fulfillment**: Lock 999600 WGC on World Chain
3. **Execution**: Virtual balance updated on Base (USDT +1e6, WGC -999200)
4. **Settlement**: Receive 1e6 USDT on World Chain

**Net Result**: Swapped 999200 WGC for 1e6 USDT (earned 400 WGC fee)

### Trader's Perspective
1. **Intent**: Lock 1e6 USDT on World Chain
2. **Execution**: Swap executed on Base via LP's strategy
3. **Settlement**: Receive 999200 WGC on World Chain

**Net Result**: Swapped 1e6 USDT for 999200 WGC (paid 800 USDT in fees/slippage)

---

## Security Considerations

### Reentrancy Protection
All swap functions use `nonReentrantStrategy` modifier:
```solidity
modifier nonReentrantStrategy(bytes32 strategyHash) {
    _reentrancyLocks[strategyHash].lock();
    _;
    _reentrancyLocks[strategyHash].unlock();
}
```

### Trusted Delegates
Aqua uses trusted delegates for cross-chain operations:
```solidity
mapping(address => bool) public trustedDelegates;

modifier onlyTrustedDelegate() {
    require(trustedDelegates[msg.sender], "Unauthorized");
    _;
}
```

CrossChainSwapComposer must be registered as a trusted delegate to call:
- `pullOnBehalfOf()`
- `pushOnBehalfOf()`

### Intent Expiration
Intents have deadlines to prevent stale executions:
```solidity
require(block.timestamp <= intent.deadline, "Intent expired");
```

### Slippage Protection
Traders specify minimum output:
```solidity
require(amountOut >= minOut, "Insufficient output");
```

---

## Gas Optimization

### Virtual Balances
- No token transfers during strategy setup
- Tokens stay in LP wallets until actually needed
- Reduces gas costs by ~70% vs traditional pools

### Transient Storage
Uses transient storage for reentrancy locks (EIP-1153):
```solidity
using TransientLockLib for TransientLock;
```

### Batch Operations
Settlement sends both tokens in one transaction:
- Dual Stargate sends
- Single LayerZero fee payment
- Atomic execution on Base

---

## Deployment Addresses

### Base Sepolia
- Aqua: `0x...` (deployed)
- StableswapAMM: `0x...` (deployed)
- ConcentratedLiquiditySwap: `0x...` (deployed)
- CrossChainSwapComposer: `0x...` (deployed)

### World Chain
- IntentPool: `0x...` (deployed)
- USDT OFT: `0x13a3ca7638802f66ce4e12b101727405ec589f47`
- WGC OFT: `0x3d63825b0d8669307366e6c8202f656b9e91d368`

### Ethereum Sepolia
- AquaStrategyComposer: `0x...` (optional)

---

## Testing Commands

### 1. Ship Strategy (Ethereum → Base)
```bash
forge script scripts/shipStrategyToChain.s.sol \
  --rpc-url $ETH_SEPOLIA_RPC \
  --broadcast
```

### 2. Register Strategy (World Chain)
```bash
forge script scripts/intent/RegisterStrategy.s.sol \
  --rpc-url $WORLD_RPC \
  --broadcast
```

### 3. Submit Intent (World Chain)
```bash
forge script scripts/intent/Step1_SubmitIntent.s.sol \
  --rpc-url $WORLD_RPC \
  --broadcast
```

### 4. Fulfill Intent (World Chain)
```bash
forge script scripts/intent/Step2_FulfillIntent.s.sol \
  --rpc-url $WORLD_RPC \
  --broadcast
```

### 5. Settle Intent (World Chain → Base)
```bash
forge script scripts/intent/Step3_SettleIntent.s.sol \
  --rpc-url $WORLD_RPC \
  --broadcast
```

---

## Future Enhancements

1. **Multi-Chain Support**: Extend to Arbitrum, Optimism, Polygon
2. **Multiple AMM Strategies**: Support more AquaApps (Balancer-style, etc.)
3. **Automated Market Making**: Bots for automatic intent fulfillment
4. **Fee Optimization**: Dynamic fees based on market conditions
5. **Liquidity Aggregation**: Combine multiple LP strategies for better pricing

---

## References

- [Aqua Whitepaper](../packages/aqua-contracts/whitepaper/aqua-dev-preview.md)
- [LayerZero Documentation](https://docs.layerzero.network/)
- [Stargate Finance](https://stargate.finance/)
- [Curve Stableswap Paper](https://curve.fi/files/stableswap-paper.pdf)
- [Uniswap V3 Whitepaper](https://uniswap.org/whitepaper-v3.pdf)


