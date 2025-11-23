# 🚀 USDT/WGC Strategy Deployment - Command Reference

## Quick Setup

```bash
# === Environment ===
export WORLD_RPC=https://worldchain-mainnet.g.alchemy.com/public
export BASE_RPC=https://mainnet.base.org
export WORLD_EID=30309
export BASE_EID=30184

# === Your Deployed Contracts ===
export AQUA_BASE=0x36d500a364a3a82140420d1bcb5f8a90c8e352ef
export COMPOSER_WORLD=<your_composer_on_world>
export COMPOSER_BASE=<your_composer_on_base>
export AMM_BASE=<your_stableswap_amm_on_base>

# === Tokens ===
export USDT_BASE=0x102d758f688a4C1C5a80b116bD945d4455460282
export WGC_BASE=<wgc_address_on_base>

# === Keys ===
export PRIVATE_KEY=0x...
export LP_PRIVATE_KEY=0x...
```

---

## Step 1: Register WGC Token Cross-Chain

**From World Chain → Register on Base:**

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

**Wait 2-5 minutes, then verify:**

```bash
cast call $COMPOSER_BASE \
  "tokenRegistry(bytes32)(address)" \
  $(cast keccak "WGC") \
  --rpc-url $BASE_RPC
```

---

## Step 2: Ship USDT/WGC Strategy

**From World Chain → Ship to Base:**

```bash
export COMPOSER_ADDRESS=$COMPOSER_WORLD
export DST_EID=$BASE_EID
export DST_APP=$AMM_BASE

forge script scripts/shipUSDT_WGC_Strategy.s.sol:ShipUSDT_WGC_StrategyScript \
  --rpc-url $WORLD_RPC \
  --broadcast
```

**Save the `STRATEGY_HASH` from the output!**

---

## Step 3: Verify Strategy on Base

```bash
export LP_ADDRESS=$(cast wallet address --private-key $LP_PRIVATE_KEY)
export STRATEGY_HASH=<from_step_2_output>

# Check USDT balance
cast call $AQUA_BASE \
  "balanceOf(address,bytes32,address)" \
  $LP_ADDRESS \
  $STRATEGY_HASH \
  $USDT_BASE \
  --rpc-url $BASE_RPC

# Check WGC balance
cast call $AQUA_BASE \
  "balanceOf(address,bytes32,address)" \
  $LP_ADDRESS \
  $STRATEGY_HASH \
  $WGC_BASE \
  --rpc-url $BASE_RPC
```

---

## Optional: Register Multiple Tokens at Once

```bash
export TOKEN_IDS='["WGC","ANOTHER_TOKEN"]'
export TOKEN_ADDRESSES='["'$WGC_BASE'","0xAnotherTokenAddress"]'

forge script scripts/RegisterTokenCrossChain.s.sol:RegisterTokenCrossChainScript \
  --rpc-url $WORLD_RPC \
  --broadcast
```

---

## Troubleshooting Commands

### Check if chain is supported

```bash
cast call $COMPOSER_WORLD \
  "supportedChains(uint32)(bool)" \
  $BASE_EID \
  --rpc-url $WORLD_RPC
```

**If false, add it:**

```bash
cast send $COMPOSER_WORLD \
  "addSupportedChain(uint32)" \
  $BASE_EID \
  --rpc-url $WORLD_RPC \
  --private-key $PRIVATE_KEY
```

### Check LayerZero peers

```bash
# Check World → Base peer
cast call $COMPOSER_WORLD \
  "peers(uint32)(bytes32)" \
  $BASE_EID \
  --rpc-url $WORLD_RPC

# Check Base → World peer
cast call $COMPOSER_BASE \
  "peers(uint32)(bytes32)" \
  $WORLD_EID \
  --rpc-url $BASE_RPC
```

### Set peers (if needed)

```bash
# On World - set Base as peer
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

### Track LayerZero message

After any cross-chain operation, you'll get a GUID. Track it at:

```
https://layerzeroscan.com/tx/<YOUR_GUID>
```

---

## Summary

✅ **Step 1:** Register WGC token on Base (cross-chain)  
✅ **Step 2:** Ship USDT/WGC strategy to Base (cross-chain)  
✅ **Step 3:** Verify strategy balances on Base

**Total time:** ~5-10 minutes (including LayerZero message delivery)

**Total transactions:** 2 (both from World Chain)

---

## What Changed from Your Original Error?

**Your original command:**
```bash
cast send $COMPOSER_BASE \
  "registerTokens(bytes32[],address[])" \
  "[$(cast keccak "USDC"),$(cast keccak "USDT")]" \
  "[$USDC_BASE,$USDT_BASE]" \
  --rpc-url $RPC_URL_BASE \
  --private-key $PRIVATE_KEY
```

**Error:** `$COMPOSER_BASE` was not set, so `cast` interpreted the function signature as the address.

**New approach:**
- ✅ Register tokens cross-chain from World (no need to transact on Base)
- ✅ Use Forge scripts instead of raw `cast send` for better validation
- ✅ Proper JSON array formatting for multiple tokens
- ✅ Automatic fee calculation and gas estimation

---

## Files Created

1. **`AquaStrategyComposer.sol`** - Updated with cross-chain token registration
2. **`RegisterTokenCrossChain.s.sol`** - Script to register tokens cross-chain
3. **`shipUSDT_WGC_Strategy.s.sol`** - Script to ship USDT/WGC strategy
4. **`CROSS_CHAIN_TOKEN_REGISTRATION.md`** - Detailed guide
5. **`USDT_WGC_STRATEGY_COMMANDS.md`** - This quick reference

---

## Need More Token Pairs?

To add another pair (e.g., USDC/DAI):

1. Register both tokens (if not already registered):
   ```bash
   export TOKEN_IDS='["USDC","DAI"]'
   export TOKEN_ADDRESSES='["0xUSDC_on_Base","0xDAI_on_Base"]'
   forge script scripts/RegisterTokenCrossChain.s.sol --rpc-url $WORLD_RPC --broadcast
   ```

2. Create a new strategy script (copy `shipUSDT_WGC_Strategy.s.sol` and modify token IDs)

3. Ship the strategy!


