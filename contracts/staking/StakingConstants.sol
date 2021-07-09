/**
 * Copyright 2017-2020, bZeroX, LLC. All Rights Reserved.
 * Licensed under the Apache License, Version 2.0.
 */

pragma solidity 0.5.17;

import "../interfaces/IERC20.sol";
import "../interfaces/IUniswapV2Router.sol";
import "./interfaces/ICurve3Pool.sol";
import "../../interfaces/IBZx.sol";


contract StakingConstants {

    address public constant BZRX = 0x56d811088235F11C8920698a204A5010a788f4b3;
    address public constant vBZRX = 0xB72B31907C1C95F3650b64b2469e08EdACeE5e8F;
    address public constant iBZRX = 0x18240BD9C07fA6156Ce3F3f61921cC82b2619157;
    address public constant LPToken = 0xe26A220a341EAca116bDa64cF9D5638A935ae629;
    IERC20 public constant curve3Crv = IERC20(0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490);

    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

    IUniswapV2Router public constant uniswapRouter = IUniswapV2Router(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    ICurve3Pool public constant curve3pool = ICurve3Pool(0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7);
    IBZx public constant bZx = IBZx(0xD8Ee69652E4e4838f2531732a46d1f7F584F0b7f);

    uint256 public constant cliffDuration =                15768000; // 86400 * 365 * 0.5
    uint256 public constant vestingDuration =              126144000; // 86400 * 365 * 4
    uint256 internal constant vestingDurationAfterCliff =  110376000; // 86400 * 365 * 3.5
    uint256 internal constant vestingStartTimestamp =      1594648800; // start_time
    uint256 internal constant vestingCliffTimestamp =      vestingStartTimestamp + cliffDuration;
    uint256 internal constant vestingEndTimestamp =        vestingStartTimestamp + vestingDuration;
    uint256 internal constant _startingVBZRXBalance =      889389933e18; // 889,389,933 BZRX

    uint256 public constant BZRXWeightStored = 1e18;

    struct DelegatedTokens {
        address user;
        uint256 BZRX;
        uint256 vBZRX;
        uint256 iBZRX;
        uint256 LPToken;
        uint256 totalVotes;
    }

    event Stake(
        address indexed user,
        address indexed token,
        address indexed delegate,
        uint256 amount
    );

    event Unstake(
        address indexed user,
        address indexed token,
        address indexed delegate,
        uint256 amount
    );

    event AddRewards(
        address indexed sender,
        uint256 bzrxAmount,
        uint256 stableCoinAmount
    );

    event Claim(
        address indexed user,
        uint256 bzrxAmount,
        uint256 stableCoinAmount
    );

    event ChangeDelegate(
        address indexed user,
        address indexed oldDelegate,
        address indexed newDelegate
    );

    event WithdrawFees(
        address indexed sender
    );

    event ConvertFees(
        address indexed sender,
        uint256 bzrxOutput,
        uint256 stableCoinOutput
    );

    event DistributeFees(
        address indexed sender,
        uint256 bzrxRewards,
        uint256 stableCoinRewards
    );
}
