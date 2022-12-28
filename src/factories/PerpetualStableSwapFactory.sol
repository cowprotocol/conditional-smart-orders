// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma abicoder v2;

import "../PerpetualStableSwap.sol";

// @title A factory to create `PerpetualStableSwap` order instances
contract PerpetualStableSwapFactory {
    GPv2Settlement public constant SETTLEMENT_CONTRACT =
        GPv2Settlement(0x9008D19f58AAbD9eD0D60971565AA8510560ab41);

    function create(
        IERC20 tokenA,
        IERC20 tokenB,
        uint256 halfSpreadBps,
        address target
    ) external returns (PerpetualStableSwap) {
        return
            new PerpetualStableSwap(
                tokenA,
                tokenB,
                halfSpreadBps,
                target,
                SETTLEMENT_CONTRACT
            );
    }
}
