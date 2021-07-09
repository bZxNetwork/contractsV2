import pytest
from brownie import Contract, network, reverts

INITIAL_ACCOUNT_AMOUNT = 200 * 10 ** 18;


@pytest.fixture(scope="module")
def requireMainnetFork():
    assert (network.show_active() == "mainnet-fork" or network.show_active() == "mainnet-fork-alchemy")


@pytest.fixture(scope="module")
def bzrx(accounts, interface):
    return Contract.from_abi("bzrx", address="0x56d811088235F11C8920698a204A5010a788f4b3", abi=interface.ERC20.abi,
                             owner=accounts[0])


@pytest.fixture(scope="module")
def vbzrx(accounts, BZRXVestingToken):
    return Contract.from_abi("bzrx", address="0xb72b31907c1c95f3650b64b2469e08edacee5e8f", abi=BZRXVestingToken.abi,
                             owner=accounts[0])

@pytest.fixture(scope="module")
def wvbzrxProxy(accounts, VBZRXWrapper, Proxy_0_5):
    impl = VBZRXWrapper.deploy({"from": accounts[0]})
    return Proxy_0_5.deploy(impl, {'from': accounts[0]})


@pytest.fixture(scope="module")
def wrapper(accounts, VBZRXWrapper, wvbzrxProxy):
    return Contract.from_abi("wrapper", address=wvbzrxProxy, abi=VBZRXWrapper.abi, owner=accounts[0])



vbzrxMajorAddress = "0x29dce6d3039644c66c456998de3bd723b141ff16";

def test_mainflow(requireMainnetFork, bzrx, vbzrx, chain, accounts, wrapper):
    account1 = accounts[1]
    account2 = accounts[2]
    vbzrxBalanceBefore = vbzrx.balanceOf(account1)
    bzrxBalanceBefore1 = bzrx.balanceOf(account1)
    bzrxBalanceBefore2 = bzrx.balanceOf(account2)
    tx1 = vbzrx.transfer(account1, INITIAL_ACCOUNT_AMOUNT, {"from": vbzrxMajorAddress})
    vbzrxBalanceAfter = vbzrxBalanceBefore + INITIAL_ACCOUNT_AMOUNT
    assert vbzrx.balanceOf(account1) == vbzrxBalanceAfter
    assert vbzrx.vestedBalanceOf(account1) == 0
    chain.mine()

    vbzrx.approve(wrapper, vbzrx.balanceOf(account1), {"from": account1})
    depositAmount = vbzrx.balanceOf(account1);
    vestedBalance = vbzrx.vestedBalanceOf(account1);
    assert vestedBalance > 0
    tx2 = wrapper.deposit(depositAmount, {"from": account1})
    assert vbzrx.vestedBalanceOf(account1) == 0
    assert bzrx.balanceOf(account1) >= vestedBalance + bzrxBalanceBefore1
    assert bzrx.balanceOf(account1) > bzrxBalanceBefore1
    assert wrapper.claimable(account1) == 0

    chain.mine()
    assert wrapper.claimable(account1) > 0

    tx3 = wrapper.transfer(account2, depositAmount, {"from": account1})
    assert wrapper.balanceOf(account1) == 0
    assert wrapper.balanceOf(account2) == INITIAL_ACCOUNT_AMOUNT
    assert wrapper.claimable(account1) == 0
    assert wrapper.claimable(account2) > 0
    assert vbzrx.vestedBalanceOf(account2) == 0
    assert vbzrx.vestedBalanceOf(account1) == 0
    wrapper.claim({"from": account2});
    assert bzrx.balanceOf(account2) > bzrxBalanceBefore2
    assert wrapper.claimable(account2) == 0

    tx4 = wrapper.withdraw(depositAmount, {"from": account2})
    assert vbzrx.balanceOf(account2) == INITIAL_ACCOUNT_AMOUNT
    assert vbzrx.vestedBalanceOf(account2) == 0
    claimable2 = wrapper.claimable(account2)
    assert claimable2 > 0
    chain.mine()
    assert wrapper.claimable(account2) == claimable2
    wrapper.claim({"from": account2})
    assert vbzrx.vestedBalanceOf(account2)  > 0
    assert wrapper.claimable(account2)  == 0
    assert vbzrx.vestedBalanceOf(account2) > 0

def test_mainflowChangeProxy(requireMainnetFork, bzrx, vbzrx, chain, accounts, wrapper, VBZRXWrapper, wvbzrxProxy):
    adminAccount = accounts[0]
    account1 = accounts[3]
    account2 = accounts[4]
    vbzrxBalanceBefore = vbzrx.balanceOf(account1)
    bzrxBalanceBefore1 = bzrx.balanceOf(account1)
    bzrxBalanceBefore2 = bzrx.balanceOf(account2)
    tx1 = vbzrx.transfer(account1, INITIAL_ACCOUNT_AMOUNT, {"from": vbzrxMajorAddress})
    vbzrxBalanceAfter = vbzrxBalanceBefore + INITIAL_ACCOUNT_AMOUNT
    assert vbzrx.balanceOf(account1) == vbzrxBalanceAfter
    assert vbzrx.vestedBalanceOf(account1) == 0
    chain.mine()

    vbzrx.approve(wrapper, vbzrx.balanceOf(account1), {"from": account1})
    depositAmount = vbzrx.balanceOf(account1);
    vestedBalance = vbzrx.vestedBalanceOf(account1);
    assert vestedBalance > 0
    tx2 = wrapper.deposit(depositAmount, {"from": account1})

    impl = VBZRXWrapper.deploy({"from": adminAccount})
    wvbzrxProxy.replaceImplementation(impl, {"from": adminAccount})

    assert vbzrx.vestedBalanceOf(account1) == 0
    assert bzrx.balanceOf(account1) >= vestedBalance + bzrxBalanceBefore1
    assert bzrx.balanceOf(account1) > bzrxBalanceBefore1

    chain.mine()
    assert wrapper.claimable(account1) > 0
    
    tx3 = wrapper.transfer(account2, depositAmount, {"from": account1})
    assert wrapper.balanceOf(account1) == 0
    assert wrapper.balanceOf(account2) == INITIAL_ACCOUNT_AMOUNT
    assert wrapper.claimable(account1) == 0
    assert wrapper.claimable(account2) > 0
    assert vbzrx.vestedBalanceOf(account2) == 0
    assert vbzrx.vestedBalanceOf(account1) == 0
    wrapper.claim({"from": account2});
    assert bzrx.balanceOf(account2) > bzrxBalanceBefore2
    assert wrapper.claimable(account2) == 0

    tx4 = wrapper.withdraw(depositAmount, {"from": account2})
    assert vbzrx.balanceOf(account2) == INITIAL_ACCOUNT_AMOUNT
    assert vbzrx.vestedBalanceOf(account2) == 0
    claimable2 = wrapper.claimable(account2)
    assert claimable2 > 0
    chain.mine()
    assert wrapper.claimable(account2) == claimable2
    wrapper.claim({"from": account2})
    assert vbzrx.vestedBalanceOf(account2)  > 0
    assert wrapper.claimable(account2)  == 0
    assert vbzrx.vestedBalanceOf(account2) > 0


def test_replaceImplementationUnderNonOwner(requireMainnetFork, bzrx, vbzrx, chain, accounts, wrapper, VBZRXWrapper, wvbzrxProxy):
    impl = VBZRXWrapper.deploy({"from": accounts[9]})

    with reverts("unauthorized"):
        wvbzrxProxy.replaceImplementation(impl, {"from": accounts[9]})

def test_exit(requireMainnetFork, bzrx, vbzrx, chain, accounts, wrapper):
    account1 = accounts[3]
    tx1 = vbzrx.transfer(account1, INITIAL_ACCOUNT_AMOUNT, {"from": vbzrxMajorAddress})
    vbzrx.approve(wrapper, vbzrx.balanceOf(account1), {"from": account1})
    depositAmount = vbzrx.balanceOf(account1);
    tx2 = wrapper.deposit(depositAmount, {"from": account1})
    assert bzrx.balanceOf(account1) > 0
    assert vbzrx.balanceOf(account1) == 0
    assert wrapper.balanceOf(account1) == INITIAL_ACCOUNT_AMOUNT
    chain.mine()
    bzrxBalanceBefore = bzrx.balanceOf(account1)
    tx3 = wrapper.exit({"from": account1})
    assert bzrx.balanceOf(account1) > bzrxBalanceBefore
    assert vbzrx.balanceOf(account1) == INITIAL_ACCOUNT_AMOUNT
    assert wrapper.balanceOf(account1) == 0


def test_events(requireMainnetFork, bzrx, vbzrx, chain, accounts, wrapper):
    account1 = accounts[4]
    tx1 = vbzrx.transfer(account1, INITIAL_ACCOUNT_AMOUNT, {"from": vbzrxMajorAddress})
    vbzrx.approve(wrapper, vbzrx.balanceOf(account1), {"from": account1})
    depositAmount = vbzrx.balanceOf(account1);
    tx2 = wrapper.deposit(depositAmount, {"from": account1})
    depositEvent = tx2.events['Deposit']
    assert depositEvent['value'] == depositAmount
    tx3 = wrapper.exit({"from": account1})
    withdrawal = tx3.events['Withdraw']
    assert withdrawal['value'] == depositAmount


def test_transfer1(requireMainnetFork, bzrx, vbzrx, chain, accounts, wrapper):
    account1 = accounts[5]
    account2 = accounts[6]
    tx1 = vbzrx.transfer(account1, INITIAL_ACCOUNT_AMOUNT, {"from": vbzrxMajorAddress})
    vbzrx.approve(wrapper, vbzrx.balanceOf(account1), {"from": account1})
    depositAmount = vbzrx.balanceOf(account1);
    wrapper.deposit(depositAmount, {"from": account1})
    balanceBefore1 = bzrx.balanceOf(account1);

    wrapper.transfer(account2, depositAmount / 2, {"from": account1})
    chain.sleep(60 * 60 * 24)
    chain.mine()
    assert abs(wrapper.claimable(account2) - wrapper.claimable(account1)) / 1e18 < 5e-6
    wrapper.claim({"from": account1})
    chain.sleep(60 * 60 * 24)
    chain.mine()
    wrapper.exit({"from": account2})
    wrapper.exit({"from": account1})
    assert abs((bzrx.balanceOf(account1)) - balanceBefore1 - bzrx.balanceOf(account2)) / 1e18 < 5e-6

def test_transfer2(requireMainnetFork, bzrx, vbzrx, chain, accounts, wrapper):
    account1 = accounts[5]
    account2 = accounts[6]
    tx1 = vbzrx.transfer(account1, INITIAL_ACCOUNT_AMOUNT, {"from": vbzrxMajorAddress})
    vbzrx.approve(wrapper, vbzrx.balanceOf(account1), {"from": account1})
    depositAmount = vbzrx.balanceOf(account1);
    wrapper.deposit(depositAmount, {"from": account1})
    chain.sleep(60 * 60 * 24)
    chain.mine()

    wrapper.transfer(account2, depositAmount / 2, {"from": account1})
    chain.sleep(60 * 60 * 24)
    chain.mine()
    #Claimable should be the same for both accounts (+-2)
    assert abs(wrapper.claimable(account2) - wrapper.claimable(account1)) < 2

def test_transfer3(requireMainnetFork, bzrx, vbzrx, chain, accounts, wrapper):
    #Precondition
    account1 = accounts[7]
    account2 = accounts[8]
    account3 = accounts[9]
    vbzrx.approve(wrapper, 2**256-1, {"from": account1})
    vbzrx.approve(wrapper, 2**256-1, {"from": account2})

    vbzrx.transfer(account1, INITIAL_ACCOUNT_AMOUNT, {"from": vbzrxMajorAddress})
    depositAmount1 = vbzrx.balanceOf(account1);
    wrapper.deposit(depositAmount1, {"from": account1})
    bzrx.transfer(accounts[0], bzrx.balanceOf(account1), {'from':account1}) #just ot have 0 balance
    chain.sleep(120 * 60 * 24) #We expect that clamableBefore1Transfer >> clamableBefore2Transfer
    chain.mine()
    clamableBefore1Transfer = wrapper.claimable(account1)
    wrapper.transfer(account3, depositAmount1,  {"from": account1});
    chain.sleep(60 * 60 * 24)
    chain.mine()

    vbzrx.transfer(account2, INITIAL_ACCOUNT_AMOUNT, {"from": vbzrxMajorAddress})
    depositAmount2 = vbzrx.balanceOf(account2);
    wrapper.deposit(depositAmount2, {"from": account2})
    bzrx.transfer(accounts[0], bzrx.balanceOf(account2), {'from':account2}) #just ot have 0 balance
    chain.sleep(60 * 60 * 24)
    chain.mine()
    clamableBefore2Transfer = wrapper.claimable(account2)

    wrapper.transfer(account3, depositAmount2,  {"from": account2});
    chain.sleep(60 * 60 * 24)
    chain.mine()
    wrapper.transfer(account1, depositAmount1,  {"from": account3});
    wrapper.transfer(account2, depositAmount2,  {"from": account3});
    assert clamableBefore1Transfer > clamableBefore2Transfer
    assert wrapper.claimable(account1) > wrapper.claimable(account2)
    assert wrapper.balanceOf(account1) == depositAmount1
    assert wrapper.balanceOf(account2) == depositAmount2
    assert wrapper.balanceOf(account3) == 0


def test_deposit_more_than_have(requireMainnetFork, vbzrx, accounts, wrapper):
    account1 = accounts[5]
    vbzrx.transfer(account1, INITIAL_ACCOUNT_AMOUNT, {"from": vbzrxMajorAddress})
    vbzrx.approve(wrapper, vbzrx.balanceOf(account1) + 1, {"from": account1})
    with reverts("insufficient-balance"):
        wrapper.deposit(vbzrx.balanceOf(account1) + 1, {"from": account1})


def test_deposit_more_than_approved(requireMainnetFork, vbzrx, accounts, wrapper):
    account1 = accounts[5]
    vbzrx.transfer(account1, INITIAL_ACCOUNT_AMOUNT, {"from": vbzrxMajorAddress})
    vbzrx.approve(wrapper, vbzrx.balanceOf(account1) - 1, {"from": account1})
    with reverts("insufficient-allowance"):
        wrapper.deposit(vbzrx.balanceOf(account1), {"from": account1})

def test_multiple_deposit_withdraw(requireMainnetFork, bzrx, vbzrx, chain, accounts, wrapper):
    for i in [1, 3]:
        account1 = accounts[i]
        vBzrxBalanceBefore1 = vbzrx.balanceOf(account1)
        vbzrx.transfer(account1, INITIAL_ACCOUNT_AMOUNT, {"from": vbzrxMajorAddress})
        vbzrx.approve(wrapper, vbzrx.balanceOf(account1), {"from": account1})
        depositAmount = vbzrx.balanceOf(account1);
        #assert False
        for i in range(5):
            wrapper.deposit(depositAmount/5, {"from": account1})
            chain.sleep(60 * 60 * 24)
            chain.mine()
            assert wrapper.claimable(account1) > 0
            wrapper.claim({"from": account1})

        for i in range(5):
            wrapper.withdraw(depositAmount/5, {"from": account1})
            chain.sleep(60 * 60 * 24)
            chain.mine()
            assert wrapper.claimable(account1) > 0
    for i in [1, 3]:
        account1 = accounts[i]
        wrapper.claim({"from": account1})


def test_multiuser_withdraw1(requireMainnetFork, bzrx, vbzrx, chain, accounts, wrapper):
    for i in [1, 3, 5, 7]:
        account1 = accounts[i]
        account2 = accounts[i + 1];
        vbzrx.transfer(account1, INITIAL_ACCOUNT_AMOUNT, {"from": vbzrxMajorAddress})
        depositAmount = vbzrx.balanceOf(account1)/2;
        vbzrx.transfer(account2, depositAmount, {"from": account1})
        vbzrx.approve(wrapper, vbzrx.balanceOf(account1), {"from": account1})
        vbzrx.approve(wrapper, vbzrx.balanceOf(account2), {"from": account2})

        wrapper.deposit(depositAmount/2, {"from": account1})
        wrapper.deposit(depositAmount/2, {"from": account2})
        wrapper.deposit(depositAmount/2, {"from": account1})
        wrapper.deposit(depositAmount/2, {"from": account2})
        chain.sleep(60 * 60 * 24)
        chain.mine()
        assert wrapper.claimable(account1) > 0
        assert wrapper.claimable(account2) > 0
        wrapper.withdraw(wrapper.balanceOf(account2), {"from": account2})
        assert wrapper.claimable(account2) > 0
        wrapper.withdraw(wrapper.balanceOf(account1), {"from": account1})
        assert wrapper.claimable(account1) > 0


def test_multiuser_withdraw2(requireMainnetFork, bzrx, vbzrx, chain, accounts, wrapper):
    for i in [1, 3, 5, 7]:
        account1 = accounts[i]
        account2 = accounts[i + 1];
        tx1 = vbzrx.transfer(account1, INITIAL_ACCOUNT_AMOUNT, {"from": vbzrxMajorAddress})
        vbzrx.approve(wrapper, vbzrx.balanceOf(account1), {"from": account1})
        depositAmount = vbzrx.balanceOf(account1);
        wrapper.deposit(depositAmount, {"from": account1})
        wrapper.transfer(account2, depositAmount / 2, {"from": account1})
        chain.sleep(60 * 60 * 24)
        chain.mine()
        wrapper.claim({"from": account1})
        chain.sleep(60 * 60 * 24)
        chain.mine()
        assert wrapper.claimable(account1) > 0
        assert wrapper.claimable(account2) > 0
        wrapper.withdraw(wrapper.balanceOf(account2), {"from": account2})
        assert wrapper.claimable(account2) > 0
        wrapper.withdraw(wrapper.balanceOf(account1), {"from": account1})
        assert wrapper.claimable(account1) > 0

def test_multiuser_exit(requireMainnetFork, bzrx, vbzrx, chain, accounts, wrapper):
    for i in [1, 3, 5, 7]:
        account1 = accounts[i]
        account2 = accounts[i + 1];
        tx1 = vbzrx.transfer(account1, INITIAL_ACCOUNT_AMOUNT, {"from": vbzrxMajorAddress})
        vbzrx.approve(wrapper, vbzrx.balanceOf(account1), {"from": account1})
        depositAmount = vbzrx.balanceOf(account1);
        wrapper.deposit(depositAmount, {"from": account1})
        wrapper.transfer(account2, depositAmount / 2, {"from": account1})
        chain.sleep(60 * 60 * 24)
        chain.mine()
        wrapper.claim({"from": account1})
        chain.sleep(60 * 60 * 24)
        chain.mine()
        wrapper.exit({"from": account2})
        wrapper.exit({"from": account1})

def test_user_able_to_claim_before_vesting_last_claim_timestamp(requireMainnetFork, bzrx, vbzrx, chain, accounts,
                                                                wrapper):
    account1 = accounts[4]
    vBzrxBalanceBefore1 = vbzrx.balanceOf(account1)
    tx1 = vbzrx.transfer(account1, INITIAL_ACCOUNT_AMOUNT, {"from": vbzrxMajorAddress})
    vbzrx.approve(wrapper, vbzrx.balanceOf(account1), {"from": account1})
    depositAmount = vbzrx.balanceOf(account1);
    tx2 = wrapper.deposit(depositAmount, {"from": account1})
    balanceBefore1 = bzrx.balanceOf(account1)
    yearSeconds = 60 * 60 * 24 * 365;
    # pass 1 year
    chain.sleep(yearSeconds)
    chain.mine()
    wrapper.claim({"from": account1});
    assert bzrx.balanceOf(account1) > balanceBefore1
    assert wrapper.claimable(account1) == 0

    # sleep up to vestingLastClaimTimestamp
    if(vbzrx.vestingLastClaimTimestamp() > chain.time()):
        chain.sleep((vbzrx.vestingLastClaimTimestamp() - chain.time()) - 10)
    chain.mine()
    balanceBefore2 = bzrx.balanceOf(account1)
    assert wrapper.claimable(account1) > 0
    tx3 = wrapper.exit({"from": account1})
    assert bzrx.balanceOf(account1) > balanceBefore2
    assert vbzrx.balanceOf(account1) == INITIAL_ACCOUNT_AMOUNT + vBzrxBalanceBefore1


def test_user_unable_to_claim_after_vesting_last_claim_timestamp(requireMainnetFork, bzrx, vbzrx, chain, accounts,
                                                       wrapper):
    account1 = accounts[4]
    vbzrxBalanceBefore = vbzrx.balanceOf(account1)
    tx1 = vbzrx.transfer(account1, INITIAL_ACCOUNT_AMOUNT, {"from": vbzrxMajorAddress})
    vbzrx.approve(wrapper, vbzrx.balanceOf(account1), {"from": account1})
    depositAmount = vbzrx.balanceOf(account1);
    tx2 = wrapper.deposit(depositAmount, {"from": account1})
    balanceBefore = bzrx.balanceOf(account1)
    # sleep up to vestingLastClaimTimestamp
    if(vbzrx.vestingLastClaimTimestamp() > chain.time()):
        chain.sleep((vbzrx.vestingLastClaimTimestamp() - chain.time()) + 1)

    chain.mine()
    assert wrapper.claimable(account1) == 0
    wrapper.exit({"from": account1});
    assert bzrx.balanceOf(account1) == balanceBefore
    assert vbzrx.balanceOf(account1) == INITIAL_ACCOUNT_AMOUNT + vbzrxBalanceBefore
    assert vbzrx.claimedBalanceOf(account1) > 0
    vbzrx.claim({"from": account1})
    assert bzrx.balanceOf(account1) == balanceBefore



# Not important case. User will not be able to claim after vesting_last_claim_timestamp.
#
# def test_user_unable_to_deposit_after_vesting_last_claim_timestamp(requireMainnetFork, vbzrx, accounts, wrapper):
#     account1 = accounts[8]
#     tx1 = vbzrx.transfer(account1, INITIAL_LP_TOKEN_ACCOUNT_AMOUNT, {"from": vbzrxMajorAddress})
#     vbzrx.approve(wrapper, vbzrx.balanceOf(account1), {"from": account1})
#     vbzrxBalanceBefore1 = vbzrx.balanceOf(account1)
#     wrapperBalanceBefore1 = vbzrx.balanceOf(account1)
#     depositAmount = vbzrx.balanceOf(account1);
#     tx2 = wrapper.deposit(depositAmount, {"from": account1})
#     assert vbzrx.balanceOf(account1) == vbzrxBalanceBefore1
#     assert wrapper.balanceOf(account1) == wrapperBalanceBefore1



