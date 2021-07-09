#!/usr/bin/python3

import pytest
from brownie import Contract, network, Wei

@pytest.fixture(scope="module")
def requireMaticFork():
    assert (network.show_active().find("-fork")>=0)

@pytest.fixture(scope="module", autouse=True)
def MATIC(accounts, TestToken):
    return Contract.from_abi("USDT", "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270", TestToken.abi)

@pytest.fixture(scope="module", autouse=True)
def ETH(accounts, TestToken):
    return Contract.from_abi("ETH", "0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619", TestToken.abi)

@pytest.fixture(scope="module", autouse=True)
def USDC(accounts, TestToken):
    return Contract.from_abi("USDC", "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174", TestToken.abi)

@pytest.fixture(scope="module", autouse=True)
def WBTC(accounts, TestToken):
    return Contract.from_abi("WMTC", "0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6", TestToken.abi)


@pytest.fixture(scope="module", autouse=True)
def USDT(accounts, TestToken):
    return Contract.from_abi("USDT", "0xc2132D05D31c914a87C6611C10748AEb04B58e8F", TestToken.abi)


@pytest.fixture(scope="module")
def BZX(accounts,LoanMaintenance_2, interface):
    bzx =  Contract.from_abi("bzx", address="0xfe4F0eb0A1Ad109185c9AaDE64C48ff8e928e54B",
                      abi=interface.IBZx.abi, owner=accounts[0])

    bzx.replaceContract(LoanMaintenance_2.deploy({'from':bzx.owner()}), {'from':bzx.owner()})
    return bzx



@pytest.fixture(scope="module", autouse=True)
def iMATIC(accounts, BZX, LoanTokenLogicWeth, MATIC ):
    iMATICAddress = BZX.underlyingToLoanPool(MATIC)
    return Contract.from_abi("iMATIC", address=iMATICAddress, abi=LoanTokenLogicWeth.abi, owner=accounts[0])


@pytest.fixture(scope="module", autouse=True)
def iETH(accounts, BZX, LoanTokenLogicStandard, ETH):
    iETHAddress = BZX.underlyingToLoanPool(ETH)
    return Contract.from_abi("iETH", address=iETHAddress , abi=LoanTokenLogicStandard.abi, owner=accounts[0])


@pytest.fixture(scope="module", autouse=True)
def iUSDC(accounts, BZX, LoanTokenLogicStandard, USDC):
    iUSDCAddress = BZX.underlyingToLoanPool(USDC)
    return Contract.from_abi("iUSDC", address=iUSDCAddress, abi=LoanTokenLogicStandard.abi, owner=accounts[0])

@pytest.fixture(scope="module", autouse=True)
def iWBTC(accounts, BZX, LoanTokenLogicStandard, WBTC):
    iWBTCAddress = BZX.underlyingToLoanPool(WBTC)
    return Contract.from_abi("iWBTC", address=iWBTCAddress, abi=LoanTokenLogicStandard.abi, owner=accounts[0])

@pytest.fixture(scope="module", autouse=True)
def iUSDT(accounts, BZX, LoanTokenLogicStandard, USDT):
    iUSDTAddress = BZX.underlyingToLoanPool(USDT)
    return Contract.from_abi("iUSDT", address=iUSDTAddress, abi=LoanTokenLogicStandard.abi, owner=accounts[0])


@pytest.fixture(scope="module", autouse=True)
def pgovToken(accounts, GovToken):
    return Contract.from_abi("GovToken", address="0xd5d84e75f48E75f01fb2EB6dFD8eA148eE3d0FEb", abi=GovToken.abi, owner=accounts[0]);


@pytest.fixture(scope="module", autouse=True)
def mintCoordinator(accounts, MintCoordinator_Polygon):
    return Contract.from_abi("mintCoordinator", address="0x21baFa16512D6B318Cca8Ad579bfF04f7b7D3440", abi=MintCoordinator_Polygon.abi, owner=accounts[0]);

@pytest.fixture(scope="module", autouse=True)
def SUSHI_PGOV_MATIC(accounts, interface):
    return Contract.from_abi("SUSHI_PGOV_wMATIC", "0xC698b8a1391F88F497A4EF169cA85b492860b502", interface.IPancakePair.abi)

@pytest.fixture(scope="module", autouse=True)
def masterChef(accounts, chain, MasterChef_Polygon, iMATIC, iETH, iUSDC, iWBTC, iUSDT, pgovToken, Proxy, MintCoordinator_Polygon):
    masterChefProxy = Contract.from_abi("masterChefProxy", address="0xd39Ff512C3e55373a30E94BB1398651420Ae1D43", abi=Proxy.abi)
    # masterChefImpl = MasterChef_Polygon.deploy({'from': masterChefProxy.owner()})
    # masterChefProxy.replaceImplementation(masterChefImpl, {'from': masterChefProxy.owner()})
    masterChef = Contract.from_abi("masterChef", address=masterChefProxy, abi=MasterChef_Polygon.abi)

    # masterChef.setStartBlock(chain.height-100, {'from': masterChef.owner()})

    # if(len(masterChef.getPoolInfos())==2):
    #     masterChef.add(12500, iMATIC, True, {'from': masterChef.owner()})
    #     masterChef.add(12500, iUSDC, True, {'from': masterChef.owner()})
    #     masterChef.massUpdatePools({'from': masterChef.owner()})

    # mintCoordinator = Contract.from_abi("mintCoordinator", address="0x21baFa16512D6B318Cca8Ad579bfF04f7b7D3440", abi=MintCoordinator_Polygon.abi, owner=accounts[0]);
    # mintCoordinator.addMinter(masterChef, {"from": mintCoordinator.owner()})
    # pgovToken.transferOwnership(mintCoordinator, {"from": pgovToken.owner()})


    # for i in range(0,len(masterChef.getPoolInfos())):
    #     masterChef.set(i, 12500, True, {'from': masterChef.owner()})
    #     masterChef.setLocked(0,False,{'from': masterChef.owner()})

    return masterChef

@pytest.fixture(scope="module", autouse=True)
def tokens(accounts, chain, iMATIC, MATIC, iUSDC, USDC):
    return {
        'iMATIC': iMATIC,
        'iUSDC': iUSDC,
        'MATIC': MATIC,
        'USDC': USDC
    }


def initBalance(account, token, lpToken, addBalance):
    if(lpToken.symbol() == 'iMATIC'):
        lpToken.mintWithEther(account, {'from': account, 'value': addBalance})
    if(lpToken.symbol() == 'iUSDC'):
        USDC.approve(iUSDT, 2**256-1, {'from': account})
        iUSDC.mint(account, addBalance, {'from': account})
        iUSDC.approve(account, 2**256-1, {'from': account})

