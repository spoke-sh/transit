# .NET Station usage

Build with `nix develop .#bindings -c just bindings::dotnet-build`. Configure a
NuGet source pointing at `.cache/bindings/dotnet` and reference
`Transit.Station.Sdk` version `[0.2.0]`. NuGet resolves the exact public client and
separate native dependencies. Reference `Transit.Client` directly when using its
public types. The qualified target is .NET 8/Linux x86_64 in the pinned bindings
shell; these native artifacts require the Nix runtime closure. Registry
publication and other runtime/platform combinations are not qualified.

Native assemblies are discovered through normal assembly resolution. SDK/package
versions and generated ABI versions are checked before use. Each owner extracts
a private native library and removes it after cleanup. An explicit
`ClientConfig.NativeDirectory` selects an override directory containing
`libtransit_station.so` and `libtransit_client.so`. Loading an assembly performs
no credential discovery, activation acquisition or network work.

## Typed handlers and state

Implement `IHandler<T>` and an `ICodec<T>` with a type ID, version, encoded bound
and strict `Encode`/`Decode`. The application format must encode its own version;
the shared example codecs demonstrate the versioned format. Incoming payloads
are decoded before initialization or handler dispatch. Decoded values must be
non-null. `Initialize`, `OnMessage`, `OnControl` and `OnResult` execute synchronously
on the owned worker. `async void` handler and recovery callbacks are rejected at
startup. Callbacks must finish their work before returning; starting detached
work does not extend their scope. Application fields are temporary.

```csharp
await using var runner = await Runner<Message>.OpenAsync(
    serviceConfig, handler, codec, FailurePolicy.Stop,
    new Recovery.PersistBeforeDispatch(store));
RunnerEvent outcome = await runner.NextAsync();
if (outcome is NeedsRecovery paused)
    SaveRecoveryEvidence(paused);
```

The application supplies an existing `Activation`: durable `ProcessRef`, current
generation and explicit credential. `ServiceConfig` selects the associated
resource name (default `data`) and query-result opt-in. Capabilities are checked
against the shared library and authority. The SDK does not provision resources,
acquire ownership or implicitly fall back from `Profile.NativeV1`.

`turn.State` provides typed `Find`, `Require`, `Put`, `Delete` and bounded `Page`.
`Key<T>` carries the application codec. A nullable `Found<T>` distinguishes
absence. `turn.Table(objectId)` discovers a general `Catalog.Schema`; `TableRow`
contains an owned stable identity and logical cells. Missing rows differ from
present rows with null cells. Table operations validate the captured native basis.
Pages own values and cursors, with at most eight entries per page. Object and
operation identities use the full `ulong` range. See
[typed handler Tables](TABLES.md) for creation, saved mutation steps and limits.

Turn-derived state, Table, retained-source and result-reader operations require
the active handler thread and reject reentrant codec access. Helpers expire when
the callback ends, including after runner disposal; owned values and copied bytes
remain usable. Read errors poison the private turn even if a handler catches the
exception. Poison prevents both successful commitment and a block-input marker.
A local stop discards private handler work without discarding unresolved mutations.

`Budgets()` reports native remaining mutations, outputs, views and retained-read
operations. Initialization consumes one mutation in the four-mutation profile.
`Retain()` records a durable read-version identity. `OpenVersion()` gives scoped,
authorized read-only access; `Release()` records release. Keeping an object does
not retain a source. Resident bounds apply to pages and operations, not total
collection cardinality.

## Calls, recovery and cleanup

`Cast`, `Call` and `Reply` encode typed application values. Save the full `ulong`
call correlation in associated state and return from the current turn. A later
`Reply<T>` or `ResultComplete` resumes from durable history. `RequireReply`
checks the current authenticated input, expected peer and saved correlation.
`WaitPolicy.Untimed` has no implicit expiry; `Until` requires an explicit deadline
and observer. `CancelCall` is an explicit durable operation with advisory peer
semantics. Cancelling a task wait does not invoke it.

Every permit/open/commit mutation passes through `IRecoveryStore.BeforeDispatch`
with immutable exact bytes, operation identity, purpose and input position.
Persist privately and synchronize to the application's failure model before
returning. `Confirmed` receives the identity and known receipt. Either hook can
fail: `NeedsRecovery` retains the mutation, phase, bounded error and any known
receipt. `NextAsync` repeats the pause; `ReconcileAsync` resumes without rerunning
the handler. A failed confirmation hook reuses retained confirmation. Transport
uncertainty retries only the same signed operation. Raw
`Client.RecoverMutationAsync` supports seedless retry after host loss.

`Recovery.FreshOwnership` is the explicit alternative when the deployment will
fence a fresh activation and reconcile durable history after losing local pending
material. It does not permit replacing an uncertain request with a new identity.
`Committed` confirms the turn; `Blocked` records explicit failure policy;
`Progress` and `Idle` do not claim commitment. `FailurePolicy.Stop` leaves failed
input unconsumed; `BlockInput` records the native blocked head and discards private
handler changes. Errors preserve rejection, uncertainty, revoked access, stale
ownership, retirement and unavailable-history distinctions. Callback return alone
proves nothing durable.

`NextAsync`, `ReconcileAsync`, `EvidenceAsync` and `CloseAsync` use one owned
8 MiB thread with one admitted operation and no work backlog. Task continuations
are scheduled asynchronously; no native I/O runs on an application event loop.
Query-enabled runners use the native 4 MiB workspace and 65535-byte segment bound.
A `CancellationToken` abandons only the local wait; admitted work continues.
`Stop()` is cooperative, and an uncooperative handler can delay cleanup.
Callbacks cannot reenter or join their own runner.

`CloseAsync` stops admission, requests local stop and waits for the admitted job
and native destruction. `CloseSnapshot` additionally joins the OS thread and
returns pending/last-event evidence. Cancelling a local `CloseAsync().WaitAsync`
view does not cancel cleanup. `RetainedEvidence` survives disposal, including
cleanup failure. `OpenAsync` acquisition must be observed and its runner disposed;
there is no cancellation token that could abandon a newly created owner.
`Dispose` blocks its caller; prefer `await using` in asynchronous applications.
Garbage collection is not a shutdown protocol.

## Queries and migration

`AllowQuery`, `StartQuery` and `CloseQuery` use native policy and typed plans; the
SDK contains no query engine. `new QueryPlan(UnifiedQuery.Plan)` freezes a general
projection, output names, typed predicate, aggregation and optional full `ulong`
limit. Table IDs and policy revisions use `ulong`. Verified `ResultComplete` arrives
separately from application messages. `turn.Result(correlation).Manifest()`
returns complete source/destination identity, resource/revision, Table-head digest, table/policy,
plan/schema/chain digests and exact counts. `Segment(ordinal)` rechecks current
authorization and returns copied original IPC with its manifest and digest.
Stream bounded segments through a consumer; external effects need idempotency
across retries. No optional .NET Arrow adapter is selected. The shared proof uses
independent PyArrow to decode original IPC after runner disposal.

The M9 `Transit.Station` low-level assembly remains available for conformance and
explicit JSON/ABI work. This independent API uses `Transit.Station.Sdk`; ordinary
handlers need no manual polling or generic JSON actions. Generated delegates and
schemas stay internal. Native post-commit allocation enumeration remains shared
evidence; the .NET proof does not inject managed allocation failure or qualify
recovery from fatal process/resource loss.
