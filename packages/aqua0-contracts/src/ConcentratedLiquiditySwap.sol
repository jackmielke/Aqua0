// SPDX-License-Identifier: LicenseRef-Degensoft-Aqua-Source-1.1
pragma solidity 0.8.30;

/// @custom:license-url https://github.com/1inch/aqua/blob/main/LICENSES/Aqua-Source-1.1.txt
/// @custom:copyright © 2025 Degensoft Ltd

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IAqua } from "aqua/interfaces/IAqua.sol";
import { AquaApp } from "aqua/AquaApp.sol";
import { TransientLock, TransientLockLib } from "aqua/libs/ReentrancyGuard.sol";

/// @title ConcentratedLiquiditySwap
/// @notice Implements a concentrated liquidity AMM similar to Uniswap v3
/// @dev Liquidity is concentrated within a price range [priceLower, priceUpper]
contract ConcentratedLiquiditySwap is AquaApp {
    using Math for uint256;
    using TransientLockLib for TransientLock;

    error InsufficientOutputAmount(uint256 amountOut, uint256 amountOutMin);
    error ExcessiveInputAmount(uint256 amountIn, uint256 amountInMax);
    error PriceOutOfRange(uint256 currentPrice, uint256 priceLower, uint256 priceUpper);
    error InvalidPriceRange(uint256 priceLower, uint256 priceUpper);

    struct Strategy {
        address maker;
        address token0;
        address token1;
        uint256 feeBps;
        uint256 priceLower; // Minimum price (token1/token0) * 1e18
        uint256 priceUpper; // Maximum price (token1/token0) * 1e18
        bytes32 salt;
    }

    uint256 internal constant BPS_BASE = 10_000;
    uint256 internal constant PRICE_PRECISION = 1e18;

    constructor(IAqua aqua_) AquaApp(aqua_) { }

    function quoteExactIn(
        Strategy calldata strategy,
        bool zeroForOne,
        uint256 amountIn
    ) external view returns (uint256 amountOut) {
        bytes32 strategyHash = keccak256(abi.encode(strategy));
        (,, uint256 balanceIn, uint256 balanceOut) = _getInAndOut(strategy, strategyHash, zeroForOne);
        
        // Validate price range
        require(strategy.priceLower < strategy.priceUpper, InvalidPriceRange(strategy.priceLower, strategy.priceUpper));
        
        amountOut = _quoteExactIn(strategy, balanceIn, balanceOut, amountIn, zeroForOne);
    }

    function quoteExactOut(
        Strategy calldata strategy,
        bool zeroForOne,
        uint256 amountOut
    ) external view returns (uint256 amountIn) {
        bytes32 strategyHash = keccak256(abi.encode(strategy));
        (,, uint256 balanceIn, uint256 balanceOut) = _getInAndOut(strategy, strategyHash, zeroForOne);
        
        // Validate price range
        require(strategy.priceLower < strategy.priceUpper, InvalidPriceRange(strategy.priceLower, strategy.priceUpper));
        
        amountIn = _quoteExactOut(strategy, balanceIn, balanceOut, amountOut, zeroForOne);
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

        (address tokenIn, address tokenOut, uint256 balanceIn, uint256 balanceOut) = _getInAndOut(strategy, strategyHash, zeroForOne);
        
        // Validate price range
        require(strategy.priceLower < strategy.priceUpper, InvalidPriceRange(strategy.priceLower, strategy.priceUpper));
        
        amountOut = _quoteExactIn(strategy, balanceIn, balanceOut, amountIn, zeroForOne);
        require(amountOut >= amountOutMin, InsufficientOutputAmount(amountOut, amountOutMin));

        AQUA.pull(strategy.maker, strategyHash, tokenOut, amountOut, to);
        IConcentratedLiquidityCallback(msg.sender).concentratedLiquidityCallback(tokenIn, tokenOut, amountIn, amountOut, strategy.maker, address(this), strategyHash, takerData);
        _safeCheckAquaPush(strategy.maker, strategyHash, tokenIn, balanceIn + amountIn);
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

        (address tokenIn, address tokenOut, uint256 balanceIn, uint256 balanceOut) = _getInAndOut(strategy, strategyHash, zeroForOne);
        
        // Validate price range
        require(strategy.priceLower < strategy.priceUpper, InvalidPriceRange(strategy.priceLower, strategy.priceUpper));
        
        amountIn = _quoteExactOut(strategy, balanceIn, balanceOut, amountOut, zeroForOne);
        require(amountIn <= amountInMax, ExcessiveInputAmount(amountIn, amountInMax));

        AQUA.pull(strategy.maker, strategyHash, tokenOut, amountOut, to);
        IConcentratedLiquidityCallback(msg.sender).concentratedLiquidityCallback(tokenIn, tokenOut, amountIn, amountOut, strategy.maker, address(this), strategyHash, takerData);
        _safeCheckAquaPush(strategy.maker, strategyHash, tokenIn, balanceIn + amountIn);
    }

    function _quoteExactIn(
        Strategy calldata strategy,
        uint256 balanceIn,
        uint256 balanceOut,
        uint256 amountIn,
        bool /* zeroForOne */
    ) internal pure returns (uint256 amountOut) {
        // Calculate current price (token1/token0)
        uint256 currentPrice = (balanceOut * PRICE_PRECISION) / balanceIn;
        
        // Check if price is within range BEFORE the swap
        require(
            currentPrice >= strategy.priceLower && currentPrice <= strategy.priceUpper,
            PriceOutOfRange(currentPrice, strategy.priceLower, strategy.priceUpper)
        );

        // Use concentrated liquidity formula
        // In a concentrated range, liquidity is more efficient
        uint256 amountInWithFee = amountIn * (BPS_BASE - strategy.feeBps) / BPS_BASE;
        
        // Calculate virtual liquidity based on concentration
        // The narrower the range, the more efficient the capital
        uint256 rangeMultiplier = _calculateRangeMultiplier(strategy.priceLower, strategy.priceUpper);
        
        // Effective balance is amplified by concentration
        uint256 effectiveBalanceIn = balanceIn * rangeMultiplier / PRICE_PRECISION;
        uint256 effectiveBalanceOut = balanceOut * rangeMultiplier / PRICE_PRECISION;
        
        // Apply constant product formula with effective balances
        amountOut = (amountInWithFee * effectiveBalanceOut) / (effectiveBalanceIn + amountInWithFee);
        
        // Ensure we don't exceed actual balance
        if (amountOut > balanceOut) {
            amountOut = balanceOut - 1; // Leave at least 1 wei
        }
        
        // Check if price would be within range AFTER the swap
        uint256 newBalanceIn = balanceIn + amountIn;
        uint256 newBalanceOut = balanceOut - amountOut;
        uint256 newPrice = (newBalanceOut * PRICE_PRECISION) / newBalanceIn;
        
        require(
            newPrice >= strategy.priceLower && newPrice <= strategy.priceUpper,
            PriceOutOfRange(newPrice, strategy.priceLower, strategy.priceUpper)
        );
    }

    function _quoteExactOut(
        Strategy calldata strategy,
        uint256 balanceIn,
        uint256 balanceOut,
        uint256 amountOut,
        bool /* zeroForOne */
    ) internal pure returns (uint256 amountIn) {
        // Calculate current price (token1/token0)
        uint256 currentPrice = (balanceOut * PRICE_PRECISION) / balanceIn;
        
        // Check if price is within range BEFORE the swap
        require(
            currentPrice >= strategy.priceLower && currentPrice <= strategy.priceUpper,
            PriceOutOfRange(currentPrice, strategy.priceLower, strategy.priceUpper)
        );

        // Calculate virtual liquidity based on concentration
        uint256 rangeMultiplier = _calculateRangeMultiplier(strategy.priceLower, strategy.priceUpper);
        
        // Effective balance is amplified by concentration
        uint256 effectiveBalanceIn = balanceIn * rangeMultiplier / PRICE_PRECISION;
        uint256 effectiveBalanceOut = balanceOut * rangeMultiplier / PRICE_PRECISION;
        
        // Apply constant product formula with effective balances
        uint256 amountOutWithFee = amountOut * BPS_BASE / (BPS_BASE - strategy.feeBps);
        amountIn = (effectiveBalanceIn * amountOutWithFee).ceilDiv(effectiveBalanceOut - amountOutWithFee);
        
        // Check if price would be within range AFTER the swap
        uint256 newBalanceIn = balanceIn + amountIn;
        uint256 newBalanceOut = balanceOut - amountOut;
        uint256 newPrice = (newBalanceOut * PRICE_PRECISION) / newBalanceIn;
        
        require(
            newPrice >= strategy.priceLower && newPrice <= strategy.priceUpper,
            PriceOutOfRange(newPrice, strategy.priceLower, strategy.priceUpper)
        );
    }

    /// @notice Calculates range multiplier for concentrated liquidity
    /// @dev Narrower ranges get higher multipliers (more efficient capital)
    function _calculateRangeMultiplier(uint256 priceLower, uint256 priceUpper) internal pure returns (uint256) {
        // Range width as percentage of lower bound
        uint256 rangeWidth = ((priceUpper - priceLower) * PRICE_PRECISION) / priceLower;
        
        // Multiplier decreases as range widens
        // For a 10% range: multiplier ≈ 2x
        // For a 50% range: multiplier ≈ 1.5x
        // For a 100%+ range: multiplier ≈ 1x (similar to regular AMM)
        
        if (rangeWidth <= PRICE_PRECISION / 10) { // <= 10% range
            return PRICE_PRECISION * 2; // 2x multiplier
        } else if (rangeWidth <= PRICE_PRECISION / 2) { // <= 50% range
            return PRICE_PRECISION * 3 / 2; // 1.5x multiplier
        } else {
            return PRICE_PRECISION; // 1x multiplier (regular AMM)
        }
    }

    function _getInAndOut(Strategy calldata strategy, bytes32 strategyHash, bool zeroForOne) private view returns (address tokenIn, address tokenOut, uint256 balanceIn, uint256 balanceOut) {
        tokenIn = zeroForOne ? strategy.token0 : strategy.token1;
        tokenOut = zeroForOne ? strategy.token1 : strategy.token0;
        (balanceIn, balanceOut) = AQUA.safeBalances(strategy.maker, address(this), strategyHash, tokenIn, tokenOut);
    }
}

interface IConcentratedLiquidityCallback {
    function concentratedLiquidityCallback(
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

