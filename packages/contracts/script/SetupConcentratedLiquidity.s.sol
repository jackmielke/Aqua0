// SPDX-License-Identifier: LicenseRef-Degensoft-Aqua-Source-1.1
pragma solidity 0.8.30;

import "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Aqua} from "aqua/Aqua.sol";
import {ConcentratedLiquiditySwap} from "../src/ConcentratedLiquiditySwap.sol";

/// @title SetupConcentratedLiquidity
/// @notice Sets up a ConcentratedLiquidity strategy with USDC/WETH pair
contract SetupConcentratedLiquidity is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Load deployed addresses
        address aquaAddr = vm.envAddress("AQUA");
        address clSwapAddr = vm.envAddress("CONCENTRATED_LIQUIDITY");
        address usdcAddr = vm.envAddress("USDC");
        address wethAddr = vm.envAddress("WETH");

        console.log("Setting up ConcentratedLiquidity strategy...");
        console.log("Maker:", deployer);
        console.log("Aqua:", aquaAddr);
        console.log("Strategy:", clSwapAddr);
        console.log("USDC:", usdcAddr);
        console.log("WETH:", wethAddr);

        Aqua aqua = Aqua(aquaAddr);
        IERC20 usdc = IERC20(usdcAddr);
        IERC20 weth = IERC20(wethAddr);

        vm.startBroadcast(deployerPrivateKey);

        // Initial liquidity amounts
        uint256 usdcAmount = 100_000e6; // 100k USDC
        uint256 wethAmount = 50 ether; // 50 WETH

        // Approve Aqua to spend tokens
        usdc.approve(aquaAddr, type(uint256).max);
        weth.approve(aquaAddr, type(uint256).max);
        console.log("Approved Aqua to spend tokens");

        // Create strategy with wide price range to handle decimal differences
        // Price = (WETH balance * 1e18) / USDC balance
        // = (50e18 * 1e18) / 100_000e6 = 5e26
        ConcentratedLiquiditySwap.Strategy memory strategy = ConcentratedLiquiditySwap
            .Strategy({
                maker: deployer,
                token0: usdcAddr,
                token1: wethAddr,
                feeBps: 30, // 0.3% fee
                priceLower: 1e9, // Wide range to handle decimal precision
                priceUpper: 1e28,
                salt: bytes32(0)
            });

        // Ship strategy to Aqua
        address[] memory tokens = new address[](2);
        tokens[0] = usdcAddr;
        tokens[1] = wethAddr;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = usdcAmount;
        amounts[1] = wethAmount;

        bytes32 strategyHash = aqua.ship(
            clSwapAddr,
            abi.encode(strategy),
            tokens,
            amounts
        );

        console.log("\nStrategy deployed!");
        console.log("Strategy Hash:", vm.toString(strategyHash));
        console.log("Liquidity provided:");
        console.log("- 100,000 USDC");
        console.log("- 50 WETH");

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
            vm.toString(wethAddr),
            "\n"
        );

        vm.writeFile("./script/concentrated-liquidity-strategy.txt", output);
        console.log(
            "\nStrategy info saved to script/concentrated-liquidity-strategy.txt"
        );
    }
}

