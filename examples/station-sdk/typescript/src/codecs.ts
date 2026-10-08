import type { Codec } from "@transit/station";

export type Add = { readonly kind: "add"; readonly value: bigint };
export type Read = { readonly kind: "read" };
export type Start = { readonly kind: "start" };
export type Total = { readonly kind: "total"; readonly value: bigint };
export type Initialize = { readonly kind: "initialize" };
export type Insert = {
  readonly kind: "insert";
  readonly key: bigint;
  readonly value: bigint | null;
};
export type Rows = { readonly kind: "rows" };
export type Advance = { readonly kind: "advance" };
export type NotReady = { readonly kind: "notReady" };
export type Update = {
  readonly kind: "update";
  readonly key: bigint;
  readonly value: bigint | null;
};
export type Delete = { readonly kind: "delete"; readonly key: bigint };
export type CounterMessage = Add | Read | Start | Total;
export type TableCommand = Initialize | Insert | Update | Delete;
export type TableMessage = TableCommand | Rows | Advance;
export type QueryMessage = TableMessage | Start | NotReady;

function wide(value: bigint, signed = false): bigint {
  const low = signed ? -(1n << 63n) : 0n,
    high = signed ? (1n << 63n) - 1n : (1n << 64n) - 1n;
  if (typeof value !== "bigint" || value < low || value > high)
    throw new TypeError("Integer outside the application format");
  return value;
}
function prefix(data: Uint8Array, letter: number): DataView {
  if (
    !(data instanceof Uint8Array) ||
    data.length < 4 ||
    data[0] !== 84 ||
    data[1] !== 83 ||
    data[2] !== letter ||
    data[3] !== 1
  )
    throw new TypeError("Unsupported application format");
  return new DataView(data.buffer, data.byteOffset, data.byteLength);
}
function bytes(letter: number, length: number, tag?: number): Uint8Array {
  const output = new Uint8Array(length);
  output.set([84, 83, letter, 1]);
  if (tag !== undefined) output[4] = tag;
  return output;
}
export const counter: Codec<CounterMessage> = Object.freeze({
  typeId: "transit.examples.counter",
  version: 1,
  maxEncodedBytes: 13,
  encode(value: CounterMessage): Uint8Array {
    const tag = ({ add: 1, read: 2, start: 3, total: 4 } as const)[value.kind];
    if (tag === undefined) throw new TypeError("Unsupported counter message");
    const output = bytes(67, tag === 1 || tag === 4 ? 13 : 5, tag);
    if (value.kind === "add" || value.kind === "total")
      new DataView(output.buffer).setBigUint64(5, wide(value.value), true);
    return output;
  },
  decode(data: Uint8Array): CounterMessage {
    const view = prefix(data, 67),
      tag = data[4];
    if ((tag === 1 || tag === 4) && data.length === 13)
      return Object.freeze({
        kind: tag === 1 ? "add" : "total",
        value: view.getBigUint64(5, true),
      });
    if (tag === 2 && data.length === 5) return Object.freeze({ kind: "read" });
    if (tag === 3 && data.length === 5) return Object.freeze({ kind: "start" });
    throw new TypeError("Invalid counter message");
  },
});
export const u64Codec: Codec<bigint> = Object.freeze({
  typeId: "transit.examples.u64",
  version: 1,
  maxEncodedBytes: 12,
  encode(value: bigint): Uint8Array {
    const output = bytes(85, 12);
    new DataView(output.buffer).setBigUint64(4, wide(value), true);
    return output;
  },
  decode(data: Uint8Array): bigint {
    const view = prefix(data, 85);
    if (data.length !== 12) throw new TypeError("Invalid u64 value");
    return view.getBigUint64(4, true);
  },
});
export const query: Codec<QueryMessage> = Object.freeze({
  typeId: "transit.examples.query",
  version: 1,
  maxEncodedBytes: 22,
  encode(value: QueryMessage): Uint8Array {
    const tag = (
      {
        initialize: 1,
        insert: 2,
        rows: 3,
        start: 4,
        advance: 5,
        notReady: 6,
        update: 7,
        delete: 8,
      } as const
    )[value.kind];
    if (tag === undefined) throw new TypeError("Unsupported query message");
    const output = bytes(
      81,
      value.kind === "insert" || value.kind === "update"
        ? value.value === null
          ? 14
          : 22
        : value.kind === "delete"
          ? 13
          : 5,
      tag,
    );
    if (value.kind === "delete")
      new DataView(output.buffer).setBigInt64(5, wide(value.key, true), true);
    if (value.kind === "insert" || value.kind === "update") {
      const view = new DataView(output.buffer);
      view.setBigInt64(5, wide(value.key, true), true);
      output[13] = value.value === null ? 0 : 1;
      if (value.value !== null) view.setBigInt64(14, wide(value.value, true), true);
    }
    return output;
  },
  decode(data: Uint8Array): QueryMessage {
    const view = prefix(data, 81),
      tag = data[4];
    if (data.length === 5 && (tag === 1 || tag === 3 || tag === 4 || tag === 5 || tag === 6))
      return Object.freeze({
        kind:
          tag === 1
            ? "initialize"
            : tag === 3
              ? "rows"
              : tag === 4
                ? "start"
                : tag === 5
                  ? "advance"
                  : "notReady",
      });
    if (data.length === 13 && tag === 8)
      return Object.freeze({ kind: "delete", key: view.getBigInt64(5, true) });
    if (
      (tag === 2 || tag === 7) &&
      ((data.length === 14 && data[13] === 0) || (data.length === 22 && data[13] === 1))
    ) {
      return Object.freeze({
        kind: tag === 2 ? "insert" : "update",
        key: view.getBigInt64(5, true),
        value: data[13] === 0 ? null : view.getBigInt64(14, true),
      });
    }
    throw new TypeError("Invalid query message");
  },
});
function selected<T extends { readonly kind: string }, K extends T["kind"]>(
  base: Codec<T>,
  kinds: readonly K[],
): Codec<Extract<T, { kind: K }>> {
  const validate = (value: T): Extract<T, { kind: K }> => {
    if (!kinds.includes(value.kind as K)) throw new TypeError("Message not accepted by this role");
    return value as Extract<T, { kind: K }>;
  };
  return Object.freeze({
    typeId: base.typeId,
    version: base.version,
    maxEncodedBytes: base.maxEncodedBytes,
    encode: (value: Extract<T, { kind: K }>) => base.encode(validate(value)),
    decode: (data: Uint8Array) => validate(base.decode(data)),
  });
}
export const counterCodec = selected(counter, ["add", "read"]);
export const requesterCodec = selected(counter, ["start", "total"]);
export const totalCodec = selected(counter, ["total"]);
export const queryServiceCodec = selected(query, [
  "initialize",
  "insert",
  "rows",
  "advance",
  "update",
  "delete",
]);
export const queryRequesterCodec = selected(query, ["start", "notReady"]);
export const queryReplyCodec = selected(query, ["notReady"]);
