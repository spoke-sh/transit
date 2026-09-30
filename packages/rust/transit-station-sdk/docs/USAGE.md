# Rust Station SDK

`transit-station-sdk = "=0.2.0"` exports `transit_station_sdk`; it depends on
version-matched `transit-client` and `transit-native-station` artifacts. Locally,
extract the crates built by `just bindings::rust-build` and use ordinary Cargo
`[patch.crates-io]` entries for those crates and `transit-native-client`. No loader
path assembly is needed: native artifacts are embedded at build time and loaded
from a private temporary directory at runtime. The executable continues to work
after removing the extracted crates and build directory. An explicit
`ClientConfig::with_native_directory` selects trusted replacement native files.
Missing files, ABI differences and absent growing capabilities produce named
errors; there is no fallback to incompatible definitions.

Native code mappings remain until process exit and are shared across runners and
codec calls. Runner close still releases its handles, buffers and owned work.
The [raw client's loader rules](../../transit-client/README.md) bound resident
images and require explicit override files to remain immutable within a process.

## Handler and runner

Implement `Codec<Message>` and `Handler<Message>`. Codecs own versioned application
bytes, maximum length and strict ingress validation. They must preserve full-width
`u64`/`i64` values. Decode happens before initialization or application dispatch.
Use the compiled [examples](../../../../examples/station-sdk/rust/README.md) for
counter and query formats shared with Python and TypeScript.

Create `ServiceConfig::new(ClientConfig::growing(url)?, activation)`, then
`Runner::open(config, handler, codec, options)`. An activation explicitly supplies
the durable process, principal, generation and seed-file reference. Loading the
crate reads no credentials and starts no worker. Enable query results explicitly
with `with_query_results(true)`.

The blocking controller owns one 8 MiB worker with one bounded command slot. All
native calls, handlers, persistence hooks and destruction execute on that worker.
Operations require `&mut Runner`; it is `Send` but not `Sync`. Move it into an
application-owned blocking task when integrating with an executor, and retain
that task until join. The core has no executor dependency. Do not call the
blocking API on an event-loop thread.

`next()` returns `Result<Option<RunnerEvent>>`; `Idle` means an empty mailbox,
`Progress` means bounded internal work, and `None` means local stop. Only
`Committed` proves turn commitment. `Blocked` records the configured failure
marker without consuming the input. `NeedsRecovery` exposes phase, exact frozen
mutation and any known receipt. Calling `next()` again preserves that event;
`reconcile()` explicitly attempts its recovery without running the handler again.

Initialization and each sequential handler share one private proposal. Returning
`Ok(())` does not acknowledge it. `FailurePolicy::Stop` discards private changes;
`BlockInput` freezes an explicit failure marker. Caught unwinding panics use the
same policy. Process abort follows host-loss recovery. Native read poisoning
prevents either commit even if the handler catches the error. Control messages
and verified query completion have separate `handle_control` and `handle_result`
callbacks, outside the application's codec.

## Lifetimes and data

`Turn<'_>` and its KV, Table, retained-source and result readers borrow the active
proposal exclusively. They cannot escape or cross threads. Pages, cursor exports,
read-version IDs, manifests and `IpcSegment` bytes own their data. Retained IDs
preserve a source basis; using them still requires current authorization and a
live turn. Associated resources do not grant access or lifetime ownership.

Use `Key<T>` with `state().find/require/put/delete`; missing and nullable values are
distinct. `TableSchema<C>` selects `i64`, `bool`, `String` or `Vec<u8>` cells with
nullable values and an i64 key. `table().get/insert/update/upsert/delete/page`
checks the native schema and bounds. Pages contain at most the native page size;
cursors remain bound to their source revision. `turn.budgets()` exposes remaining
operation capacity; initialization itself consumes a mutation slot. A durable
collection's total size is not a resident SDK queue.

`call()` stages a durable wait/output and returns its input-derived correlation.
Persist that correlation in the same turn. A fresh owner handles the later reply
using `require_reply`; no suspended Rust stack is durable. `cancel_call` stages
advisory durable cancellation, separate from stopping the local runner.

Query handlers use `start_query` with a typed plan. A requester receives
`ResultComplete`; it opens `turn.result(complete.correlation)`, reads the complete
manifest and individual bounded segments, and releases that borrow before writing
state. Every segment read rechecks current access. The manifest includes both
processes, source resource/revision/schema, plan and chain digests, correlation,
rows, segments and bytes. Original IPC remains usable after runner disposal.

Feature `arrow` enables `IpcSegment::to_arrow()` using locked Arrow Rust 59
components. Each segment is its own IPC stream. It returns owned record batches
and checks the declared row count; mutating/dropping the SDK bytes afterward does
not invalidate batches. The complete manifest determines result completeness;
one decoded segment does not. Core builds require no Arrow dependencies.

## Recovery and shutdown

Choose `Recovery::PersistBeforeDispatch(Box<dyn RecoveryStore>)` to durably save
every permit, view-open and turn mutation in `before_dispatch`. Return success
only after your storage has persisted `mutation.export()` and its identity.
Exports are opaque signed retry material; keep them private. `confirmed` receives
the matching identity and `MutationReceipt`. Hook errors or panics pause the
runner. A confirmation-hook failure retains the known receipt and does not
redispatch or repeat the handler. Recovery storage is application-owned.

After process loss, use independent `Client::recover_mutation` and
`dispatch_mutation` to reconcile saved bytes exactly, without a signing seed.
Current authorization still applies. Fresh ownership fences old work; it cannot
turn an unknown outcome into rejection. `Recovery::FenceOnRestart` explicitly
chooses fencing when retry material is not persisted.

`stop_token()` gives a cloneable local signal. Stopping during native I/O does not
interrupt that exchange or erase its receipt. `close(self)` stops, joins and
returns `Shutdown { pending, last_event }`; `CloseError` retains evidence if the
snapshot succeeded before cleanup failed. `Drop` joins without acknowledging
work but cannot report cleanup errors, so prefer explicit close. No deadline
can force arbitrary application code to return.
