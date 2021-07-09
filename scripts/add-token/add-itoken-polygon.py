#!/usr/bin/python3

from brownie import *
from brownie import network, accounts
from brownie.network.contract import InterfaceContainer
from brownie.network.state import _add_contract, _remove_contract
from brownie.network.contract import Contract
import time
import pdb

acct = accounts.load("deployer1")

# TODO insert real price feed below (usdc now)
#chainlinkFeedAddress = "0xA9F9F897dD367C416e350c33a92fC12e53e1Cee5"
bzxAddress = "0xfe4F0eb0A1Ad109185c9AaDE64C48ff8e928e54B"

bzx = Contract.from_abi("bzx", address=bzxAddress,
    abi=interface.IBZx.abi, owner=acct)


def main():

    #deployment()
    #marginSettings()
    demandCurve()

def deployment():
    underlyingSymbol = "BZRX"
    iTokenSymbol = "i{}".format(underlyingSymbol)
    iTokenName = "Fulcrum {} iToken ({})".format(underlyingSymbol, iTokenSymbol)  

    loanTokenAddress = "0x54cFe73f2c7d0c4b62Ab869B473F5512Dc0944D2"

    #LoanTokenLogicStandard deployed at: 0xa9651b36101E00E43dA389A2b491E94Ca9F807b6
    loanTokenLogicStandard = Contract.from_abi(
        "LoanTokenLogicStandard", address="0xbd36f94b35dF4DD5135d3d16C449ba2655f12a8C", abi=LoanTokenLogicStandard.abi, owner=acct)
    #loanTokenLogicStandard = acct.deploy(LoanTokenLogicWeth, acct).address

    


    # Deployment

    iTokenProxy = LoanToken.deploy(acct, loanTokenLogicStandard, {"from": acct, "gas_price": 1e9})
    #iTokenProxy = Contract.from_abi("loanTokenProxy",
    #                        "0x97dfbEF4eD5a7f63781472Dbc69Ab8e5d7357cB9", LoanToken.abi, acct)

    #loanTokenSettings = acct.deploy(LoanTokenSettings)
    #LoanTokenSettingsLowerAdmin deployed at: 0xA1988005a5D6e68a3572F43a18460708CB29ABe0
    #LoanTokenSettings deployed at: 0xbB4e3A0A540819EfdF0A9C88dFcD9B1D628802dF

    loanTokenSettings = Contract.from_abi(
        "loanToken", address="0x49646513609085f39D9e44b413c74530Ba6E2c0F", abi=LoanTokenSettings.abi, owner=acct)


    calldata = loanTokenSettings.initialize.encode_input(
        loanTokenAddress, iTokenName, iTokenSymbol)

    iToken = Contract.from_abi("loanTokenLogicStandard",
                            iTokenProxy, LoanTokenLogicStandard.abi, acct)


    iToken.updateSettings(loanTokenSettings, calldata, {"from": acct, "gas_price": 1e9})



    # Setting price Feed
    #priceFeed = Contract.from_abi(
    #    "pricefeed", bzx.priceFeeds(), abi=PriceFeeds.abi, owner=acct)
    #priceFeed.setPriceFeed([loanTokenAddress], [chainlinkFeedAddress], {'from': acct})


    bzx.setLoanPool([iToken], [loanTokenAddress], {"from": acct, "gas_price": 1e9})
    #bzx.setSupportedTokens([loanTokenAddress], [True])


def marginSettings():

    # Setting margin settings

    loanTokenSettingsLowerAdmin = Contract.from_abi(
        "loanToken", address="0x23979985d63c6d14F59B348De11f7200b469e967", abi=LoanTokenSettingsLowerAdmin.abi, owner=acct)
    base_data = [
        b"0x0",  # id
        False,  # active
        str(acct),  # owner
        "0x0000000000000000000000000000000000000001",  # loanToken
        "0x0000000000000000000000000000000000000002",  # collateralToken
        Wei("20 ether"),  # minInitialMargin
        Wei("15 ether"),  # maintenanceMargin
        0  # fixedLoanTerm
    ]

    params = []
    
    bzxRegistry = Contract.from_abi("bzxRegistry", address="0x5a6f1e81334C63DE0183A4a3864bD5CeC4151c27", abi=TokenRegistry.abi)
    supportedTokenAssetsPairs = bzxRegistry.getTokens(0, 100) # TODO move this into a loop for permissionless to support more than 100
    loanTokensArr = []
    collateralTokensArr = []
    amountsArr = []

    for tokenAssetPairA in supportedTokenAssetsPairs:

        params.clear()
        loanTokensArr.clear()
        collateralTokensArr.clear()
        amountsArr.clear()

        # below is to allow new iToken.loanTokenAddress in other existing iTokens
        existingIToken = Contract.from_abi("existingIToken", address=tokenAssetPairA[0], abi=LoanTokenLogicStandard.abi, owner=acct)
        existingITokenLoanTokenAddress = existingIToken.loanTokenAddress()
        print("itoken", existingIToken.name(), tokenAssetPairA[0])

        ## only AUTO
        #if existingITokenLoanTokenAddress != "0xa184088a740c695E156F91f5cC086a06bb78b827":
        #    continue

        for tokenAssetPairB in supportedTokenAssetsPairs:

            collateralTokenAddress = tokenAssetPairB[1]

            if collateralTokenAddress == existingITokenLoanTokenAddress:
                continue

            ## skipping BZRX for now
            if existingITokenLoanTokenAddress == "0x54cFe73f2c7d0c4b62Ab869B473F5512Dc0944D2" or collateralTokenAddress == "0x54cFe73f2c7d0c4b62Ab869B473F5512Dc0944D2":
                continue

            ## only BZRX for now
            #if existingITokenLoanTokenAddress != "0x54cFe73f2c7d0c4b62Ab869B473F5512Dc0944D2" and collateralTokenAddress != "0x54cFe73f2c7d0c4b62Ab869B473F5512Dc0944D2":
            #    continue
            '''
                        "0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82", # CAKE
                        "0xa184088a740c695E156F91f5cC086a06bb78b827", # AUTO
                        "0xbA2aE424d960c26247Dd6c32edC70B295c744C43", # DOGE
            '''
            ## only CAKE, AUTO, or DOGE params
            '''if (
                (existingITokenLoanTokenAddress != "0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82" and collateralTokenAddress != "0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82") and
                (existingITokenLoanTokenAddress != "0xa184088a740c695E156F91f5cC086a06bb78b827" and collateralTokenAddress != "0xa184088a740c695E156F91f5cC086a06bb78b827")):
                #(existingITokenLoanTokenAddress != "0xbA2aE424d960c26247Dd6c32edC70B295c744C43" and collateralTokenAddress != "0xbA2aE424d960c26247Dd6c32edC70B295c744C43")):
                continue'''

            base_data_copy = base_data.copy()
            base_data_copy[3] = existingITokenLoanTokenAddress
            base_data_copy[4] = collateralTokenAddress # pair is iToken, Underlying


            if ((existingITokenLoanTokenAddress == "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174" and collateralTokenAddress == "0xc2132D05D31c914a87C6611C10748AEb04B58e8F")
                or (existingITokenLoanTokenAddress == "0xc2132D05D31c914a87C6611C10748AEb04B58e8F" and collateralTokenAddress == "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174")):
                base_data_copy[5] = "6666666666666666666"  # minInitialMargin
                base_data_copy[6] = Wei("5 ether")  # maintenanceMargin
            else:
                base_data_copy[5] = Wei("20 ether")  # minInitialMargin
                base_data_copy[6] = Wei("15 ether")  # maintenanceMargin
            
            #print(base_data_copy)
            params.append(base_data_copy)

            loanTokensArr.append(existingITokenLoanTokenAddress)
            collateralTokensArr.append(collateralTokenAddress)
            amountsArr.append(7*10**18)

        print(params)
        if (len(params) != 0):
            ## Torque loans
            calldata = loanTokenSettingsLowerAdmin.setupLoanParams.encode_input(params, True)
            existingIToken.updateSettings(loanTokenSettingsLowerAdmin.address, calldata, {"from": acct, "gas_price": 1e9})

            ## Margin trades
            calldata = loanTokenSettingsLowerAdmin.setupLoanParams.encode_input(params, False)
            existingIToken.updateSettings(loanTokenSettingsLowerAdmin.address, calldata, {"from": acct, "gas_price": 1e9})

        bzx.setLiquidationIncentivePercent(loanTokensArr, collateralTokensArr, amountsArr, {"from": acct, "gas_price": 1e9})


def demandCurve():

    bzxRegistry = Contract.from_abi("bzxRegistry", address="0x5a6f1e81334C63DE0183A4a3864bD5CeC4151c27", abi=TokenRegistry.abi)
    supportedTokenAssetsPairs = bzxRegistry.getTokens(0, 100) # TODO move this into a loop for permissionless to support more than 100

    loanTokenSettingsLowerAdmin = Contract.from_abi(
        "loanToken", address="0x23979985d63c6d14F59B348De11f7200b469e967", abi=LoanTokenSettingsLowerAdmin.abi, owner=acct)

    for tokenAssetPairA in supportedTokenAssetsPairs:
        
        ## no BZRX params
        if (tokenAssetPairA[0] == "0x97dfbEF4eD5a7f63781472Dbc69Ab8e5d7357cB9"):
            continue

        ## only BZRX params
        #if (tokenAssetPairA[0] != "0x97dfbEF4eD5a7f63781472Dbc69Ab8e5d7357cB9"):
        #    continue

        '''if (tokenAssetPairA[0] != "0xda4f261f26c82766408dcf6ba1b510fa8e64efe9" and tokenAssetPairA[0] != "0xC5b6cC0A9D61600BE42e83d8fA1331dB9E29e48C"):
            continue'''

        #existingITokenLoanTokenAddress = tokenAssetPairA[1]
        #collateralTokenAddress = tokenAssetPairA[1]

        ## only CAKE, AUTO, or DOGE params
        '''if (
            (existingITokenLoanTokenAddress != "0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82" and collateralTokenAddress != "0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82") and
            (existingITokenLoanTokenAddress != "0xa184088a740c695E156F91f5cC086a06bb78b827" and collateralTokenAddress != "0xa184088a740c695E156F91f5cC086a06bb78b827") and
            (existingITokenLoanTokenAddress != "0xbA2aE424d960c26247Dd6c32edC70B295c744C43" and collateralTokenAddress != "0xbA2aE424d960c26247Dd6c32edC70B295c744C43")):
            continue'''

        existingIToken = Contract.from_abi("existingIToken", address=tokenAssetPairA[0], abi=LoanTokenLogicStandard.abi, owner=acct)
        print("itoken", existingIToken.name(), tokenAssetPairA[0])
        
        calldata = loanTokenSettingsLowerAdmin.setDemandCurve.encode_input(0, 20*10**18, 0, 0, 60*10**18, 80*10**18, 120*10**18)
        existingIToken.updateSettings(loanTokenSettingsLowerAdmin.address, calldata, {"from": acct, "gas_price": 1e9})
