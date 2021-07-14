/**
 * Copyright 2017-2021, bZeroX, LLC. All Rights Reserved.
 * Licensed under the Apache License, Version 2.0.
 */

pragma solidity ^0.7.6;
pragma experimental ABIEncoderV2;

/// SPDX-License-Identifier: MIT

import "@openzeppelin-3.4.0/access/Ownable.sol";
import "@openzeppelin-3.4.0/token/ERC20/IERC20.sol";
import "./IToken.sol";
import "./IBZx.sol";
import "../../interfaces/IPriceFeeds.sol";

contract HelperImpl is Ownable {
    address public constant bZxProtocol = 0xD8Ee69652E4e4838f2531732a46d1f7F584F0b7f; // mainnet
    //address public constant bZxProtocol = 0x5cfba2639a3db0D9Cc264Aa27B2E6d134EeA486a; // kovan
    //address public constant bZxProtocol = 0xC47812857A74425e2039b57891a3DFcF51602d5d; // bsc
    //address public constant bZxProtocol = 0xfe4F0eb0A1Ad109185c9AaDE64C48ff8e928e54B; // polygon

    function balanceOf(IERC20[] calldata tokens, address wallet)
        public view
        returns (uint256[] memory balances)
    {
        balances = new uint256[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            balances[i] = tokens[i].balanceOf(wallet);
        }
    }

    function totalSupply(IERC20[] calldata tokens)
        public view
        returns (uint256[] memory totalSupply)
    {
        totalSupply = new uint256[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            totalSupply[i] = tokens[i].totalSupply();
        }
    }

    function allowance(
        IERC20[] calldata tokens,
        address owner,
        address spender
    ) public view returns (uint256[] memory allowances) {
        allowances = new uint256[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            allowances[i] = tokens[i].allowance(owner, spender);
        }
    }

    function tokenPrice(IToken[] calldata tokens)
        public view
        returns (uint256[] memory prices)
    {
        prices = new uint256[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            prices[i] = tokens[i].tokenPrice();
        }
    }

    function supplyInterestRate(IToken[] calldata tokens)
        public view
        returns (uint256[] memory rates)
    {
        rates = new uint256[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            rates[i] = tokens[i].supplyInterestRate();
        }
    }

    function borrowInterestRate(IToken[] calldata tokens)
        public view
        returns (uint256[] memory rates)
    {
        rates = new uint256[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            rates[i] = tokens[i].borrowInterestRate();
        }
    }

    function assetBalanceOf(IToken[] calldata tokens, address wallet)
        public view
        returns (uint256[] memory balances)
    {
        balances = new uint256[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            balances[i] = tokens[i].assetBalanceOf(wallet);
        }
    }

    function profitOf(IToken[] calldata tokens, address wallet)
        public view
        returns (int256[] memory profits)
    {
        profits = new int256[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            profits[i] = tokens[i].profitOf(wallet);
        }
    }

    function marketLiquidity(IToken[] calldata tokens)
        public view
        returns (uint256[] memory liquidity)
    {
        liquidity = new uint256[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            liquidity[i] = tokens[i].marketLiquidity();
        }
    }


    struct ReserveDetail{
        address iToken;
        uint256 totalAssetSupply;
        uint256 totalAssetBorrow;
        uint256 supplyInterestRate;
        uint256 borrowInterestRate;
        uint256 torqueBorrowInterestRate;
        uint256 vaultBalance;
    }

    function reserveDetails(IToken[] calldata tokens)
        public
        view
        returns (ReserveDetail[] memory reserveDetails)    
        {
        reserveDetails = new ReserveDetail[](tokens.length);

        for (uint256 i = 0; i < tokens.length; i++) {
            reserveDetails[i].iToken = address(tokens[i]);
            reserveDetails[i].totalAssetSupply = tokens[i].totalAssetSupply();
            reserveDetails[i].totalAssetBorrow = tokens[i].totalAssetBorrow();
            reserveDetails[i].supplyInterestRate = tokens[i].supplyInterestRate();
            reserveDetails[i].borrowInterestRate = tokens[i].avgBorrowInterestRate();
            reserveDetails[i].torqueBorrowInterestRate = tokens[i].nextBorrowInterestRate(0);
            reserveDetails[i].vaultBalance = IERC20(tokens[i].loanTokenAddress()).balanceOf(bZxProtocol);
        }
    }

    struct AssetRates{
        uint256 rate;
        uint256 precision;
        uint256 destAmount;
    }

    function assetRates(
        address usdTokenAddress,
        address[] memory tokens,
        uint256[] memory sourceAmounts)
        public
        view
        returns (AssetRates[] memory assetRates)
    {
        IPriceFeeds feeds = IPriceFeeds(IBZx(bZxProtocol).priceFeeds());
        assetRates = new AssetRates[](tokens.length);
 

        for (uint256 i = 0; i < tokens.length; i++) {
            (assetRates[i].rate, assetRates[i].precision) = feeds.queryRate(
                tokens[i],
                usdTokenAddress
            );

            if (sourceAmounts[i] != 0) {
                assetRates[i].destAmount = sourceAmounts[i] * assetRates[i].rate;
                require(assetRates[i].destAmount / sourceAmounts[i] == assetRates[i].rate, "overflow");
                assetRates[i].destAmount = assetRates[i].destAmount / assetRates[i].precision;
            }
        }
    }
}
