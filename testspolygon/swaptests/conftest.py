#!/usr/bin/python3

import pytest
from brownie import Contract, network, Wei
from brownie.network.state import _add_contract, _remove_contract

@pytest.fixture(scope="class")
def requireMainnetFork():
    assert (network.show_active().find("mainnet-fork")>=0)


@pytest.fixture(scope="class", autouse=True)
def ETH(accounts, TestToken):
    return Contract.from_abi("ETH", "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2", TestToken.abi)

@pytest.fixture(scope="class", autouse=True)
def USDC(accounts, TestToken):
    return Contract.from_abi("USDC", "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48", TestToken.abi)

@pytest.fixture(scope="class", autouse=True)
def WBTC(accounts, TestToken):
    return Contract.from_abi("WBTC", "0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599", TestToken.abi)


@pytest.fixture(scope="class", autouse=True)
def USDT(accounts, TestToken):
    return Contract.from_abi("USDT", "0xdAC17F958D2ee523a2206206994597C13D831ec7", TestToken.abi)

@pytest.fixture(scope="class", autouse=True)
def DAI(accounts, TestToken):
    return Contract.from_abi("DAI", "0x6B175474E89094C44Da98b954EedeAC495271d0F", TestToken.abi)

@pytest.fixture(scope="class", autouse=True)
def LINK(accounts, TestToken):
    return Contract.from_abi("LINK", "0x514910771AF9Ca656af840dff83E8264EcF986CA", TestToken.abi)

@pytest.fixture(scope="class", autouse=True)
def swaps(accounts, SwapsImplUniswapV2_ETH):
    swaps = accounts[0].deploy(SwapsImplUniswapV2_ETH)
    return swaps


@pytest.fixture(scope="class", autouse=True)
def bzx(accounts, interface, bZxProtocol, swaps, ProtocolSettings, SwapsExternal,
        USDC, DAI, WBTC, ETH, USDT, LINK):

    bzx = Contract.from_abi("bzx", address="0xD8Ee69652E4e4838f2531732a46d1f7F584F0b7f", abi=bZxProtocol.abi, owner=accounts[0])
    _add_contract(bzx)
    owner = bzx.owner();
    bzx = Contract.from_abi("bzx", address=bzx.address, abi=interface.IBZx.abi, owner=accounts[0])
    settings = ProtocolSettings.deploy({'from':owner})
    bzx.replaceContract(settings.address, {'from':owner})
    bzx.setSwapsImplContract(swaps, {'from':owner})
    bzx.setSupportedTokens([
        USDC.address, DAI.address, WBTC.address, ETH.address, USDT.address, LINK.address
    ], [
        True, True, True, True, True, True
    ], True, {'from':owner})
    swapsExternal = SwapsExternal.deploy({'from':owner})
    bzx.replaceContract(swapsExternal.address, {'from':owner})

    return bzx