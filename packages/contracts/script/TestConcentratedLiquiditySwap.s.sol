// SPDX-License-Identifier: LicenseRef-Degensoft-Aqua-Source-1.1
pragma solidity 0.8.30;

import "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Aqua} from "aqua/Aqua.sol";
import {ConcentratedLiquiditySwap, IConcentratedLiquidityCallback} from "../src/ConcentratedLiquiditySwap.sol";

/// @title SimpleSwapper
/// @notice Helper contract to execute swaps with callback
contract SimpleSwapper is IConcentratedLiquidityCallback {
    Aqua public immutable aqua;

    constructor(Aqua aqua_) {
        aqua = aqua_;
    }

    function concentratedLiquidityCallback(
        address tokenIn,
        address /* tokenOut */,
        uint256 amountIn,
        uint256 /* amountOut */,
        address maker,
        address app,
        bytes32 strategyHash,
        bytes calldata /* takerData */
    ) external override {
        // Approve and push tokens back to Aqua
        IERC20(tokenIn).approve(address(aqua), amountIn);
        aqua.push(maker, app, strategyHash, tokenIn, amountIn);
    }

    function executeSwap(
        ConcentratedLiquiditySwap strategy,
        ConcentratedLiquiditySwap.Strategy memory strategyParams,
        bool zeroForOne,
        uint256 amountIn,
        uint256 minAmountOut
    ) external returns (uint256 amountOut) {
        address tokenIn = zeroForOne
            ? strategyParams.token0
            : strategyParams.token1;

        // Transfer tokens from sender to this contract
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);

        // Execute swap
        amountOut = strategy.swapExactIn(
            strategyParams,
            zeroForOne,
            amountIn,
            minAmountOut,
            msg.sender, // Send output to original sender
            ""
        );
    }
}

/// @title TestConcentratedLiquiditySwap
/// @notice Tests swapping on ConcentratedLiquidity strategy
contract TestConcentratedLiquiditySwap is Script {
    function run() external {
        uint256 traderPrivateKey = vm.envUint("DEPLOYER_KEY");
        address trader = vm.addr(traderPrivateKey);

        // Load deployed addresses
        address aquaAddr = vm.envAddress("AQUA");
        address clSwapAddr = vm.envAddress("CONCENTRATED_LIQUIDITY");
        address usdcAddr = vm.envAddress("USDC");
        address wethAddr = vm.envAddress("WETH");
        address makerAddr = vm.envAddress("MAKER");

        console.log("Testing ConcentratedLiquidity swap...");
        console.log("Trader:", trader);

        Aqua aqua = Aqua(aquaAddr);
        ConcentratedLiquiditySwap clSwap = ConcentratedLiquiditySwap(
            clSwapAddr
        );
        IERC20 usdc = IERC20(usdcAddr);
        IERC20 weth = IERC20(wethAddr);

        vm.startBroadcast(traderPrivateKey);

        // Deploy swapper helper
        SimpleSwapper swapper = new SimpleSwapper(aqua);
        console.log("Swapper deployed at:", address(swapper));

        // Recreate strategy params
        ConcentratedLiquiditySwap.Strategy memory strategy = ConcentratedLiquiditySwap
            .Strategy({
                maker: makerAddr,
                token0: usdcAddr,
                token1: wethAddr,
                feeBps: 30,
                priceLower: 1e9,
                priceUpper: 1e28,
                salt: bytes32(0)
            });

        // Test 1: Swap USDC for WETH
        console.log("\n=== Test 1: Swap 1000 USDC for WETH ===");
        uint256 usdcAmount = 1000e6;

        // Get quote
        uint256 expectedWETH = clSwap.quoteExactIn(strategy, true, usdcAmount);
        console.log("Expected WETH output:", expectedWETH);

        // Check balances before
        uint256 usdcBefore = usdc.balanceOf(trader);
        uint256 wethBefore = weth.balanceOf(trader);
        console.log("USDC balance before:", usdcBefore / 1e6);
        console.log("WETH balance before:", wethBefore / 1e18);

        // Approve and execute swap
        usdc.approve(address(swapper), usdcAmount);
        uint256 wethReceived = swapper.executeSwap(
            clSwap,
            strategy,
            true,
            usdcAmount,
            (expectedWETH * 99) / 100 // 1% slippage tolerance
        );

        // Check balances after
        uint256 usdcAfter = usdc.balanceOf(trader);
        uint256 wethAfter = weth.balanceOf(trader);
        console.log("USDC balance after:", usdcAfter / 1e6);
        console.log("WETH balance after:", wethAfter / 1e18);
        console.log("WETH received:", wethReceived);

        // Test 2: Swap WETH for USDC
        console.log("\n=== Test 2: Swap 0.5 WETH for USDC ===");
        uint256 wethAmount = 0.5 ether;

        // Get quote
        uint256 expectedUSDC = clSwap.quoteExactIn(
            strategy,
            false,
            wethAmount
        );
        console.log("Expected USDC output:", expectedUSDC / 1e6);

        // Approve and execute swap
        weth.approve(address(swapper), wethAmount);
        uint256 usdcReceived = swapper.executeSwap(
            clSwap,
            strategy,
            false,
            wethAmount,
            (expectedUSDC * 99) / 100 // 1% slippage tolerance
        );

        console.log("USDC received:", usdcReceived / 1e6);

        vm.stopBroadcast();

        console.log("\nSwaps completed successfully!");
    }
}

