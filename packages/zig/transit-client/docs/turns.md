# Calling, state views, and uncertain outcomes

[transit-client](../README.md)

## Receiving and committing in Zig

[`Session`](../src/Session.zig) binds a client to a
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

The complete runnable examples are [counter](../../../../examples/counter/README.md) and
[byte log](../../../../examples/byte-log/README.md), each with its own entry point, handler
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

## Classifying a stopped turn

| Observation | Required response |
| --- | --- |
| Timeout, disconnect, unavailable authority | Keep the exact pending proposal; acceptance may already have happened |
| Known original receipt | Use that accepted decision; it is not permission to repeat outputs or effects |
| Stale activation | Stop this activation; a replacement must reconcile against current authority |
| Revoked permission | Stop protected access; revocation does not undo an earlier commit |
| Expired view on a known-uncommitted proposal | Close/release as authorized and choose an explicit new computation policy |
| Expired required resource or retired PID | Permanent lifecycle failure; never initialize an empty replacement under the same PID |
| Capacity refusal | Expose backpressure; retention and cancellation need their own authorization |

The SDK returns errors and retry material; it does not choose a supervision or
business retry policy. Persisting pending proposals across a caller crash needs
an explicit recovery design above this library.

## Durable KV resources

`Client.state(query, key)` implements [state v1](../../../../contracts/STATE_V1.md).
Read `capabilities` before selecting a profile. Resource inspection and value
reads require separate resource grants; a process association grants neither.
Metadata and entries are bounded pages. Follow `next` with the same query/cut;
restart explicitly on `QueryExpired` or `HistoryReclaimed`.

For a state-backed turn, receive the ordered input, obtain any finite-process
permit, and resolve the configured association via `Session.associations()`.
Fetch the resource metadata, then `prepareStateView(delivery, resource, deadline)`.
Submit/reconcile that exact pending request before receiving again: opening a
view consumes a principal sequence. `readStateView(id, key)` reads the captured
revision, even if another authorized turn later changes the resource. Larger
enumerations use `Client.state` with the view ID and cut. Deadlines must fit the
advertised view bound and resource/process lifetimes; authority time decides
acceptance.

`prepareStateCommit(delivery, decision)` binds the returned view identities,
up to four distinct KV mutations in one resource, input progress, outputs and
an effect intent to one signed commit. A null mutation value deletes a key.
The helper preserves legacy inline state without interpreting it. Retain this
`Pending` unchanged after an uncertain response, including its read basis.
Expiry is an explicit rejection; never silently reopen a newer view for an
uncertain commit. `prepareCloseStateView` releases an abandoned, known-uncommitted
view; maintenance and ownership changes also release expired/stale views.

All data and view metadata own their bytes. There is no hidden cache, automatic
transaction retry, background worker or second state authority. The first
profile materializes bounded KV data in the authority and supports only one
writer PID per resource. `just test::state` qualifies the public HTTP boundary.
