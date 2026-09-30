# Shared Station ABI

`zig build station-abi client-abi transit-station-host` builds the native
libraries and optional port executable. The generated [header](../include/transit_station.h)
and [ABI/schema resource](../abi-v1.json) come from exported Zig signatures and
types. `just bindings::generate` updates host resources; `just bindings::check`
rejects drift. The native artifacts target Linux x86_64. Before use, check the complete generated
`STATION_ABI_DEFINITION` with `station_abi_definition_matches`. A missing export
or zero result rejects the library; the v1 number alone is insufficient.

The host owns its handler and supplies actions; the same Zig GenServer, Table,
registry, supervisor, signing and query code supplies framework semantics. There
are no host-language branches in the authority. [Language adapters](../../../../bindings/README.md)
own scheduling and handles, not durable state. The [port host](../../../../apps/transit-station-host/README.md)
exposes this implementation to runtimes without an in-process native adapter.

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

`station_growing_pending` exports the canonical frozen envelope understood by
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
53-bit ceiling. Each result exposes original finite IPC bytes. `station_growing_arrow_cell`
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

The `station_growing_*` family is the current native v1 turn boundary.
`station_growing_capabilities` reports local library support; it does not grant
access or advertise authority capability. Create an opaque handle
with `profile: "native_v1"`, realm/principal/PID/generation, association, finite
transport timeout and explicit `failure_policy: "stop" | "block_input"`.
Principals preserve the public 53-bit range. Unsupported profiles reject;
there is no fallback or resource migration. Handles require the declared stack, bounded I/O pool, serialized access and
joined destruction.

1. `station_growing_prepare` advances reads/private framework work only. A
   `pending` event identifies a permit, view-open or turn mutation and its
   `pending_input` position. Repeated
   preparation preserves it without sending. Export its exact bytes with
   `station_growing_pending` and persist them before calling dispatch.
2. `station_growing_dispatch` makes one attempt. On success, its event includes
   the purpose, input position and receipt in `confirmation`. Unknown outcomes
   retain pending bytes. If response allocation fails after success, the native
   handle retains the confirmed event for a later read; the error remains
   `uncertain`. `station_growing_confirmation` also re-observes acceptance after
   a foreign host fails to copy or decode an already returned buffer. Match its
   purpose/input against the saved mutation: an older confirmation can remain
   while the next operation is prepared. It never dispatches. Record confirmation
   before advancing another mutation.
3. A `ready` event supplies a local `scope` token plus authenticated input data.
   Pass that token to `apply`, `finish` and `discard`. Finished/discarded/rebuilt
   turns reject stale tokens; the token is tied to its owning handle and grants
   no authority. The host still owns sequential handler dispatch.
4. `finish` freezes success/failure without submission. `discard` drops unsent
   private work without acknowledging or blocking the input. A stop-policy
   failure discards; a block-input failure freezes the native failure proposal.
   Read poisoning survives action rollback and prevents either success or a
   fabricated durable application failure.
   The additive `station_growing_finish_result` form returns an error body with
   the native cause and available authority code; public runners use it to
   distinguish handler failure from a poisoned read. The original status-only
   `finish` remains compatible.

`GrowingAction`/`GrowingResult` are generated from the Zig boundary types. They
delegate to shared native KV/Table/message implementations, including bounded
pages and retained source operations, and accept full-width timer
observers. Each page has at most eight entries and an opaque native cursor.
Table row keys/int64 values and correlations cross JSON as decimal strings.
Cursor parsing is canonical, and resuming checks the original source, resource,
revision and Table/schema. Only null continuation means complete. Captured-view
pages exclude private mutations; retained-source pages can accompany private
progress writes, with read dependencies registered by native Station.
`table_schema` returns the captured schema and basis for live or retained Tables;
`version_table_get` reads a point from the retained basis. `budgets` reports the
remaining native decision slots, including framework work already reserved.
Local capabilities publish Table cell/name byte bounds for host-side validation.

Query support requires `query_results: true` in the growing configuration. An
enabled handle owns a bounded 4 MiB Fuze workspace until joined destruction;
disabled handles allocate none. Generated capabilities expose this budget,
8192-byte segments and state/message/operation bounds. Query actions on a disabled
handle reject even if the library advertises support. Registry actions create,
grant, handle and route scoped names; supervisor actions register and observe
children through the same private turn. Runtime provider reconciliation remains
a separately authorized controller, outside application handler actions.

`query_policy` and `query_start` delegate to native `Query`. Starting a
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
public SDK runners own scheduling and persistence callbacks.

The result uses the current nested Arrow cell layout. Its manifest includes the
source declaration fingerprint as well as resource/revision and logical schema.
Count results use uint64. `station_growing_arrow_cell` (port `growing_arrow_cell`) provides the optional
native decoder for already-owned segment bytes, preserving full-width cells.
It checks the whole IPC stream within the growing segment bound and has no
resource access; retrieving a segment still requires the scoped, authorized
result reader.
Growing `cancel` actions now return whether a waiting call was closed; `false`
means it was already closed, and neither outcome retracts work accepted by a peer.

`tests/station_growing_abi.py`, included in the binding proof, uses one resident
backend page and disk Ursula. It checks 41 Table rows in six pages, stale scopes
and cursors, retained schemas/point reads, remaining mutation budgets, repeated
confirmation observation, full-width values/principals, private stop/read poisoning, control
gates, accepted-response loss and exact recovery from a fresh process after
caller/node/store loss, current revocation and the growing port route. Native
allocation enumeration additionally checks retained confirmation on every failed
response allocation. These proofs qualify this low-level slice, not public SDKs.
The companion `tests/station_query_abi.py` proves six segments/41 rows through
capture, loss/retry and caller/node/store restart, original IPC ownership and
independent PyArrow decoding, complete metadata, native-port parity, disabled
queries, stale scope and revoked result access.

## HTTP and immutable publications

`station_http_codec` is also available as port `http_codec` in local-codec
mode. `prepare` accepts typed request pieces, a finite hex body, resource identity,
namespace, endpoint revision and reconciliation/attempt bounds. Namespace, secret
versions and endpoint revisions use canonical unsigned decimal strings, preserving
all 64 bits. The shared Zig HTTP package validates/render-checks the request and
returns its HTQ1 reference, owned metadata bytes and both Publication specs.
`outcome` decodes HTR1/HTF1; it returns explicit unknown/not-dispatched/rejected
states without inventing a complete reference. Preparation and decoding need no
authority endpoint or credentials and never perform network effects.

Growing capabilities advertise `publications`, `http_requests`, `http_replay`, `http_release`, `http_followup`,
the 65,536-byte finite request profile and 256-byte publication chunks.
`publication_create/begin/append/publish/abandon/retire/collect` delegate to Station
Publication inside the active scoped turn. Host adapters schedule bounded steps;
they do not hash, merge, publish or retry independently. Partial staging remains
private. `http_call` verifies that both exact referenced records are already
published in the current caller resource, then records the normal durable wait
and output. Publish and call in separate turns: publication reads reject private
mutations. Capacity/error rollback, frozen pending envelopes and exact signed
recovery follow the existing growing boundary.

`http_stage` composes those publication steps through `RequestRecord.stage`.
It accepts the exact reference, metadata and body, freezes the namespace's request
identity, and returns `staged:false` after at most one durable upload step.
`staged:true` means both immutable records predate this turn, permitting `http_call`
in the same turn. Fresh owners resume with identical recoverable bytes; changed
identity or retired records reject without consuming a mutation budget. Hosts own
source recovery and continuation scheduling, never a second upload state machine.

`http_release` takes a connector `pid`, capture `resource` and canonical full-width
`exchange` string. It validates and records an HTD1 call under the same scoped
turn, returning its durable correlation. Capture read access is not required to
request disposal of one's hold; the service authenticates the original holder
and current policy. The local codec's `release` emits HTD1 and `released` decodes
HTK1 into resource/exchange identity. Decoding alone authenticates no sender:
the handler must check the reply origin and correlation. HTF1 rejections retain
the existing `outcome` decoder. Replay-reader close does not submit this action.

`http_followup` takes the connector `pid`, capture `resource`, canonical full-width
`parent` string, `reason` (`retry`, `redirect`, `reconcile`, `cancel`) and exact HTQ1
`reference`. As with `http_call`, the shared implementation requires both exact
request records to be published in the current associated resource before it
records a wait/output. It returns a new durable correlation. The local codec's
`followup` action accepts the same fields except `pid` and emits HTU1. Neither
conversion nor submission permits a remote send: the service separately checks
the original caller, terminal parent, current grants, frozen policy and finite
root budget before child admission. Rejections use HTF1, outcomes HTR1.

`station_growing_http_read` (port `growing_http_read`) is separate from scoped
handler actions. `open` accepts a complete reference and replay policy; `next`
accepts the returned opaque local reader ID; `close` disposes that reader. A handle
owns at most one active reader, with an 8 KiB HTTP validator and native cursors.
Reader work is rejected while a handler or pending mutation is active. Each read
returns at most one 256-byte part and rechecks current resource/group access.
The foreign response owns its bytes. Allocation failure restores cursor progress;
a failed protocol/authority read poisons the reader and requires reopening.
Stale IDs cannot access a replacement reader. Destruction releases the local
reader after the host joins native work; it does not release any durable replay
dependency. Only `complete: true` establishes full verified capture, and unknown
outcomes cannot be opened as complete responses. This API has no endpoint, DNS
or secret resolver for external HTTP work.

Generated declarations remain separate from language-native SDKs. Their JSON
schemas derive from these Zig types, with an explicit finite slice bound for host
request arrays. Per-field HTTP validation enforces the stricter header and piece
limits. Existing kernel wire arrays and protocol limits are unchanged.

## Finite RPC calls

`station_grpc_codec` is available as port `grpc_codec`. Its `descriptor` action accepts
local descriptor-set bytes and a method path and returns the shared Zig method
shape, descriptor digest and input/output type names. `prepare` accepts that
method identity, ordered literal-byte/secret-reference metadata and a finite array
of original protobuf messages. It returns GRQ1 plus owned canonical metadata and
GRB1 batch bytes. No application protobuf decoder, reflection, endpoint or secret
resolver is involved. Secret versions, namespaces and endpoint revisions use
canonical full-width decimal strings; authority resource IDs and deadlines use
safe JSON integers. Every input still passes the shared RPC domain validation.

Scoped `grpc_stage`, `grpc_call`, `grpc_followup` and `grpc_release` mirror the
publication and authenticated call boundary above. `grpc_followup` is exclusively
an explicit retry request and has no implicit retry policy or dispatch. It takes
`pid`, capture `resource`, full-width `parent` and a published GRQ1 reference.
Metadata and finite batch publication must precede admission. A growing turn
cannot perform another publication read after staging a call mutation; schedule
additional calls in later turns. Outcome decoding distinguishes observed status
zero (`OK`) from unknown outcome with no status or complete replay reference.

`station_growing_grpc_read` (port `growing_grpc_read`) owns at most one RPC reader
per native handle, independently of its HTTP reader. Both use the same locking,
opaque reader identity, current-policy reads and copy-out rollback implementation.
RPC keeps its bounded directional validator (65,544-byte batch and 8 KiB metadata)
inside the native handle; no history-sized buffer crosses the ABI. Each result
owns one 256-byte part. Completion requires verified directional coverage and the
terminal record. Closing this reader only releases local memory. Durable release
requires an explicit correlated service call, as for HTTP.

The generated schemas and pure native/port fixtures cover binary/Unicode messages,
empty messages, duplicate/binary metadata, full-width identities and malformed
records. Allocation-failure units exercise both protocol readers. Public language
conveniences and installed RPC caller proof results belong to their SDK owners.

## Document owner operations and current-policy reads

The ABI provides `station_document_codec`, scoped `document` actions, and
`station_growing_document_read` (with corresponding port requests). All return
owned buffers; language adapters decode them before releasing the native buffer.
The generated schemas specify the exact host representation. Full-width Document
identities and counters use canonical decimal strings; resource identities retain
the protocol's safe-integer bound. Finite float64 uses little-endian IEEE bytes,
including negative zero, and character values contain one Unicode scalar.

`document.create` fixes explicit quotas. `document.stage` takes the same canonical
change and permanent job ID on every call, performing one bounded preparation,
upload or materialization step. Progress, accepted and duplicate results are
private proposals until the enclosing Station turn commits. Changed bytes under
the same job reject, including after host replacement. Stage never loops to
completion, submits implicitly or stores authoritative job state in a host field.
Checkpoint, explicit merge-window configuration, rejection, retirement and bounded
collection use the same scoped turn gate. Publication and ordinary mutation limits
are unchanged. Authenticate application routing before invoking writer operations;
these primitives do not add a public remote Document service protocol.

Reads are available outside a handler or pending mutation. They use the handle's
principal and current resource permissions independently of execution ownership.
Each path/page names an exact SDR1 accepted revision and the fresh resource cut
where its availability was checked. Cursors bind that reference and sequence
object; empty continuation pages are not EOF. Missing, null, conflict and type
failure remain distinct. No whole Document, retained permission or hidden cursor
lives in the native handle. Resynchronization returns accepted replica/clock facts
without replaying tentative changes. Runner destruction must join in-flight reads,
and local cancellation never retires the durable Document.
