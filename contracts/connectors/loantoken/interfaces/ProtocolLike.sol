/**
 * Copyright 2017-2021, bZeroX, LLC. All Rights Reserved.
 * Licensed under the Apache License, Version 2.0.
 */

pragma solidity 0.5.17;
pragma experimental ABIEncoderV2;


contract ProtocolLike {

    struct LoanOpenData {
        bytes32 loanId;
        uint256 principal;
        uint256 collateral;
    }

    /// @dev This is THE function that borrows or trades on the protocol
    /// @param loanParamsId id of the LoanParam created beforehand by setupLoanParams function
    /// @param loanId id of existing loan, if 0, start a new loan
    /// @param isTorqueLoan boolean whether it is toreque or non torque loan
    /// @param initialMargin in WEI_PERCENT_PRECISION
    /// @param sentAddresses array of size 4:
    ///         lender: must match loan if loanId provided
    ///         borrower: must match loan if loanId provided
    ///         receiver: receiver of funds (address(0) assumes borrower address)
    ///         manager: delegated manager of loan unless address(0)
    /// @param sentValues array of size 5:
    ///         newRate: new loan interest rate
    ///         newPrincipal: new loan size (borrowAmount + any borrowed interest)
    ///         torqueInterest: new amount of interest to escrow for Torque loan (determines initial loan length)
    ///         loanTokenReceived: total loanToken deposit (amount not sent to borrower in the case of Torque loans)
    ///         collateralTokenReceived: total collateralToken deposit
    /// @param loanDataBytes required when sending ether
    /// @return principal of the loan and collateral amount
    function borrowOrTradeFromPool(
        bytes32 loanParamsId,
        bytes32 loanId,
        bool isTorqueLoan,
        uint256 initialMargin,
        address[4] calldata sentAddresses,
        uint256[5] calldata sentValues,
        bytes calldata loanDataBytes)
        external
        payable
        returns (LoanOpenData memory);

    function withdrawAccruedInterest(
        address loanToken)
        external;

    function setDepositAmount(
        bytes32 loanId,
        uint256 depositValueAsLoanToken,
        uint256 depositValueAsCollateralToken)
        external;

    function getTotalPrincipal(
        address lender,
        address loanToken)
        external
        view
        returns (uint256);

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
            uint256 principalTotal);

    function priceFeeds()
        external
        view
        returns (address);

    function getEstimatedMarginExposure(
        address loanToken,
        address collateralToken,
        uint256 loanTokenSent,
        uint256 collateralTokenSent,
        uint256 interestRate,
        uint256 newPrincipal)
        external
        view
        returns (uint256);

    function getRequiredCollateralByParams(
        bytes32 loanParamsId,
        uint256 newPrincipal)
        external
        view
        returns (uint256 collateralAmountRequired);

    function getBorrowAmountByParams(
        bytes32 loanParamsId,
        uint256 collateralTokenAmount)
        external
        view
        returns (uint256 borrowAmount);

    function isLoanPool(
        address loanPool)
        external
        view
        returns (bool);

    function lendingFeePercent()
        external
        view
        returns (uint256);

    function withdraw(address receiver, uint256 amount) 
        external 
        returns (uint256 withdrawAmount);
}
