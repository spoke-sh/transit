# TypeScript SDK API design

Status: the [public raw client](../../packages/ts/transit-client/README.md) is
implemented and qualified through a clean tarball consumer. The Station APIs
below remain proposed M11 contracts. The [shared design](../SDK.md) owns authority,
lifecycle and recovery rules. The existing `@rey/transit-station` M9 adapter
remains compatible. `counter-contract` denotes the application types/codecs to
implement from shared fixtures; configuration and durable stores belong to the
application.

## Packages and runtime types

The proposed package names are `@transit/client` and `@transit/station`, with the
latter depending on the former. These are artifact-design names, not a claim of
registry availability. The current `@rey/transit-station` low-level package remains
compatible during migration; give it an explicit raw entry point without silently
changing `NativeHost` behavior. The public packages contain strict TypeScript
declarations and runtime validation. Generated wire/ABI types stay internal/raw.
Node.js execution is the target; browser Board inspection remains separate.

`ProcessRef` and `ResourceRef` are validated immutable values containing a realm
and branded protocol ID. Protocol IDs use safe integers within the generated
range. Correlations, application u64 and Arrow int64 use `bigint`. Never accept a
`number` and round it into a `bigint`. Reject malformed runtime values even after
`as`, JavaScript calls or JSON parsing have bypassed static types. Own copies of
input `Uint8Array`s before crossing an async boundary. Exported bytes are copies,
so mutating one cannot change the frozen operation or native-owned buffers.

Selected proposed declarations:

```typescript
interface Codec<T> {
  readonly typeId: string;
  readonly version: number;
  readonly maxEncodedBytes: number;
  encode(value: T): Uint8Array;
  decode(bytes: Uint8Array): T;
}
interface State {
  find<T>(key: Key<T>): Promise<Found<T> | undefined>;
  require<T>(key: Key<T>): Promise<T>;
  put<T>(key: Key<T>, value: T): Promise<void>;
  delete<T>(key: Key<T>): Promise<void>;
  page(cursor?: StateCursor): Promise<Page<KVEntry>>;
}
interface Handler<M> {
  initialize(turn: Turn): Promise<void>;
  handle(turn: Turn, incoming: Incoming<M>): Promise<void>;
}
interface Turn {
  readonly state: State;
  cast<M>(peer: ProcessRef, message: M, codec: Codec<M>): Promise<void>;
  call<M>(peer: ProcessRef, message: M,
          options: { codec: Codec<M>; wait: WaitPolicy }): Promise<bigint>;
  reply<M>(message: M, codec: Codec<M>): Promise<void>;
  requireReply<M>(reply: Reply<M>,
                  expected: { peer: ProcessRef; correlation: bigint }): void;
  cancelCall(correlation: bigint): Promise<boolean>;
}
```

`Incoming<M>` discriminates `kind: "cast" | "call" | "reply"`, with decoded
`value`, position and native-authenticated origin. `Reply<M>` adds correlation.
Application values use their own discriminants; a user-supplied `kind: "reply"`
does not establish framework provenance. `Found<T>` wraps present nullable values,
so `undefined` from `find` means absence. A key fixes its byte name and codec.
Every helper validates its live turn scope and one-in-flight guard at runtime.

## Equivalent service and requester

The proposed application module supplies `Key<bigint>` values `TOTAL`, `REQUEST`
and `OBSERVED`; `counterCodec` decodes `Add | Read`, `requesterCodec` decodes
`Start | Total`. Both validate `counter`, version 1, and full-width values.

```typescript
class Counter implements Handler<Add | Read> {
  async initialize(turn: Turn): Promise<void> {
    await turn.state.put(TOTAL, 0n);
  }
  async handle(turn: Turn, input: Incoming<Add | Read>): Promise<void> {
    if (input.kind === "cast" && input.value.kind === "add") {
      const total = u64.checkedAdd(await turn.state.require(TOTAL), input.value.value);
      await turn.state.put(TOTAL, total);
    } else if (input.kind === "call" && input.value.kind === "read") {
      await turn.reply({ kind: "total", value: await turn.state.require(TOTAL) }, totalCodec);
    } else {
      throw new HandlerError("UnexpectedMessage");
    }
  }
}

class Requester implements Handler<Start | Total> {
  constructor(private readonly counter: ProcessRef) {}
  async initialize(_turn: Turn): Promise<void> {}
  async handle(turn: Turn, input: Incoming<Start | Total>): Promise<void> {
    if (input.kind === "cast" && input.value.kind === "start") {
      if (await turn.state.find(REQUEST) !== undefined) {
        throw new HandlerError("AlreadyStarted");
      }
      const correlation = await turn.call(this.counter, { kind: "read" }, {
        codec: counterCodec, wait: { kind: "untimed" },
      });
      await turn.state.put(REQUEST, correlation);
    } else if (input.kind === "reply" && input.value.kind === "total") {
      turn.requireReply(input, {
        peer: this.counter, correlation: await turn.state.require(REQUEST),
      });
      await turn.state.put(OBSERVED, input.value.value);
    } else {
      throw new HandlerError("UnexpectedMessage");
    }
  }
}
```

`await turn.call` completes one local port operation and returns Station's
input-derived correlation; it does not await a remote reply. `await put/reply`
also only stages private work. The requester persists correlation with its wait
and call output, then handles the recorded reply in a later invocation. Restart
it with fresh ownership and the same peer configuration; no Promise survives or
needs reconstructing. Unlimited lifetimes permit the explicit untimed policy in
this example; finite waits also need a native-validated deadline and observer.

## Runner and port ownership

```typescript
const runner = await Runner.open(serviceConfig, new Counter(), counterCodec, {
  failure: "block-input",
  recovery: { kind: "persist-before-dispatch", store },
});
try {
  for await (const event of runner.run({ signal: stopSignal })) {
    switch (event.kind) {
      case "committed": observeCommit(event.inputPosition, event.receipt.position); break;
      case "blocked": reportBlocked(event.inputPosition, event.receipt); break;
      case "needs-recovery": reportPendingIdentity(event.identity); break;
    }
  }
} finally {
  await runner.close();
}
```

Use `Requester(counterRef)`, `requesterCodec` and the requester activation for
the other role. `run` is a single-consumer async iterator; overlapping runs or
calls reject with `Busy`. `reconcile()` makes one explicit attempt for pending
native work. A `needs-recovery` event ends the iterator before another handler.
Idle polling uses one bounded timer and no accumulated work queue.

Each client/runner owns one native port with one in-flight request, bounded
frames, finite native and outer deadlines, and drained diagnostics. Required
capabilities are negotiated explicitly; the existing M9 hello does not itself
prove growing runner support. The port retains the native worker/stack budgets.
Application handler promises execute serially on Node; native I/O runs in the
port. Synchronous CPU loops can still block Node, so document cooperative handler
requirements instead of promising isolation from arbitrary application code.

`Promise.all` over the same turn is rejected. A pending operation cannot outlive
handler return silently: track all issued turn calls; an outstanding or failed
unobserved call prevents successful freeze. Invalidate the scope when the handler
settles, join native work and discard the proposal on failure. A saved closure
cannot regain its turn. Read failures poison the native proposal even if caught.

The stop signal requests local stop. During an active native request, retain
ownership until completion/deadline; do not send another request or free buffers.
Stop observed before freeze discards private work. A port killed during mutation
dispatch leaves an unknown outcome and requires saved retry bytes or fresh
ownership. `close` joins/reaps the port; it never implies remote cancellation or
successful handler finish. Noncooperative handlers can delay graceful close.
All durable cancellation uses `turn.cancelCall` in a separate valid turn.

## Raw send, outcomes and recovery

`Client.open(config)` resolves and starts the explicit native client host.
`prepareSend(peer, bytes, { credential, sequence })` signs without dispatch;
`PendingSend.export()` returns copied opaque retry bytes. `recoverSend(bytes)`
requires native validation that the operation is a supported send, not a host
JSON parse. Preparation/recovery return promises because they use the local port.

```typescript
type DispatchResult =
  | { kind: "admitted"; receipt: AdmissionReceipt }
  | { kind: "rejected"; error: AuthorityRejection }
  | { kind: "uncertain"; error: UnknownOutcome; recovery: Uint8Array };

const client = await Client.open(clientConfig);
try {
  const pending = await client.prepareSend(requesterRef, encodedStart, { credential, sequence });
  try {
    await outbox.save(pending.identity, await pending.export());
    const result = await client.dispatch(pending);
    if (result.kind === "admitted") {
      await outbox.confirm(pending.identity, result.receipt);
    } else {
      reportAttempt(result); // Keep saved material; do not allocate a new sequence.
    }
  } finally {
    await pending.close();
  }
} finally {
  await client.close();
}
```

`encodedStart` is the result of the shared Station cast encoder with
`requesterCodec`. In a fresh host, use `await client.recoverSend(await
outbox.load(id))` and the same dispatch/confirmation path, without a signing seed.
The application store persists before dispatch and records confirmation before
deleting retry data. Exports, values and secrets stay out of diagnostics.

Dispatch returns a discriminated outcome for an attempted exchange. Preflight
misuse (`Busy`, `Closed`, invalid types, missing capabilities) throws named errors
before dispatch. Cancellation/port failure after possible transmission remains
`uncertain`, never a generic `AbortError` implying rejection. An earlier unknown
outcome remains unresolved if current rights deny a later retry. Read operations
report read errors rather than mutation uncertainty. Preserve exact native status,
authority code and phase in every mapped error.

`RecoveryStore` exposes `beforeDispatch(FrozenMutation): Promise<void>` and
`confirmed(identity, receipt): Promise<void>`. The runner awaits each outside a
native call before proceeding. It rejects reentry during either callback. A
failed first callback leaves the mutation unsent; a failed confirmation callback
reports the known receipt and stops without rerunning the handler.

## Data, packaging and acceptance

`await turn.table(schema)` yields a scoped `Table<Row>` with point methods and
bounded `page(cursor)`. Retained-source IDs and exported cursors can be saved;
source/table handles cannot cross turns. A query-enabled result reader has owned
complete-manifest metadata and `segment(ordinal): Promise<IpcSegment>` returning
copied IPC bytes. Optional Arrow adapters consume each IPC stream separately;
typed arrays or decoded rows cannot replace native completeness checks.

Build Node packages and a version-matched Linux x86_64 native-host artifact,
resolving that installed dependency rather than relying on the current directory
or `PATH`. Allow an explicit executable override. Import starts no process or
network work. `open` reports missing artifacts/exports or capability mismatches
before application dispatch. Core packages need no Arrow dependency; qualify a
separate adapter and its full-width values before advertising it. Registry release
and browser execution remain outside this design's installation proof.

Acceptance requires strict type checks plus runtime malformed-ingress cases,
unawaited/overlapping/escaped-turn rejection, responsive port I/O, abort/exit
recovery, shared failure scenarios and clean installation of built artifacts
outside the checkout. Compile success alone is not runtime validation.
