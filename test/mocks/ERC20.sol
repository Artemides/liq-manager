// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title ERC20Mock
/// @author Trader Joe
/// @dev ONLY FOR TESTS
contract ERC20Mock is ERC20, Ownable {
    constructor() ERC20("ERC20 Mock", "ERC20Mock") Ownable(msg.sender) {}

    /// @dev Mint _amount to _to, only callable by the owner
    /// @param _to The address that will receive the mint
    /// @param _amount The amount to be minted
    function mint(address _to, uint256 _amount) external onlyOwner {
        _mint(_to, _amount);
    }
}
