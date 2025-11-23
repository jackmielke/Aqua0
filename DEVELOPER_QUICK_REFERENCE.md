# Aqua0 Developer Quick Reference

## TL;DR - How It Works

**Aqua0 = Cross-Chain AMM Marketplace**

- **LPs**: Deploy AMM strategies on Base with virtual liquidity (no tokens locked)
- **Traders**: Submit swap intents on World Chain
- **Settlement**: Dual token bridge to Base → Execute swap → Bridge back

---

## 5-Minute Understanding

### The Problem
- Traditional AMMs lock liquidity in pools (90% unused)
- Liquidity fragmented across chains
- LPs can't easily provide liquidity cross-chain

### The Solution
1. **Aqua's Virtual Liquidity**: Tokens stay in LP wallets, Aqua tracks virtual balances
2. **Cross-Chain Strategy Shipping**: LPs ship strategies via LayerZero (message-only, no tokens)
3. **Intent-Based Swaps**: Traders submit intents, LPs fulfill, execution happens on Base

### The Flow
```
LP (Ethereum) → Ship Strategy → Base (Aqua records virtual balances)
                                   ↓
Trader (World) → Submit Intent → LP Fulfills → Settle
                                                  ↓
World → Bridge Tokens → Base → Execute Swap → Bridge Back → World
```

---

## Key Concepts

### 1. Virtual Liquidity

**Traditional AMM:**
```
LP deposits 100 USDT + 100 USDC into pool contract
Pool holds tokens, LP gets LP tokens
```

**Aqua:**
```
LP ships strategy with virtual amounts: 100 USDT + 100 USDC
Aqua records: _balances[LP][AMM][hash][USDT] = 100
              _balances[LP][AMM][hash][USDC] = 100
Tokens stay in LP's wallet!
```

**When swap happens:**
```
pull(): Decrease virtual balance, transfer from LP wallet
push(): Increase virtual balance, transfer to LP wallet
```

---

### 2. Strategy Shipping (Message-Only)

**What gets sent:**
```solidity
{
  maker: 0xLP_address,
  app: 0xStableswapAMM_address,
  strategy: abi.encode({maker, token0Id, token1Id, feeBps, A, salt}),
  tokenIds: [keccak256("USDT"), keccak256("WGC")],
  amounts: [2e6, 2e6]  // Virtual amounts
}
```

**What happens on destination:**
```
1. Resolve tokenIds to local addresses
2. Call aqua.shipOnBehalfOf()
3. Record virtual balances
4. Strategy is live!
```

**No tokens transferred!** Only a LayerZero message.

---

### 3. Intent-Based Swaps

**Traditional swap:**
```
Trader → AMM.swap() → Immediate execution
```

**Intent-based swap:**
```
Trader → Submit intent → LP fulfills → Settle → Execute on Base
```

**Why intents?**
- Allows cross-chain execution
- LP can choose which intents to fulfill
- Better capital efficiency (LP doesn't need to be online 24/7)

---

### 4. Dual Token Bridge

**Why dual?**
- Need LP's tokenOut (for trader)
- Need Trader's tokenIn (for swap execution)

**How it works:**
```
IntentPool sends TWO Stargate transfers:
1. Part 1: LP's tokenOut (e.g., 999600 WGC)
2. Part 2: Trader's tokenIn (e.g., 1e6 USDT)

Both arrive at CrossChainSwapComposer
Composer waits for both (partsReceived == 2)
Then executes swap
```

---

## Code Examples

### LP: Ship Strategy

```solidity
// On Ethereum
AquaStrategyComposer composer = AquaStrategyComposer(COMPOSER_ADDRESS);

bytes32[] memory tokenIds = new bytes32[](2);
tokenIds[0] = keccak256("USDT");
tokenIds[1] = keccak256("WGC");

uint256[] memory amounts = new uint256[](2);
amounts[0] = 2e6;  // 2 USDT (virtual)
amounts[1] = 2e6;  // 2 WGC (virtual)

bytes memory strategy = abi.encode(StableswapStrategy({
    maker: msg.sender,
    token0Id: tokenIds[0],
    token1Id: tokenIds[1],
    feeBps: 4,  // 0.04%
    amplificationFactor: 100,
    salt: bytes32(0)
}));

composer.shipStrategyToChain{value: fee}(
    BASE_EID,           // Destination: Base
    STABLESWAP_AMM,     // App address on Base
    strategy,
    tokenIds,
    amounts,
    options
);
```

### LP: Register Strategy on World Chain

```solidity
// On World Chain
IntentPool pool = IntentPool(INTENT_POOL_ADDRESS);

bytes32 strategyHash = keccak256(strategy);  // Same hash as on Base

pool.registerStrategy(strategyHash, msg.sender);
```

### Trader: Submit Intent

```solidity
// On World Chain
IntentPool pool = IntentPool(INTENT_POOL_ADDRESS);

IERC20(USDT).approve(address(pool), 1e6);

bytes32 intentId = pool.submitIntent(
    strategyHash,
    USDT,           // tokenIn
    WGC,            // tokenOut
    1e6,            // amountIn (1 USDT)
    999600,         // expectedOut (0.04% fee)
    994602,         // minOut (0.5% slippage)
    block.timestamp + 1 hours  // deadline
);
```

### LP: Fulfill Intent

```solidity
// On World Chain
IntentPool pool = IntentPool(INTENT_POOL_ADDRESS);

IERC20(WGC).approve(address(pool), 999600);

pool.fulfillIntent(intentId);
```

### Anyone: Settle Intent

```solidity
// On World Chain
IntentPool pool = IntentPool(INTENT_POOL_ADDRESS);

uint256 fee = pool.quoteSettlementFee(intentId, 500000);

pool.settleIntent{value: fee * 120 / 100}(intentId, 500000);
```

---

## Smart Contract Interfaces

### Aqua

```solidity
interface IAqua {
    // Ship strategy (initialize virtual balances)
    function ship(
        address app,
        bytes calldata strategy,
        address[] calldata tokens,
        uint256[] calldata amounts
    ) external returns (bytes32 strategyHash);

    // Ship on behalf of (for cross-chain)
    function shipOnBehalfOf(
        address maker,
        address app,
        bytes calldata strategy,
        address[] calldata tokens,
        uint256[] calldata amounts
    ) external returns (bytes32 strategyHash);

    // Pull tokens (decrease virtual balance)
    function pull(
        address maker,
        bytes32 strategyHash,
        address token,
        uint256 amount,
        address to
    ) external;

    // Push tokens (increase virtual balance)
    function push(
        address maker,
        address app,
        bytes32 strategyHash,
        address token,
        uint256 amount
    ) external;

    // Get virtual balances
    function safeBalances(
        address maker,
        address app,
        bytes32 strategyHash,
        address token0,
        address token1
    ) external view returns (uint256 balance0, uint256 balance1);
}
```

### StableswapAMM

```solidity
interface IStableswapAMM {
    struct Strategy {
        address maker;
        address token0;
        address token1;
        uint256 feeBps;
        uint256 amplificationFactor;
        bytes32 salt;
    }

    function swapExactIn(
        Strategy calldata strategy,
        bool zeroForOne,
        uint256 amountIn,
        uint256 amountOutMin,
        address to,
        bytes calldata takerData
    ) external returns (uint256 amountOut);

    function quoteExactIn(
        Strategy calldata strategy,
        bool zeroForOne,
        uint256 amountIn
    ) external view returns (uint256 amountOut);
}
```

### IntentPool

```solidity
interface IIntentPool {
    function submitIntent(
        bytes32 strategyHash,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 expectedOut,
        uint256 minOut,
        uint256 deadline
    ) external returns (bytes32 intentId);

    function fulfillIntent(bytes32 intentId) external;

    function settleIntent(bytes32 intentId, uint128 composeGasLimit) external payable;

    function quoteSettlementFee(bytes32 intentId, uint128 composeGasLimit) external view returns (uint256 totalFee);

    function getIntent(bytes32 intentId) external view returns (Intent memory);
}
```

---

## Testing Workflow

### 1. Setup (One-time)

```bash
# Deploy Aqua + AMMs on Base
cd packages/aqua-contracts
forge script script/DeployAquaRouter.s.sol --rpc-url $BASE_RPC --broadcast

# Deploy strategies on Base
cd ../aqua0-contracts
forge script script/DeployStrategies.s.sol --rpc-url $BASE_RPC --broadcast

# Deploy LayerZero contracts
cd ../layerzero-contracts
forge script scripts/deploy/DeployIntentPool.s.sol --rpc-url $WORLD_RPC --broadcast
forge script scripts/deploy/DeployComposer.s.sol --rpc-url $BASE_RPC --broadcast
```

### 2. LP Workflow

```bash
# Ship strategy from Ethereum to Base
export LP_PRIVATE_KEY=0x...
export COMPOSER_ADDRESS=0x...
export DST_EID=40245  # Base Sepolia
export DST_APP=0x...  # StableswapAMM on Base

forge script scripts/shipStrategyToChain.s.sol \
  --rpc-url $ETH_SEPOLIA_RPC \
  --broadcast

# Register strategy on World Chain
export STRATEGY_HASH=0x...  # From previous step

forge script scripts/intent/RegisterStrategy.s.sol \
  --rpc-url $WORLD_RPC \
  --broadcast
```

### 3. Trader Workflow

```bash
# Submit intent
export TRADER_PRIVATE_KEY=0x...
export INTENT_POOL_ADDRESS=0x...
export STRATEGY_HASH=0x...
export SWAP_AMOUNT_IN=1000000  # 1 USDT

forge script scripts/intent/Step1_SubmitIntent.s.sol \
  --rpc-url $WORLD_RPC \
  --broadcast

# Note the intentId from output
```

### 4. LP Fulfills

```bash
# Fulfill intent
export LP_PRIVATE_KEY=0x...
export INTENT_ID=0x...  # From previous step

forge script scripts/intent/Step2_FulfillIntent.s.sol \
  --rpc-url $WORLD_RPC \
  --broadcast
```

### 5. Settlement

```bash
# Settle intent (can be anyone)
export SETTLER_PRIVATE_KEY=0x...
export INTENT_ID=0x...

forge script scripts/intent/Step3_SettleIntent.s.sol \
  --rpc-url $WORLD_RPC \
  --broadcast

# Wait 5-10 minutes for LayerZero
# Monitor on https://layerzeroscan.com
```

---

## Debugging Tips

### Check Virtual Balances

```bash
# On Base
cast call $AQUA_ADDRESS "safeBalances(address,address,bytes32,address,address)" \
  $LP_ADDRESS \
  $AMM_ADDRESS \
  $STRATEGY_HASH \
  $USDT_ADDRESS \
  $WGC_ADDRESS \
  --rpc-url $BASE_RPC
```

### Check Intent Status

```bash
# On World Chain
cast call $INTENT_POOL_ADDRESS "getIntent(bytes32)" $INTENT_ID --rpc-url $WORLD_RPC
```

### Monitor Events

```bash
# On Base - CrossChainSwapComposer
cast logs --address $COMPOSER_ADDRESS --rpc-url $BASE_RPC

# On World Chain - IntentPool
cast logs --address $INTENT_POOL_ADDRESS --rpc-url $WORLD_RPC
```

### Track LayerZero Messages

```bash
# Get message GUID from transaction logs
cast logs --from-block $BLOCK_NUMBER --to-block latest --rpc-url $WORLD_RPC

# Track on LayerZero Scan
open "https://layerzeroscan.com/tx/$GUID"
```

---

## Common Issues

### 1. Strategy Hash Mismatch

**Problem**: Strategy hash on World Chain doesn't match Base

**Solution**: Ensure you're using the same strategy encoding:
```solidity
// Use canonical token IDs, not addresses
bytes32 token0Id = keccak256("USDT");
bytes32 token1Id = keccak256("WGC");

// Use deterministic salt
bytes32 salt = bytes32(0);
```

### 2. Intent Expired

**Problem**: Intent deadline passed before settlement

**Solution**: Increase deadline or settle faster:
```solidity
uint256 deadline = block.timestamp + 1 hours;  // Increase if needed
```

### 3. Insufficient Virtual Balance

**Problem**: LP's virtual balance too low for swap

**Solution**: Ship strategy with higher amounts:
```solidity
amounts[0] = 10e6;  // 10 USDT instead of 2
amounts[1] = 10e6;  // 10 WGC instead of 2
```

### 4. Composer Not Trusted Delegate

**Problem**: Composer can't call `pullOnBehalfOf()` / `pushOnBehalfOf()`

**Solution**: Register composer as trusted delegate:
```bash
cast send $AQUA_ADDRESS "setTrustedDelegate(address,bool)" \
  $COMPOSER_ADDRESS \
  true \
  --private-key $OWNER_PRIVATE_KEY \
  --rpc-url $BASE_RPC
```

### 5. LayerZero Message Failed

**Problem**: Message didn't arrive on destination chain

**Solution**: Check LayerZero Scan for error details:
```
https://layerzeroscan.com/tx/$GUID
```

Common causes:
- Insufficient gas limit
- Insufficient native fee
- Destination chain congestion

---

## Gas Optimization Tips

### 1. Use Virtual Liquidity

Instead of:
```solidity
// Traditional: Lock 1000 USDT in pool
pool.addLiquidity(1000e6);
```

Use:
```solidity
// Aqua: Ship with virtual 1000 USDT
aqua.ship(app, strategy, [USDT], [1000e6]);
```

**Savings**: ~70% gas reduction

### 2. Batch Strategy Shipping

Instead of shipping strategies one by one, batch them:
```solidity
// Ship multiple strategies in one transaction
for (uint i = 0; i < strategies.length; i++) {
    composer.shipStrategyToChain(...);
}
```

### 3. Optimize LayerZero Options

Use minimal gas limit that works:
```solidity
// Start with 200k, increase if needed
uint128 gasLimit = 200000;

bytes memory options = OptionsBuilder.newOptions()
    .addExecutorLzComposeOption(0, gasLimit, 0);
```

---

## Security Checklist

### For LPs

- [ ] Verify strategy hash matches across chains
- [ ] Ensure sufficient virtual balance for expected swaps
- [ ] Monitor virtual balances regularly
- [ ] Set appropriate fee (feeBps) for profitability
- [ ] Test with small amounts first

### For Traders

- [ ] Set reasonable slippage tolerance (minOut)
- [ ] Check intent deadline is sufficient
- [ ] Verify strategy is registered and active
- [ ] Monitor intent status after submission
- [ ] Ensure sufficient token balance + approval

### For Developers

- [ ] Composer is registered as trusted delegate in Aqua
- [ ] Token mappings are correct (canonical IDs → addresses)
- [ ] Supported chains are whitelisted
- [ ] Reentrancy protection on all swap functions
- [ ] Proper error handling in try-catch blocks
- [ ] Event emissions for monitoring

---

## Performance Metrics

### Expected Timings

| Operation | Time |
|-----------|------|
| Strategy shipping (Ethereum → Base) | 5-10 minutes |
| Intent submission | Instant |
| Intent fulfillment | Instant |
| Settlement (World → Base) | 5-10 minutes |
| Swap execution | Instant (once tokens arrive) |
| Return bridge (Base → World) | 5-10 minutes |
| **Total end-to-end** | **10-20 minutes** |

### Gas Costs (Estimates)

| Operation | Gas (Base) | Gas (World) |
|-----------|-----------|-------------|
| Ship strategy | ~200k | - |
| Submit intent | - | ~100k |
| Fulfill intent | - | ~80k |
| Settle intent | - | ~150k + bridge fees |
| Swap execution | ~150k | - |
| Return bridge | ~100k | - |

**Note**: Bridge fees vary based on LayerZero/Stargate pricing.

---

## Resources

### Documentation
- [Aqua Whitepaper](../packages/aqua-contracts/whitepaper/aqua-dev-preview.md)
- [Accurate Sequence Diagram](./ACCURATE_SEQUENCE_DIAGRAM.md)
- [Mermaid Diagrams](./ACCURATE_SEQUENCE_DIAGRAM_MERMAID.md)
- [Corrections Summary](./CORRECTIONS_SUMMARY.md)

### External Resources
- [LayerZero Docs](https://docs.layerzero.network/)
- [Stargate Docs](https://stargateprotocol.gitbook.io/)
- [Curve Stableswap Paper](https://curve.fi/files/stableswap-paper.pdf)
- [Uniswap V3 Whitepaper](https://uniswap.org/whitepaper-v3.pdf)

### Tools
- [LayerZero Scan](https://layerzeroscan.com/)
- [Foundry](https://book.getfoundry.sh/)
- [Cast CLI](https://book.getfoundry.sh/cast/)

---

## Quick Commands Cheat Sheet

```bash
# Deploy everything
./scripts/deploy-all.sh

# Ship strategy
forge script scripts/shipStrategyToChain.s.sol --broadcast --rpc-url $ETH_RPC

# Submit intent
forge script scripts/intent/Step1_SubmitIntent.s.sol --broadcast --rpc-url $WORLD_RPC

# Fulfill intent
forge script scripts/intent/Step2_FulfillIntent.s.sol --broadcast --rpc-url $WORLD_RPC

# Settle intent
forge script scripts/intent/Step3_SettleIntent.s.sol --broadcast --rpc-url $WORLD_RPC

# Check virtual balance
cast call $AQUA "safeBalances(address,address,bytes32,address,address)" $LP $AMM $HASH $T0 $T1 --rpc-url $BASE_RPC

# Check intent
cast call $POOL "getIntent(bytes32)" $INTENT_ID --rpc-url $WORLD_RPC

# Monitor events
cast logs --address $COMPOSER --rpc-url $BASE_RPC

# Track LayerZero
open "https://layerzeroscan.com/tx/$GUID"
```

---

## Support

For issues or questions:
1. Check the [Corrections Summary](./CORRECTIONS_SUMMARY.md) for common misunderstandings
2. Review the [Accurate Sequence Diagram](./ACCURATE_SEQUENCE_DIAGRAM.md) for flow details
3. Search existing issues in the repo
4. Create a new issue with:
   - What you're trying to do
   - What you expected
   - What actually happened
   - Relevant transaction hashes / logs

---

**Happy Building! 🚀**


