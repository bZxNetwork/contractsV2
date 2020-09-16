/**
 * Copyright 2017-2020, bZeroX, LLC. All Rights Reserved.
 * Licensed under the Apache License, Version 2.0.
 */

pragma solidity 0.5.17;
pragma experimental ABIEncoderV2;

import "./AdvancedTokenStorage.sol";
import "./interfaces/ProtocolSettingsLike.sol";


contract LoanTokenSettings is AdvancedTokenStorage {
    using SafeMath for uint256;

    modifier onlyAdmin() {
        require(msg.sender == address(this) ||
            msg.sender == owner(), "unauthorized");
        _;
    }

    bytes32 internal constant iToken_LowerAdminAddress = 0x7ad06df6a0af6bd602d90db766e0d5f253b45187c3717a0f9026ea8b10ff0d4b;    // keccak256("iToken_LowerAdminAddress")
    bytes32 internal constant iToken_LowerAdminContract = 0x34b31cff1dbd8374124bd4505521fc29cab0f9554a5386ba7d784a4e611c7e31;   // keccak256("iToken_LowerAdminContract")


    function()
        external
    {
        revert("fallback not allowed");
    }

    function setLowerAdminValues(
        address _lowerAdmin,
        address _lowerAdminContract)
        public
        onlyAdmin
    {
        assembly {
            sstore(iToken_LowerAdminAddress, _lowerAdmin)
            sstore(iToken_LowerAdminContract, _lowerAdminContract)
        }
    }

    function setDisplayParams(
        string memory _name,
        string memory _symbol)
        public
        onlyAdmin
    {
        name = _name;
        symbol = _symbol;
    }

    function recoverEther(
        address receiver,
        uint256 amount)
        public
        onlyAdmin
    {
        uint256 balance = address(this).balance;
        if (balance < amount)
            amount = balance;

        (bool success,) = receiver.call.value(amount)("");
        require(success,
            "transfer failed"
        );
    }

    function recoverToken(
        address tokenAddress,
        address receiver,
        uint256 amount)
        public
        onlyAdmin
    {
        require(tokenAddress != loanTokenAddress, "invalid token");

        IERC20 token = IERC20(tokenAddress);

        uint256 balance = token.balanceOf(address(this));
        if (balance < amount)
            amount = balance;

        require(token.transfer(
            receiver,
            amount),
            "transfer failed"
        );
    }

    function transfer(
        address _to,
        uint256 _value)
        public
        returns (bool)
    {
        require(_to != address(0), "invalid transfer");

        balances[msg.sender] = balances[msg.sender].sub(_value, "insufficient balance");
        balances[_to] = balances[_to].add(_value);

        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function initialize(
        address _loanTokenAddress,
        string memory _name,
        string memory _symbol)
        public
        onlyAdmin
    {
        loanTokenAddress = _loanTokenAddress;

        name = _name;
        symbol = _symbol;
        decimals = IERC20(loanTokenAddress).decimals();
        totalSupply_ = WEI_PRECISION; // starting supply of 1 - this is to save future gas cost in calculations
    }
}
