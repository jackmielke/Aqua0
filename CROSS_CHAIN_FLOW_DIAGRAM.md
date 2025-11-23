# 🌉 Cross-Chain Token Registration & Strategy Shipping Flow

## 📊 Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         World Chain                              │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │         AquaStrategyComposer (World)                      │  │
│  │  - Sends cross-chain messages                             │  │
│  │  - Initiates token registration                           │  │
│  │  - Ships strategies with virtual liquidity                │  │
│  └──────────────────────────────────────────────────────────┘  │
│                            │                                     │
│                            │ LayerZero Message                   │
│                            ▼                                     │
└─────────────────────────────────────────────────────────────────┘
                             │
                             │ Cross-Chain
                             │ Communication
                             │
┌─────────────────────────────────────────────────────────────────┐
│                            │                                     │
│                            ▼                                     │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │         AquaStrategyComposer (Base)                       │  │
│  │  - Receives cross-chain messages                          │  │
│  │  - Registers tokens in tokenRegistry                      │  │
│  │  - Calls Aqua.shipOnBehalfOf()                            │  │
│  └──────────────────────────────────────────────────────────┘  │
│                            │                                     │
│                            ▼                                     │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │              Aqua Router (Base)                           │  │
│  │  - Ships strategy on behalf of LP                         │  │
│  │  - Records virtual liquidity                              │  │
│  └──────────────────────────────────────────────────────────┘  │
│                            │                                     │
│                            ▼                                     │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │         StableswapAMM (Base)                              │  │
│  │  - Executes USDT/WGC swaps                                │  │
│  │  - Manages liquidity pools                                │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
│                         Base Chain                               │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🔄 Flow 1: Cross-Chain Token Registration

```
┌─────────────┐
│   LP/Owner  │
└──────┬──────┘
       │
       │ 1. Call registerTokensCrossChain()
       │    - canonicalIds: [keccak256("WGC")]
       │    - tokens: [0xWGC_on_Base]
       │    - dstEid: 30184 (Base)
       │
       ▼
┌─────────────────────────────┐
│  Composer (World Chain)     │
│  - Encode message payload   │
│  - Add MSG_TYPE = 2         │
│  - Call _lzSend()           │
└──────────┬──────────────────┘
           │
           │ 2. LayerZero Message
           │    (2-5 minutes)
           │
           ▼
┌─────────────────────────────┐
│  LayerZero Endpoint (Base)  │
│  - Validates peer           │
│  - Calls _lzReceive()       │
└──────────┬──────────────────┘
           │
           │ 3. Decode message
           │
           ▼
┌─────────────────────────────┐
│  Composer (Base Chain)      │
│  - Decode MSG_TYPE = 2      │
│  - Call _handleRegister...  │
│  - Update tokenRegistry     │
│  - Emit TokenRegistered     │
└─────────────────────────────┘
           │
           │ ✅ WGC now registered!
           ▼
     [Token Mapping]
     keccak256("WGC") => 0xWGC_on_Base
```

---

## 🚀 Flow 2: Cross-Chain Strategy Shipping

```
┌─────────────┐
│     LP      │
└──────┬──────┘
       │
       │ 1. Call shipStrategyToChain()
       │    - strategy: StableswapStrategy{
       │        maker: LP_address,
       │        token0Id: keccak256("USDT"),
       │        token1Id: keccak256("WGC"),
       │        feeBps: 4,
       │        amplificationFactor: 100
       │      }
       │    - amounts: [2e6, 2e18]
       │    - dstEid: 30184 (Base)
       │
       ▼
┌─────────────────────────────┐
│  Composer (World Chain)     │
│  - Encode strategy          │
│  - Add MSG_TYPE = 1         │
│  - Calculate strategyHash   │
│  - Call _lzSend()           │
│  - Emit CrossChainShip...   │
└──────────┬──────────────────┘
           │
           │ 2. LayerZero Message
           │    (2-5 minutes)
           │
           ▼
┌─────────────────────────────┐
│  LayerZero Endpoint (Base)  │
│  - Validates peer           │
│  - Calls _lzReceive()       │
└──────────┬──────────────────┘
           │
           │ 3. Decode message
           │
           ▼
┌─────────────────────────────┐
│  Composer (Base Chain)      │
│  - Decode MSG_TYPE = 1      │
│  - Call handleShip()        │
│  - Resolve token IDs:       │
│    * USDT => 0x102d7...     │
│    * WGC => 0xWGC_on_Base   │
└──────────┬──────────────────┘
           │
           │ 4. Call Aqua.shipOnBehalfOf()
           │
           ▼
┌─────────────────────────────┐
│     Aqua Router (Base)      │
│  - Ship strategy for LP     │
│  - Record virtual balances: │
│    * USDT: 2e6              │
│    * WGC: 2e18              │
│  - Return strategyHash      │
└──────────┬──────────────────┘
           │
           │ ✅ Strategy shipped!
           ▼
     [LP can now fulfill swaps]
```

---

## 🔑 Message Types

| Type | Value | Purpose | Payload |
|------|-------|---------|---------|
| `MSG_TYPE_SHIP_STRATEGY` | 1 | Ship a strategy cross-chain | `(msgType, maker, app, strategy, tokenIds, amounts, nonce)` |
| `MSG_TYPE_REGISTER_TOKENS` | 2 | Register token mappings | `(msgType, canonicalIds[], tokens[])` |

---

## 📝 Token ID Resolution

```
┌─────────────────────────────────────────────────────────────┐
│                   Canonical Token IDs                        │
│                   (Chain-Agnostic)                           │
│                                                              │
│  keccak256("USDT") = 0x4b5f...                              │
│  keccak256("WGC")  = 0x7a2c...                              │
│  keccak256("USDC") = 0x9f1e...                              │
└─────────────────────────────────────────────────────────────┘
                           │
                           │ Resolved per chain
                           │
        ┌──────────────────┴──────────────────┐
        │                                     │
        ▼                                     ▼
┌──────────────────┐              ┌──────────────────┐
│   World Chain    │              │   Base Chain     │
│                  │              │                  │
│ USDT => 0x79A0..│              │ USDT => 0x102d.. │
│ WGC  => 0xWGC_W │              │ WGC  => 0xWGC_B  │
│ USDC => 0xUSDC_W│              │ USDC => 0xUSDC_B │
└──────────────────┘              └──────────────────┘
```

**Why this matters:**
- ✅ Same `strategyHash` across all chains
- ✅ LP can ship once, fulfill on any chain
- ✅ Consistent strategy identification

---

## ⚡ Gas & Fee Breakdown

### Token Registration (1 token)

```
World Chain:
  - registerTokensCrossChain(): ~50,000 gas
  - LayerZero fee: ~0.0001 ETH
  
Base Chain (automatic):
  - _lzReceive(): ~40,000 gas (paid by relayer)
  - Token registry update: included
  
Total cost to LP: ~$0.30
```

### Strategy Shipping

```
World Chain:
  - shipStrategyToChain(): ~80,000 gas
  - LayerZero fee: ~0.00015 ETH
  
Base Chain (automatic):
  - _lzReceive(): ~60,000 gas (paid by relayer)
  - Aqua.shipOnBehalfOf(): ~100,000 gas (paid by relayer)
  
Total cost to LP: ~$0.50
```

---

## 🔒 Security Features

### 1. Peer Validation
```
Only messages from trusted peers are accepted:
- World Composer can only receive from Base Composer
- Base Composer can only receive from World Composer
```

### 2. Owner-Only Token Registration
```
Only the contract owner can register tokens cross-chain
- Prevents malicious token mappings
- Centralized control for security
```

### 3. Supported Chain Validation
```
Destination chain must be explicitly whitelisted:
- supportedChains[dstEid] must be true
- Prevents sending to unsupported chains
```

### 4. No Token Transfers
```
Token registration is message-only:
- No ERC20 transfers involved
- No approval needed
- No risk of token loss
```

---

## 🎯 Comparison: Before vs After

### Before (Manual)

```bash
# Step 1: On Base
cast send $COMPOSER_BASE "registerToken(...)" --rpc-url $BASE_RPC

# Step 2: On World  
cast send $COMPOSER_WORLD "registerToken(...)" --rpc-url $WORLD_RPC

# Step 3: On Arbitrum
cast send $COMPOSER_ARB "registerToken(...)" --rpc-url $ARB_RPC

# Issues:
# ❌ Need to manage keys on all chains
# ❌ 3 separate transactions
# ❌ Easy to make mistakes
# ❌ Inconsistent mappings
```

### After (Cross-Chain)

```bash
# Step 1: From World (registers on Base automatically)
forge script scripts/RegisterTokenCrossChain.s.sol --rpc-url $WORLD_RPC --broadcast

# Benefits:
# ✅ Single transaction
# ✅ Automatic propagation
# ✅ Consistent mappings
# ✅ Less error-prone
```

---

## 📚 Related Documentation

- **[CROSS_CHAIN_TOKEN_REGISTRATION.md](./packages/layerzero-contracts/CROSS_CHAIN_TOKEN_REGISTRATION.md)** - Detailed guide
- **[USDT_WGC_STRATEGY_COMMANDS.md](./USDT_WGC_STRATEGY_COMMANDS.md)** - Quick command reference
- **[AquaStrategyComposer.sol](./packages/layerzero-contracts/contracts/AquaStrategyComposer.sol)** - Contract implementation

---

## 🆘 Common Issues

### Issue: "InvalidDestinationChain"
**Cause:** Destination chain not added to `supportedChains`  
**Fix:** `cast send $COMPOSER "addSupportedChain(uint32)" $DST_EID`

### Issue: "Peer not set"
**Cause:** LayerZero peers not configured  
**Fix:** Set peers on both chains using `setPeer()`

### Issue: "TokenNotMapped"
**Cause:** Token not registered on destination chain  
**Fix:** Run `RegisterTokenCrossChain.s.sol` first

### Issue: Message not delivered after 10 minutes
**Cause:** Insufficient gas or fee  
**Fix:** Increase `GAS_LIMIT` env var or add more fee buffer

---

## ✅ Checklist for New Token Pair

- [ ] Deploy Composers on both chains
- [ ] Set LayerZero peers between chains
- [ ] Add destination chain to `supportedChains`
- [ ] Register both tokens cross-chain
- [ ] Verify token registrations
- [ ] Ship strategy cross-chain
- [ ] Verify strategy on destination
- [ ] Test swap execution

---

**Total Setup Time:** ~15 minutes  
**Transactions Required:** 5-6 (setup) + 2 per new token pair  
**Ongoing Cost:** ~$0.30-0.50 per cross-chain operation


