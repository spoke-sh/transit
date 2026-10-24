import { ownedDiagnostic } from "./diagnostics";
import type { Response as UnifiedQueryResponse } from "./types";
import { Response as schema } from "./validators.js";
import {
  boundedQueryJson,
  logicalName,
  logicalText as text,
  logicalHex as hex,
  logicalInteger,
  logicalColumnsValid as columns,
  logicalTypeEqual,
  logicalTypeValid,
  logicalAtomValid,
  logicalCellValid,
  logicalCellText,
  type LogicalField,
} from "./logical";

type Page = Extract<UnifiedQueryResponse, { page: unknown }>["page"];
export type UnifiedCell = Page["cells"][number][number];
type Inspection = Extract<UnifiedQueryResponse, { inspection: unknown }>["inspection"];
type Predicate = Extract<
  Inspection["details"],
  { explanation: unknown }
>["explanation"]["predicate"];
type Atom = Exclude<Predicate, { program: unknown }>;
const comparable = (type: LogicalField["type"]) =>
  !["structure", "list", "array", "map", "tagged_union", "json", "interval"].some(
    (kind) => kind in type,
  );
function inspectedAtom(value: Atom): boolean {
  if ("all" in value) return true;
  if ("state" in value) return logicalName(value.state.column);
  const comparison = "compare" in value ? value.compare : value.null_compare;
  return (
    logicalName(comparison.column) &&
    logicalTypeValid(comparison.type) &&
    comparable(comparison.type)
  );
}
function inspectedPredicate(value: Predicate): boolean {
  if (!("program" in value)) return inspectedAtom(value);
  if (value.program.length === 0 || value.program.length > 64) return false;
  let depth = 0;
  for (const instruction of value.program) {
    if ("atom" in instruction) {
      if (!inspectedAtom(instruction.atom)) return false;
      depth++;
    } else if ("negate" in instruction) {
      if (depth === 0) return false;
    } else {
      if (depth < 2) return false;
      depth--;
    }
  }
  return depth === 1;
}
const unsigned = (s: string, zero = true) =>
  /^(0|[1-9][0-9]{0,19})$/.test(s) && (zero || s !== "0") && BigInt(s) <= 18446744073709551615n;
const signed = (s: string) => logicalInteger(s, 64, true);
function sourceColumns(
  source: Extract<UnifiedQueryResponse, { compiled: unknown }>["compiled"]["source"],
): LogicalField[] | null {
  if ("table" in source.source) {
    const table = source.source.table;
    if (
      table.scope.resource !== source.resource ||
      table.scope.realm === 0 ||
      table.owner === 0 ||
      !unsigned(table.scope.catalog, false) ||
      !unsigned(table.object, false) ||
      !unsigned(table.metadata.id, false) ||
      table.metadata.spec.format !== 0x54434d01 ||
      table.metadata.spec.length === 0 ||
      table.metadata.spec.length > 436 ||
      !("structure" in table.row_type) ||
      !columns(table.row_type.structure)
    )
      return null;
    return table.row_type.structure;
  }
  const fields =
    "kv" in source.source
      ? [
          { name: "key", type: source.source.kv.key.type },
          { name: "value", type: source.source.kv.value.type },
        ]
      : source.source.document.projections.map((p) => p.column);
  return fields.map((field) => ({
    name: field.name,
    type: { [field.type]: {} } as LogicalField["type"],
    nullable: true,
    optional: true,
  }));
}
export function validateUnifiedQuery(input: unknown): input is UnifiedQueryResponse {
  if (!boundedQueryJson(input) || !schema(input)) return false;
  const value = input as UnifiedQueryResponse;
  if ("inspection" in value) {
    const result = value.inspection;
    const name = logicalName;
    if (
      result.version !== 1 ||
      result.resource === 0 ||
      !name(result.name) ||
      !unsigned(result.policy_revision, false)
    )
      return false;
    const details = result.details;
    if ("description" in details) return columns(details.description.columns);
    if ("tables" in details)
      return (
        details.tables.length === (result.source_kind === "table" ? 1 : 0) &&
        details.tables.every((n) => n === result.name)
      );
    const plan = details.explanation;
    const expected = [
      "scan",
      ...("all" in plan.predicate ? [] : ["filter"]),
      ...(plan.limit === null ? [] : ["limit"]),
      plan.aggregate === "rows" ? "project" : plan.aggregate,
    ];
    return (
      columns(plan.columns) &&
      JSON.stringify(plan.operators) === JSON.stringify(expected) &&
      plan.projection.length > 0 &&
      plan.projection.length <= 128 &&
      plan.projection.every(name) &&
      (plan.limit === null || unsigned(plan.limit)) &&
      Object.values(plan.budgets).every((s) => unsigned(s, false)) &&
      inspectedPredicate(plan.predicate) &&
      (plan.aggregate === "rows"
        ? plan.columns.length === plan.projection.length
        : plan.projection.length === 1 &&
          plan.columns.length === 1 &&
          (plan.aggregate === "sum" ? "int64" : "uint64") in plan.columns[0]!.type)
    );
  }
  if ("assistance" in value) {
    const assistance = value.assistance;
    return (
      assistance.version === 1 &&
      ["complete", "limited"].includes(assistance.coverage) &&
      ["ready", "inside_text", "unsupported"].includes(assistance.status) &&
      assistance.profile === "unified_v1" &&
      assistance.resource > 0 &&
      unsigned(assistance.policy_revision, false) &&
      assistance.items.length <= 8 &&
      (assistance.range === null
        ? assistance.items.length === 0
        : assistance.range.start <= assistance.range.end && assistance.range.end <= 4096) &&
      assistance.items.every(
        (item) => text(item.text, 512) && item.text.length > 0 && text(item.detail, 64),
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
  if ("status" in value) {
    if (value.status === null) return true;
    if (!unsigned(value.status.correlation)) return false;
    const diagnostic = value.status.diagnostic;
    if (diagnostic === null) return true;
    const phase = value.status.phase;
    return (
      !ownedDiagnostic(diagnostic).invalid &&
      diagnostic.evidence === "domain_status" &&
      diagnostic.identity?.domain === "query" &&
      diagnostic.outcome === (phase === "denied" || phase === "rejected" ? "rejected" : phase)
    );
  }
  if ("receipt" in value) return value.receipt.position > 0;
  if ("page" in value) {
    const page = value.page,
      evidence = page.evidence,
      manifest = evidence.manifest;
    if (
      !columns(evidence.columns) ||
      manifest.basis.cut.resource === 0 ||
      (manifest.basis.cut.kind !== "table" && manifest.basis.cut.head.some((byte) => byte !== 0)) ||
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
      manifest.value_count,
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
        row.every((c, i) => logicalCellValid(c, evidence.columns[i]!)),
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
      const path = (parts: string[], empty: boolean) =>
        (empty || parts.length > 0) &&
        parts.length <= 8 &&
        parts.every((part) => part.length > 0 && text(part, 64));
      if (
        doc.reference.resource !== source.resource ||
        ![doc.reference.document, doc.reference.epoch, doc.reference.revision].every((s) =>
          unsigned(s, false),
        ) ||
        doc.reference.type_revision !== 1 ||
        doc.change_format !== 1 ||
        (doc.expand !== null && !path(doc.expand, false)) ||
        doc.projections.length === 0 ||
        doc.projections.length > 8 ||
        !doc.projections.every(
          (p) =>
            /^[A-Za-z_][A-Za-z_0-9]{0,31}$/.test(p.column.name) &&
            path(p.path, p.relative) &&
            (!p.relative || doc.expand !== null) &&
            p.text_bytes > 0 &&
            p.text_bytes <= 4096 &&
            p.text_steps > 0 &&
            p.text_steps <= 16384 &&
            (p.mode !== "text" || p.column.type === "utf8") &&
            (!["element_counter", "element_replica"].includes(p.mode) ||
              (p.relative && !p.path.length && p.column.type === "uint64")),
        )
      )
        return false;
    }
    const fields = sourceColumns(source);
    if (!fields || !columns(fields)) return false;
    if ("description" in value) {
      const d = value.description;
      return (
        columns(d.columns) &&
        logicalName(d.name) &&
        d.columns.length === fields.length &&
        d.columns.every(
          (field, i) =>
            field.name === fields[i]!.name &&
            logicalTypeEqual(field.type, fields[i]!.type) &&
            field.nullable === fields[i]!.nullable &&
            field.optional === fields[i]!.optional,
        ) &&
        d.source.capabilities.version === 1 &&
        d.sql.version === 1 &&
        unsigned(d.source.policy_revision, false) &&
        (d.source.active === null || unsigned(d.source.active, false))
      );
    }
    const compiled = value.compiled,
      plan = compiled.plan;
    if (
      !hex(compiled.bundle, 25255) ||
      compiled.bundle.length === 0 ||
      plan.version !== 1 ||
      (plan.limit !== null && !unsigned(plan.limit)) ||
      !plan.projection.length ||
      plan.projection.length > 128 ||
      plan.projection.some((i) => i >= fields.length) ||
      (plan.output_names !== null && plan.output_names.length !== plan.projection.length) ||
      (plan.aggregate !== "rows" && plan.projection.length !== 1) ||
      (plan.aggregate === "sum" && !("int64" in fields[plan.projection[0]!]!.type))
    )
      return false;
    const output = plan.projection.map((index, i) => ({
      ...(plan.aggregate === "rows"
        ? fields[index]!
        : {
            name: plan.aggregate === "count_values" ? "count" : plan.aggregate,
            type: plan.aggregate === "sum" ? { int64: {} } : { uint64: {} },
            nullable: plan.aggregate === "sum",
            optional: false,
          }),
      ...(plan.output_names?.[i] === null || plan.output_names?.[i] === undefined
        ? {}
        : { name: plan.output_names[i]! }),
    }));
    if (!columns(output)) return false;
    type PredicateAtom = Exclude<typeof plan.predicate, { program: unknown }>;
    const atom = (a: PredicateAtom) =>
      "all" in a ||
      ("state" in a
        ? a.state.column < fields.length
        : "null_compare" in a
          ? a.null_compare.column < fields.length && comparable(fields[a.null_compare.column]!.type)
          : a.compare.column < fields.length &&
            comparable(fields[a.compare.column]!.type) &&
            logicalAtomValid(a.compare.value, fields[a.compare.column]!.type) &&
            (!("utf8" in a.compare.value) || text(a.compare.value.utf8, 4096)) &&
            (!("binary" in a.compare.value) || hex(a.compare.value.binary, 4096)));
    if (!("program" in plan.predicate)) return atom(plan.predicate);
    if (!plan.predicate.program.length || plan.predicate.program.length > 64) return false;
    let depth = 0;
    for (const instruction of plan.predicate.program) {
      if ("atom" in instruction) {
        if (!atom(instruction.atom)) return false;
        depth++;
      } else if ("negate" in instruction) {
        if (!depth) return false;
      } else {
        if (depth < 2) return false;
        depth--;
      }
    }
    return depth === 1;
  }
  return true;
}
export const unifiedCellText = logicalCellText;
export { logicalTypeText } from "./logical";
