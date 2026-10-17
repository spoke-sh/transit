import { inspect } from "node:util";
import { ResourceRef, Closed, IncompatibleNative, UnsupportedCapability } from "@transit/client";
import { integer, owned, text } from "@transit/client/internal";
import { Bridge } from "./bridge.ts";
import { hex, unhex } from "./framing.ts";
import { nativeWide, wide } from "./values.ts";
import type { GrpcCodecAction, GrpcCodecResult, GrpcReadAction, GrpcReadResult } from "./wire.ts";

export type GrpcShape = "unary" | "server_streaming" | "client_streaming" | "bidi";
export interface GrpcMethod {
  readonly path: string;
  readonly shape: GrpcShape;
  readonly descriptorDigest: Uint8Array;
}
export type GrpcMetadataValue =
  | { readonly kind: "literal"; readonly bytes: Uint8Array }
  | { readonly kind: "secret"; readonly binding: string; readonly version: bigint };
export interface GrpcMetadata {
  readonly name: string;
  readonly value: GrpcMetadataValue;
}
export interface GrpcRequest {
  readonly method: GrpcMethod;
  readonly metadata?: readonly GrpcMetadata[];
}
type NativeRequest = Extract<GrpcCodecAction, { prepare: unknown }>["prepare"]["request"];
function requestWire(input: GrpcRequest): NativeRequest {
  const method = input?.method;
  if (!method || !["unary", "server_streaming", "client_streaming", "bidi"].includes(method.shape))
    throw new TypeError("Expected an RPC method and shape");
  const digest = owned(method.descriptorDigest, 32);
  if (digest.length !== 32) throw new TypeError("Expected a 32-byte descriptor digest");
  const entries = input.metadata ?? [];
  if (!Array.isArray(entries) || entries.length > 64)
    throw new TypeError("Expected at most 64 ordered metadata fields");
  return {
    method: {
      path: text(method.path, 512),
      shape: method.shape,
      descriptor_digest: hex(digest, 32),
    },
    metadata: entries.map((entry: GrpcMetadata) => {
      const name = text(entry.name, 8192);
      switch (entry.value?.kind) {
        case "literal":
          return { name, value: { literal: hex(entry.value.bytes, 8192) } };
        case "secret":
          return {
            name,
            value: {
              secret: {
                binding: text(entry.value.binding, 128),
                version: wide(entry.value.version).toString(),
              },
            },
          };
        default:
          throw new TypeError("Expected literal metadata bytes or a secret reference");
      }
    }),
  };
}
export async function grpcMethod(
  descriptor: Uint8Array,
  path: string,
  options: { nativeHost?: string } = {},
): Promise<GrpcMethod> {
  const action: GrpcCodecAction = {
    descriptor: { bytes: hex(descriptor, 65536), method: text(path, 512) },
  };
  const bridge = await Bridge.local(options.nativeHost);
  try {
    const result = await bridge.grpcCodec(action);
    if (!("descriptor" in result))
      throw new IncompatibleNative("Expected a local descriptor method");
    const value = result.descriptor.method;
    return Object.freeze({
      path: value.path,
      shape: value.shape,
      descriptorDigest: unhex(value.descriptor_digest, 32),
    });
  } finally {
    await bridge.close();
  }
}
const construction = Symbol("grpc-native-result");
export class PreparedGrpcRequest {
  readonly resource: ResourceRef;
  readonly namespace: bigint;
  readonly #reference: Uint8Array;
  readonly #metadata: Uint8Array;
  readonly #batch: Uint8Array;
  constructor(
    secret: typeof construction,
    resource: ResourceRef,
    namespace: bigint,
    reference: Uint8Array,
    metadata: Uint8Array,
    batch: Uint8Array,
  ) {
    if (secret !== construction) throw new TypeError("Use prepareGrpc");
    this.resource = resource;
    this.namespace = namespace;
    this.#reference = owned(reference, 145);
    this.#metadata = owned(metadata, 8192);
    this.#batch = owned(batch, 65544);
    Object.freeze(this);
  }
  get reference(): Uint8Array {
    return new Uint8Array(this.#reference);
  }
  get metadata(): Uint8Array {
    return new Uint8Array(this.#metadata);
  }
  get batch(): Uint8Array {
    return new Uint8Array(this.#batch);
  }
  [inspect.custom](): string {
    return "PreparedGrpcRequest(owned bytes)";
  }
}
export async function prepareGrpc(
  resource: ResourceRef,
  namespace: bigint,
  request: GrpcRequest,
  messages: readonly Uint8Array[],
  options: {
    endpointRevision: bigint;
    reconcileBeforeMs: number;
    maxAttempts?: number;
    nativeHost?: string;
  },
): Promise<PreparedGrpcRequest> {
  if (!(resource instanceof ResourceRef)) throw new TypeError("Expected ResourceRef");
  namespace = wide(namespace);
  if (!Array.isArray(messages) || messages.length > 64)
    throw new TypeError("Expected at most 64 original protobuf messages");
  const bytes = messages.map((message: Uint8Array) => hex(message, 16384));
  // Copy and validate before awaiting host construction, so later input mutation
  // cannot change the request this call prepares.
  const action: GrpcCodecAction = {
    prepare: {
      resource: resource.resource,
      namespace: namespace.toString(),
      request: requestWire(request),
      messages: bytes,
      endpoint_revision: wide(options.endpointRevision).toString(),
      reconcile_before_ms: integer(options.reconcileBeforeMs, "reconciliation deadline"),
      max_attempts: integer(options.maxAttempts ?? 1, "attempts", 1, 0xffffffff),
    },
  };
  const bridge = await Bridge.local(options.nativeHost);
  try {
    const result = await bridge.grpcCodec(action);
    if (!("prepared" in result)) throw new IncompatibleNative("Expected a prepared RPC request");
    return new PreparedGrpcRequest(
      construction,
      resource,
      namespace,
      unhex(result.prepared.reference, 145),
      unhex(result.prepared.metadata, 8192),
      unhex(result.prepared.batch, 65544),
    );
  } finally {
    await bridge.close();
  }
}
export type GrpcPhase = "observed" | "closed-unknown" | "not-dispatched";
export type GrpcRejection = "denied" | "invalid-request" | "busy";
type Diagnostic = import("./unified.ts").Diagnostic;
export class GrpcOutcome {
  readonly kind = "grpc-outcome";
  readonly phase: GrpcPhase;
  readonly resource: ResourceRef;
  readonly exchange: bigint;
  readonly effect: number;
  readonly attempt: number;
  readonly status: number | undefined;
  readonly diagnostic: Diagnostic;
  readonly #reference: Uint8Array | undefined;
  constructor(
    secret: typeof construction,
    realm: number,
    value: Extract<GrpcCodecResult, { outcome: unknown }>["outcome"],
  ) {
    if (secret !== construction) throw new TypeError("Use decodeGrpcReply");
    this.phase =
      value.phase === "closed_unknown"
        ? "closed-unknown"
        : value.phase === "not_dispatched"
          ? "not-dispatched"
          : "observed";
    this.resource = new ResourceRef(realm, value.resource);
    this.exchange = nativeWide(value.exchange);
    this.effect = value.effect;
    this.attempt = value.attempt;
    this.status = value.status ?? undefined;
    this.diagnostic = structuredClone(value.diagnostic);
    this.#reference = value.reference === null ? undefined : unhex(value.reference, 256);
    Object.freeze(this);
  }
  get reference(): Uint8Array | undefined {
    return this.#reference?.slice();
  }
  [inspect.custom](): string {
    return `GrpcOutcome(${this.phase})`;
  }
}
export interface GrpcRejected {
  readonly kind: "grpc-rejected";
  readonly reason: GrpcRejection;
  readonly diagnostic: Diagnostic;
}
export interface GrpcReleased {
  readonly kind: "grpc-released";
  readonly resource: ResourceRef;
  readonly exchange: bigint;
}
export type GrpcReply = GrpcOutcome | GrpcRejected | GrpcReleased;
export async function decodeGrpcWithBridge(
  bridge: Bridge,
  realm: number,
  bytes: Uint8Array,
): Promise<GrpcReply> {
  integer(realm, "realm");
  if (Buffer.from(bytes.subarray(0, 4)).toString("hex") === "47524b31" && !bridge.caps.grpc_release)
    throw new UnsupportedCapability("Native RPC disposal is unavailable");
  const result = await bridge.grpcCodec({ outcome: hex(bytes, 232) });
  if ("rejected" in result)
    return Object.freeze({
      kind: "grpc-rejected",
      reason:
        result.rejected.reason === "invalid_request" ? "invalid-request" : result.rejected.reason,
      diagnostic: structuredClone(result.rejected.diagnostic),
    });
  if ("released" in result)
    return Object.freeze({
      kind: "grpc-released",
      resource: new ResourceRef(realm, result.released.resource),
      exchange: nativeWide(result.released.exchange),
    });
  if (!("outcome" in result)) throw new IncompatibleNative("Expected an RPC outcome");
  return new GrpcOutcome(construction, realm, result.outcome);
}
export async function decodeGrpcReply(
  realm: number,
  bytes: Uint8Array,
  options: { nativeHost?: string } = {},
): Promise<GrpcReply> {
  const copied = owned(bytes, 232);
  const bridge = await Bridge.local(options.nativeHost);
  try {
    return await decodeGrpcWithBridge(bridge, realm, copied);
  } finally {
    await bridge.close();
  }
}
export type GrpcReplayPolicy = "captured" | "require-unredacted";
export type GrpcPartKind = NonNullable<Extract<GrpcReadResult, { part: unknown }>["part"]>["kind"];
export interface GrpcPart {
  readonly kind: GrpcPartKind;
  readonly data: Uint8Array;
  readonly complete: boolean;
}
type Read = (action: GrpcReadAction) => Promise<GrpcReadResult>;
export class GrpcReader implements AsyncDisposable {
  readonly #identity: number;
  readonly #call: Read;
  #complete = false;
  #closed = false;
  constructor(identity: number, call: Read) {
    this.#identity = identity;
    this.#call = call;
  }
  get complete(): boolean {
    return this.#complete;
  }
  async read(): Promise<GrpcPart | undefined> {
    if (this.#closed) throw new Closed("RPC reader is closed");
    const result = await this.#call({ next: this.#identity });
    if (!("part" in result)) throw new IncompatibleNative("Expected an RPC capture part");
    if (result.part === null) {
      if (!this.#complete)
        throw new IncompatibleNative("RPC reader ended without verified completion");
      return undefined;
    }
    this.#complete = result.part.complete;
    return Object.freeze({
      kind: result.part.kind,
      data: unhex(result.part.bytes, 256),
      complete: this.#complete,
    });
  }
  async close(): Promise<void> {
    if (!this.#closed) {
      const result = await this.#call({ close: this.#identity });
      if (!("closed" in result) || !result.closed)
        throw new IncompatibleNative("Expected reader disposal");
      this.#closed = true;
    }
  }
  [Symbol.asyncDispose](): Promise<void> {
    return this.close();
  }
}
