// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma abicoder v2;

import "./ConditionalOrder.sol";
import "lib/contracts/src/contracts/GPv2Settlement.sol";
import "lib/contracts/src/contracts/interfaces/GPv2EIP1271.sol";

// @title A smart contract that is always willing to trade between tokenA and tokenB 1:1,
// taking decimals into account (and adding specifiable spread)
contract PerpetualStableSwap is ConditionalOrder, EIP1271Verifier {
    using GPv2Order for GPv2Order.Data;
    using SafeMath for uint256;
    using SafeMath for uint8;

    IERC20 public immutable tokenA;
    IERC20 public immutable tokenB;
    uint256 public immutable halfSpreadBps;
    address public immutable target;
    bytes32 domainSeparator;

    // There are 10k basis points in a unit
    uint256 public constant BPS = 10_000;

    constructor(
        IERC20 _tokenA,
        IERC20 _tokenB,
        uint256 _halfSpreadBps,
        address _target,
        GPv2Settlement _settlementContract
    ) {
        tokenA = _tokenA;
        tokenB = _tokenB;
        halfSpreadBps = _halfSpreadBps;
        domainSeparator = _settlementContract.domainSeparator();

        if (_target == address(0)) {
            _target = address(this);
            // Otherwise we expect the target to set allowance itself
            _tokenA.approve(
                address(_settlementContract.vaultRelayer()),
                uint(-1)
            );
            _tokenB.approve(
                address(_settlementContract.vaultRelayer()),
                uint(-1)
            );
        } 
        target = _target;
        emit ConditionalOrderCreated(_target);
    }

    function getTradeableOrder()
        external
        view
        override
        returns (GPv2Order.Data memory)
    {
        uint256 balanceA = tokenA.balanceOf(target);
        uint256 balanceB = tokenB.balanceOf(target);

        // Always sell whatever of the two tokens we have more of
        IERC20 sellToken;
        IERC20 buyToken;
        uint256 sellAmount;
        uint256 buyAmount;
        if (convertAmount(tokenA, balanceA, tokenB) > balanceB) {
            sellToken = tokenA;
            buyToken = tokenB;
            sellAmount = balanceA;
            buyAmount = convertAmount(tokenA, balanceA, tokenB).mul(BPS.add(halfSpreadBps)).div(BPS);
        } else {
            sellToken = tokenB;
            buyToken = tokenA;
            sellAmount = balanceB;
            buyAmount = convertAmount(tokenB, balanceB, tokenA).mul(BPS.add(halfSpreadBps)).div(BPS);
        }
        require(sellAmount > 0, "not funded");

        // Unless spread is 0 (and there is no surplus), order collision is not an issue as sell and buy amounts should
        // increase for each subsequent order. We therefore set validity to a large time span
        // Note, that reducing currenbt block to a common start time is needed so that the order returned here
        // does not change between the time it is queried and the time it is settled.
        uint32 validity = 1 weeks;
        uint32 currentTimeBucket = ((uint32(block.timestamp) / validity) + 1) * validity;
        return
            GPv2Order.Data(
                sellToken,
                buyToken,
                target,
                sellAmount,
                buyAmount,
                currentTimeBucket + validity,
                keccak256("PerpetualStableSwap"),
                0,
                GPv2Order.KIND_SELL,
                false,
                GPv2Order.BALANCE_ERC20,
                GPv2Order.BALANCE_ERC20
            );
    }

    function convertAmount(
        IERC20 srcToken,
        uint256 srcAmount,
        IERC20 destToken
    ) public view returns (uint256 destAmount) {
        uint8 srcDecimals = srcToken.decimals();
        uint8 destDecimals = destToken.decimals();

        if (srcDecimals > destDecimals) {
            destAmount = srcAmount.div(10**(srcDecimals.sub(destDecimals)));
        } else {
            destAmount = srcAmount.mul(10**(destDecimals.sub(srcDecimals)));
        }
    }

    /// @param orderDigest The EIP-712 signing digest derived from the order
    function isValidSignature(
        bytes32 orderDigest,
        bytes calldata
    ) external view override returns (bytes4) {
        require(
            ConditionalOrder(this).getTradeableOrder().hash(domainSeparator) ==
                orderDigest,
            "encoded order != tradable order"
        );

        return GPv2EIP1271.MAGICVALUE;
    }
}
