# Aqua0 Sequence Diagram Corrections Summary

## What Was Wrong in the Previous Diagram

### ❌ Major Inaccuracies

1. **Strategy Shipping Misunderstood**
   - **Wrong**: Suggested tokens were transferred during strategy shipping
   - **Correct**: Strategy shipping is a **message-only** operation via LayerZero. No tokens are transferred. Only virtual balances are recorded in Aqua's `_balances` mapping.

2. **Intent Flow Oversimplified**
   - **Wrong**: Didn't show the three distinct steps (Submit → Fulfill → Settle)
   - **Correct**: Intent lifecycle has clear phases:
     - Step 1: Trader submits intent and locks tokenIn (USDT)
     - Step 2: LP fulfills intent and locks tokenOut (WGC)
     - Step 3: Settler triggers dual Stargate bridge to Base

3. **Dual Token Bridge Missing**
   - **Wrong**: Showed single token transfer or unclear bridging
   - **Correct**: Settlement involves **TWO separate Stargate sends**:
     - Part 1: LP's tokenOut (WGC) with compose message
     - Part 2: Trader's tokenIn (USDT) with compose message
     - Both must arrive before swap executes

4. **Aqua Virtual Balance System Not Explained**
   - **Wrong**: Implied tokens were in pools or contracts
   - **Correct**: Tokens stay in **LP's wallet** on Base. Aqua only tracks virtual balances:
     ```solidity
     _balances[maker][app][strategyHash][token] = amount
     ```
   - `pull()` decreases virtual balance and transfers from LP wallet
   - `push()` increases virtual balance and transfers to LP wallet

5. **CrossChainSwapComposer Role Unclear**
   - **Wrong**: Didn't show how it coordinates the swap
   - **Correct**: Composer:
     - Receives both tokens via `lzCompose()` (called twice)
     - Waits for both parts to arrive (`partsReceived == 2`)
     - Executes swap via AMM
     - Calls Aqua's `pullOnBehalfOf()` and `pushOnBehalfOf()` as trusted delegate
     - Bridges tokens back to World Chain

6. **AMM Callback Not Shown**
   - **Wrong**: Didn't show the callback mechanism
   - **Correct**: AMM calls `stableswapCallback()` during swap, expecting Composer to push trader's tokenIn to LP's virtual balance

7. **Return Bridge Missing**
   - **Wrong**: Didn't show how tokens get back to World Chain
   - **Correct**: After swap, Composer sends:
     - tokenOut (WGC) to Trader on World Chain
     - tokenIn (USDT) to LP on World Chain

---

## ✅ Key Corrections Applied

### 1. Strategy Shipping (Message-Only)

**Corrected Flow:**
```
LP (Ethereum) → AquaStrategyComposer → LayerZero Message → Base
                                                           ↓
                                    AquaStrategyComposer receives
                                                           ↓
                                    Resolve tokenIds to addresses
                                                           ↓
                                    aqua.shipOnBehalfOf()
                                                           ↓
                                    Virtual balances recorded
```

**No tokens transferred!** Only a LayerZero message containing:
- maker address
- app address (StableswapAMM)
- strategy bytes
- canonical tokenIds (keccak256("USDT"), keccak256("WGC"))
- virtual amounts (2e6, 2e6)

---

### 2. Intent Lifecycle (3 Steps)

**Corrected Flow:**

**Step 1: Submit Intent (Trader)**
```
Trader → approve USDT → IntentPool.submitIntent()
                              ↓
                    Lock 1 USDT in IntentPool
                              ↓
                    Create intent (status: PENDING)
```

**Step 2: Fulfill Intent (LP)**
```
LP → approve WGC → IntentPool.fulfillIntent()
                        ↓
              Lock 0.9996 WGC in IntentPool
                        ↓
              Update intent (status: MATCHED)
```

**Step 3: Settle Intent (Anyone)**
```
Settler → IntentPool.settleIntent() {value: fee}
                    ↓
          Dual Stargate send to Base
                    ↓
          Update intent (status: SETTLING)
```

---

### 3. Dual Token Bridge (Critical!)

**Corrected Flow:**
```
IntentPool (World Chain)
    ↓
    ├─→ Part 1: IOFT(WGC_OFT).send()
    │   - to: CrossChainSwapComposer
    │   - amount: 999600 WGC
    │   - composeMsg: (uint8(1), intentId, LP, 999600)
    │
    └─→ Part 2: IOFT(USDT_OFT).send()
        - to: CrossChainSwapComposer
        - amount: 1e6 USDT
        - composeMsg: (uint8(2), intentId, trader, LP, 1e6, strategyHash, minOut)

Both messages arrive at CrossChainSwapComposer via lzCompose()
```

**Why dual send?**
- LP's tokenOut (WGC) is for the trader
- Trader's tokenIn (USDT) is for the swap execution
- Both needed on Base to execute the swap

---

### 4. Aqua Virtual Balance System

**Corrected Understanding:**

```solidity
// Storage structure
mapping(address maker => mapping(address app => mapping(bytes32 strategyHash => mapping(address token => Balance))))
    private _balances;

struct Balance {
    uint248 balance;  // Virtual balance
    uint8 tokensCount; // Number of tokens in strategy
}
```

**Operations:**

1. **ship() / shipOnBehalfOf()**: Initialize virtual balances
   ```
   _balances[LP][AMM][hash][USDT] = 2e6
   _balances[LP][AMM][hash][WGC] = 2e6
   ```
   No tokens transferred!

2. **pull() / pullOnBehalfOf()**: Decrease virtual balance, transfer from LP wallet
   ```
   _balances[LP][AMM][hash][WGC] -= 999200
   IERC20(WGC).transferFrom(LP_wallet, to, 999200)
   ```

3. **push() / pushOnBehalfOf()**: Increase virtual balance, transfer to LP wallet
   ```
   _balances[LP][AMM][hash][USDT] += 1e6
   IERC20(USDT).transferFrom(payer, LP_wallet, 1e6)
   ```

4. **dock() / dockOnBehalfOf()**: Close strategy
   ```
   _balances[LP][AMM][hash][token] = 0 (marked as DOCKED)
   ```

---

### 5. CrossChainSwapComposer Coordination

**Corrected Flow:**

```
lzCompose() called TWICE (once per token):

Call 1: Part 1 (WGC arrives)
    ↓
_handlePart1()
    ↓
Store: tokenOutAmount = 999600
       partsReceived = 1
    ↓
Wait for Part 2...

Call 2: Part 2 (USDT arrives)
    ↓
_handlePart2()
    ↓
Store: tokenInAmount = 1e6
       partsReceived = 2
    ↓
Both parts received!
    ↓
_executeDualSwap()
    ↓
AMM.swapExactIn()
    ↓
stableswapCallback()
    ↓
aqua.pushOnBehalfOf() (push USDT to LP's virtual balance)
    ↓
Swap complete!
    ↓
Bridge tokens back to World Chain
```

---

### 6. AMM Callback Mechanism

**Corrected Flow:**

```
AMM.swapExactIn() called by Composer
    ↓
AMM calculates output (999200 WGC)
    ↓
AMM calls aqua.pullOnBehalfOf()
    - Pull 999200 WGC from LP's virtual balance
    - Transfer from LP wallet to Composer
    ↓
AMM calls stableswapCallback() on Composer
    - Expects Composer to push trader's USDT
    ↓
Composer calls aqua.pushOnBehalfOf()
    - Push 1e6 USDT to LP's virtual balance
    - Transfer from Composer to LP wallet
    ↓
AMM validates push via _safeCheckAquaPush()
    - Checks virtual balance increased
    ↓
Swap complete, return WGC to Composer
```

**Why callback?**
- Aqua's design: tokens stay in LP wallets
- AMM needs to ensure trader's tokens are pushed to LP
- Callback pattern allows atomic swap execution

---

### 7. Return Bridge to World Chain

**Corrected Flow:**

```
After swap completes on Base:

Composer has:
- 999200 WGC (for trader)
- 0 USDT (already pushed to LP)

Composer._sendTokenToWorld(WGC, trader, 999200)
    ↓
IOFT(WGC_OFT).send() to World Chain
    ↓
Trader receives 999200 WGC on World Chain

Composer._sendTokenToWorld(USDT, LP, 1e6)
    ↓
IOFT(USDT_OFT).send() to World Chain
    ↓
LP receives 1e6 USDT on World Chain
```

---

## Token Flow Summary (Corrected)

### LP's Perspective

1. **Setup** (Ethereum → Base):
   - Ship strategy via LayerZero message
   - Virtual balances recorded: 2 USDT, 2 WGC
   - **No tokens transferred**

2. **Fulfillment** (World Chain):
   - Lock 999600 WGC in IntentPool

3. **Execution** (Base):
   - Virtual balance updated:
     - WGC: 2e6 → 2e6 - 999200 = 1000800
     - USDT: 2e6 → 2e6 + 1e6 = 3e6
   - Real tokens:
     - 999200 WGC pulled from LP wallet
     - 1e6 USDT pushed to LP wallet

4. **Settlement** (World Chain):
   - Receive 1e6 USDT

**Net Result**: Swapped 999200 WGC for 1e6 USDT (earned ~800 USDT in fees)

---

### Trader's Perspective

1. **Intent** (World Chain):
   - Lock 1e6 USDT in IntentPool

2. **Execution** (Base):
   - Swap executed via LP's strategy
   - 1e6 USDT → 999200 WGC

3. **Settlement** (World Chain):
   - Receive 999200 WGC

**Net Result**: Swapped 1e6 USDT for 999200 WGC (paid ~800 USDT in fees/slippage)

---

## Architecture Clarifications

### Chain Roles

| Chain | Components | Role |
|-------|-----------|------|
| **Ethereum Sepolia** | AquaStrategyComposer | Optional: Ship strategies cross-chain |
| **Base Sepolia** | Aqua, AMMs, AquaStrategyComposer, CrossChainSwapComposer | Execution layer: Strategies live here, swaps execute here |
| **World Chain** | IntentPool, Stargate OFTs | Intent layer: Traders and LPs match here, tokens bridge from here |

---

### Contract Responsibilities

| Contract | Responsibility |
|----------|---------------|
| **Aqua** | Track virtual balances, pull/push tokens from LP wallets |
| **StableswapAMM** | Execute Curve-style swaps using Aqua's virtual balances |
| **ConcentratedLiquiditySwap** | Execute Uniswap V3-style swaps using Aqua's virtual balances |
| **AquaStrategyComposer** | Ship strategies cross-chain via LayerZero messages |
| **IntentPool** | Match trader intents with LP strategies, trigger settlement |
| **CrossChainSwapComposer** | Coordinate dual token arrival, execute swap, bridge back |

---

## Key Innovations (Corrected)

1. **Virtual Liquidity**
   - Tokens stay in LP wallets
   - Aqua tracks virtual balances
   - ~70% gas savings vs traditional pools

2. **Cross-Chain Strategy Shipping**
   - Message-only operation (no tokens)
   - Canonical token IDs ensure consistent hashing
   - Enables multi-chain strategy deployment

3. **Intent-Based Swaps**
   - Traders submit intents, LPs fulfill
   - Execution happens on optimal chain (Base)
   - Atomic settlement via dual bridge

4. **Dual Token Bridge**
   - Both tokens bridge simultaneously
   - Composer waits for both before executing
   - Atomic execution with refund on failure

5. **Trusted Delegate Pattern**
   - CrossChainSwapComposer is trusted by Aqua
   - Can call `pullOnBehalfOf()` and `pushOnBehalfOf()`
   - Enables cross-chain operations

---

## Testing Verification

To verify the corrected understanding, run:

```bash
# 1. Ship strategy (Ethereum → Base)
forge script scripts/shipStrategyToChain.s.sol --rpc-url $ETH_SEPOLIA_RPC --broadcast

# 2. Register strategy (World Chain)
forge script scripts/intent/RegisterStrategy.s.sol --rpc-url $WORLD_RPC --broadcast

# 3. Submit intent (World Chain)
forge script scripts/intent/Step1_SubmitIntent.s.sol --rpc-url $WORLD_RPC --broadcast

# 4. Fulfill intent (World Chain)
forge script scripts/intent/Step2_FulfillIntent.s.sol --rpc-url $WORLD_RPC --broadcast

# 5. Settle intent (World Chain → Base)
forge script scripts/intent/Step3_SettleIntent.s.sol --rpc-url $WORLD_RPC --broadcast

# 6. Monitor events on Base
cast logs --address $COMPOSER_ADDRESS --rpc-url $BASE_RPC
```

---

## References to Corrected Diagrams

1. **Detailed Text Diagrams**: See `ACCURATE_SEQUENCE_DIAGRAM.md`
2. **Mermaid Visualizations**: See `ACCURATE_SEQUENCE_DIAGRAM_MERMAID.md`

Both documents now accurately reflect:
- Virtual balance system
- Dual token bridge
- Intent lifecycle
- AMM callback mechanism
- Cross-chain coordination

---

## Conclusion

The previous sequence diagram had fundamental misunderstandings about:
1. How Aqua's virtual balance system works
2. The dual token bridge mechanism
3. The role of CrossChainSwapComposer
4. The intent lifecycle and settlement process

The corrected diagrams now accurately represent the actual implementation based on the codebase analysis.


