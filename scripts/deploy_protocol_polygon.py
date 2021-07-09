#!/usr/bin/python3

from brownie import *
from brownie.network.contract import InterfaceContainer
from brownie.network.state import _add_contract, _remove_contract

import shared

def main():
    deployProtocol()

def deployProtocol():
    global deploys, bzx, tokens, constants, addresses, thisNetwork, acct

    acct = accounts.load('deployer1')
    print("Loaded account",acct)

    constants = shared.Constants()
    addresses = shared.Addresses()

    ### DEPLOYMENT START ###

    print("Deploying bZxProtocol.")
    #bzxproxy = acct.deploy(bZxProtocol)
    bzx = Contract.from_abi("bzx", address="0xfe4F0eb0A1Ad109185c9AaDE64C48ff8e928e54B", abi=interface.IBZx.abi, owner=acct)
    _add_contract(bzx)

    ## PriceFeeds
    print("Deploying PriceFeeds.")
    feeds = acct.deploy(PriceFeeds_POLYGON)
    #feeds = Contract.from_abi("feeds", address=bzx.priceFeeds(), abi=PriceFeeds.abi, owner=acct)
    '''
Tom Bean - bZx.network / fulcrum.trade, [21.05.21 11:09]
list: MATIC, BZRX, ETH, WBTC, QUICK, AAVE, LINK, USDC, USDT

Tom Bean - bZx.network / fulcrum.trade, [21.05.21 11:09]
and PGOV, PGOV/MATIC, and wvBZRX on the farming page
    '''

    print("Calling setDecimals.")
    feeds.setDecimals(
        [
            "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270", # MATIC
            "0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619", # ETH
            "0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6", # WBTC
            "0x53e0bca35ec356bd5dddfebbd1fc0fd03fabad39", # LINK
            "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174", # USDC
            "0xc2132D05D31c914a87C6611C10748AEb04B58e8F", # USDT
            "0xD6DF932A45C0f255f85145f286eA0b292B21C90B", # AAVE
            "0x54cFe73f2c7d0c4b62Ab869B473F5512Dc0944D2", # BZRX
            #"0x831753DD7087CaC61aB5644b308642cc1c33Dc13", # QUICK
        ]
    , {"from": acct})

    print("Calling setPriceFeed.")
    feeds.setPriceFeed(
        [
            "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270", # MATIC
            "0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619", # ETH
            "0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6", # WBTC
            "0x53e0bca35ec356bd5dddfebbd1fc0fd03fabad39", # LINK
            "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174", # USDC
            "0xc2132D05D31c914a87C6611C10748AEb04B58e8F", # USDT
            "0xD6DF932A45C0f255f85145f286eA0b292B21C90B", # AAVE
            "0x54cFe73f2c7d0c4b62Ab869B473F5512Dc0944D2", # BZRX
            #"0x831753DD7087CaC61aB5644b308642cc1c33Dc13", # QUICK
        ],
        [
            "0xAB594600376Ec9fD91F8e885dADF0CE036862dE0", # MATIC
            "0xF9680D99D6C9589e2a93a78A04A279e509205945", # ETH
            "0xDE31F8bFBD8c84b5360CFACCa3539B938dd78ae6", # WBTC
            "0xd9FFdb71EbE7496cC440152d43986Aae0AB76665", # LINK
            "0xfE4A8cc5b5B2366C1B58Bea3858e81843581b2F7", # USDC
            "0x0A6513e40db6EB1b165753AD52E80663aeA50545", # USDT
            "0xC47812857A74425e2039b57891a3DFcF51602d5d", # AAVE
            "0x6b7D436583e5fE0874B7310b74D29A13af816860", # BZRX
            #"", # QUICK
        ]
    , {"from": acct})


    ## SwapImpl
    print("Deploying Swaps.")
    swaps = acct.deploy(SwapsImplUniswapV2_POLYGON)

    ## ProtocolSettings
    print("Deploying ProtocolSettings.")
    settings = acct.deploy(ProtocolSettings)
    print("Calling replaceContract.")
    bzx.replaceContract(settings.address)

    print("Calling setPriceFeedContract.")
    bzx.setPriceFeedContract(
        feeds.address # priceFeeds
    )

    print("Calling setSwapsImplContract.")
    bzx.setSwapsImplContract(
        swaps.address  # swapsImpl
    )
    # old LINK: 0xb0897686c545045afc77cf20ec7a532e3120e0f1
    '''print("Calling setLoanPool.")
    bzx.setLoanPool(
        [
            "", # MATIC
            "", # ETH
            "", # WBTC
            "", # LINK
            "", # USDC
            "", # USDT
            "", # AAVE
            #"", # BZRX
            #"", # QUICK
        ],
        [
            "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270", # MATIC
            "0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619", # ETH
            "0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6", # WBTC
            "0x53e0bca35ec356bd5dddfebbd1fc0fd03fabad39", # LINK
            "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174", # USDC
            "0xc2132D05D31c914a87C6611C10748AEb04B58e8F", # USDT
            "0xD6DF932A45C0f255f85145f286eA0b292B21C90B", # AAVE
            "0x54cFe73f2c7d0c4b62Ab869B473F5512Dc0944D2", # BZRX
            #"0x831753DD7087CaC61aB5644b308642cc1c33Dc13", # QUICK
        ]
    , {"from": acct})'''

    print("Calling setSupportedTokens.")
    bzx.setSupportedTokens(
        [
            "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270", # MATIC
            "0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619", # ETH
            "0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6", # WBTC
            "0x53e0bca35ec356bd5dddfebbd1fc0fd03fabad39", # LINK
            "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174", # USDC
            "0xc2132D05D31c914a87C6611C10748AEb04B58e8F", # USDT
            "0xD6DF932A45C0f255f85145f286eA0b292B21C90B", # AAVE
            "0x54cFe73f2c7d0c4b62Ab869B473F5512Dc0944D2", # BZRX
            #"0x831753DD7087CaC61aB5644b308642cc1c33Dc13", # QUICK
        ],
        [
            True, # MATIC
            True, # ETH
            True, # WBTC
            True, # LINK
            True, # USDC
            True, # USDT
            True, # AAVE
            True, # BZRX
            #True, # QUICK
        ],
        True
    , {"from": acct})

    ## 7e18 = 5% collateral discount
    # handled in setup_pool_params2
    '''function setLiquidationIncentivePercent(
        address[] calldata loanTokens,
        address[] calldata collateralTokens,
        uint256[] calldata amounts)
        external
        onlyOwner'''

    bzx.setFeesController(acct.address)

    ## LoanSettings
    print("Deploying LoanSettings.")
    loanSettings = acct.deploy(LoanSettings)
    print("Calling replaceContract.")
    bzx.replaceContract(loanSettings.address)

    ## LoanOpenings
    print("Deploying LoanOpenings.")
    loanOpenings = acct.deploy(LoanOpenings)
    print("Calling replaceContract.")
    bzx.replaceContract(loanOpenings.address)

    ## LoanMaintenance
    print("Deploying LoanMaintenance.")
    loanMaintenance = acct.deploy(LoanMaintenance)
    print("Calling replaceContract.")
    bzx.replaceContract(loanMaintenance.address)

    ## LoanClosings
    print("Deploying LoanClosings.")
    loanClosings = acct.deploy(LoanClosings)
    print("Calling replaceContract.")
    bzx.replaceContract(loanClosings.address)

    ## SwapsExternal
    print("Deploying SwapsExternal.")
    swapsExternal = acct.deploy(SwapsExternal)
    print("Calling replaceContract.")
    bzx.replaceContract(swapsExternal.address)
