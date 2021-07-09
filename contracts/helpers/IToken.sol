/**
 * Copyright 2017-2021, bZeroX, LLC. All Rights Reserved.
 * Licensed under the Apache License, Version 2.0.
 */

pragma solidity ^0.7.6;

/// SPDX-License-Identifier: MIT

interface IToken {
    function tokenPrice() external view returns (uint256);

    function supplyInterestRate() external view returns (uint256);

    function borrowInterestRate() external view returns (uint256);

    function assetBalanceOf(address wallet) external view returns (uint256);

    function profitOf(address wallet) external view returns (int256);

    function marketLiquidity() external view returns (uint256);

    function totalAssetSupply() external view returns (uint256);

    function totalAssetBorrow() external view returns (uint256);

    function avgBorrowInterestRate() external view returns (uint256);

    function nextBorrowInterestRate(uint256 borrowAmount) external view returns (uint256);

    function loanTokenAddress() external view returns(address);
}
