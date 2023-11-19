> [!IMPORTANT]
> _This repository has been deprecated in favour of https://github.com/cowprotocol/composable-cow_

# Conditional Smart Orders

Repository to showcase how to implement autonomous trading agents in the form of smart contracts that would like to place orders based on some observable on chain condition (e.g. token balance, oracle price, etc).

This repository defined a common interface (`ConditionalOrder`) that all smart order contracts under this framework should follow. There are three main expectations

1. Smart Order contracts emit an `ConditionalOrderCreated` event upon creation allowing for some backend infrastructure to index and monitor them.
2. Whenever the contract would like to make a trade, `getTradeableOrder()` should return the CoW Protocol order data so that the monitoring tool can place an order in the backend accordingly.
3. Smart orders implement ERC1271 to "validate" the placed CoW Protocol orders (`isValidSignature(digest, signature)`). Digest will be the typed EIP712 hash of the order data, signature will be the abi-encoded pre-image of the digest, in other words the data that `getTradeableOrder()` returned in the first place.

***Note**: The contracts in this repository may not have been properly audited and could contain logic errors. Use at your own risk.*

## Requirements

- [Foundry](https://github.com/foundry-rs/foundry)
- node (v16.18.0)
- yarn
- npm
- [Tenderly](https://docs.tenderly.co/monitoring/integrations#installing-on-macos)[^1]
- node[^1]

[^1]: only when touching Web3 actions

## Deployed Contracts

Some of the contracts have been pre-deployed at the following addresses:

| Contract Name | Mainnet | Gnosis Chain | Goerli |
| --- | --- | --- | --- |
| TradeAboveThresholdFactory | [0xe608f868d95156b4df28f001a8d926df57c44054](https://etherscan.io/address/0xe608f868d95156b4df28f001a8d926df57c44054) | [0xd20a99e3c6c103108d74e241908e00ef4db447fb](https://gnosisscan.io/address/0xd20a99e3c6c103108d74e241908e00ef4db447fb) | [0x0362cb0892c3410d9beac1bc774fc2edb1b026b0](https://goerli.etherscan.io/address/0x0362cb0892c3410d9beac1bc774fc2edb1b026b0) |
| PerpetualStableSwapFactory | [0x2441c4ee592c29d2b1ed86aa9b3bbd6dadfee02b](https://etherscan.io/address/0x2441c4ee592c29d2b1ed86aa9b3bbd6dadfee02b) |  [0x46567d9749f435A8cE413BA92B6B1b3E90008a2e](https://gnosisscan.io/address/0x46567d9749f435A8cE413BA92B6B1b3E90008a2e) | [0xE608F868d95156B4df28F001A8D926Df57c44054](https://goerli.etherscan.io/address/0xE608F868d95156B4df28F001A8D926Df57c44054) |

## How to build/deploy an existing order type

The repository comes with one example contracts:

- **TradeAboveThreshold:** Checks the contract's balance of a specific token and - if larger than a threshold - wants to trade all of it into a specified buy token.
- **PerpetualStableSwap:** Takes a token pair and is always willing to trade the token it has more balance of for the other one at a rate 1:1 + a specified spread.

Check `src/` for a full list and implementation details. In order to deploy one of the contracts for your own use case, execute the following steps:

1. `forge build`
2. `export PRIVATE_KEY=<...>`
3. `export ETH_RPC_URL=<...>` (this will decide what network you deploy on)
4. `forge create <ContractName> --private-key $PRIVATE_KEY --verify --constructor-args <constructor args>` (please refer to implementation for constructor arguments)

The deployed contract should automatically be picked up by a watchdog and - once it returns a tradable order - find itself automatically placing this order. The status of placed orders by this contract can be observed on https://explorer.cow.fi/.

### Debugging in case an order doesn't get created

You can simulate the outcome of the watchdog locally by running

```
yarn check-deployment <deployed contract address>
```

This will give you the response of a single run of the watchdog (it will also create an order if possible). If this script passes, but you still don't see orders being placed automatically, please contact us.

## Using Smart Orders with your (Gnosis) Safe

In order to keep the smart order logic minimal and not worry about funding, withdrawing, updating ownership of the smart order, it can be beneficial to use a [Safe Contract](https://app.safe.global/) as the main trading contract.

Safes allow for a custom "fallback handler" that is used to verify signatures and can be used to implement arbitrary ERC1271 logic, such as the one implemented by our conditional orders for CoW Protocol trade verification.

The Safe contracts have been battle tested and come with fully configurable custody access, ownership management, etc. out of the box. We recommend using a fresh Safe for each order as changing the fallback handler can have an impact on other use cases that the Safe requires ERC1271 signatures for (this could be solved by using a "fallback handler chain" which goes beyond the scope of this document).

Order types that support being used with Safe should come with a factory contract that allows creating new instances via the transaction builder in the Safe UI (rather than requiring command line interactions).

To deploy, e.g. a `TradeAboveThreshold` smart order safe, do the following:

1. Create a new Safe
2. Set allowance on CoW Swap for the token you are looking to sell (e.g. via the CoW Swap Safe App)
3. Using the transaction builder, call the `TradeAboveThresholdFactory` (may have to be deployed) to create a custom `TradeAboveThreshold` instance using your Safe address as the target (remaining parameters according to your use case)
4. Once the `TradeAboveThreshold` is created, use the transaction builder to create another transaction, this time on your Safe itself, to `setFallbackHandler` to the address of the newly created `TradeAboveThreshold` instance.

Once the Safe meets the condition to trade, an order on its behalf should be automatically placed.


## Writing your own Smart Order

You are more than welcome to create new order types. For this simply create a new smart contract implementation in the `src/` folder (with an accompanying test contract in `/test`) and start hacking. 

Your contract should inherit from `ConditionalOrder` and `EIP1271Verifier`. This ensures you are implementing the correct methods. If you want your contract to be picked up by a watchdog, don't forget to emit the `ConditionalOrderCreated` even in the constructor.

Look at other example contracts for help/inspiration. To test your contract and make sure they comply with our style-guides please run:
1. `forge test`
2. `yarn fmt`

Once created, you can deploy your own smart orders just like existing order types as described 👆

## Deploying Tenderly Actions

This is only needed if you want to operate your own watchdog. In this case, please consider using a different trigger event, to avoid other watchdogs from monitoring the same contract. You also may have the project name if you are not part of the gp-v2 organisation.

When making changes to the tenderly actions, a good way to test them locally is by writing a [test script](https://docs.tenderly.co/web3-actions/references/local-development-and-testing).

Once ready to deploy, run

```
tenderly actions deploy
```
