// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "../helpers/SafeMath.sol";
import "../helpers/Math.sol";
import "../interfaces/IUniswapV2Pair.sol";
import "../interfaces/IUniswapV2Factory.sol";
import "../interfaces/IPriceOracle.sol";

/** @title UniswapV2Aggregator
    @notice Price Aggregator for Uniswap V2 pairs
    @notice It calculates price using Chainlink as an external Price source
    @notice If there is a price deviation, instead of the reserves, it uses a wighted geometric mean with constant invariant K.
 */
contract UnipswapV2Aggregator {
    using SafeMath for uint256;

    uint256 public constant BONE = 10**18;
    IUniswapV2Pair public immutable pair;
    IPriceOracle immutable priceOracle;
    address[] public tokens;
    uint8[] public decimals;

    uint256 public immutable maxPriceDeviation;

    constructor(
        IUniswapV2Pair _pair,
        IPriceOracle _priceOracle,
        uint256 _maxPriceDeviation,
        uint8[] memory _decimals
    ) {
        require(_decimals.length == 2, "ERR_INVALID_DECIMALS_LENGTH");
        require(
            address(_priceOracle) != address(0),
            "ERR_INVALID_PRICE_ORACLE"
        );
        require(_maxPriceDeviation < BONE, "ERR_INVALID_MAX_PRICE_DEVIATION");

        pair = _pair;
        priceOracle = _priceOracle;
        maxPriceDeviation = _maxPriceDeviation;
        decimals = _decimals;

        // add tokens to array
        tokens.push(_pair.token0());
        tokens.push(_pair.token1());
    }

    ////// VIEW FUNCTIONS /////////////////
    /**
     * Returns Uniswap V2 pair address.
     */
    function getPair() external view returns (IUniswapV2Pair) {
        return pair;
    }

    /**
     * Returns all tokens.
     */
    function getTokens() external view returns (address[] memory) {
        return tokens;
    }

    /**
     * @dev Returns the LP shares token
     * @return address of the LP shares token
     */
    function getToken() external view returns (address) {
        return address(pair);
    }

    //////////   WRITE FUNCTIONS   //////////

    function getEthBalanceByToken(uint256 _index, uint112 _reserve)
        internal
        view
        returns (uint256)
    {
        uint256 tokenPrice = uint256(priceOracle.getAssetPrice(tokens[_index]));
        require(tokenPrice > 0, "ERR_NO_ORACLE_PRICE");

        uint256 missingDecimals = uint256(18).sub(decimals[_index]);
        uint256 tokenReserve = uint256(_reserve).mul(10**(missingDecimals));
        return Math.bmul(tokenReserve, tokenPrice);
    }

    /**
     * Returns true if there is a price deviation
     * @param ethTotal_0 total eth balance of token0
     * @param ethTotal_1 total eth balance of token1
     */
    function isThereDeviation(uint256 ethTotal_0, uint256 ethTotal_1)
        internal
        view
        returns (bool)
    {
        uint256 price_deviation = Math.bdiv(ethTotal_0, ethTotal_1);

        if (
            price_deviation > BONE.add(maxPriceDeviation) ||
            price_deviation < BONE.sub(maxPriceDeviation)
        ) {
            return true;
        }

        price_deviation = Math.bdiv(ethTotal_1, ethTotal_0);

        if (
            price_deviation > BONE.add(maxPriceDeviation) ||
            price_deviation < BONE.sub(maxPriceDeviation)
        ) {
            return true;
        }

        return false;
    }

    /**
     * Calculates the price of the pair token using the formula of arithmetic mean.
     * @param ethTotal_0 Total eth for token 0.
     * @param ethTotal_1 Total eth for token 1.
     */
    function getArithmeticMean(uint256 ethTotal_0, uint256 ethTotal_1)
        internal
        view
        returns (uint256)
    {
        uint256 totalEth = ethTotal_0 + ethTotal_1;
        return Math.bdiv(totalEth, getTotalSupplyAtWithdrawal());
    }

    function getWeightedGeometricMean(uint256 ethTotal_0, uint256 ethTotal_1)
        internal
        view
        returns (uint256)
    {
        uint256 square = Math.bsqrt(Math.bmul(ethTotal_0, ethTotal_1), true);

        return
            Math.bdiv(
                Math.bmul(Math.TWO_BONES, square),
                getTotalSupplyAtWithdrawal()
            );
    }

    /**
     * Returns Uniswap V2 pair total supply at the time of withdrawal.
     */
    function getTotalSupplyAtWithdrawal()
        private
        view
        returns (uint256 totalSupply)
    {
        totalSupply = pair.totalSupply();
        address feeTo = IUniswapV2Factory(IUniswapV2Pair(pair).factory())
            .feeTo();
        bool feeOn = feeTo != address(0);
        if (feeOn) {
            uint256 kLast = IUniswapV2Pair(pair).kLast();
            if (kLast != 0) {
                (uint112 reserve_0, uint112 reserve_1, ) = pair.getReserves();
                uint256 rootK = Math.bsqrt(
                    uint256(reserve_0).mul(reserve_1),
                    false
                );
                uint256 rootKLast = Math.bsqrt(kLast, false);
                if (rootK > rootKLast) {
                    uint256 numerator = totalSupply.mul(rootK.sub(rootKLast));
                    uint256 denominator = rootK.mul(5).add(rootKLast);
                    uint256 liquidity = numerator / denominator;
                    totalSupply = totalSupply.add(liquidity);
                }
            }
        }
    }

    /**
     * @dev Returns the pair's token price.
     *   It calculates the price using Chainlink as an external price source and the pair's tokens reserves using the arithmetic mean formula.
     *   If there is a price deviation, instead of the reserves, it uses a weighted geometric mean with constant invariant K.
     * @return int256 price
     */
    function latestAnswer() external view returns (int256) {
        // Get token reserves
        (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();

        uint256 eth_Total_0 = getEthBalanceByToken(0, reserve0);
        uint256 eth_Total_1 = getEthBalanceByToken(1, reserve1);

        if (isThereDeviation(eth_Total_0, eth_Total_1)) {
            //Calculate the weighted geometric mean
            return int256(getWeightedGeometricMean(eth_Total_0, eth_Total_1));
        } else {
            //Calculate the arithmetic mean
            return int256(getArithmeticMean(eth_Total_0, eth_Total_1));
        }
    }
}
