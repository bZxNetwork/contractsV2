
from brownie.network import account
import pytest
import time
from brownie import *
from brownie import Contract, network
from brownie.network.contract import InterfaceContainer
from brownie.network.state import _add_contract, _remove_contract


WBNB = Contract.from_abi("USDT", "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c", interface.IWBNB.abi)
ETH = Contract.from_abi("USDT", "0x2170ed0880ac9a755fd29b2688956bd959f933f8", TestToken.abi)
BUSD = Contract.from_abi("BUSD", "0xe9e7cea3dedca5984780bafc599bd69add087d56", TestToken.abi)
WBTC = Contract.from_abi("USDT", "0x7130d2a12b9bcbfae4f2634d864a1ee1ce3ead9c", TestToken.abi)
USDT = Contract.from_abi("USDT", "0x55d398326f99059ff775485246999027b3197955", TestToken.abi)
BZRX = Contract.from_abi("BZRX", "0x4b87642AEDF10b642BE4663Db842Ecc5A88bf5ba", TestToken.abi)
# two sided
BZRX_wBNB = Contract.from_abi("BZRX", "0x091A7065306fa5F91a378e8D6858996C20868611", interface.IPancakePair.abi)


bzx = Contract.from_abi("bzx", address="0xc47812857a74425e2039b57891a3dfcf51602d5d", abi=interface.IBZx.abi, owner=accounts[0])

iWBNBAddress = bzx.underlyingToLoanPool(WBNB)
iETHAddress = bzx.underlyingToLoanPool(ETH)
iBUSDAddress = bzx.underlyingToLoanPool(BUSD)
iWBTCAddress = bzx.underlyingToLoanPool(WBTC)
iUSDTAddress = bzx.underlyingToLoanPool(USDT)
iBZRXAddress = bzx.underlyingToLoanPool(BZRX)

iWBNB = Contract.from_abi("iWBNB", address=iWBNBAddress, abi=LoanTokenLogicWeth.abi, owner=accounts[0])
iETH = Contract.from_abi("iETH", address=iETHAddress, abi=LoanTokenLogicStandard.abi, owner=accounts[0])
iBUSD = Contract.from_abi("iBUSD", address=iBUSDAddress, abi=LoanTokenLogicStandard.abi, owner=accounts[0])
iWBTC = Contract.from_abi("iWBTC", address=iWBTCAddress, abi=LoanTokenLogicStandard.abi, owner=accounts[0])
iUSDT = Contract.from_abi("iUSDT", address=iUSDTAddress, abi=LoanTokenLogicStandard.abi, owner=accounts[0])
iBZRX = Contract.from_abi("iBZRX", address=iBZRXAddress, abi=LoanTokenLogicStandard.abi, owner=accounts[0])

bgovToken = Contract.from_abi("BGOV", address="0xf8E026dC4C0860771f691EcFFBbdfe2fa51c77CF",
                                     abi=BGovToken.abi, owner=accounts[0]);

# TODO @Tom farm configuration
devAccount = accounts[0]  # @Tom this account will receive small fees check updatePool() func
bgovPerBlock = 25*10**18
bonusEndBlock = chain.height + 400000
startBlock = chain.height

masterChefImpl = accounts[0].deploy(MasterChef)
masterChefProxy = accounts[0].deploy(Proxy, masterChefImpl)
masterChef = Contract.from_abi("masterChef", address=masterChefProxy, abi=MasterChef.abi, owner=accounts[0])

masterChef.initialize(bgovToken, devAccount, bgovPerBlock, startBlock, bonusEndBlock)

BGOV_wBNB = Contract.from_abi("BGOV_wBNB", "0xEcd0aa12A453AE356Aba41f62483EDc35f2290ed", interface.IPancakePair.abi)

# from chef: // Total allocation poitns. Must be the sum of all allocation points in all pools.
# aloso allocation points should consider price difference. depositing 1 iWBTC should be approximately equal to depositing 55k iBUSD

# adding allocation points according to what was disscussed

# Here are the params and initial pool weights for our starting farms:
# _BGOVPerBlock: 25000000000000000000
# _startBlock: TBD (early next week)
# _bonusEndBlock: _startBlock + 400000

# allocPoints per pool:
# 12500 - iBNB, iBUSD, iBTC, iUSDT, iETH  
# 87500 - iBZRX
# 100000 - BGOV/BNB

masterChef.add(12500, iWBNB, 1)
masterChef.add(12500, iETH, 1)
masterChef.add(12500, iBUSD, 1)
masterChef.add(12500, iWBTC, 1)
masterChef.add(12500, iUSDT, 1)
masterChef.add(87500, iBZRX, 1)

# two sided
#masterChef.add(100000, BZRX_wBNB, 1)
masterChef.add(100000, BGOV_wBNB, 1)