import { ResourceRef, HandlerError, Busy, limits } from "@transit/client";
import { integer, text } from "@transit/client/internal";
import { context, operation, type Context } from "./context.ts";
import { result } from "./bridge.ts";
import { hex, unhex } from "./framing.ts";
import { nativeWide, wide, ReadVersion, type Basis, type Page } from "./values.ts";
import type { GrowingAction } from "./wire.ts";
import type { Turn } from "./turn.ts";

export type Cell = bigint | boolean | string | Uint8Array | null;
export type CellType = "int64" | "boolean" | "utf8" | "binary";
export type WireCell =
  | { int64: string }
  | { boolean: boolean }
  | { utf8: string }
  | { binary: string }
  | { null: object };
export function cell(value: Cell, kind: CellType, bound: number): WireCell {
  if (value === null) return { null: {} };
  if (kind === "int64") return { int64: wide(value, true).toString() };
  if (kind === "boolean" && typeof value === "boolean") return { boolean: value };
  if (kind === "utf8" && typeof value === "string") return { utf8: text(value, bound) };
  if (kind === "binary" && value instanceof Uint8Array) return { binary: hex(value, bound) };
  throw new TypeError("Cell does not match its Table schema");
}
function cellValue(value: WireCell, bound: number): Cell {
  if ("null" in value) return null;
  if ("int64" in value) return nativeWide(value.int64, true);
  if ("boolean" in value) return value.boolean;
  if ("utf8" in value) return text(value.utf8, bound);
  return unhex(value.binary, bound);
}
export class TableSchema<C extends Cell> {
  readonly id: number;
  readonly valueType: CellType;
  readonly keyName: string;
  readonly valueName: string;
  private constructor(id: number, kind: CellType, keyName: string, valueName: string) {
    this.id = integer(id, "table ID", 1, 0xffffffff);
    this.valueType = kind;
    this.keyName = text(keyName, limits.value_bytes);
    this.valueName = text(valueName, limits.value_bytes);
    Object.freeze(this);
  }
  static int64(id: number, key = "id", value = "value"): TableSchema<bigint> {
    return new TableSchema(id, "int64", key, value);
  }
  static boolean(id: number, key = "id", value = "value"): TableSchema<boolean> {
    return new TableSchema(id, "boolean", key, value);
  }
  static utf8(id: number, key = "id", value = "value"): TableSchema<string> {
    return new TableSchema(id, "utf8", key, value);
  }
  static binary(id: number, key = "id", value = "value"): TableSchema<Uint8Array> {
    return new TableSchema(id, "binary", key, value);
  }
  encode(value: C | null, bound: number): WireCell {
    return cell(value, this.valueType, bound);
  }
}
export interface Row<C extends Cell> {
  readonly key: bigint;
  readonly value: C;
}
const construction = Symbol("captured-table");
export class Table<C extends Cell> {
  readonly schema: TableSchema<C>;
  readonly basis: Basis;
  readonly #turn: Turn;
  readonly #version: ReadVersion | undefined;
  constructor(
    secret: typeof construction,
    turn: Turn,
    schema: TableSchema<C>,
    basis: Basis,
    version?: ReadVersion,
  ) {
    if (secret !== construction) throw new TypeError("Tables require a captured native schema");
    this.#turn = turn;
    this.schema = schema;
    this.basis = basis;
    this.#version = version;
    Object.freeze(this);
  }
  static async capture<C extends Cell>(
    current: Context,
    owner: Turn,
    schema: TableSchema<C>,
    version?: ReadVersion,
  ): Promise<Table<C>> {
    if (context(owner) !== current) throw new Busy("Table capture belongs to its current turn");
    current.scope.check();
    if (!(schema instanceof TableSchema)) throw new TypeError("Expected TableSchema");
    const value = result(
      await current.bridge.apply(current.token, {
        table_schema: { id: schema.id, version: version ?? null },
      }),
      "schema",
    );
    if (
      value.key_name !== schema.keyName ||
      value.value_name !== schema.valueName ||
      value.value_type !== schema.valueType
    ) {
      throw new HandlerError("Captured Table schema differs from the requested public type");
    }
    const basis = Object.freeze({
      resource: new ResourceRef(owner.process.realm, value.basis.resource),
      revision: integer(value.basis.revision, "revision"),
      schema: new Uint8Array(value.basis.schema),
    });
    return new Table(construction, owner, schema, basis, version);
  }
  static open<C extends Cell>(
    turn: Turn,
    schema: TableSchema<C>,
    version?: ReadVersion,
  ): Promise<Table<C>> {
    return operation(turn, (current) => Table.capture(current, turn, schema, version));
  }
  static create<C extends Cell>(turn: Turn, schema: TableSchema<C>): Promise<Table<C>> {
    return operation(turn, async (current) => {
      if (!(schema instanceof TableSchema)) throw new TypeError("Expected TableSchema");
      text(schema.keyName, current.bridge.caps.table_name_bytes);
      text(schema.valueName, current.bridge.caps.table_name_bytes);
      await current.bridge.apply(current.token, {
        table_create: {
          id: schema.id,
          key_name: schema.keyName,
          value_name: schema.valueName,
          value_type: schema.valueType,
        },
      });
      return Table.capture(current, turn, schema);
    });
  }
  get(key: bigint): Promise<Row<C | null> | undefined> {
    return operation(this.#turn, async ({ bridge, token }) => {
      const request = { id: this.schema.id, key: wide(key, true).toString() };
      const action: GrowingAction = this.#version
        ? { version_table_get: { ...request, version: this.#version } }
        : { table_get: request };
      const value = result(await bridge.apply(token, action), "row");
      return value === null
        ? undefined
        : Object.freeze({
            key: nativeWide(value.key, true),
            value: cellValue(value.value, bridge.caps.table_cell_bytes) as C | null,
          });
    });
  }
  #write(mode: "insert" | "update" | "upsert", row: Row<C | null>): Promise<void> {
    return operation(this.#turn, async ({ bridge, token }) => {
      if (this.#version) throw new HandlerError("Retained Tables are read-only");
      const value = {
        key: wide(row.key, true).toString(),
        value: this.schema.encode(row.value, bridge.caps.table_cell_bytes),
      };
      await bridge.apply(token, { table_write: { id: this.schema.id, mode, row: value } });
    });
  }
  insert(row: Row<C | null>): Promise<void> {
    return this.#write("insert", row);
  }
  update(row: Row<C | null>): Promise<void> {
    return this.#write("update", row);
  }
  upsert(row: Row<C | null>): Promise<void> {
    return this.#write("upsert", row);
  }
  delete(key: bigint): Promise<void> {
    return operation(this.#turn, async ({ bridge, token }) => {
      if (this.#version) throw new HandlerError("Retained Tables are read-only");
      await bridge.apply(token, {
        table_delete: { id: this.schema.id, key: wide(key, true).toString() },
      });
    });
  }
  page(after?: string): Promise<Page<Row<C | null>>> {
    return operation(this.#turn, async ({ bridge, token }) => {
      const value = result(
        await bridge.apply(token, {
          table_page: {
            id: this.schema.id,
            cursor: after === undefined ? null : text(after, limits.max_body),
            version: this.#version ?? null,
          },
        }),
        "rows",
      );
      const basis = Object.freeze({
        resource: new ResourceRef(this.#turn.process.realm, value.basis.resource),
        revision: integer(value.basis.revision, "revision"),
        schema: new Uint8Array(value.basis.schema),
      });
      const rows = value.rows
        .filter((row) => row !== null)
        .map((row) =>
          Object.freeze({
            key: nativeWide(row.key, true),
            value: cellValue(row.value, bridge.caps.table_cell_bytes) as C | null,
          }),
        );
      return Object.freeze({ entries: Object.freeze(rows), next: value.next ?? undefined, basis });
    });
  }
}
