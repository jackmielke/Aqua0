#!/bin/bash

# Check environment setup for Base mainnet deployment
# Run this before deploying to verify everything is configured

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "Aqua Base Mainnet Environment Checker"
echo "=========================================="
echo ""

# Load .env if exists
if [ ! -f .env ]; then
    echo -e "${RED}❌ .env file not found!${NC}"
    echo ""
    echo "Please create a .env file with the following variables:"
    echo "  DEPLOYER_KEY=0x..."
    echo "  LP_PRIVATE_KEY=0x..."
    echo "  SWAPPER_PRIVATE_KEY=0x..."
    echo "  BASE_RPC_URL=https://mainnet.base.org"
    echo "  AQUA_ROUTER_BASE=0x..."
    echo ""
    exit 1
fi

source .env

ERRORS=0
WARNINGS=0

# Check private keys
echo "Checking private keys..."
if [ -z "$DEPLOYER_KEY" ]; then
    echo -e "${RED}❌ DEPLOYER_KEY not set${NC}"
    ERRORS=$((ERRORS + 1))
else
    echo -e "${GREEN}✓ DEPLOYER_KEY set${NC}"
    DEPLOYER=$(cast wallet address --private-key $DEPLOYER_KEY 2>/dev/null || echo "invalid")
    if [ "$DEPLOYER" == "invalid" ]; then
        echo -e "${RED}  ❌ Invalid DEPLOYER_KEY format${NC}"
        ERRORS=$((ERRORS + 1))
    else
        echo "  Address: $DEPLOYER"
    fi
fi

if [ -z "$LP_PRIVATE_KEY" ]; then
    echo -e "${RED}❌ LP_PRIVATE_KEY not set${NC}"
    ERRORS=$((ERRORS + 1))
else
    echo -e "${GREEN}✓ LP_PRIVATE_KEY set${NC}"
    LP=$(cast wallet address --private-key $LP_PRIVATE_KEY 2>/dev/null || echo "invalid")
    if [ "$LP" == "invalid" ]; then
        echo -e "${RED}  ❌ Invalid LP_PRIVATE_KEY format${NC}"
        ERRORS=$((ERRORS + 1))
    else
        echo "  Address: $LP"
    fi
fi

if [ -z "$SWAPPER_PRIVATE_KEY" ]; then
    echo -e "${RED}❌ SWAPPER_PRIVATE_KEY not set${NC}"
    ERRORS=$((ERRORS + 1))
else
    echo -e "${GREEN}✓ SWAPPER_PRIVATE_KEY set${NC}"
    SWAPPER=$(cast wallet address --private-key $SWAPPER_PRIVATE_KEY 2>/dev/null || echo "invalid")
    if [ "$SWAPPER" == "invalid" ]; then
        echo -e "${RED}  ❌ Invalid SWAPPER_PRIVATE_KEY format${NC}"
        ERRORS=$((ERRORS + 1))
    else
        echo "  Address: $SWAPPER"
    fi
fi

echo ""

# Check RPC URL
echo "Checking Base RPC URL..."
if [ -z "$BASE_RPC_URL" ]; then
    echo -e "${RED}❌ BASE_RPC_URL not set${NC}"
    ERRORS=$((ERRORS + 1))
else
    echo -e "${GREEN}✓ BASE_RPC_URL set${NC}"
    echo "  $BASE_RPC_URL"
fi

echo ""

# Check Aqua Router address
echo "Checking Aqua Router address..."
if [ -z "$AQUA_ROUTER_BASE" ]; then
    echo -e "${RED}❌ AQUA_ROUTER_BASE not set${NC}"
    echo "  Contact Aqua team for the deployed AquaRouter address on Base"
    ERRORS=$((ERRORS + 1))
else
    echo -e "${GREEN}✓ AQUA_ROUTER_BASE set${NC}"
    echo "  $AQUA_ROUTER_BASE"
fi

echo ""

# Check token balances on Base if RPC is available
if [ ! -z "$BASE_RPC_URL" ] && [ ! -z "$LP" ] && [ "$LP" != "invalid" ]; then
    echo "Checking Base token balances for LP..."
    
    USDC_BASE=0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
    USDT_BASE=0x102d758f688a4C1C5a80b116bD945d4455460282
    
    USDC_BAL=$(cast call $USDC_BASE "balanceOf(address)(uint256)" $LP --rpc-url $BASE_RPC_URL 2>/dev/null || echo "0")
    USDT_BAL=$(cast call $USDT_BASE "balanceOf(address)(uint256)" $LP --rpc-url $BASE_RPC_URL 2>/dev/null || echo "0")
    
    # Convert to readable format using bc or awk to handle large numbers
    USDC_READABLE=$(echo "$USDC_BAL" | awk '{printf "%.0f", $1 / 1000000}')
    USDT_READABLE=$(echo "$USDT_BAL" | awk '{printf "%.0f", $1 / 1000000}')
    
    echo "LP Balances on Base:"
    if [ "$USDC_READABLE" -lt 2 ]; then
        echo -e "${YELLOW}  ⚠ USDC: $USDC_READABLE (need 4+ for both strategies)${NC}"
        WARNINGS=$((WARNINGS + 1))
    else
        echo -e "${GREEN}  ✓ USDC: $USDC_READABLE${NC}"
    fi
    
    if [ "$USDT_READABLE" -lt 2 ]; then
        echo -e "${YELLOW}  ⚠ USDT: $USDT_READABLE (need 4+ for both strategies)${NC}"
        WARNINGS=$((WARNINGS + 1))
    else
        echo -e "${GREEN}  ✓ USDT: $USDT_READABLE${NC}"
    fi
    
    echo ""
    
    # Check swapper balance
    if [ ! -z "$SWAPPER" ] && [ "$SWAPPER" != "invalid" ]; then
        echo "Checking Base token balances for Swapper..."
        SWAPPER_USDC=$(cast call $USDC_BASE "balanceOf(address)(uint256)" $SWAPPER --rpc-url $BASE_RPC_URL 2>/dev/null || echo "0")
        SWAPPER_USDC_READABLE=$(echo "$SWAPPER_USDC" | awk '{printf "%.0f", $1 / 1000000}')
        
        if [ "$SWAPPER_USDC_READABLE" -lt 1 ]; then
            echo -e "${YELLOW}  ⚠ USDC: $SWAPPER_USDC_READABLE (need 100+ for swap tests)${NC}"
            WARNINGS=$((WARNINGS + 1))
        else
            echo -e "${GREEN}  ✓ USDC: $SWAPPER_USDC_READABLE${NC}"
        fi
    fi
fi

echo ""
echo "=========================================="
echo "Summary"
echo "=========================================="

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✅ All checks passed! Ready to deploy on Base.${NC}"
    echo ""
    echo "Next step:"
    echo "  ./script/deploy-and-test.sh"
    echo ""
    echo "Note: Script defaults to Base network"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠ $WARNINGS warning(s) found${NC}"
    echo ""
    if [ $WARNINGS -gt 0 ]; then
        echo "Recommended token balances:"
        echo "  LP: 4 USDC + 4 USDT (2 per strategy)"
        echo "  Swapper: 100+ USDC (for testing)"
        echo ""
    fi
    echo "You can proceed, but consider addressing warnings first."
    exit 0
else
    echo -e "${RED}❌ $ERRORS error(s) and $WARNINGS warning(s) found${NC}"
    echo ""
    echo "Required environment variables:"
    echo "  DEPLOYER_KEY       - Deployer wallet private key"
    echo "  LP_PRIVATE_KEY     - LP wallet with USDC+USDT"
    echo "  SWAPPER_PRIVATE_KEY - Swapper wallet with USDC"
    echo "  BASE_RPC_URL       - Base mainnet RPC URL"
    echo "  AQUA_ROUTER_BASE   - Deployed AquaRouter address"
    echo ""
    echo "Please fix errors before deploying."
    exit 1
fi
