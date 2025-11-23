#!/bin/bash

# Exit on error
set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}=========================================="
echo "Aqua Base Mainnet Deployment & Testing"
echo -e "==========================================${NC}"
echo ""

# Check for network argument (default to base)
NETWORK=${1:-base}

if [ "$NETWORK" != "base" ]; then
    echo -e "${YELLOW}Note: Currently optimized for Base mainnet deployment${NC}"
    echo "Other networks can be added later"
    echo ""
fi

# Load environment
if [ ! -f .env ]; then
    echo "Error: .env file not found!"
    echo "Please create a .env file with required variables"
    exit 1
fi

source .env

# Validate required environment variables
if [ -z "$DEPLOYER_KEY" ]; then
    echo "Error: DEPLOYER_KEY must be set in .env"
    exit 1
fi

if [ -z "$LP_PRIVATE_KEY" ]; then
    echo "Error: LP_PRIVATE_KEY must be set in .env (the wallet with USDC/USDT tokens)"
    exit 1
fi

if [ -z "$SWAPPER_PRIVATE_KEY" ]; then
    echo "Error: SWAPPER_PRIVATE_KEY must be set in .env (for testing swaps)"
    exit 1
fi

# Set network-specific variables
if [ "$NETWORK" == "base" ]; then
    if [ -z "$BASE_RPC_URL" ]; then
        echo "Error: BASE_RPC_URL must be set in .env"
        exit 1
    fi
    RPC_URL=$BASE_RPC_URL
    
    # Base mainnet addresses
    export USDC=0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
    export USDT=0x102d758f688a4C1C5a80b116bD945d4455460282
    export AQUA_ROUTER=${AQUA_ROUTER_BASE:-""}
    
    NETWORK_NAME="Base"
    
else
    echo "Error: Network '$NETWORK' not configured yet"
    echo "Currently supporting: base"
    echo ""
    echo "To add support for other networks, update the script or contact the team"
    exit 1
fi

# Validate AQUA_ROUTER is set
if [ -z "$AQUA_ROUTER" ]; then
    echo -e "${YELLOW}Error: AQUA_ROUTER not set for Base${NC}"
    echo ""
    echo "Please add to your .env file:"
    echo "  AQUA_ROUTER_BASE=0xYourAquaRouterAddressHere"
    echo ""
    echo "Contact the Aqua team for the deployed AquaRouter address on Base"
    exit 1
fi

echo -e "${GREEN}✓ Network: $NETWORK_NAME${NC}"
echo -e "${GREEN}✓ RPC URL: $RPC_URL${NC}"
echo -e "${GREEN}✓ AquaRouter: $AQUA_ROUTER${NC}"
echo -e "${GREEN}✓ USDC: $USDC${NC}"
echo -e "${GREEN}✓ USDT: $USDT${NC}"
echo ""

# Get wallet addresses
DEPLOYER=$(cast wallet address --private-key $DEPLOYER_KEY)
LP=$(cast wallet address --private-key $LP_PRIVATE_KEY)
SWAPPER=$(cast wallet address --private-key $SWAPPER_PRIVATE_KEY)

echo "Wallet Addresses:"
echo "  Deployer: $DEPLOYER"
echo "  LP:       $LP"
echo "  Swapper:  $SWAPPER"
echo ""

# Check LP token balances
echo "Checking LP token balances..."
USDC_BALANCE=$(cast call $USDC "balanceOf(address)(uint256)" $LP --rpc-url $RPC_URL)
USDT_BALANCE=$(cast call $USDT "balanceOf(address)(uint256)" $LP --rpc-url $RPC_URL)

# Use awk to handle large numbers and scientific notation
USDC_BALANCE_READABLE=$(echo "$USDC_BALANCE" | awk '{printf "%.0f", $1 / 1000000}')
USDT_BALANCE_READABLE=$(echo "$USDT_BALANCE" | awk '{printf "%.0f", $1 / 1000000}')

echo "LP Balances:"
echo "  USDC: $USDC_BALANCE_READABLE USDC"
echo "  USDT: $USDT_BALANCE_READABLE USDT"
echo ""

if [ "$USDC_BALANCE_READABLE" -lt 2 ] || [ "$USDT_BALANCE_READABLE" -lt 2 ]; then
    echo -e "${YELLOW}Warning: LP has insufficient token balances for default liquidity (2 USDC + 2 USDT).${NC}"
    echo "Please fund the LP wallet or adjust USDC_LIQUIDITY and USDT_LIQUIDITY in .env"
    echo ""
fi

# Step 1: Deploy strategies
echo -e "${BLUE}=== Step 1/4: Deploying Strategies ===${NC}"

if [ -f script/deployed-strategies.txt ]; then
    echo -e "${YELLOW}Strategies already deployed, skipping...${NC}"
    echo "To redeploy, delete script/deployed-strategies.txt"
else
    forge script script/DeployStrategies.s.sol:DeployStrategies \
      --rpc-url $RPC_URL \
      --broadcast \
      --legacy
    echo -e "${GREEN}✓ Strategies deployed${NC}"
fi
echo ""

# Load strategy addresses
if [ ! -f script/deployed-strategies.txt ]; then
    echo "Error: Deployment file not found!"
    exit 1
fi

set -a
source script/deployed-strategies.txt
set +a

echo "Deployed Contracts:"
echo "  Aqua: $AQUA"
echo "  ConcentratedLiquidity: $CONCENTRATED_LIQUIDITY"
echo "  Stableswap: $STABLESWAP"
echo ""

# Step 2: Setup Stableswap Strategy
echo -e "${BLUE}=== Step 2/4: Setting up Stableswap Strategy ===${NC}"

if [ -f script/stableswap-strategy.txt ]; then
    echo -e "${YELLOW}Stableswap strategy already set up, skipping...${NC}"
    echo "To redeploy, delete script/stableswap-strategy.txt"
else
    # Set liquidity amounts (2 USDC / 2 USDT default, can be overridden in .env)
    export USDC_LIQUIDITY=${USDC_LIQUIDITY:-2000000}  # 2 USDC default
    export USDT_LIQUIDITY=${USDT_LIQUIDITY:-2000000}  # 2 USDT default
    
    echo "Liquidity amounts:"
    echo "  USDC: $(($USDC_LIQUIDITY / 1000000)) USDC"
    echo "  USDT: $(($USDT_LIQUIDITY / 1000000)) USDT"
    
    forge script script/SetupStableswap.s.sol:SetupStableswap \
      --rpc-url $RPC_URL \
      --broadcast \
      --legacy
    echo -e "${GREEN}✓ Stableswap strategy setup complete${NC}"
fi
echo ""

# Step 3: Setup Concentrated Liquidity Strategy
echo -e "${BLUE}=== Step 3/4: Setting up Concentrated Liquidity Strategy ===${NC}"

if [ -f script/concentrated-liquidity-strategy.txt ]; then
    echo -e "${YELLOW}Concentrated Liquidity strategy already set up, skipping...${NC}"
    echo "To redeploy, delete script/concentrated-liquidity-strategy.txt"
else
    # Use same liquidity amounts (2 USDC / 2 USDT default)
    export USDC_LIQUIDITY=${USDC_LIQUIDITY:-2000000}  # 2 USDC default
    export USDT_LIQUIDITY=${USDT_LIQUIDITY:-2000000}  # 2 USDT default
    
    echo "Liquidity amounts:"
    echo "  USDC: $(($USDC_LIQUIDITY / 1000000)) USDC"
    echo "  USDT: $(($USDT_LIQUIDITY / 1000000)) USDT"
    
    forge script script/SetupConcentratedLiquidity.s.sol:SetupConcentratedLiquidity \
      --rpc-url $RPC_URL \
      --broadcast \
      --legacy
    echo -e "${GREEN}✓ Concentrated Liquidity strategy setup complete${NC}"
fi
echo ""

# Load strategy info
if [ -f script/stableswap-strategy.txt ]; then
    set -a
    source script/stableswap-strategy.txt
    set +a
fi

# Step 4: Test Stableswap Swap
echo -e "${BLUE}=== Step 4/4: Testing Stableswap Swap ===${NC}"

# Check swapper balance
SWAPPER_USDC=$(cast call $USDC "balanceOf(address)(uint256)" $SWAPPER --rpc-url $RPC_URL)
SWAPPER_USDC_READABLE=$(echo "$SWAPPER_USDC" | awk '{printf "%.0f", $1 / 1000000}')

echo "Swapper USDC Balance: $SWAPPER_USDC_READABLE USDC"

if [ "$SWAPPER_USDC_READABLE" -lt 1 ]; then
    echo -e "${YELLOW}Warning: Swapper has low USDC balance. Consider funding the swapper wallet.${NC}"
    echo "Skipping swap test..."
else
    # Set swap amount (default 1 USDC)
    export SWAP_AMOUNT=${SWAP_AMOUNT:-1000000}
    
forge script script/TestStableswapSwap.s.sol:TestStableswapSwap \
  --rpc-url $RPC_URL \
  --broadcast \
  --legacy
    echo -e "${GREEN}✓ Swap test complete${NC}"
fi
echo ""

echo -e "${GREEN}=========================================="
echo "Deployment and Testing Complete!"
echo -e "==========================================${NC}"
echo ""
echo "Network: $NETWORK_NAME"
echo "Aqua: $AQUA"
echo "Stableswap: $STABLESWAP"
echo "ConcentratedLiquidity: $CONCENTRATED_LIQUIDITY"
echo ""
echo "Strategy info saved in:"
echo "  - script/stableswap-strategy.txt"
echo "  - script/concentrated-liquidity-strategy.txt"
echo ""
