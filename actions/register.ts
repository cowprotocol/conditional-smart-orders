import {
  ActionFn,
  Context,
  Event,
  TransactionEvent,
  Storage,
} from "@tenderly/actions";

import { ethers } from "ethers";
import { abi } from "./artifacts/ConditionalOrder.json";

export const addContract: ActionFn = async (context: Context, event: Event) => {
  const transactionEvent = event as TransactionEvent;
  const iface = new ethers.utils.Interface(abi);

  const registry = await Registry.load(context, transactionEvent.network);
  console.log(`Current registry: ${JSON.stringify(registry.contracts)}`);

  transactionEvent.logs.forEach((log) => {
    if (log.topics[0] === iface.getEventTopic("ConditionalOrderCreated")) {
      const contract = iface.decodeEventLog("ConditionalOrderCreated", log.data, log.topics)[0]
      if (
        registry.contracts.find((existing: string) => existing == contract) ===
        undefined
      ) {
        registry.contracts.push(contract);
        console.log(`adding contract ${contract}`);
      }
    }
  });
  console.log(`Updated registry: ${JSON.stringify(registry.contracts)}`);
  await registry.write();
};

export const storageKey = (network: string): string => {
  return `CONDITIONAL_ORDER_REGISTRY_${network}`;
};

export class Registry {
  contracts: string[];
  storage: Storage;
  network: string;

  constructor(contracts: string[], storage: Storage, network: string) {
    this.contracts = contracts;
    this.storage = storage;
    this.network = network;
  }

  public static async load(
    context: Context,
    network: string
  ): Promise<Registry> {
    const registry = await context.storage.getJson(storageKey(network));
    return new Registry(registry.contracts || [], context.storage, network);
  }

  public async write() {
    await this.storage.putJson(storageKey(this.network), {
      contracts: this.contracts,
    });
  }
}
