/**
 * Copyright 2017-2021, bZeroX, LLC. All Rights Reserved.
 * Licensed under the Apache License, Version 2.0.
 */

pragma solidity 0.5.17;
pragma experimental ABIEncoderV2;

import "../../core/State.sol";
import "../../events/LoanMaintenanceEvents.sol";


contract LoanMaintenance_2 is State, LoanMaintenanceEvents {

    function initialize(
        address target)
        external
        onlyOwner
    {
        _setTarget(this.transferLoan.selector, target);
    }

    function transferLoan(
        bytes32 loanId,
        address newOwner)
        external
        nonReentrant
    {
        Loan storage loanLocal = loans[loanId];
        address currentOwner = loanLocal.borrower;
        require(loanLocal.active, "loan is closed");
        require(currentOwner != newOwner, "no owner change");
        require(
            msg.sender == currentOwner ||
            delegatedManagers[loanId][msg.sender],
            "unauthorized"
        );

        require(borrowerLoanSets[currentOwner].removeBytes32(loanId), "error in transfer");
        borrowerLoanSets[newOwner].addBytes32(loanId);
        loanLocal.borrower = newOwner;

        emit TransferLoan(
            currentOwner,
            newOwner,
            loanId
        );
    }
}
