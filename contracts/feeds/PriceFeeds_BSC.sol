/**
 * Copyright 2017-2021, bZeroX, LLC. All Rights Reserved.
 * Licensed under the Apache License, Version 2.0.
 */

pragma solidity 0.5.17;

import "../openzeppelin/SafeMath.sol";
import "../openzeppelin/Ownable.sol";
import "../interfaces/IERC20.sol";
import "../core/Constants.sol";
import "./IPriceFeedsExt.sol";


contract PriceFeeds_BSC is Constants, Ownable {
    using SafeMath for uint256;

    event GlobalPricingPaused(
        address indexed sender,
        bool isPaused
    );

    mapping (address => IPriceFeedsExt) public pricesFeeds;     // token => pricefeed
    mapping (address => uint256) public decimals;               // decimals of supported tokens

    bool public globalPricingPaused = false;

    constructor()
        public
    {
        // set decimals for ether
        decimals[address(wethToken)] = 18;
    }

    function queryRate(
        address sourceToken,
        address destToken)
        public
        view
        returns (uint256 rate, uint256 precision)
    {
        require(!globalPricingPaused, "pricing is paused");
        return _queryRate(
            sourceToken,
            destToken
        );
    }

    function queryPrecision(
        address sourceToken,
        address destToken)
        public
        view
        returns (uint256)
    {
        return sourceToken != destToken ?
            _getDecimalPrecision(sourceToken, destToken) :
            WEI_PRECISION;
    }

    //// NOTE: This function returns 0 during a pause, rather than a revert. Ensure calling contracts handle correctly. ///
    function queryReturn(
        address sourceToken,
        address destToken,
        uint256 sourceAmount)
        public
        view
        returns (uint256 destAmount)
    {
        if (globalPricingPaused) {
            return 0;
        }
        (uint256 rate, uint256 precision) = _queryRate(
            sourceToken,
            destToken
        );

        destAmount = sourceAmount
            .mul(rate)
            .div(precision);
    }

    function checkPriceDisagreement(
        address sourceToken,
        address destToken,
        uint256 sourceAmount,
        uint256 destAmount,
        uint256 maxSlippage)
        public
        view
        returns (uint256 sourceToDestSwapRate)
    {
        require(!globalPricingPaused, "pricing is paused");
        (uint256 rate, uint256 precision) = _queryRate(
            sourceToken,
            destToken
        );

        rate = rate
            .mul(WEI_PRECISION)
            .div(precision);

        sourceToDestSwapRate = destAmount
            .mul(WEI_PRECISION)
            .div(sourceAmount);

        uint256 spreadValue = sourceToDestSwapRate > rate ?
            sourceToDestSwapRate - rate :
            rate - sourceToDestSwapRate;

        if (spreadValue != 0) {
            spreadValue = spreadValue
                .mul(WEI_PERCENT_PRECISION)
                .div(sourceToDestSwapRate);

            require(
                spreadValue <= maxSlippage,
                "price disagreement"
            );
        }
    }

    function amountInEth(
        address tokenAddress,
        uint256 amount)
        public
        view
        returns (uint256 ethAmount)
    {
        if (tokenAddress == address(wethToken)) {
            ethAmount = amount;
        } else {
            (uint toEthRate, uint256 toEthPrecision) = queryRate(
                tokenAddress,
                address(wethToken)
            );
            ethAmount = amount
                .mul(toEthRate)
                .div(toEthPrecision);
        }
    }

    function getMaxDrawdown(
        address loanToken,
        address collateralToken,
        uint256 loanAmount,
        uint256 collateralAmount,
        uint256 margin)
        public
        view
        returns (uint256 maxDrawdown)
    {
        uint256 loanToCollateralAmount;
        if (collateralToken == loanToken) {
            loanToCollateralAmount = loanAmount;
        } else {
            (uint256 rate, uint256 precision) = queryRate(
                loanToken,
                collateralToken
            );
            loanToCollateralAmount = loanAmount
                .mul(rate)
                .div(precision);
        }

        uint256 combined = loanToCollateralAmount
            .add(
                loanToCollateralAmount
                    .mul(margin)
                    .div(WEI_PERCENT_PRECISION)
                );

        maxDrawdown = collateralAmount > combined ?
            collateralAmount - combined :
            0;
    }

    function getCurrentMarginAndCollateralSize(
        address loanToken,
        address collateralToken,
        uint256 loanAmount,
        uint256 collateralAmount)
        public
        view
        returns (uint256 currentMargin, uint256 collateralInEthAmount)
    {
        (currentMargin,) = getCurrentMargin(
            loanToken,
            collateralToken,
            loanAmount,
            collateralAmount
        );

        collateralInEthAmount = amountInEth(
            collateralToken,
            collateralAmount
        );
    }

    function getCurrentMargin(
        address loanToken,
        address collateralToken,
        uint256 loanAmount,
        uint256 collateralAmount)
        public
        view
        returns (uint256 currentMargin, uint256 collateralToLoanRate)
    {
        uint256 collateralToLoanAmount;
        if (collateralToken == loanToken) {
            collateralToLoanAmount = collateralAmount;
            collateralToLoanRate = WEI_PRECISION;
        } else {
            uint256 collateralToLoanPrecision;
            (collateralToLoanRate, collateralToLoanPrecision) = queryRate(
                collateralToken,
                loanToken
            );

            collateralToLoanRate = collateralToLoanRate
                .mul(WEI_PRECISION)
                .div(collateralToLoanPrecision);

            collateralToLoanAmount = collateralAmount
                .mul(collateralToLoanRate)
                .div(WEI_PRECISION);
        }

        if (loanAmount != 0 && collateralToLoanAmount >= loanAmount) {
            currentMargin = collateralToLoanAmount
                .sub(loanAmount)
                .mul(WEI_PERCENT_PRECISION)
                .div(loanAmount);
        }
    }

    function shouldLiquidate(
        address loanToken,
        address collateralToken,
        uint256 loanAmount,
        uint256 collateralAmount,
        uint256 maintenanceMargin)
        public
        view
        returns (bool)
    {
        (uint256 currentMargin,) = getCurrentMargin(
            loanToken,
            collateralToken,
            loanAmount,
            collateralAmount
        );

        return currentMargin <= maintenanceMargin;
    }

    // returns per unit gas cost denominated in payToken * 1e36
    function getFastGasPrice(
        address payToken)
        external
        view
        returns (uint256)
    {
        uint256 gasPrice = _getFastGasPrice()
            .mul(WEI_PRECISION * WEI_PRECISION);
        if (payToken != address(wethToken) && payToken != address(0)) {
            require(!globalPricingPaused, "pricing is paused");
            (uint256 rate, uint256 precision) = _queryRate(
                address(wethToken),
                payToken
            );
            gasPrice = gasPrice
                .mul(rate)
                .div(precision);
        }
        return gasPrice;
    }


    /*
    * Owner functions
    */

    function setPriceFeed(
        address[] calldata tokens,
        IPriceFeedsExt[] calldata feeds)
        external
        onlyOwner
    {
        require(tokens.length == feeds.length, "count mismatch");

        for (uint256 i = 0; i < tokens.length; i++) {
            pricesFeeds[tokens[i]] = feeds[i];
        }
    }

    function setDecimals(
        IERC20[] calldata tokens)
        external
        onlyOwner
    {
        for (uint256 i = 0; i < tokens.length; i++) {
            decimals[address(tokens[i])] = tokens[i].decimals();
        }
    }

    function setGlobalPricingPaused(
        bool isPaused)
        external
        onlyOwner
    {
        globalPricingPaused = isPaused;

        emit GlobalPricingPaused(
            msg.sender,
            isPaused
        );
    }

    /*
    * Internal functions
    */

    function _queryRate(
        address sourceToken,
        address destToken)
        internal
        view
        returns (uint256 rate, uint256 precision)
    {
        if (sourceToken != destToken) {
            uint256 sourceRate = _queryRateCall(sourceToken);
            uint256 destRate = _queryRateCall(destToken);

            rate = sourceRate
                .mul(WEI_PRECISION)
                .div(destRate);

            precision = _getDecimalPrecision(sourceToken, destToken);
        } else {
            rate = WEI_PRECISION;
            precision = WEI_PRECISION;
        }
    }

    function _queryRateCall(
        address token)
        internal
        view
        returns (uint256 rate)
    {
        IPriceFeedsExt _Feed = pricesFeeds[token];
        require(address(_Feed) != address(0), "unsupported price feed");
        rate = uint256(_Feed.latestAnswer());
        require(rate != 0 && (rate >> 128) == 0, "price error");
    }

    function _getDecimalPrecision(
        address sourceToken,
        address destToken)
        internal
        view
        returns(uint256)
    {
        if (sourceToken == destToken) {
            return WEI_PRECISION;
        } else {
            uint256 sourceTokenDecimals = decimals[sourceToken];
            if (sourceTokenDecimals == 0)
                sourceTokenDecimals = IERC20(sourceToken).decimals();

            uint256 destTokenDecimals = decimals[destToken];
            if (destTokenDecimals == 0)
                destTokenDecimals = IERC20(destToken).decimals();

            if (destTokenDecimals >= sourceTokenDecimals)
                return 10**(SafeMath.sub(18, destTokenDecimals-sourceTokenDecimals));
            else
                return 10**(SafeMath.add(18, sourceTokenDecimals-destTokenDecimals));
        }
    }

    function _getFastGasPrice()
        internal
        view
        returns (uint256 gasPrice)
    {
        return 10e9;
    }
}
