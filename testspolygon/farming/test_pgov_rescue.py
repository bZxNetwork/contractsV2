#!/usr/bin/python3

import pytest

from testspolygon.conftest import initBalance, requireFork
from brownie import reverts

def testPgovRescue(requireFork, accounts, pgovToken, ETH, iETH):
    # Precondition

    account1 = accounts[2]
    initBalance(account1, ETH, iETH, 2e18)
    amount = 1e18
    ethacc = "0x28424507fefb6f7f8E9D3860F56504E4e5f5f390"
    ETH.transfer(account1, amount, {'from': ethacc})

    owner = pgovToken.owner()
    balanceBefore = ETH.balanceOf(owner);
    ETH.transfer(pgovToken, 1e18, {'from':account1})
    pgovToken.rescue(ETH, {'from':owner})
    assert ETH.balanceOf(owner) == balanceBefore + amount

    with reverts("Ownable: caller is not the owner"):
        pgovToken.rescue(ETH, {'from':account1})



def testMintCoordinatorRescue(requireFork, accounts, mintCoordinator, ETH, iETH):

    account1 = accounts[3]
    initBalance(account1, ETH, iETH, 2e18)
    amount = 1e18
    ethacc = "0x28424507fefb6f7f8E9D3860F56504E4e5f5f390"
    ETH.transfer(account1, amount, {'from': ethacc})
    owner = mintCoordinator.owner()
    ownerBalanceBefore = ETH.balanceOf(owner);
    coordinatorBalanceBefore = ETH.balanceOf(mintCoordinator)
    ETH.transfer(mintCoordinator, 1e18, {'from':account1})
    mintCoordinator.rescue(ETH, {'from':owner})
    assert ETH.balanceOf(owner) == ownerBalanceBefore + amount + coordinatorBalanceBefore

    with reverts("Ownable: caller is not the owner"):
        mintCoordinator.rescue(ETH, {'from':account1})


