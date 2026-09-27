import {
  ProcessRef,
  ResourceRef,
  HandlerError,
  MissingValue,
  IncompatibleNative,
  UnsupportedCapability,
  limits,
} from "@transit/client";
import { integer, text } from "@transit/client/internal";
import { result, type Bridge } from "./bridge.ts";
import { context, operation, register, Scope } from "./context.ts";
import {
  encode,
  decode,
  Key,
  ReadVersion,
  nativeWide,
  wide,
  type Codec,
  type Found,
  type KVEntry,
  type Page,
  type Reply,
  type WaitPolicy,
  type Budgets,
} from "./values.ts";
import { hex, unhex } from "./framing.ts";
import { Table, TableSchema, type Cell } from "./table.ts";
import { QueryPlan, ResultReader, type QueryJob } from "./query.ts";
import type { GrowingAction, GrowingEvent } from "./wire.ts";
import { PreparedHttpRequest } from "./http.ts";

function cursor(value?: string): string | null {
  return value === undefined ? null : text(value, limits.max_body);
}
function keyBytes<T>(key: Key<T>, bound: number): string {
  if (!(key instanceof Key)) throw new TypeError("Expected a typed Key");
  return hex(key.name, bound);
}
export class State {
  readonly #turn: Turn;
  readonly #version: ReadVersion | undefined;
  constructor(turn: Turn, version?: ReadVersion) {
    this.#turn = turn;
    this.#version = version;
  }
  find<T>(key: Key<T>): Promise<Found<T> | undefined> {
    return operation(this.#turn, async ({ bridge, token }) => {
      const name = keyBytes(key, bridge.caps.key_bytes);
      const action: GrowingAction = this.#version
        ? { version_get: { id: this.#version, key: name } }
        : { get: name };
      const value = result(await bridge.apply(token, action), "value");
      return value === null
        ? undefined
        : Object.freeze({
            value: decode(
              key.codec,
              unhex(value, bridge.caps.value_bytes),
              bridge.caps.value_bytes,
            ),
          });
    });
  }
  require<T>(key: Key<T>): Promise<T> {
    return operation(this.#turn, async ({ bridge, token }) => {
      const name = keyBytes(key, bridge.caps.key_bytes);
      const action: GrowingAction = this.#version
        ? { version_get: { id: this.#version, key: name } }
        : { get: name };
      const value = result(await bridge.apply(token, action), "value");
      if (value === null) throw new MissingValue("Required associated-state value is absent");
      return decode(key.codec, unhex(value, bridge.caps.value_bytes), bridge.caps.value_bytes);
    });
  }
  put<T>(key: Key<T>, value: T): Promise<void> {
    return operation(this.#turn, async ({ bridge, token }) => {
      if (this.#version) throw new HandlerError("Retained state is read-only");
      const name = keyBytes(key, bridge.caps.key_bytes);
      const bytes = encode(key.codec, value, bridge.caps.value_bytes);
      await bridge.apply(token, { put: { key: name, value: hex(bytes, bridge.caps.value_bytes) } });
    });
  }
  delete<T>(key: Key<T>): Promise<void> {
    return operation(this.#turn, async ({ bridge, token }) => {
      if (this.#version) throw new HandlerError("Retained state is read-only");
      await bridge.apply(token, { delete: keyBytes(key, bridge.caps.key_bytes) });
    });
  }
  page(after?: string): Promise<Page<KVEntry>> {
    return operation(this.#turn, async ({ bridge, token }) => {
      const position = cursor(after);
      const action: GrowingAction = this.#version
        ? { version_page: { id: this.#version, cursor: position } }
        : { page: position };
      const page = result(await bridge.apply(token, action), "page");
      const entries = page.entries
        .filter((value) => value !== null)
        .map((entry) =>
          Object.freeze({
            key: unhex(entry.key, bridge.caps.key_bytes),
            value: unhex(entry.value, bridge.caps.value_bytes),
            revision: integer(entry.revision, "entry revision"),
          }),
        );
      return Object.freeze({ entries: Object.freeze(entries), next: page.next ?? undefined });
    });
  }
}
export class Source {
  readonly identity: ReadVersion;
  readonly state: State;
  readonly #turn: Turn;
  constructor(turn: Turn, identity: ReadVersion) {
    if (!(identity instanceof ReadVersion)) throw new TypeError("Expected ReadVersion");
    this.#turn = turn;
    this.identity = identity;
    this.state = new State(turn, identity);
    Object.freeze(this);
  }
  table<C extends Cell>(schema: TableSchema<C>): Promise<Table<C>> {
    return Table.open(this.#turn, schema, this.identity);
  }
}
const construction = Symbol("native-turn");
export class Turn {
  readonly process: ProcessRef;
  readonly resource: ResourceRef;
  readonly resourceRevision: number;
  readonly state: State;
  constructor(
    secret: typeof construction,
    bridge: Bridge,
    event: GrowingEvent,
    process: ProcessRef,
    stopped: () => boolean,
  ) {
    if (
      secret !== construction ||
      event.event !== "ready" ||
      event.scope === null ||
      event.resource === null ||
      event.resource_revision === null
    ) {
      throw new IncompatibleNative("A turn requires a native ready scope");
    }
    register(this, {
      bridge,
      event,
      token: integer(event.scope, "scope"),
      scope: new Scope(stopped),
    });
    this.process = process;
    this.resource = new ResourceRef(process.realm, integer(event.resource, "resource"));
    this.resourceRevision = integer(event.resource_revision, "resource revision");
    this.state = new State(this);
    Object.freeze(this);
  }
  budgets(): Promise<Budgets> {
    return operation(this, async ({ bridge, token }) => {
      const value = result(await bridge.apply(token, { budgets: {} }), "budgets");
      return Object.freeze({
        mutations: value.mutations,
        outputs: value.outputs,
        views: value.views,
        retainedReads: value.retained_reads,
        retains: value.retains,
        releases: value.releases,
      });
    });
  }
  #peer(peer: ProcessRef): number {
    if (!(peer instanceof ProcessRef) || peer.realm !== this.process.realm)
      throw new TypeError("Destination must be a ProcessRef in this realm");
    return peer.pid;
  }
  #http(request: PreparedHttpRequest, bridge: Bridge): void {
    if (
      !(request instanceof PreparedHttpRequest) ||
      request.resource.realm !== this.resource.realm ||
      request.resource.resource !== this.resource.resource
    )
      throw new TypeError("HTTP publication must use the current associated resource");
    if (!bridge.caps.http_requests)
      throw new UnsupportedCapability("Native HTTP requests are unavailable");
  }
  stageHttp(request: PreparedHttpRequest): Promise<boolean> {
    return operation(this, async ({ bridge, token }) => {
      this.#http(request, bridge);
      return result(
        await bridge.apply(token, {
          http_stage: {
            reference: hex(request.reference, 112),
            metadata: hex(request.metadata, 8192),
            body: hex(request.body, 65536),
          },
        }),
        "staged",
      );
    });
  }
  callHttp(peer: ProcessRef, request: PreparedHttpRequest): Promise<bigint> {
    return operation(this, async ({ bridge, token }) => {
      const pid = this.#peer(peer);
      this.#http(request, bridge);
      return nativeWide(
        result(
          await bridge.apply(token, {
            http_call: {
              pid,
              reference: hex(request.reference, 112),
            },
          }),
          "correlation",
        ),
      );
    });
  }
  releaseHttp(peer: ProcessRef, resource: ResourceRef, exchange: bigint): Promise<bigint> {
    return operation(this, async ({ bridge, token }) => {
      const pid = this.#peer(peer);
      if (!(resource instanceof ResourceRef) || resource.realm !== this.resource.realm)
        throw new TypeError("HTTP capture must belong to the current realm");
      if (!bridge.caps.http_release)
        throw new UnsupportedCapability("Native HTTP disposal is unavailable");
      return nativeWide(
        result(
          await bridge.apply(token, {
            http_release: { pid, resource: resource.resource, exchange: wide(exchange).toString() },
          }),
          "correlation",
        ),
      );
    });
  }
  cast<T>(peer: ProcessRef, value: T, codec: Codec<T>): Promise<void> {
    return operation(this, async ({ bridge, token }) => {
      const pid = this.#peer(peer),
        bytes = encode(codec, value, bridge.caps.message_bytes);
      await bridge.apply(token, { cast: { pid, value: hex(bytes, bridge.caps.message_bytes) } });
    });
  }
  call<T>(
    peer: ProcessRef,
    value: T,
    options: { codec: Codec<T>; wait: WaitPolicy },
  ): Promise<bigint> {
    return operation(this, async ({ bridge, token }) => {
      const pid = this.#peer(peer),
        bytes = encode(options.codec, value, bridge.caps.message_bytes);
      let deadline: number | null = null,
        observer: number | null = null;
      if (options.wait?.kind === "until") {
        deadline = integer(options.wait.deadlineMs, "deadline");
        observer = integer(options.wait.observer, "observer");
      } else if (options.wait?.kind !== "untimed")
        throw new TypeError("Select an explicit wait policy");
      const correlation = result(
        await bridge.apply(token, {
          call: {
            pid,
            value: hex(bytes, bridge.caps.message_bytes),
            deadline_ms: deadline,
            observer,
          },
        }),
        "correlation",
      );
      return nativeWide(correlation);
    });
  }
  reply<T>(value: T, codec: Codec<T>): Promise<void> {
    return operation(this, async ({ bridge, token }) => {
      const bytes = encode(codec, value, bridge.caps.message_bytes);
      await bridge.apply(token, { reply: hex(bytes, bridge.caps.message_bytes) });
    });
  }
  requireReply<T>(reply: Reply<T>, expected: { peer: ProcessRef; correlation: bigint }): void {
    const current = context(this);
    current.scope.check();
    const pid = this.#peer(expected.peer),
      correlation = wide(expected.correlation);
    const input = current.event.input;
    if (
      !input ||
      input.kind !== "reply" ||
      !("process" in input.origin) ||
      input.origin.process.pid !== pid ||
      nativeWide(input.correlation) !== correlation ||
      reply?.kind !== "reply" ||
      reply.position !== input.position ||
      reply.correlation !== correlation
    ) {
      throw new HandlerError(
        "Reply does not match the authenticated input, peer and saved correlation",
      );
    }
  }
  cancelCall(correlation: bigint): Promise<boolean> {
    return operation(this, async ({ bridge, token }) =>
      result(await bridge.apply(token, { cancel: wide(correlation).toString() }), "cancelled"),
    );
  }
  table<C extends Cell>(schema: TableSchema<C>): Promise<Table<C>> {
    return Table.open(this, schema);
  }
  createTable<C extends Cell>(schema: TableSchema<C>): Promise<Table<C>> {
    return Table.create(this, schema);
  }
  retain(): Promise<ReadVersion> {
    return operation(this, async ({ bridge, token }) => {
      const value = result(await bridge.apply(token, { retain: {} }), "version");
      return new ReadVersion(value.pid, value.input, value.index);
    });
  }
  openVersion(identity: ReadVersion): Source {
    context(this).scope.check();
    return new Source(this, identity);
  }
  release(identity: ReadVersion): Promise<void> {
    return operation(this, async ({ bridge, token }) => {
      if (!(identity instanceof ReadVersion)) throw new TypeError("Expected ReadVersion");
      await bridge.apply(token, { release: identity });
    });
  }
  allowQuery<C extends Cell>(
    peer: ProcessRef,
    table: TableSchema<C>,
    options: { expectedRevision: number; allow: boolean },
  ): Promise<void> {
    return operation(this, async ({ bridge, token }) => {
      const pid = this.#peer(peer);
      if (!(table instanceof TableSchema) || typeof options.allow !== "boolean")
        throw new TypeError("Expected a Table schema and boolean policy");
      await bridge.apply(token, {
        query_policy: {
          peer: pid,
          table: table.id,
          expected_revision: integer(options.expectedRevision, "policy revision", 0),
          allow: options.allow,
        },
      });
    });
  }
  startQuery<C extends Cell>(schema: TableSchema<C>, plan: QueryPlan): Promise<QueryJob> {
    return operation(this, async (current) => {
      if (!(plan instanceof QueryPlan)) throw new TypeError("Expected QueryPlan");
      await Table.capture(current, this, schema);
      const value = result(
        await current.bridge.apply(current.token, {
          query_start: { id: schema.id, plan: plan.wire(current.bridge.caps.table_cell_bytes) },
        }),
        "query",
      );
      return Object.freeze({
        result: integer(value.result, "result"),
        correlation: nativeWide(value.correlation),
        source: new ReadVersion(value.source.pid, value.source.input, value.source.index),
      });
    });
  }
  closeQuery(resultId: number, reason: "cancelled" | "denied" = "cancelled"): Promise<void> {
    return operation(this, async ({ bridge, token }) => {
      if (reason !== "cancelled" && reason !== "denied")
        throw new TypeError("Select a query closure reason");
      await bridge.apply(token, { query_close: { result: integer(resultId, "result"), reason } });
    });
  }
  result(correlation: bigint): ResultReader {
    context(this).scope.check();
    return new ResultReader(this, wide(correlation));
  }
}
export function createTurn(
  bridge: Bridge,
  event: GrowingEvent,
  process: ProcessRef,
  stopped: () => boolean,
): Turn {
  return new Turn(construction, bridge, event, process, stopped);
}
export { cursor };
