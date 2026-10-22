import { expect, test } from "vite-plus/test";
import { sameDigest, unifiedContract, unifiedPage, type QueryBinding } from "./binding";
import type { UnifiedQueryResponse } from "@transit/board-client";
const digest = Array<number>(32).fill(7);
const binding: QueryBinding = {
  resource: 6,
  name: "items",
  source_kind: "table",
  schema: digest,
  profile: "unified_v1",
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
  ({
    evidence: { manifest: { basis: { cut: { resource, kind: "table" }, contract } } },
  }) as Extract<UnifiedQueryResponse, { page: unknown }>["page"];
test("unified declaration rejects old contracts and foreign source results", () => {
  unifiedContract(binding, compiled);
  unifiedPage(binding, page(digest));
  expect(() => unifiedPage(binding, page(Array<number>(32).fill(8)))).toThrow();
  expect(() => unifiedPage(binding, page(digest, 9))).toThrow();
  expect(() => unifiedContract({ ...binding, source_kind: "document" }, compiled)).toThrow();
  expect(sameDigest([], [])).toBe(false);
});
