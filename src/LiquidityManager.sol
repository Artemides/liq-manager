// SPDX-License-Identifier: MIT

pragma solidity 0.8.27;

import "openzeppelin-contracts/contracts/access/AccessControl.sol";
import {ILiquidityMananger} from "./interfaces/LiquidityManager.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/ILBRouter.sol";
import "./interfaces/ILBPair.sol";
import "lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

contract LiquidityManager is UUPSUpgradeable, AccessControl {
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    uint256 public constant PRESITION = 1e18;

    enum Version {
        V1,
        V2,
        V2_1,
        V2_2
    }

    struct PairDetails {
        address pairAddress;
        uint256[] ids;
    }

    struct RemoveAndAddLiquidityParams {
        uint16 fromBinStep;
        uint16 toBinStep;
        uint256[] ids;
        uint24 activeIdDesired;
        uint256 idSlippage;
        int256[] deltaIds;
        uint256[] distributionX;
        uint256[] distributionY;
        uint256 deadline;
    }

    IERC20 tokenX;
    IERC20 tokenY;
    ILBRouter router;

    PairDetails[] accountPairs;
    mapping(address => uint256) private pairIndex;

    event LiquidityWithdraw(uint256 amount);
    event LiquidityReallocated(
        uint256 amountXRemoved, uint256 amountYRemoved, uint256 amountXAdded, uint256 amountYAdded
    );

    error UnsupportedVersion();

    function initialize(address _tokenX, address _tokenY, address _router, address admin, address executor)
        public
        initializer
    {
        __UUPSUpgradeable_init();
        tokenX = IERC20(_tokenX);
        tokenY = IERC20(_tokenY);
        _setRoleAdmin(ADMIN_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(EXECUTOR_ROLE, ADMIN_ROLE);

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
        _grantRole(EXECUTOR_ROLE, executor);
        router = ILBRouter(_router);

        accountPairs.push(PairDetails(address(0), new uint256[](0)));
    }

    function withdraw(uint16 fromBinStep, uint256[] calldata ids, uint256 deadline)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _removeLiquidity(fromBinStep, ids, block.timestamp + deadline);
    }

    function removeAndAddLiquidity(RemoveAndAddLiquidityParams memory params) external onlyRole(EXECUTOR_ROLE) {
        //deallocate liquidity from ids s
        (uint256 amountXRemoved, uint256 amountYRemoved) =
            _removeLiquidity(params.fromBinStep, params.ids, params.deadline);
        //allocate liquidty based on bot analysis  and available
        ILBRouter.LiquidityParameters memory liqParams = ILBRouter.LiquidityParameters({
            tokenX: tokenX,
            tokenY: tokenY,
            binStep: params.toBinStep,
            amountX: amountXRemoved,
            amountY: amountYRemoved,
            amountXMin: _slippage(amountXRemoved, 1), // Allow 1% slippage
            amountYMin: _slippage(amountYRemoved, 1), // Allow 1% slippage
            activeIdDesired: params.activeIdDesired,
            idSlippage: params.idSlippage,
            deltaIds: params.deltaIds,
            distributionX: params.distributionX,
            distributionY: params.distributionY,
            to: address(this),
            refundTo: address(this),
            deadline: block.timestamp + params.deadline
        });

        tokenX.approve(address(router), amountXRemoved);
        tokenY.approve(address(router), amountYRemoved);

        (uint256 amountXAdded, uint256 amountYAdded,,,,) = router.addLiquidity(liqParams);
        emit LiquidityReallocated(amountXRemoved, amountYRemoved, amountXAdded, amountYAdded);
    }

    function _removeLiquidity(uint16 fromBinStep, uint256[] memory ids, uint256 deadline)
        internal
        returns (uint256 amountXRemoved, uint256 amountYRemoved)
    {
        ILBPair pair = ILBPair(getPair(fromBinStep));

        uint256[] memory amounts = new uint256[](ids.length);
        uint256 amountXMin;
        uint256 amountYMin;
        // To figure out amountXMin and amountYMin, we calculate how much X and Y underlying we have as liquidity
        for (uint256 i; i < ids.length; i++) {
            uint256 LBTokenAmount = pair.balanceOf(address(this), ids[i]);
            amounts[i] = LBTokenAmount;
            (uint256 binReserveX, uint256 binReserveY) = pair.getBin(uint24(ids[i]));

            amountXMin += LBTokenAmount * binReserveX / pair.totalSupply(ids[i]);
            amountYMin += LBTokenAmount * binReserveY / pair.totalSupply(ids[i]);
        }
        amountXMin = _slippage(amountXMin, 1); // Allow 1% slippage
        amountYMin = _slippage(amountYMin, 1);

        pair.approveForAll(address(router), true);

        (amountXRemoved, amountYRemoved) = router.removeLiquidity(
            tokenX, tokenY, fromBinStep, amountXMin, amountYMin, ids, amounts, address(this), block.timestamp + deadline
        );
    }

    function _slippage(uint256 amount, uint256 percentage) internal pure returns (uint256) {
        return amount * (100 - percentage) / 100; // Allow 1% slippage
    }

    function getPair(uint256 binStep) public view returns (address pair) {
        pair = address(router.getFactory().getLBPairInformation(tokenX, tokenY, binStep).LBPair);
    }

    function _addPair(uint256 binStep, uint256[] memory ids) internal {
        address pair = getPair(binStep);
        if (pairIndex[pair] == 0) {
            pairIndex[pair] = accountPairs.length;
            accountPairs.push(PairDetails(pair, ids));
        }
    }

    function _removePair(uint256 binStep) internal {
        address pair = getPair(binStep);
        uint256 pairAt = pairIndex[pair];
        require(pairAt != 0, "Pair does not exist");

        PairDetails memory lastPair = accountPairs[accountPairs.length - 1];
        accountPairs[pairAt] = lastPair;
        accountPairs.pop();
        pairIndex[lastPair.pairAddress] = pairAt;
        delete pairIndex[pair];
    }

    function _authorizeUpgrade(address) internal override onlyRole(EXECUTOR_ROLE) {}
}
