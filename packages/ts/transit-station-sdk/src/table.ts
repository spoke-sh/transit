import { ResourceRef, HandlerError, Busy, IncompatibleNative } from "@transit/client";
import { integer, validators } from "@transit/client/internal";
import { context, operation, type Context } from "./context.ts";
import { result } from "./bridge.ts";
import { hex, unhex } from "./framing.ts";
import { nativeWide, wide, ReadVersion, readVersionWire } from "./values.ts";
import {
  Schema,
  schemaWire,
  schemaValue,
  mutationWire,
  type TableLimits,
  type Mutation,
} from "./catalog.ts";
import { encodeCell, decodeCell, type Cell } from "./logical-values.ts";
import type { GrowingAction, GrowingResult } from "./wire.ts";
import type { Turn } from "./turn.ts";
import contract from "./contract.json" with { type: "json" };
import schemas from "./schemas.json" with { type: "json" };

export { Schema as TableSchema } from "./catalog.ts";
export type { Cell } from "./logical-values.ts";
export type { Column, TableLimits, Mutation, Assignment } from "./catalog.ts";
type Action = Extract<GrowingAction, { table: unknown }>["table"];
type Result = Extract<GrowingResult, { table: unknown }>["table"];
type NativeMutation = Extract<Action, { mutate: unknown }>["mutate"];
type NativeReference = Extract<Action, { status: unknown }>["status"];
type NativeStatus = NonNullable<Extract<Result, { mutation: unknown }>["mutation"]>;
type NativeDefinition = Extract<Result, { schema: unknown }>["schema"];
type NativeRow = NonNullable<Extract<Result, { row: unknown }>["row"]["row"]>;
type Tags<T> = T extends unknown ? keyof T : never;
const validate = validators(schemas).GrowingAction!;
function tableResult<K extends Tags<Result>>(
  value: GrowingResult,
  tag: K,
): Extract<Result, Record<K, unknown>>[K] {
  const table = result(value, "table");
  if (!(tag in table)) throw new IncompatibleNative("Unexpected Table result");
  return (table as Extract<Result, Record<K, unknown>>)[tag];
}
function saved<T extends "mutate" | "status">(
  text: string,
  tag: T,
): Extract<Action, Record<T, unknown>>[T] {
  if (typeof text !== "string" || Buffer.byteLength(text) > contract.limits.handler_action_bytes)
    throw new TypeError("Table intent exceeds its action budget");
  const value: unknown = JSON.parse(text);
  if (
    JSON.stringify(value) !== text ||
    Buffer.byteLength(JSON.stringify({ table: { [tag]: value } })) >
      contract.limits.handler_action_bytes ||
    !validate({ table: { [tag]: value } })
  )
    throw new IncompatibleNative("Invalid saved Table intent");
  return value as Extract<Action, Record<T, unknown>>[T];
}
function currentDefinition(value: string): void {
  if (value !== contract.definition) throw new IncompatibleNative("Incompatible Table definition");
}
export class RowIdentity {
  readonly #hex: string;
  constructor(bytes: Uint8Array) {
    this.#hex = hex(bytes, 20);
    if (this.#hex.length !== 40) throw new TypeError("Expected a 20-byte row identity");
    Object.freeze(this);
  }
  get bytes(): Uint8Array {
    return unhex(this.#hex, 20);
  }
  wire(): string {
    return this.#hex;
  }
}
export interface Row {
  readonly identity: RowIdentity;
  readonly cells: readonly Cell[];
}
export interface TableBasis {
  readonly resource: ResourceRef;
  readonly revision: number;
  readonly objectId: bigint;
  readonly head: string;
}
export interface TablePage {
  readonly rows: readonly Row[];
  readonly next?: string;
}
export interface TableCreation {
  readonly state: "building" | "applied";
  readonly admittedInput: number;
  readonly completedInput?: number;
}
export interface TableMutationStatus {
  readonly reference: TableMutationReference;
  readonly state: NativeStatus["state"];
  readonly route: NativeStatus["route"];
  readonly admittedInput: number;
  readonly completedInput?: number;
  readonly counts?: { readonly matched: bigint; readonly changed: bigint };
  readonly rejection: NativeStatus["rejection"];
  readonly witness?: {
    readonly source: NonNullable<NativeStatus["witness"]>["source"];
    readonly row?: RowIdentity;
    readonly column: bigint;
    readonly text: string;
    readonly truncated: boolean;
  };
}
function status(value: NativeStatus): TableMutationStatus {
  return Object.freeze({
    reference: TableMutationReference.load(JSON.stringify(value.reference)),
    state: value.state,
    route: value.route,
    admittedInput: integer(value.admitted_input, "admitted input"),
    ...(value.completed_input === null
      ? {}
      : { completedInput: integer(value.completed_input, "completed input") }),
    ...(value.counts === null
      ? {}
      : {
          counts: Object.freeze({
            matched: nativeWide(value.counts.matched),
            changed: nativeWide(value.counts.changed),
          }),
        }),
    rejection: value.rejection,
    ...(value.witness === null
      ? {}
      : {
          witness: Object.freeze({
            source: value.witness.source,
            column: nativeWide(value.witness.column),
            text: value.witness.text,
            truncated: value.witness.truncated,
            ...(value.witness.row === null
              ? {}
              : { row: new RowIdentity(unhex(value.witness.row, 20)) }),
          }),
        }),
  });
}
function sameResource(turn: Turn, realm: number, resource: number): void {
  if (turn.resource.realm !== realm || turn.resource.resource !== resource)
    throw new HandlerError("Table intent belongs to another resource");
}
export class TableMutationReference {
  readonly #value: NativeReference;
  private constructor(value: NativeReference) {
    this.#value = structuredClone(value);
    Object.freeze(this);
  }
  static load(text: string): TableMutationReference {
    const value = saved(text, "status");
    currentDefinition(value.definition);
    new ResourceRef(value.realm, value.resource);
    if (nativeWide(value.object) === 0n || nativeWide(value.operation) === 0n)
      throw new IncompatibleNative("Table identities must be positive");
    return new TableMutationReference(value);
  }
  save(): string {
    return JSON.stringify(this.#value);
  }
  status(turn: Turn): Promise<TableMutationStatus | undefined> {
    return this.#read(turn, "status");
  }
  async cancel(turn: Turn): Promise<TableMutationStatus> {
    const value = await this.#read(turn, "cancel");
    if (!value) throw new IncompatibleNative("Missing cancelled Table mutation");
    return value;
  }
  #read(turn: Turn, tag: "status" | "cancel"): Promise<TableMutationStatus | undefined> {
    sameResource(turn, this.#value.realm, this.#value.resource);
    return operation(turn, async ({ bridge, token }) => {
      const action: Action = tag === "status" ? { status: this.#value } : { cancel: this.#value };
      const value = tableResult(await bridge.apply(token, { table: action }), "mutation");
      if (value === null) return undefined;
      for (const key of Object.keys(this.#value) as (keyof NativeReference)[])
        if (value.reference[key] !== this.#value[key])
          throw new IncompatibleNative("Foreign Table mutation outcome");
      return status(value);
    });
  }
}
/** Persist save() before accepting work; step() prepares exactly one private turn. */
export class TableMutation {
  readonly #value: NativeMutation;
  private constructor(value: NativeMutation) {
    this.#value = structuredClone(value);
    Object.freeze(this);
  }
  static prepare(
    resource: ResourceRef,
    principal: number,
    operationId: bigint,
    schema: Schema,
    mutation: Mutation,
  ): TableMutation {
    if (!(resource instanceof ResourceRef)) throw new TypeError("Expected a resource reference");
    const operation = wide(operationId);
    if (operation === 0n) throw new TypeError("Mutation identity must be positive");
    const value: NativeMutation = {
      realm: resource.realm,
      resource: resource.resource,
      principal: integer(principal, "principal", 0),
      operation: operation.toString(),
      schema: schemaWire(schema),
      mutation: mutationWire(mutation, contract.limits.handler_action_bytes),
    };
    return TableMutation.load(JSON.stringify(value));
  }
  static load(text: string): TableMutation {
    const value = saved(text, "mutate");
    currentDefinition(value.schema.definition);
    schemaValue(value.schema);
    new ResourceRef(value.realm, value.resource);
    if (nativeWide(value.operation) === 0n)
      throw new IncompatibleNative("Mutation identity must be positive");
    return new TableMutation(value);
  }
  save(): string {
    return JSON.stringify(this.#value);
  }
  get schema(): Schema {
    return schemaValue(this.#value.schema);
  }
  get operationId(): bigint {
    return nativeWide(this.#value.operation);
  }
  step(turn: Turn): Promise<TableMutationStatus> {
    sameResource(turn, this.#value.realm, this.#value.resource);
    return operation(turn, async ({ bridge, token }) => {
      const value = tableResult(
        await bridge.apply(token, { table: { mutate: this.#value } }),
        "mutation",
      );
      if (!value) throw new IncompatibleNative("Missing Table mutation outcome");
      if (
        value.reference.object !== this.#value.schema.object ||
        ["realm", "resource", "principal", "operation"].some(
          (key) =>
            value.reference[key as keyof NativeReference] !==
            this.#value[key as keyof NativeMutation],
        )
      )
        throw new IncompatibleNative("Foreign Table mutation outcome");
      return status(value);
    });
  }
}
function decodedRow(value: NativeRow): Row {
  return Object.freeze({
    identity: new RowIdentity(unhex(value.identity, 20)),
    cells: Object.freeze(value.cells.map((cell) => decodeCell(cell))),
  });
}
const construction = Symbol("captured-table");
export class Table {
  readonly schema: Schema;
  readonly basis: TableBasis;
  readonly #turn: Turn;
  readonly #version: ReadVersion | undefined;
  private constructor(
    secret: typeof construction,
    turn: Turn,
    metadata: NativeDefinition,
    version?: ReadVersion,
  ) {
    if (secret !== construction) throw new TypeError("Open a Table through its turn");
    this.#turn = turn;
    this.#version = version;
    this.schema = schemaValue(metadata.schema);
    const head = hex(unhex(metadata.basis.head, 32), 32);
    if (head.length !== 64 || nativeWide(metadata.basis.object) !== this.schema.objectId)
      throw new IncompatibleNative("Invalid Table basis");
    this.basis = Object.freeze({
      resource: new ResourceRef(turn.process.realm, metadata.basis.resource),
      revision: integer(metadata.basis.revision, "revision"),
      objectId: this.schema.objectId,
      head,
    });
    Object.freeze(this);
  }
  static async capture(
    current: Context,
    owner: Turn,
    objectId: bigint,
    version?: ReadVersion,
  ): Promise<Table> {
    if (context(owner) !== current) throw new Busy("Table capture belongs to its current turn");
    current.scope.check();
    if (wide(objectId) === 0n) throw new TypeError("Table identity must be positive");
    const value = tableResult(
      await current.bridge.apply(current.token, {
        table: {
          schema: {
            object: objectId.toString(),
            version: version ? readVersionWire(version) : null,
          },
        },
      }),
      "schema",
    );
    return new Table(construction, owner, value, version);
  }
  static open(turn: Turn, objectId: bigint, version?: ReadVersion): Promise<Table> {
    return operation(turn, (current) => Table.capture(current, turn, objectId, version));
  }
  static create(turn: Turn, schema: Schema, limits: TableLimits): Promise<TableCreation> {
    return operation(turn, async ({ bridge, token }) => {
      const value = tableResult(
        await bridge.apply(token, {
          table: {
            create: {
              realm: turn.resource.realm,
              resource: turn.resource.resource,
              schema: schemaWire(schema),
              limits: {
                record_bytes: integer(limits.recordBytes, "record bytes"),
                staging_bytes: wide(limits.stagingBytes).toString(),
                staging_records: integer(limits.stagingRecords, "staging records"),
              },
            },
          },
        }),
        "created",
      );
      return Object.freeze({
        state: value.state,
        admittedInput: integer(value.admitted_input, "admitted input"),
        ...(value.completed_input === 0
          ? {}
          : { completedInput: integer(value.completed_input, "completed input") }),
      });
    });
  }
  #source() {
    return {
      object: this.schema.objectId.toString(),
      version: this.#version ? readVersionWire(this.#version) : null,
    };
  }
  #check(value: NativeDefinition): void {
    if (
      value.basis.head !== this.basis.head ||
      value.basis.resource !== this.basis.resource.resource ||
      value.basis.revision !== this.basis.revision
    )
      throw new IncompatibleNative("Table read changed its captured basis");
  }
  get(identity: RowIdentity): Promise<Row | undefined> {
    return operation(this.#turn, async ({ bridge, token }) => {
      if (!(identity instanceof RowIdentity)) throw new TypeError("Expected a row identity");
      const value = tableResult(
        await bridge.apply(token, {
          table: { get: { source: this.#source(), identity: identity.wire() } },
        }),
        "row",
      );
      this.#check(value.definition);
      return value.row === null ? undefined : decodedRow(value.row);
    });
  }
  getKey(key: readonly Cell[]): Promise<Row | undefined> {
    return operation(this.#turn, async ({ bridge, token }) => {
      const value = tableResult(
        await bridge.apply(token, {
          table: {
            get_key: { source: this.#source(), key: key.map((value) => encodeCell(value)) },
          },
        }),
        "row",
      );
      this.#check(value.definition);
      return value.row === null ? undefined : decodedRow(value.row);
    });
  }
  page(cursor?: string, limit = 8): Promise<TablePage> {
    return operation(this.#turn, async ({ bridge, token }) => {
      const value = tableResult(
        await bridge.apply(token, {
          table: {
            page: {
              source: this.#source(),
              cursor: cursor ?? null,
              limit: integer(limit, "page rows", 1, bridge.caps.table_page_rows),
            },
          },
        }),
        "page",
      );
      this.#check(value.definition);
      return Object.freeze({
        rows: Object.freeze(value.rows.map(decodedRow)),
        ...(value.next === null ? {} : { next: value.next }),
      });
    });
  }
  prepare(principal: number, operationId: bigint, mutation: Mutation): TableMutation {
    context(this.#turn).scope.check();
    if (this.#version) throw new HandlerError("Retained Tables are read-only");
    return TableMutation.prepare(
      this.basis.resource,
      principal,
      operationId,
      this.schema,
      mutation,
    );
  }
}
