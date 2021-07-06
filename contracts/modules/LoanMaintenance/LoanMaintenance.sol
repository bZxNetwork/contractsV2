/**
 * Copyright 2017-2021, bZeroX, LLC. All Rights Reserved.
 * Licensed under the Apache License, Version 2.0.
 */

pragma solidity 0.5.17;
pragma experimental ABIEncoderV2;

import "../../core/State.sol";
import "../../events/LoanMaintenanceEvents.sol";
import "../../mixins/VaultController.sol";
import "../../mixins/InterestUser.sol";
import "../../mixins/LiquidationHelper.sol";
import "../../swaps/SwapsUser.sol";


contract LoanMaintenance is State, LoanMaintenanceEvents, VaultController, InterestUser, SwapsUser, LiquidationHelper {

    function initialize(
        address target)
        external
        onlyOwner
    {
        _setTarget(this.depositCollateral.selector, target);
        _setTarget(this.withdrawCollateral.selector, target);
        _setTarget(this.withdrawAccruedInterest.selector, target);
        _setTarget(this.extendLoanDuration.selector, target);
        _setTarget(this.reduceLoanDuration.selector, target);
        _setTarget(this.setDepositAmount.selector, target);
        _setTarget(this.claimRewards.selector, target);
        _setTarget(this.rewardsBalanceOf.selector, target);
        _setTarget(this.getLenderInterestData.selector, target);
        _setTarget(this.getLoanInterestData.selector, target);
        _setTarget(this.getUserLoans.selector, target);
        _setTarget(this.getUserLoansCount.selector, target);
        _setTarget(this.getLoan.selector, target);
        _setTarget(this.getActiveLoans.selector, target);
        _setTarget(this.getActiveLoansAdvanced.selector, target);
        _setTarget(this.getActiveLoansCount.selector, target);
        _setTarget(this.withdraw.selector, target);
        _setTarget(this.deposit.selector, target);
    }

    function depositCollateral(
        bytes32 loanId,
        uint256 depositAmount) // must match msg.value if ether is sent
        external
        payable
        nonReentrant
    {
        require(depositAmount != 0, "depositAmount is 0");

        Loan storage loanLocal = loans[loanId];
        require(loanLocal.active, "loan is closed");

        LoanParams storage loanParamsLocal = loanParams[loanLocal.loanParamsId];

        address collateralToken = loanParamsLocal.collateralToken;
        uint256 collateral = loanLocal.collateral;

        require(msg.value == 0 || collateralToken == address(wethToken), "wrong asset sent");

        collateral = collateral
            .add(depositAmount);
        loanLocal.collateral = collateral;

        if (msg.value == 0) {
            vaultDeposit(
                collateralToken,
                msg.sender,
                depositAmount
            );
        } else {
            require(msg.value == depositAmount, "ether deposit mismatch");
            vaultEtherDeposit(
                msg.sender,
                msg.value
            );
        }

        // update deposit amount
        (uint256 collateralToLoanRate, uint256 collateralToLoanPrecision) = IPriceFeeds(priceFeeds).queryRate(
            collateralToken,
            loanParamsLocal.loanToken
        );
        if (collateralToLoanRate != 0) {
            _setDepositAmount(
                loanId,
                depositAmount
                    .mul(collateralToLoanRate)
                    .div(collateralToLoanPrecision),
                depositAmount,
                false // isSubtraction
            );
        }

        emit DepositCollateral(
            loanLocal.borrower,
            collateralToken,
            loanId,
            depositAmount
        );
    }

    function withdrawCollateral(
        bytes32 loanId,
        address receiver,
        uint256 withdrawAmount)
        external
        nonReentrant
        returns (uint256 actualWithdrawAmount)
    {
        require(withdrawAmount != 0, "withdrawAmount is 0");
        Loan storage loanLocal = loans[loanId];
        LoanParams storage loanParamsLocal = loanParams[loanLocal.loanParamsId];

        require(loanLocal.active, "loan is closed");
        require(
            msg.sender == loanLocal.borrower ||
            delegatedManagers[loanLocal.id][msg.sender],
            "unauthorized"
        );

        address collateralToken = loanParamsLocal.collateralToken;
        uint256 collateral = loanLocal.collateral;

        uint256 maxDrawdown = IPriceFeeds(priceFeeds).getMaxDrawdown(
            loanParamsLocal.loanToken,
            collateralToken,
            loanLocal.principal,
            collateral,
            loanParamsLocal.maintenanceMargin
        );

        if (withdrawAmount > maxDrawdown) {
            actualWithdrawAmount = maxDrawdown;
        } else {
            actualWithdrawAmount = withdrawAmount;
        }

        collateral = collateral
            .sub(actualWithdrawAmount, "withdrawAmount too high");
        loanLocal.collateral = collateral;

        if (collateralToken == address(wethToken)) {
            vaultEtherWithdraw(
                receiver,
                actualWithdrawAmount
            );
        } else {
            vaultWithdraw(
                collateralToken,
                receiver,
                actualWithdrawAmount
            );
        }

        // update deposit amount
        (uint256 collateralToLoanRate, uint256 collateralToLoanPrecision) = IPriceFeeds(priceFeeds).queryRate(
            collateralToken,
            loanParamsLocal.loanToken
        );
        if (collateralToLoanRate != 0) {
            _setDepositAmount(
                loanId,
                actualWithdrawAmount
                    .mul(collateralToLoanRate)
                    .div(collateralToLoanPrecision),
                actualWithdrawAmount,
                true // isSubtraction
            );
        }

        emit WithdrawCollateral(
            loanLocal.borrower,
            collateralToken,
            loanId,
            actualWithdrawAmount
        );
    }

    function withdrawAccruedInterest(
        address loanToken)
        external
    {
        // pay outstanding interest to lender
        _payInterest(
            msg.sender, // lender
            loanToken
        );
    }

    function extendLoanDuration(
        bytes32 loanId,
        uint256 depositAmount,
        bool useCollateral,
        bytes calldata /*loanDataBytes*/) // for future use
        external
        payable
        nonReentrant
        returns (uint256 secondsExtended)
    {
        require(depositAmount != 0, "depositAmount is 0");
        Loan storage loanLocal = loans[loanId];
        LoanParams storage loanParamsLocal = loanParams[loanLocal.loanParamsId];

        require(loanLocal.active, "loan is closed");
        require(
            !useCollateral ||
            msg.sender == loanLocal.borrower ||
            delegatedManagers[loanLocal.id][msg.sender],
            "unauthorized"
        );

        require(msg.value == 0 || (!useCollateral && loanParamsLocal.loanToken == address(wethToken)), "wrong asset sent");

        // pay outstanding interest to lender
        _payInterest(
            loanLocal.lender,
            loanParamsLocal.loanToken
        );

        LoanInterest storage loanInterestLocal = loanInterest[loanLocal.id];

        _settleFeeRewardForInterestExpense(
            loanInterestLocal,
            loanLocal.id,
            loanParamsLocal.loanToken,
            loanLocal.borrower,
            block.timestamp
        );

        // Handle back interest: calculates interest owned since the loan endtime passed but the loan remained open
        uint256 backInterestOwed;
        if (block.timestamp > loanLocal.endTimestamp) {
            backInterestOwed = block.timestamp
                .sub(loanLocal.endTimestamp);
            backInterestOwed = backInterestOwed
                .mul(loanInterestLocal.owedPerDay);
            backInterestOwed = backInterestOwed
                .div(1 days);

            require(depositAmount > backInterestOwed, "deposit cannot cover back interest");
        }

        // deposit interest
        uint256 collateralUsed;
        if (useCollateral) {
            collateralUsed = _doSwapWithCollateral(
                loanLocal,
                loanParamsLocal,
                depositAmount
            );
        } else {
            if (msg.value == 0) {
                vaultDeposit(
                    loanParamsLocal.loanToken,
                    msg.sender,
                    depositAmount
                );
            } else {
                require(msg.value == depositAmount, "ether deposit mismatch");
                vaultEtherDeposit(
                    msg.sender,
                    msg.value
                );
            }
        }

        if (backInterestOwed != 0) {
            depositAmount = depositAmount
                .sub(backInterestOwed);

            // pay out backInterestOwed
            _payInterestTransfer(
                loanLocal.lender,
                loanParamsLocal.loanToken,
                backInterestOwed
            );
        }

        secondsExtended = depositAmount
            .mul(1 days)
            .div(loanInterestLocal.owedPerDay);

        loanLocal.endTimestamp = loanLocal.endTimestamp
            .add(secondsExtended);

        require(loanLocal.endTimestamp > block.timestamp &&
               (loanLocal.endTimestamp - block.timestamp) > 1 hours,
            "loan too short"
        );

        loanInterestLocal.depositTotal = loanInterestLocal.depositTotal
            .add(depositAmount);

        lenderInterest[loanLocal.lender][loanParamsLocal.loanToken].owedTotal = lenderInterest[loanLocal.lender][loanParamsLocal.loanToken].owedTotal
            .add(depositAmount);

        emit ExtendLoanDuration(
            loanLocal.borrower,
            loanParamsLocal.loanToken,
            loanId,
            depositAmount,
            collateralUsed,
            loanLocal.endTimestamp
        );
    }

    function reduceLoanDuration(
        bytes32 loanId,
        address receiver,
        uint256 withdrawAmount)
        external
        nonReentrant
        returns (uint256 secondsReduced)
    {
        require(withdrawAmount != 0, "withdrawAmount is 0");
        Loan storage loanLocal = loans[loanId];
        LoanParams storage loanParamsLocal = loanParams[loanLocal.loanParamsId];

        require(loanLocal.active, "loan is closed");
        require(
            msg.sender == loanLocal.borrower ||
            delegatedManagers[loanLocal.id][msg.sender],
            "unauthorized"
        );

        require(loanLocal.endTimestamp > block.timestamp, "loan term has ended");

        // pay outstanding interest to lender
        _payInterest(
            loanLocal.lender,
            loanParamsLocal.loanToken
        );

        LoanInterest storage loanInterestLocal = loanInterest[loanLocal.id];

        _settleFeeRewardForInterestExpense(
            loanInterestLocal,
            loanLocal.id,
            loanParamsLocal.loanToken,
            loanLocal.borrower,
            block.timestamp
        );

        uint256 interestDepositRemaining = loanLocal.endTimestamp
            .sub(block.timestamp)
            .mul(loanInterestLocal.owedPerDay)
            .div(1 days);
        require(withdrawAmount < interestDepositRemaining, "withdraw amount too high");

        // withdraw interest
        if (loanParamsLocal.loanToken == address(wethToken)) {
            vaultEtherWithdraw(
                receiver,
                withdrawAmount
            );
        } else {
            vaultWithdraw(
                loanParamsLocal.loanToken,
                receiver,
                withdrawAmount
            );
        }

        secondsReduced = withdrawAmount
            .mul(1 days)
            .div(loanInterestLocal.owedPerDay);

        require (loanLocal.endTimestamp > secondsReduced, "loan too short");

        loanLocal.endTimestamp = loanLocal.endTimestamp
            .sub(secondsReduced);

        require(loanLocal.endTimestamp > block.timestamp &&
               (loanLocal.endTimestamp - block.timestamp) > 1 hours,
            "loan too short"
        );

        loanInterestLocal.depositTotal = loanInterestLocal.depositTotal
            .sub(withdrawAmount);

        lenderInterest[loanLocal.lender][loanParamsLocal.loanToken].owedTotal = lenderInterest[loanLocal.lender][loanParamsLocal.loanToken].owedTotal
            .sub(withdrawAmount);

        emit ReduceLoanDuration(
            loanLocal.borrower,
            loanParamsLocal.loanToken,
            loanId,
            withdrawAmount,
            loanLocal.endTimestamp
        );
    }

    function setDepositAmount(
        bytes32 loanId,
        uint256 depositValueAsLoanToken,
        uint256 depositValueAsCollateralToken)
        external
    {
        // only callable by loan pools
        require(loanPoolToUnderlying[msg.sender] != address(0), "not authorized");

        _setDepositAmount(
            loanId,
            depositValueAsLoanToken,
            depositValueAsCollateralToken,
            false // isSubtraction
        );
    }

    function claimRewards(
        address receiver)
        external
        returns (uint256 claimAmount)
    {
        bytes32 slot = keccak256(abi.encodePacked(msg.sender, UserRewardsID));
        assembly {
            claimAmount := sload(slot)
        }

        if (claimAmount != 0) {
            assembly {
                sstore(slot, 0)
            }

            protocolTokenPaid = protocolTokenPaid
                .add(claimAmount);

            IERC20(vbzrxTokenAddress).transfer(
                receiver,
                claimAmount
            );

            emit ClaimReward(
                msg.sender,
                receiver,
                vbzrxTokenAddress,
                claimAmount
            );
        }
    }
    // protocol holds WMATIC, 100k matic will be held as native 
    function withdraw(address receiver, uint256 amount) 
        external 
        returns (uint256 withdrawAmount) 
    {
        // only callable by loan pools
        require(loanPoolToUnderlying[msg.sender] != address(0), "not authorized");
        withdrawAmount = address(this).balance;
        if (withdrawAmount > amount) {
            withdrawAmount = amount;
        }
        if (withdrawAmount != 0) {
            Address.sendValue(
                receiver,
                withdrawAmount
            );
        }
    }

    function deposit() external payable {
    }

    function rewardsBalanceOf(
        address user)
        external
        view
        returns (uint256 rewardsBalance)
    {
        bytes32 slot = keccak256(abi.encodePacked(user, UserRewardsID));
        assembly {
            rewardsBalance := sload(slot)
        }
    }

    /// @dev Gets current lender interest data totals for all loans with a specific oracle and interest token
    /// @param lender The lender address
    /// @param loanToken The loan token address
    /// @return interestPaid The total amount of interest that has been paid to a lender so far
    /// @return interestPaidDate The date of the last interest pay out, or 0 if no interest has been withdrawn yet
    /// @return interestOwedPerDay The amount of interest the lender is earning per day
    /// @return interestUnPaid The total amount of interest the lender is owned and not yet withdrawn
    /// @return interestFeePercent The fee retained by the protocol before interest is paid to the lender
    /// @return principalTotal The total amount of outstading principal the lender has loaned
    function getLenderInterestData(
        address lender,
        address loanToken)
        external
        view
        returns (
            uint256 interestPaid,
            uint256 interestPaidDate,
            uint256 interestOwedPerDay,
            uint256 interestUnPaid,
            uint256 interestFeePercent,
            uint256 principalTotal)
    {
        LenderInterest memory lenderInterestLocal = lenderInterest[lender][loanToken];

        interestUnPaid = block.timestamp.sub(lenderInterestLocal.updatedTimestamp).mul(lenderInterestLocal.owedPerDay).div(1 days);
        if (interestUnPaid > lenderInterestLocal.owedTotal)
            interestUnPaid = lenderInterestLocal.owedTotal;

        return (
            lenderInterestLocal.paidTotal,
            lenderInterestLocal.paidTotal != 0 ? lenderInterestLocal.updatedTimestamp : 0,
            lenderInterestLocal.owedPerDay,
            lenderInterestLocal.updatedTimestamp != 0 ? interestUnPaid : 0,
            lendingFeePercent,
            lenderInterestLocal.principalTotal
        );
    }

    /// @dev Gets current interest data for a loan
    /// @param loanId A unique id representing the loan
    /// @return loanToken The loan token that interest is paid in
    /// @return interestOwedPerDay The amount of interest the borrower is paying per day
    /// @return interestDepositTotal The total amount of interest the borrower has deposited
    /// @return interestDepositRemaining The amount of deposited interest that is not yet owed to a lender
    function getLoanInterestData(
        bytes32 loanId)
        external
        view
        returns (
            address loanToken,
            uint256 interestOwedPerDay,
            uint256 interestDepositTotal,
            uint256 interestDepositRemaining)
    {
        loanToken = loanParams[loans[loanId].loanParamsId].loanToken;
        interestOwedPerDay = loanInterest[loanId].owedPerDay;
        interestDepositTotal = loanInterest[loanId].depositTotal;

        uint256 endTimestamp = loans[loanId].endTimestamp;
        uint256 interestTime = block.timestamp > endTimestamp ?
            endTimestamp :
            block.timestamp;
        interestDepositRemaining = endTimestamp > interestTime ?
            endTimestamp
                .sub(interestTime)
                .mul(interestOwedPerDay)
                .div(1 days) :
                0;
    }

    // Only returns data for loans that are active
    // All(0): all loans
    // Margin(1): margin trade loans
    // NonMargin(2): non-margin trade loans
    // only active loans are returned
    function getUserLoans(
        address user,
        uint256 start,
        uint256 count,
        LoanType loanType,
        bool isLender,
        bool unsafeOnly)
        external
        view
        returns (LoanReturnData[] memory loansData)
    {
        EnumerableBytes32Set.Bytes32Set storage set = isLender ?
            lenderLoanSets[user] :
            borrowerLoanSets[user];

        uint256 end = start.add(count).min256(set.length());
        if (start >= end) {
            return loansData;
        }
        count = end-start;

        uint256 idx = count;
        LoanReturnData memory loanData;
        loansData = new LoanReturnData[](idx);
        for (uint256 i = --end; i >= start; i--) {
            loanData = _getLoan(
                set.get(i), // loanId
                loanType,
                unsafeOnly
            );
            if (loanData.loanId == 0) {
                if (i == 0) {
                    break;
                } else {
                    continue;
                }
            }

            loansData[count-(idx--)] = loanData;

            if (i == 0) {
                break;
            }
        }

        if (idx != 0) {
            count -= idx;
            assembly {
                mstore(loansData, count)
            }
        }
    }

    function getUserLoansCount(
        address user,
        bool isLender)
        external
        view
        returns (uint256)
    {
        return isLender ?
            lenderLoanSets[user].length() :
            borrowerLoanSets[user].length();
    }

    function getLoan(
        bytes32 loanId)
        external
        view
        returns (LoanReturnData memory loanData)
    {
        return _getLoan(
            loanId,
            LoanType.All,
            false // unsafeOnly
        );
    }

    function getActiveLoans(
        uint256 start,
        uint256 count,
        bool unsafeOnly)
        external
        view
        returns (LoanReturnData[] memory loansData)
    {
        return _getActiveLoans(start, count, unsafeOnly, false);
    }

    function getActiveLoansAdvanced(
        uint256 start,
        uint256 count,
        bool unsafeOnly,
        bool isLiquidatable)
        external
        view
        returns (LoanReturnData[] memory loansData) 
    {
        return _getActiveLoans(start, count, unsafeOnly, isLiquidatable);
    }

    function _getActiveLoans(
        uint256 start,
        uint256 count,
        bool unsafeOnly,
        bool isLiquidatable)
        internal
        view 
        returns (LoanReturnData[] memory loansData)
    {
        uint256 end = start.add(count).min256(activeLoansSet.length());
        if (start >= end) {
            return loansData;
        }
        count = end-start;

        uint256 idx = count;
        LoanReturnData memory loanData;
        loansData = new LoanReturnData[](idx);
        for (uint256 i = --end; i >= start; i--) {
            loanData = _getLoan(
                activeLoansSet.get(i), // loanId
                LoanType.All,
                unsafeOnly
            );

            if (loanData.loanId == 0) {
                if (i == 0) {
                    break;
                } else {
                    continue;
                }
            }

            if (isLiquidatable && loanData.currentMargin == 0) {
                // we skip, not adding it to result set
                if (i == 0) {
                    break;
                } else {
                    continue;
                }
            }

            loansData[count-(idx--)] = loanData;

            if (i == 0) {
                break;
            }
        }

        if (idx != 0) {
            count -= idx;
            assembly {
                mstore(loansData, count)
            }
        }
    }

    function getActiveLoansCount()
        external
        view
        returns (uint256)
    {
        return activeLoansSet.length();
    }

    function _getLoan(
        bytes32 loanId,
        LoanType loanType,
        bool unsafeOnly)
        internal
        view
        returns (LoanReturnData memory loanData)
    {
        Loan memory loanLocal = loans[loanId];
        LoanParams memory loanParamsLocal = loanParams[loanLocal.loanParamsId];

        if ((loanType == LoanType.Margin && loanParamsLocal.maxLoanTerm == 0) ||
            (loanType == LoanType.NonMargin && loanParamsLocal.maxLoanTerm != 0)) {
            return loanData;
        }

        LoanInterest memory loanInterestLocal = loanInterest[loanId];

        (uint256 currentMargin, uint256 value) = IPriceFeeds(priceFeeds).getCurrentMargin( // currentMargin, collateralToLoanRate
            loanParamsLocal.loanToken,
            loanParamsLocal.collateralToken,
            loanLocal.principal,
            loanLocal.collateral
        );

        uint256 maxLiquidatable;
        uint256 maxSeizable;
        if (currentMargin <= loanParamsLocal.maintenanceMargin) {
            (maxLiquidatable, maxSeizable) = _getLiquidationAmounts(
                loanLocal.principal,
                loanLocal.collateral,
                currentMargin,
                loanParamsLocal.maintenanceMargin,
                value, // collateralToLoanRate
                liquidationIncentivePercent[loanParamsLocal.loanToken][loanParamsLocal.collateralToken]
            );
        } else if (unsafeOnly) {
            return loanData;
        }

        uint256 depositValueAsLoanToken;
        uint256 depositValueAsCollateralToken;
        bytes32 slot = keccak256(abi.encode(loanId, LoanDepositValueID));
        assembly {
            depositValueAsLoanToken := sload(slot)
            depositValueAsCollateralToken := sload(add(slot, 1))
        }

        if (loanLocal.endTimestamp > block.timestamp) {
            value = loanLocal.endTimestamp
                .sub(block.timestamp)
                .mul(loanInterestLocal.owedPerDay)
                .div(1 days);
        } else {
            value = 0;
        }

        return LoanReturnData({
            loanId: loanId,
            endTimestamp: uint96(loanLocal.endTimestamp),
            loanToken: loanParamsLocal.loanToken,
            collateralToken: loanParamsLocal.collateralToken,
            principal: loanLocal.principal,
            collateral: loanLocal.collateral,
            interestOwedPerDay: loanInterestLocal.owedPerDay,
            interestDepositRemaining: value,
            startRate: loanLocal.startRate,
            startMargin: loanLocal.startMargin,
            maintenanceMargin: loanParamsLocal.maintenanceMargin,
            currentMargin: currentMargin,
            maxLoanTerm: loanParamsLocal.maxLoanTerm,
            maxLiquidatable: maxLiquidatable,
            maxSeizable: maxSeizable,
            depositValueAsLoanToken: depositValueAsLoanToken,
            depositValueAsCollateralToken: depositValueAsCollateralToken
        });
    }

    function _doSwapWithCollateral(
        Loan storage loanLocal,
        LoanParams memory loanParamsLocal,
        uint256 depositAmount)
        internal
        returns (uint256)
    {
        // reverts in _loanSwap if amountNeeded can't be bought
        (,uint256 sourceTokenAmountUsed,) = _loanSwap(
            loanLocal.id,
            loanParamsLocal.collateralToken,
            loanParamsLocal.loanToken,
            loanLocal.borrower,
            loanLocal.collateral, // minSourceTokenAmount
            0, // maxSourceTokenAmount (0 means minSourceTokenAmount)
            depositAmount, // requiredDestTokenAmount (partial spend of loanLocal.collateral to fill this amount)
            true, // bypassFee
            "" // loanDataBytes
        );
        loanLocal.collateral = loanLocal.collateral
            .sub(sourceTokenAmountUsed);

        // ensure the loan is still healthy
        (uint256 currentMargin, uint256 collateralToLoanRate) = IPriceFeeds(priceFeeds).getCurrentMargin(
            loanParamsLocal.loanToken,
            loanParamsLocal.collateralToken,
            loanLocal.principal,
            loanLocal.collateral
        );
        require(
            currentMargin > loanParamsLocal.maintenanceMargin,
            "unhealthy position"
        );

        // update deposit amount
        if (sourceTokenAmountUsed != 0 && collateralToLoanRate != 0) {
            _setDepositAmount(
                loanLocal.id,
                sourceTokenAmountUsed
                    .mul(collateralToLoanRate)
                    .div(WEI_PRECISION),
                sourceTokenAmountUsed,
                true // isSubtraction
            );
        }

        return sourceTokenAmountUsed;
    }

    function _setDepositAmount(
        bytes32 loanId,
        uint256 depositValueAsLoanToken,
        uint256 depositValueAsCollateralToken,
        bool isSubtraction)
        internal
    {
        bytes32 slot = keccak256(abi.encode(loanId, LoanDepositValueID));
        assembly {
            let val := sload(slot)
            switch isSubtraction
            case 0 {
                sstore(slot, add(val, depositValueAsLoanToken))
            }
            default {
                switch gt(val, depositValueAsLoanToken)
                case 1 {
                    sstore(slot, sub(val, depositValueAsLoanToken))
                }
                default {
                    sstore(slot, 0)
                }
            }

            slot := add(slot, 1)
            val := sload(slot)
            switch isSubtraction
            case 0 {
                sstore(slot, add(val, depositValueAsCollateralToken))
            }
            default {
                switch gt(val, depositValueAsCollateralToken)
                case 1 {
                    sstore(slot, sub(val, depositValueAsCollateralToken))
                }
                default {
                    sstore(slot, 0)
                }
            }
        }

        emit LoanDeposit(
            loanId,
            depositValueAsLoanToken,
            depositValueAsCollateralToken
        );
    }
}
