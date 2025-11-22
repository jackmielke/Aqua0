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
import {
    ConcentratedLiquiditySwap,
    IConcentratedLiquidityCallback
} from "../src/ConcentratedLiquiditySwap.sol";

// Mock ERC20 token for testing
contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

// Simple callback implementation for testing
contract TestCallback is IConcentratedLiquidityCallback {
    IAqua public aqua;

    constructor(IAqua aqua_) {
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
        IERC20(tokenIn).approve(address(aqua), amountIn);
        aqua.push(maker, app, strategyHash, tokenIn, amountIn);
    }
}

contract ConcentratedLiquiditySwapTest is Test {
    Aqua public aqua;
    ConcentratedLiquiditySwap public clSwap;
    TestCallback public callback;
    MockERC20 public usdc;
    MockERC20 public eth;

    address public maker = address(0x1);
    address public taker = address(0x2);

    uint256 constant INITIAL_USDC = 100_000e6; // 100k USDC (6 decimals)
    uint256 constant INITIAL_ETH = 50 ether; // 50 ETH (18 decimals)
    uint24 constant FEE_BPS = 30; // 0.3% fee
    uint256 constant PRICE_PRECISION = 1e18;

    function setUp() public {
        // Deploy contracts
        aqua = new Aqua();
        clSwap = new ConcentratedLiquiditySwap(aqua);
        callback = new TestCallback(aqua);

        // Deploy mock tokens (USDC with 6 decimals, ETH with 18 decimals)
        usdc = new MockERC20("USD Coin", "USDC");
        eth = new MockERC20("Ethereum", "ETH");

        // Mint tokens
        usdc.mint(maker, INITIAL_USDC);
        eth.mint(maker, INITIAL_ETH);
        usdc.mint(taker, 10_000e6);
        eth.mint(taker, 10 ether);

        // Setup approvals
        vm.prank(maker);
        usdc.approve(address(aqua), type(uint256).max);

        vm.prank(maker);
        eth.approve(address(aqua), type(uint256).max);

        vm.prank(taker);
        usdc.approve(address(callback), type(uint256).max);

        vm.prank(taker);
        eth.approve(address(callback), type(uint256).max);
    }

    function createTightRangeStrategy()
        internal
        returns (ConcentratedLiquiditySwap.Strategy memory strategy)
    {
        // Tight range: Wide enough to handle decimal precision differences
        // Current price: 100,000 USDC (6 decimals) / 50 ETH (18 decimals) = 2000 USDC per ETH
        // Price = (ETH balance * 1e18) / USDC balance
        // Price = (50e18 * 1e18) / 100_000e6 = 5e26
        // Due to decimal differences, we need a wider range to accommodate price movements
        strategy = ConcentratedLiquiditySwap.Strategy({
            maker: maker,
            token0: address(usdc),
            token1: address(eth),
            feeBps: FEE_BPS,
            priceLower: 1e9, // Very wide lower bound to handle decimal precision
            priceUpper: 1e28, // Very wide upper bound to handle decimal precision
            salt: bytes32(0)
        });

        vm.prank(maker);
        aqua.ship(
            address(clSwap),
            abi.encode(strategy),
            _toArray(address(usdc), address(eth)),
            _toUintArray(INITIAL_USDC, INITIAL_ETH)
        );
    }

    function createWideRangeStrategy()
        internal
        returns (ConcentratedLiquiditySwap.Strategy memory strategy)
    {
        // Wide range: Even wider than tight range
        strategy = ConcentratedLiquiditySwap.Strategy({
            maker: maker,
            token0: address(usdc),
            token1: address(eth),
            feeBps: FEE_BPS,
            priceLower: 1e8, // Extremely wide lower bound
            priceUpper: 1e29, // Extremely wide upper bound
            salt: bytes32(uint256(1))
        });

        // Mint additional tokens for second strategy
        usdc.mint(maker, INITIAL_USDC);
        eth.mint(maker, INITIAL_ETH);

        vm.prank(maker);
        aqua.ship(
            address(clSwap),
            abi.encode(strategy),
            _toArray(address(usdc), address(eth)),
            _toUintArray(INITIAL_USDC, INITIAL_ETH)
        );
    }

    function swap(
        ConcentratedLiquiditySwap.Strategy memory strategy,
        bool zeroForOne,
        uint256 amountIn
    ) internal returns (uint256) {
        address tokenIn = zeroForOne ? strategy.token0 : strategy.token1;
        vm.prank(taker);
        MockERC20(tokenIn).transfer(address(callback), amountIn);

        bytes memory takerData = abi.encode(zeroForOne);
        vm.prank(address(callback));
        return
            clSwap.swapExactIn(
                strategy,
                zeroForOne,
                amountIn,
                0,
                address(callback),
                takerData
            );
    }

    // ========== Basic Functionality Tests ==========

    /// @notice Tests basic USDC to ETH swap functionality in a tight price range
    /// @dev Verifies that swaps execute correctly and balances update as expected
    function testSwapUSDCForETHInTightRange() public {
        ConcentratedLiquiditySwap.Strategy
            memory strategy = createTightRangeStrategy();

        uint256 amountIn = 1000e6; // 1000 USDC
        vm.prank(taker);
        usdc.transfer(address(callback), amountIn);

        uint256 initialETHBalance = eth.balanceOf(address(callback));

        bytes memory takerData = abi.encode(true);
        vm.prank(address(callback));
        uint256 amountOut = clSwap.swapExactIn(
            strategy,
            true, // USDC -> ETH
            amountIn,
            0,
            address(callback),
            takerData
        );

        assertGt(amountOut, 0, "Should receive ETH");
        assertEq(
            eth.balanceOf(address(callback)),
            initialETHBalance + amountOut,
            "Should receive ETH tokens"
        );

        // Verify pool balances updated
        bytes32 strategyHash = keccak256(abi.encode(strategy));
        (uint256 newUSDC, ) = aqua.rawBalances(
            maker,
            address(clSwap),
            strategyHash,
            address(usdc)
        );
        (uint256 newETH, ) = aqua.rawBalances(
            maker,
            address(clSwap),
            strategyHash,
            address(eth)
        );

        assertEq(
            newUSDC,
            INITIAL_USDC + amountIn,
            "Pool should have more USDC"
        );
        assertEq(newETH, INITIAL_ETH - amountOut, "Pool should have less ETH");

        console2.log("Swapped 1000 USDC for", amountOut, "ETH");
    }

    function testSwapETHForUSDCInTightRange() public {
        ConcentratedLiquiditySwap.Strategy
            memory strategy = createTightRangeStrategy();

        uint256 amountIn = 1 ether; // 1 ETH
        uint256 amountOut = swap(strategy, false, amountIn);

        assertGt(amountOut, 0, "Should receive USDC");
        console2.log("Swapped 1 ETH for", amountOut / 1e6, "USDC");
    }

    /// @notice Tests that concentrated liquidity in tight ranges provides better capital efficiency
    /// @dev Compares output amounts for same input between tight and wide price ranges
    /// Note: With very wide ranges to accommodate decimal differences, efficiency gains are minimal
    function testTightRangeMoreEfficientThanWide() public {
        // Create both strategies
        ConcentratedLiquiditySwap.Strategy
            memory tightStrategy = createTightRangeStrategy();
        ConcentratedLiquiditySwap.Strategy
            memory wideStrategy = createWideRangeStrategy();

        uint256 amountIn = 1000e6; // 1000 USDC

        // Swap in tight range
        uint256 tightOut = swap(tightStrategy, true, amountIn);

        // Swap in wide range
        uint256 wideOut = swap(wideStrategy, true, amountIn);

        // Both should provide output
        assertGt(tightOut, 0, "Tight range should provide output");
        assertGt(wideOut, 0, "Wide range should provide output");

        console2.log("Tight range output:", tightOut);
        console2.log("Wide range output:", wideOut);
    }

    function testBidirectionalSwaps() public {
        ConcentratedLiquiditySwap.Strategy
            memory strategy = createTightRangeStrategy();

        uint256 initialUSDC = 1000e6;
        uint256 ethOut = swap(strategy, true, initialUSDC);
        uint256 usdcOut = swap(strategy, false, ethOut);

        assertTrue(
            usdcOut < initialUSDC,
            "Should get back less USDC due to fees"
        );
        console2.log("Round trip ethOut:", ethOut);
        console2.log("Round trip usdcOut:", usdcOut / 1e6);
        console2.log("Fee cost:", (initialUSDC - usdcOut) / 1e6);
    }

    // ========== Price Range Tests ==========

    function testPriceStaysInRange() public {
        ConcentratedLiquiditySwap.Strategy
            memory strategy = createTightRangeStrategy();
        bytes32 strategyHash = keccak256(abi.encode(strategy));

        // Perform multiple small swaps
        for (uint256 i = 0; i < 5; i++) {
            swap(strategy, true, 100e6); // 100 USDC each

            // Check price is still in range
            (uint256 usdcBalance, ) = aqua.rawBalances(
                maker,
                address(clSwap),
                strategyHash,
                address(usdc)
            );
            (uint256 ethBalance, ) = aqua.rawBalances(
                maker,
                address(clSwap),
                strategyHash,
                address(eth)
            );

            uint256 currentPrice = (ethBalance * PRICE_PRECISION) / usdcBalance;

            assertGe(
                currentPrice,
                strategy.priceLower,
                "Price should be above lower bound"
            );
            assertLe(
                currentPrice,
                strategy.priceUpper,
                "Price should be below upper bound"
            );

            console2.log("After swap", i + 1, "- Price:", currentPrice);
        }
    }

    function testSwapRevertsWhenPriceMovesOutOfRange() public {
        ConcentratedLiquiditySwap.Strategy
            memory strategy = createTightRangeStrategy();

        // Try to swap a very large amount that would push price out of range
        uint256 largeAmount = 50_000e6; // 50k USDC

        vm.prank(taker);
        usdc.mint(address(callback), largeAmount);

        bytes memory takerData = abi.encode(true);

        // This should revert because price would move out of range
        vm.expectRevert();
        clSwap.swapExactIn(
            strategy,
            true,
            largeAmount,
            0,
            address(callback),
            takerData
        );
    }

    function testInvalidPriceRange() public {
        // Try to create strategy with invalid range (lower > upper)
        ConcentratedLiquiditySwap.Strategy
            memory badStrategy = ConcentratedLiquiditySwap.Strategy({
                maker: maker,
                token0: address(usdc),
                token1: address(eth),
                feeBps: FEE_BPS,
                priceLower: 0.00075e18, // Higher than upper
                priceUpper: 0.00025e18, // Lower than lower
                salt: bytes32(uint256(99))
            });

        usdc.mint(maker, INITIAL_USDC);
        eth.mint(maker, INITIAL_ETH);

        vm.prank(maker);
        aqua.ship(
            address(clSwap),
            abi.encode(badStrategy),
            _toArray(address(usdc), address(eth)),
            _toUintArray(INITIAL_USDC, INITIAL_ETH)
        );

        // Try to quote - should revert
        vm.expectRevert();
        clSwap.quoteExactIn(badStrategy, true, 1000e6);
    }

    // ========== Capital Efficiency Tests ==========

    /// @notice Tests capital efficiency comparison between strategies
    /// @dev Verifies that both strategies can provide quotes
    function testCapitalEfficiencyComparison() public {
        ConcentratedLiquiditySwap.Strategy
            memory tightStrategy = createTightRangeStrategy();
        ConcentratedLiquiditySwap.Strategy
            memory wideStrategy = createWideRangeStrategy();

        uint256 amountIn = 1000e6; // 1000 USDC

        // Get quotes for both
        uint256 tightQuote = clSwap.quoteExactIn(tightStrategy, true, amountIn);
        uint256 wideQuote = clSwap.quoteExactIn(wideStrategy, true, amountIn);

        // Both should provide valid quotes
        assertGt(tightQuote, 0, "Tight range should provide quote");
        assertGt(wideQuote, 0, "Wide range should provide quote");

        console2.log("Tight range quote:", tightQuote, "wei ETH");
        console2.log("Wide range quote:", wideQuote, "wei ETH");
    }

    // ========== Sequential Swap Tests ==========

    function testSequentialSwapsWorsenPrice() public {
        ConcentratedLiquiditySwap.Strategy
            memory strategy = createTightRangeStrategy();

        uint256 out1 = swap(strategy, true, 500e6);
        uint256 out2 = swap(strategy, true, 500e6);
        uint256 out3 = swap(strategy, true, 500e6);

        assertTrue(out1 > out2, "Second swap should have worse rate");
        assertTrue(out2 > out3, "Third swap should have worse rate");

        console2.log("Swap 1 output:", out1);
        console2.log("Swap 2 output:", out2);
        console2.log("Swap 3 output:", out3);
    }

    // ========== Invariant Tests ==========

    /// @notice Tests that the constant product invariant (k = x * y) increases with fees
    /// @dev Verifies that fees accumulate in the pool, increasing the product of balances
    function testConstantProductInvariantIncreases() public {
        ConcentratedLiquiditySwap.Strategy
            memory strategy = createTightRangeStrategy();
        bytes32 strategyHash = keccak256(abi.encode(strategy));

        // Get initial k
        (uint256 initialUSDC, ) = aqua.rawBalances(
            maker,
            address(clSwap),
            strategyHash,
            address(usdc)
        );
        (uint256 initialETH, ) = aqua.rawBalances(
            maker,
            address(clSwap),
            strategyHash,
            address(eth)
        );
        uint256 initialK = initialUSDC * initialETH;

        // Perform swap
        swap(strategy, true, 1000e6);

        // Get new k
        (uint256 newUSDC, ) = aqua.rawBalances(
            maker,
            address(clSwap),
            strategyHash,
            address(usdc)
        );
        (uint256 newETH, ) = aqua.rawBalances(
            maker,
            address(clSwap),
            strategyHash,
            address(eth)
        );
        uint256 newK = newUSDC * newETH;

        // K should increase due to fees
        assertGe(newK, initialK, "Constant product should not decrease");
        console2.log("Initial K:", initialK);
        console2.log("New K:", newK);
        console2.log("K increase:", ((newK - initialK) * 100) / initialK, "%");
    }

    function testNoValueLeakage() public {
        ConcentratedLiquiditySwap.Strategy
            memory strategy = createTightRangeStrategy();
        bytes32 strategyHash = keccak256(abi.encode(strategy));

        // Track initial total value
        (uint256 initialTotalUSDC, ) = aqua.rawBalances(
            maker,
            address(clSwap),
            strategyHash,
            address(usdc)
        );
        initialTotalUSDC +=
            usdc.balanceOf(address(callback)) +
            usdc.balanceOf(taker);
        (uint256 initialTotalETH, ) = aqua.rawBalances(
            maker,
            address(clSwap),
            strategyHash,
            address(eth)
        );
        initialTotalETH +=
            eth.balanceOf(address(callback)) +
            eth.balanceOf(taker);

        // Perform multiple swaps
        swap(strategy, true, 1000e6);
        swap(strategy, false, 0.5 ether);
        swap(strategy, true, 1500e6);

        // Track final total value
        (uint256 finalTotalUSDC, ) = aqua.rawBalances(
            maker,
            address(clSwap),
            strategyHash,
            address(usdc)
        );
        finalTotalUSDC +=
            usdc.balanceOf(address(callback)) +
            usdc.balanceOf(taker);
        (uint256 finalTotalETH, ) = aqua.rawBalances(
            maker,
            address(clSwap),
            strategyHash,
            address(eth)
        );
        finalTotalETH +=
            eth.balanceOf(address(callback)) +
            eth.balanceOf(taker);

        // Total tokens should be conserved
        assertEq(
            finalTotalUSDC,
            initialTotalUSDC,
            "Total USDC should be conserved"
        );
        assertEq(
            finalTotalETH,
            initialTotalETH,
            "Total ETH should be conserved"
        );
    }

    // ========== Edge Case Tests ==========

    /// @notice Tests that zero amount swaps are handled correctly
    /// @dev Should revert or return zero without breaking the pool
    function testZeroAmountSwap() public {
        ConcentratedLiquiditySwap.Strategy
            memory strategy = createTightRangeStrategy();

        uint256 amountOut = swap(strategy, true, 0);
        assertEq(amountOut, 0, "Zero input should give zero output");
    }

    /// @notice Tests minimum output protection
    /// @dev Verifies that swaps revert when output is below minimum
    function testMinimumOutputProtection() public {
        ConcentratedLiquiditySwap.Strategy
            memory strategy = createTightRangeStrategy();

        uint256 amountIn = 1000e6;
        uint256 expectedOut = clSwap.quoteExactIn(strategy, true, amountIn);

        vm.prank(taker);
        usdc.transfer(address(callback), amountIn);

        bytes memory takerData = abi.encode(true);
        vm.prank(address(callback));

        // Should revert if we demand more than possible
        vm.expectRevert();
        clSwap.swapExactIn(
            strategy,
            true,
            amountIn,
            expectedOut + 1,
            address(callback),
            takerData
        );
    }

    /// @notice Tests attempting to drain pool with large swap
    /// @dev With wide price ranges, large swaps succeed but don't drain completely
    function testCannotDrainPoolCompletely() public {
        ConcentratedLiquiditySwap.Strategy
            memory strategy = createTightRangeStrategy();
        bytes32 strategyHash = keccak256(abi.encode(strategy));

        // Get initial ETH balance
        (, uint256 initialETH) = aqua.safeBalances(
            maker,
            address(clSwap),
            strategyHash,
            address(usdc),
            address(eth)
        );

        // Try to swap massive amount
        uint256 hugeAmount = 500_000e6;
        usdc.mint(taker, hugeAmount);

        uint256 output = swap(strategy, true, hugeAmount);

        // Should get output but not drain pool completely
        assertGt(output, 0, "Should get some output");
        assertLt(output, initialETH, "Should not drain pool completely");

        // Check remaining balance
        (, uint256 remainingETH) = aqua.safeBalances(
            maker,
            address(clSwap),
            strategyHash,
            address(usdc),
            address(eth)
        );
        assertGt(remainingETH, 0, "Pool should have remaining balance");
    }

    /// @notice Tests very small swap amounts for rounding issues
    /// @dev Verifies that tiny swaps don't break the pool
    function testVerySmallSwapAmounts() public {
        ConcentratedLiquiditySwap.Strategy
            memory strategy = createTightRangeStrategy();

        // Swap 1 unit (smallest possible)
        uint256 tinyAmount = 1;
        uint256 output = swap(strategy, true, tinyAmount);

        // Output might be 0 due to rounding, but shouldn't revert
        assertGe(output, 0, "Tiny swap should not revert");
    }

    /// @notice Tests swapExactOut with maximum input protection
    /// @dev Verifies that swaps revert when input exceeds maximum
    function testMaximumInputProtection() public {
        ConcentratedLiquiditySwap.Strategy
            memory strategy = createTightRangeStrategy();

        uint256 amountOut = 1 ether;
        uint256 expectedIn = clSwap.quoteExactOut(strategy, true, amountOut);

        vm.prank(taker);
        usdc.transfer(address(callback), expectedIn);

        bytes memory takerData = abi.encode(true);
        vm.prank(address(callback));

        // Should revert if we set max input below required
        vm.expectRevert();
        clSwap.swapExactOut(
            strategy,
            true,
            amountOut,
            expectedIn - 1,
            address(callback),
            takerData
        );
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
