#!/usr/bin/python3

import pytest
from brownie import network, Contract, Wei, chain, reverts


@pytest.fixture(scope="module")
def requireMainnetFork():
    assert (network.show_active() == "mainnet-fork" or network.show_active() == "mainnet-fork-alchemy")

@pytest.fixture(scope="module")
def iUSDC(accounts, LoanTokenLogicStandard):
    iUSDC = loadContractFromAbi(
        "0x32E4c68B3A4a813b710595AebA7f6B7604Ab9c15", "iUSDC", LoanTokenLogicStandard.abi)
    return iUSDC

@pytest.fixture(scope="module")
def BZX(accounts, LoanTokenLogicStandard, interface):
    BZX = loadContractFromAbi(
        "0xD8Ee69652E4e4838f2531732a46d1f7F584F0b7f", "BZX", abi=interface.IBZx.abi)
    return BZX

@pytest.fixture(scope="module")
def GOVERNANCE_DELEGATOR(accounts, GovernorBravoDelegator, STAKING, TIMELOCK, GovernorBravoDelegate):
    ADMIN = accounts[0]
    MIN_VOTINGPEROD = 5760
    MIN_VOTING_DELAY = 1
    MIN_PROPOSAL_THRESHOLD = 50000e18
    impl = accounts[0].deploy(GovernorBravoDelegate)
    governorBravoDelegator = accounts[0].deploy(GovernorBravoDelegator, TIMELOCK, STAKING, ADMIN, impl, MIN_VOTINGPEROD, MIN_VOTING_DELAY, MIN_PROPOSAL_THRESHOLD) 
    return Contract.from_abi("governorBravoDelegator", address=governorBravoDelegator, abi=GovernorBravoDelegate.abi, owner=accounts[0])

@pytest.fixture(scope="module")
def STAKING(StakingV1_1, accounts, StakingProxy):
    bzxOwner = "0xB7F72028D9b502Dc871C444363a7aC5A52546608"
    stakingAddress = "0xe95Ebce2B02Ee07dEF5Ed6B53289801F7Fc137A4"
    proxy = Contract.from_abi("staking", address=stakingAddress,abi=StakingProxy.abi)
    impl = accounts[0].deploy(StakingV1_1)
    proxy.replaceImplementation(impl, {"from": bzxOwner})
    return Contract.from_abi("staking", address=stakingAddress,abi=StakingV1_1.abi)

@pytest.fixture(scope="module")
def TIMELOCK(Timelock, accounts):
    hours12 = 12*60*60
    timelock = accounts[0].deploy(Timelock, accounts[0], hours12)
    return timelock


@pytest.fixture(scope="module")
def iUSDC(LoanTokenLogicStandard):
    iUSDC = loadContractFromAbi(
        "0x32E4c68B3A4a813b710595AebA7f6B7604Ab9c15", "iUSDC", LoanTokenLogicStandard.abi)
    return iUSDC

@pytest.fixture(scope="module")
def TOKEN_SETTINGS(LoanTokenSettings):
    return Contract.from_abi(
        "loanToken", address="0x11ba2b39bc80464c14b7eea54d2ec93d8f60e7b8", abi=LoanTokenSettings.abi)

@pytest.fixture(scope="function", autouse=True)
def isolate(fn_isolation):
    pass


def loadContractFromAbi(address, alias, abi):
    try:
        return Contract(alias)
    except ValueError:
        contract = Contract.from_abi(alias, address=address, abi=abi)
        return contract


def testGovernance(requireMainnetFork, GOVERNANCE_DELEGATOR, TIMELOCK, STAKING, TOKEN_SETTINGS, iUSDC, accounts):  
    bzxOwner = "0xB7F72028D9b502Dc871C444363a7aC5A52546608"
    
    # init timelock below
    calldata = TIMELOCK.setPendingAdmin.encode_input(GOVERNANCE_DELEGATOR.address)
    eta = chain.time()+TIMELOCK.delay() + 10
    TIMELOCK.queueTransaction(TIMELOCK, 0, b"", calldata, eta)
    chain.sleep(eta-chain.time())
    chain.mine()
    TIMELOCK.executeTransaction(TIMELOCK, 0, b"", calldata, eta)

    # set staking with governor
    STAKING.setGovernor(GOVERNANCE_DELEGATOR, {"from": bzxOwner})

    # init governance
    GOVERNANCE_DELEGATOR._initiate()

    # make a proposal to change iUSDC name
    newName = iUSDC.name() + "1"
    calldata = TOKEN_SETTINGS.initialize.encode_input(iUSDC.loanTokenAddress(), newName, iUSDC.symbol())
    calldata2 = iUSDC.updateSettings.encode_input(TOKEN_SETTINGS, calldata)

    tx = GOVERNANCE_DELEGATOR.propose([iUSDC.address],[0],[""],[calldata2],"asdf", {"from": bzxOwner})
    proposalCount = GOVERNANCE_DELEGATOR.proposalCount()
    proposal = GOVERNANCE_DELEGATOR.proposals(proposalCount)
    id = proposal[0]
    eta = proposal[2]
    startBlock = proposal[3]
    endBlock = proposal[4]
    forVotes = proposal[5]
    againstVotes = proposal[6]
    abstainVotes = proposal[7]
    canceled = proposal[8]
    assert GOVERNANCE_DELEGATOR.state.call(id) == 0
    chain.mine()

    # after first vote state is active
    tx = GOVERNANCE_DELEGATOR.castVote(id,1, {"from" : bzxOwner})
    assert GOVERNANCE_DELEGATOR.state.call(id) == 1

    chain.mine(endBlock - chain.height)
    assert GOVERNANCE_DELEGATOR.state.call(id) == 1
    chain.mine()
    assert GOVERNANCE_DELEGATOR.state.call(id) == 4
    
    GOVERNANCE_DELEGATOR.queue(id)

    proposal = GOVERNANCE_DELEGATOR.proposals(proposalCount)
    eta = proposal[2]
    chain.sleep(eta - chain.time())
    chain.mine()

    iUSDC.transferOwnership(TIMELOCK, {"from": bzxOwner})
    GOVERNANCE_DELEGATOR.execute(id)

    assert True


def testGovernanceProposeCancel(requireMainnetFork, GOVERNANCE_DELEGATOR, TIMELOCK, STAKING, TOKEN_SETTINGS, iUSDC, accounts):  
    bzxOwner = "0xB7F72028D9b502Dc871C444363a7aC5A52546608"
    
    # init timelock below
    calldata = TIMELOCK.setPendingAdmin.encode_input(GOVERNANCE_DELEGATOR.address)
    eta = chain.time()+TIMELOCK.delay() + 10
    TIMELOCK.queueTransaction(TIMELOCK, 0, b"", calldata, eta)
    chain.sleep(eta-chain.time())
    chain.mine()
    TIMELOCK.executeTransaction(TIMELOCK, 0, b"", calldata, eta)

    # set staking with governor
    STAKING.setGovernor(GOVERNANCE_DELEGATOR, {"from": bzxOwner})

    # init governance
    GOVERNANCE_DELEGATOR._initiate()

    # make a proposal to change iUSDC name
    newName = iUSDC.name() + "1"
    calldata = TOKEN_SETTINGS.initialize.encode_input(iUSDC.loanTokenAddress(), newName, iUSDC.symbol())
    calldata2 = iUSDC.updateSettings.encode_input(TOKEN_SETTINGS, calldata)

    tx = GOVERNANCE_DELEGATOR.propose([iUSDC.address],[0],[""],[calldata2],"asdf", {"from": bzxOwner})
    proposalCount = GOVERNANCE_DELEGATOR.proposalCount()
    proposal = GOVERNANCE_DELEGATOR.proposals(proposalCount)
    id = proposal[0]
    eta = proposal[2]
    startBlock = proposal[3]
    endBlock = proposal[4]
    forVotes = proposal[5]
    againstVotes = proposal[6]
    abstainVotes = proposal[7]
    canceled = proposal[8]
   
    tx = GOVERNANCE_DELEGATOR.cancel(id, {"from": bzxOwner})
    proposal = GOVERNANCE_DELEGATOR.proposals(proposalCount)
    canceled = proposal[8]
    assert canceled == True



def testGovernanceProposeVotingActiveCancel(requireMainnetFork, GOVERNANCE_DELEGATOR, TIMELOCK, STAKING, TOKEN_SETTINGS, iUSDC, accounts):  
    bzxOwner = "0xB7F72028D9b502Dc871C444363a7aC5A52546608"
    
    # init timelock below
    calldata = TIMELOCK.setPendingAdmin.encode_input(GOVERNANCE_DELEGATOR.address)
    eta = chain.time()+TIMELOCK.delay() + 10
    TIMELOCK.queueTransaction(TIMELOCK, 0, b"", calldata, eta)
    chain.sleep(eta-chain.time())
    chain.mine()
    TIMELOCK.executeTransaction(TIMELOCK, 0, b"", calldata, eta)

    # set staking with governor
    STAKING.setGovernor(GOVERNANCE_DELEGATOR, {"from": bzxOwner})

    # init governance
    GOVERNANCE_DELEGATOR._initiate()

    # make a proposal to change iUSDC name
    newName = iUSDC.name() + "1"
    calldata = TOKEN_SETTINGS.initialize.encode_input(iUSDC.loanTokenAddress(), newName, iUSDC.symbol())
    calldata2 = iUSDC.updateSettings.encode_input(TOKEN_SETTINGS, calldata)

    tx = GOVERNANCE_DELEGATOR.propose([iUSDC.address],[0],[""],[calldata2],"asdf", {"from": bzxOwner})
    proposalCount = GOVERNANCE_DELEGATOR.proposalCount()
    proposal = GOVERNANCE_DELEGATOR.proposals(proposalCount)
    id = proposal[0]
    eta = proposal[2]
    startBlock = proposal[3]
    endBlock = proposal[4]
    forVotes = proposal[5]
    againstVotes = proposal[6]
    abstainVotes = proposal[7]
    canceled = proposal[8]

    chain.mine()
    tx = GOVERNANCE_DELEGATOR.castVote(id,1, {"from" : bzxOwner})
    assert GOVERNANCE_DELEGATOR.state.call(id) == 1
   
    tx = GOVERNANCE_DELEGATOR.cancel(id, {"from": bzxOwner})
    proposal = GOVERNANCE_DELEGATOR.proposals(proposalCount)
    canceled = proposal[8]
    assert canceled == True


def testGovernanceProposeVotingActiveVotingEndsDefeated(requireMainnetFork, GOVERNANCE_DELEGATOR, TIMELOCK, STAKING, TOKEN_SETTINGS, iUSDC, accounts):  
    bzxOwner = "0xB7F72028D9b502Dc871C444363a7aC5A52546608"
    
    # init timelock below
    calldata = TIMELOCK.setPendingAdmin.encode_input(GOVERNANCE_DELEGATOR.address)
    eta = chain.time()+TIMELOCK.delay() + 10
    TIMELOCK.queueTransaction(TIMELOCK, 0, b"", calldata, eta)
    chain.sleep(eta-chain.time())
    chain.mine()
    TIMELOCK.executeTransaction(TIMELOCK, 0, b"", calldata, eta)

    # set staking with governor
    STAKING.setGovernor(GOVERNANCE_DELEGATOR, {"from": bzxOwner})

    # init governance
    GOVERNANCE_DELEGATOR._initiate()

    # make a proposal to change iUSDC name
    newName = iUSDC.name() + "1"
    calldata = TOKEN_SETTINGS.initialize.encode_input(iUSDC.loanTokenAddress(), newName, iUSDC.symbol())
    calldata2 = iUSDC.updateSettings.encode_input(TOKEN_SETTINGS, calldata)

    tx = GOVERNANCE_DELEGATOR.propose([iUSDC.address],[0],[""],[calldata2],"asdf", {"from": bzxOwner})
    proposalCount = GOVERNANCE_DELEGATOR.proposalCount()
    proposal = GOVERNANCE_DELEGATOR.proposals(proposalCount)
    id = proposal[0]
    eta = proposal[2]
    startBlock = proposal[3]
    endBlock = proposal[4]
    forVotes = proposal[5]
    againstVotes = proposal[6]
    abstainVotes = proposal[7]
    canceled = proposal[8]

    chain.mine()
    tx = GOVERNANCE_DELEGATOR.castVote(id,0, {"from" : bzxOwner})
    assert GOVERNANCE_DELEGATOR.state.call(id) == 1
   

    chain.mine(endBlock - chain.height)
    assert GOVERNANCE_DELEGATOR.state.call(id) == 1
    chain.mine()
    assert GOVERNANCE_DELEGATOR.state.call(id) == 3
    with reverts("GovernorBravo::queue: proposal can only be queued if it is succeeded"):
        GOVERNANCE_DELEGATOR.queue(id)

    tx = GOVERNANCE_DELEGATOR.cancel(id, {"from": bzxOwner})
    proposal = GOVERNANCE_DELEGATOR.proposals(proposalCount)
    canceled = proposal[8]
    assert canceled == True




def testGovernanceReallyComplexTXToSetITokens(requireMainnetFork, GOVERNANCE_DELEGATOR, TIMELOCK, STAKING, TOKEN_SETTINGS, iUSDC, accounts,TestToken, LoanTokenLogicStandard, TokenRegistry, LoanToken, LoanTokenSettings, interface, PriceFeeds, ProtocolSettings, LoanTokenSettingsLowerAdmin):  
    bzxOwner = accounts.at("0xB7F72028D9b502Dc871C444363a7aC5A52546608", force=True)
    
    # init timelock below
    calldata = TIMELOCK.setPendingAdmin.encode_input(GOVERNANCE_DELEGATOR.address)
    eta = chain.time()+TIMELOCK.delay() + 10
    TIMELOCK.queueTransaction(TIMELOCK, 0, b"", calldata, eta)
    chain.sleep(eta-chain.time())
    chain.mine()
    TIMELOCK.executeTransaction(TIMELOCK, 0, b"", calldata, eta)

    # set staking with governor
    STAKING.setGovernor(GOVERNANCE_DELEGATOR, {"from": bzxOwner})

    # init governance
    GOVERNANCE_DELEGATOR._initiate()

    # begining of building calldata arrays 







    # calldataArray = getTransactionListToDeployITokens(accounts)
    calldataArray = []
    targets = []
    underlyingSymbol = "ABC"
    iTokenSymbol = "i{}".format(underlyingSymbol)
    iTokenName = "Fulcrum {} iToken ({})".format(underlyingSymbol, iTokenSymbol)  
    loanTokenAddress = bzxOwner.deploy(TestToken, underlyingSymbol, underlyingSymbol, 18, 1e50).address  
    loanTokenLogicStandard = bzxOwner.deploy(LoanTokenLogicStandard, bzxOwner).address
    bzxRegistry = Contract.from_abi("bzxRegistry", address="0xf0E474592B455579Fe580D610b846BdBb529C6F7", abi=TokenRegistry.abi)
    bzx = Contract.from_abi("bzx", address="0xD8Ee69652E4e4838f2531732a46d1f7F584F0b7f", abi=interface.IBZx.abi, owner=bzxOwner)
    priceFeed = Contract.from_abi("pricefeed", bzx.priceFeeds(), abi=PriceFeeds.abi, owner=bzxOwner)
    

    iTokenProxy = bzxOwner.deploy(LoanToken, bzxOwner, loanTokenLogicStandard)
    loanTokenSettings = bzxOwner.deploy(LoanTokenSettings)

    calldata = loanTokenSettings.initialize.encode_input(
        loanTokenAddress, iTokenName, iTokenSymbol)

    iToken = Contract.from_abi("loanTokenLogicStandard",
                            iTokenProxy, LoanTokenLogicStandard.abi, bzxOwner)

    iToken.transferOwnership(TIMELOCK, {"from": bzxOwner})
    calldata = iToken.updateSettings.encode_input(loanTokenSettings, calldata)
    calldataArray.append(calldata)
    targets.append(iToken.address)

    # Setting price Feed
    bzx.transferOwnership(TIMELOCK, {"from": bzxOwner})
    priceFeed.transferOwnership(TIMELOCK, {"from": bzxOwner})
    priceFeedAddress = "0xA9F9F897dD367C416e350c33a92fC12e53e1Cee5" # FAKE price feed
    calldata = priceFeed.setPriceFeed.encode_input([loanTokenAddress], [priceFeedAddress])

    calldataArray.append(calldata)
    targets.append(priceFeed.address)


    calldata = bzx.setLoanPool.encode_input([iToken], [loanTokenAddress])
    calldataArray.append(calldata)
    targets.append(bzx.address)

    protocolSettings = ProtocolSettings.deploy({'from': TIMELOCK})
    bzx.replaceContract(protocolSettings, {"from": TIMELOCK})
    calldata = bzx.setSupportedTokens.encode_input([loanTokenAddress], [True], False)
    calldataArray.append(calldata)
    targets.append(bzx.address)

    base_data = [
        b"0x0",  # id
        False,  # active
        str(TIMELOCK),  # owner
        "0x0000000000000000000000000000000000000001",  # loanToken
        "0x0000000000000000000000000000000000000002",  # collateralToken
        Wei("20 ether"),  # minInitialMargin
        Wei("15 ether"),  # maintenanceMargin
        0  # fixedLoanTerm
    ]

    params = []
    

    supportedTokenAssetsPairs = bzxRegistry.getTokens(0, 100) # TODO move this into a loop for permissionless to support more than 100
    loanTokensArr = []
    collateralTokensArr = []
    amountsArr =[]

    for tokenAssetPair in supportedTokenAssetsPairs:
        if tokenAssetPair[0] == iToken.address:
            continue
        # below is to allow different collateral for new iToken
        base_data_copy = base_data.copy()
        base_data_copy[3] = loanTokenAddress
        base_data_copy[4] = tokenAssetPair[1] # pair is iToken, Underlying
        print(base_data_copy)
        params.append(base_data_copy)
        
        loanTokensArr.append(loanTokenAddress)
        collateralTokensArr.append(tokenAssetPair[1])
        amountsArr.append(7*10**18)

    loanTokenSettingsLowerAdmin = LoanTokenSettingsLowerAdmin.deploy({'from': TIMELOCK})  # TODO use Tom addr
    calldata = loanTokenSettingsLowerAdmin.setupLoanParams.encode_input(params, True)
    calldata = iToken.updateSettings.encode_input(loanTokenSettingsLowerAdmin.address, calldata)
    calldataArray.append(calldata)
    targets.append(iToken.address)

    calldata = loanTokenSettingsLowerAdmin.setupLoanParams.encode_input(params, False)
    iToken.updateSettings.encode_input(loanTokenSettingsLowerAdmin.address, calldata)
    calldataArray.append(calldata)
    targets.append(iToken.address)


    calldata = loanTokenSettingsLowerAdmin.setDemandCurve.encode_input(0, 23.75*10**18, 0, 0, 80*10**18, 80*10**18, 120*10**18)
    iToken.updateSettings.encode_input(loanTokenSettingsLowerAdmin.address, calldata)
    calldataArray.append(calldata)
    targets.append(iToken.address)



    # params.clear()
    # for tokenAssetPair in supportedTokenAssetsPairs:
    #     # below is to allow new iToken.loanTokenAddress in other existing iTokens
    #     existingIToken = Contract.from_abi("existingIToken", address=tokenAssetPair[0], abi=LoanTokenLogicStandard.abi, owner=bzxOwner)
        
    #     base_data_copy = base_data.copy()
    #     existingITokenLoanTokenAddress = existingIToken.loanTokenAddress()
    #     base_data_copy[3] = existingITokenLoanTokenAddress
    #     base_data_copy[4] = loanTokenAddress # pair is iToken, Underlying
    #     print(base_data_copy)
    #     params.append(base_data_copy)


    #     calldata = loanTokenSettingsLowerAdmin.setupLoanParams.encode_input(params, True)
    #     calldata = existingIToken.updateSettings.encode_input(loanTokenSettingsLowerAdmin.address, calldata)
    #     calldataArray.append(calldata)
    #     targets.append(existingIToken.address)


    #     calldata = loanTokenSettingsLowerAdmin.setupLoanParams.encode_input(params, False)
    #     calldata = existingIToken.updateSettings.encode_input(loanTokenSettingsLowerAdmin.address, calldata)
    #     calldataArray.append(calldata)
    #     targets.append(existingIToken.address)


    #     loanTokensArr.append(loanTokenAddress)
    #     collateralTokensArr.append(existingITokenLoanTokenAddress)
    #     amountsArr.append(7*10**18)
    #     params.clear()

    # calldata = bzx.setLiquidationIncentivePercent.encode_input(loanTokensArr, collateralTokensArr, amountsArr)
    # calldataArray.append(calldata)
    # targets.append(bzx.address)












    # end of building calldata arrays 

    

    tx = GOVERNANCE_DELEGATOR.propose(
        targets,
        [0] * len(calldataArray),
        [""] * len(calldataArray),
        calldataArray,
        "asdf", 
        {"from": bzxOwner})
    proposalCount = GOVERNANCE_DELEGATOR.proposalCount()
    proposal = GOVERNANCE_DELEGATOR.proposals(proposalCount)
    id = proposal[0]
    eta = proposal[2]
    startBlock = proposal[3]
    endBlock = proposal[4]
    forVotes = proposal[5]
    againstVotes = proposal[6]
    abstainVotes = proposal[7]
    canceled = proposal[8]
    assert GOVERNANCE_DELEGATOR.state.call(id) == 0
    chain.mine()

    # after first vote state is active
    tx = GOVERNANCE_DELEGATOR.castVote(id,1, {"from" : bzxOwner})
    assert GOVERNANCE_DELEGATOR.state.call(id) == 1

    chain.mine(endBlock - chain.height)
    assert GOVERNANCE_DELEGATOR.state.call(id) == 1
    chain.mine()
    assert GOVERNANCE_DELEGATOR.state.call(id) == 4
    
    GOVERNANCE_DELEGATOR.queue(id)

    proposal = GOVERNANCE_DELEGATOR.proposals(proposalCount)
    eta = proposal[2]
    chain.sleep(eta - chain.time())
    chain.mine()

    iUSDC.transferOwnership(TIMELOCK, {"from": bzxOwner})
    GOVERNANCE_DELEGATOR.execute(id)

    assert False
