// SPDX-License-Identifier: Apache License, Version 2.0.

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BZRXv2Token is ERC20("BZRXv2 Token", "BZRXv2"), Ownable {
    function mint(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
    }

    function burn(address account, uint256 amount) public {
        _burn(account, amount);
    }
}