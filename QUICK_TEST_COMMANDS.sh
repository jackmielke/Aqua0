#!/bin/bash
# Quick Test Commands for USDT/WGC Cross-Chain Swap
# All scripts have been updated to use WGC instead of rUSD

# ============================================
# SETUP ENVIRONMENT
# ============================================
export BASE_RPC=https://base-mainnet.infura.io/v3/1f4a9f2192c74a8399ab55d05cc3e24c
export WORLD_RPC=https://sparkling-autumn-dinghy.worldchain-mainnet.quiknode.pro
export BASE_EID=30184

export COMPOSER_BASE=0xEa224c362F583D4eE0f7f6fdd31ef124D4f95447
export COMPOSER_WORLD=0xc689cA9BC4C0176b8a0d50d4733A44Af83834Ae8

export USDT_BASE=0xeab8fa7ab28f05d7600558b873d5c7f805412304
export USDT_WORLD=0x13a3ca7638802f66ce4e12b101727405ec589f47
export WGC_BASE=0x3d63825b0d8669307366e6c8202f656b9e91d368
export WGC_WORLD=0x3d63825b0d8669307366e6c8202f656b9e91d368

export AQUA_BASE=0x36d500a364a3a82140420d1bcb5f8a90c8e352ef
export AMM_BASE=0xeb99024504f5e73Fc857E4B2a0CF076C7F91fa2E

export PRIVATE_KEY=0xdcd50c28a8f94a88efbbe8a45368ec37242b85f2b46667d067be65fdd007acbb
export LP_PRIVATE_KEY=0x5195b0e02b7ce24d5ab5c233f2beffe937a6dac0891739e43c2f2b3024595948
export TRADER_PRIVATE_KEY=<your_trader_key>

# YOU NEED TO SET THESE (find from Stargate docs)
export STARGATE_USDT_WORLD=<stargate_usdt_oft>
export STARGATE_WGC_WORLD=<stargate_wgc_oft>

# ============================================
# STEP 0: Register Tokens on Base (One-time)
# ============================================
echo "Step 0: Registering USDT and WGC on Base..."
cast send $COMPOSER_BASE \
  "registerTokens(bytes32[],address[])" \
  "[$(cast keccak "USDT"),$(cast keccak "WGC")]" \
  "[$USDT_BASE,$WGC_BASE]" \
  --rpc-url $BASE_RPC \
  --private-key $PRIVATE_KEY

# ============================================
# STEP 1: Ship Strategy (One-time)
# ============================================
echo "Step 1: Shipping USDT/WGC strategy to Base..."
cd packages/layerzero-contracts

export COMPOSER_ADDRESS=$COMPOSER_WORLD
export DST_EID=$BASE_EID
export DST_APP=$AMM_BASE

forge script scripts/shipStrategyToChain.s.sol:ShipStrategyToChainScript \
  --rpc-url $WORLD_RPC \
  --broadcast

# SAVE THE STRATEGY_HASH!
read -p "Enter STRATEGY_HASH from output: " STRATEGY_HASH
export STRATEGY_HASH

# ============================================
# STEP 2: Deploy IntentPool (One-time)
# ============================================
echo "Step 2: Deploying IntentPool on World..."
export COMPOSER_ADDRESS=$COMPOSER_BASE

forge script scripts/deploy/DeployIntentPool.s.sol:DeployIntentPool \
  --rpc-url $WORLD_RPC \
  --broadcast

# SAVE THE INTENT_POOL ADDRESS!
read -p "Enter INTENT_POOL_WORLD address: " INTENT_POOL_WORLD
export INTENT_POOL_WORLD

# ============================================
# STEP 3: Register Strategy (One-time)
# ============================================
echo "Step 3: Registering strategy in IntentPool..."
export INTENT_POOL=$INTENT_POOL_WORLD

forge script scripts/intent/RegisterStrategy.s.sol:RegisterStrategy \
  --rpc-url $WORLD_RPC \
  --broadcast

# ============================================
# STEP 4: Submit Intent (Trader)
# ============================================
echo "Step 4: Trader submitting intent..."
export INTENT_POOL_ADDRESS=$INTENT_POOL_WORLD
export SWAP_AMOUNT_IN=1000000  # 1 USDT

forge script scripts/intent/Step1_SubmitIntent.s.sol:Step1_SubmitIntent \
  --rpc-url $WORLD_RPC \
  --broadcast

# SAVE THE INTENT_ID!
read -p "Enter INTENT_ID from output: " INTENT_ID
export INTENT_ID

# ============================================
# STEP 5: Fulfill Intent (LP)
# ============================================
echo "Step 5: LP fulfilling intent..."
export INTENT_POOL_ADDRESS=$INTENT_POOL_WORLD

forge script scripts/intent/Step2_FulfillIntent.s.sol:Step2_FulfillIntent \
  --rpc-url $WORLD_RPC \
  --broadcast

# ============================================
# STEP 6: Settle Intent
# ============================================
echo "Step 6: Settling intent..."
export INTENT_POOL_ADDRESS=$INTENT_POOL_WORLD

forge script scripts/intent/Step3_SettleIntent.s.sol:Step3_SettleIntent \
  --rpc-url $WORLD_RPC \
  --broadcast

echo "✅ Settlement initiated!"
echo "⏳ Wait 5-10 minutes for cross-chain execution..."

# ============================================
# STEP 7: Verify Results
# ============================================
echo "Waiting 5 minutes before checking results..."
sleep 300

export TRADER_ADDRESS=$(cast wallet address --private-key $TRADER_PRIVATE_KEY)
export LP_ADDRESS=$(cast wallet address --private-key $LP_PRIVATE_KEY)

echo "Trader WGC balance:"
cast call $WGC_WORLD "balanceOf(address)" $TRADER_ADDRESS --rpc-url $WORLD_RPC

echo "LP USDT balance:"
cast call $USDT_WORLD "balanceOf(address)" $LP_ADDRESS --rpc-url $WORLD_RPC

echo "✅ Test complete!"


