#!/usr/bin/python3

import pytest
from brownie import Contract, network, Wei
from brownie.network.state import _add_contract, _remove_contract

@pytest.fixture(scope="module")
def requireMaticFork():
    assert (network.show_active().find("fork")>=0)


@pytest.fixture(scope="module")
def BZX(accounts, interface):
    return Contract.from_abi("bzx", address="0xfe4F0eb0A1Ad109185c9AaDE64C48ff8e928e54B", abi=interface.IBZx.abi, owner=accounts[0])

@pytest.fixture(scope="module", autouse=True)
def USDC(accounts, TestToken):
    return Contract.from_abi("USDC", "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174", TestToken.abi)
    
@pytest.fixture(scope="module")
def iUSDC(BZX, accounts, LoanTokenLogicStandard, LoanToken, USDC, LoanMaintenance, RebateTokenHolder):
    # assert False
    iToken = Contract.from_abi("iTokenTemp", "0x2E1A74a16e3a9F8e3d825902Ab9fb87c606cB13f", LoanTokenLogicStandard.abi)
    proxy = Contract.from_abi("loanToken", iToken, LoanToken.abi)
    bzxOwner = accounts.at('0xB7F72028D9b502Dc871C444363a7aC5A52546608', True)
    loanTokenLogicStandard = bzxOwner.deploy(LoanTokenLogicStandard, bzxOwner)
    proxy.setTarget(loanTokenLogicStandard, {'from': bzxOwner})
    
    loanMaintenance = bzxOwner.deploy(LoanMaintenance)
    BZX.replaceContract(loanMaintenance, {"from": bzxOwner})
    BZX.deposit({"from": accounts[9], "amount": 100e18})
    # rebateTokenHolder = bzxOwner.deploy(RebateTokenHolder, bzxOwner)
    # rebateTokenHolder.giveApproval("0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270", iToken, 2**256-1)
    # accounts[0].transfer(rebateTokenHolder, 100e18)
    # iToken.setRebateTokenHolder(rebateTokenHolder, {"from": bzxOwner})

    USDC.transfer(accounts[0], 1000e6, {'from': '0x986a2fCa9eDa0e06fBf7839B89BfC006eE2a23Dd'})
    USDC.approve(iToken, 2**256-1, {'from': accounts[0]})

    return iToken



def test_mainflow(requireMaticFork, BZX, accounts, ETH, iUSDC, USDC):



    USDC.transfer(accounts[0], 1000e6, {'from': '0x986a2fCa9eDa0e06fBf7839B89BfC006eE2a23Dd'})
    USDC.approve(iUSDC, 2**256-1, {'from': accounts[0]})
    assert False
    iUSDC.mint(accounts[0], 1e6, {'from': accounts[0]})
    iUSDC.mintWithGasRebate(accounts[0], 1e6, {'from': accounts[0]})
    
    assert False
    