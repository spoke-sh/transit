/** Explicit interactive Table relations. The shared Zig owner executes and verifies pages. */
import { randomBytes } from "node:crypto";
import { Credential, IncompatibleNative, ResourceRef } from "@transit/client";
import type { ClientConfig } from "@transit/client";
import { configuration, integer, text } from "@transit/client/internal";
import { QueryBridge } from "./bridge.ts";
import { Connection } from "./catalog.ts";
import { RowIdentity } from "./table.ts";
import { unhex } from "./framing.ts";
import { nativeWide, wide } from "./values.ts";
import { decodeType } from "./logical-values.ts";
import type { Descriptor } from "./logical-values.ts";
import type { UnifiedQueryAction, UnifiedQueryResult } from "./wire.ts";
import contract from "./contract.json" with { type: "json" };

type Action = Extract<UnifiedQueryAction, { relational: unknown }>["relational"];
type Result = Extract<UnifiedQueryResult, { relational: unknown }>["relational"];
type NativeReference = Extract<Action, { close: unknown }>["close"];
type NativeDescription = Extract<Result, { explained: unknown }>["explained"];
type NativeRow = NonNullable<Extract<Result, { page: unknown }>["page"]["row"]>;
const definition = contract.definition as NativeReference["definition"];
function exactHex(value: string, bytes: number): string {
  if (typeof value !== "string" || !new RegExp(`^[0-9a-f]{${bytes * 2}}$`).test(value))
    throw new TypeError("Expected an exact lowercase hexadecimal identity");
  return value;
}
function positive(value: bigint): string {
  if (wide(value) === 0n) throw new TypeError("Relational budget must be positive");
  return value.toString();
}
/** Persist with the statement until open succeeds; retries reuse the same ID. */
export function freshId(): string {
  const bytes = randomBytes(16);
  bytes[0] = bytes[0]! | 1;
  return bytes.toString("hex");
}
export interface Options {
  readonly consistency: "per_resource_snapshot_vector";
  readonly residentBytes: bigint;
  readonly spillBytes: bigint;
  readonly resultBytes: bigint;
  readonly outputRows: bigint;
  readonly workSteps: bigint;
  readonly sourcePins: number;
  readonly requests: bigint;
  readonly spillWork: bigint;
  readonly spillDirectory: string;
}
export interface Statement {
  readonly sql: string;
  /** One configured catalog index per FROM/JOIN target, in SQL order. */
  readonly routes: readonly number[];
}
function statement(value: Statement): Extract<Action, { explain: unknown }>["explain"] {
  if (!value.routes.length || value.routes.length > 2)
    throw new TypeError("Select one or two explicit catalog routes");
  return { sql: text(value.sql, 4096), routes: value.routes.map((v) => integer(v, "route", 0, 1)) };
}
/** This reference belongs to one live host. Saving it does not make the query durable. */
export class Reference {
  readonly id: string;
  readonly plan: string;
  readonly basis: string;
  private constructor(id: string, plan: string, basis: string) {
    this.id = exactHex(id, 16);
    this.plan = exactHex(plan, 32);
    this.basis = exactHex(basis, 32);
    if (/^0+$/.test(id)) throw new TypeError("Query ID must be nonzero");
    Object.freeze(this);
  }
  static restore(saved: string): Reference {
    text(saved, 1024);
    const value: unknown = JSON.parse(saved);
    if (value === null || typeof value !== "object" || Array.isArray(value))
      throw new IncompatibleNative("Invalid relational reference");
    const fields = value as Record<string, unknown>;
    if (
      Object.keys(fields).sort().join(",") !== "basis,definition,id,plan" ||
      fields.definition !== definition ||
      typeof fields.id !== "string" ||
      typeof fields.plan !== "string" ||
      typeof fields.basis !== "string"
    )
      throw new IncompatibleNative("Missing or foreign relational reference definition");
    return new Reference(fields.id, fields.plan, fields.basis);
  }
  save(): string {
    return JSON.stringify({ definition, id: this.id, plan: this.plan, basis: this.basis });
  }
}
function reference(value: NativeReference): Reference {
  return Reference.restore(JSON.stringify(value));
}
function wireReference(value: Reference): NativeReference {
  if (!(value instanceof Reference)) throw new TypeError("Expected a relational reference");
  return { definition, id: value.id, plan: value.plan, basis: value.basis };
}
export interface Column {
  readonly name: string;
  readonly type: Descriptor;
  readonly nullable: boolean;
}
export interface Source {
  readonly alias: string;
  readonly resource: ResourceRef;
  readonly catalog: bigint;
  readonly owner: number;
  readonly objectId: bigint;
  readonly schema: string;
}
export interface Description {
  readonly plan: string;
  readonly sources: readonly Source[];
  readonly columns: readonly Column[];
  readonly join: "inner" | "left" | undefined;
  readonly grouped: boolean;
  readonly executed: false;
}
function description(value: NativeDescription): Description {
  if (value.definition !== definition || value.executed)
    throw new IncompatibleNative("Expected a current proposed relational plan");
  return Object.freeze({
    plan: exactHex(value.plan, 32),
    sources: Object.freeze(
      value.sources.map((source) =>
        Object.freeze({
          alias: source.alias,
          resource: new ResourceRef(source.realm, source.resource),
          catalog: nativeWide(source.catalog),
          owner: source.owner,
          objectId: nativeWide(source.object),
          schema: exactHex(source.schema, 32),
        }),
      ),
    ),
    columns: Object.freeze(
      value.columns.map((column) => {
        if (column.optional) throw new IncompatibleNative("Relational columns cannot be missing");
        const type = decodeType(column.type);
        if (type.kind !== "int64" && type.kind !== "uint64")
          throw new IncompatibleNative("Unsupported relational output type");
        return Object.freeze({
          name: column.name,
          type: Object.freeze(type),
          nullable: column.nullable,
        });
      }),
    ),
    join: value.join ?? undefined,
    grouped: value.grouped,
    executed: false,
  });
}
export interface Cut {
  readonly resource: number;
  readonly revision: number;
  readonly commitment: string;
  readonly schema: string;
}
export interface Opened {
  readonly reference: Reference;
  readonly description: Description;
  readonly cuts: readonly Cut[];
  readonly completeCoverage: false;
}
export type Identity =
  | { readonly kind: "pair"; readonly left: RowIdentity; readonly right: RowIdentity | undefined }
  | { readonly kind: "group"; readonly keys: readonly (bigint | null)[] };
export interface Row {
  readonly identity: Identity;
  readonly cells: readonly (bigint | null)[];
}
function row(value: NativeRow): Row {
  const identity: Identity =
    "pair" in value.identity
      ? Object.freeze({
          kind: "pair",
          left: new RowIdentity(unhex(value.identity.pair.left, 20)),
          right:
            value.identity.pair.right === null
              ? undefined
              : new RowIdentity(unhex(value.identity.pair.right, 20)),
        })
      : Object.freeze({
          kind: "group",
          keys: Object.freeze(
            value.identity.group.map((key) => {
              if (key === null) return null;
              if (!/^(0|-?[1-9][0-9]*)$/.test(key))
                throw new IncompatibleNative("Invalid relational group key");
              const result = BigInt(key);
              if (result < -(1n << 63n) || result >= 1n << 63n)
                throw new IncompatibleNative("Relational key exceeds int64");
              return result;
            }),
          ),
        });
  return Object.freeze({
    identity,
    cells: Object.freeze(
      value.cells.map((cell) => {
        if ("null" in cell) return null;
        if (!("value" in cell) || !("atom" in cell.value))
          throw new IncompatibleNative("Unsupported relational cell");
        const atom = cell.value.atom;
        if ("unsigned" in atom) return nativeWide(atom.unsigned);
        if (!("signed" in atom) || !/^(0|-?[1-9][0-9]*)$/.test(atom.signed))
          throw new IncompatibleNative("Unsupported relational scalar");
        const result = BigInt(atom.signed);
        if (result < -(1n << 63n) || result >= 1n << 63n)
          throw new IncompatibleNative("Relational scalar exceeds int64");
        return result;
      }),
    ),
  });
}
export interface Page {
  readonly reference: Reference;
  readonly ordinal: bigint;
  readonly row: Row | undefined;
  readonly completeCoverage: boolean;
}
export class Client {
  readonly #bridge: QueryBridge;
  private constructor(bridge: QueryBridge) {
    this.#bridge = bridge;
  }
  static async open(
    input: ClientConfig,
    credential: Credential,
    catalogs: readonly Connection[],
    options: Options,
  ): Promise<Client> {
    const config = configuration(input);
    if (!(credential instanceof Credential) || !catalogs.length || catalogs.length > 2)
      throw new TypeError("Supply one credential and one or two catalog connections");
    if (options.consistency !== "per_resource_snapshot_vector")
      throw new TypeError("Select per_resource_snapshot_vector explicitly");
    const routes = catalogs.map((connection) => {
      if (!(connection instanceof Connection) || connection.owner.realm !== credential.realm)
        throw new TypeError("All catalogs must use the caller realm");
      return {
        scope: {
          realm: credential.realm,
          resource: connection.scope.resource.resource,
          catalog: connection.scope.catalog.toString(),
        },
        owner: connection.owner.pid,
        principal: credential.principal,
      };
    });
    const bridge = await QueryBridge.open(
      config.url,
      credential.seedFile,
      {
        timeout_ms: config.timeoutMs,
        relational: {
          catalogs: routes,
          spill_directory: text(options.spillDirectory, 4096),
          options: {
            consistency: options.consistency,
            resident_bytes: positive(options.residentBytes),
            spill_bytes: wide(options.spillBytes).toString(),
            result_bytes: positive(options.resultBytes),
            output_rows: positive(options.outputRows),
            work_steps: positive(options.workSteps),
            source_pins: integer(options.sourcePins, "source pins", 1, 2),
            requests: positive(options.requests),
            spill_work: positive(options.spillWork),
          },
        },
      },
      config.nativeHost,
    );
    return new Client(bridge);
  }
  async explain(input: Statement): Promise<Description> {
    const result = await this.#call({ explain: statement(input) });
    if (!("explained" in result)) throw new IncompatibleNative("Expected relational explanation");
    return description(result.explained);
  }
  async openQuery(id: string, input: Statement): Promise<Opened> {
    exactHex(id, 16);
    if (/^0+$/.test(id)) throw new TypeError("Query ID must be nonzero");
    const result = await this.#call({ open: { id, statement: statement(input) } });
    if (!("opened" in result) || result.opened.complete_coverage)
      throw new IncompatibleNative("Expected an incomplete captured interactive basis");
    const value = result.opened;
    const ref = reference(value.reference);
    const plan = description(value.description);
    if (ref.id !== id || ref.plan !== plan.plan || value.cuts.length !== plan.sources.length)
      throw new IncompatibleNative("Relational open changed its requested identity");
    const cuts = value.cuts.map((cut, index) => {
      const source = plan.sources[index]!;
      if (cut.resource !== source.resource.resource || cut.schema !== source.schema)
        throw new IncompatibleNative("Relational cut differs from its source");
      return Object.freeze({
        resource: cut.resource,
        revision: cut.revision,
        commitment: exactHex(cut.commitment, 32),
        schema: exactHex(cut.schema, 32),
      });
    });
    return Object.freeze({
      reference: ref,
      description: plan,
      cuts: Object.freeze(cuts),
      completeCoverage: false,
    });
  }
  async page(ref: Reference, ordinal: bigint): Promise<Page> {
    const result = await this.#call({
      page: { reference: wireReference(ref), ordinal: wide(ordinal).toString() },
    });
    if (!("page" in result)) throw new IncompatibleNative("Expected relational page");
    const value = result.page;
    const received = reference(value.reference);
    if (
      received.save() !== ref.save() ||
      nativeWide(value.ordinal) !== ordinal ||
      value.complete_coverage !== (value.row === null)
    )
      throw new IncompatibleNative("Relational page changed its identity or coverage");
    return Object.freeze({
      reference: received,
      ordinal,
      row: value.row === null ? undefined : row(value.row),
      completeCoverage: value.complete_coverage,
    });
  }
  async closeQuery(ref: Reference): Promise<void> {
    if (!("closed" in (await this.#call({ close: wireReference(ref) }))))
      throw new IncompatibleNative("Expected relational close acknowledgement");
  }
  async #call(action: Action): Promise<Result> {
    const result = await this.#bridge.call({ relational: action });
    if (!("relational" in result)) throw new IncompatibleNative("Expected relational result");
    return result.relational;
  }
  close(): Promise<void> {
    return this.#bridge.close();
  }
}
