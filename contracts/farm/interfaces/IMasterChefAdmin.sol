pragma solidity 0.6.12;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IMasterChef.sol";
pragma experimental ABIEncoderV2;

/// SPDX-License-Identifier: MIT



interface IMasterChefAdmin is IMasterChef {
    function add(uint256 _allocPoint, IERC20 _lpToken, bool _withUpdate)
        external;
    function set(uint256 _pid, uint256 _allocPoint, bool _withUpdate)
        external;
    function setLocked(uint256 _pid, bool _toggle)
        external;
    function togglePause(bool _toggle)
        external;
    function transferTokenOwnership(address newOwner)
        external;
    function setStartBlock(uint256 _startBlock)
        external;
    function massMigrateToBalanceOf()
        external;
    function migrateToBalanceOf(uint256 _pid)
        external;
}