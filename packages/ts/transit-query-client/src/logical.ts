/** Browser admission for the shared logical contract. These checks confer no
 * source authority and never coerce a malformed response into a typed value. */
import type { Response } from "./types";

type Page = Extract<Response, { page: unknown }>["page"];
export type LogicalField = Page["evidence"]["columns"][number];
export type LogicalType = LogicalField["type"];
export type LogicalCell = Page["cells"][number][number];
type Value = Extract<LogicalCell, { value: unknown }>["value"];
type Atom = Extract<Value, { atom: unknown }>["atom"];
const encoder = new TextEncoder();
export const logicalText = (text: string, bound: number) =>
  !/[\uD800-\uDFFF]/u.test(text) && encoder.encode(text).length <= bound;
export const logicalName = (name: string) =>
  name.length > 0 && !name.includes("\0") && logicalText(name, 255);
export const logicalHex = (text: string, bound: number) =>
  text.length <= 2 * bound && /^(?:[0-9a-f]{2})*$/.test(text);
export function logicalInteger(text: string, bits: number, signed: boolean): boolean {
  if (text.length > 40 || !/^(0|[1-9][0-9]*|-[1-9][0-9]*)$/.test(text)) return false;
  const value = BigInt(text),
    upper = 1n << BigInt(signed ? bits - 1 : bits);
  return value >= (signed ? -upper : 0n) && value < upper;
}

/** Bound recursive generated validators, including hostile cyclic JS values.
 * HTTP bytes are bounded separately before JSON parsing. */
export function boundedQueryJson(input: unknown, maximumBytes = 1048576): boolean {
  let nodes = 0,
    bytes = 0;
  function visit(value: unknown, depth: number): boolean {
    if (++nodes > 1048576 || depth > 96) return false;
    if (typeof value === "string") {
      if (!logicalText(value, 1048576)) return false;
      bytes += encoder.encode(value).length;
      return bytes <= maximumBytes;
    }
    if (value === null || typeof value === "boolean") return true;
    if (typeof value === "number") return Number.isFinite(value);
    if (typeof value !== "object") return false;
    if (Array.isArray(value))
      return value.length <= 1048576 && value.every((v) => visit(v, depth + 1));
    for (const [key, child] of Object.entries(value)) {
      if (!visit(key, depth + 1) || !visit(child, depth + 1)) return false;
    }
    return true;
  }
  return visit(input, 0);
}

export function logicalTypeValid(type: LogicalType): boolean {
  let nodes = 0,
    names = 0;
  function visit(value: LogicalType, depth: number): boolean {
    if (depth >= 16 || ++nodes > 256) return false;
    if ("decimal" in value)
      return (
        value.decimal.precision >= 1 &&
        value.decimal.precision <= 38 &&
        value.decimal.scale <= value.decimal.precision
      );
    if ("structure" in value || "tagged_union" in value) {
      const fields = "structure" in value ? value.structure : value.tagged_union;
      if (
        !fields.length ||
        fields.length > 255 ||
        new Set(fields.map((f) => f.name)).size !== fields.length
      )
        return false;
      return fields.every((field) => {
        if (!logicalName(field.name)) return false;
        names += encoder.encode(field.name).length;
        return (
          names <= 4096 &&
          (!("tagged_union" in value) || !field.optional) &&
          visit(field.type, depth + 1)
        );
      });
    }
    if ("list" in value) return visit(value.list.type, depth + 1);
    if ("array" in value)
      return value.array.length > 0 && visit(value.array.element.type, depth + 1);
    if ("map" in value)
      return (
        !["structure", "list", "array", "map", "tagged_union", "json", "interval"].some(
          (k) => k in value.map.key,
        ) &&
        visit(value.map.key, depth + 1) &&
        visit(value.map.value.type, depth + 1)
      );
    return true; // Scalar tags and numeric field ranges are generated-schema checks.
  }
  return visit(type, 0);
}
export function logicalTypeEqual(left: LogicalType, right: LogicalType): boolean {
  function canonical(value: unknown): unknown {
    if (Array.isArray(value)) return value.map(canonical);
    if (value !== null && typeof value === "object")
      return Object.fromEntries(
        Object.entries(value)
          .sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0))
          .map(([k, v]) => [k, canonical(v)]),
      );
    return value;
  }
  return JSON.stringify(canonical(left)) === JSON.stringify(canonical(right));
}
export function logicalColumnsValid(columns: LogicalField[]): boolean {
  return columns.length > 0 && columns.length <= 128 && logicalTypeValid({ structure: columns });
}
export function logicalFloat(bits: string): number {
  const bytes = Uint8Array.from(bits.match(/../g) ?? [], (b) => Number.parseInt(b, 16));
  const view = new DataView(bytes.buffer);
  return bits.length === 8 ? view.getFloat32(0, true) : view.getFloat64(0, true);
}
export function logicalAtomValid(atom: Atom, type: LogicalType): boolean {
  const kind = Object.keys(type)[0]!;
  const integer = /^(u?int)(8|16|32|64|128)$/.exec(kind);
  if (integer)
    return integer[1] === "int"
      ? "signed" in atom && logicalInteger(atom.signed, Number(integer[2]), true)
      : "unsigned" in atom && logicalInteger(atom.unsigned, Number(integer[2]), false);
  if ("decimal" in type) {
    if (!("decimal" in atom) || !logicalInteger(atom.decimal, 128, true)) return false;
    const value = BigInt(atom.decimal),
      bound = 10n ** BigInt(type.decimal.precision);
    return value > -bound && value < bound;
  }
  if ("float32" in type || "float64" in type)
    return (
      "float_bits" in atom &&
      atom.float_bits.length === ("float32" in type ? 8 : 16) &&
      logicalHex(atom.float_bits, 8) &&
      Number.isFinite(logicalFloat(atom.float_bits))
    );
  if ("boolean" in type) return "boolean" in atom;
  if ("utf8" in type) return "utf8" in atom && logicalText(atom.utf8, 1048576);
  if ("binary" in type) return "binary" in atom && logicalHex(atom.binary, 1048576);
  if ("date" in type) return "date_days" in atom && logicalInteger(atom.date_days, 32, true);
  if ("time" in type)
    return (
      "time_nanos" in atom &&
      logicalInteger(atom.time_nanos, 64, false) &&
      BigInt(atom.time_nanos) < 86400000000000n
    );
  if ("timestamp" in type)
    return "timestamp_micros" in atom && logicalInteger(atom.timestamp_micros, 64, true);
  if ("interval" in type)
    return (
      "interval" in atom &&
      logicalInteger(atom.interval.months, 32, true) &&
      logicalInteger(atom.interval.days, 32, true) &&
      logicalInteger(atom.interval.nanos, 64, true)
    );
  return "uuid" in type && "uuid" in atom && atom.uuid.length === 32 && logicalHex(atom.uuid, 16);
}
function atomKey(atom: Atom): bigint | number | string | boolean {
  if ("signed" in atom) return BigInt(atom.signed);
  if ("unsigned" in atom) return BigInt(atom.unsigned);
  if ("decimal" in atom) return BigInt(atom.decimal);
  if ("date_days" in atom) return BigInt(atom.date_days);
  if ("time_nanos" in atom) return BigInt(atom.time_nanos);
  if ("timestamp_micros" in atom) return BigInt(atom.timestamp_micros);
  if ("float_bits" in atom) return logicalFloat(atom.float_bits);
  if ("boolean" in atom) return atom.boolean;
  if ("binary" in atom) return atom.binary;
  if ("uuid" in atom) return atom.uuid;
  if ("utf8" in atom)
    return Array.from(encoder.encode(atom.utf8), (b) => b.toString(16).padStart(2, "0")).join("");
  throw new TypeError("Unordered logical map key");
}

/** Validate JSON while preserving numeric lexemes and rejecting duplicate decoded
 * names. JSON.parse alone would silently discard that evidence. */
function jsonDocument(text: string): boolean {
  if (!logicalText(text, 65536)) return false;
  let offset = 0,
    tokens = 1;
  const white = () => {
    while (/[\x20\t\r\n]/.test(text[offset] ?? "!")) offset++;
  };
  function string(): string {
    const start = offset++;
    while (offset < text.length) {
      const ch = text[offset++];
      if (ch === "\\") {
        offset++;
        continue;
      }
      if (ch === '"') {
        const value: unknown = JSON.parse(text.slice(start, offset));
        if (typeof value !== "string" || !logicalText(value, 65536))
          throw new Error("Invalid JSON string");
        if (++tokens > 4096) throw new Error("JSON budget");
        return value;
      }
    }
    throw new Error("Unclosed JSON string");
  }
  function value(depth: number): void {
    white();
    const ch = text[offset];
    if (ch === '"') {
      string();
      return;
    }
    if (ch === "[" || ch === "{") {
      if (depth >= 16 || ++tokens > 4096) throw new Error("JSON budget");
      offset++;
      white();
      const end = ch === "[" ? "]" : "}";
      const keys = new Set<string>();
      if (text[offset] === end) {
        offset++;
        return;
      }
      while (true) {
        if (ch === "{") {
          white();
          if (text[offset] !== '"') throw new Error("Invalid JSON key");
          const key = string();
          if (keys.has(key) || keys.size === 256) throw new Error("JSON fields");
          keys.add(key);
          white();
          if (text[offset++] !== ":" || ++tokens > 4096) throw new Error("JSON colon");
        }
        value(depth + 1);
        white();
        const delimiter = text[offset++];
        if (delimiter === end) return;
        if (delimiter !== "," || ++tokens > 4096) throw new Error("JSON delimiter");
      }
    }
    const match = /^(?:true|false|null|-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?)/.exec(
      text.slice(offset),
    );
    if (!match) throw new Error("Invalid JSON token");
    offset += match[0].length;
  }
  try {
    value(0);
    white();
    return offset === text.length;
  } catch {
    return false;
  }
}

export function logicalCellValid(cell: LogicalCell, field: LogicalField): boolean {
  let children = 0,
    bytes = 0;
  const child = (depth: number) => depth < 16 && ++children <= 65536;
  function atom(value: Atom, type: LogicalType): boolean {
    if (!logicalAtomValid(value, type)) return false;
    if ("utf8" in value) bytes += encoder.encode(value.utf8).length;
    if ("binary" in value) bytes += value.binary.length / 2;
    return bytes <= 1048576;
  }
  function content(value: Value, type: LogicalType, depth: number): boolean {
    if ("atom" in value) return atom(value.atom, type);
    if ("structure" in value)
      return (
        "structure" in type &&
        value.structure.length === type.structure.length &&
        value.structure.every((v, i) => visit(v, type.structure[i]!, depth + 1))
      );
    if ("list" in value)
      return (
        "list" in type &&
        value.list.every((v) => visit(v, { name: "", ...type.list, optional: false }, depth + 1))
      );
    if ("array" in value)
      return (
        "array" in type &&
        value.array.length === type.array.length &&
        value.array.every((v) =>
          visit(v, { name: "", ...type.array.element, optional: false }, depth + 1),
        )
      );
    if ("map" in value)
      return (
        "map" in type &&
        value.map.every(
          (entry, i) =>
            child(depth + 1) &&
            atom(entry.key, type.map.key) &&
            (i === 0 || atomKey(value.map[i - 1]!.key) < atomKey(entry.key)) &&
            visit(entry.value, { name: "", ...type.map.value, optional: false }, depth + 1),
        )
      );
    if ("tagged_union" in value)
      return (
        "tagged_union" in type &&
        value.tagged_union.index < type.tagged_union.length &&
        visit(value.tagged_union.value, type.tagged_union[value.tagged_union.index]!, depth + 1)
      );
    bytes += encoder.encode(value.json).length;
    return "json" in type && bytes <= 1048576 && jsonDocument(value.json);
  }
  function visit(value: LogicalCell, expected: LogicalField, depth: number): boolean {
    if (!child(depth)) return false;
    if ("missing" in value) return expected.optional;
    if ("null" in value) return expected.nullable;
    if ("type_error" in value) return true;
    if ("value" in value) return content(value.value, expected.type, depth);
    if (value.conflict.length < 2 || value.conflict.length > 8) return false;
    let previous = [0n, 0n];
    return value.conflict.every((a) => {
      if (!logicalInteger(a.counter, 64, false) || !logicalInteger(a.replica, 64, false))
        return false;
      const counter = BigInt(a.counter),
        replica = BigInt(a.replica);
      if (
        counter === 0n ||
        replica === 0n ||
        counter < previous[0]! ||
        (counter === previous[0] && replica <= previous[1]!)
      )
        return false;
      previous = [counter, replica];
      return visit(a.value, expected, depth);
    });
  }
  return visit(cell, field, 0);
}

export function logicalTypeText(type: LogicalType): string {
  if ("decimal" in type) return `DECIMAL(${type.decimal.precision}, ${type.decimal.scale})`;
  if ("timestamp" in type) return type.timestamp === "utc" ? "TIMESTAMP UTC" : "TIMESTAMP";
  if ("list" in type) return `LIST(${logicalTypeText(type.list.type)})`;
  if ("array" in type)
    return `ARRAY(${logicalTypeText(type.array.element.type)}, ${type.array.length})`;
  if ("map" in type)
    return `MAP(${logicalTypeText(type.map.key)}, ${logicalTypeText(type.map.value.type)})`;
  if ("structure" in type || "tagged_union" in type) {
    const fields = "structure" in type ? type.structure : type.tagged_union;
    return `${"structure" in type ? "STRUCT" : "UNION"}(${fields.map((f) => `${JSON.stringify(f.name)} ${logicalTypeText(f.type)}`).join(", ")})`;
  }
  return Object.keys(type)[0]!.toUpperCase();
}
export function logicalCellText(cell: LogicalCell, type?: LogicalType): string {
  if ("missing" in cell) return "MISSING";
  if ("null" in cell) return "NULL";
  if ("type_error" in cell) return `TYPE ERROR (${cell.type_error})`;
  if ("conflict" in cell)
    return `CONFLICT [${cell.conflict.map((a) => `${a.counter}/${a.replica}: ${logicalCellText(a.value, type)}`).join("; ")}]`;
  const value = cell.value;
  if ("atom" in value) {
    const atom = value.atom;
    if ("signed" in atom) return atom.signed;
    if ("unsigned" in atom) return atom.unsigned;
    if ("decimal" in atom) {
      if (!type || !("decimal" in type)) return `${atom.decimal} (decimal coefficient)`;
      const scale = type.decimal.scale,
        negative = atom.decimal.startsWith("-");
      const digits = (negative ? atom.decimal.slice(1) : atom.decimal).padStart(scale + 1, "0");
      return `${negative ? "-" : ""}${scale ? `${digits.slice(0, -scale)}.${digits.slice(-scale)}` : digits}`;
    }
    if ("float_bits" in atom) {
      const n = logicalFloat(atom.float_bits);
      return Object.is(n, -0) ? "-0" : String(n);
    }
    if ("boolean" in atom) return String(atom.boolean);
    if ("utf8" in atom) return JSON.stringify(atom.utf8);
    if ("binary" in atom) return `0x${atom.binary}`;
    if ("uuid" in atom)
      return [
        atom.uuid.slice(0, 8),
        atom.uuid.slice(8, 12),
        atom.uuid.slice(12, 16),
        atom.uuid.slice(16, 20),
        atom.uuid.slice(20),
      ].join("-");
    if ("date_days" in atom) return `${atom.date_days} days since 1970-01-01`;
    if ("time_nanos" in atom) return `${atom.time_nanos} ns since midnight`;
    if ("timestamp_micros" in atom)
      return `${atom.timestamp_micros} μs since 1970-01-01${type && "timestamp" in type ? ` (${type.timestamp})` : ""}`;
    return `${atom.interval.months} months, ${atom.interval.days} days, ${atom.interval.nanos} ns`;
  }
  if ("structure" in value)
    return `{${value.structure
      .map((v, i) => {
        const field = type && "structure" in type ? type.structure[i] : undefined;
        return `${field ? JSON.stringify(field.name) : i}: ${logicalCellText(v, field?.type)}`;
      })
      .join(", ")}}`;
  if ("list" in value)
    return `[${value.list.map((v) => logicalCellText(v, type && "list" in type ? type.list.type : undefined)).join(", ")}]`;
  if ("array" in value)
    return `[${value.array.map((v) => logicalCellText(v, type && "array" in type ? type.array.element.type : undefined)).join(", ")}]`;
  if ("map" in value)
    return `{${value.map.map((e) => `${logicalCellText({ value: { atom: e.key } }, type && "map" in type ? type.map.key : undefined)}: ${logicalCellText(e.value, type && "map" in type ? type.map.value.type : undefined)}`).join(", ")}}`;
  if ("tagged_union" in value) {
    const field =
      type && "tagged_union" in type ? type.tagged_union[value.tagged_union.index] : undefined;
    return `${field ? JSON.stringify(field.name) : value.tagged_union.index}: ${logicalCellText(value.tagged_union.value, field?.type)}`;
  }
  return value.json;
}
