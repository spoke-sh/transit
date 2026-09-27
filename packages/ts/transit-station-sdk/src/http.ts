import { inspect } from "node:util";
import { ResourceRef, Closed, IncompatibleNative, UnsupportedCapability } from "@transit/client";
import { integer, owned, text } from "@transit/client/internal";
import { Bridge } from "./bridge.ts";
import { hex, unhex } from "./framing.ts";
import { nativeWide, wide } from "./values.ts";
import type { HttpCodecAction, HttpCodecResult, HttpReadAction, HttpReadResult } from "./wire.ts";

export type HttpMethod = "GET" | "HEAD" | "POST" | "PUT" | "PATCH" | "DELETE" | "OPTIONS";
export type HttpPiece =
  | { readonly kind: "literal"; readonly value: string }
  | { readonly kind: "variable"; readonly name: string; readonly value: string }
  | { readonly kind: "secret"; readonly binding: string; readonly version: bigint };
export interface HttpHeader {
  readonly name: string;
  readonly value: readonly HttpPiece[];
}
export interface HttpRequest {
  readonly method: HttpMethod;
  readonly target: readonly HttpPiece[];
  readonly headers?: readonly HttpHeader[];
}
type NativeRequest = Extract<HttpCodecAction, { prepare: unknown }>["prepare"]["request"];
function pieces(input: readonly HttpPiece[]): NativeRequest["target"] {
  if (!Array.isArray(input) || input.length > 128)
    throw new TypeError("Expected at most 128 HTTP pieces");
  return input.map((piece: HttpPiece) => {
    switch (piece?.kind) {
      case "literal":
        return { literal: text(piece.value, 8192) };
      case "variable":
        return { variable: { name: text(piece.name, 128), value: text(piece.value, 8192) } };
      case "secret":
        return {
          secret: { binding: text(piece.binding, 128), version: wide(piece.version).toString() },
        };
      default:
        throw new TypeError("Expected an HTTP literal, variable or secret reference");
    }
  });
}
function requestWire(input: HttpRequest): NativeRequest {
  if (!["GET", "HEAD", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"].includes(input?.method))
    throw new TypeError("Unsupported HTTP method");
  const headers = input.headers ?? [];
  if (!Array.isArray(headers) || headers.length > 64)
    throw new TypeError("Expected at most 64 HTTP headers");
  return {
    method: input.method,
    target: pieces(input.target),
    headers: headers.map((header: HttpHeader) => ({
      name: text(header.name, 8192),
      value: pieces(header.value),
    })),
  };
}
const construction = Symbol("http-native-result");
export class PreparedHttpRequest {
  readonly resource: ResourceRef;
  readonly namespace: bigint;
  readonly #reference: Uint8Array;
  readonly #metadata: Uint8Array;
  readonly #body: Uint8Array;
  constructor(
    secret: typeof construction,
    resource: ResourceRef,
    namespace: bigint,
    reference: Uint8Array,
    metadata: Uint8Array,
    body: Uint8Array,
  ) {
    if (secret !== construction) throw new TypeError("Use prepareHttp");
    this.resource = resource;
    this.namespace = namespace;
    this.#reference = owned(reference, 112);
    this.#metadata = owned(metadata, 8192);
    this.#body = owned(body, 65536);
    Object.freeze(this);
  }
  get reference(): Uint8Array {
    return new Uint8Array(this.#reference);
  }
  get metadata(): Uint8Array {
    return new Uint8Array(this.#metadata);
  }
  get body(): Uint8Array {
    return new Uint8Array(this.#body);
  }
  [inspect.custom](): string {
    return "PreparedHttpRequest(owned bytes)";
  }
}
export async function prepareHttp(
  resource: ResourceRef,
  namespace: bigint,
  request: HttpRequest,
  body: Uint8Array,
  options: {
    endpointRevision: bigint;
    reconcileBeforeMs: number;
    maxAttempts?: number;
    nativeHost?: string;
  },
): Promise<PreparedHttpRequest> {
  if (!(resource instanceof ResourceRef)) throw new TypeError("Expected ResourceRef");
  namespace = wide(namespace);
  const bytes = owned(body, 65536);
  // Copy and validate before awaiting host construction, so later input mutation
  // cannot change the request this call prepares.
  const action: HttpCodecAction = {
    prepare: {
      resource: resource.resource,
      namespace: namespace.toString(),
      request: requestWire(request),
      body: hex(bytes, 65536),
      endpoint_revision: wide(options.endpointRevision).toString(),
      reconcile_before_ms: integer(options.reconcileBeforeMs, "reconciliation deadline"),
      max_attempts: integer(options.maxAttempts ?? 1, "attempts", 1, 0xffffffff),
    },
  };
  const bridge = await Bridge.local(options.nativeHost);
  try {
    const result = await bridge.httpCodec(action);
    if (!("prepared" in result)) throw new IncompatibleNative("Expected a prepared HTTP request");
    return new PreparedHttpRequest(
      construction,
      resource,
      namespace,
      unhex(result.prepared.reference, 112),
      unhex(result.prepared.metadata, 8192),
      bytes,
    );
  } finally {
    await bridge.close();
  }
}
export type HttpPhase = "observed" | "closed-unknown" | "not-dispatched";
export type HttpRejection = "denied" | "invalid-request" | "busy";
export class HttpOutcome {
  readonly kind = "http-outcome";
  readonly phase: HttpPhase;
  readonly resource: ResourceRef;
  readonly exchange: bigint;
  readonly effect: number;
  readonly attempt: number;
  readonly status: number | undefined;
  readonly #reference: Uint8Array | undefined;
  constructor(
    secret: typeof construction,
    realm: number,
    value: Extract<HttpCodecResult, { outcome: unknown }>["outcome"],
  ) {
    if (secret !== construction) throw new TypeError("Use decodeHttpReply");
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
    this.#reference = value.reference === null ? undefined : unhex(value.reference, 256);
    Object.freeze(this);
  }
  get reference(): Uint8Array | undefined {
    return this.#reference?.slice();
  }
  [inspect.custom](): string {
    return `HttpOutcome(${this.phase})`;
  }
}
export interface HttpRejected {
  readonly kind: "http-rejected";
  readonly reason: HttpRejection;
}
export interface HttpReleased {
  readonly kind: "http-released";
  readonly resource: ResourceRef;
  readonly exchange: bigint;
}
export type HttpReply = HttpOutcome | HttpRejected | HttpReleased;
export async function decodeHttpWithBridge(
  bridge: Bridge,
  realm: number,
  bytes: Uint8Array,
): Promise<HttpReply> {
  integer(realm, "realm");
  if (Buffer.from(bytes.subarray(0, 4)).toString("hex") === "48544b31" && !bridge.caps.http_release)
    throw new UnsupportedCapability("Native HTTP disposal is unavailable");
  const result = await bridge.httpCodec({ outcome: hex(bytes, 71) });
  if ("rejected" in result)
    return Object.freeze({
      kind: "http-rejected",
      reason: result.rejected === "invalid_request" ? "invalid-request" : result.rejected,
    });
  if ("released" in result)
    return Object.freeze({
      kind: "http-released",
      resource: new ResourceRef(realm, result.released.resource),
      exchange: nativeWide(result.released.exchange),
    });
  if (!("outcome" in result)) throw new IncompatibleNative("Expected an HTTP outcome");
  return new HttpOutcome(construction, realm, result.outcome);
}
export async function decodeHttpReply(
  realm: number,
  bytes: Uint8Array,
  options: { nativeHost?: string } = {},
): Promise<HttpReply> {
  const copied = owned(bytes, 71);
  const bridge = await Bridge.local(options.nativeHost);
  try {
    return await decodeHttpWithBridge(bridge, realm, copied);
  } finally {
    await bridge.close();
  }
}
export type HttpReplayPolicy = "captured" | "require-unredacted";
export type HttpPartKind = NonNullable<Extract<HttpReadResult, { part: unknown }>["part"]>["kind"];
export interface HttpPart {
  readonly kind: HttpPartKind;
  readonly data: Uint8Array;
  readonly complete: boolean;
}
type Read = (action: HttpReadAction) => Promise<HttpReadResult>;
export class HttpReader implements AsyncDisposable {
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
  async read(): Promise<HttpPart | undefined> {
    if (this.#closed) throw new Closed("HTTP reader is closed");
    const result = await this.#call({ next: this.#identity });
    if (!("part" in result)) throw new IncompatibleNative("Expected an HTTP capture part");
    if (result.part === null) {
      if (!this.#complete)
        throw new IncompatibleNative("HTTP reader ended without verified completion");
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
