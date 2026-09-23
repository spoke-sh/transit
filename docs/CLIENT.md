# Programming through the Transit client

Status: implemented experimental v2 client and binding resource. Current calling
programs are Zig. Station, other language bindings, general payload references
and application migration helpers remain future work.

## The caller boundary

A caller reads its committed state and next ordered input, computes application
logic, and proposes a turn. Transit validates identity, grants, activation,
input order, state revision, lifetime and output/effect authority. One accepted
record commits state, input progress and proposed outputs/effects atomically.
The node never imports or runs application code. Recovery applies recorded state
and protocol transitions without invoking the application or redispatching effects.

An authorized caller can propose incorrect business state or falsely report a
handler failure. Protocol validation cannot establish honest computation.
Application tests own business correctness; deployment isolation restricts I/O
and credentials. A failure report must leave state unchanged and contain no
outputs/effects. It blocks the input and fences ownership, without proving why
the application failed. See [conformance](CONFORMANCE.md).

`transit-protocol` defines public commands, signatures, views, error codes and
provider-neutral evidence. Both kernel and client depend on it. `transit-client`
has no kernel, Ursula or deployment-provider implementation dependency. Its
explicit process view excludes the kernel's internal journal scan cursor.
Future Station behaviors build on this client boundary.

## Receiving and committing in Zig

[`Session`](../packages/zig/transit-client/src/Session.zig) binds a client to a
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

The complete executable example is the
[Zig caller proof](../tests/caller.zig), independently built with either
[decimal accumulation](../examples/accumulator.zig) or
[byte concatenation](../examples/byte_log.zig). The deployed
[counter worker](../apps/transit-worker/main.zig) also uses Session. There is no
application registry or callback table in the node; spawn's nonzero `code` is an
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

## Shared resource for future bindings

[`transit-v2.schema.json`](../contracts/transit-v2.schema.json) is generated from
the exact public Zig types. It includes requests, response views, receipts,
errors, defaults, field order, integer ranges, permission bits, routes and signing
metadata. Run `just generate-contract` after a public change and review the
result; `just check-contract` fails on drift. No hand-maintained parallel wire
schema is needed.

A future generator can use this resource to emit types and codecs. Interoperable
clients must also implement canonical signing and protocol semantics; JSON Schema
alone does not provide a correct SDK. Defaults and nulls are included in signed
canonical JSON, fields follow declaration order, and integers require lossless
handling over the documented ranges. Unknown/duplicate fields and noncanonical
hex values are rejected. Shared
[request vectors](../packages/zig/transit-protocol/src/fixtures/requests-v2.json)
and [sequence traces](../packages/zig/transit-protocol/src/fixtures/sequences-v2.json)
provide conformance input. Existing Python is infrastructure/fault orchestration
and an independent fixture check; both application callers remain Zig.

v2 deliberately rejects v1 requests and stored histories. Use a new development
realm; there is no migration implementation. See the
[protocol profile](../contracts/TRANSIT_V2.md) and
[service profile](../contracts/SERVICE_V2.md) for the full current contract.
