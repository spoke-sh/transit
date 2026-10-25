import type { ResultPage } from "./result";
export const cellStates = ["value", "null", "missing", "type_error", "conflict"] as const;
export type CellState = (typeof cellStates)[number];
/** Exact visible-page counts. The caller must supply a verified, currently
 * authorized page; these summaries neither read more data nor extend access. */
export function pageProfile(page: ResultPage) {
  return page.evidence.columns.map((column, index) => {
    const counts: Record<CellState, number> = {
      value: 0,
      null: 0,
      missing: 0,
      type_error: 0,
      conflict: 0,
    };
    for (const row of page.cells) {
      const cell = row[index]!;
      for (const state of cellStates) if (state in cell) counts[state]++;
    }
    return { ...column, counts };
  });
}

/** Label the admitted position without treating a Table cut as a native revision. */
export function sourcePositionText(manifest: ResultPage["evidence"]["manifest"]): string {
  const table = manifest.table_position;
  if (table) return `partition ${table.partition}, accepted ${table.accepted}`;
  const position = manifest.basis.cut.position;
  if ("native_revision" in position) return `revision ${position.native_revision}`;
  throw new Error("Missing Table position");
}
