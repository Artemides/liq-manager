# LiquidityManager Smart Contract

This contract manages liquidity in Joe's Automated Market Maker (AMM), with the ability to deposit, withdraw, and reallocate liquidity across pairs. It leverages the UUPSUpgradeable pattern for upgradeability, AccessControl for role-based permissions, and communicates with Joe's AMM router and pair contracts.

## Table of Contents

- [Overview](#overview)
- [Bot Integration](#bot-integration)
- [Contract Functions](#contract-functions)
  - [Initialization](#initialization)
  - [Liquidity Management](#liquidity-management)
  - [Tracking and Reallocation](#tracking-and-reallocation)
- [Access Control](#access-control)
- [Events](#events)
- [Modifiers](#modifiers)

## Overview

The `LiquidityManager` contract is built with the following key features:

- Working on the `V2_2`.
- It manages liquidity between over the USDT and USDC LBPair.
- The contract uses LBRouter to facilitate liquidity management.
- It supports adding and removing liquidity within specified price ranges, as well as reallocating liquidity based on a bot's strategy.
- Uses `UUPSUpgradeable` for proxy-based upgrades.
- Implements `AccessControl` to manage roles for different users.

## Bot Integration

The bot needs to understand `ILiquidityManager` interface in order to achieve challenged tasks.

- The Bot is supposed to find and compute its best strategies off-chain based on marked conditions
- The Required params in the interface were defined as is, because Joe's AMM already emits events that can be analyzed cheaply off-chain, whilst it is possible to do it on-chain it's not recommended.
- There's an attempt in the `LiquidityManager` to track on-chain liquidity. By tracking `BinStep Pairs` and even `ids` where liquidity can be deposited. However, having time limitation it couln't be solved at all, since Joe's already provides a `SDK` to track pool balances it's recommended the Bot analyzes and comunicates as `ILiquidityManager` says.
- `LiquidityManager` might still require optimizations.

## Contract Functions

### Initialization

#### `initialize(address _tokenX, address _tokenY, address _router, address _admin, address _executor)`

Initializes the contract with the required parameters. This function is called only once during the deployment or upgrade of the contract.

### Liquidity Management

#### `withdraw(uint16[] memory binSteps, uint256[][] calldata ids, uint256 deadline)`

Removes all liquidity from specified price ranges and positions and transfers the liquidity to the admin's address.

#### `withdrawFromPair(uint16 fromBinStep, uint256[] calldata ids, uint256 deadline)`

Removes liquidity from a specific price range and position and transfers it to the admin's address.

#### `depositAllLiquidity(...)`

Deposits liquidity into a specific price range and position as per the executor's strategy.

#### `removeAndAddLiquidity(RemoveAndAddLiquidityParams memory params)`

Removes liquidity from one range and adds it to another based on a bot's strategy.

### Tracking and Reallocation

#### `_trackPair(uint256 binStep, uint256[] memory ids, bool add)`

Tracks the liquidity positions for a specific pair. This is used to keep track of added or removed liquidity in the contract.

## Access Control

The contract uses the `AccessControl` mechanism to manage roles:

- **Admin Role (`ADMIN_ROLE`)**: Grants administrative permissions, including the ability to withdraw liquidity and upgrade the contract.
- **Executor Role (`EXECUTOR_ROLE`)**: Allows the executor (usually a bot or automated agent) to deposit and manage liquidity based on the strategy.

Roles are set during the initialization of the contract and can be updated through role management functions.

## Events

- ` event Withdraw(uint256 amountX, uint256 amountY);`: Emitted when liquidity all liquidity is removed and sent to admin.
- `LiquidityReallocated(uint256 amountXRemoved, uint256 amountYRemoved, uint256 amountXAdded, uint256 amountYAdded)`: Emitted when liquidity is reallocated to a new price range.

## Modifiers

- `onlyRole`: Restricts access to certain functions based on the caller's role (either `DEFAULT_ADMIN_ROLE`, `ADMIN_ROLE`, or `EXECUTOR_ROLE`).

## Slippage

The contract calculates slippage as a percentage of the liquidity removed or added. It allows for 1% slippage by default. You can modify this behavior in the `_slippage` function if required.

## Notes

- **Upgradability**: The contract uses `UUPSUpgradeable` for proxy-based upgrades. The `initialize` function is called only once to set up the contract's state.
- **Liquidity Removal**: The process of removing liquidity is managed in batches (by price range and position IDs).
- **Tracking**: All liquidity positions are tracked on-chain, but this may increase gas costs.
- **Not yet Audited**: Do not use in production mode because the protocol still requires audit and optimizations

## Getting Started

### installation

```shell
$ forge install
```

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test --fork-url --match-contract TestLiquidityManager AVALANCHE_MAINNET_RPC
```
