import { ProcessRef, ResourceRef, IncompatibleNative } from "@transit/client";
import { integer, owned } from "@transit/client/internal";
import { result } from "./bridge.ts";
import { operation, type Context } from "./context.ts";
import { planWire, type Plan, type Predicate as LogicalPredicate } from "./unified.ts";
import { nativeWide, wide, ReadVersion } from "./values.ts";
import { unhex } from "./framing.ts";
import type { GrowingAction } from "./wire.ts";
import type { Turn } from "./turn.ts";

export type Projection = readonly number[];
export type Aggregate = "rows" | "count" | "sum" | "count_values";
export type Comparison = "eq" | "ne" | "lt" | "le" | "gt" | "ge";
export type Predicate = LogicalPredicate;
type NativePlan = Extract<GrowingAction, { query_start: unknown }>["query_start"]["plan"];
export class QueryPlan {
  readonly #value: NativePlan;
  constructor(options: Plan) {
    this.#value = structuredClone(planWire(options));
    Object.freeze(this);
  }
  wire(): NativePlan {
    return structuredClone(this.#value);
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
  readonly table: bigint;
  readonly policyRevision: bigint;
  readonly basis: Readonly<{ resource: ResourceRef; revision: number; head: Uint8Array }>;
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
    head: new Uint8Array(value.basis.head),
  });
  return Object.freeze({
    result: integer(value.result, "result"),
    source: new ProcessRef(realm, value.source),
    destination: new ProcessRef(realm, value.destination),
    correlation: nativeWide(value.correlation),
    table: nativeWide(value.table),
    policyRevision: nativeWide(value.policy_revision),
    basis,
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
