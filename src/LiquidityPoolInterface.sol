// SPDX-License-Identifier: MIT

pragma solidity 0.8.27;

interface LiquidityPool {
    /**
     * @notice Withdraw all liquidity to the Admin's wallet.
     * @dev No params required so that withdraw all the Pool Balance
     */
    function withdraw() external;

    /**
     * @notice
     * @dev callable by the executor (Bot)
     */
    function removeAndAddLiquidity() external;
}
