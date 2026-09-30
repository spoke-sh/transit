import { ProcessRef, ResourceRef, IncompatibleNative, limits } from "@transit/client";
import { integer, owned } from "@transit/client/internal";
import { result } from "./bridge.ts";
import { operation, type Context } from "./context.ts";
import { cell, type Cell } from "./table.ts";
import { nativeWide, wide, ReadVersion, type Basis } from "./values.ts";
import { unhex } from "./framing.ts";
import type { GrowingAction } from "./wire.ts";
import type { Turn } from "./turn.ts";

export type Projection = "both" | "key" | "value";
export type Aggregate = "rows" | "count" | "sum";
export type Comparison = "eq" | "ne" | "lt" | "le" | "gt" | "ge";
export type Predicate =
  | { readonly kind: "is-null"; readonly column: 0 | 1 }
  | {
      readonly kind: "compare";
      readonly column: 0 | 1;
      readonly comparison: Comparison;
      readonly value: Cell;
    };
type NativePlan = NonNullable<
  Extract<GrowingAction, { query_start: unknown }>["query_start"]["plan"]
>;
export class QueryPlan {
  readonly projection: Projection;
  readonly aggregate: Aggregate;
  readonly limit: bigint | undefined;
  readonly #predicate: Predicate | undefined;
  constructor(
    options: {
      projection?: Projection;
      aggregate?: Aggregate;
      limit?: bigint;
      predicate?: Predicate;
    } = {},
  ) {
    this.projection = options.projection ?? "both";
    this.aggregate = options.aggregate ?? "rows";
    if (
      !["both", "key", "value"].includes(this.projection) ||
      !["rows", "count", "sum"].includes(this.aggregate)
    )
      throw new TypeError("Unsupported query projection or aggregate");
    this.limit = options.limit === undefined ? undefined : wide(options.limit);
    const predicate = options.predicate;
    if (predicate) {
      integer(predicate.column, "column", 0, 1);
      if (predicate.kind === "compare") {
        if (!["eq", "ne", "lt", "le", "gt", "ge"].includes(predicate.comparison))
          throw new TypeError("Unsupported comparison");
        const value =
          predicate.value instanceof Uint8Array
            ? owned(predicate.value, limits.value_bytes)
            : predicate.value;
        this.#predicate = Object.freeze({ ...predicate, value });
      } else if (predicate.kind === "is-null") this.#predicate = Object.freeze({ ...predicate });
      else throw new TypeError("Unsupported predicate");
    }
    Object.freeze(this);
  }
  wire(bound: number): NativePlan {
    let predicate: NativePlan["predicate"] = { all: {} };
    const selected = this.#predicate;
    if (selected?.kind === "is-null") predicate = { is_null: selected.column };
    else if (selected?.kind === "compare") {
      const value = selected.value;
      const type =
        typeof value === "bigint"
          ? "int64"
          : typeof value === "boolean"
            ? "boolean"
            : typeof value === "string"
              ? "utf8"
              : "binary";
      predicate = {
        compare: {
          column: selected.column,
          op: selected.comparison,
          value: cell(value, type, bound),
        },
      };
    }
    return {
      projection: this.projection,
      aggregate: this.aggregate,
      limit: this.limit?.toString() ?? null,
      predicate,
    };
  }
}
export interface QueryJob {
  readonly result: number;
  readonly correlation: bigint;
  readonly source: ReadVersion;
}
export interface ResultManifest {
  readonly result: number;
  readonly source: ProcessRef;
  readonly destination: ProcessRef;
  readonly correlation: bigint;
  readonly table: number;
  readonly policyRevision: bigint;
  readonly basis: Basis;
  readonly sourceContract: Uint8Array;
  readonly plan: Uint8Array;
  readonly segments: bigint;
  readonly byteCount: bigint;
  readonly rows: bigint;
  readonly chain: Uint8Array;
  readonly schema: Uint8Array;
}
export class IpcSegment {
  readonly manifest: ResultManifest;
  readonly ordinal: bigint;
  readonly rows: bigint;
  readonly #digest: Uint8Array;
  readonly #ipc: Uint8Array;
  constructor(
    manifest: ResultManifest,
    ordinal: bigint,
    rows: bigint,
    digest: Uint8Array,
    ipc: Uint8Array,
    bound: number,
  ) {
    this.manifest = manifest;
    this.ordinal = wide(ordinal);
    this.rows = wide(rows);
    this.#digest = owned(digest, 32);
    this.#ipc = owned(ipc, bound);
    if (this.#digest.length !== 32) throw new IncompatibleNative("Invalid segment digest");
    Object.freeze(this);
  }
  get digest(): Uint8Array {
    return new Uint8Array(this.#digest);
  }
  get ipc(): Uint8Array {
    return new Uint8Array(this.#ipc);
  }
}
async function complete(
  current: Context,
  owner: Turn,
  correlation: bigint,
): Promise<ResultManifest> {
  const value = result(
    await current.bridge.apply(current.token, { query_completed: correlation.toString() }),
    "manifest",
  );
  const realm = owner.process.realm;
  const basis = Object.freeze({
    resource: new ResourceRef(realm, value.basis.resource),
    revision: integer(value.basis.revision, "revision"),
    schema: new Uint8Array(value.basis.schema),
  });
  return Object.freeze({
    result: integer(value.result, "result"),
    source: new ProcessRef(realm, value.source),
    destination: new ProcessRef(realm, value.destination),
    correlation: nativeWide(value.correlation),
    table: integer(value.table, "table"),
    policyRevision: nativeWide(value.policy_revision),
    basis,
    sourceContract: new Uint8Array(value.basis.contract),
    plan: new Uint8Array(value.plan),
    segments: nativeWide(value.segments),
    byteCount: nativeWide(value.bytes),
    rows: nativeWide(value.rows),
    chain: new Uint8Array(value.chain),
    schema: new Uint8Array(value.schema),
  });
}
export class ResultReader {
  readonly correlation: bigint;
  readonly #turn: Turn;
  constructor(turn: Turn, correlation: bigint) {
    this.#turn = turn;
    this.correlation = wide(correlation);
    Object.freeze(this);
  }
  manifest(): Promise<ResultManifest> {
    return operation(this.#turn, (current) => complete(current, this.#turn, this.correlation));
  }
  segment(ordinal: bigint): Promise<IpcSegment> {
    return operation(this.#turn, async (current) => {
      const index = wide(ordinal);
      const manifest = await complete(current, this.#turn, this.correlation);
      const value = result(
        await current.bridge.apply(current.token, {
          query_segment: { correlation: this.correlation.toString(), ordinal: index.toString() },
        }),
        "segment",
      );
      return new IpcSegment(
        manifest,
        nativeWide(value.ordinal),
        BigInt(integer(value.rows, "segment rows", 0)),
        new Uint8Array(value.digest),
        unhex(value.ipc, current.bridge.caps.query_segment_bytes),
        current.bridge.caps.query_segment_bytes,
      );
    });
  }
}
