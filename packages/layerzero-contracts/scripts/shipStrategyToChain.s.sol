// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import { AquaStrategyComposer } from "../contracts/AquaStrategyComposer.sol";
import { OptionsBuilder } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";
import { MessagingFee, MessagingReceipt } from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";

/**
 * @title ShipStrategyToChainScript
 * @notice Test script to ship a strategy from one chain to another via LayerZero
 * @dev This is a message-only flow - no token transfers involved
 *
 * IMPORTANT: Strategy Hash Consistency
 * =====================================
 * The strategy struct uses canonical token IDs (e.g., keccak256("USDC")) instead of
 * chain-specific token addresses. This ensures the strategy hash is consistent across
 * chains. The AquaStrategyComposer on the destination chain maps these canonical IDs
 * to local token addresses before calling Aqua.shipOnBehalfOf().
 *
 * The salt is set to bytes32(0) for deterministic strategy hashing, matching the
 * mainnet deployment scripts. This makes it easier to predict and verify strategy
 * hashes across chains.
 *
 * Usage:
 * forge script scripts/shipStrategyToChain.s.sol:ShipStrategyToChainScript \
 *   --rpc-url $ETH_SEPOLIA_RPC \
 *   --broadcast \
 *   --verify
 *
 * Environment Variables Required:
 * - PRIVATE_KEY or LP_PRIVATE_KEY: Deployer private key
 * - COMPOSER_ADDRESS: Address of deployed AquaStrategyComposer on source chain
 * - DST_EID: Destination chain endpoint ID (e.g., 40161 for Arbitrum Sepolia)
 * - DST_APP: Address of strategy app on destination chain (e.g., StableswapAMM)
 *
 * Optional:
 * - GAS_LIMIT: Gas limit for execution on destination (default: 200000)
 */
contract ShipStrategyToChainScript is Script {
    using OptionsBuilder for bytes;

    // ══════════════════════════════════════════════════════════════════════════════
    // Strategy Structs (for encoding)
    // ══════════════════════════════════════════════════════════════════════════════
    // NOTE: These are simplified structs used ONLY for cross-chain messaging.
    // The actual strategy on-chain uses token addresses, not canonical IDs.
    // The AquaStrategyComposer maps canonical IDs to addresses on the destination chain.

    struct StableswapStrategy {
        address maker;
        bytes32 token0Id; // Canonical token ID (e.g., keccak256("USDC"))
        bytes32 token1Id; // Canonical token ID (e.g., keccak256("USDT"))
        uint256 feeBps;
        uint256 amplificationFactor;
        bytes32 salt;
    }

    struct ConcentratedLiquidityStrategy {
        address maker;
        bytes32 token0Id;
        bytes32 token1Id;
        uint256 feeBps;
        uint256 priceLower;
        uint256 priceUpper;
        bytes32 salt;
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // Main Script
    // ══════════════════════════════════════════════════════════════════════════════

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
        console.log("Cross-Chain Strategy Shipping Test");
        console.log("=================================================");
        console.log("Sender (Maker):", maker);

        // Get configuration
        address composerAddress = vm.envAddress("COMPOSER_ADDRESS");
        uint32 dstEid = uint32(vm.envUint("DST_EID"));
        address dstApp = vm.envAddress("DST_APP");

        console.log("Composer:", composerAddress);
        console.log("Destination EID:", dstEid);
        console.log("Destination App:", dstApp);

        // Optional parameters
        uint128 gasLimit = 200000;
        if (vm.envExists("GAS_LIMIT")) {
            gasLimit = uint128(vm.envUint("GAS_LIMIT"));
        }

        // ══════════════════════════════════════════════════════════════════════════
        // Prepare strategy data BEFORE broadcast
        // ══════════════════════════════════════════════════════════════════════════

        console.log("\n--- Preparing Strategy ---");

        // Canonical token IDs (chain-agnostic)
        bytes32[] memory tokenIds = new bytes32[](2);
        tokenIds[0] = keccak256("USDC");
        tokenIds[1] = keccak256("USDT");

        // Virtual liquidity amounts (for cross-chain bookkeeping)
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 2e6; // 2 USDC (6 decimals)
        amounts[1] = 2e6; // 2 USDT (6 decimals)

        // Use deterministic salt for consistency (matching mainnet deployment)
        bytes32 salt = bytes32(0);

        bytes memory strategyBytes = abi.encode(
            StableswapStrategy({
                maker: maker,
                token0Id: tokenIds[0],
                token1Id: tokenIds[1],
                feeBps: 4, // 0.04% fee (same as mainnet)
                amplificaxtionFactor: 100, // High A for stablecoins
                salt: salt
            })
        );

        bytes32 strategyHash = keccak256(strategyBytes);

        console.log("Strategy Hash:", vm.toString(strategyHash));
        console.log("Token 0 (USDC):", amounts[0]);
        console.log("Token 1 (USDT):", amounts[1]);
        console.log("Fee: 4 bps (0.04%)");
        console.log("Amplification Factor: 100");
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
            amounts,xx
            options,
            false
        );

        // Add 20% buffer to fee for priority delivery
        // Higher fee = faster executor pickup
        uint256 totalFee = (fee.nativeFee * 120) / 100;
        require(maker.balance >= totalFee, "Insufficient balance");

        console.log("\n--- Shipping Strategy ---");
        console.log("Fee:", totalFee, "wei");

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
        console.log("SUCCESS! Strategy Shipped Cross-Chain");
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
        console.log("https://testnet.layerzeroscan.com/tx/%s", vm.toString(receipt.guid));
        console.log("");
        console.log("To verify on destination chain:");
        console.log("1. Wait 2-5 minutes for message delivery");
        console.log("2. Check Aqua balances with maker address above");
        console.log("3. Look for CrossChainShipExecuted event");
        console.log("");
        console.log("NOTES:");
        console.log("- Strategy uses salt=0x0 (deterministic)");
        console.log("- Fee: 4 bps (0.04% - matching mainnet config)");
        console.log("- Amplification: 100 (optimized for stablecoins)");
        console.log("=================================================");
    }

    // ══════════════════════════════════════════════════════════════════════════════
    // Helper Functions
    // ══════════════════════════════════════════════════════════════════════════════

    /**
     * @notice Example: Ship a concentrated liquidity strategy
     * @dev Uses deterministic salt for consistency
     */
    function shipConcentratedLiquidity() internal {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address sender = vm.addr(pk);

        address composerAddress = vm.envAddress("COMPOSER_ADDRESS");
        uint32 dstEid = uint32(vm.envUint("DST_EID"));
        address dstApp = vm.envAddress("DST_APP");

        vm.startBroadcast(pk);

        AquaStrategyComposer composer = AquaStrategyComposer(payable(composerAddress));

        // Use deterministic salt
        bytes32 salt = bytes32(0);

        // Create concentrated liquidity strategy
        ConcentratedLiquidityStrategy memory strategy = ConcentratedLiquidityStrategy({
            maker: sender,
            token0Id: keccak256("WETH"),
            token1Id: keccak256("USDC"),
            feeBps: 5, // 0.05% fee (same as mainnet)
            priceLower: 1500e18, // $1500 per ETH
            priceUpper: 2500e18, // $2500 per ETH
            salt: salt
        });

        bytes memory strategyBytes = abi.encode(strategy);

        bytes32[] memory tokenIds = new bytes32[](2);
        tokenIds[0] = keccak256("WETH");
        tokenIds[1] = keccak256("USDC");

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1e18; // 1 WETH
        amounts[1] = 2000e6; // 2000 USDC

        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0);

        MessagingFee memory fee = composer.quoteShipStrategy(
            dstEid,
            dstApp,
            strategyBytes,
            tokenIds,
            amounts,
            options,
            false
        );

        composer.shipStrategyToChain{ value: fee.nativeFee }(dstEid, dstApp, strategyBytes, tokenIds, amounts, options);

        vm.stopBroadcast();
    }
}
