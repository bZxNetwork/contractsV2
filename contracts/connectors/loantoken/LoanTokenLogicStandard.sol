/**
 * Copyright 2017-2021, bZeroX, LLC. All Rights Reserved.
 * Licensed under the Apache License, Version 2.0.
 */

pragma solidity 0.5.17;
pragma experimental ABIEncoderV2;

import "./AdvancedToken.sol";
import "./interfaces/ProtocolLike.sol";
import "./interfaces/FeedsLike.sol";
import "../gastoken/GasTokenUser.sol";


contract LoanTokenLogicStandard is AdvancedToken, GasTokenUser {
    using SafeMath for uint256;
    using SignedSafeMath for int256;

    modifier settlesInterest() {
        _settleInterest();
        _;
    }

    address internal target_;

    uint256 public constant VERSION = 6;
    // address internal constant arbitraryCaller = 0x000F400e6818158D541C3EBE45FE3AA0d47372FF; // mainnet
    //address internal constant arbitraryCaller = 0x81e7dddFAD37E6FAb0eccE95f0B508fd40996e6d; // bsc
    address internal constant arbitraryCaller = 0x81e7dddFAD37E6FAb0eccE95f0B508fd40996e6d; // polygon

    // address public constant bZxContract = 0xD8Ee69652E4e4838f2531732a46d1f7F584F0b7f; // mainnet
    // address public constant wethToken = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // mainnet

    //address public constant bZxContract = 0x5cfba2639a3db0D9Cc264Aa27B2E6d134EeA486a; // kovan
    //address public constant wethToken = 0xd0A1E359811322d97991E03f863a0C30C2cF029C; // kovan

    //address public constant bZxContract = 0xC47812857A74425e2039b57891a3DFcF51602d5d; // bsc
    //address public constant wethToken = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c; // bsc

    address public constant bZxContract = 0xfe4F0eb0A1Ad109185c9AaDE64C48ff8e928e54B; // polygon
    address public constant wethToken = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270; // polygon

    bytes32 internal constant iToken_ProfitSoFar = 0x37aa2b7d583612f016e4a4de4292cb015139b3d7762663d06a53964912ea2fb6;          // keccak256("iToken_ProfitSoFar")
    bytes32 internal constant iToken_LowerAdminAddress = 0x7ad06df6a0af6bd602d90db766e0d5f253b45187c3717a0f9026ea8b10ff0d4b;    // keccak256("iToken_LowerAdminAddress")
    bytes32 internal constant iToken_LowerAdminContract = 0x34b31cff1dbd8374124bd4505521fc29cab0f9554a5386ba7d784a4e611c7e31;   // keccak256("iToken_LowerAdminContract")


    constructor(
        address _newOwner)
        public
    {
        transferOwnership(_newOwner);
    }

    function()
        external
    {
        revert("fallback not allowed");
    }

    /* Public functions */

    function mint(
        address receiver,
        uint256 depositAmount)
        external
        nonReentrant
        returns (uint256) // mintAmount
    {
        return _mintToken(
            receiver,
            depositAmount
        );
    }

    function mintWithGasRebate(
        address receiver,
        uint256 depositAmount)
        external
        nonReentrant
        withGasRebate(receiver, bZxContract)
        returns (uint256) // mintAmount
    {
        return _mintToken(
            receiver,
            depositAmount
        );
    }

    function burn(
        address receiver,
        uint256 burnAmount)
        external
        nonReentrant
        returns (uint256 loanAmountPaid)
    {
        loanAmountPaid = _burnToken(
            burnAmount
        );

        if (loanAmountPaid != 0) {
            _safeTransfer(loanTokenAddress, receiver, loanAmountPaid, "5");
        }
    }

    function burnWithGasRebate(
        address receiver,
        uint256 burnAmount)
        external
        nonReentrant
        withGasRebate(receiver, bZxContract)
        returns (uint256 loanAmountPaid)
    {
        loanAmountPaid = _burnToken(
            burnAmount
        );

        if (loanAmountPaid != 0) {
            _safeTransfer(loanTokenAddress, receiver, loanAmountPaid, "5");
        }
    }

    function flashBorrow(
        uint256 borrowAmount,
        address borrower,
        address target,
        string calldata signature,
        bytes calldata data)
        external
        payable
        nonReentrant
        pausable(msg.sig)
        settlesInterest
        returns (bytes memory)
    {
        require(borrowAmount != 0, "38");

        // save before balances
        uint256 beforeEtherBalance = address(this).balance.sub(msg.value);
        uint256 beforeAssetsBalance = _underlyingBalance()
            .add(totalAssetBorrow());

        // lock totalAssetSupply for duration of flash loan
        _flTotalAssetSupply = beforeAssetsBalance;

        // transfer assets to calling contract
        _safeTransfer(loanTokenAddress, borrower, borrowAmount, "39");

        emit FlashBorrow(borrower, target, loanTokenAddress, borrowAmount);

        bytes memory callData;
        if (bytes(signature).length == 0) {
            callData = data;
        } else {
            callData = abi.encodePacked(bytes4(keccak256(bytes(signature))), data);
        }

        // arbitrary call
        (bool success, bytes memory returnData) = arbitraryCaller.call.value(msg.value)(
            abi.encodeWithSelector(
                0xde064e0d, // sendCall(address,bytes)
                target,
                callData
            )
        );
        require(success, "call failed");

        // unlock totalAssetSupply
        _flTotalAssetSupply = 0;

        // verifies return of flash loan
        require(
            address(this).balance >= beforeEtherBalance &&
            _underlyingBalance()
                .add(totalAssetBorrow()) >= beforeAssetsBalance,
            "40"
        );

        return returnData;
    }

    function borrow(
        bytes32 loanId,                 // 0 if new loan
        uint256 withdrawAmount,
        uint256 initialLoanDuration,    // duration in seconds
        uint256 collateralTokenSent,    // if 0, loanId must be provided; any ETH sent must equal this value
        address collateralTokenAddress, // if address(0), this means ETH and ETH must be sent with the call or loanId must be provided
        address borrower,
        address receiver,
        bytes memory /*loanDataBytes*/) // arbitrary order data (for future use)
        public
        payable
        nonReentrant
        returns (ProtocolLike.LoanOpenData memory)
    {
        return _borrow(
            loanId,
            withdrawAmount,
            initialLoanDuration,
            collateralTokenSent,
            collateralTokenAddress,
            borrower,
            receiver,
            ""
        );
    }


    function borrowWithGasRebate(
        bytes32 loanId,                 // 0 if new loan
        uint256 withdrawAmount,
        uint256 initialLoanDuration,    // duration in seconds
        uint256 collateralTokenSent,    // if 0, loanId must be provided; any ETH sent must equal this value
        address collateralTokenAddress, // if address(0), this means ETH and ETH must be sent with the call or loanId must be provided
        address borrower,
        address receiver,
        bytes memory /*loanDataBytes*/) // arbitrary order data (for future use)
        public
        payable
        nonReentrant
        withGasRebate(receiver, bZxContract)
        returns (ProtocolLike.LoanOpenData memory)
    {
        return _borrow(
            loanId,
            withdrawAmount,
            initialLoanDuration,
            collateralTokenSent,
            collateralTokenAddress,
            borrower,
            receiver,
            ""
        );
    }

    function borrowWithGasToken(
        bytes32 loanId,                 // 0 if new loan
        uint256 withdrawAmount,
        uint256 initialLoanDuration,    // duration in seconds
        uint256 collateralTokenSent,    // if 0, loanId must be provided; any ETH sent must equal this value
        address collateralTokenAddress, // if address(0), this means ETH and ETH must be sent with the call or loanId must be provided
        address borrower,
        address receiver,
        address gasTokenUser,           // specifies an address that has given spend approval for gas/chi token
        bytes memory /*loanDataBytes*/) // arbitrary order data (for future use)
        public
        payable
        nonReentrant
        usesGasToken(gasTokenUser)
        returns (ProtocolLike.LoanOpenData memory)
    {
        return _borrow(
            loanId,
            withdrawAmount,
            initialLoanDuration,
            collateralTokenSent,
            collateralTokenAddress,
            borrower,
            receiver,
            ""
        );
    }

    // Called to borrow and immediately get into a position
    function marginTrade(
        bytes32 loanId,                 // 0 if new loan
        uint256 leverageAmount,
        uint256 loanTokenSent,
        uint256 collateralTokenSent,
        address collateralTokenAddress,
        address trader,
        bytes memory loanDataBytes)     // arbitrary order data
        public
        payable
        nonReentrant
        returns (ProtocolLike.LoanOpenData memory)
    {
        return _marginTrade(
            loanId,
            leverageAmount,
            loanTokenSent,
            collateralTokenSent,
            collateralTokenAddress,
            trader,
            loanDataBytes
        );
    }

    function marginTradeWithGasRebate(
        bytes32 loanId,                 // 0 if new loan
        uint256 leverageAmount,
        uint256 loanTokenSent,
        uint256 collateralTokenSent,
        address collateralTokenAddress,
        address trader,
        bytes memory loanDataBytes)     // arbitrary order data
        public
        payable
        nonReentrant
        withGasRebate(receiver, bZxContract)
        returns (ProtocolLike.LoanOpenData memory)
    {
        return _marginTrade(
            loanId,
            leverageAmount,
            loanTokenSent,
            collateralTokenSent,
            collateralTokenAddress,
            trader,
            loanDataBytes
        );
    }

    // Called to borrow and immediately get into a position
    function marginTradeWithGasToken(
        bytes32 loanId,                 // 0 if new loan
        uint256 leverageAmount,
        uint256 loanTokenSent,
        uint256 collateralTokenSent,
        address collateralTokenAddress,
        address trader,
        address gasTokenUser,           // specifies an address that has given spend approval for gas/chi token
        bytes memory loanDataBytes)     // arbitrary order data
        public
        payable
        nonReentrant
        usesGasToken(gasTokenUser)
        returns (ProtocolLike.LoanOpenData memory)
    {
        return _marginTrade(
            loanId,
            leverageAmount,
            loanTokenSent,
            collateralTokenSent,
            collateralTokenAddress,
            trader,
            loanDataBytes
        );
    }

    function transfer(
        address _to,
        uint256 _value)
        external
        returns (bool)
    {
        return _internalTransferFrom(
            msg.sender,
            _to,
            _value,
            uint256(-1)
        );
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _value)
        external
        returns (bool)
    {
        return _internalTransferFrom(
            _from,
            _to,
            _value,
            allowed[_from][msg.sender]
            /*ProtocolLike(bZxContract).isLoanPool(msg.sender) ?
                uint256(-1) :
                allowed[_from][msg.sender]*/
        );
    }

    function _internalTransferFrom(
        address _from,
        address _to,
        uint256 _value,
        uint256 _allowanceAmount)
        internal
        returns (bool)
    {
        if (_allowanceAmount != uint256(-1)) {
            allowed[_from][msg.sender] = _allowanceAmount.sub(_value, "14");
        }

        require(_to != address(0), "15");

        uint256 _balancesFrom = balances[_from];
        uint256 _balancesFromNew = _balancesFrom
            .sub(_value, "16");
        balances[_from] = _balancesFromNew;

        uint256 _balancesTo = balances[_to];
        uint256 _balancesToNew = _balancesTo
            .add(_value);
        balances[_to] = _balancesToNew;

        // handle checkpoint update
        uint256 _currentPrice = tokenPrice();

        _updateCheckpoints(
            _from,
            _balancesFrom,
            _balancesFromNew,
            _currentPrice
        );
        _updateCheckpoints(
            _to,
            _balancesTo,
            _balancesToNew,
            _currentPrice
        );

        emit Transfer(_from, _to, _value);
        return true;
    }

    function _updateCheckpoints(
        address _user,
        uint256 _oldBalance,
        uint256 _newBalance,
        uint256 _currentPrice)
        internal
    {
        bytes32 slot = keccak256(
            abi.encodePacked(_user, iToken_ProfitSoFar)
        );

        int256 _currentProfit;
        if (_newBalance == 0) {
            _currentPrice = 0;
        } else if (_oldBalance != 0) {
            _currentProfit = _profitOf(
                slot,
                _oldBalance,
                _currentPrice,
                checkpointPrices_[_user]
            );
        }

        assembly {
            sstore(slot, _currentProfit)
        }

        checkpointPrices_[_user] = _currentPrice;
    }

    /* Public View functions */

    function profitOf(
        address user)
        public
        view
        returns (int256)
    {
        bytes32 slot = keccak256(
            abi.encodePacked(user, iToken_ProfitSoFar)
        );

        return _profitOf(
            slot,
            balances[user],
            tokenPrice(),
            checkpointPrices_[user]
        );
    }

    function _profitOf(
        bytes32 slot,
        uint256 _balance,
        uint256 _currentPrice,
        uint256 _checkpointPrice)
        internal
        view
        returns (int256 profitSoFar)
    {
        if (_checkpointPrice == 0) {
            return 0;
        }

        assembly {
            profitSoFar := sload(slot)
        }

        profitSoFar = int256(_currentPrice)
            .sub(int256(_checkpointPrice))
            .mul(int256(_balance))
            .div(sWEI_PRECISION)
            .add(profitSoFar);
    }

    function tokenPrice()
        public
        view
        returns (uint256) // price
    {
        uint256 interestUnPaid;
        if (lastSettleTime_ != uint88(block.timestamp)) {
            (,interestUnPaid) = _getAllInterest();
        }

        return _tokenPrice(_totalAssetSupply(interestUnPaid));
    }

    function checkpointPrice(
        address _user)
        public
        view
        returns (uint256) // price
    {
        return checkpointPrices_[_user];
    }

    function marketLiquidity()
        public
        view
        returns (uint256)
    {
        uint256 totalSupply = _totalAssetSupply(0);
        uint256 totalBorrow = totalAssetBorrow();
        if (totalSupply > totalBorrow) {
            return totalSupply - totalBorrow;
        }
    }

    function avgBorrowInterestRate()
        public
        view
        returns (uint256)
    {
        return _avgBorrowInterestRate(totalAssetBorrow());
    }

    // the minimum rate the next base protocol borrower will receive for variable-rate loans
    function borrowInterestRate()
        public
        view
        returns (uint256)
    {
        return _nextBorrowInterestRate(0);
    }

    function nextBorrowInterestRate(
        uint256 borrowAmount)
        public
        view
        returns (uint256)
    {
        return _nextBorrowInterestRate(borrowAmount);
    }

    // interest that lenders are currently receiving when supplying to the pool
    function supplyInterestRate()
        public
        view
        returns (uint256)
    {
        return totalSupplyInterestRate(_totalAssetSupply(0));
    }

    function nextSupplyInterestRate(
        uint256 supplyAmount)
        public
        view
        returns (uint256)
    {
        return totalSupplyInterestRate(_totalAssetSupply(0).add(supplyAmount));
    }

    function totalSupplyInterestRate(
        uint256 assetSupply)
        public
        view
        returns (uint256)
    {
        uint256 assetBorrow = totalAssetBorrow();
        if (assetBorrow != 0) {
            return _supplyInterestRate(
                assetBorrow,
                assetSupply
            );
        }
    }

    function totalAssetBorrow()
        public
        view
        returns (uint256)
    {
        return ProtocolLike(bZxContract).getTotalPrincipal(
            address(this),
            loanTokenAddress
        );
    }

    function totalAssetSupply()
        public
        view
        returns (uint256)
    {
        uint256 interestUnPaid;
        if (lastSettleTime_ != uint88(block.timestamp)) {
            (,interestUnPaid) = _getAllInterest();
        }

        return _totalAssetSupply(interestUnPaid);
    }

    function getMaxEscrowAmount(
        uint256 leverageAmount)
        public
        view
        returns (uint256)
    {
        uint256 initialMargin = SafeMath.div(WEI_PRECISION * WEI_PERCENT_PRECISION, leverageAmount);
        return marketLiquidity()
            .mul(initialMargin)
            .div(_adjustValue(
                WEI_PERCENT_PRECISION, // maximum possible interest (100%)
                2419200, // 28 day duration for margin trades
                initialMargin));
    }

    // returns the user's balance of underlying token
    function assetBalanceOf(
        address _owner)
        public
        view
        returns (uint256)
    {
        return balanceOf(_owner)
            .mul(tokenPrice())
            .div(WEI_PRECISION);
    }

    function getEstimatedMarginDetails(
        uint256 leverageAmount,
        uint256 loanTokenSent,
        uint256 collateralTokenSent,
        address collateralTokenAddress)     // address(0) means ETH
        public
        view
        returns (uint256 principal, uint256 collateral, uint256 interestRate, uint256 collateralToLoanRate)
    {
        if (collateralTokenAddress == address(0)) {
            collateralTokenAddress = wethToken;
        }

        (principal, interestRate,, collateralToLoanRate) = _getPreMarginData(
            collateralTokenAddress,
            collateralTokenSent,
            loanTokenSent,
            leverageAmount
        );
        if (principal > _underlyingBalance()) {
            return (0, 0, 0, collateralToLoanRate);
        }

        loanTokenSent = loanTokenSent
            .add(principal);

        collateral = ProtocolLike(bZxContract).getEstimatedMarginExposure(
            loanTokenAddress,
            collateralTokenAddress,
            loanTokenSent,
            collateralTokenSent,
            interestRate,
            principal
        );
    }

    function getDepositAmountForBorrow(
        uint256 borrowAmount,
        uint256 initialLoanDuration,        // duration in seconds
        address collateralTokenAddress)     // address(0) means ETH
        public
        view
        returns (uint256) // depositAmount
    {
        if (borrowAmount != 0) {
            (,,uint256 newBorrowAmount) = _getInterestRateAndBorrowAmount(
                borrowAmount,
                totalAssetSupply(),
                initialLoanDuration
            );

            if (newBorrowAmount <= _underlyingBalance()) {
                if (collateralTokenAddress == address(0)) {
                    collateralTokenAddress = wethToken;
                }
                return ProtocolLike(bZxContract).getRequiredCollateralByParams(
                    loanParamsIds[uint256(keccak256(abi.encodePacked(
                        collateralTokenAddress,
                        true
                    )))],
                    newBorrowAmount
                ).add(10); // some dust to compensate for rounding errors
            }
        }
    }

    function getBorrowAmountForDeposit(
        uint256 depositAmount,
        uint256 initialLoanDuration,        // duration in seconds
        address collateralTokenAddress)     // address(0) means ETH
        public
        view
        returns (uint256 borrowAmount)
    {
        if (depositAmount != 0) {
            if (collateralTokenAddress == address(0)) {
                collateralTokenAddress = wethToken;
            }
            borrowAmount = ProtocolLike(bZxContract).getBorrowAmountByParams(
                loanParamsIds[uint256(keccak256(abi.encodePacked(
                    collateralTokenAddress,
                    true
                )))],
                depositAmount
            );

            (,,borrowAmount) = _getInterestRateAndBorrowAmount(
                borrowAmount,
                totalAssetSupply(),
                initialLoanDuration
            );

            if (borrowAmount > _underlyingBalance()) {
                borrowAmount = 0;
            }
        }
    }


    /* Internal functions */

    function _mintToken(
        address receiver,
        uint256 depositAmount)
        internal
        settlesInterest
        returns (uint256 mintAmount)
    {
        require (depositAmount != 0, "17");

        uint256 currentPrice = _tokenPrice(_totalAssetSupply(0));
        mintAmount = depositAmount
            .mul(WEI_PRECISION)
            .div(currentPrice);

        if (msg.value == 0) {
            _safeTransferFrom(loanTokenAddress, msg.sender, address(this), depositAmount, "18");
        } else {
            require(msg.value == depositAmount, "18");
            IWeth(wethToken).deposit.value(depositAmount)();
        }

        _updateCheckpoints(
            receiver,
            balances[receiver],
            _mint(receiver, mintAmount, depositAmount, currentPrice), // newBalance
            currentPrice
        );
    }

    function _burnToken(
        uint256 burnAmount)
        internal
        settlesInterest
        returns (uint256 loanAmountPaid)
    {
        require(burnAmount != 0, "19");

        if (burnAmount > balanceOf(msg.sender)) {
            require(burnAmount == uint256(-1), "32");
            burnAmount = balanceOf(msg.sender);
        }

        uint256 currentPrice = _tokenPrice(_totalAssetSupply(0));

        uint256 loanAmountOwed = burnAmount
            .mul(currentPrice)
            .div(WEI_PRECISION);
        uint256 loanAmountAvailableInContract = _underlyingBalance();

        loanAmountPaid = loanAmountOwed;
        require(loanAmountPaid <= loanAmountAvailableInContract, "37");

        _updateCheckpoints(
            msg.sender,
            balances[msg.sender],
            _burn(msg.sender, burnAmount, loanAmountPaid, currentPrice), // newBalance
            currentPrice
        );
    }

    function _borrow(
        bytes32 loanId,                 // 0 if new loan
        uint256 withdrawAmount,
        uint256 initialLoanDuration,    // duration in seconds
        uint256 collateralTokenSent,    // if 0, loanId must be provided; any ETH sent must equal this value
        address collateralTokenAddress, // if address(0), this means ETH and ETH must be sent with the call or loanId must be provided
        address borrower,
        address receiver,
        bytes memory /*loanDataBytes*/) // arbitrary order data (for future use)
        internal
        pausable(msg.sig)
        settlesInterest
        returns (ProtocolLike.LoanOpenData memory)
    {
        require(withdrawAmount != 0, "6");

        require(msg.value == 0 || msg.value == collateralTokenSent, "7");
        require(collateralTokenSent != 0 || loanId != 0, "8");
        require(collateralTokenAddress != address(0) || msg.value != 0 || loanId != 0, "9");

        // ensures authorized use of existing loan
        require(loanId == 0 || msg.sender == borrower, "13");

        if (collateralTokenAddress == address(0)) {
            collateralTokenAddress = wethToken;
        }
        require(collateralTokenAddress != loanTokenAddress, "10");

        address[4] memory sentAddresses;
        uint256[5] memory sentAmounts;

        sentAddresses[0] = address(this); // lender
        sentAddresses[1] = borrower;
        sentAddresses[2] = receiver;
        //sentAddresses[3] = address(0); // manager

        //sentAmounts[0] = 0; // interestRate (found later)
        //sentAmounts[1] = 0; // borrowAmount (found later)
        //sentAmounts[2] = 0; // interestInitialAmount (found later)
        //sentAmounts[3] = 0; // loanTokenSent
        sentAmounts[4] = collateralTokenSent;

        // interestRate, interestInitialAmount, borrowAmount (newBorrowAmount)
        (sentAmounts[0], sentAmounts[2], sentAmounts[1]) = _getInterestRateAndBorrowAmount(
            withdrawAmount,
            _totalAssetSupply(0), // interest is settled above
            initialLoanDuration
        );

        return _borrowOrTrade(
            loanId,
            withdrawAmount,
            0, // leverageAmount (calculated later)
            collateralTokenAddress,
            sentAddresses,
            sentAmounts,
            "" // loanDataBytes
        );
    }

    function _marginTrade(
        bytes32 loanId,                 // 0 if new loan
        uint256 leverageAmount,
        uint256 loanTokenSent,
        uint256 collateralTokenSent,
        address collateralTokenAddress,
        address trader,
        bytes memory loanDataBytes)
        internal
        pausable(msg.sig)
        settlesInterest
        returns (ProtocolLike.LoanOpenData memory loanOpenData)
    {
        // ensures authorized use of existing loan
        require(loanId == 0 || msg.sender == trader, "13");

        if (collateralTokenAddress == address(0)) {
            collateralTokenAddress = wethToken;
        }
        require(collateralTokenAddress != loanTokenAddress, "11");

        address[4] memory sentAddresses;
        uint256[5] memory sentAmounts;

        sentAddresses[0] = address(this); // lender
        sentAddresses[1] = trader;
        sentAddresses[2] = trader;
        //sentAddresses[3] = address(0); // manager

        //sentAmounts[0] = 0; // interestRate (found later)
        //sentAmounts[1] = 0; // borrowAmount (found later)
        //sentAmounts[2] = 0; // interestInitialAmount (interest is calculated based on fixed-term loan)
        sentAmounts[3] = loanTokenSent;
        sentAmounts[4] = collateralTokenSent;

        uint256 totalDeposit;
        uint256 collateralToLoanRate;
        (sentAmounts[1], sentAmounts[0], totalDeposit, collateralToLoanRate) = _getPreMarginData( // borrowAmount, interestRate, totalDeposit, collateralToLoanRate
            collateralTokenAddress,
            collateralTokenSent,
            loanTokenSent,
            leverageAmount
        );
        require(totalDeposit != 0, "12");

        loanOpenData = _borrowOrTrade(
            loanId,
            0, // withdrawAmount
            leverageAmount,
            collateralTokenAddress,
            sentAddresses,
            sentAmounts,
            loanDataBytes
        );

        ProtocolLike(bZxContract).setDepositAmount(
            loanOpenData.loanId,
            totalDeposit,
            totalDeposit
                .mul(WEI_PRECISION)
                .div(collateralToLoanRate)
        );

        return loanOpenData;
    }

    function _settleInterest()
        internal
    {
        uint88 ts = uint88(block.timestamp);
        if (lastSettleTime_ != ts) {
            ProtocolLike(bZxContract).withdrawAccruedInterest(
                loanTokenAddress
            );

            lastSettleTime_ = ts;
        }
    }

    function _totalDeposit(
        address collateralTokenAddress,
        uint256 collateralTokenSent,
        uint256 loanTokenSent)
        internal
        view
        returns (uint256 totalDeposit, uint256 collateralToLoanRate)
    {
        uint256 collateralToLoanPrecision;
        (collateralToLoanRate, collateralToLoanPrecision) = FeedsLike(ProtocolLike(bZxContract).priceFeeds()).queryRate(
            collateralTokenAddress,
            loanTokenAddress
        );
        require(collateralToLoanRate != 0 && collateralToLoanPrecision != 0, "20");
        collateralToLoanRate = collateralToLoanRate
            .mul(WEI_PRECISION)
            .div(collateralToLoanPrecision);

        totalDeposit = loanTokenSent;
        if (collateralTokenSent != 0) {
            totalDeposit = collateralTokenSent
                .mul(collateralToLoanRate)
                .div(WEI_PRECISION)
                .add(totalDeposit);
        }
    }

    function _getInterestRateAndBorrowAmount(
        uint256 borrowAmount,
        uint256 assetSupply,
        uint256 initialLoanDuration) // duration in seconds
        internal
        view
        returns (uint256 interestRate, uint256 interestInitialAmount, uint256 newBorrowAmount)
    {
        interestRate = _nextBorrowInterestRate2(
            borrowAmount,
            assetSupply
        );

        // newBorrowAmount = borrowAmount * 10^18 / (10^18 - (interestRate * initialLoanDuration * 10^18 / (31536000 * 10^20)))
        newBorrowAmount = borrowAmount
            .mul(WEI_PRECISION)
            .div(
                SafeMath.sub(WEI_PRECISION,
                    interestRate
                        .mul(initialLoanDuration)
                        .mul(WEI_PRECISION)
                        .div(31536000 * WEI_PERCENT_PRECISION) // 365 * 86400 * WEI_PERCENT_PRECISION
                )
            );

        interestInitialAmount = newBorrowAmount
            .sub(borrowAmount);
    }

    // returns newPrincipal
    function _borrowOrTrade(
        bytes32 loanId,
        uint256 withdrawAmount,
        uint256 leverageAmount,
        address collateralTokenAddress,
        address[4] memory sentAddresses,
        uint256[5] memory sentAmounts,
        bytes memory loanDataBytes)
        internal
        returns (ProtocolLike.LoanOpenData memory)
    {
        require (sentAmounts[1] <= _underlyingBalance() && // newPrincipal
            sentAddresses[1] != address(0), // borrower
            "24"
        );

	    if (sentAddresses[2] == address(0)) {
            sentAddresses[2] = sentAddresses[1]; // receiver = borrower
        }

        // handle transfers prior to adding newPrincipal to loanTokenSent
        uint256 msgValue = _verifyTransfers(
            collateralTokenAddress,
            sentAddresses,
            sentAmounts,
            withdrawAmount
        );

        // adding the loan token portion from the lender to loanTokenSent
        sentAmounts[3] = sentAmounts[3]
            .add(sentAmounts[1]); // newPrincipal

        if (withdrawAmount != 0) {
            // withdrawAmount already sent to the borrower, so we aren't sending it to the protocol
            sentAmounts[3] = sentAmounts[3]
                .sub(withdrawAmount);
        }

        bool isTorqueLoan = withdrawAmount != 0 ?
            true :
            false;

        bytes32 loanParamsId = loanParamsIds[uint256(keccak256(abi.encodePacked(
            collateralTokenAddress,
            isTorqueLoan
        )))];

        // converting to initialMargin
        if (leverageAmount != 0) {
            leverageAmount = SafeMath.div(WEI_PRECISION * WEI_PERCENT_PRECISION, leverageAmount);
        }

        return ProtocolLike(bZxContract).borrowOrTradeFromPool.value(msgValue)(
            loanParamsId,
            loanId,
            isTorqueLoan,
            leverageAmount, // initialMargin
            sentAddresses,
            sentAmounts,
            loanDataBytes
        );
    }

    // sentAddresses[0]: lender
    // sentAddresses[1]: borrower
    // sentAddresses[2]: receiver
    // sentAddresses[3]: manager
    // sentAmounts[0]: interestRate
    // sentAmounts[1]: newPrincipal
    // sentAmounts[2]: interestInitialAmount
    // sentAmounts[3]: loanTokenSent
    // sentAmounts[4]: collateralTokenSent
    function _verifyTransfers(
        address collateralTokenAddress,
        address[4] memory sentAddresses,
        uint256[5] memory sentAmounts,
        uint256 withdrawalAmount)
        internal
        returns (uint256 msgValue)
    {
        address _wethToken = wethToken;
        address _loanTokenAddress = loanTokenAddress;
        address receiver = sentAddresses[2];
        uint256 newPrincipal = sentAmounts[1];
        uint256 loanTokenSent = sentAmounts[3];
        uint256 collateralTokenSent = sentAmounts[4];

        require(_loanTokenAddress != collateralTokenAddress, "26");

        msgValue = msg.value;

        if (withdrawalAmount != 0) { // withdrawOnOpen == true
            _safeTransfer(_loanTokenAddress, receiver, withdrawalAmount, "27");
            if (newPrincipal > withdrawalAmount) {
                _safeTransfer(_loanTokenAddress, bZxContract, newPrincipal - withdrawalAmount, "27");
            }
        } else {
            _safeTransfer(_loanTokenAddress, bZxContract, newPrincipal, "27");
        }

        if (collateralTokenSent != 0) {
            if (collateralTokenAddress == _wethToken && msgValue != 0 && msgValue >= collateralTokenSent) {
                IWeth(_wethToken).deposit.value(collateralTokenSent)();
                _safeTransfer(collateralTokenAddress, bZxContract, collateralTokenSent, "28");
                msgValue -= collateralTokenSent;
            } else {
                _safeTransferFrom(collateralTokenAddress, msg.sender, bZxContract, collateralTokenSent, "28");
            }
        }

        if (loanTokenSent != 0) {
            _safeTransferFrom(_loanTokenAddress, msg.sender, bZxContract, loanTokenSent, "29");
        }
    }

    function _safeTransfer(
        address token,
        address to,
        uint256 amount,
        string memory errorMsg)
        internal
    {
        _callOptionalReturn(
            token,
            abi.encodeWithSelector(IERC20(token).transfer.selector, to, amount),
            errorMsg
        );
    }

    function _safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 amount,
        string memory errorMsg)
        internal
    {
        _callOptionalReturn(
            token,
            abi.encodeWithSelector(IERC20(token).transferFrom.selector, from, to, amount),
            errorMsg
        );
    }

    function _callOptionalReturn(
        address token,
        bytes memory data,
        string memory errorMsg)
        internal
    {
        (bool success, bytes memory returndata) = token.call(data);
        require(success, errorMsg);

        if (returndata.length != 0) {
            require(abi.decode(returndata, (bool)), errorMsg);
        }
    }

    function _underlyingBalance()
        internal
        view
        returns (uint256)
    {
        return IERC20(loanTokenAddress).balanceOf(address(this));
    }

    /* Internal View functions */

    function _tokenPrice(
        uint256 assetSupply)
        internal
        view
        returns (uint256)
    {
        uint256 totalTokenSupply = totalSupply_;

        return totalTokenSupply != 0 ?
            assetSupply
                .mul(WEI_PRECISION)
                .div(totalTokenSupply) : initialPrice;
    }

    function _avgBorrowInterestRate(
        uint256 assetBorrow)
        internal
        view
        returns (uint256)
    {
        if (assetBorrow != 0) {
            (uint256 interestOwedPerDay,) = _getAllInterest();
            return interestOwedPerDay
                .mul(365 * WEI_PERCENT_PRECISION)
                .div(assetBorrow);
        }
    }

    // next supply interest adjustment
    function _supplyInterestRate(
        uint256 assetBorrow,
        uint256 assetSupply)
        internal
        view
        returns (uint256)
    {
        if (assetBorrow != 0 && assetSupply >= assetBorrow) {
            return _avgBorrowInterestRate(assetBorrow)
                .mul(_utilizationRate(assetBorrow, assetSupply))
                .mul(SafeMath.sub(WEI_PERCENT_PRECISION, ProtocolLike(bZxContract).lendingFeePercent()))
                .div(WEI_PERCENT_PRECISION * WEI_PERCENT_PRECISION);
        }
    }

    function _nextBorrowInterestRate(
        uint256 borrowAmount)
        internal
        view
        returns (uint256)
    {
        uint256 interestUnPaid;
        if (borrowAmount != 0) {
            if (lastSettleTime_ != uint88(block.timestamp)) {
                (,interestUnPaid) = _getAllInterest();
            }

            uint256 balance = _underlyingBalance()
                .add(interestUnPaid);
            if (borrowAmount > balance) {
                borrowAmount = balance;
            }
        }

        return _nextBorrowInterestRate2(
            borrowAmount,
            _totalAssetSupply(interestUnPaid)
        );
    }

    function _nextBorrowInterestRate2(
        uint256 newBorrowAmount,
        uint256 assetSupply)
        internal
        view
        returns (uint256 nextRate)
    {
        uint256 utilRate = _utilizationRate(
            totalAssetBorrow().add(newBorrowAmount),
            assetSupply
        );

        uint256 thisMinRate;
        uint256 thisMaxRate;
        uint256 thisBaseRate = baseRate;
        uint256 thisRateMultiplier = rateMultiplier;
        uint256 thisTargetLevel = targetLevel;
        uint256 thisKinkLevel = kinkLevel;
        uint256 thisMaxScaleRate = maxScaleRate;

        if (utilRate < thisTargetLevel) {
            // target targetLevel utilization when utilization is under targetLevel
            utilRate = thisTargetLevel;
        }

        if (utilRate > thisKinkLevel) {
            // scale rate proportionally up to 100%
            uint256 thisMaxRange = WEI_PERCENT_PRECISION - thisKinkLevel; // will not overflow

            utilRate -= thisKinkLevel;
            if (utilRate > thisMaxRange)
                utilRate = thisMaxRange;

            thisMaxRate = thisRateMultiplier
                .add(thisBaseRate)
                .mul(thisKinkLevel)
                .div(WEI_PERCENT_PRECISION);

            nextRate = utilRate
                .mul(SafeMath.sub(thisMaxScaleRate, thisMaxRate))
                .div(thisMaxRange)
                .add(thisMaxRate);
        } else {
            nextRate = utilRate
                .mul(thisRateMultiplier)
                .div(WEI_PERCENT_PRECISION)
                .add(thisBaseRate);

            thisMinRate = thisBaseRate;
            thisMaxRate = thisRateMultiplier
                .add(thisBaseRate);

            if (nextRate < thisMinRate)
                nextRate = thisMinRate;
            else if (nextRate > thisMaxRate)
                nextRate = thisMaxRate;
        }
    }

    function _getAllInterest()
        internal
        view
        returns (
            uint256 interestOwedPerDay,
            uint256 interestUnPaid)
    {
        // interestPaid, interestPaidDate, interestOwedPerDay, interestUnPaid, interestFeePercent, principalTotal
        uint256 interestFeePercent;
        (,,interestOwedPerDay,interestUnPaid,interestFeePercent,) = ProtocolLike(bZxContract).getLenderInterestData(
            address(this),
            loanTokenAddress
        );

        interestUnPaid = interestUnPaid
            .mul(SafeMath.sub(WEI_PERCENT_PRECISION, interestFeePercent))
            .div(WEI_PERCENT_PRECISION);
    }

    function _getPreMarginData(
        address collateralTokenAddress,
        uint256 collateralTokenSent,
        uint256 loanTokenSent,
        uint256 leverageAmount)
        internal
        view
        returns (uint256 borrowAmount, uint256 interestRate, uint256 totalDeposit, uint256 collateralToLoanRate)
    {
        (totalDeposit, collateralToLoanRate) = _totalDeposit(
            collateralTokenAddress,
            collateralTokenSent,
            loanTokenSent
        );

        uint256 initialMargin = SafeMath.div(WEI_PRECISION * WEI_PERCENT_PRECISION, leverageAmount);

        interestRate = _nextBorrowInterestRate2(
            totalDeposit
                .mul(WEI_PERCENT_PRECISION)
                .div(initialMargin),
            _totalAssetSupply(0)
        );

        // assumes that loan, collateral, and interest token are the same
        borrowAmount = totalDeposit
            .mul(WEI_PERCENT_PRECISION * WEI_PERCENT_PRECISION)
            .div(_adjustValue(
                interestRate,
                2419200, // 28 day duration for margin trades
                initialMargin))
            .div(initialMargin);
    }

    function _totalAssetSupply(
        uint256 interestUnPaid)
        internal
        view
        returns (uint256) // assetSupply
    {
        if (totalSupply_ != 0) {
            uint256 assetsBalance = _flTotalAssetSupply; // temporary locked totalAssetSupply during a flash loan transaction
            if (assetsBalance == 0) {
                assetsBalance = _underlyingBalance()
                    .add(totalAssetBorrow());
            }

            return assetsBalance
                .add(interestUnPaid);
        }
    }

    function _adjustValue(
        uint256 interestRate,
        uint256 maxDuration,
        uint256 marginAmount)
        internal
        pure
        returns (uint256)
    {
        return maxDuration != 0 ?
            interestRate
                .mul(WEI_PERCENT_PRECISION)
                .mul(maxDuration)
                .div(31536000) // 86400 * 365
                .div(marginAmount)
                .add(WEI_PERCENT_PRECISION) :
            WEI_PERCENT_PRECISION;
    }

    function _utilizationRate(
        uint256 assetBorrow,
        uint256 assetSupply)
        internal
        pure
        returns (uint256)
    {
        if (assetBorrow != 0 && assetSupply != 0) {
            // U = total_borrow / total_supply
            return assetBorrow
                .mul(WEI_PERCENT_PRECISION)
                .div(assetSupply);
        }
    }


    /* Owner-Only functions */

    function updateSettings(
        address settingsTarget,
        bytes memory callData)
        public
    {
        if (msg.sender != owner()) {
            address _lowerAdmin;
            address _lowerAdminContract;
            assembly {
                _lowerAdmin := sload(iToken_LowerAdminAddress)
                _lowerAdminContract := sload(iToken_LowerAdminContract)
            }
            require(msg.sender == _lowerAdmin && settingsTarget == _lowerAdminContract);
        }

        address currentTarget = target_;
        target_ = settingsTarget;

        (bool result,) = address(this).call(callData);

        uint256 size;
        uint256 ptr;
        assembly {
            size := returndatasize
            ptr := mload(0x40)
            returndatacopy(ptr, 0, size)
            if eq(result, 0) { revert(ptr, size) }
        }

        target_ = currentTarget;

        assembly {
            return(ptr, size)
        }
    }
}
