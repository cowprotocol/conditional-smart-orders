// SPDX-License-Identifier: MIT
pragma abicoder v2;
pragma solidity ^0.7.6;

import "forge-std/Test.sol";
import "../src/PerpetualStableSwap.sol";
import "lib/contracts/src/contracts/interfaces/GPv2EIP1271.sol";

contract PerpetualStableSwapTest is Test {
    using GPv2Order for GPv2Order.Data;

    PerpetualStableSwap public instance;
    GPv2Settlement settlement;
    IERC20 public tokenA;
    IERC20 public tokenB;
    address public receiver;

    function setUp() public {
        tokenA = IERC20(0x1);
        tokenB = IERC20(0x2);
        receiver = address(0x3);
        settlement = new GPv2Settlement(GPv2Authentication(0), IVault(0));
    }

    function setBalance(IERC20 token, uint256 balance) private {
        vm.mockCall(
            address(token),
            abi.encodeWithSelector(token.balanceOf.selector, receiver),
            abi.encode(balance)
        );
    }

    function setDecimals(IERC20 token, uint8 decimals) private {
        vm.mockCall(
            address(token),
            abi.encodeWithSelector(token.decimals.selector),
            abi.encode(decimals)
        );
    }

    function testTradesTokenWithLargerBalance() public {
        uint256 halfSpreadBps = 100;
        instance = new PerpetualStableSwap(
            tokenA,
            tokenB,
            halfSpreadBps,
            receiver,
            settlement
        );

        setDecimals(tokenA, 18);
        setDecimals(tokenB, 18);
        setBalance(tokenA, 1e19);
        setBalance(tokenB, 2e19);

        GPv2Order.Data memory order = instance.getTradeableOrder();
        require(order.sellToken == tokenB, "Wrong sell token");
        require(order.buyToken == tokenA, "Wrong buy token");
        require(order.sellAmount == 2e19, "Wrong sell amount");
        require(order.buyAmount == 2e19 + 2e17, "Wrong buy amount");
        require(instance.isValidSignature(order.hash(settlement.domainSeparator()), "") == GPv2EIP1271.MAGICVALUE, "Tradeable order doesn't pass signature check");
    }

    function testTradesTokensWithDifferentDecimals() public {
        uint256 halfSpreadBps = 100;
        instance = new PerpetualStableSwap(
            tokenA,
            tokenB,
            halfSpreadBps,
            receiver,
            settlement
        );

        //Larger decimal token has more balance
        setDecimals(tokenA, 18);
        setDecimals(tokenB, 6);
        setBalance(tokenA, 2e18);
        setBalance(tokenB, 1e6);

        GPv2Order.Data memory order = instance.getTradeableOrder();
        require(order.sellToken == tokenA, "Wrong sell token");
        require(order.buyToken == tokenB, "Wrong buy token");
        require(order.sellAmount == 2e18, "Wrong sell amount");
        require(order.buyAmount == 2e6 + 2e4, "Wrong buy amount");
        require(instance.isValidSignature(order.hash(settlement.domainSeparator()), "") == GPv2EIP1271.MAGICVALUE, "Tradeable order doesn't pass signature check");

        //Lower decimal token has more balance
        setBalance(tokenB, 3e6);

        order = instance.getTradeableOrder();
        require(order.sellToken == tokenB, "Wrong sell token");
        require(order.buyToken == tokenA, "Wrong buy token");
        require(order.sellAmount == 3e6, "Wrong sell amount");
        require(order.buyAmount == 3e18 + 3e16, "Wrong buy amount");
        require(instance.isValidSignature(order.hash(settlement.domainSeparator()), "") == GPv2EIP1271.MAGICVALUE, "Tradeable order doesn't pass signature check");
    }

    function testValidity() public {
        uint256 halfSpreadBps = 100;
        instance = new PerpetualStableSwap(
            tokenA,
            tokenB,
            halfSpreadBps,
            receiver,
            settlement
        );

        setDecimals(tokenA, 18);
        setDecimals(tokenB, 18);
        setBalance(tokenA, 1e18);
        setBalance(tokenB, 1e18);

        vm.warp(1671436380); // Mon Dec 19
        GPv2Order.Data memory order = instance.getTradeableOrder();
        require(order.validTo == 1672272000); // Thu Dec 29

        vm.warp(1671667200); // Thu Dec 22
        order = instance.getTradeableOrder();
        require(order.validTo == 1672876800); // Thu Jan 5
    }
}
