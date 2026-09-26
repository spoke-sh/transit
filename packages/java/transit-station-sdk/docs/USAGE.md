# Java Station usage

Build with `nix develop .#bindings -c just bindings::java-build`. Install
`transit-client-0.2.0.jar`, `transit-native-client-0.2.0.jar`,
`transit-station-sdk-0.2.0.jar`, `transit-native-station-0.2.0.jar` and
`gson-2.12.1.jar` into an application's `lib/`. Compile with
`javac --release 21 -cp 'lib/*'` and run with `java -cp 'lib/*:classes' Main`.
The independent JARs include POM manifests with direct, versioned dependencies.
Native artifacts are discovered on the classpath, checked for SDK/ABI versions,
extracted privately and removed after joined cleanup. `ClientConfig.nativeHost`
overrides the Station executable explicitly. Maven resolution/publication is
not part of the local installation proof; artifacts require the pinned Nix
runtime closure.

## Handlers and turns

Implement `Handler<T>`, with an explicit `Codec<T>` specifying type ID, version,
encoded bound and strict application encoding/decoding. The application format
must carry its own version. Incoming payloads are decoded before initialization
or message dispatch. `initialize`, `onMessage`, `onControl` and `onResult` execute
synchronously on one owned worker. An exception or `Error` becomes a bounded
handler error; it never implicitly acknowledges input. Application fields are
temporary; associated state holds durable facts.

```java
try (var runner = Runner.open(serviceConfig, handler, codec,
        Types.FailurePolicy.STOP, new Recovery.PersistBeforeDispatch(store))) {
    Types.Event event = runner.next().join();
    if (event instanceof Types.NeedsRecovery paused) {
        saveRecoveryEvidence(paused);
    }
}
```

The application supplies an existing `Activation` with durable `ProcessRef`,
generation and explicit credential. `ServiceConfig` selects an association
(default `data`) and query-result opt-in. Capabilities are checked against the
native host and authority before processing. The SDK never acquires ownership,
provisions resources or falls back from `GROWING_V3` implicitly.

`Turn.state()` provides `find`, `require`, `put`, `delete` and bounded `page`.
`Key<T>` carries the application codec. `Optional<T>` distinguishes absence;
codecs must return non-null decoded values. `Table.Schema<T>` supports `Long`,
`Boolean`, `String` and immutable `Bytes`, with nullable `Row<T>.value()` and
signed `long` keys. `Optional<Row<T>>` distinguishes missing rows from null cells.
Tables validate the captured native schema. Pages own their values/cursors/basis;
the native profile returns at most eight entries per page.

Turn, state, Table, retained-source and result-reader operations require the
active handler thread and reject reentrant codec operations. All scoped helpers
expire at callback completion, including after runner disposal; saving them
does not keep the turn alive. Owned records/bytes remain usable independently.
Failed reads poison the whole private turn even if caught. Poison prevents both
success and a block-input marker. A local stop discards private work; it does not
discard earlier unresolved mutations.

`budgets()` reports native remaining mutations, outputs, views and retained-read
operations. Initialization consumes one mutation in the four-mutation profile.
`retain()` records a durable read-version identity; `openVersion()` exposes
authorized read-only state/Table access, and `release()` records its release.
Keeping a Java object never retains a source. Page size and per-turn budgets
bound resident work without setting collection cardinality ceilings.

## Calls, recovery and cleanup

`cast`, `call` and `reply` use typed codecs. A call returns a full u64
`BigInteger` correlation; save it in associated state and return from the turn.
A later `Reply<T>` or `ResultComplete` resumes through durable history.
`requireReply` verifies the current authenticated input, expected peer and saved
correlation. `WaitPolicy.untimed()` has no implicit expiry; timed waits require
an explicit deadline and observer. `cancelCall` is an explicit durable operation
with advisory peer semantics. Cancelling a Java future does not invoke it.

Every permit/open/commit mutation reaches `Recovery.Store.beforeDispatch` before
native dispatch. It receives immutable exact bytes and the native operation
identity/purpose/input. Persist privately and synchronize according to your
failure model before returning. `confirmed` receives the identity and known
receipt. Either hook may fail: `NeedsRecovery` retains the exact pending mutation,
phase, bounded error and any known receipt. `next` repeats that pause;
`reconcile` resumes it without rerunning the handler. A failed confirmation hook
reuses the retained receipt. Transport uncertainty retries only the same signed
operation. Raw `Client.recoverMutation` supports seedless recovery after host
loss. `Recovery.FreshOwnership` is the explicit alternative when the deployment
will fence a fresh activation and reconcile durable history after loss of local
pending material; it is not permission to re-sign an uncertain request.

`Committed` confirms the turn, `Blocked` records the explicit failure policy,
and `Progress`/`Idle` do not claim commitment. `STOP` leaves failed input unconsumed;
`BLOCK_INPUT` records the native blocked head while discarding private handler
changes. Errors preserve rejection, uncertainty, revoked access, stale ownership,
retirement and history unavailability. Handler return alone proves nothing durable.

`next`, `reconcile`, `evidence` and `closeAsync` return futures. There is one admitted
job, one completion slot and a reserved cleanup command, with an owned pipe worker,
completion publisher and deadline timer. The child owns native I/O and its 8 MiB
stack; query-enabled servers have the native 1 MiB workspace and 8192-byte segment
bound. No native I/O runs on a JVM event loop. Cancellation abandons only the
future; it does not interrupt its handler/native job. `stop()` is cooperative;
an uncooperative handler can delay cleanup. A callback cannot join/reenter its
own runner. Synchronous completion continuations must not wait for another result
on the same publisher; compose with `thenCompose` or use an application executor.

`closeAsync` stops admission, requests local stop and joins the admitted job before
disposing native state. `closeSnapshot` also joins the Java worker/publisher;
it returns pending/last-event evidence. Cancelled close views do not cancel this
ownership. `retainedEvidence` remains available after cleanup, including cleanup
failure. Startup and synchronous close block their caller. Dropped Java references
and garbage collection are not a shutdown protocol; close explicitly.

## Query results

`allowQuery`, `startQuery` and `closeQuery` express native policy and typed plans;
the SDK contains no query engine. `Query.Plan` supports the qualified projection,
predicate, aggregation and optional full u64 limit. A verified `ResultComplete`
is delivered separately from application messages. `turn.result(correlation)`
opens a scoped reader; `manifest()` returns complete source/destination identity,
resource/revision, table/policy, plan/schema/chain digests, and exact counts.
`segment(ordinal)` checks current authorization and returns owned original IPC
with its manifest/digest. Segment reads remain bounded; stream them through your
consumer rather than collecting an unbounded result. External consumption effects
need application idempotency across retries. Java does not select an optional
Arrow adapter; PyArrow independently qualifies IPC after runner disposal.

M9's `io.transit.station.NativeHost` remains the low-level JSON pump. This SDK uses
`io.transit.sdk.station` and keeps that adapter unchanged. Use this public runner
for application handlers; manual ABI/JSON actions are not required. Native
post-commit allocation enumeration is shared evidence; the Java consumer does
not inject JVM allocation failure or promise recovery from fatal resource loss.
