#!/usr/bin/python3

import pytest
from brownie import ETH_ADDRESS, network, Contract, Wei, chain

@pytest.fixture(scope="module")
def requireMainnetFork():
    assert (network.show_active() == "mainnet-fork" or network.show_active() == "mainnet-fork-alchemy" or network.show_active() == "bsc-main-fork") 


@pytest.fixture(scope="module")
def BZX(accounts, interface, LoanMaintenance):
    
    bzx = Contract.from_abi("bzx", address="0xD8Ee69652E4e4838f2531732a46d1f7F584F0b7f", abi=interface.IBZx.abi, owner=accounts[0])
    bzxOwner = accounts.at(bzx.owner(), True)
    loanMaintenanceImpl = bzxOwner.deploy(LoanMaintenance)
    bzx.replaceContract(loanMaintenanceImpl, {'from': bzxOwner})
    bzxNew = Contract.from_abi("bzx", address="0xD8Ee69652E4e4838f2531732a46d1f7F584F0b7f", abi=LoanMaintenance.abi, owner=accounts[0])
    # loans = bzxNew.getActiveLoans(0, 100, True)

    return bzxNew
 

 
    

def testGetActiveLoans(requireMainnetFork, BZX, accounts):
    loans = BZX.getActiveLoans(0, 100, True)
    loans2 = BZX.getActiveLoansAdvanced.call(0, 100, True, True)
    loans3 = BZX.getActiveLoansAdvanced.call(0, 100, True, False)

    assert loans == loans3
    for l in loans2:
        assert l[4] > 0 # principal
        assert l[5] > 0 # collateral
        assert l[11] > 0 # currentMargin
        assert l[13] > 0 # maxLiquidatable
        assert l[14] > 0 # maxSeizable

    assert True
