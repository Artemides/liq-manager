// SPDX-License-Identifier: MIT

pragma solidity 0.8.27;

import "forge-std/Test.sol";

import {ERC20Mock} from "./mocks/ERC20.sol";
import "../src/interfaces/ILBRouter.sol";
import "../src/interfaces/ILBFactory.sol";
import "../src/interfaces/ILBRouter.sol";
import "../src/interfaces/ILBPair.sol";
import "./../src/LiquidityManager.sol";
import "./../src/interfaces/ILiquidityManager.sol";

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
        deal(address(USDC), ADMIN, 1000e18);
        deal(address(USDT), ADMIN, 1000e18);
        LiquidityManager implementation = new LiquidityManager();

        // Deploy minimal proxy pointing to the implementation
        bytes memory initData = abi.encodeWithSelector(
            implementation.initialize.selector, address(USDT), address(USDC), address(router), ADMIN, EXECUTOR
        );

        // Create proxy
        address proxyAddress = address(new LiquidityManagerProxy(address(implementation), initData));

        // Interact with the proxy as the implementation contract
        manager = LiquidityManager(proxyAddress);
    }

    function test_withdraw() public {
        uint256[] memory binSteps = factory.getAllBinSteps();
        uint16 binStep = uint16(binSteps[0]);
        (,,,, uint256[] memory depositIds,) = _prefundLiquidityManager();

        uint16[] memory fromBinSteps = new uint16[](1);
        fromBinSteps[0] = binStep;

        uint256[][] memory ids = new uint256[][](1);
        ids[0] = new uint256[](1);
        ids[0] = depositIds;

        uint256 startingAdminXBalance = USDT.balanceOf(ADMIN);
        uint256 startingAdminYBalance = USDC.balanceOf(ADMIN);

        vm.prank(ADMIN);
        (uint256 amountXWithdrawn, uint256 amountYWithdrawn) =
            manager.withdraw(fromBinSteps, ids, block.timestamp + 300);
        uint256 endingAdminXBalance = USDT.balanceOf(ADMIN);
        uint256 endingAdminYBalance = USDC.balanceOf(ADMIN);

        assertEq(endingAdminXBalance, startingAdminXBalance + amountXWithdrawn);
        assertEq(endingAdminYBalance, startingAdminYBalance + amountYWithdrawn);
    }

    function test_removeAndAddLiquidity() public {
        uint256[] memory binSteps = factory.getAllBinSteps();
        (,,,, uint256[] memory depositIds,) = _prefundLiquidityManager();

        //REMOVE LIQUIDITY FROM
        uint16[] memory fromBinSteps = new uint16[](1);
        uint16 binStep = uint16(binSteps[0]);
        fromBinSteps[0] = binStep;

        uint256[][] memory ids = new uint256[][](1);
        ids[0] = new uint256[](1);
        ids[0] = depositIds;

        //REALLOCATE ALL LIQUIDITY WITH STRATEGY
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
        ILiquidityManager.RemoveAndAddLiquidityParams memory params = ILiquidityManager.RemoveAndAddLiquidityParams({
            fromBinSteps: fromBinSteps,
            ids: ids,
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

    function testFuzz_onlyAdminCanWithdraw(address caller) public {
        vm.assume(caller != ADMIN);
        vm.prank(caller);
        vm.expectRevert();

        manager.withdraw(new uint16[](1), new uint256[][](1), block.timestamp);
    }

    function test_onlyAdminCanUpgrade() public {
        LiquidityManager implementation = new LiquidityManager();

        // Test non-admin caller
        vm.prank(address(100));
        vm.expectRevert();
        manager.upgradeToAndCall(address(1), "");

        vm.prank(ADMIN);
        manager.upgradeToAndCall(address(implementation), "");
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
