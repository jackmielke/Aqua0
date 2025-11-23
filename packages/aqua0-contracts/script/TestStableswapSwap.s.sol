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
/// @dev Uses SWAPPER_PRIVATE_KEY (separate from LP)
contract TestStableswapSwap is Script {
    function run() external {
        // Use swapper private key (not LP or deployer)
        uint256 swapperPrivateKey = vm.envUint("SWAPPER_PRIVATE_KEY");
        address swapper = vm.addr(swapperPrivateKey);

        // Load deployed addresses
        address aquaAddr = vm.envAddress("AQUA_ROUTER");
        address stableswapAddr = vm.envAddress("STABLESWAP");
        address usdcAddr = vm.envAddress("USDC");
        address usdtAddr = vm.envAddress("USDT");
        address makerAddr = vm.envAddress("MAKER");

        console.log("=================================================");
        console.log("Testing Stableswap Swap (Mainnet)");
        console.log("=================================================");
        console.log("Swapper:", swapper);
        console.log("Maker (LP):", makerAddr);

        Aqua aqua = Aqua(aquaAddr);
        StableswapAMM stableswap = StableswapAMM(stableswapAddr);
        IERC20 usdc = IERC20(usdcAddr);
        IERC20 usdt = IERC20(usdtAddr);

        // Check swapper balances
        uint256 usdcBalanceBefore = usdc.balanceOf(swapper);
        uint256 usdtBalanceBefore = usdt.balanceOf(swapper);
        console.log("\nSwapper Balances Before:");
        console.log("USDC:", usdcBalanceBefore / 1e6, "USDC");
        console.log("USDT:", usdtBalanceBefore / 1e6, "USDT");

        // Swap amount (default 1 USDC for USDT)
        uint256 swapAmount = vm.envOr("SWAP_AMOUNT", uint256(1e6));
        require(
            usdcBalanceBefore >= swapAmount,
            "Insufficient USDC balance for swap"
        );

        console.log("\nSwapping", swapAmount / 1e6, "USDC for USDT...");

        vm.startBroadcast(swapperPrivateKey);

        // Deploy swapper helper
        StableSwapper swapperHelper = new StableSwapper(aqua);
        console.log("Swapper helper deployed at:", address(swapperHelper));

        // Recreate strategy params (must match the setup script)
        StableswapAMM.Strategy memory strategy = StableswapAMM.Strategy({
            maker: makerAddr,
            token0: usdcAddr,
            token1: usdtAddr,
            feeBps: 4,
            amplificationFactor: 100,
            salt: bytes32(0) // Note: If setup used different salt, need to match it
        });

        // Test: Swap USDC for USDT
        console.log("\n=== Executing Swap ===");

        // Get quote
        uint256 expectedUSDT = stableswap.quoteExactIn(
            strategy,
            true,
            swapAmount
        );
        console.log("Expected USDT output:", expectedUSDT / 1e6, "USDT");
        console.log("Estimated fee:", (swapAmount * 4) / 10000 / 1e6, "USDC");

        // Approve and execute swap
        usdc.approve(address(swapperHelper), swapAmount);
        uint256 usdtReceived = swapperHelper.executeSwap(
            stableswap,
            strategy,
            true,
            swapAmount,
            (expectedUSDT * 99) / 100 // 1% slippage tolerance
        );

        // Check balances after
        uint256 usdcBalanceAfter = usdc.balanceOf(swapper);
        uint256 usdtBalanceAfter = usdt.balanceOf(swapper);

        console.log("\n=================================================");
        console.log("Swap Successful!");
        console.log("=================================================");
        console.log("Swapper Balances After:");
        console.log("  USDC:", usdcBalanceAfter / 1e6, "USDC");
        console.log("  USDT:", usdtBalanceAfter / 1e6, "USDT");
        console.log("\nSwap Details:");
        console.log("  Input:", swapAmount / 1e6, "USDC");
        console.log("  Output:", usdtReceived / 1e6, "USDT");

        // Calculate effective rate
        uint256 rate = (usdtReceived * 1e6) / swapAmount;
        console.log("  Rate:", rate, "/ 1e6 (USDT per USDC)");
        console.log("=================================================");

        vm.stopBroadcast();
    }
}
