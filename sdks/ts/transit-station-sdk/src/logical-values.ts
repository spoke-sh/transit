/** Language-native logical values. Wire codecs are internal and shared by Table callers. */
import type { CatalogAction } from "./wire.ts";
import { hex, unhex } from "./framing.ts";

type Request = Extract<CatalogAction, { prepare: unknown }>["prepare"];
type Schema = Extract<Request["action"], { create: unknown }>["create"]["schema"];
type WireType = Schema["columns"][number]["type"];
type WireCell = NonNullable<Schema["columns"][number]["default"]>;
type WireValue = Extract<WireCell, { value: unknown }>["value"];
type WireAtom = Extract<WireValue, { atom: unknown }>["atom"];
export type ScalarKind =
  | "int8"
  | "int16"
  | "int32"
  | "int64"
  | "int128"
  | "uint8"
  | "uint16"
  | "uint32"
  | "uint64"
  | "uint128"
  | "float32"
  | "float64"
  | "boolean"
  | "utf8"
  | "binary"
  | "date"
  | "time"
  | "interval"
  | "uuid"
  | "json";
export interface Field {
  readonly name: string;
  readonly type: Descriptor;
  readonly nullable?: boolean;
  readonly optional?: boolean;
}
export interface Element {
  readonly type: Descriptor;
  readonly nullable?: boolean;
}
export type Descriptor =
  | { readonly kind: ScalarKind }
  | { readonly kind: "decimal"; readonly precision: number; readonly scale: number }
  | { readonly kind: "timestamp"; readonly zone: "civil" | "utc" }
  | { readonly kind: "structure" | "tagged_union"; readonly fields: readonly Field[] }
  | { readonly kind: "list"; readonly element: Element }
  | { readonly kind: "array"; readonly element: Element; readonly length: number }
  | { readonly kind: "map"; readonly key: Descriptor; readonly value: Element };
export type Atom =
  | {
      readonly kind:
        | "signed"
        | "unsigned"
        | "decimal"
        | "date_days"
        | "time_nanos"
        | "timestamp_micros";
      readonly value: bigint;
    }
  | { readonly kind: "float"; readonly width: 32 | 64; readonly value: number }
  | { readonly kind: "boolean"; readonly value: boolean }
  | { readonly kind: "utf8"; readonly value: string }
  | { readonly kind: "binary" | "uuid"; readonly value: Uint8Array }
  | {
      readonly kind: "interval";
      readonly months: bigint;
      readonly days: bigint;
      readonly nanos: bigint;
    };
export type Value =
  | { readonly kind: "atom"; readonly atom: Atom }
  | { readonly kind: "structure" | "list" | "array"; readonly cells: readonly Cell[] }
  | {
      readonly kind: "map";
      readonly entries: readonly { readonly key: Atom; readonly value: Cell }[];
    }
  | { readonly kind: "tagged_union"; readonly index: number; readonly value: Cell }
  | { readonly kind: "json"; readonly json: string };
export type SourceKind = Descriptor["kind"] | "unknown" | "null_value" | "text" | "character";
export type Cell =
  | { readonly state: "missing" | "null" }
  | { readonly state: "type_error"; readonly actual: SourceKind }
  | { readonly state: "value"; readonly value: Value }
  | {
      readonly state: "conflict";
      readonly alternatives: readonly {
        readonly counter: bigint;
        readonly replica: bigint;
        readonly cell:
          | Exclude<Cell, { state: "missing" | "null" } | { state: "conflict" }>
          | { readonly state: "null" };
      }[];
    };

function numberText(value: bigint): string {
  if (typeof value !== "bigint" || value < -(1n << 127n) || value >= 1n << 128n)
    throw new TypeError("Expected a bounded logical integer");
  return value.toString();
}
function exact(value: string): bigint {
  if (!/^(0|[1-9][0-9]*|-[1-9][0-9]*)$/.test(value))
    throw new TypeError("Noncanonical logical integer");
  const result = BigInt(value);
  numberText(result);
  return result;
}
class Budget {
  nodes = 0;
  bytes = 0;
  names = 0;
  readonly maxNodes: number;
  constructor(maxNodes: number) {
    this.maxNodes = maxNodes;
  }
  enter(depth: number): void {
    if (depth >= 16 || ++this.nodes > this.maxNodes)
      throw new TypeError("Logical value exceeds its nesting or child bound");
  }
  data(length: number): void {
    this.bytes += length;
    if (this.bytes > 1024 * 1024) throw new TypeError("Logical value exceeds its byte bound");
  }
  name(value: string): string {
    this.names += Buffer.byteLength(value);
    if (this.names > 4096) throw new TypeError("Logical type exceeds its name byte bound");
    return value;
  }
}
export function encodeType(value: Descriptor, budget = new Budget(256), depth = 0): WireType {
  budget.enter(depth);
  const element = (value: Element) => ({
    type: encodeType(value.type, budget, depth + 1),
    nullable: value.nullable ?? false,
  });
  switch (value.kind) {
    case "decimal":
      return { decimal: { precision: value.precision, scale: value.scale } };
    case "timestamp":
      return { timestamp: value.zone };
    case "structure":
    case "tagged_union": {
      const fields = value.fields.map((field) => ({
        name: budget.name(field.name),
        type: encodeType(field.type, budget, depth + 1),
        nullable: field.nullable ?? false,
        optional: field.optional ?? false,
      }));
      return value.kind === "structure" ? { structure: fields } : { tagged_union: fields };
    }
    case "list":
      return { list: element(value.element) };
    case "array":
      return { array: { element: element(value.element), length: value.length } };
    case "map":
      return {
        map: { key: encodeType(value.key, budget, depth + 1), value: element(value.value) },
      };
    default:
      return { [value.kind]: {} } as WireType;
  }
}
export function decodeType(value: WireType, budget = new Budget(256), depth = 0): Descriptor {
  budget.enter(depth);
  const element = (value: { type: WireType; nullable?: boolean }): Element => ({
    type: decodeType(value.type, budget, depth + 1),
    nullable: value.nullable ?? false,
  });
  if ("decimal" in value) return { kind: "decimal", ...value.decimal };
  if ("timestamp" in value) return { kind: "timestamp", zone: value.timestamp };
  if ("structure" in value || "tagged_union" in value) {
    const fields = "structure" in value ? value.structure : value.tagged_union;
    return {
      kind: "structure" in value ? "structure" : "tagged_union",
      fields: fields.map((field) => ({
        name: budget.name(field.name),
        type: decodeType(field.type, budget, depth + 1),
        nullable: field.nullable ?? false,
        optional: field.optional ?? false,
      })),
    };
  }
  if ("list" in value) return { kind: "list", element: element(value.list) };
  if ("array" in value)
    return { kind: "array", element: element(value.array.element), length: value.array.length };
  if ("map" in value)
    return {
      kind: "map",
      key: decodeType(value.map.key, budget, depth + 1),
      value: element(value.map.value),
    };
  return { kind: Object.keys(value)[0] as ScalarKind };
}
export function encodeAtom(value: Atom, budget = new Budget(65536)): WireAtom {
  switch (value.kind) {
    case "signed":
    case "unsigned":
    case "decimal":
    case "date_days":
    case "time_nanos":
    case "timestamp_micros":
      return { [value.kind]: numberText(value.value) } as WireAtom;
    case "interval":
      return {
        interval: {
          months: numberText(value.months),
          days: numberText(value.days),
          nanos: numberText(value.nanos),
        },
      };
    case "float": {
      if (!Number.isFinite(value.value) || ![32, 64].includes(value.width))
        throw new TypeError("Expected a finite logical float");
      budget.data(value.width / 8);
      const buffer = new ArrayBuffer(value.width / 8);
      const view = new DataView(buffer);
      if (value.width === 32) {
        view.setFloat32(0, value.value, true);
        if (!Number.isFinite(view.getFloat32(0, true))) throw new TypeError("Float32 overflow");
      } else view.setFloat64(0, value.value, true);
      return { float_bits: hex(new Uint8Array(buffer), 8) };
    }
    case "boolean":
      return { boolean: value.value };
    case "utf8":
      budget.data(Buffer.byteLength(value.value));
      return { utf8: value.value };
    case "binary":
    case "uuid":
      if (value.kind === "uuid" && value.value.length !== 16)
        throw new TypeError("Invalid logical UUID width");
      budget.data(value.value.length);
      return { [value.kind]: hex(value.value, 1024 * 1024) } as WireAtom;
  }
}
export function decodeAtom(value: WireAtom, budget = new Budget(65536)): Atom {
  if ("float_bits" in value) {
    budget.data(value.float_bits.length / 2);
    const bytes = unhex(value.float_bits, 8);
    if (bytes.length !== 4 && bytes.length !== 8)
      throw new TypeError("Invalid logical float width");
    const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
    const number = bytes.length === 4 ? view.getFloat32(0, true) : view.getFloat64(0, true);
    if (!Number.isFinite(number)) throw new TypeError("Nonfinite logical float");
    return { kind: "float", width: bytes.length === 4 ? 32 : 64, value: number };
  }
  if ("interval" in value)
    return {
      kind: "interval",
      months: exact(value.interval.months),
      days: exact(value.interval.days),
      nanos: exact(value.interval.nanos),
    };
  if ("boolean" in value) return { kind: "boolean", value: value.boolean };
  if ("utf8" in value) {
    budget.data(Buffer.byteLength(value.utf8));
    return { kind: "utf8", value: value.utf8 };
  }
  if ("binary" in value) {
    budget.data(value.binary.length / 2);
    return { kind: "binary", value: unhex(value.binary, 1024 * 1024) };
  }
  if ("uuid" in value) {
    if (value.uuid.length !== 32) throw new TypeError("Invalid logical UUID width");
    budget.data(16);
    return { kind: "uuid", value: unhex(value.uuid, 16) };
  }
  const [kind, text] = Object.entries(value)[0]!;
  return {
    kind: kind as
      | "signed"
      | "unsigned"
      | "decimal"
      | "date_days"
      | "time_nanos"
      | "timestamp_micros",
    value: exact(text as string),
  };
}
function conflictOrder(length: number): (counter: bigint, replica: bigint) => void {
  if (length < 2 || length > 8) throw new TypeError("Expected two to eight conflict alternatives");
  let previousCounter = 0n;
  let previousReplica = 0n;
  return (counter, replica) => {
    if (
      typeof counter !== "bigint" ||
      typeof replica !== "bigint" ||
      counter <= 0n ||
      counter >= 1n << 64n ||
      replica <= 0n ||
      replica >= 1n << 64n ||
      counter < previousCounter ||
      (counter === previousCounter && replica <= previousReplica)
    )
      throw new TypeError("Expected increasing positive conflict dots");
    previousCounter = counter;
    previousReplica = replica;
  };
}
export function encodeCell(value: Cell, budget = new Budget(65536), depth = 0): WireCell {
  budget.enter(depth);
  switch (value.state) {
    case "null":
      return { null: {} };
    case "missing":
      return { missing: {} };
    case "type_error":
      return { type_error: value.actual };
    case "conflict": {
      const dot = conflictOrder(value.alternatives.length);
      return {
        conflict: value.alternatives.map((item) => {
          dot(item.counter, item.replica);
          if (!["null", "type_error", "value"].includes(item.cell.state))
            throw new TypeError("Invalid conflict alternative");
          return {
            counter: numberText(item.counter),
            replica: numberText(item.replica),
            value: encodeCell(item.cell, budget, depth) as Exclude<
              WireCell,
              { missing: unknown } | { conflict: unknown }
            >,
          };
        }),
      };
    }
    case "value": {
      const cell = (value: Cell) => encodeCell(value, budget, depth + 1);
      const item = value.value;
      switch (item.kind) {
        case "atom":
          return { value: { atom: encodeAtom(item.atom, budget) } };
        case "structure":
        case "list":
        case "array":
          return { value: { [item.kind]: item.cells.map(cell) } as WireValue };
        case "map":
          return {
            value: {
              map: item.entries.map((entry) => {
                budget.enter(depth + 1);
                return { key: encodeAtom(entry.key, budget), value: cell(entry.value) };
              }),
            },
          };
        case "tagged_union":
          return { value: { tagged_union: { index: item.index, value: cell(item.value) } } };
        case "json":
          budget.data(Buffer.byteLength(item.json));
          return { value: { json: item.json } };
      }
    }
  }
}
export function decodeCell(value: WireCell, budget = new Budget(65536), depth = 0): Cell {
  budget.enter(depth);
  const cell = (value: WireCell) => decodeCell(value, budget, depth + 1);
  if ("missing" in value) return { state: "missing" };
  if ("null" in value) return { state: "null" };
  if ("type_error" in value) return { state: "type_error", actual: value.type_error };
  if ("conflict" in value) {
    const dot = conflictOrder(value.conflict.length);
    return {
      state: "conflict",
      alternatives: value.conflict.map((item) => {
        const counter = exact(item.counter),
          replica = exact(item.replica);
        dot(counter, replica);
        if ("missing" in item.value || "conflict" in item.value)
          throw new TypeError("Invalid conflict alternative");
        return {
          counter,
          replica,
          cell: decodeCell(item.value, budget, depth) as Cell & {
            state: "null" | "type_error" | "value";
          },
        };
      }),
    };
  }
  const item = value.value;
  let decoded: Value;
  if ("atom" in item) decoded = { kind: "atom", atom: decodeAtom(item.atom, budget) };
  else if ("structure" in item) decoded = { kind: "structure", cells: item.structure.map(cell) };
  else if ("list" in item) decoded = { kind: "list", cells: item.list.map(cell) };
  else if ("array" in item) decoded = { kind: "array", cells: item.array.map(cell) };
  else if ("map" in item)
    decoded = {
      kind: "map",
      entries: item.map.map((entry) => {
        budget.enter(depth + 1);
        return { key: decodeAtom(entry.key, budget), value: cell(entry.value) };
      }),
    };
  else if ("tagged_union" in item)
    decoded = {
      kind: "tagged_union",
      index: item.tagged_union.index,
      value: cell(item.tagged_union.value),
    };
  else {
    budget.data(Buffer.byteLength(item.json));
    decoded = { kind: "json", json: item.json };
  }
  return { state: "value", value: decoded };
}
