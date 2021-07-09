#!/usr/bin/python3

import pytest
from brownie import reverts

def test_swap_mainflow(requireMaticFork, bzx, accounts, ETH, WBTC, USDC, WMATIC):

    USDC.transfer(accounts[1], 1000e6, {'from': '0x986a2fCa9eDa0e06fBf7839B89BfC006eE2a23Dd'})
    USDC.approve(bzx,2**256-1, {'from':accounts[1]})
    ETH.approve(bzx,2**256-1, {'from':accounts[1]})
    WBTC.approve(bzx,2**256-1, {'from':accounts[1]})
    WMATIC.approve(bzx,2**256-1, {'from':accounts[1]})
    usdcBalance1 = USDC.balanceOf(accounts[1])

    bzx.swapExternal(USDC, ETH, accounts[1], accounts[1], USDC.balanceOf(accounts[1]), 0, bytes(0), {'from':accounts[1]})
    bzx.swapExternal(ETH, WBTC, accounts[1], accounts[1], ETH.balanceOf(accounts[1]), 0, bytes(0), {'from':accounts[1]})
    bzx.swapExternal(WBTC, WMATIC, accounts[1], accounts[1], WBTC.balanceOf(accounts[1]), 0, bytes(0), {'from':accounts[1]})
    bzx.swapExternal(WMATIC, USDC, accounts[1], accounts[1], WMATIC.balanceOf(accounts[1]), 0, bytes(0), {'from':accounts[1]})
    diff = (1-(USDC.balanceOf(accounts[1])/usdcBalance1))*100
    assert diff <= 5

def test_swap_negative(requireMaticFork, bzx, accounts, ETH, USDC):

    USDC.transfer(accounts[1], 1000e6, {'from': '0x986a2fCa9eDa0e06fBf7839B89BfC006eE2a23Dd'})

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

