// SPDX-License-Identifier: LicenseRef-Degensoft-Aqua-Source-1.1
pragma solidity 0.8.30;

import "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Aqua} from "aqua/Aqua.sol";
import {StableswapAMM} from "../src/StableswapAMM.sol";

/// @title SetupStableswap
/// @notice Sets up a Stableswap strategy with USDC/USDT pair
contract SetupStableswap is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Load deployed addresses
        address aquaAddr = vm.envAddress("AQUA");
        address stableswapAddr = vm.envAddress("STABLESWAP");
        address usdcAddr = vm.envAddress("USDC");
        address usdtAddr = vm.envAddress("USDT");

        console.log("Setting up Stableswap strategy...");
        console.log("Maker:", deployer);
        console.log("Aqua:", aquaAddr);
        console.log("Strategy:", stableswapAddr);
        console.log("USDC:", usdcAddr);
        console.log("USDT:", usdtAddr);

        Aqua aqua = Aqua(aquaAddr);
        IERC20 usdc = IERC20(usdcAddr);
        IERC20 usdt = IERC20(usdtAddr);

        vm.startBroadcast(deployerPrivateKey);

        // Initial liquidity amounts
        uint256 usdcAmount = 100_000e6; // 100k USDC
        uint256 usdtAmount = 100_000e6; // 100k USDT

        // Approve Aqua to spend tokens
        usdc.approve(aquaAddr, type(uint256).max);
        usdt.approve(aquaAddr, type(uint256).max);
        console.log("Approved Aqua to spend tokens");

        // Create strategy with high amplification for stable pairs
        StableswapAMM.Strategy memory strategy = StableswapAMM.Strategy({
            maker: deployer,
            token0: usdcAddr,
            token1: usdtAddr,
            feeBps: 4, // 0.04% fee (typical for stableswaps)
            amplificationFactor: 100, // High A for minimal slippage
            salt: bytes32(0)
        });

        // Ship strategy to Aqua
        address[] memory tokens = new address[](2);
        tokens[0] = usdcAddr;
        tokens[1] = usdtAddr;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = usdcAmount;
        amounts[1] = usdtAmount;

        bytes32 strategyHash = aqua.ship(
            stableswapAddr,
            abi.encode(strategy),
            tokens,
            amounts
        );

        console.log("\nStrategy deployed!");
        console.log("Strategy Hash:", vm.toString(strategyHash));
        console.log("Liquidity provided:");
        console.log("- 100,000 USDC");
        console.log("- 100,000 USDT");
        console.log("Amplification Factor: 100");

        vm.stopBroadcast();

        // Save strategy info
        string memory output = string.concat(
            "STRATEGY_HASH=",
            vm.toString(strategyHash),
            "\n",
            "MAKER=",
            vm.toString(deployer),
            "\n",
            "TOKEN0=",
            vm.toString(usdcAddr),
            "\n",
            "TOKEN1=",
            vm.toString(usdtAddr),
            "\n"
        );

        vm.writeFile("./script/stableswap-strategy.txt", output);
        console.log("\nStrategy info saved to script/stableswap-strategy.txt");
    }
}

