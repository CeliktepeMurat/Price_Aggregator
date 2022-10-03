// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "../helpers/SafeMath.sol";
import "../interfaces/IUniswapV2Pair.sol";

/** @title UniswapV2Aggregator
    @notice Price Aggregator for Uniswap V2 pairs
    @notice It calculates price using Chainlink as an external Price source
    @notice If there is a price deviation, instead of the reserves, it uses a wighted geometric mean with constant invariant K.
 */
contract UnipswapV2Aggregator {
    using SafeMath for uint256;

    IUniswapV2Pair public immutable pair;


    constructor(IUniswapV2Pair _pair) {
        pair = _pair;
    }
}