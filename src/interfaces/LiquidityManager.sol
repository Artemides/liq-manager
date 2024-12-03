// SPDX-License-Identifier: MIT

pragma solidity 0.8.27;

interface ILiquidityMananger {
    /**
     * @notice Withdraw all liquidity to the Admin's wallet.
     * @dev No params required so that withdraw all the Pool Balance
     */
    function withdraw() external;

    /**
     * @notice callable by the executor (Bot)
     * @dev Include a mechanism to ensure the bot does not unintentionally drain liquidity due to bugs or malicious inputs
     */
    function removeAndAddLiquidity(
        uint256 token0,
        uint256 token1,
        uint256 removeAmount,
        uint256 addAmount,
        uint64 deadline
    ) external;
}
