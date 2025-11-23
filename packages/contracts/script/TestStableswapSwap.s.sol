// SPDX-License-Identifier: LicenseRef-Degensoft-Aqua-Source-1.1
pragma solidity 0.8.30;

import "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Aqua} from "aqua/Aqua.sol";
import {StableswapAMM, IStableswapCallback} from "../src/StableswapAMM.sol";

/// @title StableSwapper
/// @notice Helper contract to execute stableswap swaps with callback
contract StableSwapper is IStableswapCallback {
    Aqua public immutable aqua;

    constructor(Aqua aqua_) {
        aqua = aqua_;
    }

    function stableswapCallback(
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
        StableswapAMM strategy,
        StableswapAMM.Strategy memory strategyParams,
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

/// @title TestStableswapSwap
/// @notice Tests swapping on Stableswap strategy
contract TestStableswapSwap is Script {
    function run() external {
        uint256 traderPrivateKey = vm.envUint("DEPLOYER_KEY");
        address trader = vm.addr(traderPrivateKey);

        // Load deployed addresses
        address aquaAddr = vm.envAddress("AQUA");
        address stableswapAddr = vm.envAddress("STABLESWAP");
        address usdcAddr = vm.envAddress("USDC");
        address usdtAddr = vm.envAddress("USDT");
        address makerAddr = vm.envAddress("MAKER");

        console.log("Testing Stableswap swap...");
        console.log("Trader:", trader);

        Aqua aqua = Aqua(aquaAddr);
        StableswapAMM stableswap = StableswapAMM(stableswapAddr);
        IERC20 usdc = IERC20(usdcAddr);
        IERC20 usdt = IERC20(usdtAddr);

        vm.startBroadcast(traderPrivateKey);

        // Deploy swapper helper
        StableSwapper swapper = new StableSwapper(aqua);
        console.log("Swapper deployed at:", address(swapper));

        // Recreate strategy params
        StableswapAMM.Strategy memory strategy = StableswapAMM.Strategy({
            maker: makerAddr,
            token0: usdcAddr,
            token1: usdtAddr,
            feeBps: 4,
            amplificationFactor: 100,
            salt: bytes32(0)
        });

        // Test 1: Swap USDC for USDT
        console.log("\n=== Test 1: Swap 1000 USDC for USDT ===");
        uint256 usdcAmount = 1000e6;

        // Get quote
        uint256 expectedUSDT = stableswap.quoteExactIn(
            strategy,
            true,
            usdcAmount
        );
        console.log("Expected USDT output:", expectedUSDT / 1e6);

        // Check balances before
        uint256 usdcBefore = usdc.balanceOf(trader);
        uint256 usdtBefore = usdt.balanceOf(trader);
        console.log("USDC balance before:", usdcBefore / 1e6);
        console.log("USDT balance before:", usdtBefore / 1e6);

        // Approve and execute swap
        usdc.approve(address(swapper), usdcAmount);
        uint256 usdtReceived = swapper.executeSwap(
            stableswap,
            strategy,
            true,
            usdcAmount,
            (expectedUSDT * 99) / 100 // 1% slippage tolerance
        );

        // Check balances after
        uint256 usdcAfter = usdc.balanceOf(trader);
        uint256 usdtAfter = usdt.balanceOf(trader);
        console.log("USDC balance after:", usdcAfter / 1e6);
        console.log("USDT balance after:", usdtAfter / 1e6);
        console.log("USDT received:", usdtReceived / 1e6);

        // Calculate slippage
        uint256 slippage = usdcAmount > usdtReceived
            ? usdcAmount - usdtReceived
            : usdtReceived - usdcAmount;
        uint256 slippageBps = (slippage * 10000) / usdcAmount;
        console.log("Slippage:", slippageBps, "bps");

        // Test 2: Swap USDT for USDC
        console.log("\n=== Test 2: Swap 500 USDT for USDC ===");
        uint256 usdtAmount = 500e6;

        // Get quote
        uint256 expectedUSDC = stableswap.quoteExactIn(
            strategy,
            false,
            usdtAmount
        );
        console.log("Expected USDC output:", expectedUSDC / 1e6);

        // Approve and execute swap
        usdt.approve(address(swapper), usdtAmount);
        uint256 usdcReceived = swapper.executeSwap(
            stableswap,
            strategy,
            false,
            usdtAmount,
            (expectedUSDC * 99) / 100 // 1% slippage tolerance
        );

        console.log("USDC received:", usdcReceived / 1e6);

        // Test 3: Large swap to test slippage
        console.log("\n=== Test 3: Large swap - 10,000 USDC for USDT ===");
        uint256 largeAmount = 10_000e6;

        uint256 largeExpectedUSDT = stableswap.quoteExactIn(
            strategy,
            true,
            largeAmount
        );
        console.log("Expected USDT output:", largeExpectedUSDT / 1e6);

        usdc.approve(address(swapper), largeAmount);
        uint256 largeUSDTReceived = swapper.executeSwap(
            stableswap,
            strategy,
            true,
            largeAmount,
            (largeExpectedUSDT * 99) / 100
        );

        console.log("USDT received:", largeUSDTReceived / 1e6);

        uint256 largeSlippage = largeAmount > largeUSDTReceived
            ? largeAmount - largeUSDTReceived
            : largeUSDTReceived - largeAmount;
        uint256 largeSlippageBps = (largeSlippage * 10000) / largeAmount;
        console.log("Large trade slippage:", largeSlippageBps, "bps");

        vm.stopBroadcast();

        console.log("\nStableswap tests completed successfully!");
        console.log(
            "Note: Stableswap should have minimal slippage for stable pairs"
        );
    }
}

