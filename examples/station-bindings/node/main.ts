import { NativeHost } from "../../../packages/ts/transit-station/src/index.ts";

const [config, role, peerText] = process.argv.slice(2);
if (!config || !role || !peerText || !process.env.TRANSIT_HOST) throw new Error("Missing example configuration");
const peer = Number(peerText);
if (!Number.isSafeInteger(peer) || peer < 1) throw new Error("Invalid peer PID");
const host = await NativeHost.open(process.env.TRANSIT_HOST, config);
try {
  for (;;) {
    const event = await host.next();
    if (event.event === "committed") break;
    if (event.event === "idle" || event.event === "blocked") throw new Error(event.event);
    if (event.event !== "ready") continue;
    try {
      if (event.initializing) {
        await host.apply({ table_create: { id: 1, key_name: "id", value_name: "value", value_type: "int64" } });
        if (role === "service") {
          await host.apply({ query_policy: { peer, table: 1, expected_revision: 0, allow: true } });
          await host.apply({ table_write: { id: 1, mode: "insert", row: { key: "1", value: { int64: "9007199254740993" } } } });
        }
      }
      const input = event.input;
      if (!input) throw new Error("Missing input");
      if (input.payload === "696e6974") {}
      else if (input.kind === "cast") await host.apply({ call: { pid: peer, value: "7175657279" } });
      else if (input.kind === "call") await host.apply({ query_reply: { id: 1 } });
      else if (input.kind === "result_complete") {
        const result = await host.apply({ query_result: input.correlation });
        if (typeof result !== "object" || !("arrow" in result)) throw new Error("Missing Arrow IPC");
        const ipc = Buffer.from(result.arrow, "hex");
        const cell = await host.arrowCell(ipc, 0, 1);
        if (typeof cell.value !== "object" || !("int64" in cell.value) || BigInt(cell.value.int64) !== 9007199254740993n) throw new Error("Lost integer precision");
        await host.apply({ put: { key: "6f62736572766564", value: "39303037313939323534373430393933" } });
      } else throw new Error("Unexpected input");
      await host.finish();
    } catch (error) {
      try {
        await host.finish(true);
        if ((await host.next()).event !== "blocked") throw new Error("Failure was not recorded");
      } catch { /* A lost port cannot record a failure; preserve the original error. */ }
      throw error;
    }
  }
} finally {
  await host.close();
}
