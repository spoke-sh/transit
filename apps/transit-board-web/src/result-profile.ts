import { unifiedCellText, type ResultView } from "@transit/query-client";
export const states = ["value", "null", "missing", "type_error", "conflict"] as const;
export function profileResult(view: ResultView, index: number) {
  const counts = { value: 0, null: 0, missing: 0, type_error: 0, conflict: 0 };
  const values: { number: bigint; label: string }[] = [];
  for (const row of view.rows) {
    const cell = row[index];
    if (!cell) continue;
    for (const state of states) if (state in cell) counts[state]++;
    if (!("value" in cell) || !("atom" in cell.value)) continue;
    const atom = cell.value.atom;
    const text =
      "signed" in atom
        ? atom.signed
        : "unsigned" in atom
          ? atom.unsigned
          : "decimal" in atom
            ? atom.decimal
            : null;
    if (text !== null)
      values.push({
        number: BigInt(text),
        label: unifiedCellText(cell, view.columns[index]?.type),
      });
  }
  values.sort((a, b) => (a.number < b.number ? -1 : a.number > b.number ? 1 : 0));
  const histogram = [0, 0, 0, 0, 0, 0];
  if (values.length) {
    const min = values[0]!.number,
      width = values[values.length - 1]!.number - min + 1n;
    for (const value of values) histogram[Number(((value.number - min) * 6n) / width)]!++;
  }
  return {
    counts,
    histogram,
    numeric: values.length === counts.value && values.length > 0,
    minimum: values[0]?.label,
    maximum: values[values.length - 1]?.label,
    distinct: new Set(values.map((value) => value.number.toString())).size,
  };
}
