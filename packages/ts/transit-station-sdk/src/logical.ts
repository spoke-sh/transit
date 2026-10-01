/** Owned logical documents validated by Zig, independent of native query admission. */
import { IncompatibleNative } from "@transit/client";
import { Bridge } from "./bridge.ts";
import { hex, unhex } from "./framing.ts";
import type { LogicalCodecAction, LogicalCodecResult } from "./wire.ts";

const bridges = new WeakMap<Codec, Bridge>();
function bridge(codec: Codec): Bridge {
  const result = bridges.get(codec);
  if (!result) throw new TypeError("Expected an owned logical codec");
  return result;
}
function request(codec: Codec, action: LogicalCodecAction): Promise<LogicalCodecResult> {
  return bridge(codec).logicalCodec(action);
}

export type Rounding = "reject" | "toward_zero" | "nearest_even";
type TypeResult = Extract<LogicalCodecResult, { type: unknown }>["type"];
type ValueResult = Extract<LogicalCodecResult, { value: unknown }>["value"];

export class Type {
  readonly json: string;
  readonly equality: boolean;
  readonly ordering: boolean;
  readonly #bytes: string;
  readonly #fingerprint: string;
  private constructor(value: TypeResult) {
    this.json = value.json;
    this.equality = value.equality;
    this.ordering = value.ordering;
    this.#bytes = value.bytes;
    this.#fingerprint = value.fingerprint;
    Object.freeze(this);
  }
  get bytes(): Uint8Array {
    return unhex(this.#bytes, 16384);
  }
  get fingerprint(): Uint8Array {
    return unhex(this.#fingerprint, 32);
  }
  static async fromJson(codec: Codec, document: string): Promise<Type> {
    const result = await request(codec, { type_json: document });
    if (!("type" in result)) throw new IncompatibleNative("Expected logical type");
    return new Type(result.type);
  }
  static async fromBytes(codec: Codec, bytes: Uint8Array): Promise<Type> {
    const result = await request(codec, { type_bytes: hex(bytes, 16384) });
    if (!("type" in result)) throw new IncompatibleNative("Expected logical type");
    return new Type(result.type);
  }
}

export class Value {
  readonly json: string;
  readonly #bytes: string;
  private constructor(value: ValueResult) {
    this.json = value.json;
    this.#bytes = value.bytes;
    Object.freeze(this);
  }
  get bytes(): Uint8Array {
    return unhex(this.#bytes, 96 * 1024);
  }
  private static async decode(codec: Codec, action: LogicalCodecAction): Promise<Value> {
    const result = await request(codec, action);
    if (!("value" in result)) throw new IncompatibleNative("Expected logical value");
    return new Value(result.value);
  }
  static fromJson(codec: Codec, document: string): Promise<Value> {
    return Value.decode(codec, { value_json: document });
  }
  static fromBytes(codec: Codec, bytes: Uint8Array): Promise<Value> {
    return Value.decode(codec, { value_bytes: hex(bytes, 96 * 1024) });
  }
  static bind(codec: Codec, type: Type, literal: string): Promise<Value> {
    return Value.decode(codec, { bind: { type_json: type.json, literal } });
  }
  cast(codec: Codec, target: Type, rounding: Rounding = "reject"): Promise<Value> {
    return Value.decode(codec, {
      cast: { value_json: this.json, type_json: target.json, rounding },
    });
  }
}

/** One owned local host. Returned values survive close; methods perform no admission. */
export class Codec {
  private constructor(bridge: Bridge) {
    bridges.set(this, bridge);
  }
  static async open(nativeHost?: string): Promise<Codec> {
    const bridge = await Bridge.local(nativeHost);
    try {
      const result = await bridge.logicalCodec({ capabilities: {} });
      if (!("capabilities" in result) || !result.capabilities.logical_json)
        throw new IncompatibleNative("Logical codecs are unavailable");
      return new Codec(bridge);
    } catch (error) {
      await bridge.close();
      throw error;
    }
  }
  async equal(left: Value, right: Value): Promise<boolean> {
    const result = await request(this, { equal: { left_json: left.json, right_json: right.json } });
    if (!("equal" in result)) throw new IncompatibleNative("Expected equality result");
    return result.equal;
  }
  async order(left: Value, right: Value): Promise<"lt" | "eq" | "gt"> {
    const result = await request(this, { order: { left_json: left.json, right_json: right.json } });
    if (!("order" in result)) throw new IncompatibleNative("Expected order result");
    return result.order;
  }
  async hash(value: Value): Promise<Uint8Array> {
    const result = await request(this, { hash: value.json });
    if (!("hash" in result)) throw new IncompatibleNative("Expected hash result");
    return unhex(result.hash, 32);
  }
  async arrow(value: Value): Promise<Uint8Array> {
    const result = await request(this, { arrow: value.json });
    if (!("arrow" in result)) throw new IncompatibleNative("Expected Arrow result");
    return unhex(result.arrow.ipc, 65536);
  }
  close(): Promise<void> {
    return bridge(this).close();
  }
}
