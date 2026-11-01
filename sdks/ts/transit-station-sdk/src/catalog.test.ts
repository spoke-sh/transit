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
  HistorySelection,
  HistorySelectionStep,
  HistoryAcquisition,
  HistoryControl,
  HistoricalSnapshot,
  HistoryCursor,
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
test("column semantic metadata owns bytes and full-width spatial units", () => {
  const digest = Uint8Array.from({ length: 32 }, (_, i) => i);
  const tzif = new Uint8Array([84, 90, 105, 102, 0, 255]);
  const schema = new Schema(
    7n,
    1n,
    3n,
    [
      {
        id: 1n,
        name: "ts",
        type: { kind: "timestamp", zone: "utc" },
        semantics: { timezone: { version: "fixture", digest, zone: "Etc/UTC", tzif } },
      },
      {
        id: 2n,
        name: "opaque",
        type: { kind: "binary" },
        semantics: {
          spatial: {
            srid: 4326,
            verticalDatum: 0,
            unitScaleNm: maximum,
            axisOrientation: "right_handed_z_up",
            manifold: "planar",
            snapGridScale: 1e-9,
            exactPredicates: "shewchuk_adaptive",
            curveOrder: "none",
          },
        },
      },
    ],
    [],
  );
  digest.fill(0);
  tzif.fill(0);
  const rules = schema.columns[0]!.semantics!.timezone!;
  assert.deepEqual(
    [...rules.digest],
    Array.from({ length: 32 }, (_, i) => i),
  );
  assert.deepEqual([...rules.tzif], [84, 90, 105, 102, 0, 255]);
  rules.tzif.fill(0);
  assert.deepEqual([...schema.columns[0]!.semantics!.timezone!.tzif], [84, 90, 105, 102, 0, 255]);
  assert.equal(schema.columns[1]!.semantics!.spatial!.unitScaleNm, maximum);
});
test("companion values preserve independent descriptors, exact bits and owned bytes", async () => {
  const fixture = JSON.parse(
    await readFile(
      new URL(
        "../../../../packages/zig/transit-fuze/src/fixtures/companion-values.json",
        import.meta.url,
      ),
      "utf8",
    ),
  );
  for (const item of fixture.cases) {
    if (item.error !== null) continue; // Semantic admission belongs to Zig.
    assert.deepEqual(encodeType(decodeType(item.field.type)), item.field.type, item.name);
    const native = decodeCell(item.cell);
    assert.deepEqual(encodeCell(native), item.cell, item.name);
    if (native.state === "value" && native.value.kind === "vector") {
      const second = decodeCell(item.cell);
      native.value.bytes.fill(0);
      assert.deepEqual(encodeCell(second), item.cell, item.name);
    }
  }
});
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
    integrity: { next_id: 1, checks: [], foreign_keys: [] },
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
        semantics: { rounding: null, metric: null, timezone: null, spatial: null },
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
  for (const field of ["encoding", "semantics"]) {
    const changed = structuredClone(metadata);
    Reflect.deleteProperty(changed.schema.columns[0]!, field);
    await withHost({ metadata: changed }, (client) =>
      assert.rejects(client.lookup("items"), ReadFailed),
    );
  }
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

test("catalog descriptions require all current policy domains without aliases", async () => {
  const authority = {
    database_domain: 10,
    schema_domain: 11,
    table_domain: 12,
    stream_domain: 31,
    queue_domain: 32,
    kv_domain: 33,
    database: 20,
    initial_schema: 1,
    initial_schema_authority: 21,
  };
  const description = {
    configuration: {
      scope: fixture.host.connection.scope,
      branch: "1",
      partition: "2",
      audience: 5,
      authority,
      database_name: "transit",
      initial_schema_name: "public",
    },
    subject: {
      principal: 4,
      login_role: 4,
      role: 4,
      credential_epoch: 1,
      audience: 5,
      context: Array(32).fill(1),
    },
    policy_revision: 2,
  };
  await withHost({ catalog: { description } }, async (client) => {
    const profile = (await client.describe()).configuration.authority;
    assert.equal(profile.streamDomain, 31);
    assert.equal(profile.queueDomain, 32);
    assert.equal(profile.kvDomain, 33);
  });
  for (const field of ["stream_domain", "queue_domain", "kv_domain"] as const) {
    for (const missing of [true, false]) {
      const bad = structuredClone(description);
      if (missing) Reflect.deleteProperty(bad.configuration.authority, field);
      else bad.configuration.authority[field] = authority.table_domain;
      await withHost({ catalog: { description: bad } }, (client) =>
        assert.rejects(client.describe(), missing ? ReadFailed : IncompatibleNative),
      );
    }
  }
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

test("Table integrity preserves exact parent definitions and owned CHECK literals", () => {
  const definition = {
    object: { scope: new Scope(new ResourceRef(1, 2), 3n), branch: 1n, objectId: 90n },
    revision: 8n,
    digest: "ab".repeat(32),
  };
  const literal = new Uint8Array([1, 2, 3]);
  const value = new Schema(
    91n,
    2n,
    3n,
    [
      { id: 1n, name: "id", type: { kind: "int64" }, nullable: false },
      { id: 2n, name: "payload", type: { kind: "binary" }, nullable: true },
    ],
    [1n],
    {
      nextId: 3,
      checks: [
        {
          id: 1,
          name: "payload_check",
          atoms: [
            {
              kind: "compareLiteral",
              column: 2n,
              op: "eq",
              literal: { kind: "binary", value: literal },
            },
          ],
          validated: false,
        },
      ],
      foreignKeys: [
        {
          id: 2,
          name: "parent_id",
          localColumns: [1n],
          targetDefinition: definition,
          targetSchemaRevision: 3n,
          targetColumns: [7n],
          onDelete: "restrict",
          onUpdate: "no_action",
          enforcement: "staged_awaiting_index",
        },
      ],
    },
  );
  literal[0] = 99;
  const checks = value.integrity.checks;
  assert.equal(checks[0]!.validated, false);
  const atom = checks[0]!.atoms[0]!;
  assert.ok(atom.kind === "compareLiteral" && atom.literal.kind === "binary");
  assert.deepEqual([...atom.literal.value], [1, 2, 3]);
  atom.literal.value[0] = 7;
  const fresh = value.integrity.checks[0]!.atoms[0]!;
  assert.ok(fresh.kind === "compareLiteral" && fresh.literal.kind === "binary");
  assert.deepEqual([...fresh.literal.value], [1, 2, 3]);
  assert.equal(value.integrity.foreignKeys[0]!.targetDefinition.revision, 8n);
  assert.equal(value.integrity.foreignKeys[0]!.targetSchemaRevision, 3n);
});

test("committed DDL retains pending dependency settlement and its original identity", async () => {
  const wire = structuredClone(recovery);
  wire.table.binding.action = "alter";
  const original = Reference.restore(JSON.stringify(wire));
  const resulting = structuredClone(stored);
  resulting.interpretation.revision = (
    BigInt(wire.table.binding.expected_definition.revision) + 1n
  ).toString();
  const evidence = {
    binding: wire.table.binding,
    resulting,
    transaction: null,
    outcome: {
      position: { partition: "9", next_lsn: "10" },
      matched: "0",
      affected: "0",
      live_rows: "0",
    },
  };
  const operation = {
    binding: wire.table.binding,
    intent: wire.table.content,
    phase: "admitted",
    reason: "none",
    dependency_steps: 1,
    protected_columns: 1,
    requires_settlement: true,
    closing: null,
  };
  const value = { observation: { ddl: { finalizing: { evidence, operation } } } };
  await withHost(value, async (client) => {
    const result = await client.inspect(original);
    assert.equal(result.state, "finalizing");
    assert.equal(result.reference, original);
    assert.ok("commit" in result);
  });
  operation.requires_settlement = false;
  await withHost(value, (client) => assert.rejects(client.inspect(original), IncompatibleNative));
});

const historyFixture = JSON.parse(
  await readFile(
    new URL(
      "../../../../packages/zig/transit-catalog/src/fixtures/direct-history-host-v1.json",
      import.meta.url,
    ),
    "utf8",
  ),
);
const historyAcquisition = HistoryAcquisition.restore(JSON.stringify(historyFixture.acquire));
const historyKey = historyAcquisition.key;
const historicalSnapshot = new HistoricalSnapshot(historyFixture.snapshot.selector);
const historyStatus = {
  key: historyFixture.acquire.key,
  intent: historyFixture.acquire.intent,
  admitted: { partition: "1", next_lsn: "20" },
  revision: { partition: "1", next_lsn: "30" },
  phase: "published",
  retained: { content: historyFixture.snapshot.sources_root, count: "2" },
  after: maximum.toString(),
  inflight: null,
  verified_after: maximum.toString(),
  policy_epoch: maximum.toString(),
  released_after: null,
  snapshot: historyFixture.snapshot,
};
const historyNamespace = {
  scope: fixture.host.connection.scope,
  id: 1,
  authorization: 10,
  name: "original",
  revision: maximum.toString(),
};
const historyEntry = {
  namespace: historyNamespace,
  name: "items",
  declaration: stored,
  accepted: metadata.position,
  catalog: { partition: "1", next_lsn: "12" },
};
const historyPage = {
  snapshot: historyFixture.snapshot,
  namespace: 1,
  entries: [historyEntry],
  next: {
    selector: historicalSnapshot.selector,
    namespace: 1,
    directory: { content: historyFixture.snapshot.sources_root, count: "2" },
    after: "7",
  },
};

test("history values own full-width original common acquisition and reject missing definitions", async () => {
  assert.equal(historyAcquisition.operation, maximum);
  assert.equal(historyAcquisition.common?.transaction.operation, maximum - 1n);
  assert.deepEqual(JSON.parse(historyAcquisition.save()), historyFixture.acquire);
  assert.equal(
    HistoricalSnapshot.restore(historicalSnapshot.save()).selector,
    historicalSnapshot.selector,
  );
  for (const field of ["definition", "common", "selection"]) {
    const invalid = structuredClone(historyFixture.acquire);
    delete invalid.intent[field];
    assert.throws(() => HistoryAcquisition.restore(JSON.stringify(invalid)), IncompatibleNative);
  }
  const invalid = structuredClone(historyFixture.acquire);
  invalid.intent.operation = Number(maximum);
  assert.throws(() => HistoryAcquisition.restore(JSON.stringify(invalid)), IncompatibleNative);
  assert.throws(() => new HistoricalSnapshot("00".repeat(193)));
  await withHost({ history: { status: historyStatus } }, async (client, requests) => {
    const common = historyAcquisition.common!;
    const original = client.prepareCommonHistoryAcquisition(
      historyKey,
      maximum,
      1,
      historyAcquisition.selection,
      historyAcquisition.commonKey!,
      common,
    );
    assert.deepEqual(JSON.parse(original.save()), historyFixture.acquire);
    const result = await client.acquireHistory(original);
    assert.equal(result.phase, "published");
    assert.equal(result.intent.operation, maximum);
    assert.equal(result.policyEpoch, maximum);
    assert.equal(result.basis?.consistency.kind, "common_transaction");
    assert.equal(result.basis?.owner.scope.catalog, maximum);
    assert.equal(result.basis?.snapshot.selector, historicalSnapshot.selector);
    await client.close();
    const sent = (await requests()).filter((item) => item.catalog?.history);
    assert.equal(sent.length, 1); // Closing is not an explicit release.
    assert.deepEqual(sent[0].catalog.history.acquire, historyFixture.acquire);
  });
});

test("history uncertainty preserves acquisition, selected step and exact release command", async () => {
  await withHost("loss", async (client) => {
    await assert.rejects(
      client.acquireHistory(historyAcquisition),
      (error) => error instanceof Uncertain && error.recovery === historyAcquisition,
    );
  });
  await withHost("loss", async (client) => {
    const selection = client.prepareHistorySelection(maximum);
    const step = client.prepareHistoryStep(selection, 1, "items");
    assert.equal(HistorySelectionStep.restore(step.save()).selection.owner.operation, maximum);
    await assert.rejects(
      client.selectHistory(step),
      (error) => error instanceof Uncertain && error.recovery === step,
    );
  });
  await withHost("loss", async (client) => {
    await assert.rejects(
      client.releaseHistory(historyKey),
      (error) =>
        error instanceof Uncertain &&
        error.recovery instanceof HistoryControl &&
        error.recovery.command === "release" &&
        error.recovery.key.save() === historyKey.save(),
    );
  });
  for (const mutate of [
    (value: typeof historyStatus) => {
      value.intent.operation = "1";
    },
    (value: typeof historyStatus) => {
      value.snapshot = { ...value.snapshot, owner: { ...value.snapshot.owner, operation: "1" } };
    },
    (value: typeof historyStatus) => {
      value.key = { ...value.key, token: "00".repeat(16) };
    },
  ]) {
    const changed = structuredClone(historyStatus);
    mutate(changed);
    await withHost({ history: { status: changed } }, (client) =>
      assert.rejects(
        client.acquireHistory(historyAcquisition),
        (error) => error instanceof Uncertain && error.recovery === historyAcquisition,
      ),
    );
  }
});

test("history selection is explicit and never reacquires moving names during acquisition", async () => {
  const selected = {
    definition: contract.definition,
    owner: historyFixture.snapshot.owner,
    branch: "1",
    directory: { content: historyFixture.snapshot.catalog_root, count: "2" },
  };
  await withHost({ history: { selection: selected } }, async (client, requests) => {
    const step = client.prepareHistoryStep(client.prepareHistorySelection(maximum), 1, "items");
    const result = await client.selectHistory(step);
    const acquisition = client.prepareHistoryAcquisition(result, historyKey);
    assert.equal(result.directory?.count, 2n);
    assert.equal(JSON.parse(acquisition.save()).intent.common, null);
    assert.equal((await requests()).filter((item) => item.catalog?.history).length, 1);
    assert.equal(HistorySelection.restore(result.save()).owner.operation, maximum);
  });
});

test("historical metadata preserves immutable basis, wide revisions, bounded pages and cursor scope", async () => {
  await withHost({ history: { listing: historyPage } }, async (client, requests) => {
    const page = await client.historicalTables(historicalSnapshot, 1);
    assert.equal(page.entries[0]?.namespace.revision, maximum);
    assert.equal(page.basis.sourceCount, 2n);
    assert.equal(page.basis.snapshot, historicalSnapshot);
    const cursor = HistoryCursor.restore(page.next!.save());
    await assert.rejects(client.historicalTables(historicalSnapshot, 2, cursor), TypeError);
    await assert.rejects(
      client.historicalTables(new HistoricalSnapshot("00".repeat(297)), 1, cursor),
      TypeError,
    );
    assert.equal((await requests()).filter((item) => item.catalog?.history).length, 1);
    await assert.rejects(
      client.historicalTables(historicalSnapshot, 1, cursor),
      IncompatibleNative,
    ); // no progress
  });
  for (const changed of [
    { ...historyPage, snapshot: { ...historyPage.snapshot, selector: "00".repeat(297) } },
    { ...historyPage, namespace: 2 },
    {
      ...historyPage,
      next: { ...historyPage.next, directory: { ...historyPage.next.directory, count: "3" } },
    },
    { ...historyPage, entries: Array(9).fill(historyEntry) },
  ])
    await withHost({ history: { listing: changed } }, (client) =>
      assert.rejects(client.historicalTables(historicalSnapshot, 1)),
    );
  await withHost(
    { history: { listing: { ...historyPage, entries: [], next: null } } },
    async (client) => {
      const page = await client.historicalTables(historicalSnapshot, 1);
      assert.equal(page.entries.length, 0);
      assert.equal(page.next, undefined);
    },
  );
  await withHost({ history: { namespace: historyNamespace } }, async (client) => {
    assert.equal(
      (await client.historicalNamespace(historicalSnapshot, "original"))?.revision,
      maximum,
    );
  });
  await withHost(
    {
      history: {
        source: {
          snapshot: historyFixture.snapshot,
          binding: historyEntry,
          schema: metadata.schema,
          rows: maximum.toString(),
          changed_lsn: maximum.toString(),
          authority: { database: 9, schema: 10, table: 11 },
        },
      },
    },
    async (client) => {
      const source = await client.historicalSource(historicalSnapshot, 7n);
      assert.equal(source.rowCount, maximum);
      assert.equal(source.changedLsn, maximum);
      assert.equal(source.schema.columns[0]?.collation, "ebcdic_cp037");
    },
  );
});

test("lost historical metadata replies remain read failures", async () => {
  await withHost("loss", (client) =>
    assert.rejects(
      client.inspectHistory(historyKey),
      (error) => error instanceof ReadFailed && !(error instanceof Uncertain),
    ),
  );
  await withHost("loss", (client) =>
    assert.rejects(
      client.historicalSource(historicalSnapshot, 7n),
      (error) => error instanceof ReadFailed && !(error instanceof Uncertain),
    ),
  );
});

test("historical coverage retains wide counts and scopes every continuation", async () => {
  const coverage = {
    snapshot: historyFixture.snapshot,
    logical: historyEntry.declaration,
    accepted: historyEntry.accepted,
    total_rows: maximum.toString(),
    definitions: {
      physical: historyEntry.declaration,
      schema_revision: maximum.toString(),
      rows: maximum.toString(),
      columns: [{ column: "1", source: { physical: "1" } }],
    },
    locations: [],
    next: {
      selector: historicalSnapshot.selector,
      object: "7",
      kind: "definitions",
      source: historyFixture.snapshot.sources_root,
      after: maximum.toString(),
    },
  };
  await withHost({ history: { coverage } }, async (client, requests) => {
    const result = await client.historicalCoverage(historicalSnapshot, 7n);
    assert.equal(result.totalRows, maximum);
    assert.equal(result.definition?.rows, maximum);
    assert.deepEqual(result.definition?.columns[0]?.source, { physical: 1n });
    await assert.rejects(
      client.historicalCoverage(historicalSnapshot, 8n, "definitions", result.next),
      TypeError,
    );
    await assert.rejects(
      client.historicalCoverage(historicalSnapshot, 7n, "locations", result.next),
      TypeError,
    );
    assert.equal((await requests()).filter((item) => item.catalog?.history).length, 1);
    await assert.rejects(
      client.historicalCoverage(historicalSnapshot, 7n, "definitions", result.next),
      IncompatibleNative,
    );
  });
});
