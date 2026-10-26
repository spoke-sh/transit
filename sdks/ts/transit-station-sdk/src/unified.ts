import contract from "./contract.json" with { type: "json" };
import {
  AdmissionReceipt,
  Credential,
  ProcessRef,
  ResourceRef,
  IncompatibleNative,
  UnknownOutcome,
} from "@transit/client";
import { configuration, integer, owned, text } from "@transit/client/internal";
import type { ClientConfig } from "@transit/client";
import { Bridge, QueryBridge } from "./bridge.ts";
import { hex, unhex } from "./framing.ts";
import { wide, nativeWide, ReadVersion } from "./values.ts";
import { DocumentReference } from "./document.ts";
import { Scope, Schema, schemaValue, schemaWire } from "./catalog.ts";
import { encodeType, decodeType, encodeAtom, decodeCell } from "./logical-values.ts";
import type { Descriptor, Atom, Cell as LogicalCell, Field } from "./logical-values.ts";
import type { Aggregate, Comparison } from "./query.ts";
import type {
  UnifiedQueryCodecAction,
  UnifiedQueryCodecResult,
  UnifiedQueryResult,
} from "./wire.ts";

export type Type = Descriptor;
export type Scalar = Atom;
export type Cell = LogicalCell;
export type State = Cell["state"];
export type Column = Field;
export type DecoderType = "int64" | "uint64" | "float64" | "boolean" | "utf8" | "binary";
export interface DecoderColumn {
  readonly name: string;
  readonly type: DecoderType;
}
export interface Decoder {
  readonly type: DecoderType;
  readonly version?: number;
}
export interface Projection {
  readonly column: DecoderColumn;
  readonly path?: readonly string[];
  readonly relative?: boolean;
  readonly mode?: "scalar" | "text" | "element_counter" | "element_replica";
  readonly textBytes?: number;
  readonly textSteps?: number;
}
export type Source =
  | {
      readonly kind: "kv";
      readonly resource: ResourceRef;
      readonly prefix: Uint8Array;
      readonly key: Decoder;
      readonly value: Decoder;
    }
  | {
      readonly kind: "table";
      readonly scope: Scope;
      readonly audience: number;
      readonly branch: bigint;
      readonly namespace: number;
      readonly interpretation: TableInterpretation;
      readonly schema: Schema;
    }
  | {
      readonly kind: "document";
      readonly reference: DocumentReference;
      readonly expand?: readonly string[];
      readonly projections: readonly Projection[];
    };
/** Accepted direct declaration and full schema commitments. */
export class TableInterpretation {
  readonly revision: bigint;
  readonly byteCount: bigint;
  readonly #digest: Uint8Array;
  readonly #schemaDigest: Uint8Array;
  constructor(revision: bigint, digest: Uint8Array, byteCount: bigint, schemaDigest: Uint8Array) {
    positive(revision);
    positive(byteCount);
    this.revision = revision;
    this.byteCount = byteCount;
    this.#digest = owned(digest, 32);
    this.#schemaDigest = owned(schemaDigest, 32);
    if (this.#digest.length !== 32 || this.#schemaDigest.length !== 32)
      throw new TypeError("Expected 32-byte commitments");
    Object.freeze(this);
  }
  get digest(): Uint8Array {
    return new Uint8Array(this.#digest);
  }
  get schemaDigest(): Uint8Array {
    return new Uint8Array(this.#schemaDigest);
  }
}
/** Service routing; the query client's caller, credential and role remain shared. */
export class Tables {
  readonly url: string;
  readonly scope: Scope;
  readonly branch: bigint;
  readonly audience: number;
  constructor(url: string, scope: Scope, branch: bigint, audience: number) {
    this.url = text(url, 2048);
    if (!(scope instanceof Scope)) throw new TypeError("Expected catalog scope");
    this.scope = scope;
    positive(branch);
    this.branch = branch;
    this.audience = integer(audience, "Table service audience");
    Object.freeze(this);
  }
}
/** One executor principal and an exact retained Table frontier. */
export class Capture {
  readonly executor: number;
  readonly operation: bigint;
  readonly partition: bigint;
  readonly nextLsn: bigint;
  constructor(executor: number, operation: bigint, partition: bigint, nextLsn: bigint) {
    this.executor = integer(executor, "executor principal");
    positive(operation);
    positive(partition);
    wide(nextLsn);
    this.operation = operation;
    this.partition = partition;
    this.nextLsn = nextLsn;
    Object.freeze(this);
  }
}
export class TableDefinition {
  readonly source: Extract<Source, { kind: "table" }>;
  readonly partition: bigint;
  readonly nextLsn: bigint;
  constructor(source: Extract<Source, { kind: "table" }>, partition: bigint, nextLsn: bigint) {
    sourceWire(source);
    positive(partition);
    wide(nextLsn);
    this.source = Object.freeze({ ...source });
    this.partition = partition;
    this.nextLsn = nextLsn;
    Object.freeze(this);
  }
  capture(executor: number, operation: bigint): Capture {
    return new Capture(executor, operation, this.partition, this.nextLsn);
  }
}
export type PredicateAtom =
  | { readonly kind: "state"; readonly column: number; readonly state: State }
  | {
      readonly kind: "compare";
      readonly column: number;
      readonly comparison: Comparison;
      readonly value: Scalar;
    };
export type PredicateInstruction =
  | { readonly kind: "atom"; readonly atom?: PredicateAtom }
  | { readonly kind: "negate" | "conjunction" | "disjunction" };
export type Predicate =
  | PredicateAtom
  | { readonly kind: "program"; readonly instructions: readonly PredicateInstruction[] };
export interface Plan {
  readonly projection: readonly number[];
  readonly outputNames?: readonly (string | null)[];
  readonly predicate?: Predicate;
  readonly limit?: bigint;
  readonly aggregate?: Aggregate;
}
export interface Budgets {
  readonly pages: bigint;
  readonly segments: bigint;
  readonly resultBytes: bigint;
}
type WireBundle = Extract<UnifiedQueryCodecAction, { prepare: unknown }>["prepare"];
type WireSource = WireBundle["source"];
type WireColumn = Extract<
  UnifiedQueryCodecAction,
  { inspect_arrow: unknown }
>["inspect_arrow"]["columns"][number];
function scalar(value: Scalar) {
  const result = encodeAtom(value);
  if (
    ("utf8" in result && Buffer.byteLength(result.utf8) > 4096) ||
    ("binary" in result && result.binary.length > 8192)
  )
    throw new TypeError("Query literal exceeds its 4096-byte bound");
  return result;
}
function fieldName(value: string): string {
  text(value, 255);
  if (!value.length || value.includes("\0") || Buffer.from(value).toString("utf8") !== value)
    throw new TypeError("Expected a UTF-8 column or source name");
  return value;
}
function column(value: Column): WireColumn {
  return {
    name: fieldName(value.name),
    type: encodeType(value.type),
    nullable: value.nullable ?? false,
    optional: value.optional ?? false,
  };
}
function fromColumn(value: WireColumn): Column {
  return Object.freeze({
    name: fieldName(value.name),
    type: decodeType(value.type),
    nullable: value.nullable,
    optional: value.optional,
  });
}
function path(value: readonly string[]): string[] {
  if (!Array.isArray(value) || value.length > 8)
    throw new TypeError("Expected at most eight path components");
  return value.map((name) => text(name, 64));
}
function resource(source: Source): ResourceRef {
  return source.kind === "document"
    ? source.reference.resource
    : source.kind === "table"
      ? source.scope.resource
      : source.resource;
}
function sourceWire(source: Source): WireSource {
  const id = resource(source);
  if (!(id instanceof ResourceRef)) throw new TypeError("Expected source resource");
  switch (source.kind) {
    case "kv":
      return {
        version: 1,
        resource: id.resource,
        source: {
          kv: {
            prefix: hex(source.prefix, 32),
            key: { type: source.key.type, version: source.key.version ?? 1 },
            value: { type: source.value.type, version: source.value.version ?? 1 },
          },
        },
      };
    case "table": {
      if (
        !(source.scope instanceof Scope) ||
        !(source.interpretation instanceof TableInterpretation) ||
        !(source.schema instanceof Schema)
      )
        throw new TypeError("Expected a direct Table interpretation and schema");
      return {
        version: 1,
        resource: id.resource,
        source: {
          table: {
            scope: {
              realm: id.realm,
              resource: id.resource,
              catalog: source.scope.catalog.toString(),
            },
            owner: integer(source.audience, "Table service audience"),
            branch: positive(source.branch),
            namespace: integer(source.namespace, "schema namespace"),
            object: source.schema.objectId.toString(),
            interpretation: {
              revision: source.interpretation.revision.toString(),
              digest: [...source.interpretation.digest],
              bytes: source.interpretation.byteCount.toString(),
              schema: [...source.interpretation.schemaDigest],
            },
            row_type: encodeType({
              kind: "structure",
              fields: source.schema.columns.map((field) => ({
                name: field.name,
                type: field.type,
                nullable: field.nullable ?? true,
                optional: false,
              })),
            }),
            collations: schemaWire(source.schema).columns.map((column) => column.collation),
          },
        },
      };
    }
    case "document": {
      const ref = source.reference;
      if (!(ref instanceof DocumentReference))
        throw new TypeError("Expected accepted Document reference");
      return {
        version: 1,
        resource: id.resource,
        source: {
          document: {
            reference: {
              resource: id.resource,
              document: ref.document.toString(),
              epoch: ref.epoch.toString(),
              type_revision: ref.typeRevision,
              revision: ref.revision.toString(),
            },
            change_format: 1,
            expand: source.expand === undefined ? null : path(source.expand),
            projections: source.projections.map((v) => ({
              column: { name: text(v.column.name, 32), type: v.column.type },
              path: path(v.path ?? []),
              relative: v.relative ?? false,
              mode: v.mode ?? "scalar",
              text_bytes: v.textBytes ?? 4096,
              text_steps: v.textSteps ?? 4096,
            })),
          },
        },
      };
    }
  }
}
type WirePredicate = NonNullable<WireBundle["plan"]["predicate"]>;
function atomWire(
  selected: PredicateAtom | undefined,
): Exclude<WirePredicate, { program: unknown }> {
  if (selected === undefined) return { all: {} };
  if (selected?.kind === "state")
    return { state: { column: integer(selected.column, "column", 0, 127), value: selected.state } };
  if (selected?.kind === "compare")
    return {
      compare: {
        column: integer(selected.column, "column", 0, 127),
        op: selected.comparison,
        value: scalar(selected.value),
      },
    };
  throw new TypeError("Expected a non-program predicate atom");
}
function predicateWire(selected: Predicate | undefined): WirePredicate {
  if (selected?.kind !== "program") return atomWire(selected);
  if (
    !Array.isArray(selected.instructions) ||
    selected.instructions.length < 1 ||
    selected.instructions.length > 64
  )
    throw new TypeError("Expected one to 64 predicate instructions");
  return {
    program: selected.instructions.map((instruction) => {
      switch (instruction?.kind) {
        case "atom":
          return { atom: atomWire(instruction.atom) };
        case "negate":
          return { negate: {} };
        case "conjunction":
          return { conjunction: {} };
        case "disjunction":
          return { disjunction: {} };
        default:
          throw new TypeError("Expected a predicate atom or operator");
      }
    }),
  };
}
export function planWire(plan: Plan): WireBundle["plan"] {
  if (!Array.isArray(plan.projection) || plan.projection.length < 1 || plan.projection.length > 128)
    throw new TypeError("Expected one to 128 projection indices");
  if (
    plan.outputNames !== undefined &&
    (!Array.isArray(plan.outputNames) || plan.outputNames.length !== plan.projection.length)
  )
    throw new TypeError("Output names must match the projection width");
  return {
    version: 1,
    projection: plan.projection.map((v) => integer(v, "column", 0, 127)),
    output_names:
      plan.outputNames === undefined
        ? null
        : plan.outputNames.map((v) => (v === null ? null : fieldName(v))),
    predicate: predicateWire(plan.predicate),
    limit: plan.limit === undefined ? null : wide(plan.limit).toString(),
    aggregate: plan.aggregate ?? "rows",
  };
}
function positive(value: bigint): string {
  if (wide(value) === 0n) throw new TypeError("Expected positive budget or namespace");
  return value.toString();
}
async function codec(
  action: UnifiedQueryCodecAction,
  nativeHost?: string,
): Promise<UnifiedQueryCodecResult> {
  const owner = await Bridge.local(nativeHost);
  try {
    return await owner.unifiedCodec(action);
  } finally {
    await owner.close();
  }
}
/** Canonical finite bytes, prepared locally through the shared Zig implementation. */
export class Bundle {
  readonly #data: Uint8Array;
  constructor(data: Uint8Array) {
    this.#data = owned(data, contract.limits.query_bundle_bytes);
    Object.freeze(this);
  }
  get data(): Uint8Array {
    return new Uint8Array(this.#data);
  }
  static async prepare(
    source: Source,
    plan: Plan,
    budgets: Budgets,
    nativeHost?: string,
  ): Promise<Bundle> {
    const declaration = sourceWire(source);
    const parameters = planWire(plan);
    if ("table" in declaration.source) parameters.collations = declaration.source.table.collations;
    const value = await codec(
      {
        prepare: {
          source: declaration,
          plan: parameters,
          limits: {
            pages: positive(budgets.pages),
            segments: positive(budgets.segments),
            result_bytes: positive(budgets.resultBytes),
          },
        },
      },
      nativeHost,
    );
    if (!("prepared" in value)) throw new IncompatibleNative("Expected prepared bundle");
    return new Bundle(unhex(value.prepared.bytes, contract.limits.query_bundle_bytes));
  }
}
/** Local decoding does not establish current source access or result completeness. */
export async function decodeArrow(
  columns: readonly Column[],
  ipc: Uint8Array,
  rows: number,
  nativeHost?: string,
): Promise<readonly (readonly Cell[])[]> {
  const value = await codec(
    {
      inspect_arrow: {
        columns: columns.map(column),
        ipc: hex(ipc, 65536),
        rows: integer(rows, "rows", 0, 8),
      },
    },
    nativeHost,
  );
  if (!("rows" in value)) throw new IncompatibleNative("Expected decoded Arrow rows");
  return Object.freeze(
    value.rows.map((row) => Object.freeze(row.map((cell) => Object.freeze(decodeCell(cell))))),
  );
}
export class Connection {
  readonly source: ProcessRef;
  readonly resource: ResourceRef;
  readonly requester: ProcessRef;
  readonly requests: ResourceRef;
  readonly role: number | undefined;
  constructor(
    source: ProcessRef,
    resource: ResourceRef,
    requester: ProcessRef,
    requests: ResourceRef,
    role?: number,
  ) {
    if (
      !(source instanceof ProcessRef) ||
      !(requester instanceof ProcessRef) ||
      !(resource instanceof ResourceRef) ||
      !(requests instanceof ResourceRef) ||
      new Set([source.realm, resource.realm, requester.realm, requests.realm]).size !== 1
    )
      throw new TypeError("Query connection requires one realm");
    this.source = source;
    this.resource = resource;
    this.requester = requester;
    this.requests = requests;
    this.role = role === undefined ? undefined : integer(role, "selected role", 0);
    Object.freeze(this);
  }
}
/** Persist data before dispatch. It must remain opaque, including after restart. */
export class Prepared {
  readonly #data: string;
  constructor(data: string) {
    this.#data = text(data, 8192);
    Object.freeze(this);
  }
  get data(): string {
    return this.#data;
  }
}
export class Uncertain extends UnknownOutcome {
  readonly prepared: Prepared;
  constructor(prepared: Prepared, cause: UnknownOutcome) {
    super("Query admission is uncertain; retain the identical prepared command", {
      status: 6,
      ...(cause.code === undefined ? {} : { code: cause.code }),
      ...(cause.diagnostic === undefined ? {} : { diagnostic: cause.diagnostic }),
      diagnosticInvalid: cause.diagnosticInvalid,
      phase: "submit-query",
    });
    this.prepared = prepared;
  }
}
/** Verification progress, never an authorization token. */
export class Cursor {
  readonly #data: string;
  constructor(data: string) {
    this.#data = text(data, 4096);
    Object.freeze(this);
  }
  get data(): string {
    return this.#data;
  }
}
export type Phase =
  | "uploading"
  | "sealed"
  | "admitted"
  | "prepared"
  | "complete"
  | "cancelled"
  | "denied"
  | "rejected"
  | "retired";
export interface Failure {
  readonly code: string;
  readonly stage: "admission" | "execution";
  readonly dimension: "none" | "pages" | "segments" | "result_bytes";
  readonly limit: bigint;
  readonly observed: bigint;
}
export type Diagnostic = NonNullable<
  NonNullable<Extract<UnifiedQueryResult, { status: unknown }>["status"]>["diagnostic"]
>;
export interface Status {
  readonly phase: Phase;
  readonly correlation: bigint;
  readonly reference: Uint8Array;
  readonly manifest: Uint8Array | undefined;
  readonly collected: boolean;
  readonly failure: Failure | null;
  readonly diagnostic: Diagnostic | null;
}
export type Observation =
  | { readonly state: "pending" | "committed" }
  | { readonly state: "rejected"; readonly reason: string };
export interface Description {
  readonly resourceRevision: number;
  readonly policyRevision: bigint;
  readonly limits: Budgets;
  readonly active: bigint | undefined;
  readonly bundleBytes: number;
  readonly segmentBytes: number;
  readonly batchRows: number;
}
export type InspectedAtom =
  | { readonly kind: "state"; readonly column: string; readonly state: State }
  | {
      readonly kind: "compare";
      readonly column: string;
      readonly comparison: Comparison;
      readonly type: Type;
    };
export type InspectedInstruction =
  | { readonly kind: "atom"; readonly atom: InspectedAtom | undefined }
  | { readonly kind: "negate" | "conjunction" | "disjunction" };
export type InspectedPredicate =
  | InspectedAtom
  | {
      readonly kind: "program";
      readonly instructions: readonly InspectedInstruction[];
    };
type WireInspection = Extract<UnifiedQueryResult, { inspection: unknown }>["inspection"];
type WireInspectedPredicate = Extract<
  WireInspection["details"],
  { explanation: unknown }
>["explanation"]["predicate"];
function inspectedAtom(
  predicate: Exclude<WireInspectedPredicate, { program: unknown }>,
): InspectedAtom | undefined {
  if ("all" in predicate) return undefined;
  if ("state" in predicate)
    return Object.freeze({
      kind: "state",
      column: predicate.state.column,
      state: predicate.state.value,
    });
  if (!("compare" in predicate)) throw new IncompatibleNative("Unsupported inspected predicate");
  return Object.freeze({
    kind: "compare",
    column: predicate.compare.column,
    comparison: predicate.compare.op,
    type: decodeType(predicate.compare.type),
  });
}
function inspectedPredicate(predicate: WireInspectedPredicate): InspectedPredicate | undefined {
  if (!("program" in predicate)) return inspectedAtom(predicate);
  if (predicate.program.length === 0 || predicate.program.length > 64)
    throw new IncompatibleNative("Invalid inspected program size");
  let depth = 0;
  const instructions = predicate.program.map((instruction): InspectedInstruction => {
    if ("atom" in instruction) {
      depth++;
      return Object.freeze({ kind: "atom", atom: inspectedAtom(instruction.atom) });
    }
    if ("negate" in instruction) {
      if (depth === 0) throw new IncompatibleNative("Invalid inspected program shape");
      return Object.freeze({ kind: "negate" });
    }
    if (depth < 2) throw new IncompatibleNative("Invalid inspected program shape");
    depth--;
    return Object.freeze({ kind: "conjunction" in instruction ? "conjunction" : "disjunction" });
  });
  if (depth !== 1) throw new IncompatibleNative("Invalid inspected program shape");
  return Object.freeze({ kind: "program", instructions: Object.freeze(instructions) });
}
export type InspectionDetails =
  | { readonly kind: "description"; readonly columns: readonly Column[] }
  | { readonly kind: "tables"; readonly names: readonly string[] }
  | {
      readonly kind: "explanation";
      readonly operators: readonly (
        | "scan"
        | "filter"
        | "limit"
        | "project"
        | "count"
        | "sum"
        | "count_values"
      )[];
      readonly predicate: InspectedPredicate | undefined;
      readonly projection: readonly string[];
      readonly limit: bigint | undefined;
      readonly aggregate: Aggregate;
      readonly columns: readonly Column[];
      readonly budgets: Budgets;
    };
export interface Inspection {
  readonly name: string;
  readonly resource: ResourceRef;
  readonly sourceKind: "kv" | "table" | "document";
  readonly sourceDigest: Uint8Array;
  readonly schemaDigest: Uint8Array;
  readonly resourceRevision: number;
  readonly policyRevision: bigint;
  readonly details: InspectionDetails;
}
function inspection(
  value: Extract<UnifiedQueryResult, { inspection: unknown }>["inspection"],
  expected: ResourceRef,
): Inspection {
  if (
    value.version !== 1 ||
    value.scope !== "configured_source" ||
    value.resource !== expected.resource
  )
    throw new IncompatibleNative("Invalid SQL inspection scope");
  const input = value.details;
  let details: InspectionDetails;
  if ("description" in input)
    details = Object.freeze({
      kind: "description",
      columns: Object.freeze(input.description.columns.map((v) => fromColumn(v))),
    });
  else if ("tables" in input)
    details = Object.freeze({ kind: "tables", names: Object.freeze([...input.tables]) });
  else {
    const plan = input.explanation;
    const inspected = inspectedPredicate(plan.predicate);
    if (plan.operators.length < 2 || plan.operators.length > 4)
      throw new IncompatibleNative("Invalid inspected operators");
    details = Object.freeze({
      kind: "explanation",
      operators: Object.freeze([...plan.operators]),
      predicate: inspected,
      projection: Object.freeze([...plan.projection]),
      limit: plan.limit === null ? undefined : nativeWide(plan.limit),
      aggregate: plan.aggregate,
      columns: Object.freeze(plan.columns.map((v) => fromColumn(v))),
      budgets: Object.freeze({
        pages: nativeWide(plan.budgets.pages),
        segments: nativeWide(plan.budgets.segments),
        resultBytes: nativeWide(plan.budgets.result_bytes),
      }),
    });
  }
  return Object.freeze({
    name: value.name,
    resource: expected,
    sourceKind: value.source_kind,
    sourceDigest: digest(value.contract),
    schemaDigest: digest(value.schema),
    resourceRevision: integer(value.resource_revision, "revision", 0),
    policyRevision: nativeWide(value.policy_revision),
    details,
  });
}
export type Cut =
  | { readonly kind: "native"; readonly revision: number }
  | { readonly kind: "table"; readonly commitment: Uint8Array };
export interface Manifest {
  readonly job: number;
  readonly source: ReadVersion | ProcessRef;
  readonly requester: ProcessRef;
  readonly correlation: bigint;
  readonly policyRevision: bigint;
  readonly request: Uint8Array;
  readonly sourceKind: "kv" | "table" | "document";
  readonly resource: ResourceRef;
  readonly cut: Cut;
  readonly sourceDigest: Uint8Array;
  readonly schemaDigest: Uint8Array;
  readonly planDigest: Uint8Array;
  readonly tablePosition:
    | Readonly<{
        resource: ResourceRef;
        partition: bigint;
        accepted: bigint;
        contract: Uint8Array;
        schema: Uint8Array;
      }>
    | undefined;
  readonly pages: bigint;
  readonly scanned: bigint;
  readonly selected: bigint;
  readonly valueCount: bigint;
  readonly segments: bigint;
  readonly rows: bigint;
  readonly byteCount: bigint;
  readonly sum: bigint | undefined;
  readonly finished: "source_end" | "limit";
  readonly chain: Uint8Array;
}
export class Page {
  readonly #ipc: Uint8Array;
  readonly manifest: Manifest;
  readonly columns: readonly Column[];
  readonly ordinal: bigint;
  readonly rows: number;
  readonly next: Cursor | undefined;
  constructor(
    manifest: Manifest,
    columns: readonly Column[],
    ordinal: bigint,
    rows: number,
    ipc: Uint8Array,
    next: Cursor | undefined,
  ) {
    this.manifest = manifest;
    this.columns = columns;
    this.ordinal = ordinal;
    this.rows = rows;
    this.next = next;
    this.#ipc = owned(ipc, 65536);
    Object.freeze(this);
  }
  get ipc(): Uint8Array {
    return new Uint8Array(this.#ipc);
  }
  decode(nativeHost?: string): Promise<readonly (readonly Cell[])[]> {
    return decodeArrow(this.columns, this.#ipc, this.rows, nativeHost);
  }
}
function digest(value: number[]): Uint8Array {
  if (value.length !== 32 || value.some((v) => !Number.isInteger(v) || v < 0 || v > 255))
    throw new IncompatibleNative("Invalid manifest commitment");
  return new Uint8Array(value);
}
type WirePage = Extract<UnifiedQueryResult, { page: unknown }>["page"];
function page(value: WirePage, realm: number): Page {
  const m = value.manifest;
  if (m.finished === null) throw new IncompatibleNative("Result manifest is unfinished");
  const position = m.basis.cut.position;
  let source: ReadVersion | ProcessRef;
  let cut: Cut;
  if (m.basis.cut.kind === "table") {
    if (!("table" in m.source) || !("table" in position))
      throw new IncompatibleNative("Invalid direct Table cut");
    source = new ProcessRef(realm, m.source.table.worker);
    cut = Object.freeze({ kind: "table", commitment: digest(position.table) });
  } else {
    if (!("native" in m.source) || !("native_revision" in position))
      throw new IncompatibleNative("Invalid native source cut");
    source = new ReadVersion(m.source.native.pid, m.source.native.input, m.source.native.index);
    cut = Object.freeze({
      kind: "native",
      revision: integer(position.native_revision, "native resource revision", 0),
    });
  }
  const tablePosition =
    m.table_position === null
      ? undefined
      : Object.freeze({
          resource: new ResourceRef(realm, m.table_position.resource),
          partition: nativeWide(m.table_position.partition),
          accepted: nativeWide(m.table_position.accepted),
          contract: digest(m.table_position.contract),
          schema: digest(m.table_position.schema),
        });
  if (
    tablePosition !== undefined &&
    (cut.kind !== "table" ||
      tablePosition.resource.resource !== m.basis.cut.resource ||
      tablePosition.partition === 0n ||
      tablePosition.accepted === 0n ||
      !tablePosition.contract.every((v, i) => v === m.basis.contract[i]) ||
      !tablePosition.schema.every((v, i) => v === m.basis.schema[i]))
  )
    throw new IncompatibleNative("Invalid Table result position");
  const manifest: Manifest = Object.freeze({
    job: integer(m.job, "job"),
    source,
    requester: new ProcessRef(realm, m.requester),
    correlation: nativeWide(m.correlation),
    policyRevision: nativeWide(m.policy_revision),
    request: unhex(m.request, 72),
    sourceKind: m.basis.cut.kind,
    resource: new ResourceRef(realm, m.basis.cut.resource),
    cut,
    sourceDigest: digest(m.basis.contract),
    schemaDigest: digest(m.basis.schema),
    planDigest: digest(m.plan),
    tablePosition,
    pages: nativeWide(m.pages),
    scanned: nativeWide(m.scanned),
    selected: nativeWide(m.selected),
    valueCount: nativeWide(m.value_count),
    segments: nativeWide(m.segments),
    rows: nativeWide(m.rows),
    byteCount: nativeWide(m.bytes),
    sum: m.sum === null ? undefined : BigInt(m.sum),
    finished: m.finished,
    chain: digest(m.chain),
  });
  return new Page(
    manifest,
    Object.freeze(value.columns.map((v) => fromColumn(v))),
    nativeWide(value.ordinal),
    integer(value.rows, "rows", 0, 8),
    unhex(value.ipc, 65536),
    value.next === null ? undefined : new Cursor(value.next),
  );
}
/** One native port, one in-flight operation; close joins before releasing ownership. */
export class Client {
  readonly connection: Connection;
  private readonly bridge: QueryBridge;
  private constructor(connection: Connection, bridge: QueryBridge) {
    this.connection = connection;
    this.bridge = bridge;
  }
  static async open(
    input: ClientConfig,
    credential: Credential,
    connection: Connection,
    tables?: Tables,
  ): Promise<Client> {
    const config = configuration(input);
    if (
      !(connection instanceof Connection) ||
      !(credential instanceof Credential) ||
      credential.realm !== connection.source.realm
    )
      throw new TypeError("Query credential must match the connection realm");
    if (
      tables !== undefined &&
      (!(tables instanceof Tables) || tables.scope.resource.realm !== credential.realm)
    )
      throw new TypeError("Direct Table service must use the query realm");
    const bridge = await QueryBridge.open(
      config.url,
      credential.seedFile,
      {
        connection: {
          realm: credential.realm,
          principal: credential.principal,
          source: connection.source.pid,
          resource: connection.resource.resource,
          requester: connection.requester.pid,
          requests: connection.requests.resource,
          role: connection.role ?? null,
        },
        timeout_ms: config.timeoutMs,
        tables:
          tables === undefined
            ? null
            : {
                url: tables.url,
                connection: {
                  scope: {
                    realm: tables.scope.resource.realm,
                    resource: tables.scope.resource.resource,
                    catalog: tables.scope.catalog.toString(),
                  },
                  branch: tables.branch.toString(),
                  audience: tables.audience,
                  principal: credential.principal,
                  role: connection.role ?? null,
                },
              },
      },
      config.nativeHost,
    );
    return new Client(connection, bridge);
  }
  /** Current direct definition and frontier; no pin acquisition or query admission. */
  async lookupTable(name: string, namespace = 1): Promise<TableDefinition | undefined> {
    const value = await this.bridge.call({
      table: { namespace: integer(namespace, "schema namespace"), name: fieldName(name) },
    });
    if (!("table" in value)) throw new IncompatibleNative("Expected direct Table definition");
    if (value.table === null) return undefined;
    const found = value.table;
    if (!("table" in found.source.source))
      throw new IncompatibleNative("Expected direct Table source");
    const direct = found.source.source.table;
    const scope = new Scope(
      new ResourceRef(direct.scope.realm, direct.scope.resource),
      nativeWide(direct.scope.catalog),
    );
    const schema = schemaValue(found.schema);
    if (
      found.source.version !== 1 ||
      found.source.resource !== scope.resource.resource ||
      nativeWide(direct.object) !== schema.objectId
    )
      throw new IncompatibleNative("Inconsistent direct Table definition");
    const source = {
      kind: "table" as const,
      scope,
      audience: direct.owner,
      branch: nativeWide(direct.branch),
      namespace: direct.namespace,
      interpretation: new TableInterpretation(
        nativeWide(direct.interpretation.revision),
        digest(direct.interpretation.digest),
        nativeWide(direct.interpretation.bytes),
        digest(direct.interpretation.schema),
      ),
      schema,
    };
    // Both descriptors come from one response and must describe the same rows.
    const expected = sourceWire(source).source;
    if (
      !("table" in expected) ||
      JSON.stringify(encodeType(decodeType(expected.table.row_type))) !==
        JSON.stringify(encodeType(decodeType(direct.row_type))) ||
      JSON.stringify(expected.table.collations) !== JSON.stringify(direct.collations)
    )
      throw new IncompatibleNative("Inconsistent direct Table row type or collations");
    return new TableDefinition(
      source,
      nativeWide(found.expected.partition),
      nativeWide(found.expected.next_lsn),
    );
  }
  async describe(source: Source): Promise<Description> {
    const id = resource(source);
    if (
      id.realm !== this.connection.resource.realm ||
      (source.kind !== "table" && id.resource !== this.connection.resource.resource)
    )
      throw new TypeError("Source differs from the connection");
    const value = await this.bridge.call({ describe: sourceWire(source) });
    if (!("description" in value)) throw new IncompatibleNative("Expected query description");
    const v = value.description;
    return Object.freeze({
      resourceRevision: integer(v.resource_revision, "revision", 0),
      policyRevision: nativeWide(v.policy_revision),
      limits: Object.freeze({
        pages: nativeWide(v.limits.pages),
        segments: nativeWide(v.limits.segments),
        resultBytes: nativeWide(v.limits.result_bytes),
      }),
      active: v.active === null ? undefined : nativeWide(v.active),
      bundleBytes: v.capabilities.bundle_bytes,
      segmentBytes: v.capabilities.segment_bytes,
      batchRows: v.capabilities.batch_rows,
    });
  }
  /** Current configured-source metadata; no snapshot, upload or admission. */
  async inspectSql(
    source: Source,
    name: string,
    sql: string,
    budgets: Budgets,
  ): Promise<Inspection> {
    const id = resource(source);
    if (
      id.realm !== this.connection.resource.realm ||
      (source.kind !== "table" && id.resource !== this.connection.resource.resource)
    )
      throw new TypeError("Source differs from the connection");
    const value = await this.bridge.call({
      inspect: {
        scope: {
          name: fieldName(name),
          source: sourceWire(source),
          limits: {
            pages: positive(budgets.pages),
            segments: positive(budgets.segments),
            result_bytes: positive(budgets.resultBytes),
          },
        },
        sql: text(sql, 4096),
      },
    });
    if (!("inspection" in value)) throw new IncompatibleNative("Expected SQL inspection");
    return inspection(value.inspection, id);
  }
  /** Compile an owned finite bundle; binding never uploads or admits a query. */
  async compileSql(
    source: Source,
    name: string,
    sql: string,
    budgets: Budgets,
    parameters?: readonly Scalar[],
  ): Promise<Bundle> {
    const id = resource(source);
    if (
      id.realm !== this.connection.resource.realm ||
      (source.kind !== "table" && id.resource !== this.connection.resource.resource)
    )
      throw new TypeError("Source differs from the connection");
    if (parameters !== undefined && (!Array.isArray(parameters) || parameters.length > 65))
      throw new TypeError("Expected at most 65 parameter atoms");
    const value = await this.bridge.call({
      compile: {
        scope: {
          name: fieldName(name),
          source: sourceWire(source),
          limits: {
            pages: positive(budgets.pages),
            segments: positive(budgets.segments),
            result_bytes: positive(budgets.resultBytes),
          },
        },
        sql: text(sql, 4096),
        parameters: parameters === undefined ? null : parameters.map(scalar),
      },
    });
    if (!("compiled" in value)) throw new IncompatibleNative("Expected compiled SQL bundle");
    return new Bundle(unhex(value.compiled.bundle, contract.limits.query_bundle_bytes));
  }
  /** Seal new work once before saving its bytes or fingerprint. Recover saved work unchanged. */
  async authorizeBundle(bundle: Bundle, capture?: Capture): Promise<Bundle> {
    if (!(bundle instanceof Bundle)) throw new TypeError("Expected query bundle");
    if (capture !== undefined && !(capture instanceof Capture))
      throw new TypeError("Expected explicit Table capture");
    const value = await this.bridge.call({
      authorize: {
        bundle: hex(bundle.data, contract.limits.query_bundle_bytes),
        capture:
          capture === undefined
            ? null
            : {
                executor: capture.executor,
                operation: capture.operation.toString(),
                expected: {
                  partition: capture.partition.toString(),
                  next_lsn: capture.nextLsn.toString(),
                },
              },
      },
    });
    if (!("authorized" in value)) throw new IncompatibleNative("Expected authorized query bundle");
    return new Bundle(unhex(value.authorized, contract.limits.query_bundle_bytes));
  }
  /** Fresh terminal cleanup authority preserves the original execution proof and cut. */
  async prepareCleanup(namespace: bigint, bundle: Bundle): Promise<Prepared> {
    if (!(bundle instanceof Bundle)) throw new TypeError("Expected original query bundle");
    const value = await this.bridge.call({
      cleanup: {
        namespace: positive(namespace),
        bundle: hex(bundle.data, contract.limits.query_bundle_bytes),
      },
    });
    if (!("prepared" in value) || value.prepared === null)
      throw new IncompatibleNative("Expected cleanup command");
    return new Prepared(value.prepared);
  }
  async prepareNext(namespace: bigint, bundle: Bundle): Promise<Prepared | undefined> {
    if (!(bundle instanceof Bundle)) throw new TypeError("Expected query bundle");
    const value = await this.bridge.call({
      next: {
        namespace: positive(namespace),
        bundle: hex(bundle.data, contract.limits.query_bundle_bytes),
      },
    });
    if (!("prepared" in value)) throw new IncompatibleNative("Expected prepared command");
    return value.prepared === null ? undefined : new Prepared(value.prepared);
  }
  private async control(
    name: "cancel" | "collect" | "retire",
    namespace: bigint,
  ): Promise<Prepared> {
    const id = positive(namespace);
    const value = await this.bridge.call({
      prepare:
        name === "cancel" ? { cancel: id } : name === "collect" ? { collect: id } : { retire: id },
    });
    if (!("prepared" in value) || value.prepared === null)
      throw new IncompatibleNative("Expected prepared command");
    return new Prepared(value.prepared);
  }
  prepareCancel(namespace: bigint): Promise<Prepared> {
    return this.control("cancel", namespace);
  }
  prepareRetire(namespace: bigint): Promise<Prepared> {
    return this.control("retire", namespace);
  }
  prepareCollect(namespace: bigint): Promise<Prepared> {
    return this.control("collect", namespace);
  }
  async submit(prepared: Prepared): Promise<AdmissionReceipt> {
    if (!(prepared instanceof Prepared)) throw new TypeError("Expected persisted prepared command");
    try {
      const value = await this.bridge.call({ submit: prepared.data });
      if (!("receipt" in value)) throw new UnknownOutcome("Missing admission receipt");
      return new AdmissionReceipt(value.receipt.position);
    } catch (error) {
      if (error instanceof UnknownOutcome) throw new Uncertain(prepared, error);
      throw error;
    }
  }
  async observe(position: number): Promise<Observation> {
    const value = await this.bridge.call({ observe: integer(position, "input position") });
    if (!("observation" in value)) throw new IncompatibleNative("Expected admission observation");
    const v = value.observation;
    if ("pending" in v) return Object.freeze({ state: "pending" });
    if ("committed" in v) return Object.freeze({ state: "committed" });
    return Object.freeze({
      state: "rejected",
      reason: new TextDecoder("utf-8", { fatal: true }).decode(unhex(v.rejected, 256)),
    });
  }
  async status(namespace: bigint): Promise<Status | undefined> {
    const value = await this.bridge.call({ status: positive(namespace) });
    if (!("status" in value)) throw new IncompatibleNative("Expected query status");
    const v = value.status;
    return v === null
      ? undefined
      : Object.freeze({
          phase: v.phase,
          correlation: nativeWide(v.correlation),
          reference: unhex(v.reference, 72),
          manifest: v.manifest === null ? undefined : unhex(v.manifest, 72),
          collected: v.collected,
          diagnostic: v.diagnostic,
          failure:
            v.failure === null
              ? null
              : Object.freeze({
                  ...v.failure,
                  limit: BigInt(v.failure.limit),
                  observed: BigInt(v.failure.observed),
                }),
        });
  }
  async page(namespace: bigint, cursor?: Cursor): Promise<Page> {
    if (cursor !== undefined && !(cursor instanceof Cursor))
      throw new TypeError("Expected query continuation");
    const value = await this.bridge.call({
      page: { namespace: positive(namespace), cursor: cursor?.data ?? null },
    });
    if (!("page" in value)) throw new IncompatibleNative("Expected result page");
    return page(value.page, this.connection.source.realm);
  }
  close(): Promise<void> {
    return this.bridge.close();
  }
}
