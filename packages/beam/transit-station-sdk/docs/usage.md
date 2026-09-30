# Erlang Station usage and recovery

Build from the repository with `nix develop .#bindings -c just bindings::beam-build`.
Install the compiled `transit_client`, `transit_native_client`,
`transit_station_sdk` and `transit_native_station` 0.2.0 application archives from
`.cache/bindings/beam` into one application directory. Set `ERL_LIBS` to that
**installation** directory. No checkout-relative source or native executable path
is required. These are ordinary compiled OTP applications; Hex/Rebar registry
resolution and portable native binaries are not qualified. Native artifacts
require their pinned Nix closure. Load starts no authority access or signing.

Include `transit_station_sdk/include/transit_station_sdk.hrl` with `include_lib`.
Construct the client with `transit_client:config(URL, native_v1)`, the credential
with `transit_client:credential(Realm, Principal, SeedFile)`, and the durable
process reference with `transit_client:process(Realm, Pid)`. A `#transit_service{}`
combines that client, a `#transit_activation{process, generation, credential}`,
association name (default `<<"data">>`) and explicit `query_results` opt-in.
Ownership, grants and association must already exist. Neither startup nor OTP
supervision acquires Transit ownership.

`transit_station_sdk:open(Service, Handler, Context, Codec, Failure, Recovery)`
returns `{ok, Runner}` or `{error, #transit_error{}}`. `Handler` implements
`transit_station_handler`; `Codec` implements `transit_station_codec`.
Handlers return `{ok, NewContext}` or `{error, Reason}`. Context and all BEAM
process fields are temporary. The installed [counter and requester examples](../../../../examples/station-sdk/erlang/README.md)
show complete application code and executable entry points.

`next/1` owns shared native preparation, initialization and sequential dispatch.
It returns `{ok, progress | idle | stopped | #transit_committed{} |
#transit_blocked{} | #transit_needs_recovery{}}` or a typed error. A handler return
only finishes private computation. A committed receipt confirms the proposal's
state mutations, input progress and outputs together; it does not prove peer
processing or an effect result. Do not spin on `idle`; apply application backoff.

## Scoped application operations

`transit_turn:state/1` creates a scoped state helper. `find/2` distinguishes
`missing` from `{found, Value}`; `require/2`, `put/3`, `delete/2` and `page/1,2`
use typed `#transit_key{name, codec}` records. The codec owns application bytes,
version and advertised bound. Decode occurs before initialization for incoming
messages. All codec calls within state operations are guarded against reentry.
A failed read poisons the private turn even if the handler catches its error.
A missing optional value is not a failed read.

`transit_table` provides `schema/2,4`, `create/2`, `open/2`, `get/2`, writes and
bounded `page/1,2`. `get/2` returns `missing` or `{found, #transit_row{}}`;
`null` is a cell value, distinct from a missing row. Table keys and int64 cells
use exact signed Erlang integers. Schema identity and source revision remain
part of the captured basis. `retain/1`, `open_version/2` and `release/2` expose
shared retained-read semantics; a retained source remains read-only and grant
checks still apply.

`cast/4`, `call/5`, `reply/3`, `require_reply/4` and `cancel_call/2` preserve
message/admission, input-derived correlation and advisory cancellation
semantics. A call uses `untimed` or `{until, DeadlineMs, ObserverProcess}`.
Persist its correlation in associated state, close the turn, and resume on a
recorded reply. A waiting BEAM process is not a durable waiter.

Query policies and plans use `transit_query`. `result/2` creates a scoped reader;
`manifest/1` returns complete provenance and `segment/2` returns owned original
IPC, digest and row count. Full-width correlations, counts and application
integers remain exact. Pages, segments, native workspace and operation budgets
are bounded; total retained history is not an implicit in-memory collection.
No BEAM Arrow adapter is selected. Independent PyArrow decodes the original
segments in qualification. Owned binaries and manifest values survive closure;
turn/state/Table/source/result helpers expire with the callback. Calls from a
different BEAM process, overlapping calls and reentry return `busy`.

## Mutation recovery and cleanup

Select `stop` or `block_input` explicitly. A codec/handler failure discards
private changes. `stop` leaves the head unconsumed; `block_input` records a
failure marker through the same mutation gate. A failed authorized read never
becomes a success or a block marker. Errors retain native status/code and
separate uncertainty, stale ownership, revoked access, retirement and history
unavailability. Diagnostics omit payloads and signing material.

Select `fresh_ownership` only when recovery will reacquire a new generation and
reconcile authority state after losing local pending material. Otherwise select
`{persist_before_dispatch, StoreModule, StoreOptions}` implementing
`transit_station_recovery`. `before_dispatch/2` must durably save
`#transit_frozen.bytes` under its opaque identity **before returning `ok`**.
It runs before permit, open-view and commit mutations. Protect these exact signed
bytes as credentials; never log a frozen record or opaque client operation.
Erlang terms have ordinary printable representations, not an automatic redactor.

`confirmed/3` durably records the observed receipt. A persistence/confirmation
failure returns `#transit_needs_recovery{phase, mutation, receipt}`. `next/1`
keeps returning that pause. `reconcile/1` retries the same frozen operation or
retained confirmation; a failed confirmation hook does not rerun the handler or
create another mutation. `evidence/1` and `close/1` return pending material and
the last event. After host loss use the independent client's `recover_mutation/2`
and `dispatch_mutation/2` with saved bytes; no signing seed is required for exact
retry. A current grant is still required.

One coordinator, one owned worker and one native port admit at most one ordinary
operation, with no unbounded queue. Native I/O has a 65-second response deadline;
shutdown acknowledgement/exit has a separate two-second bound. The coordinator
remains schedulable while the worker waits. Killing a caller or cancelling its
local wait does not cancel admitted native work. `stop/1` requests cooperative
stop; `close/1` closes admission, drains admitted work and joins native cleanup,
returning its evidence. A caller that disappears while awaiting close can lose
that returned snapshot: persistence hooks remain the recovery mechanism.
Cleanup never implies durable acknowledgement or remote cancellation.

`child_spec/6` uses a **temporary** supervised child and a 70-second shutdown
budget. `handle/1` obtains a runner from its coordinator PID. Parent shutdown
joins the port. A forced kill, VM loss or expired supervisor budget can leave an
unknown outcome. Explicit reactivation/recovery is required; automatic local
restarts cannot establish authority. BEAM PIDs and durable Transit PIDs are
different types and different lifetimes.

## Compatibility

Public APIs require exact 0.2.0 client/native artifacts, host v1 and the supported
explicit growing profile. Missing/mismatched artifacts fail startup. A native
path override is checked by the same hello/capability handshake. Generated
`priv/contract.json` is internal and regenerated from shared public native types.
Application code uses typed SDK callbacks, records and codecs. The shared native
port owns protocol and Station semantics through the current v1 definition.
Generated action schemas and transport calls remain internal adapter boundaries.
