# Aqua0 Documentation Index

## 📚 Overview

This directory contains comprehensive documentation for **Aqua0**, a cross-chain shared liquidity layer that extends 1inch's Aqua protocol. The documentation has been completely rewritten to accurately reflect the actual implementation.

---

## 🎯 Start Here

### New to Aqua0?
1. Read [DEVELOPER_QUICK_REFERENCE.md](./DEVELOPER_QUICK_REFERENCE.md) - 5-minute overview
2. Review [ACCURATE_SEQUENCE_DIAGRAM_MERMAID.md](./ACCURATE_SEQUENCE_DIAGRAM_MERMAID.md) - Visual flow diagrams
3. Check [CORRECTIONS_SUMMARY.md](./CORRECTIONS_SUMMARY.md) - Common misunderstandings

### Building with Aqua0?
1. Start with [DEVELOPER_QUICK_REFERENCE.md](./DEVELOPER_QUICK_REFERENCE.md) - Code examples & testing
2. Reference [ACCURATE_SEQUENCE_DIAGRAM.md](./ACCURATE_SEQUENCE_DIAGRAM.md) - Detailed technical flow
3. Use [QUICK_TEST_COMMANDS.sh](./QUICK_TEST_COMMANDS.sh) - Testing scripts

### Understanding the Architecture?
1. Read [ACCURATE_SEQUENCE_DIAGRAM.md](./ACCURATE_SEQUENCE_DIAGRAM.md) - Complete technical details
2. Study [ACCURATE_SEQUENCE_DIAGRAM_MERMAID.md](./ACCURATE_SEQUENCE_DIAGRAM_MERMAID.md) - Visual diagrams
3. Review [CORRECTIONS_SUMMARY.md](./CORRECTIONS_SUMMARY.md) - Key architectural points

---

## 📖 Documentation Files

### Core Documentation (✅ Accurate)

| File | Purpose | Audience |
|------|---------|----------|
| [DEVELOPER_QUICK_REFERENCE.md](./DEVELOPER_QUICK_REFERENCE.md) | Quick start guide with code examples | Developers |
| [ACCURATE_SEQUENCE_DIAGRAM.md](./ACCURATE_SEQUENCE_DIAGRAM.md) | Detailed technical flow with ASCII diagrams | Technical readers |
| [ACCURATE_SEQUENCE_DIAGRAM_MERMAID.md](./ACCURATE_SEQUENCE_DIAGRAM_MERMAID.md) | Visual flow diagrams using Mermaid | Visual learners |
| [CORRECTIONS_SUMMARY.md](./CORRECTIONS_SUMMARY.md) | What was wrong in previous docs | Everyone |

### Legacy Documentation (⚠️ Inaccurate - Do Not Use)

| File | Status | Replacement |
|------|--------|-------------|
| [SEQUENCE_DIAGRAM.md](./SEQUENCE_DIAGRAM.md) | ❌ Inaccurate | Use [ACCURATE_SEQUENCE_DIAGRAM.md](./ACCURATE_SEQUENCE_DIAGRAM.md) |
| [SEQUENCE_DIAGRAM_MERMAID.md](./SEQUENCE_DIAGRAM_MERMAID.md) | ❌ Inaccurate | Use [ACCURATE_SEQUENCE_DIAGRAM_MERMAID.md](./ACCURATE_SEQUENCE_DIAGRAM_MERMAID.md) |

### Supporting Documentation

| File | Purpose |
|------|---------|
| [CORRECT_DEPLOYMENT_ORDER.md](./CORRECT_DEPLOYMENT_ORDER.md) | Deployment sequence |
| [CROSS_CHAIN_FLOW_DIAGRAM.md](./CROSS_CHAIN_FLOW_DIAGRAM.md) | Cross-chain flow overview |
| [QUICK_TEST_COMMANDS.sh](./QUICK_TEST_COMMANDS.sh) | Testing scripts |
| [USDT_WGC_TESTING_GUIDE.md](./USDT_WGC_TESTING_GUIDE.md) | Specific token pair testing |
| [SCRIPTS_UPDATE_SUMMARY.md](./SCRIPTS_UPDATE_SUMMARY.md) | Script changes log |

---

## 🔑 Key Concepts

### 1. Virtual Liquidity
Tokens stay in LP wallets, Aqua tracks virtual balances. No tokens locked in pools.

**Learn more:**
- [DEVELOPER_QUICK_REFERENCE.md § Virtual Liquidity](./DEVELOPER_QUICK_REFERENCE.md#1-virtual-liquidity)
- [ACCURATE_SEQUENCE_DIAGRAM.md § Aqua Virtual Balance System](./ACCURATE_SEQUENCE_DIAGRAM.md#aqua-virtual-balance-system)

### 2. Cross-Chain Strategy Shipping
LPs ship strategies via LayerZero messages (no tokens transferred during shipping).

**Learn more:**
- [DEVELOPER_QUICK_REFERENCE.md § Strategy Shipping](./DEVELOPER_QUICK_REFERENCE.md#2-strategy-shipping-message-only)
- [ACCURATE_SEQUENCE_DIAGRAM.md § Phase 1](./ACCURATE_SEQUENCE_DIAGRAM.md#phase-1-lp-strategy-setup-cross-chain-shipping)
- [ACCURATE_SEQUENCE_DIAGRAM_MERMAID.md § Phase 1](./ACCURATE_SEQUENCE_DIAGRAM_MERMAID.md#phase-1-lp-strategy-setup-cross-chain-shipping)

### 3. Intent-Based Swaps
Traders submit intents, LPs fulfill, execution happens on Base.

**Learn more:**
- [DEVELOPER_QUICK_REFERENCE.md § Intent-Based Swaps](./DEVELOPER_QUICK_REFERENCE.md#3-intent-based-swaps)
- [ACCURATE_SEQUENCE_DIAGRAM.md § Phase 3](./ACCURATE_SEQUENCE_DIAGRAM.md#phase-3-intent-based-swap-flow-trader--lp)

### 4. Dual Token Bridge
Both tokens bridge simultaneously to Base for swap execution.

**Learn more:**
- [DEVELOPER_QUICK_REFERENCE.md § Dual Token Bridge](./DEVELOPER_QUICK_REFERENCE.md#4-dual-token-bridge)
- [ACCURATE_SEQUENCE_DIAGRAM.md § Step 3.3](./ACCURATE_SEQUENCE_DIAGRAM.md#step-33-settlement---dual-stargate-bridge-world--base)
- [CORRECTIONS_SUMMARY.md § Dual Token Bridge](./CORRECTIONS_SUMMARY.md#3-dual-token-bridge-critical)

---

## 🎨 Visual Learning Path

### Mermaid Diagrams (Recommended)

1. **Complete Flow**: [ACCURATE_SEQUENCE_DIAGRAM_MERMAID.md § Complete End-to-End](./ACCURATE_SEQUENCE_DIAGRAM_MERMAID.md#complete-end-to-end-flow-simplified)
2. **Phase 1 - Setup**: [ACCURATE_SEQUENCE_DIAGRAM_MERMAID.md § Phase 1](./ACCURATE_SEQUENCE_DIAGRAM_MERMAID.md#phase-1-lp-strategy-setup-cross-chain-shipping)
3. **Phase 2 - Intent**: [ACCURATE_SEQUENCE_DIAGRAM_MERMAID.md § Phase 2](./ACCURATE_SEQUENCE_DIAGRAM_MERMAID.md#phase-2-intent-submission-world-chain)
4. **Phase 3 - Fulfillment**: [ACCURATE_SEQUENCE_DIAGRAM_MERMAID.md § Phase 3](./ACCURATE_SEQUENCE_DIAGRAM_MERMAID.md#phase-3-intent-fulfillment-world-chain)
5. **Phase 4 - Settlement**: [ACCURATE_SEQUENCE_DIAGRAM_MERMAID.md § Phase 4](./ACCURATE_SEQUENCE_DIAGRAM_MERMAID.md#phase-4-settlement---dual-token-bridge-world--base)
6. **Phase 5 - Execution**: [ACCURATE_SEQUENCE_DIAGRAM_MERMAID.md § Phase 5](./ACCURATE_SEQUENCE_DIAGRAM_MERMAID.md#phase-5-swap-execution-on-base)
7. **Phase 6 - Return**: [ACCURATE_SEQUENCE_DIAGRAM_MERMAID.md § Phase 6](./ACCURATE_SEQUENCE_DIAGRAM_MERMAID.md#phase-6-bridge-tokens-back-to-world-chain)

### ASCII Diagrams (Detailed)

For detailed technical diagrams with annotations, see [ACCURATE_SEQUENCE_DIAGRAM.md](./ACCURATE_SEQUENCE_DIAGRAM.md).

---

## 🛠️ Developer Workflows

### LP Workflow

```
1. Ship Strategy (Ethereum → Base)
   ↓
2. Register Strategy (World Chain)
   ↓
3. Wait for intents...
   ↓
4. Fulfill intents
   ↓
5. Earn fees!
```

**Detailed guide**: [DEVELOPER_QUICK_REFERENCE.md § LP Workflow](./DEVELOPER_QUICK_REFERENCE.md#2-lp-workflow)

### Trader Workflow

```
1. Submit Intent (World Chain)
   ↓
2. Wait for LP fulfillment
   ↓
3. Settle intent
   ↓
4. Receive tokens!
```

**Detailed guide**: [DEVELOPER_QUICK_REFERENCE.md § Trader Workflow](./DEVELOPER_QUICK_REFERENCE.md#3-trader-workflow)

---

## 🔍 Common Questions

### Q: Where are the tokens stored?

**A:** Tokens stay in **LP's wallet** on Base. Aqua only tracks virtual balances. See [CORRECTIONS_SUMMARY.md § Aqua Virtual Balance System](./CORRECTIONS_SUMMARY.md#4-aqua-virtual-balance-system).

### Q: Are tokens transferred during strategy shipping?

**A:** **No!** Strategy shipping is a message-only operation. Only virtual balances are recorded. See [CORRECTIONS_SUMMARY.md § Strategy Shipping](./CORRECTIONS_SUMMARY.md#1-strategy-shipping-message-only).

### Q: Why dual token bridge?

**A:** Need both LP's tokenOut (for trader) and Trader's tokenIn (for swap). Both must arrive before execution. See [CORRECTIONS_SUMMARY.md § Dual Token Bridge](./CORRECTIONS_SUMMARY.md#3-dual-token-bridge-critical).

### Q: What happens if swap fails?

**A:** CrossChainSwapComposer has try-catch. On failure, both tokens are refunded to original owners. See [ACCURATE_SEQUENCE_DIAGRAM.md § Step 3.4](./ACCURATE_SEQUENCE_DIAGRAM.md#step-34-swap-execution-on-base).

### Q: How long does end-to-end take?

**A:** 10-20 minutes total (LayerZero bridging is the bottleneck). See [DEVELOPER_QUICK_REFERENCE.md § Performance Metrics](./DEVELOPER_QUICK_REFERENCE.md#performance-metrics).

---

## 🏗️ Architecture Overview

### Chains

| Chain | Components | Role |
|-------|-----------|------|
| **Ethereum Sepolia** | AquaStrategyComposer | Optional: Ship strategies |
| **Base Sepolia** | Aqua, AMMs, Composers | Execution: Strategies live here |
| **World Chain** | IntentPool, OFTs | Intent matching & bridging |

### Contracts

| Contract | Chain | Purpose |
|----------|-------|---------|
| `Aqua` | Base | Track virtual balances |
| `StableswapAMM` | Base | Curve-style swaps |
| `ConcentratedLiquiditySwap` | Base | Uniswap V3-style swaps |
| `AquaStrategyComposer` | Ethereum/Base | Ship strategies cross-chain |
| `IntentPool` | World | Match intents |
| `CrossChainSwapComposer` | Base | Execute cross-chain swaps |

**Detailed architecture**: [ACCURATE_SEQUENCE_DIAGRAM.md § Architecture Components](./ACCURATE_SEQUENCE_DIAGRAM.md#architecture-components)

---

## 🧪 Testing

### Quick Test

```bash
# Run all tests
./QUICK_TEST_COMMANDS.sh

# Or step by step
forge script scripts/shipStrategyToChain.s.sol --broadcast --rpc-url $ETH_RPC
forge script scripts/intent/Step1_SubmitIntent.s.sol --broadcast --rpc-url $WORLD_RPC
forge script scripts/intent/Step2_FulfillIntent.s.sol --broadcast --rpc-url $WORLD_RPC
forge script scripts/intent/Step3_SettleIntent.s.sol --broadcast --rpc-url $WORLD_RPC
```

**Detailed testing guide**: [DEVELOPER_QUICK_REFERENCE.md § Testing Workflow](./DEVELOPER_QUICK_REFERENCE.md#testing-workflow)

---

## 🐛 Debugging

### Common Issues

1. **Strategy Hash Mismatch**: [DEVELOPER_QUICK_REFERENCE.md § Strategy Hash Mismatch](./DEVELOPER_QUICK_REFERENCE.md#1-strategy-hash-mismatch)
2. **Intent Expired**: [DEVELOPER_QUICK_REFERENCE.md § Intent Expired](./DEVELOPER_QUICK_REFERENCE.md#2-intent-expired)
3. **Insufficient Virtual Balance**: [DEVELOPER_QUICK_REFERENCE.md § Insufficient Virtual Balance](./DEVELOPER_QUICK_REFERENCE.md#3-insufficient-virtual-balance)
4. **Composer Not Trusted**: [DEVELOPER_QUICK_REFERENCE.md § Composer Not Trusted Delegate](./DEVELOPER_QUICK_REFERENCE.md#4-composer-not-trusted-delegate)

### Debugging Tools

```bash
# Check virtual balance
cast call $AQUA "safeBalances(...)" --rpc-url $BASE_RPC

# Check intent status
cast call $POOL "getIntent(bytes32)" $INTENT_ID --rpc-url $WORLD_RPC

# Monitor events
cast logs --address $COMPOSER --rpc-url $BASE_RPC

# Track LayerZero
open "https://layerzeroscan.com/tx/$GUID"
```

**Full debugging guide**: [DEVELOPER_QUICK_REFERENCE.md § Debugging Tips](./DEVELOPER_QUICK_REFERENCE.md#debugging-tips)

---

## 📊 What Was Corrected

The previous documentation had several fundamental misunderstandings:

### Major Corrections

1. ❌ **Wrong**: Tokens transferred during strategy shipping
   - ✅ **Correct**: Message-only operation, no tokens

2. ❌ **Wrong**: Single token bridge
   - ✅ **Correct**: Dual token bridge (LP's tokenOut + Trader's tokenIn)

3. ❌ **Wrong**: Tokens locked in pools
   - ✅ **Correct**: Tokens stay in LP wallets, Aqua tracks virtual balances

4. ❌ **Wrong**: Unclear intent lifecycle
   - ✅ **Correct**: Submit → Fulfill → Settle (3 distinct steps)

5. ❌ **Wrong**: Missing AMM callback
   - ✅ **Correct**: AMM calls `stableswapCallback()` for token push

**Full corrections list**: [CORRECTIONS_SUMMARY.md](./CORRECTIONS_SUMMARY.md)

---

## 🎓 Learning Resources

### Internal Documentation
- [Aqua Whitepaper](./packages/aqua-contracts/whitepaper/aqua-dev-preview.md)
- [Deployment Guide](./packages/layerzero-contracts/DEPLOYMENT_GUIDE_FINAL.md)
- [Cross-Chain Token Registration](./packages/layerzero-contracts/CROSS_CHAIN_TOKEN_REGISTRATION.md)

### External Resources
- [LayerZero Documentation](https://docs.layerzero.network/)
- [Stargate Documentation](https://stargateprotocol.gitbook.io/)
- [Curve Stableswap Paper](https://curve.fi/files/stableswap-paper.pdf)
- [Uniswap V3 Whitepaper](https://uniswap.org/whitepaper-v3.pdf)

### Tools
- [LayerZero Scan](https://layerzeroscan.com/) - Track cross-chain messages
- [Foundry Book](https://book.getfoundry.sh/) - Solidity development
- [Cast Reference](https://book.getfoundry.sh/cast/) - CLI tool

---

## 🚀 Quick Start

### 1. Read the 5-minute overview
[DEVELOPER_QUICK_REFERENCE.md § TL;DR](./DEVELOPER_QUICK_REFERENCE.md#tldr---how-it-works)

### 2. Visualize the flow
[ACCURATE_SEQUENCE_DIAGRAM_MERMAID.md § Complete Flow](./ACCURATE_SEQUENCE_DIAGRAM_MERMAID.md#complete-end-to-end-flow-simplified)

### 3. Run a test
```bash
./QUICK_TEST_COMMANDS.sh
```

### 4. Build your integration
[DEVELOPER_QUICK_REFERENCE.md § Code Examples](./DEVELOPER_QUICK_REFERENCE.md#code-examples)

---

## 📝 Documentation Status

| Document | Status | Last Updated |
|----------|--------|--------------|
| DEVELOPER_QUICK_REFERENCE.md | ✅ Accurate | 2025-01-23 |
| ACCURATE_SEQUENCE_DIAGRAM.md | ✅ Accurate | 2025-01-23 |
| ACCURATE_SEQUENCE_DIAGRAM_MERMAID.md | ✅ Accurate | 2025-01-23 |
| CORRECTIONS_SUMMARY.md | ✅ Accurate | 2025-01-23 |
| SEQUENCE_DIAGRAM.md | ❌ Deprecated | - |
| SEQUENCE_DIAGRAM_MERMAID.md | ❌ Deprecated | - |

---

## 🤝 Contributing

When updating documentation:

1. **Verify against code**: Always check the actual implementation in `/packages`
2. **Update all related docs**: Keep consistency across files
3. **Add examples**: Code examples help understanding
4. **Visual aids**: Mermaid diagrams for complex flows
5. **Test instructions**: Ensure commands work

---

## 📞 Support

### Documentation Issues
- Found an error? Check [CORRECTIONS_SUMMARY.md](./CORRECTIONS_SUMMARY.md) first
- Still confused? Review [DEVELOPER_QUICK_REFERENCE.md](./DEVELOPER_QUICK_REFERENCE.md)
- Need clarification? Open an issue with specific questions

### Technical Issues
- Check [DEVELOPER_QUICK_REFERENCE.md § Debugging Tips](./DEVELOPER_QUICK_REFERENCE.md#debugging-tips)
- Review [DEVELOPER_QUICK_REFERENCE.md § Common Issues](./DEVELOPER_QUICK_REFERENCE.md#common-issues)
- Search existing issues in the repo

---

## 🎯 Next Steps

### For Developers
1. ✅ Read [DEVELOPER_QUICK_REFERENCE.md](./DEVELOPER_QUICK_REFERENCE.md)
2. ✅ Run [QUICK_TEST_COMMANDS.sh](./QUICK_TEST_COMMANDS.sh)
3. ✅ Build your integration
4. ✅ Test on testnet
5. ✅ Deploy to mainnet

### For Researchers
1. ✅ Read [ACCURATE_SEQUENCE_DIAGRAM.md](./ACCURATE_SEQUENCE_DIAGRAM.md)
2. ✅ Study [Aqua Whitepaper](./packages/aqua-contracts/whitepaper/aqua-dev-preview.md)
3. ✅ Analyze [CORRECTIONS_SUMMARY.md](./CORRECTIONS_SUMMARY.md)
4. ✅ Review contract implementations

### For Auditors
1. ✅ Read [CORRECTIONS_SUMMARY.md](./CORRECTIONS_SUMMARY.md) - Common misunderstandings
2. ✅ Study [ACCURATE_SEQUENCE_DIAGRAM.md](./ACCURATE_SEQUENCE_DIAGRAM.md) - Complete flow
3. ✅ Review [DEVELOPER_QUICK_REFERENCE.md § Security Checklist](./DEVELOPER_QUICK_REFERENCE.md#security-checklist)
4. ✅ Analyze contract code in `/packages`

---

**Last Updated**: November 23, 2025  
**Documentation Version**: 2.0 (Accurate)  
**Status**: ✅ Production Ready

---

## 📚 Document Map

```
aqua0/
├── DOCUMENTATION_INDEX.md (you are here)
│
├── Core Documentation (✅ Use These)
│   ├── DEVELOPER_QUICK_REFERENCE.md
│   ├── ACCURATE_SEQUENCE_DIAGRAM.md
│   ├── ACCURATE_SEQUENCE_DIAGRAM_MERMAID.md
│   └── CORRECTIONS_SUMMARY.md
│
├── Legacy Documentation (❌ Don't Use)
│   ├── SEQUENCE_DIAGRAM.md
│   └── SEQUENCE_DIAGRAM_MERMAID.md
│
├── Supporting Documentation
│   ├── CORRECT_DEPLOYMENT_ORDER.md
│   ├── CROSS_CHAIN_FLOW_DIAGRAM.md
│   ├── QUICK_TEST_COMMANDS.sh
│   ├── USDT_WGC_TESTING_GUIDE.md
│   └── SCRIPTS_UPDATE_SUMMARY.md
│
└── Package Documentation
    ├── packages/aqua-contracts/whitepaper/
    ├── packages/layerzero-contracts/DEPLOYMENT_GUIDE_FINAL.md
    └── packages/layerzero-contracts/CROSS_CHAIN_TOKEN_REGISTRATION.md
```

---

**Happy Building! 🚀**


