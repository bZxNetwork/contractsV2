pragma solidity 0.6.12;

/// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/utils/Address.sol";
import "./interfaces/Upgradeable.sol";


contract Proxy is Upgradeable {

    constructor(address _impl) public payable {
        replaceImplementation(_impl);
    }

    fallback() external payable {
        _fallback();
    }
    receive() external payable {
        _fallback();
    }
    function _fallback() internal {
        if (gasleft() <= 2300) {
            return;
        }

        address impl = implementation;

        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)

            returndatacopy(0, 0, returndatasize())

            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    function replaceImplementation(address impl) public onlyOwner {
        require(Address.isContract(impl), "not a contract");
        implementation = impl;
    }
}
