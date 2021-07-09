#!/usr/bin/python3

import pytest
from brownie import ETH_ADDRESS, network, Contract, Wei, chain

@pytest.fixture(scope="module")
def requireMainnetFork():
    assert (network.show_active() == "mainnet-fork" or network.show_active() == "mainnet-fork-alchemy" or network.show_active() == "bsc-main-fork") 


@pytest.fixture(scope="module")
def FEE_EXTRACTOR(accounts, FeeExtractAndDistribute_BSC, BZX, Proxy):
    FEE_EXTRACTOR_IMPL = accounts[9].deploy(FeeExtractAndDistribute_BSC)
    proxy = accounts[9].deploy(Proxy, FEE_EXTRACTOR_IMPL)
    # proxy.replaceImplementation(FEE_EXTRACTOR_IMPL, {'from': accounts[9]})
    fee = Contract.from_abi("fee_extractor", address=proxy, abi=FeeExtractAndDistribute_BSC.abi, owner=accounts[9])
    tokens = [
    "0xa184088a740c695E156F91f5cC086a06bb78b827", #   AUTO
    "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c", #   BNB
    "0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c", #   BTC
    "0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56", #   BUSD
    "0x4b87642AEDF10b642BE4663Db842Ecc5A88bf5ba", #   BZRX
    "0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82", #   CAKE
    "0xbA2aE424d960c26247Dd6c32edC70B295c744C43", #   DOGE
    "0x250632378E573c6Be1AC2f97Fcdf00515d0Aa91B", #   ETH
    "0xF8A0BF9cF54Bb92F17374d9e9A321E6a111a51bD", #   LINK
    "0x55d398326f99059fF775485246999027B3197955", #   USDT  

    ]
    BZX.setFeesController(fee, {'from': BZX.owner()})
    fee.setFeeTokens(tokens)
    return fee




@pytest.fixture(scope="module")
def BZX(accounts, interface):
    return Contract.from_abi("bzx", address="0xC47812857A74425e2039b57891a3DFcF51602d5d", abi=interface.IBZx.abi, owner=accounts[0])

@pytest.fixture(scope="module")
def BGOV(accounts, TestToken):
    return Contract.from_abi("BGOV", address="0xf8E026dC4C0860771f691EcFFBbdfe2fa51c77CF", abi=TestToken.abi)

@pytest.fixture(scope="module")
def BZRX(accounts, TestToken):
    return Contract.from_abi("BZRX", address="0x4b87642AEDF10b642BE4663Db842Ecc5A88bf5ba", abi=TestToken.abi)

@pytest.fixture(scope="module")
def WBNB(accounts, TestToken):
    return Contract.from_abi("WBNB", address="0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c", abi=TestToken.abi)

@pytest.fixture(scope="module")
def MASTER_CHEF(accounts, MasterChef_BSC, Proxy):
    chefImpl = accounts[0].deploy(MasterChef_BSC)
    proxy = Contract.from_abi("proxy", address="0x1FDCA2422668B961E162A8849dc0C2feaDb58915", abi=Proxy.abi, owner=accounts[0])
    proxy.replaceImplementation(chefImpl, {'from': proxy.owner()})
    return Contract.from_abi("masterChef", address="0x1FDCA2422668B961E162A8849dc0C2feaDb58915", abi=MasterChef_BSC.abi, owner=accounts[0])

def loadContractFromAbi(address, alias, abi):
    try:
        return Contract(alias)
    except ValueError:
        contract = Contract.from_abi(alias, address=address, abi=abi)
        return contract

    

def testFeeExtractor(requireMainnetFork, FEE_EXTRACTOR, BZX, MASTER_CHEF, BGOV, BZRX, WBNB, TestToken, accounts):

    BZRX.approve(FEE_EXTRACTOR, 2**256-1, {"from": accounts[9]})
    BZRX.transfer(accounts[9], 1e6*1e18, {"from": "0xF68a4b64162906efF0fF6aE34E2bB1Cd42FEf62d"})
    FEE_EXTRACTOR.depositToken(BZRX, 1e6*1e18, {"from": accounts[9]})
    MASTER_CHEF.updatePool(7)
    beforeBalanceMasterChief = BGOV.balanceOf(MASTER_CHEF);
    tx = FEE_EXTRACTOR.sweepFees()
    afterBalanceMasterChief = BGOV.balanceOf(MASTER_CHEF);
    
    diff = afterBalanceMasterChief - beforeBalanceMasterChief


    AUTO = Contract.from_abi("AUTO", address="0xa184088a740c695E156F91f5cC086a06bb78b827", abi=TestToken.abi)

    BTC = Contract.from_abi("BTC",   address="0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c", abi=TestToken.abi)
    BUSD = Contract.from_abi("BUSD", address="0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56", abi=TestToken.abi)

    CAKE = Contract.from_abi("CAKE", address="0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82", abi=TestToken.abi)
    DOGE = Contract.from_abi("DOGE", address="0xbA2aE424d960c26247Dd6c32edC70B295c744C43", abi=TestToken.abi)
    ETH = Contract.from_abi("ETH",   address="0x250632378E573c6Be1AC2f97Fcdf00515d0Aa91B", abi=TestToken.abi)
    LINK = Contract.from_abi("LINK", address="0xF8A0BF9cF54Bb92F17374d9e9A321E6a111a51bD", abi=TestToken.abi)
    USDT = Contract.from_abi("USDT", address="0x55d398326f99059fF775485246999027B3197955", abi=TestToken.abi)
    
    assert AUTO.balanceOf(FEE_EXTRACTOR) == 0
    assert BTC.balanceOf(FEE_EXTRACTOR) == 0
    assert CAKE.balanceOf(FEE_EXTRACTOR) == 0
    assert DOGE.balanceOf(FEE_EXTRACTOR) == 0
    assert ETH.balanceOf(FEE_EXTRACTOR) == 0
    assert LINK.balanceOf(FEE_EXTRACTOR) == 0
    assert USDT.balanceOf(FEE_EXTRACTOR) == 0

    
    assert BGOV.balanceOf(FEE_EXTRACTOR) == 0
    assert BZRX.balanceOf(FEE_EXTRACTOR) > 0 # leftovers
    assert WBNB.balanceOf(FEE_EXTRACTOR) == 0
    
    assert True
