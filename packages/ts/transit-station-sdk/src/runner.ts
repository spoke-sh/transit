import { AsyncLocalStorage } from "node:async_hooks";
import { setTimeout as delay } from "node:timers/promises";
import {
  Busy,
  Closed,
  HandlerError,
  IncompatibleNative,
  MutationReceipt,
  ProcessRef,
  TransitError,
  UnknownOutcome,
} from "@transit/client";
import { Serial } from "@transit/client/internal";
import { Bridge } from "./bridge.ts";
import { context } from "./context.ts";
import { unhex } from "./framing.ts";
import { createTurn, type Turn } from "./turn.ts";
import { ResultReader } from "./query.ts";
import {
  decodeHttpWithBridge,
  HttpOutcome,
  HttpReader,
  type HttpReply,
  type HttpReplayPolicy,
} from "./http.ts";
import {
  decodeGrpcWithBridge,
  GrpcOutcome,
  GrpcReader,
  type GrpcReply,
  type GrpcReplayPolicy,
} from "./grpc.ts";
import {
  decode,
  nativeWide,
  serviceConfiguration,
  type Codec,
  type Control,
  type FailurePolicy,
  type FrozenMutation,
  type Incoming,
  type Origin,
  type Recovery,
  type Reply,
  type RunnerEvent,
  type ServiceConfig,
} from "./values.ts";
import type {
  GrowingEvent,
  HttpReadAction,
  HttpReadResult,
  GrpcReadAction,
  GrpcReadResult,
} from "./wire.ts";

export interface Handler<M> {
  initialize(turn: Turn): Promise<void>;
  handle(turn: Turn, incoming: Incoming<M>): Promise<void>;
  handleControl?(turn: Turn, input: Control): Promise<void>;
  handleResult?(turn: Turn, result: ResultReader): Promise<void>;
  handleGrpcReply?(turn: Turn, input: Reply<GrpcReply>): Promise<void>;
  handleHttpReply?(turn: Turn, input: Reply<HttpReply>): Promise<void>;
}
export interface RunnerOptions {
  readonly failure: FailurePolicy;
  readonly recovery: Recovery;
}
const callbacks = new AsyncLocalStorage<object>();
type Paused = Extract<RunnerEvent, { kind: "needs-recovery" }>;

function origin(realm: number, value: NonNullable<GrowingEvent["input"]>["origin"]): Origin {
  if ("external" in value)
    return Object.freeze({
      kind: "external",
      principal: value.external.principal,
      policyRevision: value.external.policy_revision,
    });
  if ("process" in value)
    return Object.freeze({
      kind: "process",
      process: new ProcessRef(realm, value.process.pid),
      turn: value.process.turn,
      output: value.process.output,
    });
  return Object.freeze({
    kind: "effect",
    effect: value.effect.id,
    attempt: value.effect.attempt,
    executor: value.effect.executor,
  });
}

/** One consumer, one native port, and one private handler at a time. */
export class Runner<M> implements AsyncDisposable {
  readonly #config: ServiceConfig;
  readonly #handler: Handler<M>;
  readonly #codec: Codec<M>;
  readonly #options: RunnerOptions;
  readonly #bridge: Bridge;
  readonly #serial = new Serial();
  #consumer: object | undefined;
  #stopped = false;
  #closing = false;
  #pending: FrozenMutation | undefined;
  #confirmed: GrowingEvent | undefined;
  #paused: Paused | undefined;
  #attempted = false;
  #lastEvent: RunnerEvent | undefined;
  private constructor(
    config: ServiceConfig,
    handler: Handler<M>,
    codec: Codec<M>,
    options: RunnerOptions,
    bridge: Bridge,
  ) {
    this.#config = config;
    this.#handler = handler;
    this.#codec = codec;
    this.#options = options;
    this.#bridge = bridge;
  }
  static async open<M>(
    config: ServiceConfig,
    handler: Handler<M>,
    codec: Codec<M>,
    options: RunnerOptions,
  ): Promise<Runner<M>> {
    const validated = serviceConfiguration(config);
    if (typeof handler?.initialize !== "function" || typeof handler.handle !== "function")
      throw new TypeError("Handler must implement initialize and handle");
    if (options?.failure !== "stop" && options?.failure !== "block-input")
      throw new TypeError("Select an explicit failure policy");
    const selected = options.recovery;
    let recovery: Recovery;
    if (selected?.kind === "fence-on-restart") recovery = Object.freeze({ kind: selected.kind });
    else if (
      selected?.kind === "persist-before-dispatch" &&
      typeof selected.store?.beforeDispatch === "function" &&
      typeof selected.store.confirmed === "function"
    ) {
      // Capture the contract once; application changes cannot disable a later gate.
      recovery = Object.freeze({
        kind: selected.kind,
        store: Object.freeze({
          beforeDispatch: selected.store.beforeDispatch.bind(selected.store),
          confirmed: selected.store.confirmed.bind(selected.store),
        }),
      });
    } else throw new TypeError("Select an explicit recovery policy and valid persistence hooks");
    const copied = Object.freeze({ failure: options.failure, recovery });
    const bridge = await Bridge.open(validated, copied.failure);
    return new Runner(validated, handler, codec, copied, bridge);
  }
  get pending(): FrozenMutation | undefined {
    return this.#pending;
  }
  get lastEvent(): RunnerEvent | undefined {
    return this.#lastEvent;
  }
  stop(): void {
    this.#stopped = true;
  }
  #notReentrant(): void {
    if (callbacks.getStore() === this)
      throw new Busy("Runner callbacks cannot reenter or close their owner");
  }
  #admit(token?: object): void {
    this.#notReentrant();
    if (this.#closing) throw new Closed("Runner is closing");
    if (this.#consumer !== token) throw new Busy("Runner already has a consumer");
  }
  async #invoke(callback: () => Promise<void>): Promise<void> {
    const returned: unknown = await callbacks.run(this, callback);
    if (returned !== undefined)
      throw new HandlerError("Handlers and persistence hooks must return void");
  }
  #record(event: RunnerEvent): RunnerEvent {
    this.#lastEvent = Object.freeze(event);
    return this.#lastEvent;
  }
  #pause(error: unknown, phase: string, receipt?: MutationReceipt): Paused {
    if (!this.#pending) throw new IncompatibleNative("Missing saved mutation");
    this.#paused = Object.freeze({
      kind: "needs-recovery",
      mutation: this.#pending,
      phase,
      error,
      receipt,
    });
    this.#lastEvent = this.#paused;
    return this.#paused;
  }
  async #accept(event: GrowingEvent): Promise<RunnerEvent> {
    const pending = this.#pending;
    if (!pending) throw new IncompatibleNative("Missing saved mutation");
    this.#confirmed = event;
    const native = event.confirmation;
    if (!native || native.kind !== pending.purpose || native.input !== pending.inputPosition) {
      return this.#pause(
        new IncompatibleNative("Confirmation does not match the saved mutation"),
        "confirm",
      );
    }
    const receipt = new MutationReceipt(native.receipt.position);
    if (this.#options.recovery.kind === "persist-before-dispatch") {
      const store = this.#options.recovery.store;
      try {
        await this.#invoke(() => store.confirmed(pending.identity, receipt));
      } catch (error) {
        return this.#pause(error, "confirm", receipt);
      }
    }
    const outcome: RunnerEvent =
      event.event === "blocked"
        ? { kind: "blocked", inputPosition: native.input, receipt }
        : pending.purpose === "commit"
          ? { kind: "committed", inputPosition: native.input, receipt }
          : { kind: "progress" };
    this.#pending = this.#confirmed = this.#paused = undefined;
    this.#attempted = false;
    return this.#record(outcome);
  }
  async #attempt(): Promise<RunnerEvent> {
    const pending = this.#pending;
    if (!pending) throw new Closed("There is no saved mutation to reconcile");
    if (this.#confirmed) return this.#accept(this.#confirmed);
    if (this.#attempted) {
      let known: GrowingEvent | undefined;
      try {
        known = await this.#bridge.confirmation(pending);
      } catch (error) {
        return this.#pause(error, "observe-confirmation");
      }
      if (known) return this.#accept(known);
    }
    if (this.#stopped) return this.#record({ kind: "stopped" });
    if (this.#options.recovery.kind === "persist-before-dispatch") {
      const store = this.#options.recovery.store;
      try {
        await this.#invoke(() => store.beforeDispatch(pending));
      } catch (error) {
        return this.#pause(error, "persist");
      }
    }
    if (this.#stopped) return this.#record({ kind: "stopped" });
    this.#attempted = true;
    let event: GrowingEvent;
    try {
      event = await this.#bridge.dispatch();
    } catch (error) {
      return this.#pause(
        error instanceof TransitError
          ? error
          : new UnknownOutcome("Native dispatch outcome is unknown", { phase: "dispatch" }),
        "dispatch",
      );
    }
    return this.#accept(event);
  }
  async #handle(event: GrowingEvent): Promise<RunnerEvent> {
    const turn = createTurn(
      this.#bridge,
      event,
      this.#config.activation.process,
      () => this.#stopped,
    );
    const current = context(turn);
    let failed = false,
      failure: unknown;
    if (!this.#stopped) {
      try {
        const input = event.input;
        if (!input) throw new IncompatibleNative("Ready scope lacks an input");
        const provenance = origin(turn.process.realm, input.origin),
          correlation = nativeWide(input.correlation);
        let dispatch: () => Promise<void>;
        const payload = unhex(input.payload, this.#bridge.caps.message_bytes);
        const httpMagic = Buffer.from(payload.subarray(0, 4)).toString("hex");
        if (
          input.kind === "reply" &&
          typeof this.#handler.handleHttpReply === "function" &&
          (httpMagic === "48545231" || httpMagic === "48544631" || httpMagic === "48544b31")
        ) {
          const value = await decodeHttpWithBridge(this.#bridge, turn.process.realm, payload);
          const reply: Reply<HttpReply> = Object.freeze({
            kind: "reply",
            value,
            position: input.position,
            origin: provenance,
            correlation,
          });
          dispatch = () => this.#handler.handleHttpReply!(turn, reply);
        } else if (
          input.kind === "reply" &&
          typeof this.#handler.handleGrpcReply === "function" &&
          (httpMagic === "47525231" || httpMagic === "47524631" || httpMagic === "47524b31")
        ) {
          const value = await decodeGrpcWithBridge(this.#bridge, turn.process.realm, payload);
          const reply: Reply<GrpcReply> = Object.freeze({
            kind: "reply",
            value,
            position: input.position,
            origin: provenance,
            correlation,
          });
          dispatch = () => this.#handler.handleGrpcReply!(turn, reply);
        } else if (input.kind === "cast" || input.kind === "call" || input.kind === "reply") {
          // Decode before initialization can stage application changes.
          const value = decode(this.#codec, payload, this.#bridge.caps.message_bytes);
          const incoming: Incoming<M> = Object.freeze({
            kind: input.kind,
            value,
            position: input.position,
            origin: provenance,
            correlation,
          });
          dispatch = () => this.#handler.handle(turn, incoming);
        } else if (input.kind === "result_complete") {
          if (typeof this.#handler.handleResult !== "function")
            throw new HandlerError("A verified query result requires handleResult");
          dispatch = () => this.#handler.handleResult!(turn, new ResultReader(turn, correlation));
        } else if (input.kind === "cancel" || input.kind === "timeout") {
          if (typeof this.#handler.handleControl !== "function")
            throw new HandlerError("A framework control input requires handleControl");
          const control: Control = Object.freeze({
            kind: input.kind,
            position: input.position,
            origin: provenance,
            correlation,
          });
          dispatch = () => this.#handler.handleControl!(turn, control);
        } else throw new HandlerError("Unsupported native application input");
        await current.scope.invoke(async () => {
          if (event.initializing) await this.#invoke(() => this.#handler.initialize(turn));
          if (!this.#stopped) await this.#invoke(dispatch);
        });
      } catch (error) {
        failed = true;
        failure = error;
      }
    }
    const outstanding = await current.scope.seal();
    if (outstanding && !failed) {
      failed = true;
      failure = outstanding;
    }
    if (this.#stopped) {
      await this.#bridge.discard(current.token);
      return this.#record({ kind: "stopped" });
    }
    try {
      await this.#bridge.finish(current.token, failed);
    } catch (error) {
      if (
        failed &&
        this.#options.failure === "stop" &&
        error instanceof TransitError &&
        error.code === "ForeignHandlerFailure"
      )
        throw failure;
      throw error;
    }
    return { kind: "progress" };
  }
  async #next(): Promise<RunnerEvent> {
    if (this.#paused) return this.#paused;
    if (this.#stopped) return this.#record({ kind: "stopped" });
    if (this.#pending) return this.#attempt();
    for (let step = 0; step < 16; step++) {
      if (this.#stopped) return this.#record({ kind: "stopped" });
      const event = await this.#bridge.prepare();
      if (event.event === "pending") {
        this.#pending = await this.#bridge.pending(event);
        return this.#attempt();
      }
      if (event.event === "idle") return this.#record({ kind: "idle" });
      if (event.event === "blocked") return this.#record({ kind: "blocked" });
      if (event.event === "ready") {
        const outcome = await this.#handle(event);
        if (outcome.kind === "stopped") return outcome;
      } else if (event.event !== "progress")
        throw new IncompatibleNative("Unexpected native preparation event");
    }
    return this.#record({ kind: "progress" });
  }
  next(): Promise<RunnerEvent> {
    this.#admit();
    return this.#serial.run(() => this.#next());
  }
  reconcile(): Promise<RunnerEvent> {
    this.#admit();
    return this.#serial.run(() => this.#attempt());
  }
  #httpRead(action: HttpReadAction): Promise<HttpReadResult> {
    this.#admit();
    return this.#serial.run(async () => {
      if (this.#pending) throw new Busy("Resolve the saved mutation before reading HTTP capture");
      return await this.#bridge.httpRead(action);
    });
  }
  async openHttp(outcome: HttpOutcome, policy: HttpReplayPolicy = "captured"): Promise<HttpReader> {
    if (
      !(outcome instanceof HttpOutcome) ||
      outcome.phase !== "observed" ||
      outcome.resource.realm !== this.#config.activation.process.realm
    )
      throw new TypeError("Expected a completed HTTP outcome in this realm");
    const reference = outcome.reference;
    if (!reference) throw new TypeError("HTTP outcome has no complete reference");
    if (policy !== "captured" && policy !== "require-unredacted")
      throw new TypeError("Select an HTTP replay policy");
    const result = await this.#httpRead({
      open: {
        reference: Buffer.from(reference).toString("hex"),
        policy: policy === "captured" ? policy : "require_unredacted",
      },
    });
    if (!("opened" in result)) throw new IncompatibleNative("Expected an HTTP reader");
    return new HttpReader(result.opened, (action) => this.#httpRead(action));
  }
  #grpcRead(action: GrpcReadAction): Promise<GrpcReadResult> {
    this.#admit();
    return this.#serial.run(async () => {
      if (this.#pending) throw new Busy("Resolve the saved mutation before reading RPC capture");
      return await this.#bridge.grpcRead(action);
    });
  }
  async openGrpc(outcome: GrpcOutcome, policy: GrpcReplayPolicy = "captured"): Promise<GrpcReader> {
    if (
      !(outcome instanceof GrpcOutcome) ||
      outcome.phase !== "observed" ||
      outcome.resource.realm !== this.#config.activation.process.realm
    )
      throw new TypeError("Expected a completed RPC outcome in this realm");
    const reference = outcome.reference;
    if (!reference) throw new TypeError("RPC outcome has no complete reference");
    if (policy !== "captured" && policy !== "require-unredacted")
      throw new TypeError("Select an RPC replay policy");
    const result = await this.#grpcRead({
      open: {
        reference: Buffer.from(reference).toString("hex"),
        policy: policy === "captured" ? policy : "require_unredacted",
      },
    });
    if (!("opened" in result)) throw new IncompatibleNative("Expected an RPC reader");
    return new GrpcReader(result.opened, (action) => this.#grpcRead(action));
  }
  async *run(options: { signal?: AbortSignal } = {}): AsyncGenerator<RunnerEvent, void> {
    this.#admit();
    const token = {},
      stopped = () => this.stop();
    this.#consumer = token;
    const signal = options.signal;
    signal?.addEventListener("abort", stopped, { once: true });
    if (signal?.aborted) this.stop();
    try {
      while (!this.#closing) {
        const event = await this.#serial.run(() => this.#next());
        if (
          event.kind === "needs-recovery" ||
          event.kind === "blocked" ||
          event.kind === "stopped"
        ) {
          this.#consumer = undefined;
          yield event;
          return;
        }
        if (event.kind === "committed") yield event;
        else if (event.kind === "idle") await delay(20);
      }
    } finally {
      signal?.removeEventListener("abort", stopped);
      if (this.#consumer === token) this.#consumer = undefined;
    }
  }
  close(): Promise<void> {
    this.#notReentrant();
    this.#closing = true;
    this.stop();
    return this.#serial.close(() => this.#bridge.close());
  }
  [Symbol.asyncDispose](): Promise<void> {
    return this.close();
  }
}
