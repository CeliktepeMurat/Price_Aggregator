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
        
        pair = _pair;
        priceOracle = _priceOracle;
        maxPriceDeviation = _maxPriceDeviation;
        isPeggedToEth = _isPeggedToEth;
        decimals = _decimals;
    }
}