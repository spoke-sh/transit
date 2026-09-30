import type { Response as UnifiedQueryResponse } from "./types";
import { Response as schema } from "./validators.js";

type Page = Extract<UnifiedQueryResponse, { page: unknown }>["page"];
export type UnifiedCell = Page["cells"][number][number];
type Scalar = Extract<UnifiedCell, { value: unknown }>["value"];
type Column = Page["evidence"]["columns"][number];
const unsigned = (s: string, zero = true) =>
  /^(0|[1-9][0-9]{0,19})$/.test(s) && (zero || s !== "0") && BigInt(s) <= 18446744073709551615n;
const signed = (s: string) =>
  /^(0|-?[1-9][0-9]{0,18})$/.test(s) &&
  BigInt(s) >= -9223372036854775808n &&
  BigInt(s) <= 9223372036854775807n;
const hex = (s: string, bound: number) => s.length <= 2 * bound && /^(?:[0-9a-f]{2})*$/.test(s);
const text = (s: string, bound: number) =>
  !/[\uD800-\uDFFF]/u.test(s) && new TextEncoder().encode(s).length <= bound;
function floating(bits: string): number {
  const bytes = Uint8Array.from(bits.match(/../g) ?? [], (byte) => Number.parseInt(byte, 16));
  return new DataView(bytes.buffer).getFloat64(0, true);
}
function scalar(value: Scalar, kind: Column["type"]): boolean {
  if ("int64" in value) return kind === "int64" && signed(value.int64);
  if ("uint64" in value) return kind === "uint64" && unsigned(value.uint64);
  if ("float_bits" in value)
    return (
      kind === "float64" &&
      value.float_bits.length === 16 &&
      hex(value.float_bits, 8) &&
      Number.isFinite(floating(value.float_bits))
    );
  if ("boolean" in value) return kind === "boolean";
  if ("utf8" in value) return kind === "utf8" && text(value.utf8, 4096);
  return kind === "binary" && hex(value.binary, 4096);
}
function cell(value: UnifiedCell, kind: Column["type"]): boolean {
  if ("value" in value) return scalar(value.value, kind);
  if (!("conflict" in value)) return true;
  if (value.conflict.length < 2 || value.conflict.length > 8) return false;
  let previous = [0n, 0n];
  for (const alternative of value.conflict) {
    if (!unsigned(alternative.counter, false) || !unsigned(alternative.replica, false))
      return false;
    const counter = BigInt(alternative.counter),
      replica = BigInt(alternative.replica);
    if (counter < previous[0]! || (counter === previous[0] && replica <= previous[1]!))
      return false;
    previous = [counter, replica];
    if ("value" in alternative.value && !scalar(alternative.value.value, kind)) return false;
  }
  return true;
}
function columns(values: Column[]): boolean {
  return (
    values.length > 0 &&
    values.length <= 8 &&
    new Set(values.map((c) => c.name)).size === values.length &&
    values.every((c) => /^[A-Za-z_][A-Za-z_0-9]{0,31}$/.test(c.name))
  );
}
export function validateUnifiedQuery(input: unknown): input is UnifiedQueryResponse {
  if (!schema(input)) return false;
  const value = input as UnifiedQueryResponse;
  if ("assistance" in value) {
    const assistance = value.assistance;
    return (
      assistance.version === 1 &&
      assistance.profile === "unified_v1" &&
      assistance.resource > 0 &&
      unsigned(assistance.policy_revision, false) &&
      assistance.items.length <= 8 &&
      (assistance.range === null
        ? assistance.items.length === 0
        : assistance.range.start <= assistance.range.end && assistance.range.end <= 4096) &&
      assistance.items.every(
        (item) => text(item.text, 64) && item.text.length > 0 && text(item.detail, 64),
      )
    );
  }
  if ("suggestions" in value)
    return (
      value.suggestions.resource > 0 &&
      value.suggestions.items.length <= 8 &&
      value.suggestions.items.every((item) => text(item.label, 128) && text(item.sql, 4096))
    );
  if ("draft" in value) {
    const draft = value.draft;
    return (
      draft === null ||
      (unsigned(draft.generation, false) &&
        draft.limit >= 1 &&
        draft.limit <= 8 &&
        draft.starts <= draft.limit &&
        draft.namespaces.length === 8 &&
        Object.values(draft.budgets).every((value) => unsigned(value, false)) &&
        draft.namespaces.every((namespace, index) =>
          index < draft.starts
            ? unsigned(namespace, false) && !draft.namespaces.slice(0, index).includes(namespace)
            : namespace === "0",
        ))
    );
  }
  if ("prepared" in value)
    return (
      value.prepared === null ||
      (value.prepared.token.length > 0 && text(value.prepared.token, 8192))
    );
  if ("status" in value) return value.status === null || unsigned(value.status.correlation);
  if ("receipt" in value) return value.receipt.position > 0;
  if ("page" in value) {
    const page = value.page,
      evidence = page.evidence,
      manifest = evidence.manifest;
    if (
      !columns(evidence.columns) ||
      evidence.rows > 8 ||
      page.cells.length !== evidence.rows ||
      !hex(evidence.ipc, 65536) ||
      evidence.ipc.length === 0 ||
      (evidence.next !== null && !text(evidence.next, 4096))
    )
      return false;
    for (const field of [
      evidence.ordinal,
      manifest.correlation,
      manifest.policy_revision,
      manifest.pages,
      manifest.scanned,
      manifest.selected,
      manifest.segments,
      manifest.rows,
      manifest.bytes,
    ])
      if (!unsigned(field)) return false;
    if (
      BigInt(evidence.ordinal) >= BigInt(manifest.segments) ||
      BigInt(evidence.rows) > BigInt(manifest.rows) ||
      (evidence.next === null) !== (BigInt(evidence.ordinal) + 1n === BigInt(manifest.segments)) ||
      (manifest.sum !== null && !signed(manifest.sum))
    )
      return false;
    return page.cells.every(
      (row) =>
        row.length === evidence.columns.length &&
        row.every((c, i) => cell(c, evidence.columns[i]!.type)),
    );
  }
  if ("description" in value || "compiled" in value) {
    const source = "description" in value ? value.description.source.source : value.compiled.source;
    const limits = "description" in value ? value.description.budgets : value.compiled.limits;
    if (
      source.version !== 1 ||
      source.resource === 0 ||
      ![limits.pages, limits.segments, limits.result_bytes].every((s) => unsigned(s, false))
    )
      return false;
    if (
      "kv" in source.source &&
      (!hex(source.source.kv.prefix, 32) ||
        source.source.kv.key.version !== 1 ||
        source.source.kv.value.version !== 1)
    )
      return false;
    if ("document" in source.source) {
      const doc = source.source.document;
      if (
        doc.reference.resource !== source.resource ||
        ![doc.reference.document, doc.reference.epoch, doc.reference.revision].every((s) =>
          unsigned(s, false),
        ) ||
        doc.reference.type_revision !== 1 ||
        doc.change_format !== 1 ||
        !columns(doc.projections.map((p) => p.column))
      )
        return false;
    }
    if ("description" in value) {
      const d = value.description;
      return (
        columns(d.columns) &&
        d.source.capabilities.version === 1 &&
        d.sql.version === 1 &&
        unsigned(d.source.policy_revision, false) &&
        (d.source.active === null || unsigned(d.source.active, false))
      );
    }
    const compiled = value.compiled;
    return (
      hex(compiled.bundle, 16384) &&
      compiled.bundle.length > 0 &&
      compiled.plan.version === 1 &&
      (compiled.plan.limit === null || unsigned(compiled.plan.limit)) &&
      compiled.plan.projection.length > 0 &&
      compiled.plan.projection.length <= 8
    );
  }
  return true;
}
export function unifiedCellText(value: UnifiedCell): string {
  if ("missing" in value) return "MISSING";
  if ("null" in value) return "NULL";
  if ("type_error" in value) return `TYPE ERROR (${value.type_error})`;
  if ("conflict" in value)
    return `CONFLICT [${value.conflict.map((a) => `${a.counter}/${a.replica}: ${unifiedCellText(a.value)}`).join("; ")}]`;
  const item = value.value;
  if ("int64" in item) return item.int64;
  if ("uint64" in item) return item.uint64;
  if ("float_bits" in item) {
    const n = floating(item.float_bits);
    return Object.is(n, -0) ? "-0" : String(n);
  }
  if ("boolean" in item) return String(item.boolean);
  if ("binary" in item) return `0x${item.binary}`;
  return item.utf8 === "" ? '""' : item.utf8;
}
