import { expect, test } from "vite-plus/test";
import {
  sameDigest,
  tableContract,
  tablePage,
  unifiedContract,
  unifiedPage,
  type QueryBinding,
  type TableContract,
} from "./binding";
import type { QueryResponse, UnifiedQueryResponse } from "@rey/transit-board-client";
const digest = Array<number>(32).fill(7);
const binding: QueryBinding = {
  resource: 6,
  name: "items",
  source_kind: "table",
  schema: digest,
  profile: "unified_v2",
  sql: "SELECT * FROM items",
  refresh: "snapshot",
  starts: 1,
};
// The guards consume already runtime-validated responses. These projections
// isolate the identity boundary from unrelated result payload fields.
const compiled = { source: { resource: 6, source: { table: {} } }, contract: digest } as Extract<
  UnifiedQueryResponse,
  { compiled: unknown }
>["compiled"];
const page = (contract: number[], resource = 6) =>
  ({ evidence: { manifest: { basis: { resource, kind: "table", contract } } } }) as Extract<
    UnifiedQueryResponse,
    { page: unknown }
  >["page"];
test("unified declaration rejects old contracts and foreign source results", () => {
  unifiedContract(binding, compiled);
  unifiedPage(binding, page(digest));
  expect(() => unifiedPage(binding, page(Array<number>(32).fill(8)))).toThrow();
  expect(() => unifiedPage(binding, page(digest, 9))).toThrow();
  expect(() => unifiedContract({ ...binding, source_kind: "document" }, compiled)).toThrow();
  expect(sameDigest([], [])).toBe(false);
});
test("Table bindings fence a different Table even with an identical column schema", () => {
  const contract = {
    source: { connection: { resource: 6, name: "items", table: 2 } },
    fingerprint: digest,
    schema: digest,
  } as TableContract;
  tableContract({ ...binding, profile: "table_v1" }, contract);
  const result = { manifest: { table: 2, basis: { resource: 6, schema: digest } } } as Extract<
    QueryResponse,
    { page: unknown }
  >["page"];
  tablePage(contract, result);
  expect(() =>
    tablePage(contract, { ...result, manifest: { ...result.manifest, table: 1 } }),
  ).toThrow();
  expect(() =>
    tableContract({ ...binding, profile: "table_v1", name: "other" }, contract),
  ).toThrow();
});
