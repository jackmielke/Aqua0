#!/bin/bash

# Exit on error
set -e

# Load environment
if [ ! -f .env ]; then
    echo "Error: .env file not found!"
    echo "Please create a .env file with PRIVATE_KEY and RPC_URL"
    exit 1
fi

source .env

if [ -z "$PRIVATE_KEY" ] || [ -z "$RPC_URL" ]; then
    echo "Error: PRIVATE_KEY and RPC_URL must be set in .env"
    exit 1
fi

echo "=========================================="
echo "Aqua Testnet Deployment & Testing Script"
echo "=========================================="
echo ""

# Step 1: Deploy mocks
echo "=== Step 1/6: Deploying Mock Tokens ==="
forge script script/DeployMocks.s.sol:DeployMocks \
  --rpc-url $RPC_URL \
  --broadcast \
  --legacy

echo ""
echo "✅ Mock tokens deployed"
echo ""

# Step 2: Deploy strategies
echo "=== Step 2/6: Deploying Aqua & Strategies ==="
forge script script/DeployStrategies.s.sol:DeployStrategies \
  --rpc-url $RPC_URL \
  --broadcast \
  --legacy

echo ""
echo "✅ Aqua and strategies deployed"
echo ""

# Load addresses
if [ ! -f script/deployed-mocks.txt ] || [ ! -f script/deployed-strategies.txt ]; then
    echo "Error: Deployment files not found!"
    exit 1
fi

source <(cat script/deployed-mocks.txt | sed 's/^/export /')
source <(cat script/deployed-strategies.txt | sed 's/^/export /')

echo "Loaded addresses:"
echo "  USDC: $USDC"
echo "  USDT: $USDT"
echo "  WETH: $WETH"
echo "  AQUA: $AQUA"
echo "  CONCENTRATED_LIQUIDITY: $CONCENTRATED_LIQUIDITY"
echo "  STABLESWAP: $STABLESWAP"
echo ""

# Step 3: Setup ConcentratedLiquidity
echo "=== Step 3/6: Setting up ConcentratedLiquidity Strategy ==="
forge script script/SetupConcentratedLiquidity.s.sol:SetupConcentratedLiquidity \
  --rpc-url $RPC_URL \
  --broadcast \
  --legacy

echo ""
echo "✅ ConcentratedLiquidity strategy setup complete"
echo ""

# Step 4: Setup Stableswap
echo "=== Step 4/6: Setting up Stableswap Strategy ==="
forge script script/SetupStableswap.s.sol:SetupStableswap \
  --rpc-url $RPC_URL \
  --broadcast \
  --legacy

echo ""
echo "✅ Stableswap strategy setup complete"
echo ""

# Reload all addresses
source <(cat script/concentrated-liquidity-strategy.txt | sed 's/^/export /')
source <(cat script/stableswap-strategy.txt | sed 's/^/export /')

# Step 5: Test ConcentratedLiquidity swaps
echo "=== Step 5/6: Testing ConcentratedLiquidity Swaps ==="
forge script script/TestConcentratedLiquiditySwap.s.sol:TestConcentratedLiquiditySwap \
  --rpc-url $RPC_URL \
  --broadcast \
  --legacy

echo ""
echo "✅ ConcentratedLiquidity swap tests complete"
echo ""

# Step 6: Test Stableswap swaps
echo "=== Step 6/6: Testing Stableswap Swaps ==="
forge script script/TestStableswapSwap.s.sol:TestStableswapSwap \
  --rpc-url $RPC_URL \
  --broadcast \
  --legacy

echo ""
echo "✅ Stableswap swap tests complete"
echo ""

echo "=========================================="
echo "🎉 All deployments and tests completed!"
echo "=========================================="
echo ""
echo "Deployed contracts:"
echo "  Aqua: $AQUA"
echo "  ConcentratedLiquidity: $CONCENTRATED_LIQUIDITY"
echo "  Stableswap: $STABLESWAP"
echo ""
echo "Mock tokens:"
echo "  USDC: $USDC"
echo "  USDT: $USDT"
echo "  WETH: $WETH"
echo ""
echo "Strategy info saved in:"
echo "  - script/concentrated-liquidity-strategy.txt"
echo "  - script/stableswap-strategy.txt"
echo ""

