# 3-Hop Flow with Accurate Quoting

## 🎯 The Problem

LP needs to know **exactly** how much USDT to lock before committing to the intent. This requires:
1. **Accurate quote** from the AMM on Base
2. **Slippage tolerance** for price movements
3. **On-chain or off-chain** quote mechanism

## 🔄 Complete Flow with Quoting

### HOP 0: Pre-Flight Quote (Before Intent)

```
Option A: Off-Chain Quote (Fast)
─────────────────────────────────
World Chain                              Base Chain
───────────                              ──────────

Trader prepares swap:
amountIn = 10 USDC
        │
        │ RPC call (view function)
        ├────────────────────────►  StableswapAMM.quoteExactIn(
        │                              strategy,
        │                              zeroForOne: true,
        │                              amountIn: 10e6
        │                           )
        │                           ↓
   ◄────────────────────────────  Quote: 9.996 USDT
        │
Trader creates intent with:
- amountIn: 10 USDC
- expectedOut: 9.996 USDT
- minOut: 9.946 USDT (0.5% slippage)
```

**Pros:** Fast, no gas cost
**Cons:** Quote can become stale

```
Option B: Cross-Chain Quote Request (Accurate)
───────────────────────────────────────────────
World Chain                              Base Chain
───────────                              ──────────

Trader requests quote:
QuoteOracle.requestQuote(
  strategyHash,
  amountIn: 10 USDC
)
        │
        │ LZ Message
        ├────────────────────────►  QuoteOracle.getQuote()
        │                              ↓
        │                           Calls AMM.quoteExactIn()
        │                           ↓
   ◄────────────────────────────  Returns: 9.996 USDT
        │
Trader creates intent with quote
```

**Pros:** Most accurate, guaranteed fresh
**Cons:** Requires LZ message (~30 sec, extra cost)

## 💡 Recommended: Hybrid Approach

**Use off-chain RPC quote + on-chain validation:**

```solidity
// IntentPool.sol

function submitIntent(
    bytes32 strategyHash,
    address tokenIn,
    address tokenOut,
    uint256 amountIn,
    uint256 expectedOut,    // From off-chain quote
    uint256 minOut,         // expectedOut - slippage
    uint256 quoteTimestamp  // When quote was fetched
) external {
    // Validate quote isn't too stale
    require(
        block.timestamp - quoteTimestamp < 60, // 1 minute max age
        "Quote too old"
    );
    
    // Lock trader's tokenIn
    IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
    
    // Create intent
    intents[intentId] = Intent({
        trader: msg.sender,
        strategyHash: strategyHash,
        tokenIn: tokenIn,
        tokenOut: tokenOut,
        amountIn: amountIn,
        expectedOut: expectedOut,
        minOut: minOut,
        status: IntentStatus.PENDING
    });
    
    emit IntentSubmitted(intentId, msg.sender, expectedOut, minOut);
}

function fulfillIntent(uint256 intentId) external {
    Intent storage intent = intents[intentId];
    require(intent.status == IntentStatus.PENDING, "Not pending");
    
    // LP sees expectedOut and can choose to fulfill or not
    // If market moved unfavorably, LP can skip
    
    // Calculate actual amount LP needs to provide
    // Option 1: Use expectedOut exactly
    uint256 lpAmount = intent.expectedOut;
    
    // Option 2: Re-quote on Base (more accurate)
    // uint256 lpAmount = _fetchQuoteFromBase(intent);
    
    // Validate against minOut
    require(lpAmount >= intent.minOut, "Below minimum");
    
    // Lock LP's tokenOut
    IERC20(intent.tokenOut).safeTransferFrom(
        msg.sender,
        address(this),
        lpAmount
    );
    
    // Update intent
    intent.LP = msg.sender;
    intent.actualOut = lpAmount;
    intent.status = IntentStatus.MATCHED;
    
    emit IntentFulfilled(intentId, msg.sender, lpAmount);
}
```

## 🎯 Detailed Flow with Quoting

### Step 1: Trader Gets Quote

```javascript
// Frontend / Script

// Get quote from Base via RPC
const quote = await stableswapAMM.quoteExactIn(
  strategy,
  true, // zeroForOne (USDC → USDT)
  ethers.utils.parseUnits("10", 6) // 10 USDC
);

console.log("Expected output:", ethers.utils.formatUnits(quote, 6), "USDT");
// Output: "9.996 USDT"

// Apply slippage (0.5%)
const slippageBps = 50; // 0.5%
const minOut = quote.mul(10000 - slippageBps).div(10000);

console.log("Min output (0.5% slippage):", ethers.utils.formatUnits(minOut, 6), "USDT");
// Output: "9.946 USDT"

// Submit intent with quote
const tx = await intentPool.submitIntent(
  strategyHash,
  USDC_ADDRESS,
  USDT_ADDRESS,
  ethers.utils.parseUnits("10", 6), // amountIn
  quote, // expectedOut
  minOut, // minOut (with slippage)
  Math.floor(Date.now() / 1000) // quoteTimestamp
);
```

### Step 2: LP Sees Intent and Decides

```javascript
// LP Monitor Script

intentPool.on("IntentSubmitted", async (intentId, trader, expectedOut, minOut) => {
  console.log("New intent:", intentId);
  console.log("Expected output:", ethers.utils.formatUnits(expectedOut, 6), "USDT");
  console.log("Min acceptable:", ethers.utils.formatUnits(minOut, 6), "USDT");
  
  // LP can re-quote to verify profitability
  const currentQuote = await stableswapAMM.quoteExactIn(...);
  
  if (currentQuote.gte(minOut)) {
    console.log("✅ Intent profitable, fulfilling...");
    
    // Approve and fulfill
    await usdt.approve(intentPool.address, expectedOut);
    await intentPool.fulfillIntent(intentId);
  } else {
    console.log("❌ Market moved, skipping intent");
  }
});
```

### Step 3: Settlement with Quote Validation

```solidity
// CrossChainSwapComposer.sol

function _executeSwapWithBothTokens(
    bytes32 intentId,
    DualTransfer memory transfer
) internal {
    // Build strategy
    IStableswapAMM.Strategy memory strategy = IStableswapAMM.Strategy({
        maker: transfer.LP,
        token0: TOKEN_IN,
        token1: TOKEN_OUT,
        feeBps: 4,
        amplificationFactor: 100,
        salt: transfer.strategyHash
    });
    
    // Execute swap with minOut protection
    uint256 amountOut = AMM.swapExactIn(
        strategy,
        true, // zeroForOne
        transfer.usdcAmount,
        transfer.minAmountOut, // ✅ Protects against slippage
        address(this),
        abi.encode(intentId, transfer)
    );
    
    // Validate we got expected amount
    require(amountOut >= transfer.minAmountOut, "Slippage exceeded");
    
    emit SwapExecuted(intentId, transfer.trader, transfer.usdcAmount, amountOut);
    
    // Bridge back
    _bridgeBackBoth(intentId, transfer, amountOut);
}
```

## 📊 Quote Sources & Accuracy

### Option 1: Direct AMM Quote (Most Accurate) ✅

```solidity
// StableswapAMM.sol already has:

function quoteExactIn(
    Strategy calldata strategy,
    bool zeroForOne,
    uint256 amountIn
) external view returns (uint256 amountOut) {
    bytes32 strategyHash = keccak256(abi.encode(strategy));
    (, , uint256 balanceIn, uint256 balanceOut) = _getInAndOut(
        strategy,
        strategyHash,
        zeroForOne
    );
    
    amountOut = _quoteExactIn(
        strategy.feeBps,
        strategy.amplificationFactor,
        balanceIn,
        balanceOut,
        amountIn
    );
}
```

**Usage:**
```javascript
// Trader fetches via RPC (no gas cost)
const quote = await stableswapAMM.quoteExactIn(
  {
    maker: LP_ADDRESS,
    token0: USDC_ADDRESS,
    token1: USDT_ADDRESS,
    feeBps: 4,
    amplificationFactor: 100,
    salt: ethers.constants.HashZero
  },
  true, // USDC → USDT
  ethers.utils.parseUnits("10", 6)
);
```

### Option 2: Quote Registry (Cached) ⚡

```solidity
// QuoteCache.sol on World Chain

contract QuoteCache {
    struct CachedQuote {
        uint256 amountOut;
        uint256 timestamp;
        uint256 blockNumber;
    }
    
    mapping(bytes32 => CachedQuote) public quotes;
    
    // Updated periodically by keeper/relayer
    function updateQuote(
        bytes32 strategyHash,
        uint256 amountIn,
        uint256 amountOut
    ) external onlyKeeper {
        bytes32 key = keccak256(abi.encodePacked(strategyHash, amountIn));
        quotes[key] = CachedQuote({
            amountOut: amountOut,
            timestamp: block.timestamp,
            blockNumber: block.number
        });
    }
    
    function getQuote(
        bytes32 strategyHash,
        uint256 amountIn,
        uint256 maxAge
    ) external view returns (uint256 amountOut) {
        bytes32 key = keccak256(abi.encodePacked(strategyHash, amountIn));
        CachedQuote memory quote = quotes[key];
        
        require(block.timestamp - quote.timestamp <= maxAge, "Quote stale");
        return quote.amountOut;
    }
}
```

**Pros:** Fast, on-chain, no cross-chain call
**Cons:** Requires keeper to update, can be stale

### Option 3: Cross-Chain Quote Oracle (Most Accurate but Slow)

```solidity
// QuoteOracle.sol - Dual deployment

// On World Chain:
contract QuoteOracleWorld is OApp {
    function requestQuote(
        bytes32 strategyHash,
        uint256 amountIn
    ) external payable returns (bytes32 requestId) {
        requestId = keccak256(abi.encodePacked(msg.sender, strategyHash, amountIn, block.timestamp));
        
        bytes memory message = abi.encode(requestId, strategyHash, amountIn);
        _lzSend(baseEid, message, options, MessagingFee(msg.value, 0), payable(msg.sender));
        
        emit QuoteRequested(requestId, msg.sender);
    }
    
    function _lzReceive(...) internal override {
        (bytes32 requestId, uint256 amountOut) = abi.decode(_message, (bytes32, uint256));
        emit QuoteReceived(requestId, amountOut);
        // Trader can now submit intent with this quote
    }
}

// On Base Chain:
contract QuoteOracleBase is OApp {
    IStableswapAMM public immutable AMM;
    
    function _lzReceive(...) internal override {
        (bytes32 requestId, bytes32 strategyHash, uint256 amountIn) = 
            abi.decode(_message, (bytes32, bytes32, uint256));
        
        // Get quote from AMM
        uint256 amountOut = AMM.quoteExactIn(strategy, true, amountIn);
        
        // Send back to World
        bytes memory response = abi.encode(requestId, amountOut);
        _lzSend(worldEid, response, options, fee, refund);
    }
}
```

**Pros:** Most accurate, guaranteed fresh
**Cons:** Slow (~30-60 seconds), costs LZ fees

## ✅ Recommended Implementation

**Use Option 1 (Direct AMM Quote via RPC) with these protections:**

1. **Trader gets quote** via RPC (instant, free)
2. **Trader adds slippage** (0.5% typical)
3. **Intent includes:**
   - `expectedOut` (from quote)
   - `minOut` (expectedOut - slippage)
   - `quoteTimestamp` (freshness check)
4. **LP validates** by re-quoting (optional)
5. **Settlement enforces** `minOut` on Base

**This provides:**
- ✅ Fast quotes (no waiting)
- ✅ No extra gas costs
- ✅ Slippage protection
- ✅ LP can verify profitability
- ✅ On-chain validation at settlement

## 📝 Complete Quote Flow

```
1. Trader (Off-chain):
   quote = AMM.quoteExactIn() via RPC
   minOut = quote * 99.5% (0.5% slippage)
   
2. Trader (On-chain):
   IntentPool.submitIntent(
     amountIn: 10 USDC,
     expectedOut: quote,
     minOut: minOut
   )
   
3. LP (Off-chain):
   Sees intent with expectedOut
   Can re-quote to verify
   
4. LP (On-chain):
   If profitable:
   IntentPool.fulfillIntent(intentId)
   Locks expectedOut amount of USDT
   
5. Settlement (Base Chain):
   Composer executes swap
   Validates: amountOut >= minOut ✅
   Bridges tokens back
```

This ensures accurate pricing while maintaining speed and efficiency! 🎯

