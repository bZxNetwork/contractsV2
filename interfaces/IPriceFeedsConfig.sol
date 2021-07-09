/**
 * Copyright 2017-2020, bZeroX, LLC. All Rights Reserved.
 * Licensed under the Apache License, Version 2.0.
 */

pragma solidity 0.5.17;


interface IPriceFeedsConfig {
    function setPriceFeed(
        address[] calldata tokens,
        address[] calldata feeds)
        external;

    function setDecimals(
        address[] calldata tokens)
        external;

    function setGlobalPricingPaused(
        bool isPaused)
        external;

    function decimals(
        address token)
        external
        view
        returns (uint256);

    function pricesFeeds(
        address token)
        external
        view
        returns (address);

    function globalPricingPaused()
        external
        view
        returns (bool);

    function queryRate(
        address sourceToken,
        address destToken)
        external
        view
        returns (uint256 rate, uint256 precision);

    function queryPrecision(
        address sourceToken,
        address destToken)
        external
        view
        returns (uint256);

    function queryReturn(
        address sourceToken,
        address destToken,
        uint256 sourceAmount)
        external
        view
        returns (uint256 destAmount);
}
