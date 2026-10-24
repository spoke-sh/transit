import { describe, expect, it, vi } from "vite-plus/test";
import {
  unifiedCellText,
  validateUnifiedQuery,
  type UnifiedQueryResponse,
  type UnifiedCell,
  request,
} from "@transit/board-client";

function page(cell: UnifiedCell): UnifiedQueryResponse {
  return {
    page: {
      evidence: {
        manifest: {
          job: 1,
          source: { native: { pid: 8, input: 9, index: 0 } },
          requester: 1,
          correlation: "18446744073709551615",
          policy_revision: "1",
          request: "00",
          basis: {
            cut: { kind: "document", resource: 7, position: { native_revision: 42 } },
            contract: Array(32).fill(0),
            schema: Array(32).fill(1),
          },
          table_position: null,
          plan: Array(32).fill(2),
          pages: "1",
          scanned: "1",
          selected: "1",
          value_count: "0",
          segments: "1",
          rows: "1",
          bytes: "1",
          sum: null,
          finished: "source_end",
          chain: Array(32).fill(3),
        },
        columns: [{ name: "counter", type: { uint64: {} }, nullable: true, optional: true }],
        ordinal: "0",
        rows: 1,
        ipc: "00",
        next: null,
      },
      cells: [[cell]],
    },
  };
}
describe("unified query boundary", () => {
  it("rejects impossible draft budgets and preserves full-width generation identities", () => {
    const draft = {
      generation: "18446744073709551615",
      limit: 2,
      starts: 1,
      enabled: false,
      contract: Array(32).fill(1),
      budgets: { pages: "16", segments: "4", result_bytes: "65536" },
      namespaces: ["18446744073709551615", ...Array(7).fill("0")],
    };
    expect(validateUnifiedQuery({ draft })).toBe(true);
    expect(validateUnifiedQuery({ draft: { ...draft, generation: "18446744073709551616" } })).toBe(
      false,
    );
    expect(validateUnifiedQuery({ draft: { ...draft, starts: 3 } })).toBe(false);
    expect(validateUnifiedQuery({ draft: { ...draft, limit: 9 } })).toBe(false);
    expect(
      validateUnifiedQuery({
        draft: { ...draft, starts: 2, namespaces: ["1", "1", ...Array(6).fill("0")] },
      }),
    ).toBe(false);
    expect(
      validateUnifiedQuery({ draft: { ...draft, namespaces: ["1", "2", ...Array(6).fill("0")] } }),
    ).toBe(false);
    expect(
      validateUnifiedQuery({ draft: { ...draft, budgets: { ...draft.budgets, pages: "0" } } }),
    ).toBe(false);
  });
  it("admits escaped query pages while keeping inspection and query response bounds", async () => {
    const value = page({ value: { atom: { utf8: "\u0000".repeat(2048) } } });
    if (!("page" in value)) throw new Error("fixture");
    value.page.evidence.columns = [
      { name: "key", type: { utf8: {} }, nullable: true, optional: true },
      { name: "value", type: { utf8: {} }, nullable: true, optional: true },
    ];
    value.page.evidence.rows = 8;
    value.page.evidence.ipc = "00".repeat(65536);
    Object.assign(value.page.evidence.manifest, {
      scanned: "8",
      selected: "8",
      value_count: "0",
      rows: "8",
      bytes: "65536",
    });
    value.page.cells = Array.from({ length: 8 }, () => [
      { value: { atom: { utf8: "\u0000".repeat(2048) } } },
      { value: { atom: { utf8: "\u0000".repeat(2048) } } },
    ]);
    const encoded = JSON.stringify(value);
    expect(encoded.length).toBeGreaterThan(262144);
    expect(validateUnifiedQuery(value)).toBe(true);
    try {
      vi.stubGlobal("fetch", async () => new Response(encoded));
      expect(await request("/api/v1/query", validateUnifiedQuery)).toEqual(value);
      await expect(request("/api/v1/processes", validateUnifiedQuery)).rejects.toMatchObject({
        code: "ResponseTooLarge",
      });
      vi.stubGlobal("fetch", async () => new Response(" ".repeat(1048577)));
      await expect(request("/api/v1/query", validateUnifiedQuery)).rejects.toMatchObject({
        code: "ResponseTooLarge",
      });
    } finally {
      vi.unstubAllGlobals();
    }
  });
  it("retains wide numbers and all five states without guessing nulls", () => {
    const values: UnifiedCell[] = [
      { missing: {} },
      { null: {} },
      { type_error: "map" },
      { value: { atom: { unsigned: "18446744073709551615" } } },
      {
        conflict: [
          { counter: "1", replica: "1", value: { null: {} } },
          {
            counter: "1",
            replica: "18446744073709551615",
            value: { value: { atom: { unsigned: "18446744073709551615" } } },
          },
        ],
      },
    ];
    for (const value of values) expect(validateUnifiedQuery(page(value))).toBe(true);
    expect(values.map((value) => unifiedCellText(value))).toEqual([
      "MISSING",
      "NULL",
      "TYPE ERROR (map)",
      "18446744073709551615",
      "CONFLICT [1/1: NULL; 1/18446744073709551615: 18446744073709551615]",
    ]);
    expect(unifiedCellText({ value: { atom: { float_bits: "0000000000000080" } } })).toBe("-0");
    expect(unifiedCellText({ value: { atom: { binary: "00ff" } } })).toBe("0x00ff");
  });
  it("rejects widened cells, reordered conflicts and false final coverage", () => {
    expect(
      validateUnifiedQuery(page({ value: { atom: { unsigned: "18446744073709551616" } } })),
    ).toBe(false);
    expect(validateUnifiedQuery(page({ value: { atom: { unsigned: "01" } } }))).toBe(false);
    expect(validateUnifiedQuery(page({ value: { atom: { signed: "1" } } }))).toBe(false);
    expect(
      validateUnifiedQuery(
        page({
          conflict: [
            { counter: "2", replica: "1", value: { null: {} } },
            { counter: "1", replica: "1", value: { null: {} } },
          ],
        }),
      ),
    ).toBe(false);
    const invalid = page({ missing: {} });
    if (!("page" in invalid)) throw new Error("fixture");
    invalid.page.evidence.next = "opaque";
    expect(validateUnifiedQuery(invalid)).toBe(false);
    invalid.page.evidence.next = null;
    invalid.page.evidence.manifest.rows = "1.0";
    expect(validateUnifiedQuery(invalid)).toBe(false);
  });
});
