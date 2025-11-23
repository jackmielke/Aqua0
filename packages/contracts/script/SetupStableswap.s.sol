// SPDX-License-Identifier: LicenseRef-Degensoft-Aqua-Source-1.1
pragma solidity 0.8.30;

import "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Aqua} from "aqua/Aqua.sol";
import {StableswapAMM} from "../src/StableswapAMM.sol";

/// @title SetupStableswap
/// @notice Sets up a Stableswap strategy with USDC/USDT pair
/// @dev Uses LP_PRIVATE_KEY for liquidity provider (not DEPLOYER_KEY)
contract SetupStableswap is Script {
    function run() external {
        // Use LP private key (the one with tokens)
        uint256 lpPrivateKey = vm.envUint("LP_PRIVATE_KEY");
        address lpAddress = vm.addr(lpPrivateKey);

        // Load deployed addresses
        address aquaAddr = vm.envAddress("AQUA_ROUTER");
        address stableswapAddr = vm.envAddress("STABLESWAP");
        address usdcAddr = vm.envAddress("USDC");
        address usdtAddr = vm.envAddress("USDT");

        console.log("=================================================");
        console.log("Setting up Stableswap Strategy (Mainnet)");
        console.log("=================================================");
        console.log("LP (Maker):", lpAddress);
        console.log("Aqua:", aquaAddr);
        console.log("Strategy:", stableswapAddr);
        console.log("USDC:", usdcAddr);
        console.log("USDT:", usdtAddr);

        Aqua aqua = Aqua(aquaAddr);
        IERC20 usdc = IERC20(usdcAddr);
        IERC20 usdt = IERC20(usdtAddr);

        // Check LP balances
        uint256 usdcBalance = usdc.balanceOf(lpAddress);
        uint256 usdtBalance = usdt.balanceOf(lpAddress);
        console.log("\nLP Token Balances:");
        console.log("USDC:", usdcBalance / 1e6, "USDC");
        console.log("USDT:", usdtBalance / 1e6, "USDT");

        // Initial liquidity amounts (adjust based on available balance)
        uint256 usdcAmount = vm.envOr("USDC_LIQUIDITY", uint256(2e6)); // Default 2 USDC
        uint256 usdtAmount = vm.envOr("USDT_LIQUIDITY", uint256(2e6)); // Default 2 USDT

        require(usdcBalance >= usdcAmount, "Insufficient USDC balance");
        require(usdtBalance >= usdtAmount, "Insufficient USDT balance");

        console.log("\nProviding Liquidity:");
        console.log("USDC:", usdcAmount / 1e6, "USDC");
        console.log("USDT:", usdtAmount / 1e6, "USDT");

        vm.startBroadcast(lpPrivateKey);

        // Approve Aqua to spend tokens
        usdc.approve(aquaAddr, type(uint256).max);
        usdt.approve(aquaAddr, type(uint256).max);
        console.log("Approved Aqua to spend tokens");

        // Create strategy with high amplification for stable pairs
        // Use deterministic salt for easier testing
        bytes32 salt = bytes32(0);
        StableswapAMM.Strategy memory strategy = StableswapAMM.Strategy({
            maker: lpAddress,
            token0: usdcAddr,
            token1: usdtAddr,
            feeBps: 4, // 0.04% fee (typical for stableswaps)
            amplificationFactor: 100, // High A for minimal slippage
            salt: salt
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

        console.log("=================================================");
        console.log("Strategy Deployed Successfully!");
        console.log("=================================================");
        console.log("Strategy Hash:", vm.toString(strategyHash));
        console.log("Maker (LP):", lpAddress);
        console.log("Liquidity Provided:");
        console.log("  USDC:", usdcAmount / 1e6, "USDC");
        console.log("  USDT:", usdtAmount / 1e6, "USDT");
        console.log("Fee: 0.04% (4 bps)");
        console.log("Amplification Factor: 100");
        console.log("=================================================");

        vm.stopBroadcast();

        // Save strategy info including salt
        string memory output = string.concat(
            "STRATEGY_HASH=",
            vm.toString(strategyHash),
            "\n",
            "MAKER=",
            vm.toString(lpAddress),
            "\n",
            "TOKEN0=",
            vm.toString(usdcAddr),
            "\n",
            "TOKEN1=",
            vm.toString(usdtAddr),
            "\n",
            "SALT=",
            vm.toString(salt),
            "\n"
        );

        vm.writeFile("./script/stableswap-strategy.txt", output);
        console.log("Strategy info saved to script/stableswap-strategy.txt");
    }
}
