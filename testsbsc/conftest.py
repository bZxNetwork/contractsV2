#!/usr/bin/python3

import pytest
from brownie import Contract, network, Wei

@pytest.fixture(scope="module")
def requireFork():
    assert (network.show_active().find("-fork")>=0)

@pytest.fixture(scope="module", autouse=True)
def BNB(accounts, TestToken):
    return Contract.from_abi("BNB", "0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c", TestToken.abi)

@pytest.fixture(scope="module", autouse=True)
def ETH(accounts, TestToken):
    return Contract.from_abi("ETH", "0x2170ed0880ac9a755fd29b2688956bd959f933f8", TestToken.abi)

@pytest.fixture(scope="module", autouse=True)
def WBTC(accounts, TestToken):
    return Contract.from_abi("WBTC", "0x7130d2a12b9bcbfae4f2634d864a1ee1ce3ead9c", TestToken.abi)


@pytest.fixture(scope="module", autouse=True)
def USDT(accounts, TestToken):
    return Contract.from_abi("USDT", "0x55d398326f99059ff775485246999027b3197955", TestToken.abi)

@pytest.fixture(scope="module", autouse=True)
def BUSD(accounts, TestToken):
    return Contract.from_abi("BUSD", "0xe9e7cea3dedca5984780bafc599bd69add087d56", TestToken.abi)


@pytest.fixture(scope="module")
def BZX(accounts, interface):
    return Contract.from_abi("bzx", address="0xc47812857a74425e2039b57891a3dfcf51602d5d",abi=interface.IBZx.abi, owner=accounts[0])



@pytest.fixture(scope="module", autouse=True)
def iBNB(accounts, BZX, LoanTokenLogicWeth, BNB ):
    iBNBAddress = BZX.underlyingToLoanPool(BNB)
    return Contract.from_abi("iBNB", address=iBNBAddress, abi=LoanTokenLogicWeth.abi, owner=accounts[0])


@pytest.fixture(scope="module", autouse=True)
def iETH(accounts, BZX, LoanTokenLogicStandard, ETH):
    iETHAddress = BZX.underlyingToLoanPool(ETH)
    return Contract.from_abi("iETH", address=iETHAddress , abi=LoanTokenLogicStandard.abi, owner=accounts[0])

@pytest.fixture(scope="module", autouse=True)
def iWBTC(accounts, BZX, LoanTokenLogicStandard, WBTC):
    iWBTCAddress = BZX.underlyingToLoanPool(WBTC)
    return Contract.from_abi("iWBTC", address=iWBTCAddress, abi=LoanTokenLogicStandard.abi, owner=accounts[0])

@pytest.fixture(scope="module", autouse=True)
def iUSDT(accounts, BZX, LoanTokenLogicStandard, USDT):
    iUSDTAddress = BZX.underlyingToLoanPool(USDT)
    return Contract.from_abi("iUSDT", address=iUSDTAddress, abi=LoanTokenLogicStandard.abi, owner=accounts[0])

@pytest.fixture(scope="module", autouse=True)
def iBUSD(accounts, BZX, LoanTokenLogicStandard, USDT):
    iBUSDAddress = BZX.underlyingToLoanPool(USDT)
    return Contract.from_abi("iBUSD", address=iBUSDAddress, abi=LoanTokenLogicStandard.abi, owner=accounts[0])


@pytest.fixture(scope="module", autouse=True)
def bgovToken(accounts, GovToken):
    return Contract.from_abi("GovToken", address="0xf8E026dC4C0860771f691EcFFBbdfe2fa51c77CF", abi=GovToken.abi, owner=accounts[0]);


@pytest.fixture(scope="module", autouse=True)
def BGOV_BNB(accounts, interface):
    return Contract.from_abi("BGOV_BNB", "0x10ED43C718714eb63d5aA57B78B54704E256024E", interface.IPancakePair.abi)

@pytest.fixture(scope="module", autouse=True)
def masterChef(accounts, MasterChef_BSC, interface, iBNB, iETH, iWBTC, iUSDT, bgovToken, Proxy):
    masterChefProxy = Contract.from_abi("masterChefProxy", address="0x1FDCA2422668B961E162A8849dc0C2feaDb58915", abi=Proxy.abi)
    masterChefImpl = MasterChef_BSC.deploy({'from': masterChefProxy.owner()})
    masterChefProxy.replaceImplementation(masterChefImpl, {'from': masterChefProxy.owner()})
    masterChef = Contract.from_abi("masterChef", address=masterChefProxy, abi=interface.IMasterChefAdmin.abi)

    for i in range(0,len(masterChef.getPoolInfos())):
    #    masterChef.set(i, 12500, True, {'from': masterChef.owner()})
        masterChef.setLocked(0,False,{'from': masterChef.owner()})
    masterChef.togglePause(False, {'from': masterChef.owner()})
    return masterChef

@pytest.fixture(scope="module", autouse=True)
def tokens(accounts, chain, iBNB, BNB, iBUSD, BUSD):
    return {
        'iBNB': iBNB,
        'iBUSD': iBUSD,
        'BNB': BNB,
        'BUSD': BUSD
    }


def initBalance(account, token, lpToken, addBalance):
    if(lpToken.symbol() == 'iBNB'):
        lpToken.mintWithEther(account, {'from': account, 'value': addBalance})
    if(lpToken.symbol() == 'iBUSD'):
        BUSD.approve(iUSDT, 2**256-1, {'from': account})
        iBUSD.mint(account, addBalance, {'from': account})
        iBUSD.approve(account, 2**256-1, {'from': account})

