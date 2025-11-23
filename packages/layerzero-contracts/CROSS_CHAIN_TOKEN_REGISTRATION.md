# 🌉 Cross-Chain Token Registration Guide

This guide shows you how to register tokens on Base from World Chain (or any other chain) using LayerZero messaging.

## 📋 Overview

Instead of manually calling `registerToken()` on each chain, you can now:
1. Deploy `AquaStrategyComposer` on both chains
2. Set up LayerZero peers between them
3. Register tokens cross-chain with a single transaction from the source chain

## 🚀 Quick Start: Register WGC on Base from World Chain

### Step 1: Set Environment Variables

```bash
# === Chains ===
export WORLD_RPC=https://worldchain-mainnet.g.alchemy.com/public
export BASE_RPC=https://mainnet.base.org
export WORLD_EID=30309  # World Chain endpoint ID
export BASE_EID=30184   # Base endpoint ID

# === Composer Addresses ===
export COMPOSER_WORLD=<your_composer_on_world>
export COMPOSER_BASE=<your_composer_on_base>

# === Token Addresses ===
export WGC_BASE=<wgc_address_on_base>

# === Keys ===
export PRIVATE_KEY=0x...  # Owner/deployer key
```

### Step 2: Ensure Composers are Peered

The composers on both chains must be configured as LayerZero peers:

```bash
# On World Chain - set Base as peer
cast send $COMPOSER_WORLD \
  "setPeer(uint32,bytes32)" \
  $BASE_EID \
  $(cast abi-encode "f(address)" $COMPOSER_BASE) \
  --rpc-url $WORLD_RPC \
  --private-key $PRIVATE_KEY

# On Base - set World as peer
cast send $COMPOSER_BASE \
  "setPeer(uint32,bytes32)" \
  $WORLD_EID \
  $(cast abi-encode "f(address)" $COMPOSER_WORLD) \
  --rpc-url $BASE_RPC \
  --private-key $PRIVATE_KEY
```

### Step 3: Add Base as Supported Chain on World Composer

```bash
cast send $COMPOSER_WORLD \
  "addSupportedChain(uint32)" \
  $BASE_EID \
  --rpc-url $WORLD_RPC \
  --private-key $PRIVATE_KEY
```

### Step 4: Register WGC Cross-Chain

```bash
cd packages/layerzero-contracts

export COMPOSER_ADDRESS=$COMPOSER_WORLD
export DST_EID=$BASE_EID
export TOKEN_IDS='["WGC"]'
export TOKEN_ADDRESSES='["'$WGC_BASE'"]'

forge script scripts/RegisterTokenCrossChain.s.sol:RegisterTokenCrossChainScript \
  --rpc-url $WORLD_RPC \
  --broadcast
```

### Step 5: Verify Registration

Wait 2-5 minutes for LayerZero to deliver the message, then verify:

```bash
# Check if WGC is registered on Base
cast call $COMPOSER_BASE \
  "tokenRegistry(bytes32)(address)" \
  $(cast keccak "WGC") \
  --rpc-url $BASE_RPC
```

**Expected output:** Your `$WGC_BASE` address

---

## 📝 Register Multiple Tokens at Once

You can register multiple tokens in a single cross-chain transaction:

```bash
export TOKEN_IDS='["WGC","USDT","USDC"]'
export TOKEN_ADDRESSES='["0xWGC_on_Base","0xUSDT_on_Base","0xUSDC_on_Base"]'

forge script scripts/RegisterTokenCrossChain.s.sol:RegisterTokenCrossChainScript \
  --rpc-url $WORLD_RPC \
  --broadcast
```

---

## 🔄 Complete Flow: Ship USDT/WGC Strategy

After registering WGC, here's the complete flow to ship a USDT/WGC strategy:

### 1. Register WGC (if not done)

```bash
# See Step 4 above
```

### 2. Ship USDT/WGC Strategy from World to Base

```bash
export COMPOSER_ADDRESS=$COMPOSER_WORLD
export DST_EID=$BASE_EID
export DST_APP=<your_stableswap_amm_on_base>

forge script scripts/shipUSDT_WGC_Strategy.s.sol:ShipUSDT_WGC_StrategyScript \
  --rpc-url $WORLD_RPC \
  --broadcast
```

**Save the `STRATEGY_HASH` from the output!**

### 3. Verify Strategy on Base

```bash
# Check Aqua balances for your LP address
cast call $AQUA_BASE \
  "balanceOf(address,bytes32,address)" \
  <LP_ADDRESS> \
  <STRATEGY_HASH> \
  $WGC_BASE \
  --rpc-url $BASE_RPC
```

---

## 🛠️ Troubleshooting

### Error: "InvalidDestinationChain"

**Solution:** Add the destination chain as supported:

```bash
cast send $COMPOSER_SOURCE \
  "addSupportedChain(uint32)" \
  $DST_EID \
  --rpc-url $SOURCE_RPC \
  --private-key $PRIVATE_KEY
```

### Error: "Peer not set"

**Solution:** Set up LayerZero peers (see Step 2 above)

### Token not registered after 5 minutes

**Possible causes:**
1. **Insufficient gas limit:** Try increasing `GAS_LIMIT` env var to 200000
2. **Insufficient fee:** The script adds 20% buffer, but you can manually increase it
3. **Message failed:** Check LayerZero scan with the GUID from the output

**Check message status:**
```
https://layerzeroscan.com/tx/<YOUR_GUID>
```

---

## 📊 Gas Costs

Approximate costs for cross-chain token registration:

| Operation | Source Chain Gas | LayerZero Fee | Total (USD) |
|-----------|-----------------|---------------|-------------|
| Register 1 token | ~50,000 gas | ~0.0001 ETH | ~$0.30 |
| Register 3 tokens | ~80,000 gas | ~0.00015 ETH | ~$0.45 |

*Costs vary based on network congestion and gas prices*

---

## 🔐 Security Notes

1. **Only owner can register tokens cross-chain** - The `registerTokensCrossChain()` function is `onlyOwner`
2. **Peer validation** - LayerZero ensures messages only come from trusted peers
3. **No token transfers** - This is a message-only operation; no tokens are moved

---

## 🎯 Summary

**Before (Manual):**
```bash
# On Base
cast send $COMPOSER_BASE "registerToken(...)" ... --rpc-url $BASE_RPC
```

**After (Cross-Chain):**
```bash
# From World Chain - registers on Base automatically
forge script scripts/RegisterTokenCrossChain.s.sol --rpc-url $WORLD_RPC --broadcast
```

**Benefits:**
- ✅ Single transaction from one chain
- ✅ Consistent token mappings across chains
- ✅ No need to manage keys on multiple chains
- ✅ Batch register multiple tokens at once

---

## 📚 Related Scripts

- `RegisterTokenCrossChain.s.sol` - Register tokens on destination chain
- `shipUSDT_WGC_Strategy.s.sol` - Ship USDT/WGC strategy cross-chain
- `shipStrategyToChain.s.sol` - Generic strategy shipping script

---

## 🆘 Need Help?

1. Check LayerZero message status: https://layerzeroscan.com
2. Verify composer configuration: `cast call $COMPOSER "peers(uint32)" $EID`
3. Check supported chains: `cast call $COMPOSER "supportedChains(uint32)" $EID`


