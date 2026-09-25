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
qualifies Rust, Node and Java through cross-language service/requester pairs.
Node also checks its schemas/transport independently. .NET and BEAM remain work
in progress; the complete language/failure matrix remains M9 work.
