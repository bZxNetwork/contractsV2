BZX = Contract.from_abi("BZX", "0xfe4F0eb0A1Ad109185c9AaDE64C48ff8e928e54B", interface.IBZx.abi)
TOKEN_REGISTRY = Contract.from_abi("TOKEN_REGISTRY", "0x5a6f1e81334C63DE0183A4a3864bD5CeC4151c27", TokenRegistry.abi)

list = TOKEN_REGISTRY.getTokens(0, 100)
for l in list:
    iTokenTemp = Contract.from_abi("iTokenTemp", l[0], LoanTokenLogicStandard.abi)
    globals()[iTokenTemp.symbol()] = iTokenTemp

    underlyingTemp = Contract.from_abi("underlyingTemp", l[1], TestToken.abi)
    globals()[underlyingTemp.symbol()] = underlyingTemp

CHEF =  Contract.from_abi("CHEF", "0xd39Ff512C3e55373a30E94BB1398651420Ae1D43", MasterChef_Polygon.abi)
PGOV = Contract.from_abi("PGOV", "0xd5d84e75f48E75f01fb2EB6dFD8eA148eE3d0FEb", GovToken.abi)
PGOV_MATIC_LP = Contract.from_abi("PGOV", "0xC698b8a1391F88F497A4EF169cA85b492860b502", interface.ERC20.abi)
HELPER = Contract.from_abi("HELPER", "0xCc0fD6AA1F92e18D103A7294238Fdf558008725a", HelperImpl.abi)
PRICE_FEED = Contract.from_abi("PRICE_FEED", BZX.priceFeeds(), abi = PriceFeeds.abi)
SUSHI_ROUTER = Contract.from_abi("router", "0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506", interface.IPancakeRouter02.abi)