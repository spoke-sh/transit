import assert from "node:assert/strict";
import test from "node:test";
import { mkdtemp, rm, writeFile, readFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { Credential, ProcessRef, ResourceRef, IncompatibleNative } from "@transit/client";
import { Connection, Scope } from "./catalog.ts";
import * as r from "./relational.ts";
import contract from "./contract.json" with { type: "json" };

const reference = {
  definition: contract.definition,
  id: "01".repeat(16),
  plan: "02".repeat(32),
  basis: "03".repeat(32),
};
const options: r.Options = {
  consistency: "per_resource_snapshot_vector",
  residentBytes: 16777216n,
  spillBytes: (1n << 64n) - 1n,
  resultBytes: 8388608n,
  outputRows: 1000n,
  workSteps: 100000n,
  sourcePins: 2,
  requests: 100000n,
  spillWork: 100000n,
  spillDirectory: "/tmp",
};

test("interactive relational references require exact definitions and remain immutable", () => {
  const restored = r.Reference.restore(JSON.stringify(reference));
  assert.equal(restored.save(), JSON.stringify(reference));
  assert(Object.isFrozen(restored));
  for (const invalid of [
    { ...reference, definition: "foreign" },
    { id: reference.id, plan: reference.plan, basis: reference.basis },
    { ...reference, extra: true },
  ])
    assert.throws(() => r.Reference.restore(JSON.stringify(invalid)), IncompatibleNative);
  assert.throws(() => r.Reference.restore(JSON.stringify({ ...reference, id: "00".repeat(16) })));
  for (let i = 0; i < 20; i++) assert.match(r.freshId(), /^[0-9a-f]{32}$/);
});

test("relational pages preserve exact values and own their caller-selected ordinal", async () => {
  const response = {
    page: {
      reference,
      ordinal: "18446744073709551615",
      row: {
        identity: { group: [null, "-9223372036854775808"] },
        cells: [
          { value: { atom: { signed: "-9223372036854775808" } } },
          { value: { atom: { unsigned: "18446744073709551615" } } },
          { null: {} },
        ],
      },
      complete_coverage: false,
    },
  };
  await withHost(response, async (client, requests) => {
    const ref = r.Reference.restore(JSON.stringify(reference));
    const result = await client.page(ref, (1n << 64n) - 1n);
    assert.deepEqual(result.row?.cells, [-(1n << 63n), (1n << 64n) - 1n, null]);
    assert.deepEqual(result.row?.identity, { kind: "group", keys: [null, -(1n << 63n)] });
    assert.equal(result.completeCoverage, false);
    assert(Object.isFrozen(result.row?.cells));
    const sent = (await requests()).find((v: any) => v.unified_query?.relational?.page) as any;
    assert.equal(sent.unified_query.relational.page.ordinal, "18446744073709551615");
  });
});

test("relational responses cannot change references, coverage or the int64 profile", async () => {
  for (const page of [
    {
      reference: { ...reference, basis: "04".repeat(32) },
      ordinal: "0",
      row: null,
      complete_coverage: true,
    },
    { reference, ordinal: "0", row: null, complete_coverage: false },
    {
      reference,
      ordinal: "0",
      row: {
        identity: { group: [] },
        cells: [{ value: { atom: { signed: "9223372036854775808" } } }],
      },
      complete_coverage: false,
    },
  ])
    await withHost({ page }, async (client) => {
      await assert.rejects(
        client.page(r.Reference.restore(JSON.stringify(reference)), 0n),
        IncompatibleNative,
      );
    });
});

async function withHost(
  response: object,
  run: (client: r.Client, requests: () => Promise<unknown[]>) => Promise<void>,
): Promise<void> {
  const directory = await mkdtemp(join(tmpdir(), "transit-relational-boundary-"));
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
  else if ('capabilities' in action.unified_query.relational) value={relational:{capabilities:{definition:${JSON.stringify(contract.definition)},sources:2,active_queries:1,page_rows:1,interactive:true,captured:false,maintained:false,consistency:'per_resource_snapshot_vector'}}};
  else value={relational:${JSON.stringify(response)}};
  console.log(JSON.stringify({status:0,value}));
}
`,
    { mode: 0o700 },
  );
  try {
    const client = await r.Client.open(
      { url: "http://127.0.0.1:1", profile: "native_v1", nativeHost: path },
      new Credential(1, 9, "unused.seed"),
      [new Connection(new ProcessRef(1, 3), new Scope(new ResourceRef(1, 7), (1n << 64n) - 1n))],
      options,
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
