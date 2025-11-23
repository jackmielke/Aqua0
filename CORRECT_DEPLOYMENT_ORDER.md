# 🏗️ Correct Deployment Order for USDT/WGC Cross-Chain Swap

## 📋 Overview

The deployment order is critical because contracts depend on each other's addresses. Here's the correct sequence:

```
Base Chain First → World Chain Second
```

---

## ✅ Correct Deployment Sequence

### Phase 1: Base Chain Setup (One-time)

```
1. Deploy/Verify Aqua Router on Base
2. Deploy StableswapAMM on Base  
3. Deploy CrossChainSwapComposer on Base
4. Register tokens (USDT, WGC) in Composer
5. Ship USDT/WGC strategy from World to Base
```

### Phase 2: World Chain Setup (One-time)

```
6. Deploy IntentPool on World (needs Composer address from step 3)
7. Register strategy in IntentPool
```

### Phase 3: Testing (Repeatable)

```
8. Trader submits intent
9. LP fulfills intent
10. Settle intent (triggers cross-chain swap)
```

---

## 📝 Detailed Step-by-Step

### PHASE 1: BASE CHAIN SETUP

#### Step 1.1: Verify Aqua Router on Base

```bash
export AQUA_BASE=0x36d500a364a3a82140420d1bcb5f8a90c8e352ef

# Verify it exists
cast code $AQUA_BASE --rpc-url $BASE_RPC
```

✅ **Already deployed!**

---

#### Step 1.2: Deploy StableswapAMM on Base (if not done)

```bash
export AMM_BASE=0xeb99024504f5e73Fc857E4B2a0CF076C7F91fa2E

# Verify it exists
cast code $AMM_BASE --rpc-url $BASE_RPC
```

✅ **Already deployed!**

---

#### Step 1.3: Deploy CrossChainSwapComposer on Base

**Check if already deployed:**

```bash
export COMPOSER_BASE=0xEa224c362F583D4eE0f7f6fdd31ef124D4f95447

cast code $COMPOSER_BASE --rpc-url $BASE_RPC
```

**If not deployed, deploy it:**

```bash
cd packages/layerzero-contracts

# Set environment
export AQUA_ADDRESS=$AQUA_BASE

# Deploy using hardhat
npx hardhat deploy --network base-mainnet --tags CrossChainSwapComposer

# Or deploy manually
# (You'd need to create a deployment script for CrossChainSwapComposer)
```

✅ **Already deployed at:** `0xEa224c362F583D4eE0f7f6fdd31ef124D4f95447`

---

#### Step 1.4: Register USDT and WGC on Base Composer

```bash
cast send $COMPOSER_BASE \
  "registerTokens(bytes32[],address[])" \
  "[$(cast keccak "USDT"),$(cast keccak "WGC")]" \
  "[0xeab8fa7ab28f05d7600558b873d5c7f805412304,0x3d63825b0d8669307366e6c8202f656b9e91d368]" \
  --rpc-url $BASE_RPC \
  --private-key $PRIVATE_KEY

# Verify
cast call $COMPOSER_BASE \
  "tokenRegistry(bytes32)(address)" \
  $(cast keccak "USDT") \
  --rpc-url $BASE_RPC

cast call $COMPOSER_BASE \
  "tokenRegistry(bytes32)(address)" \
  $(cast keccak "WGC") \
  --rpc-url $BASE_RPC
```

---

#### Step 1.5: Ship USDT/WGC Strategy to Base

**From World Chain (or any chain with AquaStrategyComposer):**

```bash
cd packages/layerzero-contracts

export COMPOSER_ADDRESS=$COMPOSER_WORLD  # Composer on World
export DST_EID=30184  # Base
export DST_APP=$AMM_BASE

forge script scripts/shipStrategyToChain.s.sol:ShipStrategyToChainScript \
  --rpc-url $WORLD_RPC \
  --broadcast

# 📝 SAVE THE STRATEGY_HASH!
export STRATEGY_HASH=<from_output>
```

**Wait 2-5 minutes, then verify on Base:**

```bash
export LP_ADDRESS=$(cast wallet address --private-key $LP_PRIVATE_KEY)

cast call $AQUA_BASE \
  "balanceOf(address,bytes32,address)" \
  $LP_ADDRESS \
  $STRATEGY_HASH \
  0xeab8fa7ab28f05d7600558b873d5c7f805412304 \
  --rpc-url $BASE_RPC

# Expected: 2000000 (2 USDT)
```

✅ **Phase 1 Complete!** Base chain is ready.

---

### PHASE 2: WORLD CHAIN SETUP

#### Step 2.1: Deploy IntentPool on World

**This is where order matters!** IntentPool constructor needs:
- `baseEid` - Base chain endpoint ID
- `composer` - **CrossChainSwapComposer address on Base** (from Step 1.3)
- `stargateTokenA` - Stargate OFT for USDT on World
- `stargateTokenB` - Stargate OFT for WGC on World

```bash
cd packages/layerzero-contracts

# Set environment
export BASE_EID=30184
export COMPOSER_ADDRESS=$COMPOSER_BASE  # ⚠️ This is on Base!
export STARGATE_USDT_WORLD=<find_from_stargate_docs>
export STARGATE_WGC_WORLD=<find_from_stargate_docs>

forge script scripts/deploy/DeployIntentPool.s.sol:DeployIntentPool \
  --rpc-url $WORLD_RPC \
  --broadcast

# 📝 SAVE THE INTENT_POOL ADDRESS!
export INTENT_POOL_WORLD=<from_output>
```

**Verify deployment:**

```bash
# Check baseEid
cast call $INTENT_POOL_WORLD "baseEid()(uint32)" --rpc-url $WORLD_RPC
# Expected: 30184

# Check composer address
cast call $INTENT_POOL_WORLD "composer()(address)" --rpc-url $WORLD_RPC
# Expected: 0xEa224c362F583D4eE0f7f6fdd31ef124D4f95447 (Composer on Base)
```

---

#### Step 2.2: Register Strategy in IntentPool

```bash
export INTENT_POOL=$INTENT_POOL_WORLD

forge script scripts/intent/RegisterStrategy.s.sol:RegisterStrategy \
  --rpc-url $WORLD_RPC \
  --broadcast

# Verify
cast call $INTENT_POOL_WORLD \
  "getStrategyLP(bytes32)" \
  $STRATEGY_HASH \
  --rpc-url $WORLD_RPC

# Expected: Your LP address
```

✅ **Phase 2 Complete!** World chain is ready.

---

### PHASE 3: TESTING

Now you can test the full flow:

```bash
# Step 3.1: Trader submits intent
forge script scripts/intent/Step1_SubmitIntent.s.sol --rpc-url $WORLD_RPC --broadcast

# Step 3.2: LP fulfills intent
forge script scripts/intent/Step2_FulfillIntent.s.sol --rpc-url $WORLD_RPC --broadcast

# Step 3.3: Settle intent
forge script scripts/intent/Step3_SettleIntent.s.sol --rpc-url $WORLD_RPC --broadcast
```

---

## 🔍 Why This Order Matters

### ❌ Wrong Order (IntentPool First)

```solidity
// IntentPool constructor
constructor(
    uint32 _baseEid,
    address _composer,  // ❌ Don't know this yet!
    address _stargateTokenA,
    address _stargateTokenB
)
```

If you deploy IntentPool first, you don't have the Composer address yet!

### ✅ Correct Order (Composer First)

```
1. Deploy Composer on Base → Get address: 0xEa22...
2. Deploy IntentPool on World → Pass composer address: 0xEa22...
```

Now IntentPool knows where to send tokens!

---

## 📊 Dependency Graph

```
Base Chain:
  Aqua Router (already exists)
    ↓
  StableswapAMM (already exists)
    ↓
  CrossChainSwapComposer ← DEPLOY THIS FIRST
    ↑
    │ (needs address)
    │
World Chain:
  IntentPool ← DEPLOY THIS SECOND
    ↓
  Submit Intents ← DO THIS THIRD
```

---

## 🎯 Quick Checklist

Before deploying IntentPool, ensure you have:

- [ ] Aqua Router address on Base
- [ ] StableswapAMM address on Base
- [ ] **CrossChainSwapComposer address on Base** ⚠️ CRITICAL
- [ ] Stargate OFT addresses for USDT and WGC on World
- [ ] Base chain endpoint ID (30184)
- [ ] Strategy already shipped to Base
- [ ] Tokens registered in Composer on Base

If any of these are missing, **STOP** and complete them first!

---

## 🔄 What If I Already Deployed Wrong?

If you deployed IntentPool with wrong composer address:

### Option 1: Update Composer Address (if function exists)

```bash
# Check if IntentPool has setComposer function
cast call $INTENT_POOL_WORLD "setComposer(address)" --rpc-url $WORLD_RPC

# If yes, update it
cast send $INTENT_POOL_WORLD \
  "setComposer(address)" \
  $COMPOSER_BASE \
  --rpc-url $WORLD_RPC \
  --private-key $PRIVATE_KEY
```

### Option 2: Deploy New IntentPool

```bash
# Deploy a new one with correct address
forge script scripts/deploy/DeployIntentPool.s.sol:DeployIntentPool \
  --rpc-url $WORLD_RPC \
  --broadcast

# Use the new address
export INTENT_POOL_WORLD=<new_address>
```

---

## 📝 Environment Variables Summary

### Base Chain (Deploy First)
```bash
export AQUA_BASE=0x36d500a364a3a82140420d1bcb5f8a90c8e352ef
export AMM_BASE=0xeb99024504f5e73Fc857E4B2a0CF076C7F91fa2E
export COMPOSER_BASE=0xEa224c362F583D4eE0f7f6fdd31ef124D4f95447  # ⚠️ NEEDED FOR WORLD
```

### World Chain (Deploy Second)
```bash
export BASE_EID=30184
export COMPOSER_ADDRESS=$COMPOSER_BASE  # ⚠️ FROM BASE CHAIN
export STARGATE_USDT_WORLD=<find_from_docs>
export STARGATE_WGC_WORLD=<find_from_docs>
export INTENT_POOL_WORLD=<after_deployment>
```

---

## ✅ Summary

**Correct Order:**
1. ✅ Base: Deploy CrossChainSwapComposer
2. ✅ Base: Register tokens
3. ✅ Base: Ship strategy
4. ✅ World: Deploy IntentPool (needs Composer address)
5. ✅ World: Register strategy
6. ✅ World: Submit intents

**Key Point:** CrossChainSwapComposer on Base must exist before IntentPool on World, because IntentPool needs to know where to send tokens!

---

## 🚀 Ready to Deploy

Follow this order and you'll have a working cross-chain swap system! 🎉


