BZX = Contract.from_abi("BZX", "0xAbd9372723C735D426D0a760D047206Fe115ee6d", interface.IBZx.abi)
TOKEN_REGISTRY = Contract.from_abi("TOKEN_REGISTRY", "0x02Ed75baD5DAB130983560135b9969F7DFC45e44", TokenRegistry.abi) # TODO this not working fix it

list = TOKEN_REGISTRY.getTokens(0, 100)
for l in list:
    iTokenTemp = Contract.from_abi("iTokenTemp", l[0], LoanTokenLogicStandard.abi)
    globals()[iTokenTemp.symbol()] = iTokenTemp

    underlyingTemp = Contract.from_abi("underlyingTemp", l[1], TestToken.abi)
    globals()[underlyingTemp.symbol()] = underlyingTemp

HELPER = Contract.from_abi("HELPER", "0x4C90348b3fa4Edf8bFC2e777170a0A495463cb90", HelperImpl.abi)
PRICE_FEED = Contract.from_abi("PRICE_FEED", BZX.priceFeeds(), abi = PriceFeeds.abi)