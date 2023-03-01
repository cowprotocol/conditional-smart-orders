// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma abicoder v2;

import "../WaitForCoWOrder.sol";

// @title A factory to create `WaitForCoW` order instances
contract PerpetualStableSwapFactory {
    GPv2Settlement public constant SETTLEMENT_CONTRACT =
        GPv2Settlement(0x9008D19f58AAbD9eD0D60971565AA8510560ab41);

    function create(
        IERC20 sellToken,
        IERC20 buyToken,
        address target,
        IExpectedOutCalculator expectedOutCalculator,
        bytes calldata expectedOutCalculatorCalldata,
        uint256 halfSpreadBps
    ) external returns (WaitForCoWOrder) {
        return
            new WaitForCoWOrder(
                sellToken,
                buyToken,
                target,
                SETTLEMENT_CONTRACT,
                expectedOutCalculator,
                expectedOutCalculatorCalldata,
                halfSpreadBps
            );
    }
}
