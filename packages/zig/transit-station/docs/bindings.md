# Shared Station ABI

`zig build station-abi client-abi transit-station-host` builds the native
libraries and optional port executable. The generated [header](../include/transit_station.h)
and [ABI/schema resource](../abi-v1.json) come from exported Zig signatures and
types. `just bindings::generate` updates host resources; `just bindings::check`
rejects drift. ABI version 1 is experimental and qualified on Linux x86_64.

The host owns its handler and supplies actions; the same Zig GenServer, Table,
registry, supervisor, signing and query code supplies framework semantics. There
are no host-language branches in the authority. [Language adapters](../../../../bindings/README.md)
own scheduling and handles, not durable state. The [port host](../../../../apps/transit-station-host/README.md)
exposes this implementation to runtimes without an in-process native adapter.

## A private turn

The following `station_server_*` interface retains the M9 legacy profile.
The additive [growing interface](#explicit-growing-turns) is selected separately.

1. Create a server with an explicit endpoint, 32-byte seed, realm, principal,
   PID, activation generation and required association. Creation does no I/O.
2. `station_server_next` drives bounded protocol work. `progress` means more
   polling is needed, `idle` means no input, `ready` presents one detached turn,
   and `committed`/`blocked` describe a confirmed durable transition.
3. At `ready`, run initialization when indicated, then the handler. Apply typed
   actions to its private proposal: KV, Table, messaging, query, name or child
   operations. A rejected action rolls back that action, preserving earlier
   private work. Query-after-mutation is rejected rather than using a new view.
4. `station_server_finish(server, 0)` validates and freezes the proposal.
   Passing `1` discards the proposal and freezes a failed turn, preserving the
   mailbox head. Neither form submits a request. Poll until the result is known.

The host may poll a ready turn repeatedly; this does not renew its read view.
An expired view cannot be committed. Destroying a host or handle does not
acknowledge, cancel, commit or record a handler failure implicitly. The host
chooses its exception policy and drives a failed proposal if it needs that
durable outcome. The Zig `GenServer.step` callback API uses the same poll/finish
machine. Handler code has no authority-side execution path.

## Ownership, scheduling and recovery

Handles own their native I/O state. One operation may use a handle at a time;
concurrent use returns `busy`. Destruction requires joining every operation
first. All non-null pointers must be valid, lengths must match their allocations,
and native buffers are not NUL terminated. `station_buffer_data/size` borrow
bytes until exactly one `station_buffer_destroy`. No callback crosses the ABI.

The qualified Debug build requires an **8 MiB calling-thread stack**, published
as `minimum_stack_bytes`/`STATION_MINIMUM_STACK_BYTES`. The Rust default 2 MiB
worker stack failed the real service proof; its adapter supplies an explicit
worker with the generated budget. Use that worker, a suitably configured native
thread, or the port. Do not call into this build on small executor/green stacks.
Bound the number of native workers as well as their stack size. The host port
uses the ordinary Linux process stack. Smaller native stack requirements need
a separate allocation refactor and qualification; optimized builds alone are
not evidence for lowering this declared bound.

Calls are synchronous and deadline-bounded; adapters move them off event loops
and BEAM schedulers. Cancelling an await never proves that a submitted request
was cancelled. Keep the handle alive until native work returns. A fresh host
may retry exact exported pending bytes through the raw Transit ABI, or obtain
a fresh activation and reconcile the committed view before recomputing.

The native handle's I/O pool remains bounded to two workers. Shared client
deadlines include waiting for retiring workers to release their slots; only
scheduling is retried. HTTP attempts and frozen proposals retain the ordinary
explicit retry policy. The ABI proof runs on one CPU on Linux and exercises
back-to-back raw-client retries alongside Station polling.

`station_server_pending` exports the canonical frozen envelope understood by
the [raw client ABI](../../transit-client/docs/bindings.md). Persist those exact
bytes before sending when durable local retry material is needed. They contain
no private key, but may contain application data. They are not a receipt or a
second source of execution authority. The framework persists call correlations
and query results in associated state, independently of these native handles.

Errors distinguish argument/version/ownership problems, busy handles, unavailable
reads and uncertain submissions. Rejections retain the authority's protocol
error when present. No error silently consumes the input or changes ownership.
The host's proposed read deadline is bounded and checked by the authority.

## Foreign data

The generated action/result schemas own JSON shapes. Payloads and IPC bytes use
lowercase hex. Arrow int64 values/keys and Station u64 correlations use decimal
strings across JSON boundaries; protocol identity counters retain their existing
53-bit ceiling. Each result exposes original finite IPC bytes. `station_arrow_cell`
is an optional bounded accessor using the same Arrow implementation; consumers
can instead give IPC to their own Arrow library. It does not replace the bytes
with a JSON-only result API. All ordinary Table and result budgets still apply.

The shared `station_json_extract` helper gives C/C++ callers bounded JSON access
without another parser: slash-separated object keys/array indices, JSON or raw
string output. It is deliberately not a complete JSON Pointer implementation
and has no escaping syntax. Returned raw strings may contain NUL bytes.

`just bindings::native` qualifies C/C++/Python and the native port,
including a real handler/Table exchange, exact pending retry after handle loss,
failed-turn rollback, fencing/revocation, full-width data and cancellation while
native I/O is blocked. `just bindings::test` in the bindings shell additionally
qualifies Rust, Node, Java, .NET, Erlang and Elixir through cross-language
service/requester pairs. Node checks its schemas/transport independently. Java
and BEAM exercise malformed/oversized/lost ports and cancellation; .NET proves
bounded admission, await cancellation, asynchronous close and GC cleanup.

## Explicit growing turns

M11 adds the `station_growing_*` family without changing the legacy entry points.
`station_growing_capabilities` reports local library support; it does not grant
access or advertise authority capability. Create a separate opaque growing handle
with `profile: "growing_v3"`, realm/principal/PID/generation, association, finite
transport timeout and explicit `failure_policy: "stop" | "block_input"`.
Principals preserve the public 53-bit range. Missing/legacy profiles reject;
there is no fallback or resource migration. Handles require the same native
stack, bounded I/O pool, serialized access and joined destruction as legacy ones.

1. `station_growing_prepare` advances reads/private framework work only. A
   `pending` event identifies a permit, view-open or turn mutation. Repeated
   preparation preserves it without sending. Export its exact bytes with
   `station_growing_pending` and persist them before calling dispatch.
2. `station_growing_dispatch` makes one attempt. On success, its event includes
   the purpose, input position and receipt in `confirmation`. Unknown outcomes
   retain pending bytes. If response allocation fails after success, the native
   handle retains the confirmed event for a later read; the error remains
   `uncertain`. Record confirmation before advancing another mutation.
3. A `ready` event supplies a local `scope` token plus authenticated input data.
   Pass that token to `apply`, `finish` and `discard`. Finished/discarded/rebuilt
   turns reject stale tokens; the token is tied to its owning handle and grants
   no authority. The host still owns sequential handler dispatch.
4. `finish` freezes success/failure without submission. `discard` drops unsent
   private work without acknowledging or blocking the input. A stop-policy
   failure discards; a block-input failure freezes the native failure proposal.
   Read poisoning survives action rollback and prevents either success or a
   fabricated durable application failure.

`GrowingAction`/`GrowingResult` are generated from the Zig boundary types. They
share basic KV/Table/message implementations with the legacy adapter, add bounded
KV/Table pages and retained source operations, and accept full-width timer
observers. Each page has at most eight entries and an opaque native cursor.
Table row keys/int64 values and correlations cross JSON as decimal strings.
Cursor parsing is canonical, and resuming checks the original source, resource,
revision and Table/schema. Only null continuation means complete. Captured-view
pages exclude private mutations; retained-source pages can accompany private
progress writes, with read dependencies registered by native Station.

Query support requires `query_results: true` in the growing configuration. An
enabled handle owns a bounded 1 MiB Fuze workspace until joined destruction;
disabled handles allocate none. Generated capabilities expose this budget,
8192-byte segments and state/message/operation bounds. Query actions on a disabled
handle reject even if the library advertises support. Registries, supervision
and runtime bindings are not part of this growing foreign slice.

`query_policy` and `query_start` delegate to native `GrowingQuery`. Starting a
query requires an authenticated call and uses the whole four-mutation proposal;
it cannot share initialization or an earlier private mutation. The native state
machine handles capture/publication continuations, receiver credit, fragments
and acknowledgement. Every control turn still passes through the dispatch gate.
Only a verified first `result_complete` reaches the host handler; public adapters
must route it separately from their application payload codec.

`query_completed` returns the verified complete manifest, source/destination,
Table and captured basis, ordered chain and schema. `query_segment` rechecks
completion/current access and returns one owned IPC stream plus ordinal, digest,
row and byte counts. It rejects missing/incomplete evidence and invalid ordinals.
Full-width correlations, query limits and aggregate counts use decimal strings.
IPC bytes remain valid after scope/handle disposal; readers remain scoped and
must reauthorize each access. A local read does not extend retention or confirm
the containing turn's commitment. Consumers decode each IPC stream separately;
concatenation is not the result format. The native port uses the same exports;
public runners and persistence callbacks remain separate M11 work.

`station_growing_arrow_cell` (port `growing_arrow_cell`) provides the optional
native decoder for already-owned segment bytes, preserving full-width cells.
It checks the whole IPC stream within the growing segment bound and has no
resource access; retrieving a segment still requires the scoped, authorized
result reader. The older `station_arrow_cell` retains its finite result bound.
Growing `cancel` actions now return whether a waiting call was closed; `false`
means it was already closed, and neither outcome retracts work accepted by a peer.

`tests/station_growing_abi.py`, included in the binding proof, uses one resident
backend page and disk Ursula. It checks 41 Table rows in six pages, stale scopes
and cursors, full-width values/principals, private stop/read poisoning, control
gates, accepted-response loss and exact recovery from a fresh process after
caller/node/store loss, current revocation and the growing port route. Native
allocation enumeration additionally checks retained confirmation on every failed
response allocation. These proofs qualify this low-level slice, not public SDKs.
The companion `tests/station_query_abi.py` proves six segments/41 rows through
capture, loss/retry and caller/node/store restart, original IPC ownership and
independent PyArrow decoding, complete metadata, native-port parity, disabled
queries, stale scope and revoked result access.
