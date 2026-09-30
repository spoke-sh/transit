import fixture from "../../../zig/transit-query/src/fixtures/sql-inspection-v1.json";
import { afterEach, expect, test, vi } from "vite-plus/test";
import { validateUnifiedQuery } from "./values";
import { httpTransport } from "./transport";

const response = (details: unknown) => ({
  inspection: {
    version: 1,
    scope: "configured_source",
    name: "items",
    resource: 17,
    source_kind: "table",
    contract: Array(32).fill(7),
    schema: Array(32).fill(8),
    resource_revision: 31,
    policy_revision: "18446744073709551615",
    details,
  },
});
afterEach(() => vi.unstubAllGlobals());
test("native inspection fixtures retain full-width metadata and enforce plan semantics", () => {
  for (const item of fixture.cases) expect(validateUnifiedQuery(response(item.details))).toBe(true);
  const plan = fixture.cases[2]!.details.explanation!;
  for (const invalid of [
    { ...plan, operators: ["scan", "limit", "filter", "project"] },
    { ...plan, limit: "18446744073709551616" },
    { ...plan, projection: ["value", "value"] },
    { ...plan, budgets: { ...plan.budgets, pages: "0" } },
  ])
    expect(validateUnifiedQuery(response({ explanation: invalid }))).toBe(false);
  expect(validateUnifiedQuery(response({ tables: ["foreign"] }))).toBe(false);
  expect(validateUnifiedQuery(response({ tables: [] }))).toBe(false);
});
test("inspection read conflicts retry the exact request and return separate metadata", async () => {
  const expected = response(fixture.cases[1]!.details);
  const fetcher = vi
    .fn()
    .mockResolvedValueOnce(Response.json({ err: "QueryReadConflict" }, { status: 409 }))
    .mockResolvedValueOnce(Response.json(expected));
  vi.stubGlobal("fetch", fetcher);
  expect(await httpTransport("/query")({ inspect: { sql: "SHOW TABLES" } })).toEqual(expected);
  expect(fetcher.mock.calls[0]?.[1].body).toBe(fetcher.mock.calls[1]?.[1].body);
  expect(fetcher).toHaveBeenCalledTimes(2);
});
