import { describe, expect, it, vi } from "vite-plus/test";
import {
  unifiedCellText,
  validateUnifiedQuery,
  type UnifiedQueryResponse,
  type UnifiedCell,
  request,
} from "@rey/transit-board-client";

function page(cell: UnifiedCell): UnifiedQueryResponse {
  return {
    page: {
      evidence: {
        manifest: {
          job: 1,
          source: { pid: 8, input: 9, index: 0 },
          requester: 1,
          correlation: "18446744073709551615",
          policy_revision: "1",
          request: "00",
          basis: {
            kind: "document",
            resource: 7,
            revision: 42,
            contract: Array(32).fill(0),
            schema: Array(32).fill(1),
          },
          plan: Array(32).fill(2),
          pages: "1",
          scanned: "1",
          selected: "1",
          segments: "1",
          rows: "1",
          bytes: "1",
          sum: null,
          finished: "source_end",
          chain: Array(32).fill(3),
        },
        columns: [{ name: "counter", type: "uint64" }],
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
  it("admits escaped owned pages beyond the inspection response budget and bounds v2 separately", async () => {
    const value = page({ value: { utf8: "\u0000".repeat(2048) } });
    if (!("page" in value)) throw new Error("fixture");
    value.page.evidence.columns = [
      { name: "key", type: "utf8" },
      { name: "value", type: "utf8" },
    ];
    value.page.evidence.rows = 8;
    value.page.evidence.ipc = "00".repeat(65536);
    Object.assign(value.page.evidence.manifest, {
      scanned: "8",
      selected: "8",
      rows: "8",
      bytes: "65536",
    });
    value.page.cells = Array.from({ length: 8 }, () => [
      { value: { utf8: "\u0000".repeat(2048) } },
      { value: { utf8: "\u0000".repeat(2048) } },
    ]);
    const encoded = JSON.stringify(value);
    expect(encoded.length).toBeGreaterThan(262144);
    expect(validateUnifiedQuery(value)).toBe(true);
    try {
      vi.stubGlobal("fetch", async () => new Response(encoded));
      expect(await request("/api/v1/query-v2", validateUnifiedQuery)).toEqual(value);
      await expect(request("/api/v1/query", validateUnifiedQuery)).rejects.toMatchObject({
        code: "ResponseTooLarge",
      });
      vi.stubGlobal("fetch", async () => new Response(" ".repeat(1048577)));
      await expect(request("/api/v1/query-v2", validateUnifiedQuery)).rejects.toMatchObject({
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
      { value: { uint64: "18446744073709551615" } },
      {
        conflict: [
          { counter: "1", replica: "1", value: { null: {} } },
          {
            counter: "1",
            replica: "18446744073709551615",
            value: { value: { uint64: "18446744073709551615" } },
          },
        ],
      },
    ];
    for (const value of values) expect(validateUnifiedQuery(page(value))).toBe(true);
    expect(values.map(unifiedCellText)).toEqual([
      "MISSING",
      "NULL",
      "TYPE ERROR (map)",
      "18446744073709551615",
      "CONFLICT [1/1: NULL; 1/18446744073709551615: 18446744073709551615]",
    ]);
    expect(unifiedCellText({ value: { float_bits: "0000000000000080" } })).toBe("-0");
    expect(unifiedCellText({ value: { binary: "00ff" } })).toBe("0x00ff");
  });
  it("rejects widened cells, reordered conflicts and false final coverage", () => {
    expect(validateUnifiedQuery(page({ value: { uint64: "18446744073709551616" } }))).toBe(false);
    expect(validateUnifiedQuery(page({ value: { uint64: "01" } }))).toBe(false);
    expect(validateUnifiedQuery(page({ value: { int64: "1" } }))).toBe(false);
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
