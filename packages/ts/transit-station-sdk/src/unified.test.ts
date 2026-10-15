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
import { Metadata, MetadataCommitment, Schema, Scope } from "./catalog.ts";
import contract from "./contract.json" with { type: "json" };

const resource = new ResourceRef(1, 7),
  owner = new ProcessRef(1, 3);
const source: q.Source = {
  kind: "table",
  owner,
  metadata: new Metadata({
    namespace: 1,
    scope: new Scope(resource, 9n),
    objectId: 17n,
    revision: 3n,
    name: "people",
    schemaFingerprint: "01".repeat(32),
    principal: 9,
    operation: 2n,
    admittedInput: 10,
    commitment: new MetadataCommitment(200, "ab".repeat(32)),
  }),
  schema: new Schema(17n, 2n, 3n, [
    { id: 1n, name: "id", type: { kind: "uint128" }, nullable: false },
    { id: 2n, name: "値", type: { kind: "binary" }, nullable: true },
  ]),
};
const budgets = { pages: 100n, segments: 100n, resultBytes: 1048576n };

test("SQL preparation freezes full-width atoms and catalog metadata before awaiting transport", async () => {
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
    assert.equal(table.metadata.id, "3");
    assert.deepEqual(table.metadata.spec.digest, Array(32).fill(0xab));
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
  else if ('capabilities' in action.unified_query) value={capabilities:{version:1,source:1,plan:1,result:1,bundle_bytes:25069,part_bytes:128,segment_bytes:65536,batch_rows:8,columns:128,kv:true,table:true,document:true}};
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
      new q.Connection(owner, resource, new ProcessRef(1, 4), new ResourceRef(1, 8)),
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
