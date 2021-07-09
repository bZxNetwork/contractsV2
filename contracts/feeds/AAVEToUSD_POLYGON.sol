/**
 * Copyright 2017-2021, bZeroX, LLC. All Rights Reserved.
 * Licensed under the Apache License, Version 2.0.
 */

pragma solidity 0.5.17;

import "./IPriceFeedsExt.sol";


// polygon: 0xC47812857A74425e2039b57891a3DFcF51602d5d
contract AAVEToUSD_POLYGON is IPriceFeedsExt {
    function latestAnswer()
        external
        view
        returns (int256)
    {
        int256 aave_eth = IPriceFeedsExt(0xbE23a3AA13038CfC28aFd0ECe4FdE379fE7fBfc4).latestAnswer();
        require(aave_eth != 0 && (aave_eth >> 128) == 0, "price error");

        int256 eth_usd = IPriceFeedsExt(0xF9680D99D6C9589e2a93a78A04A279e509205945).latestAnswer();
        require(eth_usd != 0 && (eth_usd >> 128) == 0, "price error");

        return aave_eth * eth_usd / 1e18;
    }
}
