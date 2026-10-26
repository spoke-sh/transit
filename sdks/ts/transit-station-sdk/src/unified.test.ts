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
import * as q from "./unified.ts";
import { Schema, Scope, schemaWire } from "./catalog.ts";
import contract from "./contract.json" with { type: "json" };

const resource = new ResourceRef(1, 7),
  owner = new ProcessRef(1, 3);
const source: q.Source = {
  kind: "table",
  scope: new Scope(resource, 9n),
  audience: 3,
  branch: 1n,
  namespace: 1,
  interpretation: new q.TableInterpretation(
    3n,
    new Uint8Array(32).fill(0xab),
    200n,
    new Uint8Array(32).fill(1),
  ),
  schema: new Schema(17n, 2n, 3n, [
    { id: 1n, name: "id", type: { kind: "uint128" }, nullable: false },
    { id: 2n, name: "値", type: { kind: "binary" }, nullable: true },
  ]),
};
const budgets = { pages: 100n, segments: 100n, resultBytes: 1048576n };

test("lookup preserves direct interpretation, schema and full-width frontier", async () => {
  const maximum = (1n << 64n) - 1n;
  const response = {
    table: {
      source: {
        version: 1,
        resource: 7,
        source: {
          table: {
            scope: { realm: 1, resource: 7, catalog: "9" },
            owner: 3,
            branch: "1",
            namespace: 1,
            object: "17",
            interpretation: {
              revision: "3",
              digest: Array(32).fill(0xab),
              bytes: "200",
              schema: Array(32).fill(1),
            },
            row_type: {
              structure: [
                { name: "id", type: { uint128: {} }, nullable: false, optional: false },
                { name: "値", type: { binary: {} }, nullable: true, optional: false },
              ],
            },
            collations: ["none", "none"],
          },
        },
      },
      schema: schemaWire(source.schema),
      expected: { partition: maximum.toString(), next_lsn: maximum.toString() },
    },
  };
  await withHost(response, async (client) => {
    const found = await client.lookupTable("people");
    assert.ok(found);
    assert.equal(found.source.schema.objectId, 17n);
    assert.equal(found.source.interpretation.revision, 3n);
    assert.equal(found.source.schema.revision, 2n);
    assert.deepEqual(found.capture(103, 12n), new q.Capture(103, 12n, maximum, maximum));
  });
  const inconsistent = structuredClone(response);
  inconsistent.table.source.source.table.row_type.structure[0]!.name = "substituted";
  await withHost(inconsistent, async (client) => {
    await assert.rejects(client.lookupTable("people"), IncompatibleNative);
  });
  for (const collations of [undefined, [], ["none"], ["none", "ascii_ci"]]) {
    const mismatched = structuredClone(response);
    Object.assign(mismatched.table.source.source.table, { collations });
    await withHost(mismatched, async (client) => {
      // Missing required fields fail schema admission before value conversion.
      await assert.rejects(
        client.lookupTable("people"),
        collations === undefined ? ReadFailed : IncompatibleNative,
      );
    });
  }
  const collated = structuredClone(response);
  Object.assign(collated.table.schema.columns[1]!, {
    type: { utf8: {} },
    collation: "ascii_ci",
  });
  Object.assign(collated.table.source.source.table.row_type.structure[1]!, { type: { utf8: {} } });
  collated.table.source.source.table.collations[1] = "ascii_ci";
  await withHost(collated, async (client, requests) => {
    const found = await client.lookupTable("people");
    assert.ok(found);
    assert.equal(found.source.schema.columns[1]!.collation, "ascii_ci");
    // Reuse the looked-up declaration in a real adapter request; the fake host
    // verifies serialization only and deliberately cannot compile a query.
    await assert.rejects(
      client.compileSql(found.source, "people", "SELECT * FROM people", budgets),
      IncompatibleNative,
    );
    const submitted = (await requests()).find((v: any) => v.unified_query?.compile) as any;
    assert.deepEqual(submitted.unified_query.compile.scope.source.source.table.collations, [
      "none",
      "ascii_ci",
    ]);
  });
});

test("capture preserves full-width storage coordinates and keeps cleanup separate", async () => {
  const maximum = (1n << 64n) - 1n;
  const bundle = new q.Bundle(new Uint8Array([1, 2, 3]));
  await withHost({ authorized: "010203" }, async (client, requests) => {
    await client.authorizeBundle(bundle, new q.Capture(103, maximum, maximum, maximum));
    const submitted = (await requests()).find((v: any) => v.unified_query?.authorize) as any;
    assert.deepEqual(submitted.unified_query.authorize, {
      bundle: "010203",
      capture: {
        executor: 103,
        operation: maximum.toString(),
        expected: { partition: maximum.toString(), next_lsn: maximum.toString() },
      },
    });
  });
  await withHost({ prepared: "owned cleanup control" }, async (client, requests) => {
    const prepared = await client.prepareCleanup(maximum, bundle);
    assert.equal(prepared.data, "owned cleanup control");
    const submitted = (await requests()).find((v: any) => v.unified_query?.cleanup) as any;
    assert.deepEqual(submitted.unified_query.cleanup, {
      namespace: maximum.toString(),
      bundle: "010203",
    });
  });
  assert.throws(() => new q.Capture(103, maximum + 1n, 1n, 0n), TypeError);
  assert.throws(() => new q.Capture(103, 1n, 0n, 0n), TypeError);
});

test("Table result cuts remain distinct from native resource versions", async () => {
  // The fake boundary checks decoding and route separation, never result truth.
  const response = {
    page: {
      manifest: {
        job: 1,
        source: { table: { worker: 3 } },
        requester: 4,
        correlation: "1",
        policy_revision: "1",
        request: "00".repeat(72),
        basis: {
          cut: { kind: "table", resource: 7, position: { table: Array(32).fill(1) } },
          contract: Array(32).fill(2),
          schema: Array(32).fill(3),
        },
        table_position: {
          resource: 7,
          partition: "18446744073709551615",
          accepted: "18446744073709551615",
          contract: Array(32).fill(2),
          schema: Array(32).fill(3),
        },
        plan: Array(32).fill(4),
        pages: "3",
        scanned: "19",
        selected: "19",
        value_count: "0",
        segments: "1",
        rows: "1",
        bytes: "64",
        sum: null,
        finished: "source_end",
        chain: Array(32).fill(5),
      },
      columns: [{ name: "n", type: { uint64: {} }, nullable: false, optional: false }],
      ordinal: "0",
      rows: 1,
      ipc: "00",
      next: null,
    },
  };
  await withHost(response, async (client) => {
    const page = await client.page(1n);
    assert.deepEqual(page.manifest.source, owner);
    assert.deepEqual(page.manifest.resource, resource);
    assert.equal(page.manifest.tablePosition?.accepted, (1n << 64n) - 1n);
    assert.deepEqual(page.manifest.cut, { kind: "table", commitment: new Uint8Array(32).fill(1) });
  });
  const substituted = structuredClone(response);
  substituted.page.manifest.table_position.schema.fill(7);
  await withHost(substituted, async (client) => {
    await assert.rejects(client.page(1n), IncompatibleNative);
  });
  const crossed = structuredClone(response);
  Object.assign(crossed.page.manifest.basis.cut, { position: { native_revision: 1 } });
  await withHost(crossed, async (client) => {
    await assert.rejects(client.page(1n), IncompatibleNative);
  });
});

test("SQL preparation freezes full-width atoms and direct interpretation before awaiting transport", async () => {
  await withHost({ compiled: {} }, async (client, requests) => {
    const bytes = new Uint8Array([0, 255]);
    const parameters: q.Scalar[] = [
      { kind: "unsigned", value: (1n << 128n) - 1n },
      { kind: "binary", value: bytes },
    ];
    const pending = client.compileSql(
      source,
      "人々 with spaces",
      'SELECT * FROM "人々 with spaces" WHERE id=$1 AND "値"=$2',
      budgets,
      parameters,
    );
    bytes.fill(1);
    parameters.length = 0;
    // The fake host deliberately returns an invalid result. It cannot establish
    // compilation or authority, but it records the actual owned request bytes.
    await assert.rejects(pending, ReadFailed);
    const submitted = (await requests()).find((v: any) => v.unified_query?.compile) as any;
    assert.deepEqual(submitted.unified_query.compile.parameters, [
      { unsigned: ((1n << 128n) - 1n).toString() },
      { binary: "00ff" },
    ]);
    const table = submitted.unified_query.compile.scope.source.source.table;
    assert.equal(table.object, "17");
    assert.equal(table.interpretation.revision, "3");
    assert.deepEqual(table.interpretation.digest, Array(32).fill(0xab));
    assert.deepEqual(table.collations, ["none", "none"]);
    assert.deepEqual(
      table.row_type.structure.map((v: any) => [v.name, v.type, v.nullable]),
      [
        ["id", { uint128: {} }, false],
        ["値", { binary: {} }, true],
      ],
    );
  });
});
test("inspection preserves recursive types and flags beyond the former eight-column profile", async () => {
  const columns = Array.from({ length: 128 }, (_, i) => ({
    name: `列 ${i}`,
    type: { list: { type: { decimal: { precision: 38, scale: 7 } }, nullable: true } },
    nullable: true,
    optional: false,
  }));
  await withHost(
    {
      inspection: {
        version: 1,
        scope: "configured_source",
        name: "people",
        resource: 7,
        source_kind: "table",
        contract: Array(32).fill(1),
        schema: Array(32).fill(2),
        resource_revision: 3,
        policy_revision: "18446744073709551615",
        details: { description: { columns } },
      },
    },
    async (client) => {
      const found = await client.inspectSql(source, "people", "DESCRIBE people", budgets);
      assert.equal(found.policyRevision, (1n << 64n) - 1n);
      assert.equal(found.details.kind, "description");
      if (found.details.kind !== "description") assert.fail();
      assert.equal(found.details.columns.length, 128);
      assert.deepEqual(found.details.columns[127], {
        name: "列 127",
        type: {
          kind: "list",
          element: { type: { kind: "decimal", precision: 38, scale: 7 }, nullable: true },
        },
        nullable: true,
        optional: false,
      });
    },
  );
});
test("unparameterized inspection rejects a bound NULL comparison directly and in a program", async () => {
  const atom = { null_compare: { column: "id", op: "eq", type: { uint128: {} } } };
  for (const predicate of [atom, { program: [{ atom }] }]) {
    await withHost(
      {
        inspection: {
          version: 1,
          scope: "configured_source",
          name: "people",
          resource: 7,
          source_kind: "table",
          contract: Array(32).fill(1),
          schema: Array(32).fill(2),
          resource_revision: 3,
          policy_revision: "1",
          details: {
            explanation: {
              operators: ["scan", "filter", "project"],
              predicate,
              projection: ["id"],
              limit: null,
              aggregate: "rows",
              columns: [{ name: "id", type: { uint128: {} }, nullable: false, optional: false }],
              budgets: { pages: "100", segments: "100", result_bytes: "1048576" },
            },
          },
        },
      },
      async (client) => {
        await assert.rejects(
          client.inspectSql(source, "people", "EXPLAIN SELECT id FROM people", budgets),
          IncompatibleNative,
        );
      },
    );
  }
});
async function withHost(
  response: object,
  run: (client: q.Client, requests: () => Promise<unknown[]>) => Promise<void>,
): Promise<void> {
  const directory = await mkdtemp(join(tmpdir(), "transit-query-boundary-"));
  const path = join(directory, "host.mjs"),
    log = join(directory, "requests.jsonl");
  await writeFile(
    path,
    `#!${process.execPath}
import {createInterface} from 'node:readline';
import {appendFileSync} from 'node:fs';
for await (const line of createInterface({input: process.stdin})) {
  appendFileSync(${JSON.stringify(log)}, line+'\\n');
  const action=JSON.parse(line); let value;
  if ('hello' in action) value={host_version:1,station_version:1,transit_version:1};
  else if ('growing_capabilities' in action) value={definition:${JSON.stringify(contract.definition)}};
  else if ('capabilities' in action.unified_query) value={capabilities:{version:1,source:1,plan:1,result:1,bundle_bytes:25614,part_bytes:128,segment_bytes:65536,batch_rows:8,columns:128,kv:true,table:true,document:true}};
  else value=${JSON.stringify(response)};
  console.log(JSON.stringify({status:0,value}));
}
`,
    { mode: 0o700 },
  );
  try {
    const client = await q.Client.open(
      { url: "http://127.0.0.1:1", profile: "native_v1", nativeHost: path },
      new Credential(1, 9, "unused.seed"),
      new q.Connection(owner, new ResourceRef(1, 77), new ProcessRef(1, 4), new ResourceRef(1, 8)),
      new q.Tables("http://127.0.0.1:2", new Scope(resource, 9n), 1n, 3),
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
