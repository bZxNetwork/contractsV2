#!/usr/bin/python3

import pytest
from brownie import network, Contract, Wei, chain


@pytest.fixture(scope="module")
def requireMainnetFork():
    assert (network.show_active() == "mainnet-fork" or network.show_active() == "mainnet-fork-alchemy")


@pytest.fixture(scope="module")
def LPT(accounts):
    LPT = loadContractFromEtherscan(
        "0xe26A220a341EAca116bDa64cF9D5638A935ae629", "LPT")
    return LPT


@pytest.fixture(scope="module")
def vBZRX(accounts, BZRXVestingToken):
    vBZRX = loadContractFromAbi(
        "0xb72b31907c1c95f3650b64b2469e08edacee5e8f", "vBZRX", BZRXVestingToken.abi)
    return vBZRX


@pytest.fixture(scope="module")
def iUSDC(accounts, LoanTokenLogicStandard):
    iUSDC = loadContractFromAbi(
        "0x32E4c68B3A4a813b710595AebA7f6B7604Ab9c15", "iUSDC", LoanTokenLogicStandard.abi)
    return iUSDC


@pytest.fixture(scope="module")
def WETH(accounts, TestWeth):
    WETH = loadContractFromAbi(
        "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2", "WETH", TestWeth.abi)
    return WETH


@pytest.fixture(scope="module")
def USDC(accounts, TestToken):
    USDC = loadContractFromAbi(
        "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48", "USDC", TestToken.abi)
    return USDC


@pytest.fixture(scope="module")
def USDT(accounts, TestToken):
    USDT = loadContractFromAbi(
        "0xdAC17F958D2ee523a2206206994597C13D831ec7", "USDT", TestToken.abi)
    return USDT


@pytest.fixture(scope="module")
def WBTC(accounts, TestToken):
    WBTC = loadContractFromAbi(
        "0x2260fac5e5542a773aa44fbcfedf7c193bc2c599", "WBTC", TestToken.abi)
    return WBTC


@pytest.fixture(scope="module")
def BZRX(accounts, TestToken):
    BZRX = loadContractFromAbi(
        "0x56d811088235F11C8920698a204A5010a788f4b3", "BZRX", TestToken.abi)
    BZRX.transfer(accounts[0], 1000*10**18, {'from': BZRX.address})
    return BZRX


@pytest.fixture(scope="module")
def iBZRX(accounts, BZRX, LoanTokenLogicStandard):
    iBZRX = loadContractFromAbi(
        "0x18240BD9C07fA6156Ce3F3f61921cC82b2619157", "iBZRX", LoanTokenLogicStandard.abi)
    return iBZRX


@pytest.fixture(scope="module")
def iUSDC(accounts, BZRX, LoanTokenLogicStandard):
    iUSDC = loadContractFromAbi(
        "0x32E4c68B3A4a813b710595AebA7f6B7604Ab9c15", "iUSDC", LoanTokenLogicStandard.abi)
    return iUSDC


@pytest.fixture(scope="module")
def iUSDT(accounts, BZRX, LoanTokenLogicStandard):
    iUSDT = loadContractFromAbi(
        "0x7e9997a38A439b2be7ed9c9C4628391d3e055D48", "iUSDT", LoanTokenLogicStandard.abi)
    return iUSDT


@pytest.fixture(scope="module")
def iWBTC(accounts, BZRX, LoanTokenLogicStandard):
    iWBTC = loadContractFromAbi(
        "0x2ffa85f655752fB2aCB210287c60b9ef335f5b6E", "iWBTC", LoanTokenLogicStandard.abi)
    return iWBTC


def loadContractFromEtherscan(address, alias):
    try:
        return Contract(alias)
    except ValueError:
        contract = Contract.from_explorer(address)
        contract.set_alias(alias)
        return contract


def loadContractFromAbi(address, alias, abi):
    try:
        return Contract(alias)
    except ValueError:
        contract = Contract.from_abi(alias, address=address, abi=abi)
        return contract


@pytest.fixture(scope="module")
def helperContract(accounts, HelperImpl, HelperProxy):
    helperImpl = accounts[0].deploy(HelperImpl)
    helperProxy = accounts[0].deploy(HelperProxy, helperImpl)
    return Contract.from_abi("helperProxy", helperProxy, HelperImpl.abi)


def testHelperContract(requireMainnetFork, helperContract, accounts, iUSDC, USDC, iUSDT, USDT, iWBTC, WBTC):

 

    USDC.transfer(accounts[0], 203*10**6, {'from': "0x0A59649758aa4d66E25f08Dd01271e891fe52199"})
    USDC.approve(iUSDC, 500e18, {'from': accounts[0]})
    iUSDC.mint(accounts[0], 104*10**6, {'from':accounts[0]})

    WBTC.transfer(accounts[0], 3*10**8, {'from': WBTC.address})
    WBTC.approve(iWBTC, 500e18, {'from': accounts[0]})
    iWBTC.mint(accounts[0], 1*10**8, {'from': accounts[0]})


    balanceOfUSDC = USDC.balanceOf(accounts[0])
    balanceOfiUSDC = iUSDC.balanceOf(accounts[0])
    balanceOfWBTC = WBTC.balanceOf(accounts[0])
    balanceOfiWBTC = iWBTC.balanceOf(accounts[0])

    balancesOfHelper = helperContract.balanceOf.call([USDC, iUSDC, WBTC, iWBTC], accounts[0])
    balanceOfExpected =[balanceOfUSDC, balanceOfiUSDC, balanceOfWBTC, balanceOfiWBTC]
    assert(balancesOfHelper == balanceOfExpected)


    actualResult = helperContract.tokenPrice.call([iUSDC, iWBTC])
    assert(actualResult == [iUSDC.tokenPrice(), iWBTC.tokenPrice()])
    
    actualResult = helperContract.supplyInterestRate.call([iUSDC, iWBTC])
    assert(actualResult == [iUSDC.supplyInterestRate(), iWBTC.supplyInterestRate()])
    
    actualResult = helperContract.borrowInterestRate.call([iUSDC, iWBTC])
    assert(actualResult == [iUSDC.borrowInterestRate(), iWBTC.borrowInterestRate()])
    
    actualResult = helperContract.assetBalanceOf.call([iUSDC, iWBTC], accounts[0])
    assert(actualResult == [iUSDC.assetBalanceOf(accounts[0]), iWBTC.assetBalanceOf(accounts[0])])
    
    actualResult = helperContract.profitOf.call([iUSDC, iWBTC], accounts[0])
    assert(actualResult == [iUSDC.profitOf(accounts[0]), iWBTC.profitOf(accounts[0])])
    
    actualResult = helperContract.marketLiquidity.call([iUSDC, iWBTC])
    assert(actualResult == [iUSDC.marketLiquidity(), iWBTC.marketLiquidity()])

    actualResult = helperContract.reserveDetails([iUSDC, iWBTC])

    assert(actualResult[0][0] == iUSDC)
    assert(actualResult[1][0] == iWBTC)

    assert(actualResult[0][1] == iUSDC.totalAssetSupply())
    assert(actualResult[0][2] == iUSDC.totalAssetBorrow()) 
    assert(actualResult[0][3] == iUSDC.supplyInterestRate()) 
    assert(actualResult[0][4] == iUSDC.avgBorrowInterestRate()) 
    assert(actualResult[0][5] == iUSDC.nextBorrowInterestRate(0)) 


    assert(actualResult[1][1] == iWBTC.totalAssetSupply())
    assert(actualResult[1][2] == iWBTC.totalAssetBorrow()) 
    assert(actualResult[1][3] == iWBTC.supplyInterestRate()) 
    assert(actualResult[1][4] == iWBTC.avgBorrowInterestRate()) 
    assert(actualResult[1][5] == iWBTC.nextBorrowInterestRate(0)) 

    actualResult = helperContract.assetRates(USDC, [WBTC], [10**18])
    assert actualResult[0][0] > 0
    assert True

