/**
 * Copyright 2017-2021, bZeroX, LLC <https://bzx.network/>. All Rights Reserved.
 * Licensed under the Apache License, Version 2.0.
 */
// SPDX-License-Identifier: Apache License, Version 2.0.
pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./VBZRXv2VestingToken.sol";
import "./BZRXv2Token.sol";


contract BZRXv2Converter is Ownable {

    event ConvertBZRX(
        address indexed sender,
        uint256 amount
    );

    IERC20 public constant BZRXv1 = IERC20(0x56d811088235F11C8920698a204A5010a788f4b3);
    // IERC20 public constant vBZRXv1 = IERC20(0xB72B31907C1C95F3650b64b2469e08EdACeE5e8F);
    BZRXv2Token public BZRXv2;
    // VBZRXv2VestingToken public vBZRXv2;
    address constant DEAD = 0x000000000000000000000000000000000000dEaD;

    uint256 public totalConverted;
    uint256 public totalVestingConverted;
    uint256 public terminationTimestamp;

    function convert(
        address receiver,
        uint256 _tokenAmount)
        external
    {
        BZRXv1.transferFrom(
            msg.sender,
            DEAD, // burn address, since transfers to address(0) are not allowed by the token
            _tokenAmount
        );

        // we mint burned amount
        BZRXv2.mint(receiver, _tokenAmount);

        // overflow condition cannot be reached since the above will throw for bad amounts
        totalConverted += _tokenAmount;

        emit ConvertBZRX(
            receiver,
            _tokenAmount
        );
    }

    // open convert tool to the public
    function initialize(BZRXv2Token _BZRXv2 /*, VBZRXv2VestingToken _vBZRXv2*/)
        external
        onlyOwner
    {
        require(terminationTimestamp == 0, "already initialized");
        terminationTimestamp = _getTimestamp() + 60 * 60 * 24 * 365; // one year from now
        BZRXv2 = _BZRXv2;
        // vBZRXv2 = _vBZRXv2;
    }

    // funds unclaimed after one year can be rescued
    function rescue(
        address _receiver,
        uint256 _amount,
        address _token)
        external
        onlyOwner
    {
        require(_getTimestamp() > terminationTimestamp, "unauthorized");

        IERC20(_token).transfer(
            _receiver,
            _amount
        );
    }

    function _getTimestamp()
        internal
        view
        returns (uint256)
    {
        return block.timestamp;
    }
}