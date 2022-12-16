import { ActionFn, BlockEvent, Context, Event } from "@tenderly/actions";

import axios from "axios";
import { OrderKind } from "@cowprotocol/contracts";
import { ethers } from "ethers";
import { abi } from "./artifacts/ConditionalOrder.json";
import { Registry } from "./register";

export const checkForAndPlaceOrder: ActionFn = async (
  context: Context,
  event: Event
) => {
  const blockEvent = event as BlockEvent;
  const registry = await Registry.load(context, blockEvent.network);
  const chainContext = await ChainContext.create(context, blockEvent.network);
  for (const contract_address of registry.contracts) {
    console.log(`Checking ${contract_address}`);
    const contract = new ethers.Contract(
      contract_address,
      abi,
      chainContext.provider
    );
    try {
      const order = await contract.getTradeableOrder();
      const signature = contract.interface.encodeFunctionResult(
        "getTradeableOrder()",
        [Array.from(order)]
      );
      console.log(`Placing Order: ${order}`);
      await placeOrder(
        { ...order, from: contract_address, signature },
        chainContext.api_url
      );
    } catch (e) {
      console.log(`Not tradeable (${e})`);
    }
  }
};

async function placeOrder(order: any, api_url: string) {
  try {
    const { data } = await axios.post(
      `${api_url}/api/v1/orders`,
      {
        sellToken: order.sellToken,
        buyToken: order.buyToken,
        receiver: order.receiver,
        sellAmount: order.sellAmount.toString(),
        buyAmount: order.buyAmount.toString(),
        validTo: order.validTo,
        appData: order.appData,
        feeAmount: order.feeAmount.toString(),
        kind: orderKind(order),
        partiallyFillable: order.partiallyFillable,
        signature: order.signature,
        signingScheme: "eip1271",
        from: order.from,
      },
      {
        headers: {
          "Content-Type": "application/json",
          accept: "application/json",
        },
      }
    );
    console.log(`API response: ${data}`);
  } catch (error: any) {
    if (error.response) {
      // The request was made and the server responded with a status code
      // that falls out of the range of 2xx
      console.log(error.response.status);
      console.log(error.response.data);
    } else if (error.request) {
      // The request was made but no response was received
      // `error.request` is an instance of XMLHttpRequest in the browser and an instance of
      // http.ClientRequest in node.js
      console.log(error.request);
    } else if (error.message) {
      // Something happened in setting up the request that triggered an Error
      console.log("Error", error.message);
    } else {
      console.log(error);
    }
  }
}

function orderKind(order: any): OrderKind {
  for (const kind of [OrderKind.BUY, OrderKind.SELL]) {
    if (order.kind == ethers.utils.id(kind)) {
      return kind;
    }
  }
  throw "Unexpected order kind";
}

class ChainContext {
  provider: ethers.providers.Provider;
  api_url: string;

  constructor(provider: ethers.providers.Provider, api_url: string) {
    this.provider = provider;
    this.api_url = api_url;
  }

  public static async create(
    context: Context,
    network: string
  ): Promise<ChainContext> {
    const node_url = await context.secrets.get(`NODE_URL_${network}`);
    const provider = new ethers.providers.JsonRpcProvider(node_url);
    return new ChainContext(provider, apiUrl(network));
  }
}

function apiUrl(network: string): string {
  switch (network) {
    case "1":
      return "https://barn.api.cow.fi/mainnet";
    case "5":
      return "https://barn.api.cow.fi/goerli";
    case "100":
      return "https://barn.api.cow.fi/xdai";
    default:
      throw "Unsupported network";
  }
}
