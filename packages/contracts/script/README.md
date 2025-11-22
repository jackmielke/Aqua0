# Testnet Deployment & Testing Scripts

This directory contains scripts for deploying and testing Aqua trading strategies on testnets.

## Quick Start

**For Base Sepolia with existing AquaRouter**, see [QUICKSTART.md](../QUICKSTART.md) for a streamlined guide.

## Prerequisites

1. **Set up environment variables** in `.env` file:

```bash
# Your private key (without 0x prefix)
DEPLOYER_KEY=your_private_key_here

# RPC URL for your testnet (e.g., Sepolia, Base Sepolia, etc.)
RPC_URL=https://sepolia.infura.io/v3/YOUR_PROJECT_ID

# AquaRouter address (REQUIRED)
# This should be your deployed AquaRouter contract address
AQUA_ROUTER=0xYourAquaRouterAddress

# Etherscan API key for verification (optional)
ETHERSCAN_API_KEY=your_etherscan_api_key
```

2. **Fund your wallet** with testnet ETH from a faucet

## Deployment Flow

### Step 1: Deploy Mock Tokens

Deploy mock USDC, USDT, and WETH tokens for testing:

```bash
forge script script/DeployMocks.s.sol:DeployMocks \
  --rpc-url $RPC_URL \
  --broadcast \
  --verify
```

**Output**: Creates `script/deployed-mocks.txt` with token addresses

### Step 2: Deploy Strategies

Deploy both trading strategies (using your existing AquaRouter):

```bash
forge script script/DeployStrategies.s.sol:DeployStrategies \
  --rpc-url $RPC_URL \
  --broadcast \
  --verify
```

**Output**: Creates `script/deployed-strategies.txt` with contract addresses

### Step 3: Setup ConcentratedLiquidity Strategy

Create and fund a USDC/WETH concentrated liquidity strategy:

```bash
# Load addresses from previous deployments
source <(cat script/deployed-mocks.txt | sed 's/^/export /')
source <(cat script/deployed-strategies.txt | sed 's/^/export /')

forge script script/SetupConcentratedLiquidity.s.sol:SetupConcentratedLiquidity \
  --rpc-url $RPC_URL \
  --broadcast
```

**Output**: Creates `script/concentrated-liquidity-strategy.txt` with strategy info

**What it does**:
- Approves Aqua to spend your USDC and WETH
- Ships 100,000 USDC and 50 WETH to the strategy
- Creates a strategy with 0.3% fee and wide price range

### Step 4: Setup Stableswap Strategy

Create and fund a USDC/USDT stableswap strategy:

```bash
forge script script/SetupStableswap.s.sol:SetupStableswap \
  --rpc-url $RPC_URL \
  --broadcast
```

**Output**: Creates `script/stableswap-strategy.txt` with strategy info

**What it does**:
- Approves Aqua to spend your USDC and USDT
- Ships 100,000 USDC and 100,000 USDT to the strategy
- Creates a strategy with 0.04% fee and amplification factor of 100

## Testing Swaps

### Test ConcentratedLiquidity Swaps

Test USDC <> WETH swaps on the concentrated liquidity strategy:

```bash
# Load all addresses
source <(cat script/deployed-mocks.txt | sed 's/^/export /')
source <(cat script/deployed-strategies.txt | sed 's/^/export /')
source <(cat script/concentrated-liquidity-strategy.txt | sed 's/^/export /')

forge script script/TestConcentratedLiquiditySwap.s.sol:TestConcentratedLiquiditySwap \
  --rpc-url $RPC_URL \
  --broadcast
```

**Tests performed**:
1. Swap 1000 USDC for WETH
2. Swap 0.5 WETH for USDC

### Test Stableswap Swaps

Test USDC <> USDT swaps on the stableswap strategy:

```bash
# Load all addresses
source <(cat script/deployed-mocks.txt | sed 's/^/export /')
source <(cat script/deployed-strategies.txt | sed 's/^/export /')
source <(cat script/stableswap-strategy.txt | sed 's/^/export /')

forge script script/TestStableswapSwap.s.sol:TestStableswapSwap \
  --rpc-url $RPC_URL \
  --broadcast
```

**Tests performed**:
1. Swap 1000 USDC for USDT (small trade)
2. Swap 500 USDT for USDC (reverse direction)
3. Swap 10,000 USDC for USDT (large trade to test slippage)

## Complete Deployment Script

For convenience, here's a complete deployment and testing script:

```bash
#!/bin/bash

# Load environment
source .env

# Step 1: Deploy mocks
echo "=== Deploying Mock Tokens ==="
forge script script/DeployMocks.s.sol:DeployMocks \
  --rpc-url $RPC_URL \
  --broadcast

# Step 2: Deploy strategies
echo "=== Deploying Aqua & Strategies ==="
forge script script/DeployStrategies.s.sol:DeployStrategies \
  --rpc-url $RPC_URL \
  --broadcast

# Load addresses
source <(cat script/deployed-mocks.txt | sed 's/^/export /')
source <(cat script/deployed-strategies.txt | sed 's/^/export /')

# Step 3: Setup ConcentratedLiquidity
echo "=== Setting up ConcentratedLiquidity Strategy ==="
forge script script/SetupConcentratedLiquidity.s.sol:SetupConcentratedLiquidity \
  --rpc-url $RPC_URL \
  --broadcast

# Step 4: Setup Stableswap
echo "=== Setting up Stableswap Strategy ==="
forge script script/SetupStableswap.s.sol:SetupStableswap \
  --rpc-url $RPC_URL \
  --broadcast

# Reload all addresses
source <(cat script/concentrated-liquidity-strategy.txt | sed 's/^/export /')
source <(cat script/stableswap-strategy.txt | sed 's/^/export /')

# Step 5: Test ConcentratedLiquidity swaps
echo "=== Testing ConcentratedLiquidity Swaps ==="
forge script script/TestConcentratedLiquiditySwap.s.sol:TestConcentratedLiquiditySwap \
  --rpc-url $RPC_URL \
  --broadcast

# Step 6: Test Stableswap swaps
echo "=== Testing Stableswap Swaps ==="
forge script script/TestStableswapSwap.s.sol:TestStableswapSwap \
  --rpc-url $RPC_URL \
  --broadcast

echo "=== All tests completed! ==="
```

Save this as `script/deploy-and-test.sh` and run:

```bash
chmod +x script/deploy-and-test.sh
./script/deploy-and-test.sh
```

## Understanding the Aqua Flow

### 1. Maker (Liquidity Provider) Flow

```
Maker Wallet
    ↓ (approve tokens)
    ↓ (ship strategy)
Aqua Protocol (virtual accounting)
    ↓ (strategy active)
Strategy Contract (ConcentratedLiquidity or Stableswap)
```

**Key points**:
- Tokens stay in maker's wallet
- Aqua tracks virtual balances
- Maker can dock strategy anytime to revoke liquidity

### 2. Taker (Trader) Flow

```
Taker
    ↓ (calls swapExactIn)
Strategy Contract
    ↓ (pulls output tokens via Aqua)
Maker Wallet → Taker
    ↓ (callback: taker pushes input tokens)
Taker → Maker Wallet (via Aqua.push)
```

**Key points**:
- Strategy quotes price based on virtual balances
- Aqua pulls output tokens from maker's wallet
- Taker must implement callback to push input tokens back
- All operations are atomic (succeed or revert together)

## Troubleshooting

### "Insufficient balance" error

Make sure you have enough mock tokens:
- Check balances: `cast balance --erc20 $USDC $YOUR_ADDRESS`
- Mint more tokens if needed (mock tokens allow anyone to mint)

### "Insufficient liquidity" error

The strategy doesn't have enough virtual balance:
- Check strategy balances in Aqua
- Ship more liquidity to the strategy
- Or reduce swap amount

### "Price out of range" error (ConcentratedLiquidity only)

The swap would move price outside the configured range:
- Use smaller swap amounts
- Or create a new strategy with wider price range

### Transaction reverts with no message

Likely an approval issue:
- Ensure Aqua is approved to spend your tokens
- Check that swapper contract is approved to spend your tokens

## Supported Testnets

These scripts work on any EVM-compatible testnet:
- Ethereum Sepolia
- Base Sepolia
- Optimism Sepolia
- Arbitrum Sepolia
- Polygon Mumbai
- BSC Testnet

Just update your `RPC_URL` in `.env` to the appropriate testnet.

## Gas Optimization

All contracts are compiled with:
- IR-based optimization (`via_ir = true`)
- 200 optimizer runs
- Efficient callback patterns
- Minimal storage operations

Typical gas costs:
- Deploy Aqua: ~1.5M gas
- Deploy Strategy: ~2-3M gas
- Ship strategy: ~150-200k gas
- Swap: ~150-250k gas

## Next Steps

After successful testnet deployment:

1. **Monitor strategy performance**:
   - Track virtual balances in Aqua
   - Monitor swap volumes and fees earned
   - Analyze slippage patterns

2. **Experiment with parameters**:
   - Try different fee tiers
   - Adjust price ranges (ConcentratedLiquidity)
   - Test different amplification factors (Stableswap)

3. **Test edge cases**:
   - Very large swaps
   - Rapid sequential swaps
   - Docking and re-shipping strategies
   - Multiple strategies with same tokens

4. **Prepare for mainnet**:
   - Use real token addresses
   - Carefully review all parameters
   - Start with small liquidity amounts
   - Monitor closely after deployment

