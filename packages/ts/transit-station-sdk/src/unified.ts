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
import type { Aggregate, Comparison } from "./query.ts";
import type {
  UnifiedQueryCodecAction,
  UnifiedQueryCodecResult,
  UnifiedQueryResult,
} from "./wire.ts";

export type Type = "int64" | "uint64" | "float64" | "boolean" | "utf8" | "binary";
export type State = "missing" | "null" | "type_error" | "value" | "conflict";
export type Scalar =
  | { readonly type: "int64" | "uint64"; readonly value: bigint }
  | { readonly type: "float64"; readonly value: number }
  | { readonly type: "boolean"; readonly value: boolean }
  | { readonly type: "utf8"; readonly value: string }
  | { readonly type: "binary"; readonly value: Uint8Array };
export interface Column {
  readonly name: string;
  readonly type: Type;
}
export interface Decoder {
  readonly type: Type;
  readonly version?: number;
}
export interface Projection {
  readonly column: Column;
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
      readonly resource: ResourceRef;
      readonly table: number;
      readonly names: readonly [string, string];
      readonly valueType: "int64" | "boolean" | "utf8" | "binary";
    }
  | {
      readonly kind: "document";
      readonly reference: DocumentReference;
      readonly expand?: readonly string[];
      readonly projections: readonly Projection[];
    };
export type Predicate =
  | { readonly kind: "state"; readonly column: number; readonly state: State }
  | {
      readonly kind: "compare";
      readonly column: number;
      readonly comparison: Comparison;
      readonly value: Scalar;
    };
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
export interface Alternative {
  readonly counter: bigint;
  readonly replica: bigint;
  readonly state: "null" | "type_error" | "value";
  readonly value?: Scalar;
  readonly actualKind?: string;
}
export type Cell =
  | { readonly state: "missing" }
  | { readonly state: "null" }
  | { readonly state: "type_error"; readonly actualKind: string }
  | { readonly state: "value"; readonly value: Scalar }
  | { readonly state: "conflict"; readonly alternatives: readonly Alternative[] };
type WireBundle = Extract<UnifiedQueryCodecAction, { prepare: unknown }>["prepare"];
type WireSource = WireBundle["source"];
type WireScalar = Extract<
  NonNullable<WireBundle["plan"]["predicate"]>,
  { compare: unknown }
>["compare"]["value"];
type WireCell = Extract<UnifiedQueryCodecResult, { rows: unknown }>["rows"][number][number];
function scalar(value: Scalar): WireScalar {
  switch (value?.type) {
    case "int64":
      if (typeof value.value !== "bigint" || value.value < -(1n << 63n) || value.value >= 1n << 63n)
        throw new TypeError("Expected int64");
      return { int64: value.value.toString() };
    case "uint64":
      return { uint64: wide(value.value).toString() };
    case "float64": {
      if (typeof value.value !== "number" || !Number.isFinite(value.value))
        throw new TypeError("Expected finite float64");
      const bytes = new Uint8Array(8);
      new DataView(bytes.buffer).setFloat64(0, value.value, true);
      return { float_bits: hex(bytes, 8) };
    }
    case "boolean":
      if (typeof value.value !== "boolean") throw new TypeError("Expected boolean");
      return { boolean: value.value };
    case "utf8":
      return { utf8: text(value.value, 4096) };
    case "binary":
      return { binary: hex(value.value, 4096) };
    default:
      throw new TypeError("Expected typed query scalar");
  }
}
function fromScalar(value: WireScalar): Scalar {
  let out: Scalar;
  if ("int64" in value) out = { type: "int64", value: BigInt(value.int64) };
  else if ("uint64" in value) out = { type: "uint64", value: nativeWide(value.uint64) };
  else if ("float_bits" in value) {
    const bytes = unhex(value.float_bits, 8);
    if (bytes.length !== 8) throw new IncompatibleNative("Invalid float width");
    out = {
      type: "float64",
      value: new DataView(bytes.buffer, bytes.byteOffset, 8).getFloat64(0, true),
    };
  } else if ("boolean" in value) out = { type: "boolean", value: value.boolean };
  else if ("utf8" in value) out = { type: "utf8", value: value.utf8 };
  else out = { type: "binary", value: unhex(value.binary, 4096) };
  scalar(out);
  return Object.freeze(out);
}
function fromCell(value: WireCell): Cell {
  if ("missing" in value) return Object.freeze({ state: "missing" });
  if ("null" in value) return Object.freeze({ state: "null" });
  if ("type_error" in value)
    return Object.freeze({ state: "type_error", actualKind: value.type_error });
  if ("value" in value) return Object.freeze({ state: "value", value: fromScalar(value.value) });
  return Object.freeze({
    state: "conflict",
    alternatives: Object.freeze(
      value.conflict.map((item): Alternative => {
        const selected = fromCell(item.value);
        if (selected.state === "missing" || selected.state === "conflict")
          throw new IncompatibleNative("Invalid conflict alternative");
        return Object.freeze({
          ...selected,
          counter: nativeWide(item.counter),
          replica: nativeWide(item.replica),
        });
      }),
    ),
  });
}
function path(value: readonly string[]): string[] {
  if (!Array.isArray(value) || value.length > 8)
    throw new TypeError("Expected at most eight path components");
  return value.map((name) => text(name, 64));
}
function column(value: Column): Column {
  return { name: text(value.name, 64), type: value.type };
}
function resource(source: Source): ResourceRef {
  return source.kind === "document" ? source.reference.resource : source.resource;
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
    case "table":
      return {
        version: 1,
        resource: id.resource,
        source: {
          table: {
            id: integer(source.table, "table", 1, 0xffffffff),
            names: [...source.names],
            value_type: source.valueType,
          },
        },
      };
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
              column: column(v.column),
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
function planWire(plan: Plan): WireBundle["plan"] {
  if (!Array.isArray(plan.projection) || plan.projection.length < 1 || plan.projection.length > 8)
    throw new TypeError("Expected one to eight projection indices");
  if (
    plan.outputNames !== undefined &&
    (!Array.isArray(plan.outputNames) || plan.outputNames.length !== plan.projection.length)
  )
    throw new TypeError("Output names must match the projection width");
  let predicate: NonNullable<WireBundle["plan"]["predicate"]> = { all: {} };
  const selected = plan.predicate;
  if (selected?.kind === "state")
    predicate = {
      state: { column: integer(selected.column, "column", 0, 7), value: selected.state },
    };
  else if (selected?.kind === "compare")
    predicate = {
      compare: {
        column: integer(selected.column, "column", 0, 7),
        op: selected.comparison,
        value: scalar(selected.value),
      },
    };
  else if (selected !== undefined) throw new TypeError("Expected query predicate");
  return {
    version: 1,
    projection: plan.projection.map((v) => integer(v, "column", 0, 7)),
    output_names:
      plan.outputNames === undefined
        ? null
        : plan.outputNames.map((v) => (v === null ? null : text(v, 32))),
    predicate,
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
    this.#data = owned(data, 16384);
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
    const value = await codec(
      {
        prepare: {
          source: sourceWire(source),
          plan: planWire(plan),
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
    return new Bundle(unhex(value.prepared.bytes, 16384));
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
  return Object.freeze(value.rows.map((row) => Object.freeze(row.map(fromCell))));
}
export class Connection {
  readonly source: ProcessRef;
  readonly resource: ResourceRef;
  readonly requester: ProcessRef;
  readonly requests: ResourceRef;
  constructor(
    source: ProcessRef,
    resource: ResourceRef,
    requester: ProcessRef,
    requests: ResourceRef,
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
  | "complete"
  | "cancelled"
  | "denied"
  | "rejected"
  | "retired";
export interface Status {
  readonly phase: Phase;
  readonly correlation: bigint;
  readonly reference: Uint8Array;
  readonly manifest: Uint8Array | undefined;
  readonly collected: boolean;
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
  return Object.freeze({
    kind: "compare",
    column: predicate.compare.column,
    comparison: predicate.compare.op,
    type: predicate.compare.type,
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
      readonly operators: readonly ("scan" | "filter" | "limit" | "project" | "count" | "sum")[];
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
      columns: Object.freeze(input.description.columns.map((v) => Object.freeze(column(v)))),
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
      columns: Object.freeze(plan.columns.map((v) => Object.freeze(column(v)))),
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
export interface Manifest {
  readonly job: number;
  readonly source: ReadVersion;
  readonly requester: ProcessRef;
  readonly correlation: bigint;
  readonly policyRevision: bigint;
  readonly request: Uint8Array;
  readonly sourceKind: "kv" | "table" | "document";
  readonly resource: ResourceRef;
  readonly revision: number;
  readonly sourceDigest: Uint8Array;
  readonly schemaDigest: Uint8Array;
  readonly planDigest: Uint8Array;
  readonly pages: bigint;
  readonly scanned: bigint;
  readonly selected: bigint;
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
  const manifest: Manifest = Object.freeze({
    job: integer(m.job, "job"),
    source: new ReadVersion(m.source.pid, m.source.input, m.source.index),
    requester: new ProcessRef(realm, m.requester),
    correlation: nativeWide(m.correlation),
    policyRevision: nativeWide(m.policy_revision),
    request: unhex(m.request, 72),
    sourceKind: m.basis.kind,
    resource: new ResourceRef(realm, m.basis.resource),
    revision: integer(m.basis.revision, "revision", 0),
    sourceDigest: digest(m.basis.contract),
    schemaDigest: digest(m.basis.schema),
    planDigest: digest(m.plan),
    pages: nativeWide(m.pages),
    scanned: nativeWide(m.scanned),
    selected: nativeWide(m.selected),
    segments: nativeWide(m.segments),
    rows: nativeWide(m.rows),
    byteCount: nativeWide(m.bytes),
    sum: m.sum === null ? undefined : BigInt(m.sum),
    finished: m.finished,
    chain: digest(m.chain),
  });
  return new Page(
    manifest,
    Object.freeze(value.columns.map((v) => Object.freeze(column(v)))),
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
  ): Promise<Client> {
    const config = configuration(input);
    if (
      !(connection instanceof Connection) ||
      !(credential instanceof Credential) ||
      credential.realm !== connection.source.realm
    )
      throw new TypeError("Query credential must match the connection realm");
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
        },
        timeout_ms: config.timeoutMs,
      },
      config.nativeHost,
    );
    return new Client(connection, bridge);
  }
  async describe(source: Source): Promise<Description> {
    const id = resource(source);
    if (
      id.realm !== this.connection.resource.realm ||
      id.resource !== this.connection.resource.resource
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
      id.resource !== this.connection.resource.resource
    )
      throw new TypeError("Source differs from the connection");
    const value = await this.bridge.call({
      inspect: {
        scope: {
          name: text(name, 32),
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
  async prepareNext(namespace: bigint, bundle: Bundle): Promise<Prepared | undefined> {
    if (!(bundle instanceof Bundle)) throw new TypeError("Expected query bundle");
    const value = await this.bridge.call({
      next: { namespace: positive(namespace), bundle: hex(bundle.data, 16384) },
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
