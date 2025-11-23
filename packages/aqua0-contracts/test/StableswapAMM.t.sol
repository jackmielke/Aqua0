// SPDX-License-Identifier: LicenseRef-Degensoft-Aqua-Source-1.1
pragma solidity ^0.8.13;

/// @custom:license-url https://github.com/1inch/aqua/blob/main/LICENSES/Aqua-Source-1.1.txt
/// @custom:copyright © 2025 Degensoft Ltd

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {IAqua} from "aqua/interfaces/IAqua.sol";
import {Aqua} from "aqua/Aqua.sol";
import {StableswapAMM, IStableswapCallback} from "../src/StableswapAMM.sol";

// Mock ERC20 token for testing
contract MockERC20 is ERC20 {
    uint8 private _decimals;

    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals_
    ) ERC20(name, symbol) {
        _decimals = decimals_;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

// Simple callback implementation for testing
contract TestCallback is IStableswapCallback {
    IAqua public aqua;

    constructor(IAqua aqua_) {
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
        IERC20(tokenIn).approve(address(aqua), amountIn);
        aqua.push(maker, app, strategyHash, tokenIn, amountIn);
    }
}

contract StableswapAMMTest is Test {
    Aqua public aqua;
    StableswapAMM public stableswap;
    TestCallback public callback;
    MockERC20 public usdc;
    MockERC20 public usdt;

    address public maker = address(0x1);
    address public taker = address(0x2);

    uint256 constant INITIAL_USDC = 100_000e6; // 100k USDC (6 decimals)
    uint256 constant INITIAL_USDT = 100_000e6; // 100k USDT (6 decimals)
    uint24 constant FEE_BPS = 4; // 0.04% fee (typical for stableswaps)

    function setUp() public {
        // Deploy contracts
        aqua = new Aqua();
        stableswap = new StableswapAMM(aqua);
        callback = new TestCallback(aqua);

        // Deploy mock stablecoins (both with 6 decimals)
        usdc = new MockERC20("USD Coin", "USDC", 6);
        usdt = new MockERC20("Tether USD", "USDT", 6);

        // Mint tokens
        usdc.mint(maker, INITIAL_USDC);
        usdt.mint(maker, INITIAL_USDT);
        usdc.mint(taker, 10_000e6);
        usdt.mint(taker, 10_000e6);

        // Setup approvals
        vm.prank(maker);
        usdc.approve(address(aqua), type(uint256).max);

        vm.prank(maker);
        usdt.approve(address(aqua), type(uint256).max);

        vm.prank(taker);
        usdc.approve(address(callback), type(uint256).max);

        vm.prank(taker);
        usdt.approve(address(callback), type(uint256).max);
    }

    /// @notice Creates a high amplification strategy optimized for stable pairs
    /// @dev High A factor (100) makes the curve behave more like constant sum (minimal slippage)
    function createHighAmpStrategy()
        internal
        returns (StableswapAMM.Strategy memory strategy)
    {
        strategy = StableswapAMM.Strategy({
            maker: maker,
            token0: address(usdc),
            token1: address(usdt),
            feeBps: FEE_BPS,
            amplificationFactor: 100, // High amplification for stable pairs
            salt: bytes32(0)
        });

        vm.prank(maker);
        aqua.ship(
            address(stableswap),
            abi.encode(strategy),
            _toArray(address(usdc), address(usdt)),
            _toUintArray(INITIAL_USDC, INITIAL_USDT)
        );
    }

    /// @notice Creates a low amplification strategy that behaves more like constant product
    /// @dev Low A factor (1) makes the curve behave more like traditional AMM
    function createLowAmpStrategy()
        internal
        returns (StableswapAMM.Strategy memory strategy)
    {
        strategy = StableswapAMM.Strategy({
            maker: maker,
            token0: address(usdc),
            token1: address(usdt),
            feeBps: FEE_BPS,
            amplificationFactor: 1, // Low amplification (more like constant product)
            salt: bytes32(uint256(1))
        });

        // Mint additional tokens for second strategy
        usdc.mint(maker, INITIAL_USDC);
        usdt.mint(maker, INITIAL_USDT);

        vm.prank(maker);
        aqua.ship(
            address(stableswap),
            abi.encode(strategy),
            _toArray(address(usdc), address(usdt)),
            _toUintArray(INITIAL_USDC, INITIAL_USDT)
        );
    }

    function swap(
        StableswapAMM.Strategy memory strategy,
        bool zeroForOne,
        uint256 amountIn
    ) internal returns (uint256) {
        address tokenIn = zeroForOne ? strategy.token0 : strategy.token1;
        vm.prank(taker);
        MockERC20(tokenIn).transfer(address(callback), amountIn);

        bytes memory takerData = abi.encode(zeroForOne);
        vm.prank(address(callback));
        return
            stableswap.swapExactIn(
                strategy,
                zeroForOne,
                amountIn,
                0,
                address(callback),
                takerData
            );
    }

    // ========== Basic Functionality Tests ==========

    /// @notice Tests basic USDC to USDT swap in a stableswap pool
    /// @dev Verifies that swaps execute correctly with minimal slippage for stable pairs
    function testSwapUSDCForUSDT() public {
        StableswapAMM.Strategy memory strategy = createHighAmpStrategy();

        uint256 amountIn = 1000e6; // 1000 USDC
        vm.prank(taker);
        usdc.transfer(address(callback), amountIn);

        uint256 initialUSDTBalance = usdt.balanceOf(address(callback));

        bytes memory takerData = abi.encode(true);
        vm.prank(address(callback));
        uint256 amountOut = stableswap.swapExactIn(
            strategy,
            true, // USDC -> USDT
            amountIn,
            0,
            address(callback),
            takerData
        );

        assertGt(amountOut, 0, "Should receive USDT");
        assertEq(
            usdt.balanceOf(address(callback)),
            initialUSDTBalance + amountOut,
            "Should receive USDT tokens"
        );

        // For stableswap with high A, output should be very close to input (minimal slippage)
        uint256 slippage = amountIn > amountOut
            ? amountIn - amountOut
            : amountOut - amountIn;
        uint256 slippageBps = (slippage * 10000) / amountIn;

        console2.log("Swapped 1000 USDC for", amountOut / 1e6, "USDT");
        console2.log("Slippage:", slippageBps, "bps");

        // Slippage should be very low for stableswap
        assertLt(
            slippageBps,
            100,
            "Slippage should be less than 1% for stable pairs"
        );
    }

    /// @notice Tests that high amplification provides better prices than low amplification
    /// @dev Compares slippage between high A and low A strategies
    function testHighAmpHasLessSlippage() public {
        StableswapAMM.Strategy memory highAmpStrategy = createHighAmpStrategy();
        StableswapAMM.Strategy memory lowAmpStrategy = createLowAmpStrategy();

        uint256 amountIn = 1000e6;

        // Swap with high amplification
        uint256 highAmpOut = swap(highAmpStrategy, true, amountIn);

        // Swap with low amplification
        uint256 lowAmpOut = swap(lowAmpStrategy, true, amountIn);

        // High amplification should give better output (closer to 1:1)
        assertGt(
            highAmpOut,
            lowAmpOut,
            "High amplification should have less slippage"
        );

        uint256 highAmpSlippage = amountIn - highAmpOut;
        uint256 lowAmpSlippage = amountIn - lowAmpOut;

        console2.log("High amp output:", highAmpOut / 1e6, "USDT");
        console2.log("Low amp output:", lowAmpOut / 1e6, "USDT");
        console2.log("High amp slippage:", highAmpSlippage);
        console2.log("Low amp slippage:", lowAmpSlippage);
    }

    /// @notice Tests bidirectional swaps (round trip)
    /// @dev Verifies that swapping back and forth incurs expected fees
    function testBidirectionalSwaps() public {
        StableswapAMM.Strategy memory strategy = createHighAmpStrategy();

        uint256 initialUSDC = 1000e6;
        uint256 usdtOut = swap(strategy, true, initialUSDC);
        uint256 usdcOut = swap(strategy, false, usdtOut);

        assertTrue(
            usdcOut < initialUSDC,
            "Should get back less USDC due to fees"
        );

        console2.log("Round trip usdtOut:", usdtOut / 1e6);
        console2.log("Round trip usdcOut:", usdcOut / 1e6);
        console2.log("Fee cost:", (initialUSDC - usdcOut) / 1e6);
    }

    // ========== Slippage Tests ==========

    /// @notice Tests that large trades have acceptable slippage in stableswap
    /// @dev Verifies that even large swaps maintain low slippage with high amplification
    function testLargeTradeSlippage() public {
        StableswapAMM.Strategy memory strategy = createHighAmpStrategy();

        uint256 largeAmount = 10_000e6; // 10k USDC (10% of pool)
        uint256 output = swap(strategy, true, largeAmount);

        // Calculate slippage
        uint256 slippage = largeAmount - output;
        uint256 slippageBps = (slippage * 10000) / largeAmount;

        console2.log("Large trade output:", output / 1e6, "USDT");
        console2.log("Large trade slippage:", slippageBps, "bps");

        // Even large trades should have reasonable slippage with stableswap
        assertLt(
            slippageBps,
            500,
            "Large trade slippage should be less than 5%"
        );
    }

    /// @notice Tests that small trades have minimal slippage
    /// @dev Verifies that small swaps are nearly 1:1 in stableswap
    function testSmallTradeMinimalSlippage() public {
        StableswapAMM.Strategy memory strategy = createHighAmpStrategy();

        uint256 smallAmount = 100e6; // 100 USDC
        uint256 output = swap(strategy, true, smallAmount);

        // Calculate slippage
        uint256 slippage = smallAmount > output
            ? smallAmount - output
            : output - smallAmount;
        uint256 slippageBps = (slippage * 10000) / smallAmount;

        console2.log("Small trade output:", output / 1e6, "USDT");
        console2.log("Small trade slippage:", slippageBps, "bps");

        // Small trades should have very minimal slippage
        assertLt(
            slippageBps,
            50,
            "Small trade slippage should be less than 0.5%"
        );
    }

    // ========== Sequential Swap Tests ==========

    /// @notice Tests that sequential swaps in the same direction increase slippage
    /// @dev Verifies that depleting one side of the pool increases price impact
    function testSequentialSwapsIncreaseSlippage() public {
        StableswapAMM.Strategy memory strategy = createHighAmpStrategy();

        uint256 amountIn = 1000e6;

        uint256 out1 = swap(strategy, true, amountIn);
        uint256 out2 = swap(strategy, true, amountIn);
        uint256 out3 = swap(strategy, true, amountIn);

        // Each swap should get progressively worse output
        assertTrue(out1 > out2, "Second swap should have more slippage");
        assertTrue(out2 > out3, "Third swap should have even more slippage");

        console2.log("Swap 1 output:", out1 / 1e6);
        console2.log("Swap 2 output:", out2 / 1e6);
        console2.log("Swap 3 output:", out3 / 1e6);
    }

    // ========== Invariant Tests ==========

    /// @notice Tests that total value is conserved across swaps
    /// @dev Verifies no tokens are created or destroyed during trading
    function testNoValueLeakage() public {
        StableswapAMM.Strategy memory strategy = createHighAmpStrategy();
        bytes32 strategyHash = keccak256(abi.encode(strategy));

        // Track initial total value
        (uint256 initialTotalUSDC, ) = aqua.rawBalances(
            maker,
            address(stableswap),
            strategyHash,
            address(usdc)
        );
        initialTotalUSDC +=
            usdc.balanceOf(address(callback)) +
            usdc.balanceOf(taker);
        (uint256 initialTotalUSDT, ) = aqua.rawBalances(
            maker,
            address(stableswap),
            strategyHash,
            address(usdt)
        );
        initialTotalUSDT +=
            usdt.balanceOf(address(callback)) +
            usdt.balanceOf(taker);

        // Perform multiple swaps
        swap(strategy, true, 1000e6);
        swap(strategy, false, 500e6);
        swap(strategy, true, 1500e6);

        // Track final total value
        (uint256 finalTotalUSDC, ) = aqua.rawBalances(
            maker,
            address(stableswap),
            strategyHash,
            address(usdc)
        );
        finalTotalUSDC +=
            usdc.balanceOf(address(callback)) +
            usdc.balanceOf(taker);
        (uint256 finalTotalUSDT, ) = aqua.rawBalances(
            maker,
            address(stableswap),
            strategyHash,
            address(usdt)
        );
        finalTotalUSDT +=
            usdt.balanceOf(address(callback)) +
            usdt.balanceOf(taker);

        // Total tokens should be conserved
        assertEq(
            finalTotalUSDC,
            initialTotalUSDC,
            "Total USDC should be conserved"
        );
        assertEq(
            finalTotalUSDT,
            initialTotalUSDT,
            "Total USDT should be conserved"
        );
    }

    /// @notice Tests that quote matches actual swap output
    /// @dev Verifies that the quote function accurately predicts swap results
    function testQuoteMatchesSwap() public {
        StableswapAMM.Strategy memory strategy = createHighAmpStrategy();

        uint256 amountIn = 1000e6;

        // Get quote
        uint256 quotedOut = stableswap.quoteExactIn(strategy, true, amountIn);

        // Perform actual swap
        uint256 actualOut = swap(strategy, true, amountIn);

        assertEq(actualOut, quotedOut, "Actual output should match quote");
    }

    // ========== Edge Case Tests ==========

    /// @notice Tests zero amount swaps
    /// @dev Should handle gracefully without breaking pool state
    function testZeroAmountSwap() public {
        StableswapAMM.Strategy memory strategy = createHighAmpStrategy();

        uint256 amountOut = swap(strategy, true, 0);
        assertEq(amountOut, 0, "Zero input should give zero output");
    }

    /// @notice Tests minimum output protection
    /// @dev Verifies InsufficientOutputAmount error is thrown correctly
    function testMinimumOutputProtection() public {
        StableswapAMM.Strategy memory strategy = createHighAmpStrategy();

        uint256 amountIn = 1000e6;
        uint256 expectedOut = stableswap.quoteExactIn(strategy, true, amountIn);

        vm.prank(taker);
        usdc.transfer(address(callback), amountIn);

        bytes memory takerData = abi.encode(true);
        vm.prank(address(callback));

        // Should revert if minimum output is too high
        vm.expectRevert(
            abi.encodeWithSelector(
                StableswapAMM.InsufficientOutputAmount.selector,
                expectedOut,
                expectedOut + 1
            )
        );
        stableswap.swapExactIn(
            strategy,
            true,
            amountIn,
            expectedOut + 1,
            address(callback),
            takerData
        );
    }

    /// @notice Tests maximum input protection for swapExactOut
    /// @dev Verifies ExcessiveInputAmount error is thrown correctly
    function testMaximumInputProtection() public {
        StableswapAMM.Strategy memory strategy = createHighAmpStrategy();

        uint256 amountOut = 1000e6;
        uint256 expectedIn = stableswap.quoteExactOut(
            strategy,
            true,
            amountOut
        );

        vm.prank(taker);
        usdc.transfer(address(callback), expectedIn);

        bytes memory takerData = abi.encode(true);
        vm.prank(address(callback));

        // Should revert if maximum input is too low
        vm.expectRevert(
            abi.encodeWithSelector(
                StableswapAMM.ExcessiveInputAmount.selector,
                expectedIn,
                expectedIn - 1
            )
        );
        stableswap.swapExactOut(
            strategy,
            true,
            amountOut,
            expectedIn - 1,
            address(callback),
            takerData
        );
    }

    /// @notice Tests very small swap amounts
    /// @dev Ensures rounding doesn't break with tiny amounts
    function testVerySmallSwapAmounts() public {
        StableswapAMM.Strategy memory strategy = createHighAmpStrategy();

        uint256 tinyAmount = 1; // 1 unit
        uint256 output = swap(strategy, true, tinyAmount);

        // Should not revert, output might be 0 due to rounding
        assertGe(output, 0, "Tiny swap should not revert");
    }

    /// @notice Tests extreme amplification factor (very high)
    /// @dev High A should behave like constant sum
    function testExtremeHighAmplification() public {
        StableswapAMM.Strategy memory extremeStrategy = StableswapAMM.Strategy({
            maker: maker,
            token0: address(usdc),
            token1: address(usdt),
            feeBps: FEE_BPS,
            amplificationFactor: 10000, // Extremely high A
            salt: bytes32(uint256(99))
        });

        usdc.mint(maker, INITIAL_USDC);
        usdt.mint(maker, INITIAL_USDT);

        vm.prank(maker);
        aqua.ship(
            address(stableswap),
            abi.encode(extremeStrategy),
            _toArray(address(usdc), address(usdt)),
            _toUintArray(INITIAL_USDC, INITIAL_USDT)
        );

        uint256 amountIn = 1000e6;
        uint256 output = swap(extremeStrategy, true, amountIn);

        // With very high A, output should be very close to input (minus fees)
        uint256 expectedOut = (amountIn * (10000 - FEE_BPS)) / 10000;
        assertApproxEqAbs(
            output,
            expectedOut,
            100e6,
            "High A should behave like constant sum"
        );
    }

    /// @notice Tests imbalanced pool scenario
    /// @dev When one side is nearly depleted, slippage should increase significantly
    function testImbalancedPool() public {
        StableswapAMM.Strategy memory strategy = createHighAmpStrategy();

        // Deplete USDT side with smaller swaps to avoid running out of taker funds
        for (uint256 i = 0; i < 5; i++) {
            swap(strategy, true, 1000e6);
        }

        // Now try another swap - should have higher slippage than initial
        uint256 amountIn = 500e6;
        uint256 output = swap(strategy, true, amountIn);

        // Output should be less than input due to imbalance and fees
        assertLt(output, amountIn, "Imbalanced pool should have slippage");

        console2.log("Imbalanced pool output:", output / 1e6, "USDT");
        console2.log("Slippage:", ((amountIn - output) * 100) / amountIn, "%");
    }

    /// @notice Tests attempting to drain pool completely
    /// @dev Should handle gracefully without breaking
    function testCannotDrainPoolCompletely() public {
        StableswapAMM.Strategy memory strategy = createHighAmpStrategy();

        // Try to swap for more than pool has
        uint256 hugeAmount = 200_000e6; // More than pool balance
        usdc.mint(taker, hugeAmount);

        vm.prank(taker);
        usdc.transfer(address(callback), hugeAmount);

        bytes memory takerData = abi.encode(true);
        vm.prank(address(callback));

        // Should succeed but output will be limited by balance
        uint256 output = stableswap.swapExactIn(
            strategy,
            true,
            hugeAmount,
            0,
            address(callback),
            takerData
        );

        // Output should be less than initial pool balance (can't drain completely)
        assertLt(output, INITIAL_USDT, "Cannot drain pool completely");
    }

    // ========== Helper Functions ==========

    function _toArray(
        address a,
        address b
    ) internal pure returns (address[] memory) {
        address[] memory arr = new address[](2);
        arr[0] = a;
        arr[1] = b;
        return arr;
    }

    function _toUintArray(
        uint256 a,
        uint256 b
    ) internal pure returns (uint256[] memory) {
        uint256[] memory arr = new uint256[](2);
        arr[0] = a;
        arr[1] = b;
        return arr;
    }
}
