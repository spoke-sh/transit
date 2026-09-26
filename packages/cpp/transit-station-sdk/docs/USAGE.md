# Installing and composing a runner

Extract the version-matched C/client/Station and native archives plus both C++
header archives from `just bindings::c-build` into one prefix. Point
`PKG_CONFIG_PATH` at its `lib/pkgconfig` directory, then compile with:

```sh
zig c++ -std=c++17 app.cpp $(pkg-config --cflags --libs transit-station-cpp) -o app
```

`transit-sdk-examples-cpp` additionally installs the real `transit-cpp-counter`
executable and public application header, depending on the shared C application
codec library. The [examples](../../../../examples/station-sdk/cpp/README.md)
implement both counter and Table/query roles without native actions or raw polling.
The supported combination is the pinned Zig C++17 toolchain, Linux x86_64 and
the build's Nix runtime closure. No compiler-independent C++ binary ABI or generic
Linux distribution is claimed. pkg-config pins direct package versions and
supplies the installed rpath. Native libraries resolve beside the C client SDK;
`ClientConfig::native_directory` overrides that directory explicitly.

Create `ServiceConfig` with the endpoint, durable process, principal, generation
and seed file. Association `data` is the default; `association(name)` selects
another existing association. Enable `query_results()` explicitly. The SDK
checks native/authority capabilities and current authorization. It neither
provisions processes nor obtains new ownership implicitly.

Implement `Codec<T>` and `Handler<T>`. The codec owns versioned application bytes,
strict ingress validation and an encoded-size bound. Its metadata methods are
pure, stable and noexcept; its application type fits max_align_t alignment and
has a noexcept destructor. Handler input is a variant of `Cast<T>`, `Call<T>` and
`Reply<T>` with authenticated origin and position. Controls and verified query
completion have separate virtual methods. Returning from any handler contributes
private state/outputs, not a commit receipt.

`Runner<T>::open` owns the handler and shared codec; pass explicit
`RunnerOptions::fresh_ownership()` or `RunnerOptions::persist(store)`. `next()`
does bounded native/framework work and returns a move-only event. `info()`
distinguishes progress, idle, committed, blocked, stopped and needs-recovery
observations. Committed events carry a known receipt. For needs-recovery,
`pending()` returns owned exact bytes plus native-classified identity/purpose/input.
Export does not decode or replace the signed request. `reconcile()` retries a
paused operation/confirmation; normal `next()` stays paused in the meantime.

The store persists each permit/open/commit before dispatch and observes known
receipts afterward. A confirmation-hook exception retains the known receipt;
reconciliation does not rerun the handler. The counter CLI's sample store syncs
both the request file and its parent directory before authorizing dispatch.
Provision a private, durable application directory and choose its retention and
recovery policy. An unknown accepted result can be recovered with the independent
raw client's `recover_mutation`/`dispatch`, including without the signing seed.
The SDK never infers current ownership from a file or host object.

## Scope, errors and cleanup

One owned 8 MiB worker runs native calls, encoding/decoding, handlers and cleanup.
Controller methods block; move the runner into an application-owned blocking task
when integrating with an executor. `stop()` signals cooperative local stop and
can be called while work is in flight. `close()` joins and returns last-event and
pending evidence. Abandoning a controller's receive leaves its task responsible
for joining. Asynchronous POSIX thread cancellation is unsupported. A callback
that never returns also prevents completion of close; this SDK does not claim
preemptive application isolation.

Runner/client handles are move-only. Do not move or destroy them concurrently
with another thread using them. Close can join an admitted operation; callback
reentry rejects before changing stop state. Member destruction joins native work
before releasing handler/codec/store contexts. RAII never acknowledges a private
turn or claims durable cancellation. Explicit `cancel_call` records advisory peer
cancellation; a local stop or abandoned future is different.

`Turn`, `State`, `Source` and `ResultReader` retain a local scope token. Copies are
safe to keep, but operations after their handler turn fail with TURN_EXPIRED.
Foreign-thread and recursive codec access fail with BUSY. Native read errors
poison the private turn even when caught by application code. SDK `Error` retains
the category, phase, native status and bounded protocol code; foreign exceptions
are converted before crossing the C callback boundary. Stop policy leaves the
mailbox head pending; block-input policy gates a native failure marker after
discarding private changes. Fencing, retirement, revoked access and missing
history remain distinct from ordinary handler/codec failure.

## State and owned data

`Key<T>` pairs a copied application key with a shared codec. `state().find(key)`
returns an optional value; `require(key)` distinguishes missing state from a
decoded nullable application value. Typed `put` requires the key's value type.
`budgets()` exposes remaining operations. Only one associated KV resource may
be mutated per turn under the current profile; durable cardinality is accessed
through bounded pages, not copied into a runner-owned queue.

`TableSchema<T>` supports int64_t, bool, string and byte-vector values, with an
i64 key. `Row<T>` has an optional cell; `get()` has a separate optional row.
Schema capture verifies the declared names and value type. Pages contain owned
rows, source basis and an optional move-only cursor. `retain()` records a durable
read version, and `source(version)` exposes read-only KV/Table helpers with
current native authorization. `release(version)` is an explicit durable turn
operation. Freeing a local helper never silently releases a recorded version.

Calls return full u64 correlations. Store that identity with the output and end
the private turn; a later activation verifies its recorded reply with
`require_reply`. Handler fields, threads and captured lambdas do not replace
associated durable state. Query plans use typed projections, predicates and
aggregates; execution stays in Fuze's Zig implementation.

`result(correlation)` rechecks access on every complete manifest/segment read.
The manifest carries source/destination, captured resource/revision/schema, plan,
segment/row/byte counts and chain identity. `IpcSegment` owns its native-independent
data, and `ipc()` returns another owned byte vector. Both survive runner close;
mutating a returned copy cannot alter the segment. No Arrow C++ adapter is
selected. Original streams are decoded independently with PyArrow in the shared
proof; an application can add its own qualified Arrow consumer without changing
core SDK dependencies. A single segment is not advertised as the entire result.

M9's `transit_station.hpp` low-level wrapper remains separate. Migrating to this
SDK replaces direct ABI polling/actions with typed handlers and explicit durable
observations; it does not expand native quotas, schemas or authority guarantees.
