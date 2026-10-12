import { describe, expect, it, vi, afterEach } from "vite-plus/test";
import {
  relationalQuery,
  validateRelational,
  BoardError,
  type RelationalReference,
} from "@rey/transit-board-client";
import fixture from "../../../packages/zig/transit-protocol/src/fixtures/diagnostic-v1.json" with { type: "json" };
const reference: RelationalReference = {
  definition: fixture.definition as RelationalReference["definition"],
  id: "01".repeat(16),
  plan: "02".repeat(32),
  basis: "03".repeat(32),
};
const page = {
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
};
afterEach(() => vi.unstubAllGlobals());
describe("relational browser boundaries", () => {
  it("preserves integer bounds, nullable group identity and incomplete prefixes", () => {
    expect(validateRelational({ query: { page } })).toBe(true);
    for (const change of [
      { row: null },
      { complete_coverage: true },
      { ordinal: "01" },
      { reference: { ...reference, definition: "foreign" } },
      { row: { ...page.row, cells: [{ value: { atom: { signed: "9223372036854775808" } } }] } },
    ])
      expect(validateRelational({ query: { page: { ...page, ...change } } })).toBe(false);
  });
  it("rejects a valid page belonging to another active query", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue(
        new Response(
          JSON.stringify({
            query: { page: { ...page, reference: { ...reference, id: "04".repeat(16) } } },
          }),
          { status: 200 },
        ),
      ),
    );
    await expect(
      relationalQuery({ query: { page: { reference, ordinal: page.ordinal } } }),
    ).rejects.toBeInstanceOf(BoardError);
  });
  it("owns a request across rate refusals and never retries an execution failure", async () => {
    const operation = { query: { page: { reference: { ...reference }, ordinal: page.ordinal } } };
    const bodies: string[] = [];
    vi.stubGlobal(
      "fetch",
      vi.fn().mockImplementation(async (_: unknown, init: RequestInit) => {
        bodies.push(init.body as string);
        if (bodies.length === 1) {
          operation.query.page.reference.id = "ff".repeat(16);
          return new Response(JSON.stringify({ err: "RateLimited", diagnostic: null }), {
            status: 429,
          });
        }
        return new Response(JSON.stringify({ err: "Unavailable", diagnostic: null }), {
          status: 503,
        });
      }),
    );
    await expect(relationalQuery(operation)).rejects.toMatchObject({ status: 503 });
    expect(bodies).toHaveLength(2);
    expect(bodies[0]).toBe(bodies[1]);
    expect(JSON.parse(bodies[1]!).query.page.reference.id).toBe(reference.id);
  });
});
