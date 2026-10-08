import { Key, type Codec } from "@transit/station";
import { query, type TableCommand } from "./codecs.ts";

export const MAX_INPUT = (1n << 53n) - 1n;
export const INITIAL = (1n << 64n) - 1n;
export const REJECTIONS = [
  "none",
  "row_exists",
  "row_identity_exists",
  "null_not_allowed",
  "missing_required_field",
  "character_limit_exceeded",
  "overflow",
  "inexact",
] as const;
export interface Queue {
  readonly head: bigint;
  readonly tail: bigint;
  readonly ready: boolean;
}
export interface Work {
  readonly next: bigint;
  readonly command: TableCommand;
}
export interface Outcome {
  readonly state: number;
  readonly admitted: bigint;
  readonly completed: bigint;
  readonly matched: bigint;
  readonly changed: bigint;
  readonly rejection: number;
}
function bounded(value: bigint, low: bigint, high: bigint): bigint {
  if (typeof value !== "bigint" || value < low || value > high)
    throw new TypeError("Invalid Table record integer");
  return value;
}
function byte(value: number, high: number): number {
  if (!Number.isInteger(value) || value < 0 || value > high)
    throw new TypeError("Invalid Table record tag");
  return value;
}
function prefix(data: Uint8Array, tag: number, lengths: readonly number[]): DataView {
  if (
    !(data instanceof Uint8Array) ||
    !lengths.includes(data.length) ||
    data[0] !== 84 ||
    data[1] !== 81 ||
    data[2] !== tag ||
    data[3] !== 1
  )
    throw new TypeError("Invalid Table application record");
  return new DataView(data.buffer, data.byteOffset, data.byteLength);
}
function record(tag: number, length: number): Uint8Array {
  const data = new Uint8Array(length);
  data.set([84, 81, tag, 1]);
  return data;
}
export const queueCodec: Codec<Queue> = Object.freeze({
  typeId: "transit.examples.table.queue",
  version: 1,
  maxEncodedBytes: 21,
  encode(value: Queue): Uint8Array {
    bounded(value.head, 0n, INITIAL);
    bounded(value.tail, 0n, MAX_INPUT);
    if (
      (value.head === 0n) !== (value.tail === 0n) ||
      (value.head !== INITIAL && value.head > value.tail) ||
      typeof value.ready !== "boolean" ||
      (value.head === INITIAL && value.ready)
    )
      throw new TypeError("Invalid Table queue");
    const data = record(77, 21),
      view = new DataView(data.buffer);
    view.setBigUint64(4, value.head, true);
    view.setBigUint64(12, value.tail, true);
    data[20] = Number(value.ready);
    return data;
  },
  decode(data: Uint8Array): Queue {
    const view = prefix(data, 77, [21]);
    byte(data[20]!, 1);
    const value = Object.freeze({
      head: view.getBigUint64(4, true),
      tail: view.getBigUint64(12, true),
      ready: data[20] === 1,
    });
    queueCodec.encode(value);
    return value;
  },
});
export const workCodec: Codec<Work> = Object.freeze({
  typeId: "transit.examples.table.work",
  version: 1,
  maxEncodedBytes: 34,
  encode(value: Work): Uint8Array {
    bounded(value.next, 0n, MAX_INPUT);
    if (!["initialize", "insert", "update", "delete"].includes(value.command.kind))
      throw new TypeError("Invalid queued command");
    const command = query.encode(value.command),
      data = record(87, 12 + command.length);
    new DataView(data.buffer).setBigUint64(4, value.next, true);
    data.set(command, 12);
    return data;
  },
  decode(data: Uint8Array): Work {
    const view = prefix(data, 87, [17, 25, 26, 34]),
      command = query.decode(data.subarray(12));
    if (
      command.kind !== "initialize" &&
      command.kind !== "insert" &&
      command.kind !== "update" &&
      command.kind !== "delete"
    )
      throw new TypeError("Invalid queued command");
    const value = Object.freeze({ next: view.getBigUint64(4, true), command });
    workCodec.encode(value);
    return value;
  },
});
export const outcomeCodec: Codec<Outcome> = Object.freeze({
  typeId: "transit.examples.table.outcome",
  version: 1,
  maxEncodedBytes: 38,
  encode(value: Outcome): Uint8Array {
    byte(value.state, 3);
    byte(value.rejection, REJECTIONS.length - 1);
    bounded(value.admitted, 1n, MAX_INPUT);
    bounded(value.completed, value.admitted, MAX_INPUT);
    bounded(value.matched, 0n, INITIAL);
    bounded(value.changed, 0n, value.matched);
    if (
      (value.state !== 1 && (value.matched !== 0n || value.changed !== 0n)) ||
      (value.state === 2) !== (value.rejection !== 0)
    )
      throw new TypeError("Invalid Table outcome");
    const data = record(79, 38),
      view = new DataView(data.buffer);
    data[4] = value.state;
    [value.admitted, value.completed, value.matched, value.changed].forEach((n, i) =>
      view.setBigUint64(5 + 8 * i, n, true),
    );
    data[37] = value.rejection;
    return data;
  },
  decode(data: Uint8Array): Outcome {
    const view = prefix(data, 79, [38]);
    const value = Object.freeze({
      state: data[4]!,
      admitted: view.getBigUint64(5, true),
      completed: view.getBigUint64(13, true),
      matched: view.getBigUint64(21, true),
      changed: view.getBigUint64(29, true),
      rejection: data[37]!,
    });
    outcomeCodec.encode(value);
    return value;
  },
});
export const QUEUE = new Key(new TextEncoder().encode("table.queue"), queueCodec);
function key<T>(prefix: string, identity: bigint, codec: Codec<T>): Key<T> {
  bounded(identity, 1n, INITIAL);
  return new Key(new TextEncoder().encode(prefix + identity.toString(16).padStart(16, "0")), codec);
}
export const workKey = (identity: bigint): Key<Work> => key("table.work.", identity, workCodec);
export const outcomeKey = (identity: bigint): Key<Outcome> =>
  key("table.done.", identity, outcomeCodec);
