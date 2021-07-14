/**
 * Copyright 2017-2021, bZeroX, LLC. All Rights Reserved.
 * Licensed under the Apache License, Version 2.0.
 */

pragma solidity ^0.7.6;

/// SPDX-License-Identifier: MIT

interface IBZx {
    function priceFeeds()
        external
        view
        returns (address);
}