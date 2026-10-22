# Finite RPC calls and captured replay

Shared Zig owns descriptor validation, immutable request publication, call framing
and transcript verification. Both BEAM APIs support all four RPC shapes using
one finite outgoing batch fixed before dispatch. The descriptor is a local protoc
`FileDescriptorSet`; no remote reflection is performed. Metadata preserves order,
duplicates and binary literals; credentials appear only as versioned references.
Original protobuf bytes are retained, including empty messages.

Include `transit_station_sdk.hrl`. `transit_grpc:method(Descriptor, Path)` returns
`{ok, #transit_grpc_method{}}` with the exact path, shape and full descriptor digest.
`transit_grpc:prepare(Resource, Namespace, Request, Messages, Options)` returns
`{ok, #transit_grpc_prepared{}}`. The request record contains a method and ordered
`{Name, {literal, Binary} | {secret, Binding, Version}}` metadata. Messages are a
list of immutable binaries. Options set `endpoint_revision`,
`reconcile_before_ms` and `max_attempts` (default one). Positive full-width
unsigned identities remain Erlang integers.

Inside a callback, `transit_grpc:stage(Turn, Prepared)` contributes one upload
step. Commit false results and arrange another input. Once ready,
`transit_grpc:call(Turn, Peer, Prepared)` returns the correlation to persist in
that same turn. Reconstruct the exact prepared request after fresh ownership to
resume staging. Decode only after authenticating the outer reply with
`transit_turn:require_reply`. `transit_grpc:decode_reply(Realm, Bytes)` returns an
outcome, rejection or released record. Observed status zero differs from
`undefined` status/reference on a closed unknown outcome.

`transit_grpc:open(Runner, Outcome)` returns an opaque reader token.
`transit_grpc:read(Reader)` returns `{ok, {PartOrDone, NextReader}}`.
Always use `NextReader`; a copied old token returns `read_failed` instead of
skipping a native part. Parts own at most 256 binary bytes. `complete/1` reports
validated completion; `close/1` closes locally and is idempotent on the active
runner. Owned binaries survive runner close.

`transit_grpc:retry(Turn, Peer, Parent, Prepared)` requests a linked attempt;
`transit_grpc:release(Turn, Peer, Resource, Exchange)` releases the durable caller
hold. Persist and authenticate both returned correlations.

Each live batch admits at most 64 messages, 16 KiB per message and 64 KiB framed
outgoing data. Canonical metadata is at most 8 KiB and the local descriptor at
most 64 KiB. An empty message differs from no messages. These are active-work
bounds, not retained-call cardinality limits.

Current authorization is rechecked on every replay part. Prefixes are provisional
until completion. Read failure is sticky even after restoring a grant: close and
reopen under current policy. Replay uses no credential resolution or remote I/O.
Pending uncertain mutations and overlapping operations reject. Killing a process
waiting on a read does not cancel native work; runner close joins it. Old tokens
cannot silently advance after a lost wait. HTTP and RPC share this bounded
scheduling/token implementation while their validators remain protocol-specific.

Local close does not release durable history or cancel remote effects. Retry
requires the identical request under the original deadline/attempt budget and an
explicit idempotency policy. Release does not retire or erase capture; duplicate
release remains safe after cleanup without a read grant. The finite worker needs
a fresh `poll` activation for these control calls. See its
[configuration and recovery guide](../../../../apps/transit-station-grpc-worker/README.md).

`just bindings::beam-sdk-test` runs clean Erlang and Elixir installed consumers
through the same real-worker TLS schedule, plus HTTP regressions. It covers
upload recovery, binary/Unicode protobuf, full-width identities, correlated
status zero, current replay revocation, sticky and old-token failures, abandoned
wait/join, explicit retry refusal and disposal before/after cleanup. Shared
fixtures distinguish unknown and validate release/rejection/truncation behavior.
See [proof details](../../../../tests/README.md).

Outcome and rejection values own `diagnostic` after the codec/native buffer is
released. It retains the exact protocol status, exchange identity and inspection
guidance. A completed response does not establish business success or permit a
retry; rejected input does not settle earlier work. Original details absent from
the reply are explicitly unrecorded. See the
[shared SDK diagnostic contract](../../../../docs/handbook/reference/sdks.md#structured-failure-details).

## Original diagnostic evidence

Use `transit_grpc:diagnostic(Runner, Outcome, Kind)` after the runner has no pending
mutation. Select `capture_failure` or `native_effect`; the result is `{ok, DiagnosticMap}` or `{ok, null}`.
Capture evidence is the original retained local failure; native effect evidence
reports the independently recorded effect outcome. Absence does not establish
success. Reads work after exchange retirement while the evidence remains readable.
They require current capture-resource access; native effect reads additionally
require inspection of the connector PID. Permission, stale-cut and integrity
failures remain read errors. These operations do not open a replay cursor,
resolve credentials, dispatch, resume or retry an effect. See the
[shared diagnostic semantics](../../../../docs/handbook/reference/sdks.md#structured-failure-details).
