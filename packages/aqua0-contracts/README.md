# Aqua Trading Strategies

This package contains two production-ready trading strategies implemented as Aqua Apps, with complete testnet deployment scripts for Base Sepolia.

## 🚀 Quick Start

**Want to test on Base Sepolia?** See [QUICKSTART.md](./QUICKSTART.md) for a step-by-step guide using your existing AquaRouter.

**Full deployment details?** See [DEPLOYMENT_SUMMARY.md](./DEPLOYMENT_SUMMARY.md) for architecture and integration info.

## Strategies Implemented

### 1. ConcentratedLiquiditySwap
**Formula**: Modified Constant Product with Range Multiplier  
**Use Case**: USDC <> ETH pairs with concentrated liquidity

**Key Features**:
- Price range constraints (similar to Uniswap v3)
- Capital efficiency through range concentration
- Amplified liquidity within specified price bounds
- Reverts if price moves outside range

**Formula**:
```
effectiveBalance = balance * rangeMultiplier / PRECISION
amountOut = (amountInWithFee * effectiveBalanceOut) / (effectiveBalanceIn + amountInWithFee)
```

Where `rangeMultiplier` increases for narrower ranges:
- ≤10% range: 2x multiplier
- ≤50% range: 1.5x multiplier  
- >50% range: 1x multiplier (standard AMM)

### 2. StableswapAMM
**Formula**: Hybrid Constant Sum + Constant Product (Curve-style)  
**Use Case**: USDC <> USDT stablecoin pairs

**Key Features**:
- Minimal slippage for stable pairs
- Amplification factor controls curve shape
- High A (100) = more like constant sum (better for stables)
- Low A (1) = more like constant product (better for volatiles)

**Formula**:
```
weight = A / (A + 1)
constantSumOut = amountInWithFee
constantProductOut = (amountInWithFee * balanceOut) / (balanceIn + amountInWithFee)
amountOut = (weight * constantSumOut + (1 - weight) * constantProductOut) / PRECISION
```

## Running Tests

```bash
# Run all tests
forge test

# Run specific strategy tests
forge test --match-contract ConcentratedLiquiditySwapTest
forge test --match-contract StableswapAMMTest

# Run with verbosity
forge test -vv
```

## Test Coverage

### ConcentratedLiquiditySwap Tests (11 tests)
- ✅ Basic swap functionality (USDC → ETH, ETH → USDC)
- ✅ Bidirectional swaps with fee impact
- ✅ Price range validation
- ✅ Out-of-range reversion
- ✅ Sequential swaps price impact
- ✅ Constant product invariant
- ✅ Value conservation (no leakage)
- ✅ Capital efficiency comparison

### StableswapAMM Tests (8 tests)
- ✅ Basic swap functionality (USDC → USDT)
- ✅ High vs low amplification comparison
- ✅ Slippage analysis (small, large trades)
- ✅ Sequential swap slippage increase
- ✅ Bidirectional swaps
- ✅ Quote accuracy
- ✅ Value conservation

## Key Differences

| Feature | ConcentratedLiquidity | Stableswap |
|---------|----------------------|------------|
| **Best For** | Volatile pairs (ETH/USDC) | Stable pairs (USDC/USDT) |
| **Formula** | Modified Constant Product | Hybrid Sum + Product |
| **Slippage** | Higher, range-dependent | Minimal for stables |
| **Capital Efficiency** | High within range | Consistent across range |
| **Price Constraint** | Must stay in range | No constraints |
| **Amplification** | Range-based multiplier | A parameter (1-100+) |

## Architecture

Both strategies follow the Aqua App pattern:

1. **Inherit from `AquaApp`** - provides AQUA instance and reentrancy protection
2. **Define Strategy struct** - immutable parameters (maker, tokens, fees, etc.)
3. **Implement quote functions** - view functions for price discovery
4. **Implement swap functions** - execute trades with callbacks
5. **Use pull/push pattern** - AQUA.pull() for outputs, callback pushes inputs

## Aqua Benefits Demonstrated

✅ **Shared Liquidity**: Same capital can back multiple strategies  
✅ **No Custody**: Funds stay in maker wallets  
✅ **Specialization**: Different formulas for different use cases  
✅ **Composability**: Standard callback interface  
✅ **Capital Efficiency**: Virtual balance accounting

## Gas Optimization

- Compiled with `via_ir = true` for IR-based optimization
- Optimizer runs: 200
- Minimal storage reads through Aqua's virtual accounting
- Efficient callback pattern

## License

LicenseRef-Degensoft-Aqua-Source-1.1
