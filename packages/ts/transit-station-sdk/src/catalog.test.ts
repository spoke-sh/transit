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
import {
  Client,
  Scope,
  Connection,
  Schema,
  CreateTable,
  Compiled,
  Prepared,
  Policy,
  Cursor,
  Page,
  Uncertain,
} from "./catalog.ts";
import contract from "./contract.json" with { type: "json" };

const maximum = (1n << 64n) - 1n;
const scope = new Scope(new ResourceRef(1, 3), maximum);
const connection = new Connection(new ProcessRef(1, 2), scope);
const request = new CreateTable(
  scope,
  maximum,
  maximum,
  4,
  "items",
  new Schema(["id", "value"], "utf8"),
);
test("catalog values retain bigint identity and own names and canonical bytes", () => {
  const names: [string, string] = ["id", "value"];
  const schema = new Schema(names, "utf8");
  names[0] = "changed";
  assert.deepEqual(schema.names, ["id", "value"]);
  assert.ok(Object.isFrozen(schema.names));
  const bytes = new Uint8Array([1, 2]);
  const compiled = new Compiled(request, bytes);
  bytes.fill(0);
  compiled.canonical.fill(0);
  assert.deepEqual(compiled.canonical, new Uint8Array([1, 2]));
  assert.equal(compiled.request.objectId, maximum);
  assert.equal(new Policy(scope, 0, maximum, true, false).revision, maximum);
  assert.throws(() => new Scope(scope.resource, 1 as unknown as bigint));
  assert.throws(() => new Scope(scope.resource, 1n << 64n));
  assert.throws(() => new Connection(new ProcessRef(2, 2), scope));
  assert.throws(() => new Prepared("\ud800"));
});
for (const response of [
  { receipt: { position: 0 } },
  { receipt: { position: 1.5 } },
  { receipt: { position: "1" } },
  { prepared: "unexpected" },
]) {
  test(`unconfirmed catalog response retains exact prepared text: ${JSON.stringify(response)}`, async () => {
    await withHost(response, async (client) => {
      const prepared = new Prepared('{"opaque":"keep exact spacing"}');
      await assert.rejects(
        client.submit(prepared),
        (error) => error instanceof Uncertain && error.prepared === prepared,
      );
    });
  });
}
test("catalog generated schema rejects unknown outcomes", async () => {
  await withHost({ observation: "cancelled" }, async (client) => {
    await assert.rejects(client.observe(new Prepared("saved"), 1), ReadFailed);
  });
});
for (const revision of ["01", "+1", "18446744073709551616"]) {
  test(`catalog response rejects noncanonical revision ${revision}`, async () => {
    const nativeScope = { realm: 1, resource: 3, catalog: maximum.toString() };
    await withHost(
      {
        description: {
          configuration: { scope: nativeScope, owner: 2, administrator: 9 },
          policy: { scope: nativeScope, principal: 9, revision, inspect: true, create: false },
          resource_revision: 2,
        },
      },
      async (client) => {
        await assert.rejects(client.describe(), IncompatibleNative);
      },
    );
  });
}
for (const definition of [null, "0".repeat(64)]) {
  test(`catalog rejects missing or foreign native definition ${definition}`, async () => {
    await assert.rejects(
      withHost({}, async () => assert.fail("Incompatible catalog opened"), definition),
      IncompatibleNative,
    );
  });
}
const metadata = {
  scope: { realm: 1, resource: 3, catalog: maximum.toString() },
  object: maximum.toString(),
  revision: maximum.toString(),
  name: "items",
  source: { table: { id: 0xffffffff, schema: { names: ["id", "value"], value_type: "utf8" } } },
  principal: 9,
  operation: maximum.toString(),
  input: 2,
};
const page = {
  resource_revision: 3,
  entries: [metadata, ...Array(7).fill(null)],
  next: {
    definition: contract.definition,
    scope: metadata.scope,
    resource_revision: 3,
    after: "items",
  },
};
test("metadata has owned full-width values and exact requested identity", async () => {
  await withHost({ definition: metadata }, async (client) => {
    const value = await client.lookup("items");
    assert.ok(value);
    assert.equal(value.objectId, maximum);
    assert.equal(value.revision, maximum);
    assert.equal(value.source.table, 0xffffffff);
    assert.ok(Object.isFrozen(value) && Object.isFrozen(value.source.schema.names));
    assert.deepEqual(await client.definition(maximum, maximum), value);
    await assert.rejects(client.lookup("other"), IncompatibleNative);
    await assert.rejects(client.definition(1n, 1n), IncompatibleNative);
  });
  await withHost({ definition: null }, async (client) => {
    assert.equal(await client.lookup("absent"), undefined);
    assert.equal(await client.definition(1n, 1n), undefined);
  });
});
test("metadata pages own dense entries and bind continuation", async () => {
  await withHost({ page }, async (client) => {
    const value = await client.list();
    assert.equal(value.entries.length, 1);
    assert.equal(value.next?.after, "items");
    assert.ok(Object.isFrozen(value.entries) && Object.isFrozen(value.next));
    const entries = [...value.entries];
    const copy = new Page(value.resourceRevision, entries, value.next);
    entries.length = 0;
    assert.equal(copy.entries.length, 1);
    await assert.rejects(client.list(value.next), IncompatibleNative);
  });
  await withHost(
    { page: { resource_revision: 3, entries: Array(8).fill(null), next: null } },
    async (client) => {
      assert.deepEqual(
        (await client.list(new Cursor(contract.definition, scope, 3, "items"))).entries,
        [],
      );
      await assert.rejects(
        client.list(new Cursor(contract.definition, scope, 2, "items")),
        IncompatibleNative,
      );
    },
  );
});
for (const defect of [
  "hole",
  "order",
  "scope",
  "cut",
  "next_name",
  "missing_definition",
  "foreign_definition",
  "numeric_object",
  "unknown_source",
]) {
  test(`metadata rejects malformed page ${defect}`, async () => {
    const bad = structuredClone(page);
    if (defect === "hole") [bad.entries[1], bad.entries[0]] = [bad.entries[0], null];
    else if (defect === "order") bad.entries[1] = structuredClone(metadata);
    else if (defect === "scope") bad.entries[0].scope.catalog = "1";
    else if (defect === "cut") bad.next.resource_revision++;
    else if (defect === "next_name") bad.next.after = "other";
    else if (defect === "missing_definition") Reflect.deleteProperty(bad.next, "definition");
    else if (defect === "foreign_definition") bad.next.definition = "0".repeat(64);
    else if (defect === "numeric_object") bad.entries[0].object = 1;
    else bad.entries[0].source = { document: {} };
    await withHost({ page: bad }, async (client) => {
      await assert.rejects(
        client.list(),
        (error) => error instanceof IncompatibleNative || error instanceof ReadFailed,
      );
    });
  });
}
async function withHost(
  response: object,
  run: (client: Client) => Promise<void>,
  definition: string | null = contract.definition,
): Promise<void> {
  const directory = await mkdtemp(join(tmpdir(), "transit-catalog-boundary-"));
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
  else if ('capabilities' in action.catalog) value={capabilities:{version:1,definition:${JSON.stringify(contract.definition)},initialize:true,create_table:true,conditional_policy:true,current_metadata:true,max_saved_bytes:8192,table_columns:2}};
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
