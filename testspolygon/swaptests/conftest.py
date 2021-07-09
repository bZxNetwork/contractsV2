#!/usr/bin/python3

import pytest
from brownie import Contract, network, Wei
from brownie.network.state import _add_contract, _remove_contract

@pytest.fixture(scope="class")
def requireMaticFork():
    assert (network.show_active().find("matic-fork")>=0)


@pytest.fixture(scope="class", autouse=True)
def ETH(accounts, TestToken):
    return Contract.from_abi("ETH", "0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619", TestToken.abi)

@pytest.fixture(scope="class", autouse=True)
def USDC(accounts, TestToken):
    return Contract.from_abi("USDC", "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174", TestToken.abi)

@pytest.fixture(scope="class", autouse=True)
def WBTC(accounts, TestToken):
    return Contract.from_abi("WBTC", "0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6", TestToken.abi)


@pytest.fixture(scope="class", autouse=True)
def USDT(accounts, TestToken):
    return Contract.from_abi("USDT", "0xc2132D05D31c914a87C6611C10748AEb04B58e8F", TestToken.abi)

@pytest.fixture(scope="class", autouse=True)
def DAI(accounts, TestToken):
    return Contract.from_abi("DAI", "0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063", TestToken.abi)

@pytest.fixture(scope="class", autouse=True)
def WMATIC(accounts, TestToken):
    return Contract.from_abi("WMATIC", "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270", TestToken.abi)


@pytest.fixture(scope="class", autouse=True)
def swaps(accounts, SwapsImplUniswapV2_POLYGON):
    swaps = accounts[0].deploy(SwapsImplUniswapV2_POLYGON)
    return swaps


@pytest.fixture(scope="class", autouse=True)
def bzx(accounts, bZxProtocol, interface, swaps, ProtocolSettings, SwapsExternal,
        WMATIC,USDC, DAI, WBTC, ETH):
    bzxproxy = accounts[0].deploy(bZxProtocol)
    bzx = Contract.from_abi("bzx", address=bzxproxy.address, abi=interface.IBZx.abi, owner=accounts[0])
    _add_contract(bzx)
    settings = accounts[0].deploy(ProtocolSettings)
    bzx.replaceContract(settings.address)
    bzx.setSwapsImplContract(swaps)
    bzx.setSupportedTokens([
        WMATIC.address, USDC.address, DAI.address, WBTC.address, ETH.address
    ], [
        True, True, True, True, True
    ], True, {'from':accounts[0]})
    bzx.replaceContract(accounts[0].deploy(SwapsExternal).address, {'from': accounts[0]})

    return bzx


