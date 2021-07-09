acct = accounts[0]
BZX = Contract.from_abi("bzx", address="0xfe4F0eb0A1Ad109185c9AaDE64C48ff8e928e54B", abi=interface.IBZx.abi, owner=acct)
MATIC = Contract.from_abi("MATIC", address="0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270", abi=TestToken.abi, owner=acct)
ETH = Contract.from_abi("ETH", address="0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619", abi=TestToken.abi, owner=acct)
WBTC = Contract.from_abi("WBTC", address="0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6", abi=TestToken.abi, owner=acct)
LINK = Contract.from_abi("LINK", address="0x53e0bca35ec356bd5dddfebbd1fc0fd03fabad39", abi=TestToken.abi, owner=acct)
USDC = Contract.from_abi("USDC", address="0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174", abi=TestToken.abi, owner=acct)
USDT = Contract.from_abi("USDT", address="0xc2132D05D31c914a87C6611C10748AEb04B58e8F", abi=TestToken.abi, owner=acct)
AAVE = Contract.from_abi("AAVE", address="0xD6DF932A45C0f255f85145f286eA0b292B21C90B", abi=TestToken.abi, owner=acct)
BZRX = Contract.from_abi("BZRX", address="0x54cFe73f2c7d0c4b62Ab869B473F5512Dc0944D2", abi=TestToken.abi, owner=acct)


iMATIC = Contract.from_abi("iMATIC", address=BZX.underlyingToLoanPool(MATIC.address), abi=LoanTokenLogicWeth.abi, owner=acct)
iETH = Contract.from_abi("iETH", address=BZX.underlyingToLoanPool(ETH.address), abi=LoanTokenLogicStandard.abi, owner=acct)
iWBTC = Contract.from_abi("iWBTC", address=BZX.underlyingToLoanPool(WBTC.address), abi=LoanTokenLogicStandard.abi, owner=acct)
iLINK = Contract.from_abi("iLINK", address=BZX.underlyingToLoanPool(LINK.address), abi=LoanTokenLogicStandard.abi, owner=acct)
iUSDC = Contract.from_abi("iUSDC", address=BZX.underlyingToLoanPool(USDC.address), abi=LoanTokenLogicStandard.abi, owner=acct)
iUSDT = Contract.from_abi("iUSDT", address=BZX.underlyingToLoanPool(USDT.address), abi=LoanTokenLogicStandard.abi, owner=acct)
iAAVE = Contract.from_abi("iAAVE", address=BZX.underlyingToLoanPool(AAVE.address), abi=LoanTokenLogicStandard.abi, owner=acct)
iBZRX = Contract.from_abi("iBZRX", address=BZX.underlyingToLoanPool(BZRX.address), abi=LoanTokenLogicStandard.abi, owner=acct)

usdcacc = "0x1a13F4Ca1d028320A707D99520AbFefca3998b7F"
USDC.transfer(acct, USDC.balanceOf(usdcacc), {'from': usdcacc})

wmaticacc = "0x8dF3aad3a84da6b69A4DA8aeC3eA40d9091B2Ac4"
MATIC.transfer(acct, MATIC.balanceOf(wmaticacc), {'from': wmaticacc})


linkacc = "0x74D23F21F780CA26B47Db16B0504F2e3832b9321"
LINK.transfer(acct, LINK.balanceOf(linkacc), {'from': linkacc})

ethacc = "0x28424507fefb6f7f8E9D3860F56504E4e5f5f390"
ETH.transfer(acct, ETH.balanceOf(ethacc), {'from': ethacc})


print ("Mint iusdt")
amount = USDC.balanceOf(acct)/2
USDC.approve(iUSDC, 2**256-1, {'from': acct})
iUSDC.mint(acct, amount, {'from': acct})
iUSDC.approve(acct, 2**256-1, {'from': acct})

print ("Mint imatic")
amount = MATIC.balanceOf(acct)/2
MATIC.approve(iMATIC, 2**256-1, {'from': acct})
iMATIC.mint(acct, amount, {'from': acct})
iMATIC.approve(acct, 2**256-1, {'from': acct})

print ("Mint ieth")
amount = ETH.balanceOf(acct)/2
ETH.approve(iETH, 2**256-1, {'from': acct})
iETH.mint(acct, amount, {'from': acct})
iETH.approve(acct, 2**256-1, {'from': acct})


print("Deposit iMatic to get some pgovs")

SUSHI_PGOV_wMATIC = Contract.from_abi("SUSHI_PGOV_wMATIC", "0xC698b8a1391F88F497A4EF169cA85b492860b502", interface.IPancakePair.abi)
SUSHI_PGOV_wMATIC_PID = 1
pgovToken = Contract.from_abi("GovToken", address="0xd5d84e75f48E75f01fb2EB6dFD8eA148eE3d0FEb", abi=GovToken.abi, owner=accounts[0]);

#masterChef = Contract.from_abi("masterChef", address="0xd39Ff512C3e55373a30E94BB1398651420Ae1D43", abi=MasterChef_Polygon.abi, owner=accounts[0])


devAccount = accounts[9]
bgovPerBlock = 100*10**18
bonusEndBlock = chain.height + 1*10**6
startBlock = chain.height

masterChefProxy = Contract.from_abi("masterChefProxy", address="0xd39Ff512C3e55373a30E94BB1398651420Ae1D43", abi=Proxy.abi, owner=acct)
# masterChefImpl = MasterChef_Polygon.deploy({'from': masterChefProxy.owner()})
# masterChefProxy.replaceImplementation(masterChefImpl, {'from': masterChefProxy.owner()})
masterChef = Contract.from_abi("masterChef", address=masterChefProxy, abi=MasterChef_Polygon.abi, owner=acct)

# mintCoordinator = Contract.from_abi("mintCoordinator", address="0x21baFa16512D6B318Cca8Ad579bfF04f7b7D3440", abi=MintCoordinator_Polygon.abi, owner=accounts[0]);
# mintCoordinator.addMinter(masterChef, {"from": mintCoordinator.owner()})
# pgovToken.transferOwnership(mintCoordinator, {"from": pgovToken.owner()})


masterChef.setStartBlock(chain.height-100, {'from': masterChef.owner()})

#masterChef.add(12500, pgovToken, True, {'from': masterChef.owner()})
#masterChef.add(12500, SUSHI_PGOV_wMATIC, True, {'from': masterChef.owner()})
# masterChef.add(12500, iMATIC, True, {'from': masterChef.owner()})
# masterChef.add(12500, iWBTC, True, {'from': masterChef.owner()})
# masterChef.add(12500, iETH, True, {'from': masterChef.owner()})
# masterChef.add(12500, iLINK, True, {'from': masterChef.owner()})
# masterChef.add(12500, iUSDC, True, {'from': masterChef.owner()})
# masterChef.add(12500, iUSDT, True, {'from': masterChef.owner()})
# masterChef.add(12500, iAAVE, True, {'from': masterChef.owner()})
# masterChef.add(12500, iBZRX, True, {'from': masterChef.owner()})


#masterChef.massUpdatePools({'from': masterChef.owner()})

MATIC_PID = 8
print("masterChef.set")
for i in range(0,len(masterChef.getPoolInfos())):
    masterChef.set(i, 12500, True, {'from': masterChef.owner()})

masterChef.massUpdatePools({'from': masterChef.owner()})

iMATIC.approve(masterChef, 2**256-1, {'from': acct})
masterChef.deposit(MATIC_PID, iMATIC.balanceOf(acct), {'from': acct})

chain.sleep(60 * 60 * 24)
chain.mine()

print("Claim PGOVs")
masterChef.claimReward(8, {'from':acct})
masterChef.withdraw(MATIC_PID, masterChef.userInfo(MATIC_PID, acct)[0]-5000e18, {'from': acct})

print(f"PGOVs: {pgovToken.balanceOf(acct)}")

print("Adding liquidity to sushi")
SUSHI_ROUTER = Contract.from_abi("router", "0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506", interface.IPancakeRouter02.abi)

quote = SUSHI_ROUTER.quote(1000*10**18, pgovToken.address, MATIC.address)
quote1 = SUSHI_ROUTER.quote(10*10**18, MATIC.address, pgovToken.address)
MATIC.approve(SUSHI_ROUTER, 2**256-1, {'from': acct})
pgovToken.approve(SUSHI_ROUTER, 2**256-1, {'from': acct})

SUSHI_ROUTER.addLiquidity(pgovToken, MATIC, quote, pgovToken.balanceOf(acct), 0, 0,  acct, 10000000000000000000000000, {'from': acct})
SUSHI_PGOV_wMATIC.approve(masterChef, 2**256-1, {'from': acct})

masterChef.deposit(SUSHI_PGOV_wMATIC_PID, SUSHI_PGOV_wMATIC.balanceOf(acct), {'from': acct})

print("-----------------------------------")
print (f"MATIC: {MATIC.address}")
print (f"ETH: {ETH.address}")
print (f"WBTC: {WBTC.address}")
print (f"LINK: {LINK.address}")
print (f"USDC: {USDC.address}")
print (f"USDT: {USDT.address}")
print (f"AAVE: {AAVE.address}")
print (f"BZRX: {BZRX.address}")

print("-----------------------------------")
print (f"iMATIC: {BZX.underlyingToLoanPool(MATIC.address)}")
print (f"iETH: {BZX.underlyingToLoanPool(ETH.address)}")
print (f"iWBTC: {BZX.underlyingToLoanPool(WBTC.address)}")
print (f"iLINK: {BZX.underlyingToLoanPool(LINK.address)}")
print (f"iUSDC: {BZX.underlyingToLoanPool(USDC.address)}")
print (f"iUSDT: {BZX.underlyingToLoanPool(USDT.address)}")
print (f"iAAVE: {BZX.underlyingToLoanPool(AAVE.address)}")
print (f"iBZRX: {BZX.underlyingToLoanPool(BZRX.address)}")

print("-----------------------------------")
print (f"MasterChef: {masterChef.address}")


