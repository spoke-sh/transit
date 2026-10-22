import { expect, test } from "vite-plus/test";
import { BoardError } from "@transit/board-client";
import { verifiedPage, type ResultPage, type ReadPage } from "./unified-result";

const manifest: ResultPage["evidence"]["manifest"] = {
  job: 1,
  source: { pid: 2, input: 3, index: 0 },
  requester: 4,
  correlation: "5",
  policy_revision: "1",
  request: "00",
  basis: {
    cut: { kind: "table", resource: 6, revision: 7, head: Array(32).fill(0) },
    contract: Array(32).fill(0),
    schema: Array(32).fill(0),
  },
  plan: Array(32).fill(0),
  pages: "3",
  scanned: "3",
  selected: "3",
  value_count: "0",
  segments: "3",
  rows: "3",
  bytes: "3",
  sum: null,
  finished: "source_end",
  chain: Array(32).fill(0),
};
function page(n: number): ResultPage {
  return {
    evidence: {
      manifest,
      columns: [{ name: "id", type: { int64: {} }, nullable: true, optional: true }],
      ordinal: String(n),
      rows: 1,
      ipc: "00",
      next: n === 2 ? null : String(n + 1),
    },
    cells: [[{ value: { atom: { signed: String(n) } } }]],
  };
}
test("complete verification discards prefixes before the current-authority visible reread", async () => {
  const calls: (string | null)[] = [];
  const read: ReadPage = async (namespace, cursor) => {
    expect(namespace).toBe("18446744073709551615");
    calls.push(cursor);
    return page(Number(cursor ?? 0));
  };
  const result = await verifiedPage(
    "18446744073709551615",
    null,
    "3",
    new AbortController().signal,
    read,
  );
  expect(calls).toEqual([null, "1", "2", null]);
  expect(result.cells).toEqual([[{ value: { atom: { signed: "0" } } }]]);
});
test("denial between verification and reread yields no candidate", async () => {
  let calls = 0;
  const read: ReadPage = async (_namespace, cursor) => {
    if (++calls === 4) throw new BoardError(403, "Forbidden");
    return page(Number(cursor ?? 0));
  };
  await expect(
    verifiedPage("1", null, "3", new AbortController().signal, read),
  ).rejects.toMatchObject({ status: 403 });
});
test("mixed manifests, incomplete coverage and operation budget cannot publish a prefix", async () => {
  for (const failure of ["identity", "coverage", "budget"]) {
    const read: ReadPage = async (_namespace, cursor) => {
      const result = page(Number(cursor ?? 0));
      if (failure === "identity" && cursor === "1")
        result.evidence.manifest = { ...manifest, job: 99 };
      if (failure === "coverage" && cursor === "1") result.evidence.next = null;
      return result;
    };
    await expect(
      verifiedPage("1", null, failure === "budget" ? "2" : "3", new AbortController().signal, read),
    ).rejects.toThrow(BoardError);
  }
});
