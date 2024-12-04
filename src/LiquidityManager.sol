// SPDX-License-Identifier: MIT

pragma solidity 0.8.27;

import "openzeppelin-contracts/contracts/access/AccessControl.sol";
import "./interfaces/ILiquidityManager.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/ILBRouter.sol";
import "./interfaces/ILBPair.sol";
import "lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

contract LiquidityManager is UUPSUpgradeable, AccessControl, ILiquidityManager {
    struct PairDetails {
        address pairAddress;
        uint256 binStep;
    }

    // roles used by Access Controll to manage admin and excutor
    // the admin can also upgrate to new implementations
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    uint256 public constant PRESITION = 1e18;

    //Pair Addreses such USDT/USDX
    address admin;
    address executor;
    IERC20 tokenX;
    IERC20 tokenY;
    ILBRouter router;

    // tracks the pairs where the contract deposited liquidity into
    PairDetails[] accountPairs;
    // indexes of pairs in the accountPairs
    mapping(address => uint256) public pairIndex;
    mapping(address => mapping(uint256 => bool)) public trackedIds;
    mapping(address => uint256[]) public pairIds;
    mapping(address => mapping(uint256 => uint256)) public pairIdIndex;

    event LiquidityReallocated(
        uint256 amountXRemoved, uint256 amountYRemoved, uint256 amountXAdded, uint256 amountYAdded
    );
    event Withdraw(uint256 amountX, uint256 amountY);
    /**
     * @notice Initializes the Proxy contract with the specified parameters.
     *
     * This function sets up initial values for token addresses, the router, roles, and grants them to the provided accounts.
     * Additionally, it sets the router and initializes the account pairs.
     *
     * The function is called only once when the contract is deployed or upgraded, and the contract is initialized with specific addresses
     * and roles that control the contract's functionality.
     *
     * @param _tokenX The address of the token X contract required for the LBPair.
     * @param _tokenY The address of the token Y contrac required for the LBPair.
     * @param _router The address of the router of Joe's AMM.
     * @param _admin The address of the account to be granted the `DEFAULT_ADMIN_ROLE` and `ADMIN_ROLE`.
     * @param _executor The address of the bot or account to be granted the `EXECUTOR_ROLE` .
     */

    function initialize(address _tokenX, address _tokenY, address _router, address _admin, address _executor)
        public
        initializer
    {
        __UUPSUpgradeable_init();
        tokenX = IERC20(_tokenX);
        tokenY = IERC20(_tokenY);
        admin = _admin;
        executor = _executor;
        //grant Roles
        _setRoleAdmin(ADMIN_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(EXECUTOR_ROLE, ADMIN_ROLE);
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
        _grantRole(EXECUTOR_ROLE, executor);
        router = ILBRouter(_router);

        //tracking protection
        PairDetails memory details;
        accountPairs.push(details);
    }

    /**
     * @notice removes All liquidity from ranges and ids then trasfer tho admin address
     * @param binSteps the prince ranges to withdraw from
     * @param ids the id positionsin the LBPair to withdraw from
     * @param deadline the deadline of the Tx
     * @dev in case of removing all the pairs and positions an uprade is required with probably tracking pairs and positions when the contract add or removes liquidity.
     */
    function withdraw(uint16[] memory binSteps, uint256[][] calldata ids, uint256 deadline)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        returns (uint256 totalXRemoved, uint256 totalYRemoved)
    {
        (totalXRemoved, totalYRemoved) = _removeAllLiquidity(binSteps, ids, deadline);

        tokenX.transfer(admin, totalXRemoved);
        tokenY.transfer(admin, totalYRemoved);
        emit Withdraw(totalXRemoved, totalYRemoved);
    }

    /**
     * @notice removes liquidity from range and ids then trasfer tho admin address
     * @param fromBinStep the prince range to withdraw from
     * @param ids the id positionsin the LBPair to withdraw from
     * @param deadline the deadline of the Tx
     * @dev in case of removing all the pairs and positions an uprade is required with probably tracking pairs and positions when the contract add or removes liquidity.
     */
    function withdrawFromPair(uint16 fromBinStep, uint256[] calldata ids, uint256 deadline)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        (uint256 amountXRemoved, uint256 amountYRemoved) =
            _removeLiquidity(RemoveLiquidityParams(fromBinStep, ids, deadline));

        tokenX.transfer(admin, amountXRemoved);
        tokenY.transfer(admin, amountYRemoved);
    }

    function depositAllLiquidity(
        uint256 binStep,
        uint256 activeIdDesired,
        uint256 idSlippage,
        int256[] memory deltaIds,
        uint256[] memory distributionX,
        uint256[] memory distributionY,
        uint32 deadline
    ) public onlyRole(EXECUTOR_ROLE) {
        uint256 amountX = tokenX.balanceOf(address(this));
        uint256 amountY = tokenY.balanceOf(address(this));

        tokenX.approve(address(router), amountX);
        tokenY.approve(address(router), amountX);

        ILBRouter.LiquidityParameters memory liqParams = ILBRouter.LiquidityParameters({
            tokenX: tokenX,
            tokenY: tokenY,
            binStep: binStep,
            amountX: amountX,
            amountY: amountY,
            amountXMin: _slippage(amountX, 1), // Allow 1% slippage
            amountYMin: _slippage(amountY, 1), // Allow 1% slippage
            activeIdDesired: activeIdDesired,
            idSlippage: idSlippage,
            deltaIds: deltaIds,
            distributionX: distributionX,
            distributionY: distributionY,
            to: address(this),
            refundTo: address(this),
            deadline: deadline
        });

        router.addLiquidity(liqParams);
    }

    /**
     * @notice Removes and re-adds liquidinty from Pairs and ids, to reallocate based on bot's strategy
     * @param params RemoveAndAddLiquidityParams for reallocations
     */
    function removeAndAddLiquidity(RemoveAndAddLiquidityParams memory params) external onlyRole(EXECUTOR_ROLE) {
        //Remove liquidity from binSteps and ids (all)
        (uint256 amountXRemoved, uint256 amountYRemoved) =
            _removeAllLiquidity(params.fromBinSteps, params.ids, params.deadline);
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
            deadline: params.deadline
        });

        tokenX.approve(address(router), amountXRemoved);
        tokenY.approve(address(router), amountYRemoved);

        (uint256 amountXAdded, uint256 amountYAdded,,,,) = router.addLiquidity(liqParams);
        emit LiquidityReallocated(amountXRemoved, amountYRemoved, amountXAdded, amountYAdded);
    }

    /**
     * @notice removes All liquidity from ranges and ids to this contract
     * @param binSteps the prince ranges to withdraw from
     * @param ids the id positionsin the LBPair to withdraw from
     * @param deadline the deadline of the Tx
     * @dev in case of removing all the pairs and positions an uprade is required with probably tracking pairs and positions when the contract add or removes liquidity.
     */
    function _removeAllLiquidity(uint16[] memory binSteps, uint256[][] memory ids, uint256 deadline)
        internal
        returns (uint256 totalXRemoved, uint256 totalYRemoved)
    {
        totalXRemoved;
        totalYRemoved;
        for (uint256 i; i < binSteps.length; i++) {
            (uint256 amountXRemoved, uint256 amountYRemoved) =
                _removeLiquidity(RemoveLiquidityParams(binSteps[i], ids[i], deadline));
            totalXRemoved += amountXRemoved;
            totalYRemoved += amountYRemoved;
        }
    }
    /**
     * @notice Removes liquidity
     * @param params binSteps and ids to remove liquidity from
     */

    function _removeLiquidity(RemoveLiquidityParams memory params)
        internal
        returns (uint256 amountXRemoved, uint256 amountYRemoved)
    {
        ILBPair pair = ILBPair(getPair(params.fromBinStep));

        uint256[] memory amounts = new uint256[](params.ids.length);
        uint256 amountXMin;
        uint256 amountYMin;
        // To figure out amountXMin and amountYMin, we calculate how much X and Y underlying we have as liquidity
        for (uint256 i; i < params.ids.length; i++) {
            uint256 LBTokenAmount = pair.balanceOf(address(this), params.ids[i]);
            amounts[i] = LBTokenAmount;
            (uint256 binReserveX, uint256 binReserveY) = pair.getBin(uint24(params.ids[i]));

            amountXMin += LBTokenAmount * binReserveX / pair.totalSupply(params.ids[i]);
            amountYMin += LBTokenAmount * binReserveY / pair.totalSupply(params.ids[i]);
        }
        amountXMin = _slippage(amountXMin, 1); // Allow 1% slippage
        amountYMin = _slippage(amountYMin, 1);

        pair.approveForAll(address(router), true);

        (amountXRemoved, amountYRemoved) = router.removeLiquidity(
            tokenX,
            tokenY,
            params.fromBinStep,
            amountXMin,
            amountYMin,
            params.ids,
            amounts,
            address(this),
            params.deadline
        );
    }

    /**
     * @notice computes a sliapge
     * @param amount amount used to get percentage slippage
     * @param percentage the slippage percentage to apply
     */
    function _slippage(uint256 amount, uint256 percentage) internal pure returns (uint256) {
        if (percentage > 100) {
            percentage = 100;
        }
        return amount * (100 - percentage) / 100; // Allow 1% slippage
    }

    /**
     * @notice calculates the Pair for the tokenX and tokenY
     * @param binStep the range to get the Pair
     */
    function getPair(uint256 binStep) public view returns (address pair) {
        pair = address(router.getFactory().getLBPairInformation(tokenX, tokenY, binStep).LBPair);
    }

    /**
     * @notice track all the Pairs and Ids where the account holds liquidity
     * @dev this process is cheaper off-chain, by tracking on chain it will only increase
     * the gas cost per remove and add liquidity
     */
    function _trackPair(uint256 binStep, uint256[] memory ids, bool add) internal {
        address pair = getPair(binStep);
        uint256 pairAt = pairIndex[pair];
        if (pairAt == 0) {
            pairIndex[pair] = accountPairs.length;
            accountPairs.push(PairDetails(pair, binStep));
        }

        for (uint256 i = 0; i < ids.length; i++) {
            uint256 id = ids[i];
            if (add || pairAt == 0) {
                if (!trackedIds[pair][id] && pairIds[pair].length > 0) {
                    pairIdIndex[pair][id] = pairIds[pair].length;
                    pairIds[pair].push(id);
                    trackedIds[pair][id] = true;
                }
                continue;
            }

            if (trackedIds[pair][id]) {
                uint256 lastIndex = pairIds[pair].length - 1;
                uint256 lastId = pairIds[pair][lastIndex];
                uint256 idIndex = pairIdIndex[pair][id];
                pairIds[pair][idIndex] = lastId;

                delete pairIds[pair][lastIndex];
                delete trackedIds[pair][id];
            }
        }
    }

    /**
     * @notice removes from tracking the Pair and positions where the contract no more liquidity is available
     * @param binStep range whete the user holds liquidity
     */
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

    /**
     * @notice override proxy admin grants
     */
    function _authorizeUpgrade(address) internal override onlyRole(ADMIN_ROLE) {}
}
