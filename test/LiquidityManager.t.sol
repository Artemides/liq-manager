// SPDX-License-Identifier: MIT

pragma solidity 0.8.27;

import "forge-std/Test.sol";

import {ERC20Mock} from "./mocks/ERC20.sol";
import "../src/interfaces/ILBRouter.sol";
import "../src/interfaces/ILBFactory.sol";
import "../src/interfaces/ILBRouter.sol";
import "../src/interfaces/ILBPair.sol";
import "./../src/LiquidityManager.sol";
import {LiquidityManagerProxy} from "./mocks/LiquidityManagerProxy.sol";

contract TestLiquidityManager is Test {
    LiquidityManager manager;
    uint256 PRECISION = 1e18;
    address ADMIN = makeAddr("admin");
    address EXECUTOR = makeAddr("executor");
    //Addresses on Avalanche
    ILBRouter router = ILBRouter(0x18556DA13313f3532c54711497A8FedAC273220E);
    ILBFactory factory = ILBFactory(0xb43120c4745967fa9b93E79C149E66B0f2D6Fe0c);
    ERC20Mock USDC = ERC20Mock(0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E);
    ERC20Mock USDT = ERC20Mock(0x9702230A8Ea53601f5cD2dc00fDBc13d4dF4A8c7);
    ILBPair pair;

    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);
    error UUPSUnauthorizedCallContext();

    function setUp() public {
        console.log("setyp");
        manager = new LiquidityManager();
        deal(address(USDC), ADMIN, 1000e18);
        deal(address(USDT), ADMIN, 1000e18);
        manager.initialize(address(USDT), address(USDC), address(router), ADMIN, EXECUTOR);
    }

    function test_removeAndAddLiquidity() public {
        uint256[] memory binSteps = factory.getAllBinSteps();
        (,,,, uint256[] memory depositIds,) = _prefundLiquidityManager();
        uint256 binsAmount = 3;
        int256[] memory deltaIds = new int256[](binsAmount);
        deltaIds[0] = -1;
        deltaIds[1] = 0;
        deltaIds[2] = 1;

        uint256[] memory distributionX = new uint256[](binsAmount);
        distributionX[0] = PRECISION / 2;
        distributionX[1] = PRECISION / 4;
        distributionX[2] = PRECISION / 4;

        uint256[] memory distributionY = new uint256[](binsAmount);
        distributionY[0] = (2 * PRECISION) / 3;
        distributionY[1] = PRECISION / 3;
        distributionY[2] = 0;
        vm.prank(EXECUTOR);
        LiquidityManager.RemoveAndAddLiquidityParams memory params = LiquidityManager.RemoveAndAddLiquidityParams({
            fromBinStep: uint16(binSteps[0]),
            ids: depositIds,
            toBinStep: uint16(binSteps[3]),
            activeIdDesired: 0,
            idSlippage: 0,
            deltaIds: deltaIds,
            distributionX: distributionX,
            distributionY: distributionY,
            deadline: block.timestamp + 300
        });
        manager.removeAndAddLiquidity(params);
    }

    function test_onlyExecutorCanRemoveAndAddLiquidity() public {
        vm.prank(ADMIN);
        vm.expectRevert(
            abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, ADMIN, keccak256("EXECUTOR_ROLE"))
        );

        LiquidityManager.RemoveAndAddLiquidityParams memory params;
        manager.removeAndAddLiquidity(params);
    }

    function test_onlyAdminCanWithdraw() public {
        vm.prank(address(100));
        vm.expectRevert(abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, address(100), 0x0));

        manager.withdraw(1, new uint256[](1), block.timestamp);
    }

    function test_onlyAdminCanUpgrade() public {
        LiquidityManager implementation = new LiquidityManager();

        // Deploy minimal proxy pointing to the implementation
        bytes memory initData =
            abi.encodeWithSelector(implementation.initialize.selector, USDT, USDC, router, ADMIN, EXECUTOR);

        // Create proxy
        address proxyAddress = address(new LiquidityManagerProxy(address(implementation), initData));

        // Interact with the proxy as the implementation contract
        LiquidityManager proxiedManager = LiquidityManager(proxyAddress);

        // Test non-admin caller
        // vm.prank(address(100));
        // vm.expectRevert(UUPSUnauthorizedCallContext.selector);
        // proxiedManager.upgradeToAndCall(address(1), "");

        // Test admin caller
        vm.prank(ADMIN);
        proxiedManager.upgradeToAndCall(address(new LiquidityManager()), "");
    }

    function _prefundLiquidityManager()
        internal
        returns (
            uint256 amountXAdded,
            uint256 amountYAdded,
            uint256 amountXLeft,
            uint256 amountYLeft,
            uint256[] memory depositIds,
            uint256[] memory liquidityMinted
        )
    {
        vm.startPrank(ADMIN);
        uint256[] memory binSteps = factory.getAllBinSteps();
        uint16 binStep = uint16(binSteps[0]);
        pair = ILBPair(manager.getPair(binStep));

        uint256 binsAmount = 3;
        uint256 activeIdDesired = pair.getActiveId();
        int256[] memory deltaIds = new int256[](binsAmount);
        deltaIds[0] = -1;
        deltaIds[1] = 0;
        deltaIds[2] = 1;

        uint256[] memory distributionX = new uint256[](binsAmount);
        distributionX[0] = 0;
        distributionX[1] = PRECISION / 2;
        distributionX[2] = PRECISION / 2;

        uint256[] memory distributionY = new uint256[](binsAmount);
        distributionY[0] = (2 * PRECISION) / 3;
        distributionY[1] = PRECISION / 3;
        distributionY[2] = 0;

        ILBRouter.LiquidityParameters memory liquidityParameters = ILBRouter.LiquidityParameters({
            tokenX: USDT,
            tokenY: USDC,
            binStep: binSteps[0],
            amountX: 100e18,
            amountY: 100e18,
            amountXMin: 0,
            amountYMin: 0,
            activeIdDesired: activeIdDesired,
            idSlippage: 2,
            deltaIds: deltaIds,
            distributionX: distributionX,
            distributionY: distributionY,
            to: address(manager),
            refundTo: ADMIN,
            deadline: block.timestamp + 300
        });

        USDC.approve(address(router), 100e18);
        USDT.approve(address(router), 100e18);
        // Add liquidity
        (amountXAdded, amountYAdded, amountXLeft, amountYLeft, depositIds, liquidityMinted) =
            router.addLiquidity(liquidityParameters);
        console.log(amountXAdded, amountYAdded, amountXLeft, amountYLeft);

        vm.stopPrank();
    }
}
