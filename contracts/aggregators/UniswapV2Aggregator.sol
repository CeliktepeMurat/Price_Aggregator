// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "../helpers/SafeMath.sol";
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
    bool[] public isPeggedToEth;
    uint8[] public decimals;
    uint256 public immutable maxPriceDeviation;

    constructor(
        IUniswapV2Pair _pair, 
        IPriceOracle _priceOracle,
        uint256 _maxPriceDeviation,
        bool[] memory _isPeggedToEth,
        uint8[] memory _decimals) {
        require(_isPeggedToEth.length == 2, "ERR_INVALID_PEGGED_LENGTH");
        require(_decimals.length == 2, "ERR_INVALID_DECIMALS_LENGTH");
        require(address(_priceOracle) != address(0), "ERR_INVALID_PRICE_ORACLE");
        require(_maxPriceDeviation < BONE, "ERR_INVALID_MAX_PRICE_DEVIATION");

        pair = _pair;
        priceOracle = _priceOracle;
        maxPriceDeviation = _maxPriceDeviation;
        isPeggedToEth = _isPeggedToEth;
        decimals = _decimals;
    }
}