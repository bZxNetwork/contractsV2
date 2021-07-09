#!/usr/bin/python3

import pytest
from brownie import reverts

def test_TransferLoan(requireMaticFork, BZX, accounts):
    account1 = accounts[0]
    account2 = accounts[1]
    account3 = accounts[2]

    loans = BZX.getActiveLoans(0,10, False)
    loan = loans[0]
    borrower = BZX.loans(loan[0])[9]

    with reverts("no owner change"):
        BZX.transferLoan(loan[0], borrower, {'from':borrower})

    with reverts("unauthorized"):
        BZX.transferLoan(loan[0], account3, {'from':account2})

    BZX.transferLoan(loan[0], account1, {'from':borrower})
    assert account1 == BZX.loans(loan[0])[9]
    BZX.setDelegatedManager(loan[0], account2, True, {'from': account1})
    BZX.transferLoan(loan[0], account3, {'from':account2})
    assert account3 == BZX.loans(loan[0])[9]



