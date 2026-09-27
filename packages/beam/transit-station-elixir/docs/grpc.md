# Finite RPC calls and captured replay

Shared Zig owns descriptor validation, immutable request publication, call framing
and transcript verification. Both BEAM APIs support all four RPC shapes using
one finite outgoing batch fixed before dispatch. The descriptor is a local protoc
`FileDescriptorSet`; no remote reflection is performed. Metadata preserves order,
duplicates and binary literals; credentials appear only as versioned references.
Original protobuf bytes are retained, including empty messages.

Use `Transit.Station.Sdk.Grpc` and its `Method`, `Request`, `Prepared`, `Outcome`,
`Rejected`, `Released`, `Part` and `Reader` structs. `Grpc.method(descriptor, path)`
returns a locally bound method; `Grpc.prepare(resource, namespace, request,
messages, options)` returns immutable prepared binaries. Request metadata is an
ordered list of `{name, Grpc.literal(binary) | Grpc.secret(binding, version)}`.
Messages are a list of original protobuf binaries. Options set
`:endpoint_revision`, `:reconcile_before_ms` and `:max_attempts` (default one).

`Grpc.stage(turn, prepared)` contributes one bounded upload step. Commit false
results and arrange another input. Once ready, `Grpc.call(turn, peer, prepared)`
returns a correlation to persist in that same turn. Reconstruct the exact
prepared request after fresh ownership to resume staging. Authenticate the
outer reply with `Turn.require_reply` before `Grpc.decode_reply` interprets it.
Observed status zero differs from nil status/reference on a closed unknown.

`Grpc.open(runner, outcome)` returns `{:ok, reader}`. Each `Reader.read(reader)`
returns `{:ok, {part_or_done, next_reader}}`. Always use the returned token; a
copied old token fails rather than skipping a native part. `Part.data` owns at
most 256 bytes and survives runner close. Check `Reader.complete?`, then
`Reader.close`; close is idempotent on the active runner.

`Grpc.retry(turn, peer, parent, prepared)` submits an explicit linked attempt;
`Grpc.release(turn, peer, resource, exchange)` releases the durable caller hold.
Persist and authenticate their returned correlations. Tagged errors preserve
native uncertainty and policy refusal.

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
