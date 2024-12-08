// SPDX-License-Identifier: MIT

pragma solidity 0.8.27;

interface ILiquidityManager {
    /**
     * @notice The parameters for removing and adding liquidity, which include:
     * @param removeParams
     * - `fromBinStep`: the binStep range to withdraw id positions.
     * - `ids`: the id positions to withdraw.
     * @param addParams
     * - `toBinStep`: the binStep range to reallocate.
     * - `activeIdDesired`: The active id that user wants to add liquidity.
     * - `idSlippage`: The number of id that are allowed to slip
     * - `deltaIds`: The list of delta ids to add liquidity (`deltaId = activeId - desiredId`).
     * - `distributionX`: The distribution of tokenX with sum(distributionX) = 1e18 (100%) or 0 (0%)
     * - `distributionY`: The distribution of tokenY with sum(distributionY) = 1e18 (100%) or 0 (0%)
     * - `deadline`:  The deadline of the transaction
     */
    struct RemoveAndAddLiquidityParams {
        uint16[] fromBinSteps;
        uint256[][] ids;
        uint16 toBinStep;
        uint24 activeIdDesired;
        uint256 idSlippage;
        int256[] deltaIds;
        uint256[] distributionX;
        uint256[] distributionY;
        uint256 deadline;
    }

    /**
     * @notice Removes liquidity
     * @param fromBinStep binStep to remove liquidity from
     * @param ids positions ids in the LBPair's binStep
     * @param deadline deadline of the transaction
     */
    struct RemoveLiquidityParams {
        uint16 fromBinStep;
        uint256[] ids;
        uint256 deadline;
    }

    /**
     * @notice Withdraw all liquidity to the Admin's wallet.
     * @dev No params required so that withdraw all the Pool Balance
     * @param binSteps the ranges in a pair to withdraw from
     * @param ids the ids in the ranges pairs to withdraw from
     */
    function withdraw(uint16[] memory binSteps, uint256[][] memory ids, uint256 deadline)
        external
        returns (uint256 totalXRemoved, uint256 totalYRemoved);

    /**
     * @notice Withdraw all liquidity to the Admin's wallet.
     * @param binStep range in a Pair to Withdraw from
     * @param ids in the range Pair to withdraw from
     */
    function withdrawFromPair(uint16 binStep, uint256[] calldata ids, uint256 deadline) external;
    /**
     * @notice only the bot can call it so that reallocate liquidity based on it's off-chain computed strategy
     * @param params the RemoveAndAddLiquidityParams
     */
    function removeAndAddLiquidity(RemoveAndAddLiquidityParams memory params) external;
}
