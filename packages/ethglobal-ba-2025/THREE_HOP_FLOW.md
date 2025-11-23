# The 3-Hop Cross-Chain Swap Flow

## 🎯 The Complete Flow

```
         World Chain                                Base Chain
         (LP & Trader)                              (Aqua & AMM)
         ═══════════                                ══════════

HOP 1: Intent Matching on World
─────────────────────────────────
Trader submits intent
LP fulfills intent
Both lock tokens in IntentPool
        │
        │
HOP 2: Dual Token Bridge (The Key!)
────────────────────────────────────
        │
        │ Stargate sends TWO token transfers:
        │ 1. LP's USDT (9.996e6)
        │ 2. Trader's USDC (10e6)
        │
        ├─────────────────────────►  Both arrive in Composer
        │                            - 9.996 USDT ✅
        │                            - 10 USDC ✅
        │
HOP 3: Settlement & Return
───────────────────────────
                                     Composer executes swap
                                     Updates Aqua's books
                                          ↓
        ◄─────────────────────────  Sends back:
        │                            - 9.996 USDT → Trader
        │                            - 10 USDC → LP
        │
   Everyone gets their tokens! 🎉
```

## 🔄 Detailed 3-Hop Implementation

### HOP 1: Intent Matching (World Chain)

```solidity
// IntentPool.sol on World Chain

1. Trader submits intent:
   trader.approve(intentPool, 10 USDC)
   intentPool.submitIntent(
     strategyHash: 0x123...,
     tokenIn: USDC,
     tokenOut: USDT,
     amountIn: 10e6,
     minAmountOut: 9.96e6
   )
   
   State:
   ├─ Trader's 10 USDC locked ✅
   └─ Intent status: PENDING

2. LP fulfills intent:
   LP.approve(intentPool, 9.996 USDT)
   intentPool.fulfillIntent(intentId)
   
   State:
   ├─ Trader's 10 USDC locked ✅
   ├─ LP's 9.996 USDT locked ✅
   └─ Intent status: MATCHED → Ready for settlement!
```

### HOP 2: Dual Token Bridge (World → Base)

```solidity
// IntentPool triggers dual send

function settleIntent(uint256 intentId) external payable {
    Intent memory intent = intents[intentId];
    
    // CRITICAL: Send BOTH tokens together with ONE composeMsg
    
    // Step 1: Send LP's USDT (tokenOut)
    bytes memory composeMsgPart1 = abi.encode(
        uint8(1), // Part 1: LP's USDT
        intentId,
        intent.LP,
        intent.amountOut // 9.996 USDT
    );
    
    StargateUSDT.send{value: msg.value / 2}(
        SendParam({
            dstEid: BASE_EID,
            to: bytes32(uint256(uint160(composer))),
            amountLD: intent.amountOut,
            minAmountLD: intent.amountOut,
            extraOptions: OptionsBuilder.newOptions()
                .addExecutorLzComposeOption(0, 500000, 0),
            composeMsg: composeMsgPart1,
            oftCmd: ""
        }),
        MessagingFee(msg.value / 2, 0),
        msg.sender
    );
    
    // Step 2: Send Trader's USDC (tokenIn)
    bytes memory composeMsgPart2 = abi.encode(
        uint8(2), // Part 2: Trader's USDC
        intentId,
        intent.trader,
        intent.amountIn, // 10 USDC
        intent.strategyHash,
        intent.minAmountOut
    );
    
    StargateUSDC.send{value: msg.value / 2}(
        SendParam({
            dstEid: BASE_EID,
            to: bytes32(uint256(uint160(composer))),
            amountLD: intent.amountIn,
            minAmountLD: intent.amountIn,
            extraOptions: OptionsBuilder.newOptions()
                .addExecutorLzComposeOption(1, 500000, 0),
            composeMsg: composeMsgPart2,
            oftCmd: ""
        }),
        MessagingFee(msg.value / 2, 0),
        msg.sender
    );
}
```

### HOP 3: Execute & Return (Base Chain)

```solidity
// CrossChainSwapComposer.sol on Base Chain

// State to track dual arrival
struct DualTransfer {
    uint256 usdtAmount;    // LP's USDT
    uint256 usdcAmount;    // Trader's USDC
    address trader;
    address LP;
    bytes32 strategyHash;
    uint256 minAmountOut;
    uint8 partsReceived;   // 0, 1, or 2
}

mapping(bytes32 intentId => DualTransfer) public pendingTransfers;

// Receive FIRST token (LP's USDT)
function lzCompose(
    address _sender,
    bytes32 _guid,
    bytes calldata _message,
    address,
    bytes calldata
) external payable {
    uint8 part;
    bytes32 intentId;
    
    (part, intentId, ...) = abi.decode(
        OFTComposeMsgCodec.composeMsg(_message),
        (uint8, bytes32, ...)
    );
    
    if (part == 1) {
        // Part 1: LP's USDT arrived
        uint256 amountLD = OFTComposeMsgCodec.amountLD(_message);
        
        DualTransfer storage transfer = pendingTransfers[intentId];
        transfer.usdtAmount = amountLD;
        transfer.partsReceived++;
        
        // Wait for part 2...
    }
    else if (part == 2) {
        // Part 2: Trader's USDC arrived
        uint256 amountLD = OFTComposeMsgCodec.amountLD(_message);
        
        (
            ,
            ,
            address trader,
            uint256 amountIn,
            bytes32 strategyHash,
            uint256 minAmountOut
        ) = abi.decode(
            OFTComposeMsgCodec.composeMsg(_message),
            (uint8, bytes32, address, uint256, bytes32, uint256)
        );
        
        DualTransfer storage transfer = pendingTransfers[intentId];
        transfer.usdcAmount = amountLD;
        transfer.trader = trader;
        transfer.strategyHash = strategyHash;
        transfer.minAmountOut = minAmountOut;
        transfer.partsReceived++;
    }
    
    // Execute when BOTH parts arrived
    DualTransfer memory transfer = pendingTransfers[intentId];
    if (transfer.partsReceived == 2) {
        _executeSwapWithBothTokens(intentId, transfer);
    }
}

function _executeSwapWithBothTokens(
    bytes32 intentId,
    DualTransfer memory transfer
) internal {
    // Now we have BOTH tokens! ✅
    // - transfer.usdtAmount (LP's USDT)
    // - transfer.usdcAmount (Trader's USDC)
    
    // Build strategy
    IStableswapAMM.Strategy memory strategy = ...;
    
    // Execute swap
    uint256 amountOut = AMM.swapExactIn(
        strategy,
        true, // zeroForOne (USDC → USDT)
        transfer.usdcAmount,
        transfer.minAmountOut,
        address(this),
        abi.encode(intentId, transfer)
    );
    
    // In the callback:
    // aqua.pullOnBehalfOf() uses the bridged USDT ✅
    // aqua.pushOnBehalfOf() uses the bridged USDC ✅
    
    // Bridge back:
    // - USDT → Trader on World
    // - USDC → LP on World
    _bridgeBackBoth(intentId, transfer, amountOut);
}

// AMM Callback
function stableswapCallback(
    address tokenIn,
    address tokenOut,
    uint256 amountIn,
    uint256 amountOut,
    address maker,
    address app,
    bytes32 strategyHash,
    bytes calldata takerData
) external override {
    (bytes32 intentId, DualTransfer memory transfer) = 
        abi.decode(takerData, (bytes32, DualTransfer));
    
    // Pull: Use LP's bridged USDT
    // This transfers the USDT that arrived from World
    AQUA.pullOnBehalfOf(
        transfer.LP,
        address(this), // delegate
        strategyHash,
        tokenOut, // USDT
        amountOut,
        address(this) // Keep here for bridging back
    );
    
    // Push: Use Trader's bridged USDC
    // This transfers the USDC that arrived from World
    IERC20(tokenIn).approve(address(AQUA), amountIn);
    AQUA.pushOnBehalfOf(
        transfer.LP,
        address(this), // delegate
        app,
        strategyHash,
        tokenIn, // USDC
        amountIn
    );
    
    // Aqua state updated! ✅
    // LP's virtual USDC: 100 → 110 ✅
    // LP's virtual USDT: 100 → 90.004 ✅
}

function _bridgeBackBoth(
    bytes32 intentId,
    DualTransfer memory transfer,
    uint256 usdtAmount
) internal {
    uint32 srcEid = ...; // World chain
    
    // Send USDT to trader
    StargateUSDT.send{value: msg.value / 2}(
        SendParam({
            dstEid: srcEid,
            to: bytes32(uint256(uint160(transfer.trader))),
            amountLD: usdtAmount,
            ...
        }),
        ...
    );
    
    // Send USDC to LP
    StargateUSDC.send{value: msg.value / 2}(
        SendParam({
            dstEid: srcEid,
            to: bytes32(uint256(uint160(transfer.LP))),
            amountLD: transfer.usdcAmount,
            ...
        }),
        ...
    );
}
```

## 🎯 The Key Innovation: Dual Token Transfer

**The Critical Insight:**

Instead of trying to pull LP's tokens from their wallet on World, we:
1. **Lock both parties' tokens** on World (in IntentPool)
2. **Bridge BOTH tokens together** to Base (via Stargate)
3. **Composer has BOTH tokens** when swap executes
4. **Aqua operations use the bridged tokens** ✅

**Why This Works:**

```
Before (Broken):
AMM calls: aqua.pull(LP, USDT, amt)
           ↓
    safeTransferFrom(LP, composer, amt)
           ↓
    ❌ LP has no USDT on Base!

After (Fixed):
1. LP's USDT bridged to Composer
2. AMM calls: aqua.pullOnBehalfOf(LP, composer, USDT, amt)
           ↓
    Composer as delegate transfers the bridged USDT
           ↓
    ✅ USDT is already on Base in Composer!
```

## 📦 Complete Implementation Needed

### 1. IntentPool (World Chain)
```solidity
contract IntentPool {
    function submitIntent(...) // Trader locks USDC
    function fulfillIntent(...) // LP locks USDT
    function settleIntent(...) // Dual Stargate.send()
}
```

### 2. Update CrossChainSwapComposer (Base Chain)
```solidity
contract CrossChainSwapComposer {
    // Track dual arrivals
    mapping(bytes32 => DualTransfer) pendingTransfers;
    
    // Handle part 1 (LP's USDT)
    // Handle part 2 (Trader's USDC)
    // Execute when both arrived
    // Bridge both back
}
```

## ✅ This Is The Right Architecture!

**3 Hops:**
1. **Intent matching** (World)
2. **Dual bridge** (World → Base)
3. **Settlement & return** (Base → World)

**Key Benefits:**
- ✅ LP doesn't pre-lock for long
- ✅ Tokens only bridge when matched
- ✅ Composer has BOTH tokens for swap
- ✅ Aqua operations work correctly
- ✅ Everyone gets tokens back

**Want me to implement the complete IntentPool and updated Composer?** 🚀

