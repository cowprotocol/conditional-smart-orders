// SPDX-License-Identifier: MIT
pragma abicoder v2;
pragma solidity ^0.7.6;

import "forge-std/Test.sol";
import "../src/WaitForCoWOrder.sol";
import "./libraries/TestLib.t.sol";
import "lib/contracts/src/contracts/interfaces/GPv2EIP1271.sol";

contract WaitForCowOrderTest is Test {
    using GPv2Order for GPv2Order.Data;

    WaitForCoWOrder public instance;
    IERC20 public constant SELL_TOKEN = IERC20(0x1);
    IERC20 public constant BUY_TOKEN = IERC20(0x2);
    address public constant RECEIVER = address(0x3);
    IExpectedOutCalculator public constant EXPECTED_OUT_CALCULATOR =
        IExpectedOutCalculator(0x4);
    bytes public constant EXPECTED_OUT_CALLDATA = "0x";
    GPv2Settlement public settlement;
    GPv2Order.Data public order;

    function setUp() public {
        uint256 slippageToleranceBps = 5;
        settlement = new GPv2Settlement(GPv2Authentication(0), IVault(0));

        instance = new WaitForCoWOrder(
            SELL_TOKEN,
            BUY_TOKEN,
            RECEIVER,
            settlement,
            EXPECTED_OUT_CALCULATOR,
            EXPECTED_OUT_CALLDATA,
            slippageToleranceBps
        );

        order = GPv2Order.Data({
            sellToken: SELL_TOKEN,
            buyToken: BUY_TOKEN,
            receiver: RECEIVER,
            sellAmount: 0,
            buyAmount: 0,
            feeAmount: 0,
            appData: bytes32(0),
            validTo: 0,
            kind: GPv2Order.KIND_SELL,
            partiallyFillable: false,
            sellTokenBalance: GPv2Order.BALANCE_ERC20,
            buyTokenBalance: GPv2Order.BALANCE_ERC20
        });

        TestLib.setBalance(vm, SELL_TOKEN, 10000e18, RECEIVER);
        TestLib.setDecimals(vm, SELL_TOKEN, 18);
        TestLib.setDecimals(vm, BUY_TOKEN, 18);
    }

    function testGoodPrice() public {
        order.sellAmount = 9995e18;
        order.buyAmount = 10000e18;

        vm.mockCall(
            address(EXPECTED_OUT_CALCULATOR),
            abi.encodeWithSelector(
                EXPECTED_OUT_CALCULATOR.getExpectedOut.selector,
                1e18,
                SELL_TOKEN,
                BUY_TOKEN
            ),
            abi.encode(0.9995e18)
        );
        require(
            instance.isValidSignature(
                order.hash(settlement.domainSeparator()),
                abi.encode(order)
            ) == GPv2EIP1271.MAGICVALUE,
            "Order failed signature check"
        );
    }

    function testLimitPrice() public {
        order.sellAmount = 10000e18;
        order.buyAmount = 10000e18;

        vm.mockCall(
            address(EXPECTED_OUT_CALCULATOR),
            abi.encodeWithSelector(
                EXPECTED_OUT_CALCULATOR.getExpectedOut.selector,
                1e18,
                SELL_TOKEN,
                BUY_TOKEN
            ),
            abi.encode(0.9995e18)
        );
        require(
            instance.isValidSignature(
                order.hash(settlement.domainSeparator()),
                abi.encode(order)
            ) == GPv2EIP1271.MAGICVALUE,
            "Order failed signature check"
        );
    }

    function testBadPrice() public {
        order.sellAmount = 10001e18;
        order.buyAmount = 10000e18;

        vm.mockCall(
            address(EXPECTED_OUT_CALCULATOR),
            abi.encodeWithSelector(
                EXPECTED_OUT_CALCULATOR.getExpectedOut.selector,
                1e18,
                SELL_TOKEN,
                BUY_TOKEN
            ),
            abi.encode(0.9995e18)
        );

        bytes32 hash = order.hash(settlement.domainSeparator());
        bytes memory encodedOrder = abi.encode(order);
        vm.expectRevert("Bad price");
        instance.isValidSignature(hash, encodedOrder);
    }
}
