#!/usr/bin/python3

import pytest

from testspolygon.conftest import initBalance, requireMaticFork
from brownie import chain
testdata = [
    ('MATIC', 'iMATIC', 8)
]

INITIAL_LP_TOKEN_ACCOUNT_AMOUNT = 100 * 10 ** 18;

## GovPool locked
## LPPool locked
@pytest.mark.parametrize("tokenName, lpTokenName, pid", testdata)
def testFarming_Vesting1(requireMaticFork, bzxOwner, tokens, tokenName, lpTokenName, pid, accounts, masterChef, pgovToken):
    # Precondition
    lpToken = tokens[lpTokenName]
    token = tokens[tokenName]
    account1 = accounts[7]
    initBalance(account1, token, lpToken, INITIAL_LP_TOKEN_ACCOUNT_AMOUNT)
    lpBalance1 = lpToken.balanceOf(account1)

    lpToken.approve(masterChef, 2**256-1, {'from': account1})
    depositAmount = lpBalance1
    masterChef.set(0, 10000000000, True, {'from': masterChef.owner()})
    masterChef.set(pid, 10000000000, True, {'from': masterChef.owner()})
    pgovToken.approve(masterChef, 2**256-1, {'from': account1})
    masterChef.setLocked(pid, True, {'from': masterChef.owner()})
    masterChef.setLocked(0, True, {'from': masterChef.owner()})

    tx1 = masterChef.deposit(pid, depositAmount, {'from': account1})
    chain.mine(blocks=100)

    masterChef.compoundReward(pid,  {'from': account1})
    chain.mine()
    masterChef.compoundReward(0,  {'from': account1})
    chain.mine()
    lockedRewards1 = masterChef.lockedRewards(account1);
    assert lockedRewards1 > 0
    chain.mine(blocks=100)

    assert masterChef.unlockedRewards(account1) > 0
    assert masterChef.lockedRewards(account1) < lockedRewards1


def testFarming_Vesting2(requireMaticFork, masterChef):
    lockedAmount = 1000e18
    startVestinStamp = 1625993882
    userStartVestinStamp = 1626013882
    now = chain.time()
    assert masterChef.calculateUnlockedRewards(lockedAmount, now, startVestinStamp) == masterChef.calculateUnlockedRewards(lockedAmount, now, 0)
    assert masterChef.calculateUnlockedRewards(lockedAmount, now, userStartVestinStamp) < masterChef.calculateUnlockedRewards(lockedAmount, now, startVestinStamp)
    assert masterChef.calculateUnlockedRewards(lockedAmount, now + 15768000, 0) == lockedAmount
    masterChef.calculateUnlockedRewards(lockedAmount, now + 15768000-1, now) < lockedAmount
    masterChef.calculateUnlockedRewards(lockedAmount, now + 15768000, now) == lockedAmount

    cliffDuration = now - userStartVestinStamp
    assert masterChef.calculateVestingStartStamp(now, userStartVestinStamp, lockedAmount, lockedAmount/2) == (cliffDuration/2) + userStartVestinStamp
    assert masterChef.calculateVestingStartStamp(now, userStartVestinStamp, lockedAmount, lockedAmount) == (cliffDuration) + userStartVestinStamp
    assert masterChef.calculateVestingStartStamp(now, userStartVestinStamp, lockedAmount, 0) == userStartVestinStamp