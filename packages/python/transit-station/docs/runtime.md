# Runtime, recovery and scoped data

`Runner.open` is synchronous; `AsyncRunner.open` is awaited. Use `with` or
`async with await AsyncRunner.open(...)`. Both execute synchronous handlers and
persistence hooks on one owned worker with the generated 8 MiB minimum stack.
Each native handle has a separate bounded two-worker I/O pool. One operation is
admitted per runner; overlap/reentry raises `Busy`. Async I/O and joined cleanup
leave the event loop responsive. A CPU-bound or noncooperative handler can still
delay progress and shutdown; this is not arbitrary-code isolation.

A handler implements `initialize(turn)` and `handle(turn, incoming)`. Decode
happens before either callback. Initialization belongs to the first committed
turn; fields on the handler remain temporary. `Incoming` is `Cast`, `Call` or
`Reply`, carrying immutable authenticated provenance separately from its value.
Optional `handle_control(turn, control)` receives application-visible timeout or
cancel inputs. `handle_result(turn, reader)` receives native-verified completion;
query control processing stays in Zig and never enters an application codec.
Coroutine callbacks and non-None callback returns are rejected.

`run(stop=...)` owns sequential dispatch and yields `Committed`, `Blocked`,
`NeedsRecovery` or `Stopped`; normal polling progress remains internal. `next()`
advances a bounded amount of work for explicit scheduling; it may also return
`Idle` or `Progress`. Neither can overlap another consumer. A failure event ends
iteration. `Committed` confirms the input's native turn receipt, including any
internal framework turn. It does not promise an external effect or reply.

Choose `FailurePolicy.STOP` to discard private handler/codec changes and leave
the input for a fresh attempt. Choose `BLOCK_INPUT` to freeze a durable failure
marker, which still needs persistence and confirmed dispatch. A failed native
read poisons the proposal even if the handler catches the exception; it cannot
be turned into a successful commit or application failure marker.

## Persistence and cancellation

Choose `Recovery.persist_before_dispatch(store)` or explicitly select
`Recovery.fence_on_restart()`. The latter requires fresh authorized ownership
after host loss. No SDK call acquires that ownership for the application.

A store implements synchronous `before_dispatch(FrozenMutation)` and
`confirmed(OperationIdentity, MutationReceipt)`. Persist `mutation.export()`
before returning from the first hook, then record the receipt before deleting
retry material in the second. Hooks cover permits, view opens and every turn,
including internal query work. The SDK writes no hidden outbox files.

A persistence failure leaves the mutation unsent. Dispatch uncertainty retains
its exact signed bytes. Confirmation failure retains the known receipt and
stops before another handler. `NeedsRecovery` identifies the mutation, phase,
error and optional receipt. `reconcile()` explicitly retries the stopped phase;
it never reruns the completed handler. Native confirmation is retained even when
foreign response allocation fails after acceptance.

In another host, `transit_client.Client.recover_mutation(saved_bytes)` and
`dispatch_mutation(pending)` reconcile the same native-classified command without
a seed. Its `MutationReceipt` confirms that command, not message admission or a
remote reply. Record it, then obtain a fresh activation before starting a new
runner. Without saved bytes, fence the old worker and inspect durable state;
do not manufacture a replacement identity for an unknown request. Revoked retry
rights leave the earlier uncertainty unresolved.

Cancelling an async await requests local stop but retains native ownership until
completion/deadline. `aclose()` joins work and releases handles, even if its own
await is cancelled. Inspect `last_event` and `pending`; save recovery material
before dispatch. Local stop, exceptions and cleanup never acknowledge input.
Unsent private work is discarded when stop is observed. `turn.cancel_call` is a
separate recorded advisory cancellation; it cannot retract accepted peer work.
Explicit contexts are required; finalizers are not a shutdown protocol.

Named exceptions are in `transit_client.errors` and retain native status, cause,
authority code when available and attempt phase. Scope escape raises
`TurnExpired`; another thread cannot use a handler's turn. Authentication,
retirement, stale ownership and read failure remain distinct. Current read
authorization may hide an association, reported as unavailable state rather than
inventing an authority denial code. Keep credentials, payloads and opaque retry
bytes out of diagnostics. Python copies of secret material cannot be guaranteed
erased; native temporary keys are erased.

## State and results

`Key[T]` binds immutable application key bytes and a codec. `find` returns
`Found(value)` or None, preserving a present nullable value; `require` raises
`MissingValue`. `put` and `delete` stage changes in the same native proposal as
input progress and outputs. `turn.budgets` includes native framework reservations.
All resource helpers expire with the turn, including captured closures.

[Typed Tables](tables.md) discover their general schema and expose stable row
identities, composite primary-key lookup and bounded `page(cursor)` reads.
Readers observe the committed cut; a private mutation becomes visible after its
turn commits. `TableMutation.save()` captures the exact intent and `step(turn)`
prepares one resumable step. Input processing and applied mutation completion are
separate outcomes. `retain`, `open_version` and `release` expose retained sources;
IDs survive turns, handles do not. Only a null continuation proves a page sequence
complete. Default lifetimes remain unlimited.

Queries require `ServiceConfig(query_results=True)`. Services explicitly authorize
peer/Table policies and call `start_query` from a recorded request. The result
reader checks native completion and current access and returns owned metadata
and one bounded `IpcSegment` at a time. `ipc: bytes` survives scope/runner disposal;
the reader does not. No whole-result collection is allocated by the SDK.

`IpcSegment.to_pyarrow()` optionally decodes one stream with PyArrow 23.0.0. Core
SDK use needs no Arrow dependency; install the `arrow` extra for this adapter.
The test uses the pinned Nix PyArrow consumer after the clean core-wheel proof.
The manifest retains source, captured basis, plan, chain, schema and counts.
Copied bytes/decoded batches neither extend a result's lifetime nor grant access
to fetch more segments. External effects performed by a result callback still
need their own recorded intent/idempotency policy; the enclosing turn is private
until its receipt is confirmed.
