// SPDX-License-Identifier: MIT
pragma abicoder v2;
pragma solidity ^0.7.6;

import "forge-std/Test.sol";
import "../src/TradeAboveThreshold.sol";

//solhint-disable reason-string
contract TradeAboveThresholdTest is Test {
    using GPv2Order for GPv2Order.Data;

    TradeAboveThreshold public instance;
    GPv2Settlement public settlement;
    IERC20 public sellToken;
    IERC20 public buyToken;
    address public receiver;

    function setUp() public {
        sellToken = IERC20(0x1);
        buyToken = IERC20(0x2);
        receiver = address(0x3);
        settlement = new GPv2Settlement(GPv2Authentication(0), IVault(0));

        //mock approval
        vm.mockCall(
            address(sellToken),
            abi.encodeWithSelector(
                sellToken.approve.selector,
                settlement.vaultRelayer(),
                uint(-1)
            ),
            abi.encode(true)
        );

        instance = new TradeAboveThreshold(
            IERC20(sellToken),
            IERC20(buyToken),
            receiver,
            100,
            settlement
        );
    }

    function setBalance(uint256 balance) private {
        vm.mockCall(
            address(sellToken),
            abi.encodeWithSelector(sellToken.balanceOf.selector, instance),
            abi.encode(balance)
        );
    }

    function testRevertsWhenNotEnoughBalance() public {
        setBalance(10);
        vm.expectRevert(bytes("Not enough balance"));
        instance.getTradeableOrder();
    }

    function testReturnsOrderIfEnoughBalance() public {
        setBalance(100);
        GPv2Order.Data memory order = instance.getTradeableOrder();
        require(order.sellToken == sellToken);
        require(order.buyToken == buyToken);
        require(order.sellAmount == 100);
        require(order.buyAmount == 1);
    }

    function testReturnsSameValidToAsLongAsInTheSameQuarterHour() public {
        setBalance(100);

        vm.warp(1670625300); // 22:35
        GPv2Order.Data memory order = instance.getTradeableOrder();
        require(order.validTo == 1670626800); //23:00

        vm.warp(1670625600); // 22:40
        order = instance.getTradeableOrder();
        require(order.validTo == 1670626800); //23:00

        vm.warp(1670626200); // 22:50
        order = instance.getTradeableOrder();
        require(order.validTo == 1670627700); //23:15
    }

    function testIsValidOrderWorksWithTradableOrder() public {
        setBalance(200);
        GPv2Order.Data memory order = instance.getTradeableOrder();
        require(
            instance.isValidSignature(
                order.hash(settlement.domainSeparator()),
                abi.encode(order)
            ) == 0x1626ba7e
        );
    }

    function testIsValidOrderRevertsWithMutatedOrder() public {
        setBalance(200);
        GPv2Order.Data memory order = instance.getTradeableOrder();
        order.sellAmount += 1;

        bytes32 hash = order.hash(settlement.domainSeparator());
        bytes memory encoded = abi.encode(order);

        vm.expectRevert("encoded order != tradable order");
        instance.isValidSignature(hash, encoded);
    }

    function testIsValidOrderRevertsWithWrongPreimage() public {
        setBalance(200);
        GPv2Order.Data memory order = instance.getTradeableOrder();
        bytes32 hash = order.hash(settlement.domainSeparator());

        order.sellAmount += 1;
        bytes memory encoded = abi.encode(order);

        vm.expectRevert("encoded order digest mismatch");
        instance.isValidSignature(hash, encoded);
    }
}
