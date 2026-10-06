import assert from "node:assert/strict";
import test from "node:test";
import { mkdtemp, rm, writeFile, readFile } from "node:fs/promises";
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
  Basis,
  Identity,
  SavedIntent,
  Prepared,
  Policy,
  PolicyChange,
  Cursor,
  Page,
  Uncertain,
} from "./catalog.ts";
import {
  encodeType,
  decodeType,
  encodeAtom,
  decodeAtom,
  encodeCell,
  decodeCell,
} from "./logical-values.ts";
import type { Descriptor, Cell, Atom } from "./logical-values.ts";
import contract from "./contract.json" with { type: "json" };

const maximum = (1n << 64n) - 1n;
const scope = new Scope(new ResourceRef(1, 3), maximum);
const connection = new Connection(new ProcessRef(1, 2), scope);
const ids = new Identity(maximum, maximum - 1n);
const nativeScope = { realm: 1, resource: 3, catalog: maximum.toString() };
const rights = {
  inspect: true,
  create: true,
  read: false,
  insert: false,
  update: false,
  delete: false,
  alter: false,
  drop: false,
};
const metadata = {
  scope: nativeScope,
  object: "17",
  revision: "3",
  name: "東京 people",
  schema_fingerprint: "ab".repeat(32),
  principal: 9,
  operation: maximum.toString(),
  admitted_input: 2,
};
const head = { revision: "4", rows: maximum.toString(), pending: "0" };
const wireSchema = {
  definition: contract.definition,
  object: "17",
  revision: "2",
  next_column: "3",
  columns: [
    {
      id: "1",
      name: "id",
      type: { uint128: {} },
      nullable: false,
      default: null,
      max_characters: null,
    },
    {
      id: "2",
      name: "payload",
      type: { list: { type: { binary: {} }, nullable: true } },
      nullable: true,
      default: null,
      max_characters: null,
    },
  ],
  primary_key: ["1"],
};
const entry = { metadata, head };
const page = {
  resource_revision: 3,
  entries: [entry, ...Array(7).fill(null)],
  next: {
    definition: contract.definition,
    scope: nativeScope,
    resource_revision: 3,
    after_object: "19",
  },
};
const compiled = {
  intent: {
    reference: { definition: contract.definition, digest: "cd".repeat(32) },
    scope: nativeScope,
    owner: 2,
    principal: 9,
    operation: maximum.toString(),
    namespace: (maximum - 1n).toString(),
    object: "17",
    kind: "create",
  },
  saved: { definition: contract.definition, bytes: "010203" },
};

test("catalog values own schemas, bytes and every independent right", () => {
  const bytes = new Uint8Array([1, 2]);
  const column = {
    id: 2n,
    name: "binary",
    type: { kind: "binary" } as const,
    default: {
      state: "value",
      value: { kind: "atom", atom: { kind: "binary", value: bytes } },
    } as const,
  };
  const schema = new Schema(
    maximum,
    1n,
    3n,
    [{ id: 1n, name: "id", type: { kind: "int32" }, nullable: false }, column],
    [1n],
  );
  bytes.fill(0);
  column.name = "changed";
  assert.equal(schema.columns[1]?.name, "binary");
  assert.deepEqual(schema.columns[1]?.default, {
    state: "value",
    value: { kind: "atom", atom: { kind: "binary", value: new Uint8Array([1, 2]) } },
  });
  assert.equal(schema.objectId, maximum);
  const saved = new SavedIntent(contract.definition, new Uint8Array([1, 2]));
  saved.bytes.fill(0);
  assert.deepEqual(saved.bytes, new Uint8Array([1, 2]));
  const policy = new Policy(scope, 0, maximum, rights);
  rights.read = true;
  assert.equal(policy.rights.read, false);
  rights.read = false;
  assert.equal(new PolicyChange(maximum - 1n, policy).expectedRevision, maximum - 1n);
  assert.throws(() => new PolicyChange(maximum, policy));
  assert.throws(() => new Scope(scope.resource, 1 as unknown as bigint));
  assert.throws(() => new Scope(scope.resource, 1n << 64n));
  assert.throws(() => new Connection(new ProcessRef(2, 2), scope));
  assert.throws(() => new Prepared("\ud800"));
  assert.throws(() => new SavedIntent("0".repeat(64), new Uint8Array([1])));
});

test("native logical values preserve wide numbers, signed zero and nested states", () => {
  const atoms: Atom[] = [
    { kind: "unsigned", value: (1n << 128n) - 1n },
    { kind: "signed", value: -(1n << 127n) },
    { kind: "decimal", value: -123456789012345678901234567890n },
    { kind: "float", width: 32, value: -0 },
    { kind: "float", width: 64, value: 1.25 },
    { kind: "date_days", value: -719162n },
    { kind: "time_nanos", value: 1n },
    { kind: "timestamp_micros", value: -10n },
    { kind: "interval", months: -12n, days: 3n, nanos: -99n },
    { kind: "boolean", value: true },
    { kind: "utf8", value: "東京" },
    { kind: "binary", value: new Uint8Array([0, 255]) },
    { kind: "uuid", value: new Uint8Array(16) },
  ];
  for (const atom of atoms) assert.deepEqual(decodeAtom(encodeAtom(atom)), atom);
  const cell: Cell = {
    state: "value",
    value: {
      kind: "map",
      entries: [
        {
          key: { kind: "utf8", value: "a" },
          value: {
            state: "value",
            value: {
              kind: "list",
              cells: [
                { state: "null" },
                { state: "value", value: { kind: "atom", atom: atoms[0]! } },
              ],
            },
          },
        },
      ],
    },
  };
  assert.deepEqual(decodeCell(encodeCell(cell)), cell);
  const descriptor: Descriptor = {
    kind: "array",
    length: 3,
    element: {
      nullable: true,
      type: {
        kind: "structure",
        fields: [
          {
            name: "id",
            type: { kind: "decimal", precision: 38, scale: 2 },
            nullable: false,
            optional: false,
          },
        ],
      },
    },
  };
  assert.deepEqual(decodeType(encodeType(descriptor)), descriptor);
  assert.throws(() => encodeAtom({ kind: "float", width: 32, value: 1e99 }));
  assert.throws(() => encodeAtom({ kind: "signed", value: 1 as unknown as bigint }));
  assert.throws(() => decodeAtom({ signed: "01" }));
  const recursive: Descriptor = { kind: "list", element: { type: { kind: "int64" } } };
  Object.assign(recursive.element, { type: recursive });
  assert.throws(() => encodeType(recursive), /nesting/);
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
test("generated schema rejects an invented observation", async () => {
  await withHost({ observation: "cancelled" }, async (client) => {
    await assert.rejects(client.observe(new Prepared("saved"), 1), ReadFailed);
  });
});
for (const revision of ["01", "+1", "18446744073709551616"]) {
  test(`response rejects noncanonical revision ${revision}`, async () => {
    await withHost(
      {
        description: {
          configuration: {
            scope: nativeScope,
            owner: 2,
            administrator: 9,
            table_limits: { record_bytes: 2097152, staging_bytes: "4194304", staging_records: 196 },
          },
          policy: { scope: nativeScope, principal: 9, revision, ...rights },
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
  test(`rejects missing or foreign native definition ${definition}`, async () => {
    await assert.rejects(
      withHost({}, async () => assert.fail("Incompatible catalog opened"), definition),
      IncompatibleNative,
    );
  });
}
test("metadata owns general schema and validates the requested identity", async () => {
  await withHost({ definition: { ...entry, schema: wireSchema } }, async (client) => {
    const value = await client.lookup(metadata.name);
    assert.ok(value);
    assert.equal(value.metadata.objectId, 17n);
    assert.equal(value.schema.revision, 2n);
    assert.equal(value.head.rows, maximum);
    assert.deepEqual(value.schema.primaryKey, [1n]);
    assert.equal(value.schema.columns[1]?.type.kind, "list");
    assert.equal(value.metadata.basis.schemaFingerprint, metadata.schema_fingerprint);
    await assert.rejects(client.lookup("other"), IncompatibleNative);
  });
  await withHost({ definition: null }, async (client) =>
    assert.equal(await client.lookup("absent"), undefined),
  );
});
test("historical definitions bind exact identities without inventing a live head", async () => {
  await withHost({ historical: { metadata, schema: wireSchema } }, async (client) => {
    const value = await client.definition(17n, 3n);
    assert.ok(value);
    assert.equal(value.metadata.revision, 3n);
    assert.equal(value.schema.revision, 2n);
    assert.equal("head" in value, false);
    await assert.rejects(client.definition(18n, 3n), IncompatibleNative);
    await assert.rejects(client.definition(17n, 4n), IncompatibleNative);
  });
  await withHost({ historical: null }, async (client) =>
    assert.equal(await client.definition(17n, 99n), undefined),
  );
});
test("historical definitions reject foreign scope and schema attribution", async () => {
  await withHost(
    {
      historical: {
        metadata: { ...metadata, scope: { ...nativeScope, catalog: "1" } },
        schema: wireSchema,
      },
    },
    async (client) => assert.rejects(client.definition(17n, 3n), IncompatibleNative),
  );
  await withHost(
    { historical: { metadata, schema: { ...wireSchema, object: "18" } } },
    async (client) => assert.rejects(client.definition(17n, 3n), IncompatibleNative),
  );
  await withHost({ historical: { metadata, schema: wireSchema, head } }, async (client) =>
    assert.rejects(client.definition(17n, 3n), ReadFailed),
  );
});
test("metadata pagination allows retired objects and empty continuing pages", async () => {
  await withHost({ page }, async (client) => {
    const value = await client.list();
    assert.equal(value.entries.length, 1);
    assert.equal(value.next?.afterObject, 19n);
    const entries = [...value.entries];
    const copy = new Page(value.resourceRevision, entries, value.next);
    entries.length = 0;
    assert.equal(copy.entries.length, 1);
    await assert.rejects(client.list(value.next), IncompatibleNative);
  });
  await withHost({ page: { ...page, entries: Array(8).fill(null) } }, async (client) => {
    const previous = new Cursor(contract.definition, scope, 3, 18n);
    assert.equal((await client.list(previous)).next?.afterObject, 19n);
    await assert.rejects(
      client.list(new Cursor(contract.definition, scope, 2, 18n)),
      IncompatibleNative,
    );
  });
});
for (const defect of [
  "hole",
  "order",
  "scope",
  "cut",
  "before_object",
  "missing_definition",
  "foreign_definition",
  "numeric_object",
]) {
  test(`metadata rejects malformed page ${defect}`, async () => {
    const bad = structuredClone(page);
    if (defect === "hole") [bad.entries[1], bad.entries[0]] = [bad.entries[0], null];
    else if (defect === "order") bad.entries[1] = structuredClone(entry);
    else if (defect === "scope") bad.entries[0].metadata.scope.catalog = "1";
    else if (defect === "cut") bad.next.resource_revision++;
    else if (defect === "before_object") bad.next.after_object = "1";
    else if (defect === "missing_definition") Reflect.deleteProperty(bad.next, "definition");
    else if (defect === "foreign_definition") bad.next.definition = "0".repeat(64);
    else bad.entries[0].metadata.object = 1;
    await withHost({ page: bad }, async (client) => {
      await assert.rejects(
        client.list(),
        (error) => error instanceof IncompatibleNative || error instanceof ReadFailed,
      );
    });
  });
}
test("typed nested input uses exact bigint and binary wire values", async () => {
  await withHost({ compiled }, async (client, requests) => {
    const columns = [
      {
        id: 1n,
        name: "value",
        type: { kind: "uint128" } as const,
        default: {
          state: "value",
          value: { kind: "atom", atom: { kind: "unsigned", value: (1n << 128n) - 1n } },
        } as const,
      },
    ];
    const result = await client.prepare("people", ids, {
      kind: "create",
      schema: new Schema(17n, 1n, 2n, columns),
    });
    assert.equal(result.intent.identity.operation, maximum);
    const last = (await requests()).at(-1) as {
      catalog: { prepare: { action: { create: { schema: typeof wireSchema } } } };
    };
    assert.deepEqual(last.catalog.prepare.action.create.schema.columns[0]?.default, {
      value: { atom: { unsigned: ((1n << 128n) - 1n).toString() } },
    });
    assert.deepEqual(result.saved.bytes, new Uint8Array([1, 2, 3]));
  });
});
test("catalog framing carries fragmented intent responses above the raw-client bound", async () => {
  const large = structuredClone(compiled);
  large.saved.bytes = "ab".repeat(600000);
  await withHost(
    { compiled: large },
    async (client) => {
      const result = await client.compileSql("CREATE TABLE people (value INTEGER)", ids, 17n);
      assert.equal(result.saved.bytes.length, 600000);
    },
    contract.definition,
    true,
  );
});
test("loading preserves saved bytes without SQL reconstruction", async () => {
  await withHost({ loaded: compiled.intent }, async (client, requests) => {
    const saved = new SavedIntent(contract.definition, new Uint8Array([0, 255, 4]));
    const result = await client.load(saved);
    assert.equal(result.objectId, 17n);
    assert.deepEqual((await requests()).at(-1), {
      catalog: { load: { definition: contract.definition, bytes: "00ff04" } },
    });
  });
});
test("typed binary requests exceed the raw profile bound without losing their byte value", async () => {
  const reply = structuredClone(compiled);
  reply.intent.kind = "insert";
  await withHost({ compiled: reply }, async (client, requests) => {
    const bytes = new Uint8Array(300 * 1024).fill(255);
    await client.prepare("people", ids, {
      kind: "mutate",
      basis: new Basis(17n, 3n, metadata.schema_fingerprint),
      mutation: {
        kind: "insert",
        rows: [
          [
            {
              column: 2n,
              value: {
                state: "value",
                value: { kind: "atom", atom: { kind: "binary", value: bytes } },
              },
            },
          ],
        ],
      },
    });
    const request = JSON.stringify((await requests()).at(-1));
    assert.ok(Buffer.byteLength(request) > 540672);
    assert.ok(request.includes('"binary":"' + "ff".repeat(bytes.length) + '"'));
  });
});
for (const defect of ["principal", "kind", "object", "operation", "namespace"]) {
  test(`compiled typed intent rejects foreign ${defect}`, async () => {
    const reply = structuredClone(compiled);
    if (defect === "principal") reply.intent.principal = 18;
    else if (defect === "kind") reply.intent.kind = "drop";
    else if (defect === "object") reply.intent.object = "18";
    else if (defect === "operation") reply.intent.operation = "18";
    else reply.intent.namespace = "18";
    await withHost({ compiled: reply }, async (client) => {
      await assert.rejects(
        client.prepare("people", ids, {
          kind: "create",
          schema: new Schema(17n, 1n, 2n, [{ id: 1n, name: "value", type: { kind: "int64" } }]),
        }),
        IncompatibleNative,
      );
    });
  });
}
async function withHost(
  response: object,
  run: (client: Client, requests: () => Promise<unknown[]>) => Promise<void>,
  definition: string | null = contract.definition,
  fragment = false,
): Promise<void> {
  const directory = await mkdtemp(join(tmpdir(), "transit-catalog-boundary-"));
  const host = join(directory, "host.mjs"),
    log = join(directory, "requests.jsonl");
  await writeFile(
    host,
    `#!${process.execPath}
import { createInterface } from 'node:readline';
import { appendFileSync } from 'node:fs';
for await (const line of createInterface({input:process.stdin})) {
  appendFileSync(${JSON.stringify(log)}, line+'\\n');
  const action=JSON.parse(line); let value;
  if ('hello' in action) value={host_version:1,station_version:1,transit_version:1};
  else if ('growing_capabilities' in action) value=${JSON.stringify(definition === null ? {} : { definition })};
  else if ('capabilities' in action.catalog) value={capabilities:{version:1,definition:${JSON.stringify(contract.definition)},max_columns:128,max_rows:1024,max_sql_bytes:4096,max_intent_bytes:${contract.limits.catalog_intent_bytes},max_action_bytes:${contract.limits.catalog_action_bytes},max_prepared_bytes:8192,resident_intents:1}};
  else value=${JSON.stringify(response)};
  const result=JSON.stringify({status:0,value})+'\\n';
  if (${fragment}) { for(let i=0;i<result.length;i+=1021) { await new Promise(resolve=>process.stdout.write(result.slice(i,i+1021),resolve)); } }
  else console.log(result.trimEnd());
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
      await run(client, async () =>
        (await readFile(log, "utf8"))
          .trim()
          .split("\n")
          .map((line) => JSON.parse(line)),
      );
    } finally {
      await client.close();
    }
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
}
