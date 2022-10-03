// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.17;

/************
@title IPriceOracle interface
*/

interface IPriceOracle {
  /***********
    @dev returns the asset price in ETH
     */
  function getAssetPrice(address _asset) external view returns (uint256);
}