import {
  TestTransactionEvent,
  TestLog,
  TestRuntime,
} from "@tenderly/actions-test";
import { assert } from "console";
import { addContract, storageKey } from "../register";

const main = async () => {
  const testRuntime = new TestRuntime();

  // https://gnosisscan.io/tx/0x9f20f13c80cf89604763ad0aed86bfd6f647e1ecd5da1921e7fe09ff3664a3ec#eventlog
  const alreadyIndexedLog = new TestLog();
  alreadyIndexedLog.address = "0x75748d1774e768370d67571d5ac954c3cf3114c2";
  alreadyIndexedLog.topics = [
    "0xa463d4c6494f3788b95f6cf2a5c8c1a63090dce890c49318a6f5f32dc51efcd1",
  ];

  const newLog = new TestLog();
  newLog.address = "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE";
  newLog.topics = [
    "0xa463d4c6494f3788b95f6cf2a5c8c1a63090dce890c49318a6f5f32dc51efcd1",
  ];

  const event = new TestTransactionEvent();
  event.logs.push(alreadyIndexedLog);
  event.logs.push(newLog);
  event.network = "mainnet";

  await testRuntime.context.storage.putJson(storageKey(event.network), {
    contracts: ["0x75748d1774e768370d67571d5ac954c3cf3114c2"],
  });

  await testRuntime.execute(addContract, event);

  const storage = await testRuntime.context.storage.getJson(
    storageKey(event.network)
  );
  console.log(storage);
  assert(
    storage.contracts.length == 2,
    "Incorrect amount of contracts indexed"
  );
  assert(
    storage.contracts[0] == "0x75748d1774e768370d67571d5ac954c3cf3114c2",
    "Missing already indexed contract"
  );
  assert(
    storage.contracts[1] == "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE",
    "Missing new contract"
  );
};

(async () => await main())();
