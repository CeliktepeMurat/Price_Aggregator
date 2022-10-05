// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "../helpers/SafeMath.sol";
import "../helpers/Math.sol";
import "../interfaces/IUniswapV2Pair.sol";
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

    function latestAnswer() external view returns (int256) {
        // Get token reserves
        (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();

        uint256 eth_Total_0 = getEthBalanceByToken(0, reserve0);
        uint256 eth_Total_1 = getEthBalanceByToken(1, reserve1);
    }
}
