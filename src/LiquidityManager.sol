// SPDX-License-Identifier: MIT

pragma solidity 0.8.27;

contract LiquidityPool {
    address token0;
    address token1;

    event LiquidityWithdraw(uint256 amount);
    event Liquidity
    constructor(address _token0, address _token1) {
        token0 = _token0;
        token1 = _token1;
    }
}
