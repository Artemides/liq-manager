// SPDX-License-Identifier: MIT

pragma solidity 0.8.27;

import "openzeppelin-contracts/contracts/access/AccessControl.sol";
import {ILiquidityMananger} from "./interfaces/LiquidityManager.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/ILBRouter.sol";
import "./interfaces/ILBPair.sol";

contract LiquidityManager is AccessControl {
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    bytes32 public constant OBSERVER_ROLE = keccak256("OBSERVER_ROLE");
    uint256 public constant PRESITION = 1e18;

    enum Version {
        V1,
        V2,
        V2_1,
        V2_2
    }

    IERC20 tokenX;
    IERC20 tokenY;
    ILBRouter router;

    event LiquidityWithdraw(uint256 amount);
    event LiquidityReallocated(
        uint256 amountXAdded,
        uint256 amountYAdded,
        uint256 amountXLeft,
        uint256 amountYLeft,
        uint256[] depositIds,
        uint256[] liquidityMinted
    );

    error UnsupportedVersion();

    constructor(address _tokenX, address _tokenY, address _router, address admin, address executor) {
        tokenX = IERC20(_tokenX);
        tokenY = IERC20(_tokenY);
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(EXECUTOR_ROLE, executor);
        router = ILBRouter(_router);
    }

    function withdraw() external onlyRole(DEFAULT_ADMIN_ROLE) {}

    function removeAndAddLiquidity(
        uint16 fromBinStep,
        uint16 toBinStep,
        uint256[] calldata ids,
        uint24 activeIdDesired,
        uint256 idSlippage,
        int256[] calldata deltaIds,
        uint256[] calldata distributionX,
        uint256[] calldata distributionY,
        uint256 deadline
    ) external onlyRole(EXECUTOR_ROLE) {
        ILBPair pair = ILBPair(_getPair(fromBinStep));
        uint256 totalXBalanceWithdrawn;
        uint256 totalYBalanceWithdrawn;
        uint256[] memory amounts = new uint256[](ids.length);
        // To figure out amountXMin and amountYMin, we calculate how much X and Y underlying we have as liquidity

        for (uint256 i; i < ids.length; i++) {
            uint256 LBTokenAmount = pair.balanceOf(address(this), ids[i]);
            amounts[i] = LBTokenAmount;
            (uint256 binReserveX, uint256 binReserveY) = pair.getBin(uint24(ids[i]));

            totalXBalanceWithdrawn += LBTokenAmount * binReserveX / pair.totalSupply(ids[i]);
            totalYBalanceWithdrawn += LBTokenAmount * binReserveY / pair.totalSupply(ids[i]);
        }
        uint256 amountXMin = totalXBalanceWithdrawn * 99 / 100; // Allow 1% slippage
        uint256 amountYMin = totalYBalanceWithdrawn * 99 / 100; // Allow 1% slippage

        pair.approveForAll(address(router), true);

        (uint256 amountX, uint256 amountY) = router.removeLiquidity(
            tokenX, tokenY, fromBinStep, amountXMin, amountYMin, ids, amounts, address(this), deadline
        );

        amountXMin = amountX * 99 / 100; // Allow 1% slippage
        amountYMin = amountY * 99 / 100; // Allow 1% slippage

        ILBRouter.LiquidityParameters memory liqParams = ILBRouter.LiquidityParameters({
            tokenX: tokenX,
            tokenY: tokenY,
            binStep: toBinStep,
            amountX: amountX,
            amountY: amountY,
            amountXMin: amountXMin,
            amountYMin: amountYMin,
            activeIdDesired: activeIdDesired,
            idSlippage: idSlippage,
            deltaIds: deltaIds,
            distributionX: distributionX,
            distributionY: distributionY,
            to: address(this),
            refundTo: address(this),
            deadline: deadline
        });

        tokenX.approve(address(router), amountX);
        tokenY.approve(address(router), amountY);
        (
            uint256 amountXAdded,
            uint256 amountYAdded,
            uint256 amountXLeft,
            uint256 amountYLeft,
            uint256[] memory depositIds,
            uint256[] memory liquidityMinted
        ) = router.addLiquidity(liqParams);

        emit LiquidityReallocated(amountXAdded, amountYAdded, amountXLeft, amountYLeft, depositIds, liquidityMinted);
    }

    function _getPair(uint256 binStep) private view returns (address pair) {
        pair = address(router.getFactory().getLBPairInformation(tokenX, tokenY, binStep).LBPair);
    }
}
