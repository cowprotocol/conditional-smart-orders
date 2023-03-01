// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "lib/contracts/src/contracts/interfaces/IERC20.sol";
import "forge-std/Test.sol";

library TestLib {
    function setBalance(Vm vm, IERC20 token, uint256 balance, address owner) public {
        vm.mockCall(
            address(token),
            abi.encodeWithSelector(token.balanceOf.selector, owner),
            abi.encode(balance)
        );
    }

    function setDecimals(Vm vm, IERC20 token, uint8 decimals) public {
        vm.mockCall(
            address(token),
            abi.encodeWithSelector(token.decimals.selector),
            abi.encode(decimals)
        );
    }
}
