BZX = Contract.from_abi("BZX", "0xc47812857a74425e2039b57891a3dfcf51602d5d", interface.IBZx.abi)
TOKEN_REGISTRY = Contract.from_abi("TOKEN_REGISTRY", "0x2fA30fB75E08f5533f0CF8EBcbb1445277684E85", TokenRegistry.abi)

list = TOKEN_REGISTRY.getTokens(0, 100)
for l in list:
    iTokenTemp = Contract.from_abi("iTokenTemp", l[0], LoanTokenLogicStandard.abi)
    globals()[iTokenTemp.symbol()] = iTokenTemp

    underlyingTemp = Contract.from_abi("underlyingTemp", l[1], TestToken.abi)
    globals()[underlyingTemp.symbol()] = underlyingTemp

CHI = Contract.from_abi("CHI", "0x0000000000004946c0e9F43F4Dee607b0eF1fA1c", TestToken.abi)
CHEF = Contract.from_abi("CHEF", "0x1FDCA2422668B961E162A8849dc0C2feaDb58915", MasterChef_BSC.abi)
HELPER = Contract.from_abi("HELPER", "0xE05999ACcb887D32c9bd186e8C9dfE0e1E7814dE", HelperImpl.abi)
