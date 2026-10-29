import { describe, expect, it, vi, afterEach } from "vite-plus/test";
import {
  relationalQuery,
  validateRelational,
  BoardError,
  type RelationalReference,
} from "@transit/board-client";
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
    identity: { group: [null, { signed: "-9223372036854775808" }, { utf8: "A\u0000é " }] },
    cells: [
      { value: { atom: { signed: "-9223372036854775808" } } },
      { value: { atom: { unsigned: "18446744073709551615" } } },
      { null: {} },
      { value: { atom: { utf8: "A\u0000é " } } },
      { value: { atom: { utf8: "" } } },
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
      { row: { ...page.row, identity: { group: ["1"] } } },
      { row: { ...page.row, cells: [{ value: { atom: { utf8: "\ud800" } } }] } },
      { complete_coverage: true },
      { ordinal: "01" },
      { reference: { ...reference, definition: "foreign" } },
      { row: { ...page.row, cells: [{ value: { atom: { signed: "9223372036854775808" } } }] } },
    ])
      expect(validateRelational({ query: { page: { ...page, ...change } } })).toBe(false);
  });
  it("validates direct definitions and independent partition cuts", async () => {
    const scope = { realm: 1, resource: 7, catalog: "18446744073709551615" };
    const object = { scope, branch: "1", object: "18446744073709551615" };
    const binding = {
      definition: reference.definition,
      connection: { scope, branch: "1", audience: 3, principal: 9, role: null },
      namespace: 1,
      name: "items",
      interpretation: {
        interpretation: { object, revision: "18446744073709551615", digest: "04".repeat(32) },
        content: { bytes: "1024", sha256: "04".repeat(32) },
        schema_fingerprint: "05".repeat(32),
        retired: false,
      },
    };
    const position = { partition: "18446744073709551615", next_lsn: "18446744073709551615" };
    const storage = {
      binding,
      observed: {
        position,
        changed_lsn: "18446744073709551614",
        live_rows: "4",
        pending_rows: "0",
        pending_bytes: "0",
        pending_complete: true,
        oldest_pending_lsn: null,
        archive_through: "0",
        recovery_through: null,
        history_floor: "3",
        next_segment: "2",
        archive_source_lsn: "0",
        archived_source_lsn: "0",
        archive_target_source_lsn: null,
        archive_target_through_lsn: null,
        compaction_source_lsn: "0",
        compacted_source_lsn: "0",
        compaction_target_source_lsn: null,
        compaction_target_before_segment: null,
        compaction_target_after_segment: null,
      },
    };
    expect(validateRelational({ storage })).toBe(true);
    for (const change of [
      { live_rows: 4 },
      { pending_rows: "5" },
      { pending_complete: false },
      { archive_through: position.next_lsn },
      { next_segment: "0" },
    ])
      expect(
        validateRelational({
          storage: { ...storage, observed: { ...storage.observed, ...change } },
        }),
      ).toBe(false);
    const opened = {
      reference,
      description: {
        definition: reference.definition,
        plan: reference.plan,
        sources: [{ alias: "items", binding, position }],
        columns: [{ name: "id", type: { int64: {} }, optional: false, nullable: false }],
        join: null,
        grouped: false,
        executed: false,
      },
      cuts: [
        {
          object,
          position,
          commitment: "06".repeat(32),
          schema: binding.interpretation.schema_fingerprint,
        },
      ],
      complete_coverage: false,
    };
    expect(validateRelational({ query: { opened } })).toBe(true);
    const shifted = structuredClone(opened);
    shifted.cuts[0]!.position = { ...position, next_lsn: "1" };
    expect(validateRelational({ query: { opened: shifted } })).toBe(false);
    const inconsistent = structuredClone(opened);
    inconsistent.description.sources[0]!.binding.interpretation.content.sha256 = "07".repeat(32);
    expect(validateRelational({ query: { opened: inconsistent } })).toBe(false);
    for (const bytes of ["0", "01", "18446744073709551616"]) {
      const corrupt = structuredClone(opened);
      corrupt.description.sources[0]!.binding.interpretation.content.bytes = bytes;
      expect(validateRelational({ query: { opened: corrupt } })).toBe(false);
    }
    const replaced = structuredClone(opened);
    replaced.description.sources[0]!.binding.name = "another_name";
    vi.stubGlobal(
      "fetch",
      vi
        .fn()
        .mockResolvedValue(
          new Response(JSON.stringify({ query: { opened: replaced } }), { status: 200 }),
        ),
    );
    await expect(
      relationalQuery({
        query: {
          open: {
            id: reference.id,
            statement: { sql: "SELECT id FROM items", routes: [0], namespace: 1 },
            sources: [{ alias: "items", binding, position }],
          },
        },
      }),
    ).rejects.toBeInstanceOf(BoardError);
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
  it("reports persistent rate refusal after three identical close retries", async () => {
    const bodies: string[] = [];
    vi.stubGlobal(
      "fetch",
      vi.fn().mockImplementation(async (_: unknown, init: RequestInit) => {
        bodies.push(init.body as string);
        return new Response(JSON.stringify({ err: "RateLimited", diagnostic: null }), {
          status: 429,
        });
      }),
    );
    await expect(relationalQuery({ query: { close: reference } })).rejects.toMatchObject({
      status: 429,
    });
    expect(bodies).toHaveLength(4);
    expect(new Set(bodies).size).toBe(1);
  });
});
