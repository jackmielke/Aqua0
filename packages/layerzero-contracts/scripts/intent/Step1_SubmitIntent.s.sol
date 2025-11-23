// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Step1_SubmitIntent
 * @notice Trader submits an intent to swap USDT for WGC
 *
 * Usage:
 * forge script scripts/intent/Step1_SubmitIntent.s.sol:Step1_SubmitIntent --broadcast --rpc-url $WORLD_RPC
 *
 * Required env vars:
 * - TRADER_PRIVATE_KEY
 * - INTENT_POOL_ADDRESS
 * - STRATEGY_HASH
 * - USDT_ADDRESS (World Chain) - default: 0x13a3ca7638802f66ce4e12b101727405ec589f47
 * - WGC_ADDRESS (World Chain) - default: 0x3d63825b0d8669307366e6c8202f656b9e91d368
 * - SWAP_AMOUNT_IN (e.g., 1000000 for 1 USDT with 6 decimals)
 */
contract Step1_SubmitIntent is Script {
    function run() external {
        uint256 traderPk = vm.envUint("TRADER_PRIVATE_KEY");
        address intentPool = vm.envAddress("INTENT_POOL_ADDRESS");
        bytes32 strategyHash = vm.envBytes32("STRATEGY_HASH");

        // Use env vars or defaults for World Chain
        address usdt = vm.envAddress("USDT_ADDRESS");
        address wgc = vm.envAddress("WGC_ADDRESS");
        uint256 amountIn = vm.envUint("SWAP_AMOUNT_IN");

        address trader = vm.addr(traderPk);

        vm.startBroadcast(traderPk);

        // Calculate expected output (assuming 1:1 with 0.04% fee)
        // Note: Both USDT and WGC have 6 decimals
        // For production, query AMM on Base via RPC
        uint256 expectedOut = (amountIn * 9996) / 10000; // 0.04% fee
        uint256 minOut = (expectedOut * 9950) / 10000; // 0.5% slippage
        uint256 deadline = block.timestamp + 1 hours;

        console.log("=== Submitting Intent: USDT -> WGC ===");
        console.log("Trader:", trader);
        console.log("Strategy Hash:", vm.toString(strategyHash));
        console.log("USDT Address:", usdt);
        console.log("WGC Address:", wgc);
        console.log("Amount In (USDT):", amountIn);
        console.log("Expected Out (WGC):", expectedOut);
        console.log("Min Out (WGC):", minOut);
        console.log("Deadline:", deadline);

        // Approve USDT to IntentPool
        IERC20(usdt).approve(intentPool, amountIn);
        console.log("USDT approved");

        // Submit intent
        (bool success, bytes memory data) = intentPool.call(
            abi.encodeWithSignature(
                "submitIntent(bytes32,address,address,uint256,uint256,uint256,uint256)",
                strategyHash,
                usdt,
                wgc,
                amountIn,
                expectedOut,
                minOut,
                deadline
            )
        );

        require(success, "Submit intent failed");
        bytes32 intentId = abi.decode(data, (bytes32));

        console.log("=== Intent Submitted Successfully ===");
        console.log("Intent ID:", vm.toString(intentId));
        console.log("");
        console.log("Next: LP needs to fulfill this intent with WGC");
        console.log("Run: forge script scripts/intent/Step2_FulfillIntent.s.sol");
        console.log("Set env var: INTENT_ID=%s", vm.toString(intentId));

        vm.stopBroadcast();
    }
}
