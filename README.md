# LiquidityManager Smart Contract

This contract manages liquidity in Joe's Automated Market Maker (AMM), with the ability to deposit, withdraw, and reallocate liquidity across pairs. It leverages the UUPSUpgradeable pattern for upgradeability, AccessControl for role-based permissions, and communicates with Joe's AMM router and pair contracts.

## Table of Contents

- [Overview](#overview)
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

## Contract Functions

### Initialization

#### `initialize(address _tokenX, address _tokenY, address _router, address _admin, address _executor)`

Initializes the contract with the required parameters. This function is called only once during the deployment or upgrade of the contract.

**Parameters:**

- `_tokenX`: Address of the first token (ERC20) USDT.
- `_tokenY`: Address of the second token (ERC20) USDC.
- `_router`: Address of the AMM's router.
- `_admin`: Address of the admin (granted `ADMIN_ROLE`).
- `_executor`: Address of the executor (granted `EXECUTOR_ROLE`).

### Liquidity Management

#### `withdraw(uint16[] memory binSteps, uint256[][] calldata ids, uint256 deadline)`

Removes all liquidity from specified price ranges and positions and transfers the liquidity to the admin's address.

**Parameters:**

- `binSteps`: Array of price ranges from which liquidity should be withdrawn.
- `ids`: Array of position IDs within the LBPair to withdraw liquidity from.
- `deadline`: Transaction deadline.

#### `withdrawFromPair(uint16 fromBinStep, uint256[] calldata ids, uint256 deadline)`

Removes liquidity from a specific price range and position and transfers it to the admin's address.

**Parameters:**

- `fromBinStep`: Price range to withdraw liquidity from.
- `ids`: Array of position IDs within the LBPair to withdraw liquidity from.
- `deadline`: Transaction deadline.

#### `depositAllLiquidity(...)`

Deposits liquidity into a specific price range and position as per the executor's strategy.

**Parameters:**

- `binStep`: Price range to deposit liquidity into.
- `activeIdDesired`: Desired active ID for liquidity.
- `idSlippage`: Slippage tolerance for the ID.
- `deltaIds`: Array of delta IDs for liquidity distribution.
- `distributionX`: Distribution for tokenX.
- `distributionY`: Distribution for tokenY.
- `deadline`: Transaction deadline.

#### `removeAndAddLiquidity(RemoveAndAddLiquidityParams memory params)`

Removes liquidity from one range and adds it to another based on a bot's strategy.

**Parameters:**

- `params`: Parameters for the liquidity removal and addition process.

### Tracking and Reallocation

#### `_trackPair(uint256 binStep, uint256[] memory ids, bool add)`

Tracks the liquidity positions for a specific pair. This is used to keep track of added or removed liquidity in the contract.

**Parameters:**

- `binStep`: Price range for the pair.
- `ids`: Array of position IDs to track.
- `add`: Whether to add or remove the tracking of liquidity.

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
