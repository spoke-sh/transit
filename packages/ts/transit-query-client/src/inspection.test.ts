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
test("compiled metadata preserves output names and rejects malformed name vectors", () => {
  const compiled = {
    bundle: "00",
    source: fixture.scope.source,
    limits: fixture.scope.limits,
    contract: Array(32).fill(7),
    schema: Array(32).fill(8),
    plan: {
      version: 1,
      projection: [1, 0],
      output_names: ["Result", null],
      limit: null,
      aggregate: "rows",
      predicate: { all: {} },
    },
  };
  expect(validateUnifiedQuery({ compiled })).toBe(true);
  for (const names of [null, [null, null], ["__proto__", "constructor"]])
    expect(
      validateUnifiedQuery({
        compiled: { ...compiled, plan: { ...compiled.plan, output_names: names } },
      }),
    ).toBe(true);
  for (const names of [
    [],
    ["Result"],
    ["same", "same"],
    ["", null],
    ["bad name", null],
    ["a".repeat(33), null],
  ])
    expect(
      validateUnifiedQuery({
        compiled: { ...compiled, plan: { ...compiled.plan, output_names: names } },
      }),
    ).toBe(false);
});
test("native inspection fixtures retain full-width metadata and enforce plan semantics", () => {
  for (const item of fixture.cases) expect(validateUnifiedQuery(response(item.details))).toBe(true);
  const plan = fixture.cases[2]!.details.explanation!;
  for (const invalid of [
    { ...plan, operators: ["scan", "limit", "filter", "project"] },
    { ...plan, limit: "18446744073709551616" },
    { ...plan, columns: [plan.columns[0], plan.columns[0]] },
    { ...plan, projection: ["value"] },
    { ...plan, projection: ["value", "invalid name"] },
    { ...plan, budgets: { ...plan.budgets, pages: "0" } },
  ])
    expect(validateUnifiedQuery(response({ explanation: invalid }))).toBe(false);
  const count = fixture.cases[6]!.details.explanation!;
  expect(
    validateUnifiedQuery(
      response({ explanation: { ...count, columns: [{ name: "rows", type: "int64" }] } }),
    ),
  ).toBe(false);
  expect(validateUnifiedQuery(response({ tables: ["foreign"] }))).toBe(false);
  expect(validateUnifiedQuery(response({ tables: [] }))).toBe(false);
});
test("compound inspection accepts bounded postfix structure and rejects malformed programs", () => {
  const plan = fixture.cases[2]!.details.explanation!;
  const atom = { atom: { compare: { column: "id", op: "eq", type: "int64" } } };
  const check = (program: unknown[]) =>
    validateUnifiedQuery(
      response({
        explanation: { ...plan, predicate: { program } },
      }),
    );
  expect(
    check([
      atom,
      { negate: {} },
      { atom: { state: { column: "value", value: "null" } } },
      { disjunction: {} },
    ]),
  ).toBe(true);
  expect(check([atom, ...Array.from({ length: 63 }, () => ({ negate: {} }))])).toBe(true);
  for (const invalid of [
    [],
    [{ negate: {} }],
    [atom, atom],
    [atom, { conjunction: {} }],
    [atom, ...Array.from({ length: 64 }, () => ({ negate: {} }))],
    [{ atom: { state: { column: "bad name", value: "null" } } }],
    [{ atom: { program: [atom] } }],
  ])
    expect(check(invalid)).toBe(false);
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
