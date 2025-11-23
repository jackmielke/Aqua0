# Complete Cross-Chain Swap Flow (Final)

## 🎯 The Actors & Setup

### World Chain (Where LP & Trader Are)
- **LP**: Has USDC/USDT in wallet
- **Trader**: Has USDC in wallet
- **Stargate OFTs**: USDC and USDT (already deployed by LayerZero)

### Base Chain (Where Strategy Logic Lives)
- **CrossChainSwapComposer**: Executes swaps (our contract)
- **StableswapAMM**: Swap logic
- **Aqua**: Tracks LP's virtual balances
- **Stargate OFTs**: USDC and USDT

---

## 🚀 PHASE 1: LP Ships Strategy (One-Time Setup)

```
World Chain                              Base Chain
═══════════                              ══════════

LP's Wallet:
├─ 100 USDC (stays in wallet!) ✅
└─ 100 USDT (stays in wallet!) ✅

LP ships strategy metadata (NO TOKENS):
[This is already working via existing AquaStrategyComposer]

        │ LZ Message (metadata only)
        ├────────────────────────►  Aqua on Base:
        │                           ├─ LP's virtual USDC: 100e6 ✅
        │                           └─ LP's virtual USDT: 100e6 ✅
        │                           
        │                           Strategy is active!
        │                           (But no physical tokens on Base yet)
```

**Key Point:** LP's tokens stay in their wallet on World. Strategy only exists as metadata on Base.

---

## 🔄 PHASE 2: Trader Swaps (The Magic!)

### Step 1: Trader Initiates Swap on World

```
World Chain
═══════════

Trader's Wallet: 10 USDC

Trader runs script:
$ forge script InitiateCrossChainSwap.s.sol \
    --rpc-url $WORLD_RPC \
    --broadcast

Script does:
1. trader.approve(stargateUSDC, 10e6)
2. Prepare composeMsg:
   composeMsg = abi.encode(
     trader,           // 0x...trader (to receive USDT back)
     LP,               // 0x...LP
     strategyHash,     // 0x123...
     9.96e6            // minAmountOut (0.996 USDT minimum)
   )
3. Call Stargate:
   StargateUSDC.send{value: fee}(
     dstEid: 40245,              // Base chain
     to: CrossChainSwapComposer, // Our contract on Base
     amountLD: 10e6,             // 10 USDC
     minAmountLD: 9.99e6,        // Min after bridge fees
     composeMsg: composeMsg,     // Swap instructions
     extraOptions: lzComposeGas(500000)
   )

Trader's wallet:
├─ USDC: 10 → 0 (sent to Stargate) ✅
└─ Waiting for USDT...
```

### Step 2: Stargate Bridges Tokens

```
World Chain                              Base Chain
───────────                              ──────────

Stargate USDC OFT                        Stargate USDC OFT
      │                                        │
      │ Bridge 10 USDC                         │
      ├────────────────────────►              │
                                               ▼
                                        10 USDC arrives in
                                        CrossChainSwapComposer ✅
```

### Step 3: LayerZero Triggers Compose

```
Base Chain
══════════

LayerZero Endpoint detects composeMsg
      │
      ├─► Calls CrossChainSwapComposer.lzCompose()
      │   
      │   Parameters:
      │   - sender: StargateUSDC (OFT)
      │   - guid: 0xabc... (message ID)
      │   - message: encoded OFT message
      │   - executor: 0x...
      │
      └─► Composer validates:
          ✓ sender == OFT_IN (Stargate USDC)
          ✓ msg.sender == ENDPOINT
          ✓ amountLD = 10e6 USDC arrived
```

### Step 4: Composer Executes Swap

```
Base Chain
══════════

CrossChainSwapComposer.handleCompose():

1. Decode composeMsg:
   trader = 0x...
   LP = 0x...
   strategyHash = 0x123...
   minAmountOut = 9.96e6

2. Build strategy:
   Strategy {
     maker: LP,
     token0: USDC,
     token1: USDT,
     feeBps: 4,        // 0.04%
     amplificationFactor: 100,
     salt: strategyHash
   }

3. Call AMM:
   AMM.swapExactIn(
     strategy,
     zeroForOne: true,
     amountIn: 10e6,
     minOut: 9.96e6,
     to: CrossChainSwapComposer,
     takerData: abi.encode(guid, trader, LP, strategyHash)
   )
```

### Step 5: Inside AMM Swap (The Critical Part!)

```
Base Chain - Inside AMM.swapExactIn()
═════════════════════════════════════

AMM calculates:
Quote = 9.996 USDT (10 USDC - 0.04% fee)

AMM calls PULL:
┌────────────────────────────────────────┐
│ aqua.pull(                             │
│   LP,                    // maker      │
│   strategyHash,                        │
│   USDT,                  // token      │
│   9.996e6,               // amount     │
│   CrossChainSwapComposer // to         │
│ )                                      │
└────────────────────────────────────────┘
      │
      ├─► Tries: USDT.safeTransferFrom(LP, Composer, 9.996e6)
      │   ❌ FAILS! LP's USDT is on World, not Base!
      │
      │   PROBLEM: How does Composer get USDT to give to trader?
      │
      └─► 🚨 THIS IS THE ISSUE! 🚨
```

---

## ❌ THE PROBLEM WITH CURRENT DESIGN

**The Issue:**
1. LP's USDT is on **World Chain** (in their wallet)
2. `aqua.pull()` tries to transfer from LP → Composer **on Base**
3. **LP has no USDT on Base!**
4. Transaction **FAILS** ❌

**Why `pullOnBehalfOf` Doesn't Help:**
```solidity
// pullOnBehalfOf still does:
IERC20(token).safeTransferFrom(maker, to, amount);
                               ↑
                        LP's address on World
                        (has no tokens on Base!)
```

---

## ✅ THE SOLUTION: Two Approaches

### Option A: Pre-Bridge LP's Liquidity (Escrow Model)

```
Setup Phase:
LP deposits USDC/USDT to Vault on World
    ↓
Vault bridges to Composer on Base
    ↓
Composer holds LP's tokens
    ↓
Composer acts as "maker" in strategy

Swap Phase:
Trader's USDC arrives
    ↓
AMM.swapExactIn(maker: Composer) // ✅ Composer has tokens!
    ↓
aqua.pull(Composer, USDT) // ✅ Works!
```

**Pros:**
- Simple, works with current design
- Instant swaps (no waiting for LP)

**Cons:**
- LP must pre-lock tokens
- Violates Aqua's "no lock" principle

### Option B: Just-In-Time Liquidity (Intent Model) ⭐ RECOMMENDED

```
Phase 1: Trader Submits Intent
Trader sends USDC to IntentPool on World
IntentPool locks it
Emits: SwapIntentSubmitted(strategyHash, 10 USDC → USDT)

Phase 2: LP Fulfills Intent  
LP sees intent on World
LP sends USDT directly to trader (on World!) ✅
IntentPool locks trader's USDC

Phase 3: Settlement on Base
Both tokens bridge to Base together:
- Trader's 10 USDC
- LP's 9.996 USDT

CrossChainSwapComposer receives both
Executes swap to update Aqua's books
Bridges LP's USDC proceeds back to World
```

**Pros:**
- ✅ LP doesn't pre-lock tokens
- ✅ Trader gets output immediately
- ✅ Settlement happens asynchronously
- ✅ Maintains Aqua's philosophy

**Cons:**
- More complex (needs IntentPool)
- 2-step process

---

## 🎯 RECOMMENDED FLOW (Intent Model)

```
World Chain                              Base Chain
═══════════                              ══════════

1. TRADER: Submit Intent
   IntentPool.submitIntent(
     strategyHash,
     10 USDC → USDT,
     minOut: 9.96 USDT
   )
   Trader's 10 USDC locked ✅
        │
        │ Event: SwapIntentSubmitted
        │
2. LP: Fulfill Intent
   LP sees intent
   LP calls IntentPool.fulfillIntent()
        │
        ├─► LP's 9.996 USDT → Trader ✅
        │   (Direct transfer on World)
        │
   Trader received USDT! 🎉
   (Swap "complete" from trader's perspective)
        │
3. SETTLEMENT: Update Aqua
        │
        │ Bridge both tokens to Base:
        │ - Trader's 10 USDC
        │ - LP's 9.996 USDT
        ├────────────────────────►  4. Tokens arrive in Composer
        │                              ↓
        │                           5. lzCompose() triggers
        │                              ↓
        │                           6. Composer executes:
        │                              
        │                              AMM.swapExactIn(
        │                                strategy,
        │                                amountIn: 10e6,
        │                                to: Composer
        │                              )
        │                              ↓
        │                              aqua.pull(
        │                                LP,
        │                                USDT,
        │                                9.996e6,
        │                                Composer
        │                              )
        │                              Uses LP's bridged USDT ✅
        │                              ↓
        │                              Aqua updates:
        │                              LP's USDT: 100 → 90.004 ✅
        │                              ↓
        │                              aqua.push(
        │                                LP,
        │                                USDC,
        │                                10e6
        │                              )
        │                              Uses trader's bridged USDC ✅
        │                              ↓
        │                              Aqua updates:
        │                              LP's USDC: 100 → 110 ✅
        │                              ↓
        │                           7. Bridge LP's proceeds back
        │                              10 USDC → LP on World
        │                              ↓
   ◄────────────────────────────   8. LP receives 10 USDC ✅

Final State:
Trader: +9.996 USDT, -10 USDC ✅
LP: +10 USDC, -9.996 USDT ✅
Aqua on Base: Books updated ✅
```

---

## 📦 What Needs to Be Built

### For Intent Model:

**1. IntentPool (World Chain)**
```solidity
contract IntentPool {
    function submitIntent(...) // Trader locks USDC
    function fulfillIntent(...) // LP sends USDT to trader
    function settleOnBase(...) // Bridge both to Base
}
```

**2. Update CrossChainSwapComposer (Base Chain)**
```solidity
contract CrossChainSwapComposer {
    // Receive BOTH tokens (trader's + LP's)
    // Execute swap to update Aqua
    // Bridge LP's proceeds back
}
```

---

## 💡 Why This Is The Right Way

**The Core Problem:**
- LP's tokens on World
- Aqua's accounting on Base
- Need to coordinate both

**The Solution:**
- Settlement happens on Base (where Aqua is)
- But LP provides tokens on World (where they are)
- Bridge only when needed (just-in-time)
- Trader gets instant settlement (no waiting)

**This maintains Aqua's "no pre-lock" principle while enabling cross-chain swaps!** 🎯

