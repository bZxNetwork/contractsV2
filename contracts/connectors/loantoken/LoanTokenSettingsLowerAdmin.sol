/**
 * Copyright 2017-2021, bZeroX, LLC. All Rights Reserved.
 * Licensed under the Apache License, Version 2.0.
 */

pragma solidity 0.5.17;
pragma experimental ABIEncoderV2;

import "./AdvancedTokenStorage.sol";
import "../../../interfaces/IBZx.sol";


contract LoanTokenSettingsLowerAdmin is AdvancedTokenStorage {
    using SafeMath for uint256;

    address public constant bZxContract = 0xD8Ee69652E4e4838f2531732a46d1f7F584F0b7f; // mainnet
    //address public constant bZxContract = 0x5cfba2639a3db0D9Cc264Aa27B2E6d134EeA486a; // kovan
    //address public constant bZxContract = 0xC47812857A74425e2039b57891a3DFcF51602d5d; // bsc
    //address public constant bZxContract = 0xfe4F0eb0A1Ad109185c9AaDE64C48ff8e928e54B; // polygon

    bytes32 internal constant iToken_LowerAdminAddress = 0x7ad06df6a0af6bd602d90db766e0d5f253b45187c3717a0f9026ea8b10ff0d4b;    // keccak256("iToken_LowerAdminAddress")

    modifier onlyAdmin() {
        address _lowerAdmin;
        assembly {
            _lowerAdmin := sload(iToken_LowerAdminAddress)
        }

        require(msg.sender == address(this) ||
            msg.sender == _lowerAdmin ||
            msg.sender == owner(), "unauthorized");
        _;
    }

    function()
        external
    {
        revert("fallback not allowed");
    }

    function setupLoanParams(
        IBZx.LoanParams[] memory loanParamsList,
        bool areTorqueLoans)
        public
        onlyAdmin
    {
        bytes32[] memory loanParamsIdList;
        address _loanTokenAddress = loanTokenAddress;

        for (uint256 i = 0; i < loanParamsList.length; i++) {
            loanParamsList[i].loanToken = _loanTokenAddress;
            loanParamsList[i].maxLoanTerm = areTorqueLoans ? 0 : 28 days;
        }
        loanParamsIdList = IBZx(bZxContract).setupLoanParams(loanParamsList);
        for (uint256 i = 0; i < loanParamsIdList.length; i++) {
            loanParamsIds[uint256(keccak256(abi.encodePacked(
                loanParamsList[i].collateralToken,
                areTorqueLoans // isTorqueLoan
            )))] = loanParamsIdList[i];
        }
    }

    function disableLoanParams(
        address[] calldata collateralTokens,
        bool[] calldata isTorqueLoans)
        external
        onlyAdmin
    {
        require(collateralTokens.length == isTorqueLoans.length, "count mismatch");

        bytes32[] memory loanParamsIdList = new bytes32[](collateralTokens.length);
        for (uint256 i = 0; i < collateralTokens.length; i++) {
            uint256 id = uint256(keccak256(abi.encodePacked(
                collateralTokens[i],
                isTorqueLoans[i]
            )));
            loanParamsIdList[i] = loanParamsIds[id];
            delete loanParamsIds[id];
        }

        IBZx(bZxContract).disableLoanParams(loanParamsIdList);
    }

    // These params should be percentages represented like so: 5% = 5000000000000000000
    // rateMultiplier + baseRate can't exceed 100%
    function setDemandCurve(
        uint256 _baseRate,
        uint256 _rateMultiplier,
        uint256 _lowUtilBaseRate,
        uint256 _lowUtilRateMultiplier,
        uint256 _targetLevel,
        uint256 _kinkLevel,
        uint256 _maxScaleRate)
        public
        onlyAdmin
    {
        require(_rateMultiplier.add(_baseRate) <= WEI_PERCENT_PRECISION, "curve params too high");
        require(_lowUtilRateMultiplier.add(_lowUtilBaseRate) <= WEI_PERCENT_PRECISION, "curve params too high");

        require(_targetLevel <= WEI_PERCENT_PRECISION && _kinkLevel <= WEI_PERCENT_PRECISION, "levels too high");

        baseRate = _baseRate;
        rateMultiplier = _rateMultiplier;
        lowUtilBaseRate = _lowUtilBaseRate;
        lowUtilRateMultiplier = _lowUtilRateMultiplier;

        targetLevel = _targetLevel; // 80 ether
        kinkLevel = _kinkLevel; // 90 ether
        maxScaleRate = _maxScaleRate; // 100 ether
    }

    function toggleFunctionPause(
        string memory funcId,  // example: "mint(uint256,uint256)"
        bool isPaused)
        public
        onlyAdmin
    {
        bytes32 slot = keccak256(abi.encodePacked(bytes4(keccak256(abi.encodePacked(funcId))), Pausable_FunctionPause));
        assembly {
            sstore(slot, isPaused)
        }
    }
}
