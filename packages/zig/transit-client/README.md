# transit-client

Zig caller library, exported as `transit_client`. Applications receive ordered
input and committed state, compute their own logic, and submit signed proposals.
The authority validates the protocol without executing application code.

Its package dependencies are [transit-protocol](../transit-protocol/README.md),
re-exported as `protocol`, and optional runtime instrumentation through
[transit-observability](../transit-observability/README.md), re-exported as
`observability`. It does not import the kernel, Ursula, or a provider.
[Client](src/root.zig) owns bounded HTTP exchange; [Session](src/Session.zig)
adds activation-aware receive/prepare/submit operations. This is an experimental
v2 API. For the architectural boundary, read [the caller model](../../../docs/CLIENT.md).

## Receiving and committing in Zig

[`Session`](src/Session.zig) binds a client to a
realm, principal, PID, generation and signing key. The caller obtains that
activation from trusted provisioning; a session cannot grant or renew ownership.
It needs current PID-scoped `inspect` and `execute`, plus `publish` or `effect`
when proposing outputs or effects.

The basic sequence is:

1. `session.receive()` polls a scoped view and returns an owned `Delivery`, or null when no input is
   pending. It includes the input, committed state, state revision and next
   principal sequence. A blocked or stale activation returns an error.
2. If `delivery.needs_permit`, call `prepareBegin(delivery)`, submit that pending
   request, and receive again. Finite processes require this recorded permission
   before starting the turn. Transit enforces the settlement deadline at commit.
3. Compute application state from the delivery. Use `prepareCommit(delivery,
   decision)` with proposed state and any fixed-PID outputs or effect intent.
4. Keep the resulting `Pending` until its outcome is resolved. `pending.submit`
   sends that exact signed request and returns a durable receipt.

The complete runnable examples are [counter](../../../examples/counter/README.md) and
[byte log](../../../examples/byte-log/README.md), each with its own entry point, handler
and run instructions. Both use Session. `just test::callers` launches these exact
binaries; fault injection and adversarial assertions remain under `tests/`.
The counter also supplies the reference deployment workload. Neither example
is a required platform service. There is no application registry or callback
table in the node; spawn's nonzero `code` is an
application tag, separate from runtime binding and workload-image evidence.

A state revision starts at zero and becomes the accepted successful turn's
journal position. `prepareCommit` copies the delivery's revision into
`expected_revision`; Transit rejects a mismatch even if the caller still owns
the activation. Ownership generation and state revision serve different purposes.

## Ownership, retries and memory

One `Client` serves one caller at a time. A principal must serialize mutations,
including across multiple sessions/PIDs: all share its request sequence. Keep
one outstanding mutation per principal until resolved. Session does not coordinate
multiple writers or persist pending requests automatically.

A timeout or dropped connection can follow a successful append. Retry the same
`Pending`; do not invent a new sequence, rerun an external effect, or interpret
transport failure as rejection. Preserve the signed request if recovery across
a caller crash requires resolving that operation. An authorized duplicate returns
its original receipt within the configured retry horizon. A conflict requires
reconciliation against current history; stale ownership requires stopping the
activation. A fresh receive alone is not permission to abandon an uncertain
operation. `Client.last_rejection` exposes a recognized wire error separately
from transport failure; current permission is required even for old receipts.

`Value` owns up to 256 inline bytes. Inputs, state, output data and effect data use
this representation; Transit does not decode application serialization. JSON uses
lowercase hex, including `""` for empty bytes. Callers can encode text, binary,
JSON or another bounded format and own its schema/version. The integer helpers
are convenience encoding for examples, not kernel arithmetic.

Deliveries, views and pending requests own their bytes and need no per-value
`deinit`. `Value.slice()` borrows from that value: keep its owner alive. The client
borrows its configured URL and I/O runtime; those must outlive it. Call
`Client.deinit()` before releasing them. Signing keys are caller-owned secrets.
The fixed representation keeps ownership and response bounds explicit, at the
cost of copying and small payloads. Large body references require a later
retention/dependency contract. HTTP bodies/responses are bounded by 256 KiB;
accepted journal entries by 8 KiB, and checkpoints by 1 MiB.

## Instrumentation

An embedding service can set `Client.observer` to its borrowed telemetry runtime
and `Client.parent_context` to the operation making the call. Each call then
records a separate `transit.client.request` span and propagates `traceparent` to
the configured authority, without changing signed bytes. Both fields default to
null; imports and client construction perform no telemetry I/O. Successful poll
requests use debug logs; failed attempts are warnings. Metrics count every
completed attempt, independently of log filtering/loss.

`last_status` and `last_rejection` describe a completed exchange when available,
not a timeout's server outcome. Mutation failures can remain `uncertain`; a
successful response is a `receipt`, not proof of a newly committed transition.
Instrumentation finishes after cancellation joins, before call state is reused.

## Wire compatibility

The [public contract package](../transit-protocol/README.md) owns the generated
schema, canonical signing rules, and shared vectors for future language bindings.
v2 rejects v1 histories and requests; start a fresh development realm. Station
behaviors, other language bindings, and general payload references remain planned.

## Build and verification

Use the repository's pinned `nix develop` shell. From the repository root:

```sh
(cd packages/zig/transit-client && zig build test)
just test::packages
```

See the [test guide](../../../tests/README.md) for integration evidence and limits.

`just test::callers` exercises the real counter and byte-log programs against the
same authority, including lost receipts, stale owners, malformed responses, and
restart recovery. `just test::service` also covers client request deadlines.

## Inspection

`Client.inspect(query, key)` reads authorized process discovery, current facts,
mailbox, outbox, effects, payload metadata, and filtered retained history. Pages
own their bytes. Keep the resource/PID/cut when following `next`; on `QueryExpired`
or `HistoryReclaimed`, discard assembled pages and refresh with explicit gap
handling. See [inspection v1](../../../contracts/INSPECTION_V1.md).
