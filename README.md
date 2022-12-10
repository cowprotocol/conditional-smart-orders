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

## How to build/deploy an existing order type

The repository comes with one example contracts:

- **TradeAboveThreshold:** Checks the contract's balance of a specific token and - if larger than a threshold - wants to trade all of it into a specified buy token.

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
