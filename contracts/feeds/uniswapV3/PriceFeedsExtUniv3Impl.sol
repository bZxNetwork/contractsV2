/**
 * Copyright 2017-2021, bZeroX, LLC. All Rights Reserved.
 * Licensed under the Apache License, Version 2.0.
 */
/// SPDX-License-Identifier: Apache License, Version 2.0.

pragma solidity >=0.5.0 <0.8.0;

import "../IPriceFeedsExt.sol";
import '@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol';

contract PriceFeedsExtUniv3Impl is IPriceFeedsExt {
  uint32 public period;
  uint128 public baseAmount;
  address public pool;
  address public tokenA;
  address public tokenB;

  constructor(address _pool, uint32 _period, address _tokenA, address _tokenB, uint128 _baseAmount) {
      period = _period;
      baseAmount = _baseAmount;
      pool = _pool;
      tokenA = _tokenA;
      tokenB = _tokenB;
      
  }

  function latestAnswer() external view override returns (int256){
    int24 timeWeightedAverageTick = OracleLibrary.consult(pool, period);
    uint256 quoteAmount = OracleLibrary.getQuoteAtTick(timeWeightedAverageTick, baseAmount, tokenB, tokenA);
    return int256(quoteAmount);
  }
}
