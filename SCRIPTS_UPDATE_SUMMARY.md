# 📝 Scripts Update Summary: USDT/rUSD → USDT/WGC

All scripts in `packages/layerzero-contracts/scripts/` have been updated to use **USDT/WGC** instead of USDT/rUSD.

## ✅ Updated Files

### 1. Deploy Scripts

#### `scripts/deploy/DeployIntentPool.s.sol`
**Changes:**
- ✅ Changed `STARGATE_rUSD_WORLD` → `STARGATE_WGC_WORLD`
- ✅ Updated variable name `stargateRUSD` → `stargateWGC`
- ✅ Added fallback to `PRIVATE_KEY` if `DEPLOYER_PRIVATE_KEY` not set
- ✅ Updated console output to mention "USDT/WGC"

**Environment Variables:**
```bash
# Before
STARGATE_rUSD_WORLD=<address>

# After
STARGATE_WGC_WORLD=<address>
```

---

### 2. Intent Scripts

#### `scripts/intent/Step1_SubmitIntent.s.sol`
**Changes:**
- ✅ Changed `rUSD_ADDRESS` → `WGC_ADDRESS`
- ✅ Updated variable name `rusd` → `wgc`
- ✅ Added default address for WGC: `0x3d63825b0d8669307366e6c8202f656b9e91d368`
- ✅ Fixed decimal calculation: Both USDT and WGC have 6 decimals (no conversion needed)
- ✅ Updated fee calculation: `(amountIn * 9996) / 10000` (removed 1e12 multiplier)
- ✅ Updated console output to show "USDT -> WGC"

**Before (USDT/rUSD):**
```solidity
uint256 expectedOut = (amountIn * 1e12 * 9996) / 10000; // 6 to 18 decimals
```

**After (USDT/WGC):**
```solidity
uint256 expectedOut = (amountIn * 9996) / 10000; // Both 6 decimals
```

**Environment Variables:**
```bash
# Before
rUSD_ADDRESS=$rUSD_WORLD

# After
WGC_ADDRESS=$WGC_WORLD  # Optional, has default
```

---

#### `scripts/intent/Step2_FulfillIntent.s.sol`
**Changes:**
- ✅ Changed `rUSD_ADDRESS` → `WGC_ADDRESS`
- ✅ Updated variable name `rusd` → `wgc`
- ✅ Added default address for WGC
- ✅ Updated console output to show "WGC" instead of "rUSD"
- ✅ Changed approval from rUSD to WGC

**Environment Variables:**
```bash
# Before
rUSD_ADDRESS=$rUSD_WORLD

# After
WGC_ADDRESS=$WGC_WORLD  # Optional, has default
```

---

#### `scripts/intent/Step3_SettleIntent.s.sol`
**Changes:**
- ✅ Added fallback to `PRIVATE_KEY` if `SETTLER_PRIVATE_KEY` not set
- ✅ Updated console output to mention "USDT/WGC Swap"
- ✅ Updated expected events description (WGC instead of rUSD)
- ✅ Updated final result description

**Environment Variables:**
```bash
# No changes to env vars, but now supports PRIVATE_KEY fallback
```

---

### 3. Strategy Shipping Script

#### `scripts/shipStrategyToChain.s.sol`
**Changes:**
- ✅ Changed token ID: `keccak256("rUSD")` → `keccak256("WGC")`
- ✅ Updated amounts: `2e18` → `2e6` (both tokens now 6 decimals)
- ✅ Updated console output to show "WGC" instead of "rUSD"

**Before:**
```solidity
tokenIds[1] = keccak256("rUSD");
amounts[1] = 2e18; // 2 rUSD (18 decimals)
```

**After:**
```solidity
tokenIds[1] = keccak256("WGC");
amounts[1] = 2e6; // 2 WGC (6 decimals)
```

---

## 📊 Key Differences: USDT/rUSD vs USDT/WGC

| Aspect | USDT/rUSD | USDT/WGC |
|--------|-----------|----------|
| **Token 0 Decimals** | 6 | 6 |
| **Token 1 Decimals** | 18 | 6 ✅ |
| **Decimal Conversion** | Required (×1e12) | Not needed ✅ |
| **Fee Calculation** | `(amt * 1e12 * 9996) / 10000` | `(amt * 9996) / 10000` |
| **Virtual Amounts** | `[2e6, 2e18]` | `[2e6, 2e6]` |
| **Stableswap Suitability** | Suboptimal | Perfect ✅ |

---

## 🎯 Token Addresses Reference

### World Chain
```bash
export USDT_WORLD=0x13a3ca7638802f66ce4e12b101727405ec589f47
export WGC_WORLD=0x3d63825b0d8669307366e6c8202f656b9e91d368
```

### Base Chain
```bash
export USDT_BASE=0xeab8fa7ab28f05d7600558b873d5c7f805412304
export WGC_BASE=0x3d63825b0d8669307366e6c8202f656b9e91d368  # Same as World!
```

---

## 🔧 Environment Variable Changes

### Required New Variables
```bash
# Replace rUSD with WGC
export STARGATE_WGC_WORLD=<stargate_wgc_oft_address>
export WGC_ADDRESS=$WGC_WORLD  # Optional in scripts, has default
```

### Removed Variables
```bash
# No longer needed
# export STARGATE_rUSD_WORLD=...
# export rUSD_ADDRESS=...
```

### Optional Variables (Now with Fallbacks)
```bash
# These now fall back to PRIVATE_KEY if not set
DEPLOYER_PRIVATE_KEY  # Falls back to PRIVATE_KEY
SETTLER_PRIVATE_KEY   # Falls back to PRIVATE_KEY
```

---

## 🚀 Usage Examples

### Before (USDT/rUSD)
```bash
export rUSD_ADDRESS=$rUSD_WORLD
export STARGATE_rUSD_WORLD=<address>

forge script scripts/intent/Step1_SubmitIntent.s.sol \
  --rpc-url $WORLD_RPC \
  --broadcast
```

### After (USDT/WGC)
```bash
# WGC_ADDRESS is optional (has default)
export STARGATE_WGC_WORLD=<address>

forge script scripts/intent/Step1_SubmitIntent.s.sol \
  --rpc-url $WORLD_RPC \
  --broadcast
```

---

## ✅ Testing Checklist

- [x] Updated `DeployIntentPool.s.sol` for WGC
- [x] Updated `Step1_SubmitIntent.s.sol` for WGC
- [x] Updated `Step2_FulfillIntent.s.sol` for WGC
- [x] Updated `Step3_SettleIntent.s.sol` for WGC
- [x] Updated `shipStrategyToChain.s.sol` for WGC
- [x] Fixed decimal calculations (6 decimals for both)
- [x] Added default addresses for convenience
- [x] Added fallback to PRIVATE_KEY
- [x] Updated all console outputs
- [x] Created comprehensive testing guide

---

## 📚 Documentation Created

1. **`USDT_WGC_TESTING_GUIDE.md`** - Complete step-by-step testing guide
2. **`QUICK_TEST_COMMANDS.sh`** - Automated test script
3. **`SCRIPTS_UPDATE_SUMMARY.md`** - This file

---

## 🎓 What You Need to Know

### 1. Decimal Handling
- **USDT**: 6 decimals on both chains
- **WGC**: 6 decimals on both chains
- **No conversion needed** between USDT and WGC amounts

### 2. Stargate OFT Addresses
You **must** find and set these before deploying IntentPool:
```bash
export STARGATE_USDT_WORLD=<from_stargate_docs>
export STARGATE_WGC_WORLD=<from_stargate_docs>
```

If WGC doesn't have Stargate support, you'll need an alternative bridging solution.

### 3. Default Addresses
Scripts now have sensible defaults:
- `USDT_WORLD`: `0x13a3ca7638802f66ce4e12b101727405ec589f47`
- `WGC_WORLD`: `0x3d63825b0d8669307366e6c8202f656b9e91d368`

You can override them with environment variables if needed.

### 4. Private Key Fallbacks
Scripts now support multiple private key env vars:
- `DEPLOYER_PRIVATE_KEY` → falls back to `PRIVATE_KEY`
- `SETTLER_PRIVATE_KEY` → falls back to `PRIVATE_KEY`
- `TRADER_PRIVATE_KEY` → required (no fallback)
- `LP_PRIVATE_KEY` → required (no fallback)

---

## 🔍 How to Verify Updates

### Check Script Contents
```bash
# Verify WGC is used instead of rUSD
grep -r "rUSD" packages/layerzero-contracts/scripts/
# Should return no results

grep -r "WGC" packages/layerzero-contracts/scripts/
# Should show all updated files
```

### Check Decimal Calculations
```bash
# Look for the fee calculation in Step1
grep "expectedOut" packages/layerzero-contracts/scripts/intent/Step1_SubmitIntent.s.sol
# Should show: (amountIn * 9996) / 10000
# NOT: (amountIn * 1e12 * 9996) / 10000
```

### Check Strategy Amounts
```bash
# Look for virtual amounts in shipStrategyToChain
grep "amounts\[1\]" packages/layerzero-contracts/scripts/shipStrategyToChain.s.sol
# Should show: 2e6 (not 2e18)
```

---

## ⚠️ Breaking Changes

If you have existing deployments using USDT/rUSD:

1. **IntentPool**: Deploy a new one for USDT/WGC
2. **Strategy**: Ship a new strategy with WGC token ID
3. **Environment**: Update all env vars from rUSD to WGC

**Do NOT reuse existing USDT/rUSD deployments for USDT/WGC!**

---

## 🎉 Summary

All scripts are now ready for USDT/WGC testing! The main improvements:

✅ Correct token pair (WGC instead of rUSD)  
✅ Proper decimal handling (both 6 decimals)  
✅ Simplified calculations (no conversion needed)  
✅ Better defaults (addresses pre-configured)  
✅ More flexible (private key fallbacks)  
✅ Clear documentation (comprehensive guides)

**Ready to test!** Follow `USDT_WGC_TESTING_GUIDE.md` for complete instructions.


