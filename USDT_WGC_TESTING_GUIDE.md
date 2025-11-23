# 🧪 USDT/WGC Cross-Chain Swap Testing Guide

Complete step-by-step guide to test the USDT → WGC cross-chain swap using the Intent system.

## 📋 Prerequisites

All scripts have been updated to use **USDT/WGC** instead of USDT/rUSD.

### Environment Setup

```bash
# ============================================
# CHAIN CONFIGURATION
# ============================================
export BASE_RPC=https://base-mainnet.infura.io/v3/1f4a9f2192c74a8399ab55d05cc3e24c
export WORLD_RPC=https://sparkling-autumn-dinghy.worldchain-mainnet.quiknode.pro
export BASE_EID=30184

# ============================================
# DEPLOYED CONTRACTS
# ============================================
export COMPOSER_BASE=0xEa224c362F583D4eE0f7f6fdd31ef124D4f95447
export COMPOSER_WORLD=0xc689cA9BC4C0176b8a0d50d4733A44Af83834Ae8

export AQUA_BASE=0x36d500a364a3a82140420d1bcb5f8a90c8e352ef
export AMM_BASE=0xeb99024504f5e73Fc857E4B2a0CF076C7F91fa2E

# ============================================
# TOKEN ADDRESSES
# ============================================
# USDT
export USDT_BASE=0xeab8fa7ab28f05d7600558b873d5c7f805412304
export USDT_WORLD=0x13a3ca7638802f66ce4e12b101727405ec589f47

# WGC (same on both chains)
export WGC_BASE=0x3d63825b0d8669307366e6c8202f656b9e91d368
export WGC_WORLD=0x3d63825b0d8669307366e6c8202f656b9e91d368

# ============================================
# STARGATE OFT ADDRESSES (REQUIRED)
# ============================================
# You need to find these from Stargate documentation
# https://stargateprotocol.gitbook.io/stargate/v/v2-developer-docs/technical-reference/mainnet-contracts
export STARGATE_USDT_WORLD=<stargate_usdt_oft_on_world>
export STARGATE_WGC_WORLD=<stargate_wgc_oft_on_world>

# ============================================
# PRIVATE KEYS
# ============================================
export PRIVATE_KEY=0xdcd50c28a8f94a88efbbe8a45368ec37242b85f2b46667d067be65fdd007acbb
export LP_PRIVATE_KEY=0x5195b0e02b7ce24d5ab5c233f2beffe937a6dac0891739e43c2f2b3024595948
export TRADER_PRIVATE_KEY=<separate_trader_key_for_testing>
```

---

## 🚀 Complete Test Flow

### Step 0: Register Tokens on Base (One-time Setup)

```bash
cd packages/layerzero-contracts

# Register USDT and WGC on Base Composer
cast send $COMPOSER_BASE \
  "registerTokens(bytes32[],address[])" \
  "[$(cast keccak "USDT"),$(cast keccak "WGC")]" \
  "[0xeab8fa7ab28f05d7600558b873d5c7f805412304,0x3d63825b0d8669307366e6c8202f656b9e91d368]" \
  --rpc-url $BASE_RPC \
  --private-key $PRIVATE_KEY

# Verify registrations
echo "✅ Verifying USDT..."
cast call $COMPOSER_BASE \
  "tokenRegistry(bytes32)(address)" \
  $(cast keccak "USDT") \
  --rpc-url $BASE_RPC

echo "✅ Verifying WGC..."
cast call $COMPOSER_BASE \
  "tokenRegistry(bytes32)(address)" \
  $(cast keccak "WGC") \
  --rpc-url $BASE_RPC
```

---

### Step 1: Ship USDT/WGC Strategy to Base (One-time Setup)

```bash
export COMPOSER_ADDRESS=$COMPOSER_WORLD
export DST_EID=$BASE_EID
export DST_APP=$AMM_BASE

forge script scripts/shipStrategyToChain.s.sol:ShipStrategyToChainScript \
  --rpc-url $WORLD_RPC \
  --broadcast

# 📝 SAVE THE STRATEGY_HASH FROM THE OUTPUT!
export STRATEGY_HASH=<strategy_hash_from_output>

# Wait 2-5 minutes for LayerZero delivery, then verify
export LP_ADDRESS=$(cast wallet address --private-key $LP_PRIVATE_KEY)

cast call $AQUA_BASE \
  "balanceOf(address,bytes32,address)" \
  $LP_ADDRESS \
  $STRATEGY_HASH \
  $USDT_BASE \
  --rpc-url $BASE_RPC

cast call $AQUA_BASE \
  "balanceOf(address,bytes32,address)" \
  $LP_ADDRESS \
  $STRATEGY_HASH \
  $WGC_BASE \
  --rpc-url $BASE_RPC

# Expected: 2000000 for both (2 tokens with 6 decimals)
```

---

### Step 2: Deploy IntentPool on World Chain (One-time Setup)

```bash
export COMPOSER_ADDRESS=$COMPOSER_BASE

forge script scripts/deploy/DeployIntentPool.s.sol:DeployIntentPool \
  --rpc-url $WORLD_RPC \
  --broadcast

# 📝 SAVE THE INTENT_POOL ADDRESS!
export INTENT_POOL_WORLD=<deployed_intent_pool_address>
```

---

### Step 3: Register Strategy in IntentPool (One-time Setup)

```bash
export INTENT_POOL=$INTENT_POOL_WORLD

forge script scripts/intent/RegisterStrategy.s.sol:RegisterStrategy \
  --rpc-url $WORLD_RPC \
  --broadcast

# Verify registration
cast call $INTENT_POOL_WORLD \
  "getStrategyLP(bytes32)" \
  $STRATEGY_HASH \
  --rpc-url $WORLD_RPC

# Expected: Your LP address
```

---

### Step 4: Trader Submits Intent (USDT → WGC)

```bash
export INTENT_POOL_ADDRESS=$INTENT_POOL_WORLD
export SWAP_AMOUNT_IN=1000000  # 1 USDT (6 decimals)

# Optional: Set custom addresses (defaults are already set in script)
# export USDT_ADDRESS=$USDT_WORLD
# export WGC_ADDRESS=$WGC_WORLD

forge script scripts/intent/Step1_SubmitIntent.s.sol:Step1_SubmitIntent \
  --rpc-url $WORLD_RPC \
  --broadcast

# 📝 SAVE THE INTENT_ID FROM THE OUTPUT!
export INTENT_ID=<intent_id_from_output>

# Verify intent was created
cast call $INTENT_POOL_WORLD \
  "getIntent(bytes32)" \
  $INTENT_ID \
  --rpc-url $WORLD_RPC
```

**What happened:**
- ✅ Trader locked 1 USDT in IntentPool
- ✅ Intent status: PENDING
- ⏳ Waiting for LP to fulfill

---

### Step 5: LP Fulfills Intent (Locks WGC)

```bash
export INTENT_POOL_ADDRESS=$INTENT_POOL_WORLD
# WGC_ADDRESS has default in script

forge script scripts/intent/Step2_FulfillIntent.s.sol:Step2_FulfillIntent \
  --rpc-url $WORLD_RPC \
  --broadcast

# Verify intent is now MATCHED
cast call $INTENT_POOL_WORLD \
  "getIntent(bytes32)" \
  $INTENT_ID \
  --rpc-url $WORLD_RPC
```

**What happened:**
- ✅ LP locked ~0.9996 WGC in IntentPool (after 0.04% fee)
- ✅ Intent status: MATCHED
- ⏳ Ready for settlement

---

### Step 6: Settle Intent (Trigger Cross-Chain Swap)

```bash
export INTENT_POOL_ADDRESS=$INTENT_POOL_WORLD

# Quote the settlement fee first
cast call $INTENT_POOL_WORLD \
  "quoteSettlementFee(bytes32,uint128)" \
  $INTENT_ID \
  500000 \
  --rpc-url $WORLD_RPC

# Run settlement script (automatically adds 20% buffer)
forge script scripts/intent/Step3_SettleIntent.s.sol:Step3_SettleIntent \
  --rpc-url $WORLD_RPC \
  --broadcast

echo "✅ Settlement initiated!"
echo "⏳ Wait 5-10 minutes for LayerZero to bridge tokens to Base"
```

**What's happening:**
1. Both tokens (USDT + WGC) are bridged from World → Base via Stargate
2. CrossChainSwapComposer on Base receives both tokens
3. Composer executes swap on Aqua: USDT → WGC
4. Tokens are bridged back to World Chain
5. Trader receives WGC, LP receives USDT

---

### Step 7: Monitor Progress

```bash
# Check intent status on World
cast call $INTENT_POOL_WORLD \
  "getIntent(bytes32)" \
  $INTENT_ID \
  --rpc-url $WORLD_RPC

# Look for events on Base Composer
cast logs \
  --address $COMPOSER_BASE \
  --from-block -1000 \
  --to-block latest \
  --rpc-url $BASE_RPC

# Track on LayerZero scan
# https://layerzeroscan.com
```

---

### Step 8: Verify Final Balances

```bash
export TRADER_ADDRESS=$(cast wallet address --private-key $TRADER_PRIVATE_KEY)
export LP_ADDRESS=$(cast wallet address --private-key $LP_PRIVATE_KEY)

# Check Trader received WGC on World
echo "Trader WGC balance:"
cast call $WGC_WORLD \
  "balanceOf(address)" \
  $TRADER_ADDRESS \
  --rpc-url $WORLD_RPC

# Check LP received USDT on World
echo "LP USDT balance:"
cast call $USDT_WORLD \
  "balanceOf(address)" \
  $LP_ADDRESS \
  --rpc-url $WORLD_RPC

echo "✅ Cross-chain swap complete!"
```

---

## 📊 Summary of Changes

All scripts have been updated from **USDT/rUSD** to **USDT/WGC**:

| Script | Changes |
|--------|---------|
| `DeployIntentPool.s.sol` | Uses `STARGATE_WGC_WORLD` instead of `STARGATE_rUSD_WORLD` |
| `Step1_SubmitIntent.s.sol` | Swaps USDT → WGC (both 6 decimals), no decimal conversion needed |
| `Step2_FulfillIntent.s.sol` | LP locks WGC instead of rUSD |
| `Step3_SettleIntent.s.sol` | Updated console output for WGC |

---

## 🎯 Key Differences: USDT/rUSD vs USDT/WGC

| Aspect | USDT/rUSD | USDT/WGC |
|--------|-----------|----------|
| **Decimals** | 6 / 18 | 6 / 6 ✅ Same! |
| **Conversion** | Need to multiply by 1e12 | Direct 1:1 |
| **Fee Calculation** | `(amountIn * 1e12 * 9996) / 10000` | `(amountIn * 9996) / 10000` |
| **Stableswap** | Different decimals | Perfect for stableswap |

---

## ⚠️ Important Notes

### 1. Stargate OFT Addresses Required

You **MUST** set these before deploying IntentPool:
```bash
export STARGATE_USDT_WORLD=<from_stargate_docs>
export STARGATE_WGC_WORLD=<from_stargate_docs>
```

Find them at: https://stargateprotocol.gitbook.io/stargate/v/v2-developer-docs/technical-reference/mainnet-contracts

**If WGC doesn't have Stargate support**, you'll need to:
- Deploy your own OFT tokens for WGC
- Or use a different bridging solution
- Or modify IntentPool to use a different bridge

### 2. Gas Fees

- **Settlement fee**: ~0.001-0.01 ETH (LayerZero fees)
- **Total flow cost**: ~0.02-0.05 ETH including all transactions

### 3. Timing

- Strategy shipping: 2-5 minutes
- Intent settlement: 5-10 minutes
- Total test time: ~15-20 minutes

### 4. Testing Tips

- Start with small amounts (1 USDT)
- Use separate wallets for Trader and LP
- Monitor LayerZero scan for message delivery
- Check event logs on Base for debugging

---

## 🔧 Troubleshooting

### Error: "Strategy not found"
**Solution:** Re-ship the strategy and save the correct STRATEGY_HASH

### Error: "Token not mapped"
**Solution:** Register tokens on Base Composer (Step 0)

### Error: "Intent expired"
**Solution:** Increase deadline in Step1_SubmitIntent.s.sol

### Error: "Insufficient balance"
**Solution:** Ensure Trader has USDT and LP has WGC on World Chain

### Settlement stuck
**Solution:** Check LayerZero scan, may need to wait longer or increase gas limit

---

## ✅ Success Criteria

After completing all steps, you should see:

- ✅ Trader's USDT balance decreased by 1 USDT
- ✅ Trader's WGC balance increased by ~0.9996 WGC
- ✅ LP's WGC balance decreased by ~0.9996 WGC
- ✅ LP's USDT balance increased by 1 USDT
- ✅ Intent status: SETTLED

---

## 📚 Script Reference

All updated scripts are in `packages/layerzero-contracts/scripts/`:

```
scripts/
├── deploy/
│   └── DeployIntentPool.s.sol          ✅ Updated for WGC
├── intent/
│   ├── RegisterStrategy.s.sol          (no changes needed)
│   ├── Step1_SubmitIntent.s.sol        ✅ Updated for WGC
│   ├── Step2_FulfillIntent.s.sol       ✅ Updated for WGC
│   └── Step3_SettleIntent.s.sol        ✅ Updated for WGC
└── shipStrategyToChain.s.sol           ✅ Updated for WGC
```

---

**Ready to test!** 🚀

Start with Step 0 and work your way through. Each step builds on the previous one.


