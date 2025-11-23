// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import { AquaStrategyComposer } from "../contracts/AquaStrategyComposer.sol";
import { OptionsBuilder } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";
import { MessagingFee, MessagingReceipt } from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";

/**
 * @title RegisterTokenCrossChainScript
 * @notice Registers token mappings on a destination chain via LayerZero
 * @dev This allows you to register tokens on Base from World Chain (or vice versa)
 *
 * Usage Example - Register WGC on Base from World Chain:
 * 
 * export COMPOSER_ADDRESS=<composer_on_world_chain>
 * export DST_EID=30184  # Base mainnet
 * export TOKEN_IDS='["WGC"]'
 * export TOKEN_ADDRESSES='["0xYourWGCAddressOnBase"]'
 * 
 * forge script scripts/RegisterTokenCrossChain.s.sol:RegisterTokenCrossChainScript \
 *   --rpc-url $WORLD_RPC \
 *   --broadcast
 *
 * Environment Variables Required:
 * - PRIVATE_KEY: Deployer/owner private key
 * - COMPOSER_ADDRESS: Address of AquaStrategyComposer on SOURCE chain
 * - DST_EID: Destination chain endpoint ID
 * - TOKEN_IDS: JSON array of token symbols (e.g., '["WGC","USDT"]')
 * - TOKEN_ADDRESSES: JSON array of token addresses on DESTINATION chain
 *
 * Optional:
 * - GAS_LIMIT: Gas limit for execution on destination (default: 100000)
 */
contract RegisterTokenCrossChainScript is Script {
    using OptionsBuilder for bytes;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(pk);

        console.log("=================================================");
        console.log("Cross-Chain Token Registration");
        console.log("=================================================");
        console.log("Sender:", deployer);

        // Get configuration
        address composerAddress = vm.envAddress("COMPOSER_ADDRESS");
        uint32 dstEid = uint32(vm.envUint("DST_EID"));

        console.log("Composer:", composerAddress);
        console.log("Destination EID:", dstEid);

        // Parse token IDs from environment
        string memory tokenIdsJson = vm.envString("TOKEN_IDS");
        string[] memory tokenSymbols = vm.parseJsonStringArray(tokenIdsJson, "$");

        // Parse token addresses from environment
        string memory tokenAddressesJson = vm.envString("TOKEN_ADDRESSES");
        address[] memory tokenAddresses = vm.parseJsonAddressArray(tokenAddressesJson, "$");

        require(tokenSymbols.length == tokenAddresses.length, "Array length mismatch");
        require(tokenSymbols.length > 0, "No tokens to register");

        // Convert symbols to canonical IDs
        bytes32[] memory canonicalIds = new bytes32[](tokenSymbols.length);
        for (uint256 i = 0; i < tokenSymbols.length; i++) {
            canonicalIds[i] = keccak256(bytes(tokenSymbols[i]));
        }

        // Optional gas limit
        uint128 gasLimit = 100000;
        if (vm.envExists("GAS_LIMIT")) {
            gasLimit = uint128(vm.envUint("GAS_LIMIT"));
        }

        console.log("\n--- Tokens to Register ---");
        for (uint256 i = 0; i < tokenSymbols.length; i++) {
            console.log("Token:", tokenSymbols[i]);
            console.log("  Canonical ID:", vm.toString(canonicalIds[i]));
            console.log("  Address:", tokenAddresses[i]);
        }

        // ══════════════════════════════════════════════════════════════════════════
        // Start broadcast and execute
        // ══════════════════════════════════════════════════════════════════════════

        vm.startBroadcast(pk);

        AquaStrategyComposer composer = AquaStrategyComposer(payable(composerAddress));

        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(gasLimit, 0);

        MessagingFee memory fee = composer.quoteRegisterTokens(
            dstEid,
            canonicalIds,
            tokenAddresses,
            options,
            false
        );

        // Add 20% buffer to fee
        uint256 totalFee = (fee.nativeFee * 120) / 100;
        require(deployer.balance >= totalFee, "Insufficient balance");

        console.log("\n--- Sending Registration ---");
        console.log("Fee:", totalFee, "wei");
        console.log("Fee (ETH):", totalFee / 1e18);

        MessagingReceipt memory receipt = composer.registerTokensCrossChain{ value: totalFee }(
            dstEid,
            canonicalIds,
            tokenAddresses,
            options
        );

        vm.stopBroadcast();

        // ══════════════════════════════════════════════════════════════════════════
        // Output results
        // ══════════════════════════════════════════════════════════════════════════

        console.log("\n=================================================");
        console.log("SUCCESS! Token Registration Sent Cross-Chain");
        console.log("=================================================");
        console.log("");
        console.log("MESSAGE TRACKING:");
        console.log("GUID:", vm.toString(receipt.guid));
        console.log("Nonce:", receipt.nonce);
        console.log("Fee Paid:", receipt.fee.nativeFee, "wei");
        console.log("");
        console.log("Track your message at:");
        console.log("https://layerzeroscan.com/tx/%s", vm.toString(receipt.guid));
        console.log("");
        console.log("To verify on destination chain:");
        console.log("1. Wait 2-5 minutes for message delivery");
        console.log("2. Check token registry:");
        for (uint256 i = 0; i < tokenSymbols.length; i++) {
            console.log("");
            console.log("   cast call $COMPOSER_DST \\");
            console.log("     \"tokenRegistry(bytes32)(address)\" \\");
            console.log("     $(cast keccak \"%s\") \\", tokenSymbols[i]);
            console.log("     --rpc-url $DST_RPC");
        }
        console.log("");
        console.log("Expected results:");
        for (uint256 i = 0; i < tokenSymbols.length; i++) {
            console.log("  %s => %s", tokenSymbols[i], tokenAddresses[i]);
        }
        console.log("=================================================");
    }
}


