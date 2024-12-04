// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "src/LiquidityManager.sol";
import {LiquidityManagerProxy} from "test/mocks/LiquidityManagerProxy.sol";
import "src/interfaces/ILBRouter.sol";
import "src/interfaces/ILBFactory.sol";
import "test/mocks/ERC20.sol";
import "forge-std/Script.sol";

contract LiquidityManagerDeploy is Script {
    // Addresses on Avalanche
    ILBRouter router = ILBRouter(0x18556DA13313f3532c54711497A8FedAC273220E);
    ILBFactory factory = ILBFactory(0xb43120c4745967fa9b93E79C149E66B0f2D6Fe0c);
    ERC20Mock USDC = ERC20Mock(0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E);
    ERC20Mock USDT = ERC20Mock(0x9702230A8Ea53601f5cD2dc00fDBc13d4dF4A8c7);
    address ADMIN = address(0); // Set your ADMIN address
    address EXECUTOR = address(0); // Set your EXECUTOR address

    function run() public {
        // Start the fork context
        vm.startBroadcast();

        // Deploy the LiquidityManager implementation
        LiquidityManager implementation = new LiquidityManager();

        // Initialize proxy with the implementation
        bytes memory initData = abi.encodeWithSelector(
            implementation.initialize.selector, address(USDT), address(USDC), address(router), ADMIN, EXECUTOR
        );

        // Create proxy
        address proxyAddress = address(new LiquidityManagerProxy(address(implementation), initData));

        // Interact with the proxy contract
        LiquidityManager manager = LiquidityManager(proxyAddress);

        // Optionally, you can add further setup or interaction with the deployed contract
        console.log("Proxy Address:", address(manager));
        // Stop the broadcast
        vm.stopBroadcast();
    }
}
