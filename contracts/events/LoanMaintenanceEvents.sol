/**
 * Copyright 2017-2021, bZeroX, LLC. All Rights Reserved.
 * Licensed under the Apache License, Version 2.0.
 */

pragma solidity 0.5.17;


contract LoanMaintenanceEvents {

    event DepositCollateral(
        address indexed user,
        address indexed depositToken,
        bytes32 indexed loanId,
        uint256 depositAmount
    );

    event WithdrawCollateral(
        address indexed user,
        address indexed withdrawToken,
        bytes32 indexed loanId,
        uint256 withdrawAmount
    );

    event ExtendLoanDuration(
        address indexed user,
        address indexed depositToken,
        bytes32 indexed loanId,
        uint256 depositAmount,
        uint256 collateralUsedAmount,
        uint256 newEndTimestamp
    );

    event ReduceLoanDuration(
        address indexed user,
        address indexed withdrawToken,
        bytes32 indexed loanId,
        uint256 withdrawAmount,
        uint256 newEndTimestamp
    );

    event LoanDeposit(
        bytes32 indexed loanId,
        uint256 depositValueAsLoanToken,
        uint256 depositValueAsCollateralToken
    );

    event ClaimReward(
        address indexed user,
        address indexed receiver,
        address indexed token,
        uint256 amount
    );

    event TransferLoan(
        address indexed currentOwner,
        address indexed newOwner,
        bytes32 indexed loanId
    );

    enum LoanType {
        All,
        Margin,
        NonMargin
    }

    struct LoanReturnData {
        bytes32 loanId; // id of the loan
        uint96 endTimestamp; // loan end timestamp
        address loanToken; // loan token address
        address collateralToken; // collateral token address
        uint256 principal; // principal amount of the loan
        uint256 collateral; // collateral amount of the loan
        uint256 interestOwedPerDay; // interest owned per day
        uint256 interestDepositRemaining; // remaining unspent interest
        uint256 startRate; // collateralToLoanRate
        uint256 startMargin; // margin with which loan was open
        uint256 maintenanceMargin; // maintenance margin
        uint256 currentMargin; /// current margin
        uint256 maxLoanTerm; // maximum term of the loan
        uint256 maxLiquidatable; // current max liquidatable
        uint256 maxSeizable; // current max seizable
        uint256 depositValueAsLoanToken; // net value of deposit denominated as loanToken
        uint256 depositValueAsCollateralToken; // net value of deposit denominated as collateralToken
    }
}
