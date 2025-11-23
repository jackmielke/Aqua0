// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import { AquaStrategyComposer } from "../contracts/AquaStrategyComposer.sol";
import { OptionsBuilder } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";
import { MessagingFee, MessagingReceipt } from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";

/**
 * @title ShipUSDT_WGC_StrategyScript
 * @notice Ships a USDT/WGC stableswap strategy from World Chain to Base
 * @dev This script is specifically for the USDT/WGC token pair
 *
 * Usage:
 * forge script scripts/shipUSDT_WGC_Strategy.s.sol:ShipUSDT_WGC_StrategyScript \
 *   --rpc-url $WORLD_RPC \
 *   --broadcast
 *
 * Environment Variables Required:
 * - LP_PRIVATE_KEY or PRIVATE_KEY: LP's private key
 * - COMPOSER_ADDRESS: Address of AquaStrategyComposer on World Chain
 * - DST_EID: Destination chain endpoint ID (30184 for Base)
 * - DST_APP: Address of StableswapAMM on Base
 *
 * Optional:
 * - GAS_LIMIT: Gas limit for execution on destination (default: 200000)
 * - USDT_AMOUNT: Virtual USDT amount (default: 2e6 = 2 USDT)
 * - WGC_AMOUNT: Virtual WGC amount (default: 2e18 = 2 WGC)
 * - FEE_BPS: Fee in basis points (default: 4 = 0.04%)
 * - AMP_FACTOR: Amplification factor (default: 100)
 */
contract ShipUSDT_WGC_StrategyScript is Script {
    using OptionsBuilder for bytes;

    struct StableswapStrategy {
        address maker;
        bytes32 token0Id; // Canonical token ID (e.g., keccak256("USDT"))
        bytes32 token1Id; // Canonical token ID (e.g., keccak256("WGC"))
        uint256 feeBps;
        uint256 amplificationFactor;
        bytes32 salt;
    }

    function run() external {
        // Use LP_PRIVATE_KEY if available, otherwise fall back to PRIVATE_KEY
        uint256 pk;
        if (vm.envExists("LP_PRIVATE_KEY")) {
            pk = vm.envUint("LP_PRIVATE_KEY");
            console.log("Using LP_PRIVATE_KEY");
        } else {
            pk = vm.envUint("PRIVATE_KEY");
            console.log("Using PRIVATE_KEY");
        }

        // Compute maker address ONCE before broadcast
        address maker = vm.addr(pk);

        console.log("=================================================");
        console.log("Shipping USDT/WGC Strategy Cross-Chain");
        console.log("=================================================");
        console.log("Sender (Maker):", maker);

        // Get configuration
        address composerAddress = vm.envAddress("COMPOSER_ADDRESS");
        uint32 dstEid = uint32(vm.envUint("DST_EID"));
        address dstApp = vm.envAddress("DST_APP");

        console.log("Composer:", composerAddress);
        console.log("Destination EID:", dstEid);
        console.log("Destination App:", dstApp);

        // Optional parameters with defaults
        uint128 gasLimit = 200000;
        if (vm.envExists("GAS_LIMIT")) {
            gasLimit = uint128(vm.envUint("GAS_LIMIT"));
        }

        uint256 usdtAmount = 2e6; // 2 USDT (6 decimals)
        if (vm.envExists("USDT_AMOUNT")) {
            usdtAmount = vm.envUint("USDT_AMOUNT");
        }

        uint256 wgcAmount = 2e18; // 2 WGC (assuming 18 decimals)
        if (vm.envExists("WGC_AMOUNT")) {
            wgcAmount = vm.envUint("WGC_AMOUNT");
        }

        uint256 feeBps = 4; // 0.04% fee
        if (vm.envExists("FEE_BPS")) {
            feeBps = vm.envUint("FEE_BPS");
        }

        uint256 ampFactor = 100; // High A for stablecoins
        if (vm.envExists("AMP_FACTOR")) {
            ampFactor = vm.envUint("AMP_FACTOR");
        }

        // ══════════════════════════════════════════════════════════════════════════
        // Prepare strategy data BEFORE broadcast
        // ══════════════════════════════════════════════════════════════════════════

        console.log("\n--- Preparing USDT/WGC Strategy ---");

        // Canonical token IDs (chain-agnostic)
        bytes32[] memory tokenIds = new bytes32[](2);
        tokenIds[0] = keccak256("USDT");
        tokenIds[1] = keccak256("WGC");

        // Virtual liquidity amounts
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = usdtAmount;
        amounts[1] = wgcAmount;

        // Use deterministic salt for consistency
        bytes32 salt = bytes32(0);

        bytes memory strategyBytes = abi.encode(
            StableswapStrategy({
                maker: maker,
                token0Id: tokenIds[0],
                token1Id: tokenIds[1],
                feeBps: feeBps,
                amplificationFactor: ampFactor,
                salt: salt
            })
        );

        bytes32 strategyHash = keccak256(strategyBytes);

        console.log("Strategy Hash:", vm.toString(strategyHash));
        console.log("Token 0 (USDT):", amounts[0]);
        console.log("Token 1 (WGC):", amounts[1]);
        console.log("Fee:", feeBps, "bps");
        console.log("Amplification Factor:", ampFactor);
        console.log("Salt:", vm.toString(salt));

        // ══════════════════════════════════════════════════════════════════════════
        // Start broadcast and execute
        // ══════════════════════════════════════════════════════════════════════════

        vm.startBroadcast(pk);

        AquaStrategyComposer composer = AquaStrategyComposer(payable(composerAddress));

        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(gasLimit, 0);

        MessagingFee memory fee = composer.quoteShipStrategy(
            dstEid,
            dstApp,
            strategyBytes,
            tokenIds,
            amounts,
            options,
            false
        );

        // Add 20% buffer to fee for priority delivery
        uint256 totalFee = (fee.nativeFee * 120) / 100;
        require(maker.balance >= totalFee, "Insufficient balance");

        console.log("\n--- Shipping Strategy ---");
        console.log("Fee:", totalFee, "wei");
        console.log("Fee (ETH):", totalFee / 1e18);

        MessagingReceipt memory receipt = composer.shipStrategyToChain{ value: totalFee }(
            dstEid,
            dstApp,
            strategyBytes,
            tokenIds,
            amounts,
            options
        );

        vm.stopBroadcast();

        // ══════════════════════════════════════════════════════════════════════════
        // Output results
        // ══════════════════════════════════════════════════════════════════════════

        _printResults(maker, strategyHash, receipt);
    }

    function _printResults(address maker, bytes32 strategyHash, MessagingReceipt memory receipt) internal view {
        console.log("\n=================================================");
        console.log("SUCCESS! USDT/WGC Strategy Shipped Cross-Chain");
        console.log("=================================================");
        console.log("");
        console.log("IMPORTANT - Save these values:");
        console.log("---------------------------------------------");
        console.log("Maker Address:", maker);
        console.log("Strategy Hash:", vm.toString(strategyHash));
        console.log("");
        console.log("MESSAGE TRACKING:");
        console.log("GUID:", vm.toString(receipt.guid));
        console.log("Nonce:", receipt.nonce);
        console.log("Fee Paid:", receipt.fee.nativeFee, "wei");
        console.log("");
        console.log("Track your message at:");
        console.log("https://layerzeroscan.com/tx/%s", vm.toString(receipt.guid));
        console.log("");
        console.log("To verify on Base:");
        console.log("1. Wait 2-5 minutes for message delivery");
        console.log("2. Check Aqua balances with maker address above");
        console.log("3. Look for CrossChainShipExecuted event");
        console.log("");
        console.log("NEXT STEPS:");
        console.log("1. Save STRATEGY_HASH for IntentPool registration");
        console.log("2. Register this strategy in IntentPool (if using intent system)");
        console.log("3. Test swaps against this strategy");
        console.log("=================================================");
    }
}


