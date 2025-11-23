// SPDX-License-Identifier: LicenseRef-Degensoft-Aqua-Source-1.1
pragma solidity 0.8.30;

/// @custom:license-url https://github.com/1inch/aqua/blob/main/LICENSES/Aqua-Source-1.1.txt
/// @custom:copyright © 2025 Degensoft Ltd

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IAqua} from "aqua/interfaces/IAqua.sol";
import {AquaApp} from "aqua/AquaApp.sol";
import {TransientLock, TransientLockLib} from "aqua/libs/ReentrancyGuard.sol";

/// @title StableswapAMM
/// @notice Implements a Curve-style stableswap AMM optimized for assets with similar prices
/// @dev Uses a hybrid constant product and constant sum formula for minimal slippage
contract StableswapAMM is AquaApp {
    using Math for uint256;
    using TransientLockLib for TransientLock;

    error InsufficientOutputAmount(uint256 amountOut, uint256 amountOutMin);
    error ExcessiveInputAmount(uint256 amountIn, uint256 amountInMax);

    struct Strategy {
        address maker;
        address token0;
        address token1;
        uint256 feeBps;
        uint256 amplificationFactor; // A parameter: higher = more like constant sum (stable), lower = more like constant product
        bytes32 salt;
    }

    uint256 internal constant BPS_BASE = 10_000;
    uint256 internal constant PRECISION = 1e18;

    constructor(IAqua aqua_) AquaApp(aqua_) {}

    function quoteExactIn(
        Strategy calldata strategy,
        bool zeroForOne,
        uint256 amountIn
    ) external view returns (uint256 amountOut) {
        bytes32 strategyHash = keccak256(abi.encode(strategy));
        (, , uint256 balanceIn, uint256 balanceOut) = _getInAndOut(
            strategy,
            strategyHash,
            zeroForOne
        );
        amountOut = _quoteExactIn(
            strategy.feeBps,
            strategy.amplificationFactor,
            balanceIn,
            balanceOut,
            amountIn
        );
    }

    function quoteExactOut(
        Strategy calldata strategy,
        bool zeroForOne,
        uint256 amountOut
    ) external view returns (uint256 amountIn) {
        bytes32 strategyHash = keccak256(abi.encode(strategy));
        (, , uint256 balanceIn, uint256 balanceOut) = _getInAndOut(
            strategy,
            strategyHash,
            zeroForOne
        );
        amountIn = _quoteExactOut(
            strategy.feeBps,
            strategy.amplificationFactor,
            balanceIn,
            balanceOut,
            amountOut
        );
    }

    function swapExactIn(
        Strategy calldata strategy,
        bool zeroForOne,
        uint256 amountIn,
        uint256 amountOutMin,
        address to,
        bytes calldata takerData
    )
        external
        nonReentrantStrategy(keccak256(abi.encode(strategy)))
        returns (uint256 amountOut)
    {
        bytes32 strategyHash = keccak256(abi.encode(strategy));

        (
            address tokenIn,
            address tokenOut,
            uint256 balanceIn,
            uint256 balanceOut
        ) = _getInAndOut(strategy, strategyHash, zeroForOne);

        amountOut = _quoteExactIn(
            strategy.feeBps,
            strategy.amplificationFactor,
            balanceIn,
            balanceOut,
            amountIn
        );
        require(
            amountOut >= amountOutMin,
            InsufficientOutputAmount(amountOut, amountOutMin)
        );

        AQUA.pull(strategy.maker, strategyHash, tokenOut, amountOut, to);
        IStableswapCallback(msg.sender).stableswapCallback(
            tokenIn,
            tokenOut,
            amountIn,
            amountOut,
            strategy.maker,
            address(this),
            strategyHash,
            takerData
        );
        _safeCheckAquaPush(
            strategy.maker,
            strategyHash,
            tokenIn,
            balanceIn + amountIn
        );
    }

    function swapExactOut(
        Strategy calldata strategy,
        bool zeroForOne,
        uint256 amountOut,
        uint256 amountInMax,
        address to,
        bytes calldata takerData
    )
        external
        nonReentrantStrategy(keccak256(abi.encode(strategy)))
        returns (uint256 amountIn)
    {
        bytes32 strategyHash = keccak256(abi.encode(strategy));

        (
            address tokenIn,
            address tokenOut,
            uint256 balanceIn,
            uint256 balanceOut
        ) = _getInAndOut(strategy, strategyHash, zeroForOne);

        amountIn = _quoteExactOut(
            strategy.feeBps,
            strategy.amplificationFactor,
            balanceIn,
            balanceOut,
            amountOut
        );
        require(
            amountIn <= amountInMax,
            ExcessiveInputAmount(amountIn, amountInMax)
        );

        AQUA.pull(strategy.maker, strategyHash, tokenOut, amountOut, to);
        IStableswapCallback(msg.sender).stableswapCallback(
            tokenIn,
            tokenOut,
            amountIn,
            amountOut,
            strategy.maker,
            address(this),
            strategyHash,
            takerData
        );
        _safeCheckAquaPush(
            strategy.maker,
            strategyHash,
            tokenIn,
            balanceIn + amountIn
        );
    }

    /// @notice Calculates output amount using Curve's stableswap invariant
    /// @dev Simplified stableswap formula: combines constant product and constant sum
    function _quoteExactIn(
        uint256 feeBps,
        uint256 A,
        uint256 balanceIn,
        uint256 balanceOut,
        uint256 amountIn
    ) internal pure returns (uint256 amountOut) {
        // Apply fee
        uint256 amountInWithFee = (amountIn * (BPS_BASE - feeBps)) / BPS_BASE;

        // Simplified Curve formula: y = (A * x * y + x * y^2) / (A * x + y^2)
        // Where A is amplification coefficient
        // Higher A = more like constant sum (x + y = const) = better for stable pairs
        // Lower A = more like constant product (x * y = const) = better for volatile pairs

        uint256 newBalanceIn = balanceIn + amountInWithFee;

        // For simplicity, use a hybrid approach:
        // weight = A / (A + 1)
        // output = weight * constantSumOutput + (1 - weight) * constantProductOutput

        uint256 constantSumOut = amountInWithFee; // In constant sum, output = input
        uint256 constantProductOut = (amountInWithFee * balanceOut) /
            (balanceIn + amountInWithFee);

        // Blend based on amplification factor
        // A=100 means 99% constant sum, 1% constant product
        // A=1 means 50% constant sum, 50% constant product
        uint256 weight = (A * PRECISION) / (A + 1);
        amountOut =
            (weight *
                constantSumOut +
                (PRECISION - weight) *
                constantProductOut) /
            PRECISION;

        // Ensure we don't exceed balance
        if (amountOut > balanceOut) {
            amountOut = balanceOut - 1;
        }
    }

    /// @notice Calculates input amount needed for desired output using stableswap formula
    function _quoteExactOut(
        uint256 feeBps,
        uint256 A,
        uint256 balanceIn,
        uint256 balanceOut,
        uint256 amountOut
    ) internal pure returns (uint256 amountIn) {
        // Simplified inverse calculation
        uint256 constantSumIn = amountOut; // In constant sum, input = output
        uint256 constantProductIn = (balanceIn * amountOut).ceilDiv(
            balanceOut - amountOut
        );

        // Blend based on amplification factor
        uint256 weight = (A * PRECISION) / (A + 1);
        uint256 amountInBeforeFee = (weight *
            constantSumIn +
            (PRECISION - weight) *
            constantProductIn) / PRECISION;

        // Account for fee
        amountIn = (amountInBeforeFee * BPS_BASE).ceilDiv(BPS_BASE - feeBps);
    }

    function _getInAndOut(
        Strategy calldata strategy,
        bytes32 strategyHash,
        bool zeroForOne
    )
        private
        view
        returns (
            address tokenIn,
            address tokenOut,
            uint256 balanceIn,
            uint256 balanceOut
        )
    {
        tokenIn = zeroForOne ? strategy.token0 : strategy.token1;
        tokenOut = zeroForOne ? strategy.token1 : strategy.token0;
        (balanceIn, balanceOut) = AQUA.safeBalances(
            strategy.maker,
            address(this),
            strategyHash,
            tokenIn,
            tokenOut
        );
    }
}

interface IStableswapCallback {
    function stableswapCallback(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        address maker,
        address app,
        bytes32 strategyHash,
        bytes calldata takerData
    ) external;
}
