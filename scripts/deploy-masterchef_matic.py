
from brownie.network import account
import pytest
import time
from brownie import *
from brownie import Contract, network
from brownie.network.contract import InterfaceContainer
from brownie.network.state import _add_contract, _remove_contract


acct = accounts[0] #accounts.load('deployer1')

bzxProtocol = '0xfe4F0eb0A1Ad109185c9AaDE64C48ff8e928e54B'

bzx = Contract.from_abi("bzx", address=bzxProtocol, abi=interface.IBZx.abi, owner=acct)

MATIC = Contract.from_abi("MATIC", address="0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270", abi=TestToken.abi, owner=acct)
ETH = Contract.from_abi("ETH", address="0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619", abi=TestToken.abi, owner=acct)
WBTC = Contract.from_abi("WBTC", address="0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6", abi=TestToken.abi, owner=acct)
LINK = Contract.from_abi("LINK", address="0xb0897686c545045afc77cf20ec7a532e3120e0f1", abi=TestToken.abi, owner=acct)
USDC = Contract.from_abi("USDC", address="0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174", abi=TestToken.abi, owner=acct)
USDT = Contract.from_abi("USDT", address="0xc2132D05D31c914a87C6611C10748AEb04B58e8F", abi=TestToken.abi, owner=acct)
AAVE = Contract.from_abi("AAVE", address="0xD6DF932A45C0f255f85145f286eA0b292B21C90B", abi=TestToken.abi, owner=acct)
BZRX = Contract.from_abi("BZRX", address="0x97dfbEF4eD5a7f63781472Dbc69Ab8e5d7357cB9", abi=TestToken.abi, owner=acct)


iMATIC = Contract.from_abi("iMATIC", address=bzx.underlyingToLoanPool(MATIC.address), abi=LoanTokenLogicWeth.abi, owner=acct)
iETH = Contract.from_abi("iETH", address=bzx.underlyingToLoanPool(ETH.address), abi=LoanTokenLogicStandard.abi, owner=acct)
iWBTC = Contract.from_abi("iWBTC", address=bzx.underlyingToLoanPool(WBTC.address), abi=LoanTokenLogicStandard.abi, owner=acct)
iLINK = Contract.from_abi("iLINK", address=bzx.underlyingToLoanPool(LINK.address), abi=LoanTokenLogicStandard.abi, owner=acct)
iUSDC = Contract.from_abi("iUSDC", address=bzx.underlyingToLoanPool(USDC.address), abi=LoanTokenLogicStandard.abi, owner=acct)
iUSDT = Contract.from_abi("iUSDT", address=bzx.underlyingToLoanPool(USDT.address), abi=LoanTokenLogicStandard.abi, owner=acct)
iAAVE = Contract.from_abi("iAAVE", address=bzx.underlyingToLoanPool(AAVE.address), abi=LoanTokenLogicStandard.abi, owner=acct)
iBZRX = Contract.from_abi("iBZRX", address=bzx.underlyingToLoanPool(AAVE.address), abi=LoanTokenLogicStandard.abi, owner=acct)

QUICKROUTER = Contract.from_abi("router", "0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff", interface.IPancakeRouter02.abi)


# two sided
USDT_WMATIC = Contract.from_abi("USDT_WMATIC", "0x604229c960e5cacf2aaeac8be68ac07ba9df81c3", interface.IPancakePair.abi)

pgovToken = Contract.from_abi("PGOV", "0xd5d84e75f48E75f01fb2EB6dFD8eA148eE3d0FEb", GovToken.abi)


devAccount = accounts[9]
pgovPerBlock = 25*10**18
startBlock = chain.height
masterChefImpl = accounts[0].deploy(MasterChef_Polygon)
masterChefProxy = accounts[0].deploy(Proxy, masterChefImpl)
masterChef = Contract.from_abi("masterChef", address=masterChefProxy, abi=MasterChef_Polygon.abi, owner=accounts[0])
masterChef.initialize(pgovToken, devAccount, pgovPerBlock, startBlock)
masterChef.add(87500, iUSDT, 1)
masterChef.add(87500, iETH, 1)
masterChef.add(87500, iMATIC, 1)
masterChef.add(12500, iUSDC, 1)

SUSHI_PGOV_wMATIC = Contract.from_abi("SUSHI_PGOV_wMATIC", "0xC698b8a1391F88F497A4EF169cA85b492860b502", interface.IPancakePair.abi)
masterChef.add(12500, SUSHI_PGOV_wMATIC, 1)


mintCoordinator = Contract.from_abi("mintCoordinator", address="0x21baFa16512D6B318Cca8Ad579bfF04f7b7D3440", abi=MintCoordinator_Polygon.abi, owner=accounts[0]);
mintCoordinator.addMinter(masterChef, {"from": mintCoordinator.owner()})
pgovToken.transferOwnership(mintCoordinator, {"from": pgovToken.owner()})
masterChef.massUpdatePools({'from': masterChef.owner()})

exec(open("./scripts/set-env-polygon.py").read())