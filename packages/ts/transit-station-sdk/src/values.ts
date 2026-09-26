import { inspect } from "node:util";
import {
  Credential,
  ProcessRef,
  ResourceRef,
  OperationIdentity,
  MutationReceipt,
  CodecError,
  limits,
  type ClientConfig,
} from "@transit/client";
import { integer, owned, text, configuration } from "@transit/client/internal";

export interface Codec<T> {
  readonly typeId: string;
  readonly version: number;
  readonly maxEncodedBytes: number;
  encode(value: T): Uint8Array;
  decode(bytes: Uint8Array): T;
}
export function encode<T>(codec: Codec<T>, value: T, bound: number): Uint8Array {
  try {
    integer(codec.version, "codec version");
    integer(codec.maxEncodedBytes, "codec bound", 1, bound);
    if (!text(codec.typeId)) throw new TypeError();
    return owned(codec.encode(value), codec.maxEncodedBytes);
  } catch {
    throw new CodecError("Application encoding failed");
  }
}
export function decode<T>(codec: Codec<T>, bytes: Uint8Array, bound: number): T {
  try {
    integer(codec.version, "codec version");
    integer(codec.maxEncodedBytes, "codec bound", 1, bound);
    if (!text(codec.typeId)) throw new TypeError();
    return codec.decode(owned(bytes, codec.maxEncodedBytes));
  } catch {
    throw new CodecError("Application decoding failed");
  }
}
export class Key<T> {
  readonly codec: Codec<T>;
  readonly #name: Uint8Array;
  constructor(name: Uint8Array, codec: Codec<T>) {
    this.#name = owned(name, limits.value_bytes);
    if (!this.#name.length || this.#name[0] === 0)
      throw new TypeError("Application keys must be nonempty and cannot begin with zero");
    this.codec = codec;
    Object.freeze(this);
  }
  get name(): Uint8Array {
    return new Uint8Array(this.#name);
  }
  [inspect.custom](): string {
    return "Key(application codec)";
  }
}
export interface Found<T> {
  readonly value: T;
}
export interface Basis {
  readonly resource: ResourceRef;
  readonly revision: number;
  readonly schema: Uint8Array;
}
export interface Page<T> {
  readonly entries: readonly T[];
  readonly next: string | undefined;
  readonly basis?: Basis;
}
export interface KVEntry {
  readonly key: Uint8Array;
  readonly value: Uint8Array;
  readonly revision: number;
}
export class Activation {
  readonly process: ProcessRef;
  readonly generation: number;
  readonly credential: Credential;
  constructor(process: ProcessRef, principal: number, generation: number, seedFile: string) {
    if (!(process instanceof ProcessRef)) throw new TypeError("Expected ProcessRef");
    this.process = process;
    this.generation = integer(generation, "generation");
    this.credential = new Credential(process.realm, integer(principal, "principal"), seedFile);
    Object.freeze(this);
  }
}
export interface ServiceConfig extends ClientConfig {
  readonly activation: Activation;
  readonly association?: string;
  readonly queryResults?: boolean;
}
export function serviceConfiguration(
  value: ServiceConfig,
): Readonly<Required<Omit<ServiceConfig, "nativeHost">> & Pick<ServiceConfig, "nativeHost">> {
  const client = configuration(value);
  if (!(value.activation instanceof Activation)) throw new TypeError("Expected Activation");
  const association = text(value.association ?? "data", limits.value_bytes);
  if (!association) throw new TypeError("An association is required");
  if (value.queryResults !== undefined && typeof value.queryResults !== "boolean")
    throw new TypeError("queryResults must be boolean");
  return Object.freeze({
    ...client,
    activation: value.activation,
    association,
    queryResults: value.queryResults ?? false,
  });
}
export type FailurePolicy = "stop" | "block-input";
export type WaitPolicy =
  | { readonly kind: "untimed" }
  | { readonly kind: "until"; readonly deadlineMs: number; readonly observer: number };
export type Origin =
  | { readonly kind: "external"; readonly principal: number; readonly policyRevision: number }
  | {
      readonly kind: "process";
      readonly process: ProcessRef;
      readonly turn: number;
      readonly output: number;
    }
  | {
      readonly kind: "effect";
      readonly effect: number;
      readonly attempt: number;
      readonly executor: number;
    };
export type Cast<T> = {
  readonly kind: "cast";
  readonly value: T;
  readonly position: number;
  readonly origin: Origin;
};
export type Call<T> = {
  readonly kind: "call";
  readonly value: T;
  readonly position: number;
  readonly origin: Origin;
  readonly correlation: bigint;
};
export type Reply<T> = {
  readonly kind: "reply";
  readonly value: T;
  readonly position: number;
  readonly origin: Origin;
  readonly correlation: bigint;
};
export type Incoming<T> = Cast<T> | Call<T> | Reply<T>;
export interface Control {
  readonly kind: "cancel" | "timeout";
  readonly position: number;
  readonly origin: Origin;
  readonly correlation: bigint;
}
export class FrozenMutation {
  readonly identity: OperationIdentity;
  readonly purpose: "permit" | "open" | "commit";
  readonly inputPosition: number;
  readonly #bytes: Uint8Array;
  constructor(
    identity: OperationIdentity,
    purpose: "permit" | "open" | "commit",
    inputPosition: number,
    bytes: Uint8Array,
  ) {
    if (!(identity instanceof OperationIdentity) || !["permit", "open", "commit"].includes(purpose))
      throw new TypeError("Invalid mutation metadata");
    this.identity = identity;
    this.purpose = purpose;
    this.inputPosition = integer(inputPosition, "input position");
    this.#bytes = owned(bytes, limits.max_body);
    Object.freeze(this);
  }
  export(): Uint8Array {
    return new Uint8Array(this.#bytes);
  }
  [inspect.custom](): object {
    return { identity: this.identity, purpose: this.purpose, inputPosition: this.inputPosition };
  }
}
export interface RecoveryStore {
  beforeDispatch(mutation: FrozenMutation): Promise<void>;
  confirmed(identity: OperationIdentity, receipt: MutationReceipt): Promise<void>;
}
export type Recovery =
  | { readonly kind: "fence-on-restart" }
  | { readonly kind: "persist-before-dispatch"; readonly store: RecoveryStore };
export type RunnerEvent =
  | {
      readonly kind: "committed";
      readonly inputPosition: number;
      readonly receipt: MutationReceipt;
    }
  | {
      readonly kind: "blocked";
      readonly inputPosition?: number;
      readonly receipt?: MutationReceipt;
    }
  | {
      readonly kind: "needs-recovery";
      readonly mutation: FrozenMutation;
      readonly phase: string;
      readonly error: unknown;
      readonly receipt?: MutationReceipt;
    }
  | { readonly kind: "idle" | "progress" | "stopped" };

export function wide(value: unknown, signed = false): bigint {
  const low = signed ? -(1n << 63n) : 0n,
    high = signed ? (1n << 63n) - 1n : (1n << 64n) - 1n;
  if (typeof value !== "bigint" || value < low || value > high)
    throw new TypeError("Expected a full-width bigint in range");
  return value;
}
export function nativeWide(value: string, signed = false): bigint {
  if (typeof value !== "string" || value.length > 20 || !/^(0|-?[1-9][0-9]*)$/.test(value))
    throw new TypeError("Invalid native full-width integer");
  return wide(BigInt(value), signed);
}
export const u64 = Object.freeze({
  checkedAdd(left: bigint, right: bigint): bigint {
    return wide(wide(left) + wide(right));
  },
});
export class ReadVersion {
  readonly pid: number;
  readonly input: number;
  readonly index: number;
  constructor(pid: number, input: number, index: number) {
    this.pid = integer(pid, "pid");
    this.input = integer(input, "input");
    this.index = integer(index, "version index", 0, 255);
    Object.freeze(this);
  }
}
export interface Budgets {
  readonly mutations: number;
  readonly outputs: number;
  readonly views: number;
  readonly retainedReads: number;
  readonly retains: number;
  readonly releases: number;
}
