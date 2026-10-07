import assert from "node:assert/strict";
import test from "node:test";
import { HandlerError, IncompatibleNative, ResourceRef } from "@transit/client";
import { TableSchema, TableMutation, TableMutationReference, RowIdentity } from "./table.ts";
import { QueryPlan } from "./query.ts";
import type { Turn } from "./turn.ts";
import contract from "./contract.json" with { type: "json" };
const maximum = (1n << 64n) - 1n;
const resource = new ResourceRef(1, 7);
const schema = new TableSchema(
  maximum,
  1n,
  5n,
  [
    { id: 1n, name: "id", type: { kind: "int64" }, nullable: false },
    { id: 2n, name: "name", type: { kind: "utf8" } },
    { id: 3n, name: "amount", type: { kind: "decimal", precision: 18, scale: 2 } },
    {
      id: 4n,
      name: "tags",
      type: { kind: "list", element: { type: { kind: "binary" }, nullable: true } },
    },
  ],
  [1n],
);

test("Table intents own rich values and preserve full-width identities across saved recovery", () => {
  const input = new Uint8Array([0, 1, 255]);
  const intent = TableMutation.prepare(resource, 0, maximum, schema, {
    kind: "insert",
    rows: [
      [
        {
          column: 1n,
          value: { state: "value", value: { kind: "atom", atom: { kind: "signed", value: 7n } } },
        },
        { column: 2n, value: { state: "null" } },
        {
          column: 3n,
          value: {
            state: "value",
            value: { kind: "atom", atom: { kind: "decimal", value: 12345n } },
          },
        },
        {
          column: 4n,
          value: {
            state: "value",
            value: {
              kind: "list",
              cells: [
                { state: "null" },
                { state: "value", value: { kind: "atom", atom: { kind: "binary", value: input } } },
              ],
            },
          },
        },
      ],
    ],
  });
  const saved = intent.save();
  input.fill(42);
  assert.equal(intent.save(), saved);
  const recovered = TableMutation.load(saved);
  assert.equal(recovered.save(), saved);
  assert.equal(recovered.operationId, maximum);
  assert.equal(recovered.schema.objectId, maximum);
  assert.deepEqual(recovered.schema.columns, schema.columns);
  const foreign = JSON.parse(saved);
  assert.equal(foreign.realm, 1);
  assert.equal(foreign.resource, 7);
  assert.equal(foreign.operation, maximum.toString());
  assert.equal(
    foreign.mutation.action.insert[0][3].value.cell.value.list[1].value.atom.binary,
    "0001ff",
  );
});

test("saved Table work rejects missing foreign and malformed identities before dispatch", () => {
  const intent = TableMutation.prepare(resource, 0, 1n, schema, { kind: "delete" });
  for (const change of [
    (value: Record<string, unknown>) => {
      delete (value.schema as Record<string, unknown>).definition;
    },
    (value: Record<string, unknown>) => {
      (value.schema as Record<string, unknown>).definition = "old";
    },
    (value: Record<string, unknown>) => {
      value.operation = 1;
    },
    (value: Record<string, unknown>) => {
      delete value.realm;
    },
    (value: Record<string, unknown>) => {
      value.table_write = {};
    },
  ]) {
    const value = JSON.parse(intent.save());
    change(value);
    assert.throws(() => TableMutation.load(JSON.stringify(value)), IncompatibleNative);
  }
  assert.throws(() => TableMutation.load(` ${intent.save()}`), IncompatibleNative);
  assert.throws(() => TableMutation.prepare(resource, 0, 0n, schema, { kind: "delete" }));
  assert.throws(() =>
    TableMutation.prepare(resource, 0, 1 as unknown as bigint, schema, { kind: "delete" }),
  );
});

test("Table recovery cannot retarget another realm or resource", () => {
  const intent = TableMutation.prepare(resource, 0, 1n, schema, { kind: "delete" });
  const reference = TableMutationReference.load(
    JSON.stringify({
      definition: contract.definition,
      realm: 1,
      resource: 7,
      object: maximum.toString(),
      principal: 0,
      operation: "1",
      digest: "11".repeat(32),
    }),
  );
  for (const target of [new ResourceRef(2, 7), new ResourceRef(1, 8)]) {
    const turn = { resource: target } as Turn;
    assert.throws(() => intent.step(turn), HandlerError);
    assert.throws(() => reference.status(turn), HandlerError);
  }
  assert.equal(TableMutationReference.load(reference.save()).save(), reference.save());
});

test("general handler plans freeze arbitrary projections and exact predicates", () => {
  const projection = [3, 0, 2];
  const plan = new QueryPlan({
    projection,
    outputNames: ["tags", "identity", "amount"],
    predicate: {
      kind: "compare",
      column: 2,
      comparison: "ge",
      value: { kind: "decimal", value: 12345n },
    },
    limit: maximum,
  });
  projection[0] = 1;
  assert.deepEqual(plan.wire().projection, [3, 0, 2]);
  assert.equal(plan.wire().limit, maximum.toString());
  const modified = plan.wire();
  modified.projection[0] = 1;
  assert.deepEqual(plan.wire().projection, [3, 0, 2]);
  assert.equal(
    new QueryPlan({ projection: Array.from({ length: 128 }, (_, i) => i) }).wire().projection
      .length,
    128,
  );
  assert.throws(() => new QueryPlan({ projection: [128] }));
});

test("row identity ownership and mutation operation budgets are explicit", () => {
  const bytes = new Uint8Array(20).fill(1);
  const identity = new RowIdentity(bytes);
  bytes.fill(2);
  assert.deepEqual(identity.bytes, new Uint8Array(20).fill(1));
  identity.bytes.fill(3);
  assert.deepEqual(identity.bytes, new Uint8Array(20).fill(1));
  assert.throws(() => new RowIdentity(new Uint8Array(19)));
  assert.throws(() =>
    TableMutation.prepare(resource, 0, 1n, schema, {
      kind: "insert",
      rows: [
        [
          {
            column: 1n,
            value: { state: "value", value: { kind: "atom", atom: { kind: "signed", value: 7n } } },
          },
          {
            column: 2n,
            value: {
              state: "value",
              value: {
                kind: "atom",
                atom: { kind: "utf8", value: "x".repeat(contract.limits.handler_action_bytes) },
              },
            },
          },
        ],
      ],
    }),
  );
});

test("handler schema bounds distinguish 128 columns from 1024 mutation rows", () => {
  const wide = new TableSchema(
    9n,
    1n,
    129n,
    Array.from({ length: 128 }, (_, i) => ({
      id: BigInt(i + 1),
      name: `c${i}`,
      type: { kind: "int64" as const },
    })),
  );
  const rows = Array.from({ length: 1024 }, (_, i) => [
    {
      column: 1n,
      value: {
        state: "value" as const,
        value: { kind: "atom" as const, atom: { kind: "signed" as const, value: BigInt(i) } },
      },
    },
  ]);
  const saved = TableMutation.prepare(resource, 0, 9n, wide, { kind: "insert", rows }).save();
  const recovered = TableMutation.load(saved);
  assert.equal(recovered.schema.columns.length, 128);
  assert.equal(JSON.parse(recovered.save()).mutation.action.insert.length, 1024);
  assert.throws(() =>
    TableMutation.prepare(resource, 0, 9n, wide, { kind: "insert", rows: [...rows, rows[0]!] }),
  );
});
