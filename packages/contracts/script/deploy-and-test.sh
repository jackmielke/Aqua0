#!/bin/bash

# Exit on error
set -e

# Check for --clean flag
CLEAN_MODE=false
if [ "$1" == "--clean" ]; then
    CLEAN_MODE=true
    echo "🧹 Clean mode: Removing existing deployment files..."
    rm -f script/deployed-mocks.txt
    rm -f script/deployed-strategies.txt
    rm -f script/concentrated-liquidity-strategy.txt
    rm -f script/stableswap-strategy.txt
    echo "✅ Cleaned up deployment files"
    echo ""
fi

# Load environment
if [ ! -f .env ]; then
    echo "Error: .env file not found!"
    echo "Please create a .env file with DEPLOYER_KEY and RPC_URL"
    exit 1
fi

source .env

if [ -z "$DEPLOYER_KEY" ] || [ -z "$RPC_URL" ]; then
    echo "Error: DEPLOYER_KEY and RPC_URL must be set in .env"
    exit 1
fi

if [ -z "$AQUA_ROUTER" ]; then
    echo "Error: AQUA_ROUTER must be set in .env"
    echo ""
    echo "Please add your AquaRouter address to .env:"
    echo "  AQUA_ROUTER=0xYourAquaRouterAddressHere"
    echo ""
    echo "If you don't have an AquaRouter deployed, you can:"
    echo "  1. Deploy one using the Aqua package"
    echo "  2. Or comment out this check to deploy a new Aqua contract"
    exit 1
fi

echo "=========================================="
echo "Aqua Testnet Deployment & Testing Script"
echo "=========================================="
echo ""
echo "✅ Using AquaRouter at: $AQUA_ROUTER"
echo ""

if [ "$CLEAN_MODE" = false ]; then
    echo "💡 Tip: Run with --clean to force redeployment of all contracts"
    echo ""
fi

# Step 1: Deploy mocks (or skip if already deployed)
if [ -f script/deployed-mocks.txt ]; then
    echo "=== Step 1/6: Mock Tokens (already deployed, skipping) ==="
    echo "Loading existing mock token addresses..."
else
    echo "=== Step 1/6: Deploying Mock Tokens ==="
    forge script script/DeployMocks.s.sol:DeployMocks \
      --rpc-url $RPC_URL \
      --broadcast \
      --legacy
    echo ""
    echo "✅ Mock tokens deployed"
fi
echo ""

# Step 2: Deploy strategies (or skip if already deployed)
if [ -f script/deployed-strategies.txt ]; then
    echo "=== Step 2/6: Strategies (already deployed, skipping) ==="
    echo "Loading existing strategy addresses..."
else
    echo "=== Step 2/6: Deploying Strategies ==="
    forge script script/DeployStrategies.s.sol:DeployStrategies \
      --rpc-url $RPC_URL \
      --broadcast \
      --legacy
    echo ""
    echo "✅ Strategies deployed"
fi
echo ""

# Load addresses from files
if [ ! -f script/deployed-mocks.txt ] || [ ! -f script/deployed-strategies.txt ]; then
    echo "Error: Deployment files not found!"
    exit 1
fi

# Export variables from files
set -a
source script/deployed-mocks.txt
source script/deployed-strategies.txt
set +a

echo "Loaded addresses:"
echo "  USDC: $USDC"
echo "  USDT: $USDT"
echo "  WETH: $WETH"
echo "  AQUA: $AQUA"
echo "  CONCENTRATED_LIQUIDITY: $CONCENTRATED_LIQUIDITY"
echo "  STABLESWAP: $STABLESWAP"
echo ""

# Step 3: Setup ConcentratedLiquidity (or skip if already set up)
if [ -f script/concentrated-liquidity-strategy.txt ]; then
    echo "=== Step 3/6: ConcentratedLiquidity Strategy (already set up, skipping) ==="
    echo "Loading existing strategy info..."
else
    echo "=== Step 3/6: Setting up ConcentratedLiquidity Strategy ==="
    forge script script/SetupConcentratedLiquidity.s.sol:SetupConcentratedLiquidity \
      --rpc-url $RPC_URL \
      --broadcast \
      --legacy
    echo ""
    echo "✅ ConcentratedLiquidity strategy setup complete"
fi
echo ""

# Step 4: Setup Stableswap (or skip if already set up)
if [ -f script/stableswap-strategy.txt ]; then
    echo "=== Step 4/6: Stableswap Strategy (already set up, skipping) ==="
    echo "Loading existing strategy info..."
else
    echo "=== Step 4/6: Setting up Stableswap Strategy ==="
    forge script script/SetupStableswap.s.sol:SetupStableswap \
      --rpc-url $RPC_URL \
      --broadcast \
      --legacy
    echo ""
    echo "✅ Stableswap strategy setup complete"
fi
echo ""

# Load strategy info
if [ -f script/concentrated-liquidity-strategy.txt ]; then
    set -a
    source script/concentrated-liquidity-strategy.txt
    set +a
fi
if [ -f script/stableswap-strategy.txt ]; then
    set -a
    source script/stableswap-strategy.txt
    set +a
fi

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

