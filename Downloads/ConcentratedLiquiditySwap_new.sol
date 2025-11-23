// SPDX-License-Identifier: LicenseRef-Degensoft-Aqua-Source-1.1
pragma solidity 0.8.30;

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IAqua } from "aqua/interfaces/IAqua.sol";
import { AquaApp } from "aqua/AquaApp.sol";
import { TransientLock, TransientLockLib } from "aqua/libs/ReentrancyGuard.sol";

/// @title ConcentratedLiquiditySwap
/// @notice Implements Uniswap V3-style concentrated liquidity within Aqua framework
/// @dev Accepts regular prices in strategy and converts to sqrt prices internally
contract ConcentratedLiquiditySwap is AquaApp {
    using Math for uint256;
    using TransientLockLib for TransientLock;

    error InsufficientOutputAmount(uint256 amountOut, uint256 amountOutMin);
    error ExcessiveInputAmount(uint256 amountIn, uint256 amountInMax);
    error PriceOutOfRange(uint160 sqrtPrice, uint160 sqrtPriceLower, uint160 sqrtPriceUpper);
    error InvalidPriceRange(uint256 priceLower, uint256 priceUpper);
    error InsufficientLiquidity();
    error PriceTooLarge(uint256 price);

    struct Strategy {
        address maker;
        address token0;
        address token1;
        uint24 feeBps;  // Fee in basis points (e.g., 30 = 0.3%)
        uint256 priceLower;  // Regular price (token1/token0) with 18 decimals
        uint256 priceUpper;  // Regular price (token1/token0) with 18 decimals
        bytes32 salt;
    }

    // Internal struct to work with sqrt prices
    struct SqrtPriceRange {
        uint160 sqrtPriceLower;
        uint160 sqrtPriceUpper;
    }

    uint256 internal constant BPS_BASE = 10_000;
    uint256 internal constant PRICE_DECIMALS = 1e18;  // Prices are expected with 18 decimals
    uint256 internal constant Q96 = 2**96;
    uint256 internal constant MAX_SAFE_PRICE = 2**128;  // Maximum price we can safely sqrt

    // State variable to track current sqrt price for each strategy
    mapping(bytes32 => uint160) public currentSqrtPrice;

    constructor(IAqua aqua_) AquaApp(aqua_) { }

    /// @notice Convert a regular price to sqrt price in Q64.96 format
    /// @param price Regular price with 18 decimals (e.g., 2000e18 for $2000)
    /// @return sqrtPriceX96 Square root price in Q64.96 format
    function priceToSqrtPriceX96(uint256 price) public pure returns (uint160 sqrtPriceX96) {
        require(price > 0 && price < MAX_SAFE_PRICE, PriceTooLarge(price));
        
        // Calculate sqrt(price * 2^192 / 10^18)
        // This is equivalent to sqrt(price) * 2^96 / 10^9
        // We multiply by 2^192 to maintain precision in Q64.96 format
        
        // First scale the price to maintain precision
        uint256 scaledPrice = (price * Q96 * Q96) / PRICE_DECIMALS;
        
        // Take square root
        sqrtPriceX96 = uint160(Math.sqrt(scaledPrice));
    }

    /// @notice Convert sqrt price back to regular price
    /// @param sqrtPriceX96 Square root price in Q64.96 format
    /// @return price Regular price with 18 decimals
    function sqrtPriceX96ToPrice(uint160 sqrtPriceX96) public pure returns (uint256 price) {
        // Square the sqrt price and adjust for Q64.96 format
        uint256 squaredPrice = uint256(sqrtPriceX96) * uint256(sqrtPriceX96);
        price = (squaredPrice * PRICE_DECIMALS) / (Q96 * Q96);
    }

    /// @notice Get sqrt price range from strategy
    function _getSqrtPriceRange(Strategy calldata strategy) internal pure returns (SqrtPriceRange memory range) {
        require(strategy.priceLower < strategy.priceUpper, InvalidPriceRange(strategy.priceLower, strategy.priceUpper));
        range.sqrtPriceLower = priceToSqrtPriceX96(strategy.priceLower);
        range.sqrtPriceUpper = priceToSqrtPriceX96(strategy.priceUpper);
    }

    /// @notice Calculate liquidity from token amounts at current price
    function _getLiquidityFromAmounts(
        uint256 amount0,
        uint256 amount1,
        uint160 sqrtPriceCurrent,
        uint160 sqrtPriceLower,
        uint160 sqrtPriceUpper
    ) internal pure returns (uint128 liquidity) {
        if (sqrtPriceCurrent <= sqrtPriceLower) {
            // Price is below range, all holdings are in token0
            liquidity = _getLiquidityForAmount0(sqrtPriceLower, sqrtPriceUpper, amount0);
        } else if (sqrtPriceCurrent >= sqrtPriceUpper) {
            // Price is above range, all holdings are in token1
            liquidity = _getLiquidityForAmount1(sqrtPriceLower, sqrtPriceUpper, amount1);
        } else {
            // Price is in range, holdings are mixed
            uint128 liquidity0 = _getLiquidityForAmount0(sqrtPriceCurrent, sqrtPriceUpper, amount0);
            uint128 liquidity1 = _getLiquidityForAmount1(sqrtPriceLower, sqrtPriceCurrent, amount1);
            liquidity = liquidity0 < liquidity1 ? liquidity0 : liquidity1;
        }
    }

    /// @notice Calculate liquidity from amount0
    function _getLiquidityForAmount0(
        uint160 sqrtPriceA,
        uint160 sqrtPriceB,
        uint256 amount0
    ) internal pure returns (uint128 liquidity) {
        if (sqrtPriceA > sqrtPriceB) (sqrtPriceA, sqrtPriceB) = (sqrtPriceB, sqrtPriceA);
        uint256 intermediate = (uint256(sqrtPriceA) * uint256(sqrtPriceB)) / Q96;
        liquidity = uint128((amount0 * intermediate) / (sqrtPriceB - sqrtPriceA));
    }

    /// @notice Calculate liquidity from amount1
    function _getLiquidityForAmount1(
        uint160 sqrtPriceA,
        uint160 sqrtPriceB,
        uint256 amount1
    ) internal pure returns (uint128 liquidity) {
        if (sqrtPriceA > sqrtPriceB) (sqrtPriceA, sqrtPriceB) = (sqrtPriceB, sqrtPriceA);
        liquidity = uint128((amount1 * Q96) / (sqrtPriceB - sqrtPriceA));
    }

    /// @notice Calculate token amounts from liquidity
    function _getAmountsFromLiquidity(
        uint128 liquidity,
        uint160 sqrtPriceCurrent,
        uint160 sqrtPriceLower,
        uint160 sqrtPriceUpper
    ) internal pure returns (uint256 amount0, uint256 amount1) {
        if (sqrtPriceCurrent <= sqrtPriceLower) {
            // All in token0
            amount0 = _getAmount0FromLiquidity(sqrtPriceLower, sqrtPriceUpper, liquidity);
            amount1 = 0;
        } else if (sqrtPriceCurrent >= sqrtPriceUpper) {
            // All in token1
            amount0 = 0;
            amount1 = _getAmount1FromLiquidity(sqrtPriceLower, sqrtPriceUpper, liquidity);
        } else {
            // Mixed position
            amount0 = _getAmount0FromLiquidity(sqrtPriceCurrent, sqrtPriceUpper, liquidity);
            amount1 = _getAmount1FromLiquidity(sqrtPriceLower, sqrtPriceCurrent, liquidity);
        }
    }

    function _getAmount0FromLiquidity(
        uint160 sqrtPriceA,
        uint160 sqrtPriceB,
        uint128 liquidity
    ) internal pure returns (uint256 amount0) {
        if (sqrtPriceA > sqrtPriceB) (sqrtPriceA, sqrtPriceB) = (sqrtPriceB, sqrtPriceA);
        amount0 = (uint256(liquidity) * Q96 * (sqrtPriceB - sqrtPriceA)) / (uint256(sqrtPriceB) * uint256(sqrtPriceA));
    }

    function _getAmount1FromLiquidity(
        uint160 sqrtPriceA,
        uint160 sqrtPriceB,
        uint128 liquidity
    ) internal pure returns (uint256 amount1) {
        if (sqrtPriceA > sqrtPriceB) (sqrtPriceA, sqrtPriceB) = (sqrtPriceB, sqrtPriceA);
        amount1 = (uint256(liquidity) * (sqrtPriceB - sqrtPriceA)) / Q96;
    }

    /// @notice Compute swap within a single tick range
    function _computeSwapStep(
        uint160 sqrtPriceCurrent,
        uint160 sqrtPriceTarget,
        uint128 liquidity,
        uint256 amountRemaining,
        uint24 feeBps
    ) internal pure returns (
        uint160 sqrtPriceNext,
        uint256 amountIn,
        uint256 amountOut,
        uint256 feeAmount
    ) {
        bool zeroForOne = sqrtPriceCurrent >= sqrtPriceTarget;
        bool exactIn = amountRemaining > 0;

        if (exactIn) {
            uint256 amountRemainingLessFee = (amountRemaining * (BPS_BASE - feeBps)) / BPS_BASE;
            amountIn = zeroForOne
                ? _getAmount0Delta(sqrtPriceTarget, sqrtPriceCurrent, liquidity)
                : _getAmount1Delta(sqrtPriceCurrent, sqrtPriceTarget, liquidity);

            if (amountRemainingLessFee >= amountIn) {
                sqrtPriceNext = sqrtPriceTarget;
            } else {
                sqrtPriceNext = _getNextSqrtPriceFromInput(
                    sqrtPriceCurrent,
                    liquidity,
                    amountRemainingLessFee,
                    zeroForOne
                );
                amountIn = amountRemaining;
            }

            amountOut = zeroForOne
                ? _getAmount1Delta(sqrtPriceNext, sqrtPriceCurrent, liquidity)
                : _getAmount0Delta(sqrtPriceCurrent, sqrtPriceNext, liquidity);

            feeAmount = (amountIn * feeBps) / BPS_BASE;
        }
    }

    function _getAmount0Delta(
        uint160 sqrtPriceA,
        uint160 sqrtPriceB,
        uint128 liquidity
    ) internal pure returns (uint256 amount0) {
        if (sqrtPriceA > sqrtPriceB) (sqrtPriceA, sqrtPriceB) = (sqrtPriceB, sqrtPriceA);
        uint256 numerator = uint256(liquidity) * Q96 * (sqrtPriceB - sqrtPriceA);
        amount0 = numerator / uint256(sqrtPriceB) / uint256(sqrtPriceA);
    }

    function _getAmount1Delta(
        uint160 sqrtPriceA,
        uint160 sqrtPriceB,
        uint128 liquidity
    ) internal pure returns (uint256 amount1) {
        if (sqrtPriceA > sqrtPriceB) (sqrtPriceA, sqrtPriceB) = (sqrtPriceB, sqrtPriceA);
        amount1 = (uint256(liquidity) * (sqrtPriceB - sqrtPriceA)) / Q96;
    }

    function _getNextSqrtPriceFromInput(
        uint160 sqrtPriceCurrent,
        uint128 liquidity,
        uint256 amountIn,
        bool zeroForOne
    ) internal pure returns (uint160 sqrtPriceNext) {
        if (zeroForOne) {
            // token0 -> token1, price decreases
            uint256 product = uint256(liquidity) * uint256(sqrtPriceCurrent);
            sqrtPriceNext = uint160((product * Q96) / (product + amountIn * Q96));
        } else {
            // token1 -> token0, price increases
            sqrtPriceNext = uint160(sqrtPriceCurrent + (amountIn * Q96) / liquidity);
        }
    }

    /// @notice Initialize sqrt price for a strategy from balances or midpoint
    function _initializeSqrtPrice(
        bytes32 strategyHash,
        uint256 balance0,
        uint256 balance1,
        SqrtPriceRange memory range
    ) internal returns (uint160 sqrtPriceCurrent) {
        sqrtPriceCurrent = currentSqrtPrice[strategyHash];
        if (sqrtPriceCurrent == 0) {
            if (balance0 > 0 && balance1 > 0) {
                // Calculate implied sqrt price from balances
                // Price = balance1/balance0, so sqrtPrice = sqrt(balance1/balance0) * Q96
                uint256 price = (balance1 * PRICE_DECIMALS) / balance0;
                sqrtPriceCurrent = priceToSqrtPriceX96(price);
                
                // Clamp to range if necessary
                if (sqrtPriceCurrent < range.sqrtPriceLower) {
                    sqrtPriceCurrent = range.sqrtPriceLower;
                } else if (sqrtPriceCurrent > range.sqrtPriceUpper) {
                    sqrtPriceCurrent = range.sqrtPriceUpper;
                }
            } else {
                // Use geometric mean of range as initial price
                uint256 sqrtLower = uint256(range.sqrtPriceLower);
                uint256 sqrtUpper = uint256(range.sqrtPriceUpper);
                sqrtPriceCurrent = uint160(Math.sqrt(sqrtLower * sqrtUpper));
            }
            currentSqrtPrice[strategyHash] = sqrtPriceCurrent;
        }
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
        // Convert regular prices to sqrt prices
        SqrtPriceRange memory range = _getSqrtPriceRange(strategy);
        
        bytes32 strategyHash = keccak256(abi.encode(strategy));
        
        // Get current balances from Aqua
        (address tokenIn, address tokenOut, uint256 balance0, uint256 balance1) = 
            _getBalances(strategy, strategyHash, zeroForOne);

        // Get or initialize current sqrt price
        uint160 sqrtPriceCurrent = _initializeSqrtPrice(strategyHash, balance0, balance1, range);

        require(
            sqrtPriceCurrent >= range.sqrtPriceLower && 
            sqrtPriceCurrent <= range.sqrtPriceUpper,
            PriceOutOfRange(sqrtPriceCurrent, range.sqrtPriceLower, range.sqrtPriceUpper)
        );

        // Calculate liquidity from current balances
        uint128 liquidity = _getLiquidityFromAmounts(
            balance0,
            balance1,
            sqrtPriceCurrent,
            range.sqrtPriceLower,
            range.sqrtPriceUpper
        );

        require(liquidity > 0, InsufficientLiquidity());

        // Determine target price (bounded by range)
        uint160 sqrtPriceTarget = zeroForOne 
            ? range.sqrtPriceLower 
            : range.sqrtPriceUpper;

        // Compute the swap
        (uint160 sqrtPriceNext, uint256 amountInUsed, uint256 amountOutComputed,) = _computeSwapStep(
            sqrtPriceCurrent,
            sqrtPriceTarget,
            liquidity,
            amountIn,
            strategy.feeBps
        );

        amountOut = amountOutComputed;
        require(amountOut >= amountOutMin, InsufficientOutputAmount(amountOut, amountOutMin));

        // Update price
        currentSqrtPrice[strategyHash] = sqrtPriceNext;

        // Execute the swap through Aqua
        uint256 balanceIn = zeroForOne ? balance0 : balance1;
        AQUA.pull(strategy.maker, strategyHash, tokenOut, amountOut, to);
        IConcentratedLiquidityCallback(msg.sender).concentratedLiquidityCallback(
            tokenIn, tokenOut, amountInUsed, amountOut, 
            strategy.maker, address(this), strategyHash, takerData
        );
        _safeCheckAquaPush(strategy.maker, strategyHash, tokenIn, balanceIn + amountInUsed);
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
        // Convert regular prices to sqrt prices
        SqrtPriceRange memory range = _getSqrtPriceRange(strategy);
        
        bytes32 strategyHash = keccak256(abi.encode(strategy));
        
        // Get current balances from Aqua
        (address tokenIn, address tokenOut, uint256 balance0, uint256 balance1) = 
            _getBalances(strategy, strategyHash, zeroForOne);

        // Get or initialize current sqrt price
        uint160 sqrtPriceCurrent = _initializeSqrtPrice(strategyHash, balance0, balance1, range);

        require(
            sqrtPriceCurrent >= range.sqrtPriceLower && 
            sqrtPriceCurrent <= range.sqrtPriceUpper,
            PriceOutOfRange(sqrtPriceCurrent, range.sqrtPriceLower, range.sqrtPriceUpper)
        );

        // Calculate liquidity from current balances
        uint128 liquidity = _getLiquidityFromAmounts(
            balance0,
            balance1,
            sqrtPriceCurrent,
            range.sqrtPriceLower,
            range.sqrtPriceUpper
        );

        require(liquidity > 0, InsufficientLiquidity());

        // For exact output, we need to compute the input amount
        // This is the inverse of the exact input calculation
        uint160 sqrtPriceTarget = zeroForOne 
            ? range.sqrtPriceLower 
            : range.sqrtPriceUpper;

        // Calculate the sqrt price after removing amountOut
        uint160 sqrtPriceNext;
        if (zeroForOne) {
            // Removing token1, price decreases
            uint256 deltaY = amountOut;
            if (deltaY >= uint256(liquidity) * (sqrtPriceCurrent - range.sqrtPriceLower) / Q96) {
                sqrtPriceNext = range.sqrtPriceLower;
            } else {
                sqrtPriceNext = uint160(sqrtPriceCurrent - (deltaY * Q96) / liquidity);
            }
        } else {
            // Removing token0, price increases
            uint256 deltaX = amountOut;
            uint256 product = uint256(liquidity) * uint256(sqrtPriceCurrent);
            sqrtPriceNext = uint160((product * Q96) / (product - deltaX * Q96));
            if (sqrtPriceNext > range.sqrtPriceUpper) {
                sqrtPriceNext = range.sqrtPriceUpper;
            }
        }

        // Calculate required input
        amountIn = zeroForOne
            ? _getAmount0Delta(sqrtPriceCurrent, sqrtPriceNext, liquidity)
            : _getAmount1Delta(sqrtPriceNext, sqrtPriceCurrent, liquidity);

        // Add fee
        amountIn = (amountIn * BPS_BASE) / (BPS_BASE - strategy.feeBps);

        require(amountIn <= amountInMax, ExcessiveInputAmount(amountIn, amountInMax));

        // Update price
        currentSqrtPrice[strategyHash] = sqrtPriceNext;

        // Execute the swap through Aqua
        uint256 balanceIn = zeroForOne ? balance0 : balance1;
        AQUA.pull(strategy.maker, strategyHash, tokenOut, amountOut, to);
        IConcentratedLiquidityCallback(msg.sender).concentratedLiquidityCallback(
            tokenIn, tokenOut, amountIn, amountOut, 
            strategy.maker, address(this), strategyHash, takerData
        );
        _safeCheckAquaPush(strategy.maker, strategyHash, tokenIn, balanceIn + amountIn);
    }

    function _getBalances(
        Strategy calldata strategy, 
        bytes32 strategyHash, 
        bool zeroForOne
    ) private view returns (
        address tokenIn, 
        address tokenOut, 
        uint256 balance0, 
        uint256 balance1
    ) {
        tokenIn = zeroForOne ? strategy.token0 : strategy.token1;
        tokenOut = zeroForOne ? strategy.token1 : strategy.token0;
        (balance0, balance1) = AQUA.safeBalances(
            strategy.maker, 
            address(this), 
            strategyHash, 
            strategy.token0, 
            strategy.token1
        );
    }

    /// @notice Get quote for exact input amount
    function quoteExactIn(
        Strategy calldata strategy,
        bool zeroForOne,
        uint256 amountIn
    ) external view returns (uint256 amountOut) {
        SqrtPriceRange memory range = _getSqrtPriceRange(strategy);
        bytes32 strategyHash = keccak256(abi.encode(strategy));
        (, , uint256 balance0, uint256 balance1) = _getBalances(strategy, strategyHash, zeroForOne);
        
        uint160 sqrtPriceCurrent = currentSqrtPrice[strategyHash];
        if (sqrtPriceCurrent == 0) {
            if (balance0 > 0 && balance1 > 0) {
                uint256 price = (balance1 * PRICE_DECIMALS) / balance0;
                sqrtPriceCurrent = priceToSqrtPriceX96(price);
                
                if (sqrtPriceCurrent < range.sqrtPriceLower) {
                    sqrtPriceCurrent = range.sqrtPriceLower;
                } else if (sqrtPriceCurrent > range.sqrtPriceUpper) {
                    sqrtPriceCurrent = range.sqrtPriceUpper;
                }
            } else {
                uint256 sqrtLower = uint256(range.sqrtPriceLower);
                uint256 sqrtUpper = uint256(range.sqrtPriceUpper);
                sqrtPriceCurrent = uint160(Math.sqrt(sqrtLower * sqrtUpper));
            }
        }

        require(
            sqrtPriceCurrent >= range.sqrtPriceLower && 
            sqrtPriceCurrent <= range.sqrtPriceUpper,
            PriceOutOfRange(sqrtPriceCurrent, range.sqrtPriceLower, range.sqrtPriceUpper)
        );

        uint128 liquidity = _getLiquidityFromAmounts(
            balance0,
            balance1,
            sqrtPriceCurrent,
            range.sqrtPriceLower,
            range.sqrtPriceUpper
        );

        uint160 sqrtPriceTarget = zeroForOne 
            ? range.sqrtPriceLower 
            : range.sqrtPriceUpper;

        (, , amountOut, ) = _computeSwapStep(
            sqrtPriceCurrent,
            sqrtPriceTarget,
            liquidity,
            amountIn,
            strategy.feeBps
        );
    }

    /// @notice Get quote for exact output amount
    function quoteExactOut(
        Strategy calldata strategy,
        bool zeroForOne,
        uint256 amountOut
    ) external view returns (uint256 amountIn) {
        SqrtPriceRange memory range = _getSqrtPriceRange(strategy);
        bytes32 strategyHash = keccak256(abi.encode(strategy));
        (, , uint256 balance0, uint256 balance1) = _getBalances(strategy, strategyHash, zeroForOne);
        
        uint160 sqrtPriceCurrent = currentSqrtPrice[strategyHash];
        if (sqrtPriceCurrent == 0) {
            if (balance0 > 0 && balance1 > 0) {
                uint256 price = (balance1 * PRICE_DECIMALS) / balance0;
                sqrtPriceCurrent = priceToSqrtPriceX96(price);
                
                if (sqrtPriceCurrent < range.sqrtPriceLower) {
                    sqrtPriceCurrent = range.sqrtPriceLower;
                } else if (sqrtPriceCurrent > range.sqrtPriceUpper) {
                    sqrtPriceCurrent = range.sqrtPriceUpper;
                }
            } else {
                uint256 sqrtLower = uint256(range.sqrtPriceLower);
                uint256 sqrtUpper = uint256(range.sqrtPriceUpper);
                sqrtPriceCurrent = uint160(Math.sqrt(sqrtLower * sqrtUpper));
            }
        }

        require(
            sqrtPriceCurrent >= range.sqrtPriceLower && 
            sqrtPriceCurrent <= range.sqrtPriceUpper,
            PriceOutOfRange(sqrtPriceCurrent, range.sqrtPriceLower, range.sqrtPriceUpper)
        );

        uint128 liquidity = _getLiquidityFromAmounts(
            balance0,
            balance1,
            sqrtPriceCurrent,
            range.sqrtPriceLower,
            range.sqrtPriceUpper
        );

        // Calculate the sqrt price after removing amountOut
        uint160 sqrtPriceNext;
        if (zeroForOne) {
            uint256 deltaY = amountOut;
            if (deltaY >= uint256(liquidity) * (sqrtPriceCurrent - range.sqrtPriceLower) / Q96) {
                sqrtPriceNext = range.sqrtPriceLower;
            } else {
                sqrtPriceNext = uint160(sqrtPriceCurrent - (deltaY * Q96) / liquidity);
            }
        } else {
            uint256 deltaX = amountOut;
            uint256 product = uint256(liquidity) * uint256(sqrtPriceCurrent);
            sqrtPriceNext = uint160((product * Q96) / (product - deltaX * Q96));
            if (sqrtPriceNext > range.sqrtPriceUpper) {
                sqrtPriceNext = range.sqrtPriceUpper;
            }
        }

        amountIn = zeroForOne
            ? _getAmount0Delta(sqrtPriceCurrent, sqrtPriceNext, liquidity)
            : _getAmount1Delta(sqrtPriceNext, sqrtPriceCurrent, liquidity);

        amountIn = (amountIn * BPS_BASE) / (BPS_BASE - strategy.feeBps);
    }

    /// @notice Get current price information for a strategy
    /// @return currentPrice The current price in regular format with 18 decimals
    /// @return sqrtPriceX96 The current sqrt price in Q64.96 format
    /// @return inRange Whether the current price is within the strategy's range
    function getStrategyPriceInfo(Strategy calldata strategy) 
        external 
        view 
        returns (
            uint256 currentPrice,
            uint160 sqrtPriceX96,
            bool inRange
        ) 
    {
        bytes32 strategyHash = keccak256(abi.encode(strategy));
        SqrtPriceRange memory range = _getSqrtPriceRange(strategy);
        
        sqrtPriceX96 = currentSqrtPrice[strategyHash];
        if (sqrtPriceX96 == 0) {
            // Not initialized yet, estimate from balances
            (, , uint256 balance0, uint256 balance1) = _getBalances(strategy, strategyHash, false);
            if (balance0 > 0 && balance1 > 0) {
                uint256 price = (balance1 * PRICE_DECIMALS) / balance0;
                sqrtPriceX96 = priceToSqrtPriceX96(price);
            } else {
                // Use geometric mean of range
                uint256 sqrtLower = uint256(range.sqrtPriceLower);
                uint256 sqrtUpper = uint256(range.sqrtPriceUpper);
                sqrtPriceX96 = uint160(Math.sqrt(sqrtLower * sqrtUpper));
            }
        }
        
        currentPrice = sqrtPriceX96ToPrice(sqrtPriceX96);
        inRange = sqrtPriceX96 >= range.sqrtPriceLower && sqrtPriceX96 <= range.sqrtPriceUpper;
    }

    /// @notice Calculate optimal token amounts to deposit for a given liquidity amount
    /// @dev Useful for LPs to know how much of each token they need
    function calculateOptimalAmounts(
        Strategy calldata strategy,
        uint128 desiredLiquidity
    ) external view returns (
        uint256 amount0,
        uint256 amount1,
        uint256 currentPrice
    ) {
        bytes32 strategyHash = keccak256(abi.encode(strategy));
        SqrtPriceRange memory range = _getSqrtPriceRange(strategy);
        
        // Get current or estimated sqrt price
        uint160 sqrtPriceCurrent = currentSqrtPrice[strategyHash];
        if (sqrtPriceCurrent == 0) {
            (, , uint256 balance0, uint256 balance1) = _getBalances(strategy, strategyHash, false);
            if (balance0 > 0 && balance1 > 0) {
                uint256 price = (balance1 * PRICE_DECIMALS) / balance0;
                sqrtPriceCurrent = priceToSqrtPriceX96(price);
                
                if (sqrtPriceCurrent < range.sqrtPriceLower) {
                    sqrtPriceCurrent = range.sqrtPriceLower;
                } else if (sqrtPriceCurrent > range.sqrtPriceUpper) {
                    sqrtPriceCurrent = range.sqrtPriceUpper;
                }
            } else {
                uint256 sqrtLower = uint256(range.sqrtPriceLower);
                uint256 sqrtUpper = uint256(range.sqrtPriceUpper);
                sqrtPriceCurrent = uint160(Math.sqrt(sqrtLower * sqrtUpper));
            }
        }
        
        // Calculate amounts from liquidity
        (amount0, amount1) = _getAmountsFromLiquidity(
            desiredLiquidity,
            sqrtPriceCurrent,
            range.sqrtPriceLower,
            range.sqrtPriceUpper
        );
        
        currentPrice = sqrtPriceX96ToPrice(sqrtPriceCurrent);
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
