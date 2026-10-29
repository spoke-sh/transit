import assert from "node:assert/strict";
import test from "node:test";
import { mkdtemp, rm, writeFile, readFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { Credential, ResourceRef, ReadFailed, IncompatibleNative } from "@transit/client";
import {
  Client,
  Scope,
  Connection,
  Schema,
  Basis,
  Identity,
  SavedIntent,
  Reference,
  SnapshotOwner,
  SnapshotAcquisition,
  Snapshot,
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
test("logical cells preserve source-only mismatch kinds", () => {
  for (const actual of ["unknown", "null_value", "text", "character"] as const) {
    const cell: Cell = { state: "type_error", actual };
    assert.deepEqual(decodeCell(encodeCell(cell)), cell);
    const conflict: Cell = {
      state: "conflict",
      alternatives: [
        { counter: 1n, replica: (1n << 64n) - 1n, cell },
        { counter: (1n << 64n) - 1n, replica: 1n, cell: { state: "null" } },
      ],
    };
    assert.deepEqual(decodeCell(encodeCell(conflict)), conflict);
  }
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

test("logical conflicts, map children and aggregate budgets match native limits", () => {
  let deep: Cell = {
    state: "conflict",
    alternatives: [
      { counter: 1n, replica: 1n, cell: { state: "null" } },
      { counter: 1n, replica: 2n, cell: { state: "null" } },
    ],
  };
  for (let i = 0; i < 15; i++) deep = { state: "value", value: { kind: "list", cells: [deep] } };
  assert.deepEqual(decodeCell(encodeCell(deep)), deep);
  assert.throws(() => encodeCell({ state: "value", value: { kind: "list", cells: [deep] } }));
  assert.throws(() => decodeCell({ value: { list: [encodeCell(deep)] } }));
  for (const dots of [
    [],
    [[1n, 1n]],
    [
      [0n, 1n],
      [1n, 1n],
    ],
    [
      [1n, 1n],
      [1n, 1n],
    ],
    [
      [2n, 1n],
      [1n, 1n],
    ],
  ]) {
    assert.throws(() =>
      encodeCell({
        state: "conflict",
        alternatives: dots.map(([counter, replica]) => ({
          counter: counter!,
          replica: replica!,
          cell: { state: "null" },
        })),
      }),
    );
    assert.throws(() =>
      decodeCell({
        conflict: dots.map(([counter, replica]) => ({
          counter: counter!.toString(),
          replica: replica!.toString(),
          value: { null: {} },
        })),
      }),
    );
  }
  const entries = Array.from({ length: 32767 }, (_, i) => ({
    key: { kind: "signed" as const, value: BigInt(i) },
    value: { state: "null" as const },
  }));
  assert.doesNotThrow(() =>
    decodeCell(encodeCell({ state: "value", value: { kind: "map", entries } })),
  );
  assert.throws(() =>
    encodeCell({ state: "value", value: { kind: "map", entries: [...entries, entries[0]!] } }),
  );
  assert.throws(() =>
    decodeCell({
      value: {
        map: Array.from({ length: 32768 }, (_, i) => ({
          key: { signed: String(i) },
          value: { null: {} },
        })),
      },
    }),
  );
  const payload: Cell = {
    state: "value",
    value: { kind: "atom", atom: { kind: "binary", value: new Uint8Array(600000) } },
  };
  assert.throws(() =>
    encodeCell({ state: "value", value: { kind: "list", cells: [payload, payload] } }),
  );
  assert.throws(() =>
    decodeCell({
      value: {
        list: [
          { value: { atom: { utf8: "x".repeat(600000) } } },
          { value: { json: "x".repeat(600000) } },
        ],
      },
    }),
  );
  assert.throws(() =>
    decodeType({
      structure: Array.from({ length: 256 }, () => ({
        name: "x",
        type: { boolean: {} },
        nullable: false,
        optional: false,
      })),
    }),
  );
  assert.throws(() =>
    encodeType({
      kind: "structure",
      fields: Array.from({ length: 17 }, () => ({
        name: "x".repeat(255),
        type: { kind: "boolean" },
      })),
    }),
  );
});

const fixture = JSON.parse(
  await readFile(
    new URL(
      "../../../../packages/zig/transit-catalog/src/fixtures/direct-table-host-reference-v1.json",
      import.meta.url,
    ),
    "utf8",
  ),
);
const intentFixture = JSON.parse(
  await readFile(
    new URL(
      "../../../../packages/zig/transit-catalog/src/fixtures/direct-table-intent-v1.json",
      import.meta.url,
    ),
    "utf8",
  ),
);
const recovery = { table: fixture.host };
const saved = {
  table: {
    definition: contract.definition,
    namespace: 1,
    bytes: Buffer.from(intentFixture.base64, "base64").toString("hex"),
  },
};
const summary = {
  id: { definition: contract.definition, digest: "aa".repeat(32) },
  namespace: 1,
  binding: { table: fixture.host.binding },
};
const scope = new Scope(new ResourceRef(42, 3), maximum);
const connection = new Connection(scope, 5);
const ids = new Identity(maximum);
const stored = {
  interpretation: fixture.host.binding.expected_definition,
  content: fixture.host.content,
  schema_fingerprint: "bb".repeat(32),
  retired: false,
};
const preparedBasis = {
  definition: contract.definition,
  connection: fixture.host.connection,
  namespace: 1,
  name: "items",
  interpretation: stored,
};
const metadata = {
  binding: preparedBasis,
  authorization: 11,
  position: { partition: "9", next_lsn: "10" },
  changed_lsn: "10",
  row_count: maximum.toString(),
  schema: {
    definition: contract.definition,
    object: "7",
    revision: "2",
    next_column: "2",
    primary_key: [],
    columns: [
      {
        id: "1",
        name: "payload",
        type: { utf8: {} },
        nullable: true,
        default: null,
        max_characters: null,
        encoding: "ebcdic",
        collation: "ebcdic_cp037",
      },
    ],
  },
};

test("saved work, recovery and complete bases own exact full-width values", () => {
  const original = JSON.stringify(saved);
  const work = SavedIntent.restore(original);
  const ref = Reference.restore(JSON.stringify(recovery));
  const basis = Basis.restore(JSON.stringify(preparedBasis));
  assert.equal(work.save(), original);
  assert.equal(ref.operation, maximum);
  assert.equal(ref.namespace, 1);
  assert.equal(basis.definition.interpretation.object.scope.catalog, maximum);
  assert.deepEqual(JSON.parse(basis.save()), preparedBasis);
  for (const value of [saved, recovery]) {
    for (const key of ["definition", "namespace"]) {
      const missing = structuredClone(value);
      Reflect.deleteProperty(missing.table, key);
      assert.throws(
        () =>
          value === saved
            ? SavedIntent.restore(JSON.stringify(missing))
            : Reference.restore(JSON.stringify(missing)),
        IncompatibleNative,
      );
    }
  }
  const foreign = structuredClone(saved);
  foreign.table.definition = "00".repeat(32);
  assert.throws(() => SavedIntent.restore(JSON.stringify(foreign)), IncompatibleNative);
  const rounded = structuredClone(recovery);
  rounded.table.binding.identity.operation = Number(maximum);
  assert.throws(() => Reference.restore(JSON.stringify(rounded)), IncompatibleNative);
});

test("lookup retains full schema descriptors and original connection", async () => {
  await withHost({ metadata }, async (client) => {
    const found = await client.lookup("items");
    assert.equal(found?.rowCount, maximum);
    assert.equal(found?.basis.definition.interpretation.revision, 2n);
    assert.equal(found?.schema.columns[0]?.encoding, "ebcdic");
    assert.equal(found?.schema.columns[0]?.collation, "ebcdic_cp037");
    assert.deepEqual(JSON.parse(found!.basis.save()), preparedBasis);
  });
  for (const path of ["name", "namespace", "connection"] as const) {
    const changed = structuredClone(metadata);
    if (path === "name") changed.binding.name = "other";
    if (path === "namespace") changed.binding.namespace = 2;
    if (path === "connection") changed.binding.connection.principal = 5;
    await withHost({ metadata: changed }, (client) =>
      assert.rejects(client.lookup("items"), IncompatibleNative),
    );
  }
  const changed = structuredClone(metadata);
  Reflect.deleteProperty(changed.schema.columns[0]!, "encoding");
  await withHost({ metadata: changed }, (client) =>
    assert.rejects(client.lookup("items"), ReadFailed),
  );
});

test("compile, load and typed bulk preparation perform only their requested actions", async () => {
  await withHost({ compiled: { summary, saved } }, async (client, requests) => {
    const prepared = await client.compileSql("DROP TABLE items", ids);
    assert.equal(prepared.intent.operation, maximum);
    assert.equal(prepared.saved.save(), JSON.stringify(saved));
    const bytes = new Uint8Array(32768).fill(7);
    await client.prepare("items", ids, {
      kind: "mutate",
      basis: Basis.restore(JSON.stringify(preparedBasis)),
      ingestion: "bulk",
      mutation: {
        kind: "insert",
        rows: Array.from({ length: 9 }, () => [
          {
            column: 1n,
            value: {
              state: "value",
              value: { kind: "atom", atom: { kind: "binary", value: bytes } },
            },
          },
        ]),
      },
    });
    const sent = await requests();
    assert.deepEqual(
      sent.slice(3).map((value) => Object.keys(value.catalog)[0]),
      ["compile", "prepare"],
    );
    const action = sent.at(-1).catalog.prepare;
    assert.equal(action.operation, maximum.toString());
    assert.equal(action.action.mutate.ingestion, "bulk");
    assert.ok(JSON.stringify(action).length > contract.limits.handler_action_bytes);
    assert.equal(
      action.action.mutate.mutation.action.insert[8][0].value.cell.value.atom.binary,
      Buffer.from(bytes).toString("hex"),
    );
  });
  await withHost({ loaded: summary }, async (client, requests) => {
    const work = SavedIntent.restore(JSON.stringify(saved));
    assert.equal((await client.load(work)).saved, work);
    assert.deepEqual((await requests()).at(-1).catalog, { load: saved });
  });
});

test("read transport loss and uncertain mutation keep different recovery evidence", async () => {
  const original = Reference.restore(JSON.stringify(recovery));
  await withHost("loss", (client) => assert.rejects(client.inspect(original), ReadFailed));
  for (const invoke of [
    (client: Client) => client.admit(original),
    (client: Client) => client.execute(original, 32),
    (client: Client) => client.cancel(original),
  ]) {
    await withHost("loss", (client) =>
      assert.rejects(
        invoke(client),
        (error) => error instanceof Uncertain && error.recovery === original,
      ),
    );
  }
  await withHost({ status: 1, value: { err: "InvalidDataOperation" } }, (client) =>
    assert.rejects(client.admit(original), (error) => !(error instanceof Uncertain)),
  );
});

test("a mismatched successful mutation remains uncertain with the original reference", async () => {
  const original = Reference.restore(JSON.stringify(recovery));
  const binding = structuredClone(fixture.host.binding);
  binding.identity.operation = "1";
  const value = {
    observation: {
      ddl: {
        committed: {
          binding,
          resulting: stored,
          transaction: null,
          outcome: {
            position: { partition: "9", next_lsn: "10" },
            matched: "0",
            affected: "0",
            live_rows: "0",
          },
        },
      },
    },
  };
  await withHost(value, (client) =>
    assert.rejects(
      client.execute(original, 32),
      (error) => error instanceof Uncertain && error.recovery === original,
    ),
  );
  await withHost(value, (client) => assert.rejects(client.inspect(original), IncompatibleNative));
});

test("aggregate conversion stops before materializing oversized schema and DML", async () => {
  const cell: Cell = {
    state: "value",
    value: { kind: "atom", atom: { kind: "binary", value: new Uint8Array(1024 * 1024) } },
  };
  let visits = 0;
  const column = {
    id: 1n,
    name: "data",
    type: { kind: "binary" } as const,
    get default() {
      assert.ok(++visits < 8);
      return cell;
    },
  };
  assert.throws(() => new Schema(1n, 1n, 2n, Array(128).fill(column)), /Table wire budget/);
  visits = 0;
  const assignment = {
    column: 1n,
    get value() {
      assert.ok(++visits < 32);
      return cell;
    },
  };
  await withHost({}, (client) =>
    assert.rejects(
      client.prepare("items", ids, {
        kind: "mutate",
        basis: Basis.restore(JSON.stringify(preparedBasis)),
        mutation: { kind: "insert", rows: Array(1024).fill([assignment]) },
      }),
      /Table wire budget/,
    ),
  );
  assert.ok(visits < 32);
});

test("snapshot acquisition and release preserve saved recovery through host loss", async () => {
  const owner = {
    definition: contract.definition,
    connection: fixture.host.connection,
    object: fixture.host.binding.target,
    operation: maximum.toString(),
  };
  const value = { owner, expected: { partition: "9", next_lsn: maximum.toString() } };
  const acquisition = SnapshotAcquisition.restore(JSON.stringify(value));
  const snapshot = Snapshot.restore(JSON.stringify({ owner, content: fixture.host.content }));
  assert.equal(acquisition.owner.operation, maximum);
  assert.equal(acquisition.expected.nextLsn, maximum);
  assert.deepEqual(JSON.parse(acquisition.save()), value);
  assert.deepEqual(JSON.parse(snapshot.owner.save()), owner);
  const invalid = structuredClone(owner);
  Reflect.deleteProperty(invalid, "definition");
  assert.throws(() => SnapshotOwner.restore(JSON.stringify(invalid)), IncompatibleNative);
  await withHost("loss", (client) =>
    assert.rejects(
      client.acquireSnapshot(acquisition),
      (error) => error instanceof Uncertain && error.recovery === acquisition,
    ),
  );
  await withHost("loss", (client) =>
    assert.rejects(
      client.releaseSnapshot(snapshot),
      (error) => error instanceof Uncertain && error.recovery === snapshot,
    ),
  );
  await withHost("loss", (client) =>
    assert.rejects(client.snapshotStatus(acquisition.owner), ReadFailed),
  );
  await withHost("loss", (client) => assert.rejects(client.snapshotMetadata(snapshot), ReadFailed));
});

async function withHost(
  response: object | "loss",
  run: (client: Client, requests: () => Promise<any[]>) => Promise<void>,
): Promise<void> {
  const directory = await mkdtemp(join(tmpdir(), "transit-direct-catalog-boundary-"));
  const host = join(directory, "host.mjs"),
    log = join(directory, "requests.jsonl");
  const caps = {
    version: 1,
    definition: contract.definition,
    max_columns: 128,
    max_rows: 1024,
    max_sql_bytes: 4096,
    max_intent_bytes: contract.limits.catalog_intent_bytes,
    max_action_bytes: contract.limits.catalog_action_bytes,
    metadata_page_entries: 8,
    resident_intents: 1,
  };
  await writeFile(
    host,
    `#!${process.execPath}
import {createInterface} from 'node:readline';
import {appendFileSync} from 'node:fs';
for await (const line of createInterface({input:process.stdin})) {
  appendFileSync(${JSON.stringify(log)},line+'\\n');
  const action=JSON.parse(line);let result;
  if ('hello' in action) result={status:0,value:{host_version:1,station_version:1,transit_version:1}};
  else if ('growing_capabilities' in action) result={status:0,value:{definition:${JSON.stringify(contract.definition)}}};
  else if (action.catalog?.catalog?.capabilities) result={status:0,value:{catalog:{capabilities:${JSON.stringify(caps)}}}};
  else if (${JSON.stringify(response)} === 'loss') process.exit(0);
  else {const value=${JSON.stringify(response)};result='status' in value?value:{status:0,value};}
  const bytes=JSON.stringify(result)+'\\n';
  for(let i=0;i<bytes.length;i+=1021) await new Promise(resolve=>process.stdout.write(bytes.slice(i,i+1021),resolve));
}`,
    { mode: 0o700 },
  );
  try {
    const client = await Client.open(
      { url: "http://127.0.0.1:1", profile: "native_v1", nativeHost: host },
      new Credential(42, 4, "unused.seed"),
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
