/**
 * Copyright 2017-2021, bZeroX, LLC. All Rights Reserved.
 * Licensed under the Apache License, Version 2.0.
 */

pragma solidity 0.5.17;
pragma experimental ABIEncoderV2;


contract DAppHelper_TokenLike {
    string public name;
    uint8 public decimals;
    string public symbol;
    function totalSupply() public view returns (uint256);
    function balanceOf(address _who) public view returns (uint256);
    function allowance(address _owner, address _spender) public view returns (uint256);
}

contract DAppHelper_iTokenLike is DAppHelper_TokenLike {
    function loanTokenAddress() public view returns (address);
    function tokenPrice() public view returns (uint256);
    function totalAssetSupply() public view returns (uint256);
    function totalAssetBorrow() public view returns (uint256);
    function supplyInterestRate() public view returns (uint256);
    function avgBorrowInterestRate() public view returns (uint256);
    function nextBorrowInterestRate(
        uint256 borrowAmount)
        public
        view
        returns (uint256);
}

contract DAppHelper_Protocol {
    function priceFeeds()
        public
        view
        returns (uint256);
}

contract DAppHelper_FeedsLike {
    function queryRate(
        address sourceToken,
        address destToken)
        public
        view
        returns (uint256 rate, uint256 precision);
}

contract DAppHelper {

    address public constant bZxProtocol = 0xD8Ee69652E4e4838f2531732a46d1f7F584F0b7f; // mainnet
    //address public constant bZxProtocol = 0x5cfba2639a3db0D9Cc264Aa27B2E6d134EeA486a; // kovan
    //address public constant bZxProtocol = 0xC47812857A74425e2039b57891a3DFcF51602d5d; // bsc
    //address public constant bZxProtocol = 0xfe4F0eb0A1Ad109185c9AaDE64C48ff8e928e54B; // polygon

    function assetRates(
        address usdTokenAddress,
        address[] memory tokens,
        uint256[] memory sourceAmounts)
        public
        view
        returns (
            uint256[] memory rates,
            uint256[] memory precisions,
            uint256[] memory destAmounts
        )
    {
        DAppHelper_FeedsLike feeds = DAppHelper_FeedsLike(DAppHelper_Protocol(bZxProtocol).priceFeeds());
        rates = new uint256[](tokens.length);
        precisions = new uint256[](tokens.length);
        destAmounts = new uint256[](tokens.length);

        for (uint256 i=0; i < tokens.length; i++) {
            (rates[i], precisions[i]) = feeds.queryRate(
                tokens[i],
                usdTokenAddress
            );

            if (sourceAmounts[i] != 0) {
                destAmounts[i] = sourceAmounts[i] * rates[i];
                require(destAmounts[i] / sourceAmounts[i] == rates[i], "overflow");
                destAmounts[i] = destAmounts[i] / precisions[i];
            }
        }
    }

    function reserveDetails(
        address[] memory tokenAddresses)
        public
        view
        returns (
            uint256[] memory totalAssetSupply,
            uint256[] memory totalAssetBorrow,
            uint256[] memory supplyInterestRate,
            uint256[] memory borrowInterestRate,
            uint256[] memory torqueBorrowInterestRate,
            uint256[] memory vaultBalance
        )
    {
        totalAssetSupply = new uint256[](tokenAddresses.length);
        totalAssetBorrow = new uint256[](tokenAddresses.length);
        supplyInterestRate = new uint256[](tokenAddresses.length);
        borrowInterestRate = new uint256[](tokenAddresses.length);
        torqueBorrowInterestRate = new uint256[](tokenAddresses.length);
        vaultBalance = new uint256[](tokenAddresses.length);

        for (uint256 i=0; i < tokenAddresses.length; i++) {
            DAppHelper_iTokenLike token = DAppHelper_iTokenLike(tokenAddresses[i]);
            totalAssetSupply[i] = token.totalAssetSupply();
            totalAssetBorrow[i] = token.totalAssetBorrow();
            supplyInterestRate[i] = token.supplyInterestRate();
            borrowInterestRate[i] = token.avgBorrowInterestRate();
            torqueBorrowInterestRate[i] = token.nextBorrowInterestRate(0);

            address loanToken = token.loanTokenAddress();
            vaultBalance[i] = DAppHelper_TokenLike(loanToken).balanceOf(bZxProtocol);
        }
    }
}
