import assert from "node:assert/strict";
import test from "node:test";
import { mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import {
  Credential,
  ProcessRef,
  ResourceRef,
  ReadFailed,
  IncompatibleNative,
} from "@transit/client";
import { Client, Compiled, Connection, Prepared, Reference, Uncertain } from "./mutations.ts";
import contract from "./contract.json" with { type: "json" };

const connection = new Connection(new ProcessRef(1, 2), new ResourceRef(1, 3), 4);
test("mutation values own mutable input and protect saved text", () => {
  const bytes = new Uint8Array(72).fill(7);
  const ref = new Reference(bytes);
  const value = new Compiled(bytes, ref);
  bytes.fill(0);
  ref.data.fill(0);
  value.request.fill(0);
  assert.equal(ref.data[0], 7);
  assert.equal(value.request[0], 7);
  assert.throws(() => new Prepared("\ud800"));
  assert.throws(() => new Connection(new ProcessRef(2, 2), connection.resource, 4));
});

// Exercise the real port/schema boundary with invalid successful host responses.
for (const response of [
  { receipt: { position: 0 } },
  { receipt: { position: 1.5 } },
  { prepared: "unexpected" },
]) {
  test(`unconfirmed mutation receipt preserves recovery: ${JSON.stringify(response)}`, async () => {
    await withHost(response, async (client) => {
      const saved = new Prepared('{"opaque":"keep exact spacing"}');
      await assert.rejects(
        client.submit(saved),
        (error) => error instanceof Uncertain && error.prepared === saved,
      );
    });
  });
}
test("runtime schema rejects a foreign mutation phase", async () => {
  const reference = new Reference(new Uint8Array(72));
  await withHost(
    {
      status: {
        reference: "00".repeat(72),
        principal: 9,
        table: 4,
        declaration: "00".repeat(32),
        policy_revision: "1",
        phase: "complete",
        affected_rows: 1,
        reason: "none",
        input: 1,
      },
    },
    async (client) => {
      await assert.rejects(client.status(reference), ReadFailed);
    },
  );
});
for (const definition of [null, "0".repeat(64)]) {
  test(`same v1 label cannot admit a ${definition === null ? "missing" : "foreign"} definition`, async () => {
    await assert.rejects(
      withHost(
        {},
        async () => {
          assert.fail("Incompatible client opened");
        },
        definition,
      ),
      IncompatibleNative,
    );
  });
}
async function withHost(
  response: object,
  run: (client: Client) => Promise<void>,
  definition: string | null = contract.definition,
): Promise<void> {
  const directory = await mkdtemp(join(tmpdir(), "transit-mutation-boundary-"));
  const host = join(directory, "host.mjs");
  await writeFile(
    host,
    `#!${process.execPath}
import { createInterface } from 'node:readline';
for await (const line of createInterface({ input:process.stdin })) {
  const action=JSON.parse(line);
  let value;
  if ('hello' in action) value={host_version:1,station_version:1,transit_version:1};
  else if ('growing_capabilities' in action) value=${JSON.stringify(definition === null ? {} : { definition })};
  else if ('shutdown' in action) { console.log(JSON.stringify({status:0,value:{}})); break; }
  else if ('capabilities' in action.table_mutation) value={capabilities:{version:1,max_rows:3,max_request_bytes:799,max_saved_bytes:8192,insert:true,update_primary_key:true,delete_primary_key:true}};
  else value=${JSON.stringify(response)};
  console.log(JSON.stringify({status:0,value}));
}
`,
    { mode: 0o700 },
  );
  try {
    const client = await Client.open(
      { url: "http://127.0.0.1:1", profile: "native_v1", nativeHost: host },
      new Credential(1, 9, "unused.seed"),
      connection,
    );
    try {
      await run(client);
    } finally {
      await client.close();
    }
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
}
