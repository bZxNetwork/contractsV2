/**
 * Copyright 2017-2021, bZeroX, LLC <https://bzx.network/>. All Rights Reserved.
 * Licensed under the Apache License, Version 2.0.
 */

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin-3.4.0/token/ERC20/SafeERC20.sol";
import "./interfaces/Upgradeable.sol";
import "./interfaces/IWethERC20.sol";
import "./interfaces/IUniswapV2Router.sol";
import "../../interfaces/IBZx.sol";
import "./interfaces/IMasterChefPartial.sol";
import "./interfaces/IPriceFeeds.sol";

contract FeeExtractAndDistribute_Polygon is Upgradeable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IBZx public constant bZx = IBZx(0xfe4F0eb0A1Ad109185c9AaDE64C48ff8e928e54B);
    IMasterChefPartial public constant chef =
        IMasterChefPartial(0xd39Ff512C3e55373a30E94BB1398651420Ae1D43);

    address public constant PGOV = 0xd5d84e75f48E75f01fb2EB6dFD8eA148eE3d0FEb;
    address public constant MATIC = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
    address public constant BZRX = 0x54cFe73f2c7d0c4b62Ab869B473F5512Dc0944D2;
    address public constant iBZRX = 0x97dfbEF4eD5a7f63781472Dbc69Ab8e5d7357cB9;

    IUniswapV2Router public constant swapsRouterV2 =
        IUniswapV2Router(0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506); // Sushiswap

    address internal constant ZERO_ADDRESS = address(0);

    bool public isPaused;

    address payable public fundsWallet;

    mapping(address => uint256) public exportedFees;

    address[] public currentFeeTokens;

    mapping(IERC20 => uint256) public tokenHeld;

    event ExtractAndDistribute();

    event AssetSwap(
        address indexed sender,
        address indexed srcAsset,
        address indexed dstAsset,
        uint256 srcAmount,
        uint256 dstAmount
    );

    event AssetBurn(
        address indexed sender,
        address indexed asset,
        uint256 amount
    );

    modifier onlyEOA() {
        require(msg.sender == tx.origin, "unauthorized");
        _;
    }

    modifier checkPause() {
        require(!isPaused || msg.sender == owner(), "paused");
        _;
    }

    function sweepFees() public // sweepFeesByAsset() does checkPause
    {
        sweepFeesByAsset(currentFeeTokens);
    }

    function sweepFeesByAsset(address[] memory assets)
        public
        checkPause
        onlyEOA
    {
        _extractAndDistribute(assets);
    }

    function _extractAndDistribute(address[] memory assets) internal {
        uint256[] memory amounts = bZx.withdrawFees(
            assets,
            address(this),
            IBZx.FeeClaimType.All
        );

        for (uint256 i = 0; i < assets.length; i++) {
            require(assets[i] != PGOV, "asset not supported");
            exportedFees[assets[i]] = exportedFees[assets[i]].add(amounts[i]);
        }

        uint256 maticOutput = exportedFees[MATIC];
        exportedFees[MATIC] = 0;

        address asset;
        uint256 amount;
        for (uint256 i = 0; i < assets.length; i++) {
            asset = assets[i];
            if (asset == PGOV || asset == BZRX || asset == MATIC) {
                continue;
            }
            amount = exportedFees[asset];
            exportedFees[asset] = 0;

            if (amount != 0) {
                maticOutput += _swapWithPair(asset, MATIC, amount);
            }
        }

        if (maticOutput != 0) {
            amount = (maticOutput * 15e18) / 1e20; // burn (15%)
            uint256 sellAmount = amount; // sell for BZRX (15%)
            uint256 distributeAmount = (maticOutput * 50e18) / 1e20; // distribute to stakers (50%)
            maticOutput -= (amount + sellAmount + distributeAmount);

            uint256 pgovAmount = _swapWithPair(MATIC, PGOV, amount);
            emit AssetSwap(msg.sender, MATIC, PGOV, amount, pgovAmount);

            // burn baby burn (15% of original amount)
            IERC20(PGOV).transfer(
                0x000000000000000000000000000000000000dEaD,
                pgovAmount
            );
            emit AssetBurn(msg.sender, PGOV, pgovAmount);

            // buy and distribute BZRX
            uint256 buyAmount = IPriceFeeds(bZx.priceFeeds()).queryReturn(
                MATIC,
                BZRX,
                sellAmount
            );
            uint256 availableForBuy = tokenHeld[IERC20(BZRX)];
            if (buyAmount > availableForBuy) {
                amount = sellAmount.mul(availableForBuy).div(buyAmount);
                buyAmount = availableForBuy;

                exportedFees[MATIC] += (sellAmount - amount); // retain excess MATIC for next time
                sellAmount = amount;
            }
            tokenHeld[IERC20(BZRX)] = availableForBuy - buyAmount;

            // add any BZRX extracted from fees
            buyAmount += exportedFees[BZRX];
            exportedFees[BZRX] = 0;

            if (buyAmount != 0) {
                IERC20(BZRX).safeTransfer(iBZRX, buyAmount);
                emit AssetSwap(msg.sender, MATIC, BZRX, sellAmount, buyAmount);
            }

            IWethERC20(MATIC).withdraw(maticOutput + sellAmount + distributeAmount);
            chef.addAltReward.value(distributeAmount);
            Address.sendValue(fundsWallet, maticOutput + sellAmount);

            emit ExtractAndDistribute();
        }
    }

    function _swapWithPair(
        address inAsset,
        address outAsset,
        uint256 inAmount
    ) internal returns (uint256 returnAmount) {
        address[] memory path = new address[](2);
        path[0] = inAsset;
        path[1] = outAsset;

        uint256[] memory amounts = swapsRouterV2.swapExactTokensForTokens(
            inAmount,
            1, // amountOutMin
            path,
            address(this),
            block.timestamp
        );

        returnAmount = amounts[1];
    }

    // OnlyOwner functions

    function togglePause(bool _isPaused) external onlyOwner {
        isPaused = _isPaused;
    }

    function setFundsWallet(address payable _fundsWallet) external onlyOwner {
        fundsWallet = _fundsWallet;
    }

    function setFeeTokens(address[] calldata tokens) external onlyOwner {
        currentFeeTokens = tokens;
        for (uint256 i = 0; i < tokens.length; i++) {
            IERC20(tokens[i]).safeApprove(address(swapsRouterV2), 0);
            IERC20(tokens[i]).safeApprove(
                address(swapsRouterV2),
                uint256(-1)
            );
        }
        IERC20(PGOV).safeApprove(address(chef), 0);
        IERC20(PGOV).safeApprove(address(chef), uint256(-1));
    }

    function depositToken(IERC20 token, uint256 amount) external onlyOwner {
        token.safeTransferFrom(msg.sender, address(this), amount);

        tokenHeld[token] = tokenHeld[token].add(amount);
    }

    function withdrawToken(IERC20 token, uint256 amount) external onlyOwner {
        uint256 balance = tokenHeld[token];
        if (amount > balance) {
            amount = balance;
        }

        tokenHeld[token] = tokenHeld[token].sub(amount);

        token.safeTransfer(msg.sender, amount);
    }
}
