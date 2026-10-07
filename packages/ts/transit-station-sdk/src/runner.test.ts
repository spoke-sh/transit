import assert from "node:assert/strict";
import test from "node:test";
import {
  Busy,
  HandlerError,
  MutationReceipt,
  OperationIdentity,
  ProcessRef,
  ReadFailed,
  TransitError,
  TurnExpired,
  UnknownOutcome,
} from "@transit/client";
import { Bridge } from "./bridge.ts";
import { Runner, type Handler } from "./runner.ts";
import {
  Activation,
  FrozenMutation,
  Key,
  type Codec,
  type RecoveryStore,
  type RunnerEvent,
} from "./values.ts";
import type { GrowingAction, GrowingEvent, GrowingResult } from "./wire.ts";
import type { Turn } from "./turn.ts";

const codec: Codec<number> = {
  typeId: "test",
  version: 1,
  maxEncodedBytes: 1,
  encode: (value) => new Uint8Array([value]),
  decode: (bytes) => bytes[0]!,
};
const key = new Key(new Uint8Array([97]), codec);
const config = {
  url: "http://127.0.0.1:1",
  profile: "native_v1" as const,
  activation: new Activation(new ProcessRef(1, 1), 1, 1, "/unused"),
};
const empty = (): GrowingEvent => ({
  event: "progress",
  pid: 1,
  generation: 1,
  scope: null,
  initializing: false,
  input: null,
  resource: null,
  resource_revision: null,
  pending_kind: null,
  pending_input: null,
  confirmation: null,
});

class Native {
  readonly caps = { message_bytes: 243, value_bytes: 256, key_bytes: 32 };
  phase = 0;
  input: GrowingEvent["input"] = null;
  dispatches = 0;
  finishes = 0;
  failed = false;
  discards = 0;
  closed = false;
  lost = false;
  block = false;
  poison = false;
  confirmed: GrowingEvent | undefined;
  applyGate: Promise<void> = Promise.resolve();
  async prepare(): Promise<GrowingEvent> {
    if (this.phase === 2)
      return {
        ...empty(),
        event: "ready",
        scope: 1,
        initializing: true,
        resource: 1,
        resource_revision: 1,
        input: this.input ?? {
          query_failure: null,
          position: 1,
          kind: "cast",
          correlation: "0",
          payload: "01",
          origin: { external: { principal: 1, policy_revision: 1 } },
        },
      };
    if (this.phase > 3) return { ...empty(), event: "idle" };
    return {
      ...empty(),
      event: "pending",
      pending_kind: this.phase === 0 ? "permit" : this.phase === 1 ? "open" : "commit",
      pending_input: 1,
    };
  }
  async pending(event: GrowingEvent): Promise<FrozenMutation> {
    return new FrozenMutation(
      new OperationIdentity(String(this.phase + 1).repeat(64)),
      event.pending_kind!,
      1,
      new Uint8Array([this.phase]),
    );
  }
  async dispatch(): Promise<GrowingEvent> {
    this.dispatches++;
    const event = await this.prepare();
    this.phase++;
    this.confirmed = {
      ...empty(),
      event: this.block ? "blocked" : event.pending_kind === "commit" ? "committed" : "progress",
      confirmation: { kind: event.pending_kind!, input: 1, receipt: { position: this.dispatches } },
    };
    if (this.lost) {
      this.lost = false;
      throw new UnknownOutcome("Accepted before host allocation failed");
    }
    return this.confirmed;
  }
  async confirmation(pending: FrozenMutation): Promise<GrowingEvent | undefined> {
    return this.confirmed?.confirmation?.kind === pending.purpose ? this.confirmed : undefined;
  }
  async apply(_scope: number, action: GrowingAction): Promise<GrowingResult> {
    await this.applyGate;
    if (this.poison && "get" in action) throw new ReadFailed("Poisoned read");
    return "get" in action ? { value: "01" } : { ok: {} };
  }
  async finish(_scope: number, failed: boolean): Promise<void> {
    this.finishes++;
    this.failed = failed;
    if (this.poison) throw new ReadFailed("Sticky native read failure");
    if (failed && !this.block) {
      this.phase = 5;
      throw new TransitError("Handler failed", { code: "ForeignHandlerFailure" });
    }
    this.phase = 3;
  }
  async discard(): Promise<void> {
    this.discards++;
    this.phase = 5;
  }
  async close(): Promise<void> {
    this.closed = true;
  }
}
async function fixture(work: (native: Native) => Promise<void>): Promise<void> {
  const native = new Native(),
    original = Bridge.open;
  Bridge.open = async () => native as unknown as Bridge;
  try {
    await work(native);
  } finally {
    Bridge.open = original;
  }
}
const handler: Handler<number> = { async initialize() {}, async handle() {} };
const fencing = { failure: "stop" as const, recovery: { kind: "fence-on-restart" as const } };
async function ready(runner: Runner<number>): Promise<void> {
  assert.equal((await runner.next()).kind, "progress");
  assert.equal((await runner.next()).kind, "progress");
}

test("all mutation gates retain accepted confirmations and never rerun handlers", () =>
  fixture(async (native) => {
    const saved = new Set<string>(),
      confirmed = new Set<string>();
    let calls = 0,
      runner!: Runner<number>;
    const store: RecoveryStore = {
      async beforeDispatch(mutation) {
        assert.throws(() => runner.next(), Busy);
        assert.throws(() => runner.close(), Busy);
        if (!saved.has(mutation.purpose)) {
          saved.add(mutation.purpose);
          throw new Error("store unavailable");
        }
        native.lost = true;
      },
      async confirmed(identity, receipt) {
        assert.ok(receipt instanceof MutationReceipt);
        if (!confirmed.has(identity.sha256)) {
          confirmed.add(identity.sha256);
          throw new Error("confirmation store unavailable");
        }
      },
    };
    runner = await Runner.open(
      config,
      {
        ...handler,
        async handle() {
          calls++;
        },
      },
      codec,
      { failure: "stop", recovery: { kind: "persist-before-dispatch", store } },
    );
    try {
      for (const purpose of ["permit", "open", "commit"]) {
        let event: RunnerEvent = await runner.next();
        assert.equal(event.kind, "needs-recovery");
        assert.equal(runner.pending?.purpose, purpose);
        assert.equal(native.dispatches, confirmed.size);
        assert.equal(await runner.next(), event);
        event = await runner.reconcile();
        assert.equal(event.kind, "needs-recovery");
        if (event.kind === "needs-recovery") assert.equal(event.phase, "dispatch");
        event = await runner.reconcile();
        assert.equal(event.kind, "needs-recovery");
        if (event.kind === "needs-recovery") {
          assert.equal(event.phase, "confirm");
          assert.ok(event.receipt);
        }
        event = await runner.reconcile();
        assert.equal(event.kind, purpose === "commit" ? "committed" : "progress");
      }
      assert.equal(calls, 1);
      assert.equal(native.dispatches, 3);
    } finally {
      await runner.close();
    }
    assert.ok(native.closed);
  }));

for (const mode of ["drop", "overlap", "throw", "poison"] as const) {
  test(`${mode} cannot freeze a successful private turn`, () =>
    fixture(async (native) => {
      let saved!: Turn;
      const runner = await Runner.open(
        config,
        {
          ...handler,
          async handle(turn) {
            saved = turn;
            if (mode === "poison") {
              native.poison = true;
              try {
                await turn.state.require(key);
              } catch {}
              return;
            }
            if (mode === "throw") throw new HandlerError("application failed");
            void turn.state.put(key, 2);
            if (mode === "overlap") await turn.state.put(key, 3);
          },
        },
        codec,
        fencing,
      );
      await ready(runner);
      await assert.rejects(
        runner.next(),
        mode === "poison" ? ReadFailed : mode === "overlap" ? Busy : HandlerError,
      );
      assert.equal(native.dispatches, 2);
      assert.throws(() => saved.state.put(key, 4), TurnExpired);
      await runner.close();
    }));
}

test("external close joins handler I/O and discards without finishing", () =>
  fixture(async (native) => {
    let entered!: () => void, release!: () => void;
    const start = new Promise<void>((resolve) => {
      entered = resolve;
    });
    native.applyGate = new Promise<void>((resolve) => {
      release = resolve;
    });
    const runner = await Runner.open(
      config,
      {
        ...handler,
        async handle(turn) {
          entered();
          await turn.state.put(key, 2);
        },
      },
      codec,
      fencing,
    );
    await ready(runner);
    const active = runner.next();
    await start;
    await assert.rejects(runner.next(), Busy);
    const close = runner.close();
    await new Promise((resolve) => setTimeout(resolve, 10));
    assert.equal(native.closed, false);
    release();
    assert.equal((await active).kind, "stopped");
    await close;
    assert.equal(native.finishes, 0);
    assert.equal(native.discards, 1);
    assert.equal(native.closed, true);
  }));

test("negative query outcomes bypass application codecs and preserve full correlation width", () =>
  fixture(async (native) => {
    for (const reason of [
      "result_too_large",
      "workspace_exceeded",
      "overflow",
      "cancelled",
      "denied",
    ] as const) {
      native.phase = 0;
      native.input = {
        position: 7,
        kind: "result_failed",
        correlation: "18446744073709551615",
        payload: "",
        origin: { process: { pid: 2, turn: 3, output: 0 } },
        query_failure: { result: 55, reason },
      };
      let calls = 0;
      const runner = await Runner.open(
        config,
        {
          ...handler,
          async handle() {
            assert.fail("Application message callback must not run");
          },
          async handleQueryFailure(_turn, failure) {
            calls++;
            assert.deepEqual(failure, {
              position: 7,
              origin: { kind: "process", process: new ProcessRef(1, 2), turn: 3, output: 0 },
              correlation: 18446744073709551615n,
              result: 55,
              reason,
            });
            assert.ok(Object.isFrozen(failure));
          },
        },
        {
          ...codec,
          decode() {
            assert.fail("Application codec must not run");
          },
        },
        fencing,
      );
      try {
        await ready(runner);
        assert.equal((await runner.next()).kind, "committed");
        assert.equal(calls, 1);
        assert.equal((await runner.next()).kind, "idle");
        assert.equal(calls, 1);
      } finally {
        await runner.close();
      }
    }
  }));

test("unhandled or malformed query failure cannot commit a successful callback", () =>
  fixture(async (native) => {
    for (const queryFailure of [null, { result: 55, reason: "denied" as const }]) {
      native.phase = 0;
      native.input = {
        position: 1,
        kind: "result_failed",
        correlation: "1",
        payload: "",
        origin: { process: { pid: 2, turn: 3, output: 0 } },
        query_failure: queryFailure,
      };
      native.block = false;
      native.failed = false;
      const selected =
        queryFailure === null
          ? {
              ...handler,
              async handleQueryFailure() {
                assert.fail("Missing native outcome must reject");
              },
            }
          : handler;
      const runner = await Runner.open(config, selected, codec, {
        failure: "block-input",
        recovery: fencing.recovery,
      });
      try {
        await ready(runner);
        native.block = true;
        assert.equal((await runner.next()).kind, "blocked");
        assert.equal(native.failed, true);
      } finally {
        await runner.close();
      }
    }
  }));
