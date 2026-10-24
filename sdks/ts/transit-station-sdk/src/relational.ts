/** Explicit interactive Table relations. The shared Zig owner executes and verifies pages. */
import { isDeepStrictEqual } from "node:util";
import { randomBytes } from "node:crypto";
import { Credential, IncompatibleNative, ResourceRef } from "@transit/client";
import type { ClientConfig } from "@transit/client";
import { configuration, integer, text } from "@transit/client/internal";
import { QueryBridge } from "./bridge.ts";
import { Basis, Connection, Scope, Snapshot } from "./catalog.ts";
import type { ObjectIdentity, Position } from "./catalog.ts";
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
  readonly consistency: "independent_table_snapshots";
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
  readonly namespace?: number;
  readonly sql: string;
  /** One configured catalog index per FROM/JOIN target, in SQL order. */
  readonly routes: readonly number[];
}
function statement(value: Statement): Extract<Action, { explain: unknown }>["explain"] {
  if (!value.routes.length || value.routes.length > 2)
    throw new TypeError("Select one or two explicit catalog routes");
  return {
    namespace: integer(value.namespace ?? 1, "namespace"),
    sql: text(value.sql, 4096),
    routes: value.routes.map((v) => integer(v, "route", 0, 1)),
  };
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
  readonly basis: Basis;
  readonly position: Position;
}
export interface RetainedSource {
  readonly basis: Basis;
  readonly snapshot: Snapshot;
}
function position(value: NativeDescription["sources"][number]["position"]): Position {
  return Object.freeze({
    partition: nativeWide(value.partition),
    nextLsn: nativeWide(value.next_lsn),
  });
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
          basis: Basis.restore(JSON.stringify(source.binding)),
          position: position(source.position),
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
  readonly object: ObjectIdentity;
  readonly position: Position;
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
export interface RelationalClientConfig extends ClientConfig {
  readonly serviceUrl?: string;
}
export class Client {
  readonly #bridge: QueryBridge;
  readonly #connections: readonly NativeDescription["sources"][number]["binding"]["connection"][];
  private constructor(
    bridge: QueryBridge,
    connections: readonly NativeDescription["sources"][number]["binding"]["connection"][],
  ) {
    this.#bridge = bridge;
    this.#connections = connections;
  }
  static async open(
    input: RelationalClientConfig,
    credential: Credential,
    catalogs: readonly Connection[],
    options: Options,
  ): Promise<Client> {
    const config = configuration(input);
    if (!(credential instanceof Credential) || !catalogs.length || catalogs.length > 2)
      throw new TypeError("Supply one credential and one or two catalog connections");
    if (options.consistency !== "independent_table_snapshots")
      throw new TypeError("Select independent_table_snapshots explicitly");
    const routes = catalogs.map((connection) => {
      if (
        !(connection instanceof Connection) ||
        connection.scope.resource.realm !== credential.realm
      )
        throw new TypeError("All catalogs must use the caller realm");
      return {
        scope: {
          realm: credential.realm,
          resource: connection.scope.resource.resource,
          catalog: connection.scope.catalog.toString(),
        },
        branch: connection.branch.toString(),
        audience: connection.audience,
        role: connection.role ?? null,
        principal: credential.principal,
      };
    });
    const bridge = await QueryBridge.open(
      config.url,
      credential.seedFile,
      {
        timeout_ms: config.timeoutMs,
        relational: {
          definition,
          service_url:
            input.serviceUrl === undefined
              ? null
              : configuration({ ...input, url: input.serviceUrl }).url,
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
    return new Client(bridge, routes);
  }
  async explain(input: Statement): Promise<Description> {
    const result = await this.#call({ explain: statement(input) });
    if (!("explained" in result)) throw new IncompatibleNative("Expected relational explanation");
    return this.#description(result.explained, input);
  }
  async openQuery(
    id: string,
    input: Statement,
    sources: readonly RetainedSource[],
  ): Promise<Opened> {
    exactHex(id, 16);
    if (/^0+$/.test(id)) throw new TypeError("Query ID must be nonzero");
    if (sources.length !== input.routes.length || sources.length < 1 || sources.length > 2)
      throw new TypeError("Supply one original binding and explicit snapshot per source");
    const bindings = sources.map((source) => {
      if (!(source.basis instanceof Basis) || !(source.snapshot instanceof Snapshot))
        throw new TypeError("Supply saved Table bindings and snapshots");
      return JSON.parse(source.basis.save()) as Extract<
        Action,
        { open: unknown }
      >["open"]["bindings"][number];
    });
    const snapshots = sources.map(
      (source) =>
        JSON.parse(source.snapshot.save()) as Extract<
          Action,
          { open: unknown }
        >["open"]["snapshots"][number],
    );
    const result = await this.#call({
      open: { id, statement: statement(input), bindings, snapshots },
    });
    if (!("opened" in result) || result.opened.complete_coverage)
      throw new IncompatibleNative("Expected an incomplete captured interactive basis");
    const value = result.opened;
    const ref = reference(value.reference);
    const plan = this.#description(value.description, input);
    for (let i = 0; i < sources.length; i++) {
      if (!isDeepStrictEqual(JSON.parse(plan.sources[i]!.basis.save()), bindings[i]))
        throw new IncompatibleNative("Relational open changed its original binding");
    }
    if (ref.id !== id || ref.plan !== plan.plan || value.cuts.length !== plan.sources.length)
      throw new IncompatibleNative("Relational open changed its requested identity");
    const cuts = value.cuts.map((cut, index) => {
      const source = plan.sources[index]!;
      const original = source.basis.definition.interpretation.object;
      if (
        cut.object.scope.realm !== original.scope.resource.realm ||
        cut.object.scope.resource !== original.scope.resource.resource ||
        nativeWide(cut.object.scope.catalog) !== original.scope.catalog ||
        nativeWide(cut.object.branch) !== original.branch ||
        nativeWide(cut.object.object) !== original.objectId ||
        cut.schema !== source.basis.definition.schemaFingerprint ||
        nativeWide(cut.position.partition) !== source.position.partition ||
        nativeWide(cut.position.next_lsn) !== source.position.nextLsn
      )
        throw new IncompatibleNative("Relational cut differs from its original source");
      return Object.freeze({
        object: Object.freeze({
          scope: new Scope(
            new ResourceRef(cut.object.scope.realm, cut.object.scope.resource),
            nativeWide(cut.object.scope.catalog),
          ),
          branch: nativeWide(cut.object.branch),
          objectId: nativeWide(cut.object.object),
        }),
        position: position(cut.position),
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
  #description(value: NativeDescription, input: Statement): Description {
    if (value.sources.length !== input.routes.length)
      throw new IncompatibleNative("Relational source count changed");
    for (let i = 0; i < value.sources.length; i++) {
      const binding = value.sources[i]!.binding;
      const connection = this.#connections[input.routes[i]!];
      if (
        !connection ||
        !isDeepStrictEqual(binding.connection, connection) ||
        binding.namespace !== (input.namespace ?? 1)
      )
        throw new IncompatibleNative(
          "Relational source changed its configured connection or namespace",
        );
    }
    return description(value);
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
