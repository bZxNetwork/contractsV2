#!/usr/bin/python3

import pytest
from brownie import reverts

usdcMajorAccount = '0x0a59649758aa4d66e25f08dd01271e891fe52199'
def test_swap_mainflow(requireMainnetFork, bzx, accounts, ETH, WBTC, USDC, DAI, USDT, LINK, swaps):

    USDC.transfer(accounts[1], 1000e6, {'from': usdcMajorAccount})
    USDC.approve(bzx,2**256-1, {'from':accounts[1]})
    ETH.approve(bzx,2**256-1, {'from':accounts[1]})
    WBTC.approve(bzx,2**256-1, {'from':accounts[1]})
    DAI.approve(bzx,2**256-1, {'from':accounts[1]})
    LINK.approve(bzx,2**256-1, {'from':accounts[1]})
    usdcBalance1 = USDC.balanceOf(accounts[1])

    bzx.swapExternal(USDC, ETH, accounts[1], accounts[1], USDC.balanceOf(accounts[1]), 0, bytes(0), {'from':accounts[1]})
    bzx.swapExternal(ETH, LINK, accounts[1], accounts[1], ETH.balanceOf(accounts[1]), 0, bytes(0), {'from':accounts[1]})
    bzx.swapExternal(LINK, DAI, accounts[1], accounts[1], LINK.balanceOf(accounts[1]), 0, bytes(0), {'from':accounts[1]})
    bzx.swapExternal(DAI, USDC, accounts[1], accounts[1], DAI.balanceOf(accounts[1]), 0, bytes(0), {'from':accounts[1]})
    diff = (1-(USDC.balanceOf(accounts[1])/usdcBalance1))*100
    assert diff <= 5

def test_swap_negative(requireMainnetFork, bzx, accounts, ETH, USDC):

    USDC.transfer(accounts[1], 1000e6, {'from': usdcMajorAccount})

    USDC.approve(bzx,0, {'from':accounts[1]})
    with reverts("SafeERC20: low-level call failed"):
        bzx.swapExternal(USDC, ETH, accounts[1], accounts[1], USDC.balanceOf(accounts[1])+1, 0, bytes(0), {'from':accounts[1]})

    USDC.approve(bzx,2**256-1, {'from':accounts[1]})
    with reverts("SafeERC20: low-level call failed"):
        bzx.swapExternal(USDC, ETH, accounts[1], accounts[1], USDC.balanceOf(accounts[1])+1, 0, bytes(0), {'from':accounts[1]})
    with reverts("sourceTokenAmount == 0"):
        bzx.swapExternal(USDC, ETH, accounts[1], accounts[1], 0, 0, bytes(0), {'from':accounts[1]})

    with reverts("source amount too high"):
        bzx.swapExternal(USDC, ETH, accounts[1], accounts[1], 100e6, 100e18, bytes(0), {'from':accounts[1]})

    with reverts("SafeERC20: low-level call failed"):
        bzx.swapExternal(USDC, ETH, accounts[1], accounts[1], 100e6, 0, bytes(0), {'from':accounts[3]})

