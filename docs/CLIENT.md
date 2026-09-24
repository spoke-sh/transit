# Caller programming model

Status: experimental v2 Zig client and [M7 state-resource API](roadmap/M7.md)
implemented. Station, additional language bindings, general payload references,
and migration helpers remain planned.

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
Future Station behaviors build on this client boundary. `Input` exposes position,
opaque value and a versioned authenticated origin. Applications match the expected
source process/output or effect attempt before accepting correlated replies;
external admission authenticates a principal, not a claimed process sender.
See the [public input contract](../contracts/TRANSIT_V2.md).

## One caller turn

A caller receives committed state and the next ordered input, obtains any
required finite-lifetime permit, computes its application decision, and submits
state plus outputs/effects in one proposal. Input progress, state, and committed
outputs become durable together. Ownership generation fences executors; state
revision fences decisions based on old state. Neither is application identity.

Uncertain submissions must retain the same signed request until reconciled.
A timeout cannot establish rejection, authorize a new sequence, or justify
repeating an external effect. Current permission is required even when reading
a historical receipt. Concrete retry, sequencing, byte ownership, and API rules
belong to the [transit-client README](../packages/zig/transit-client/README.md).

## Associated-state model

[State](STATE.md) provides named associations, versioned
resource reads, and proposed KV mutations. It must be usable by ordinary Transit
callers before Station exists. A turn commits mutations with input progress and
outputs; direct storage writes and independent mutable state stores cannot
substitute for that decision. References grant neither access nor implicit
retention, and reads must declare their revision and coverage.

M7 defines coexistence for inline-state callers and stored histories.
The implemented `transit-client` operations capture bounded read views and freeze
mutation proposals for exact retry. Station will build behavior ergonomics on
that public contract without importing core.

## Inspection clients

[Board](BOARD.md) is the operator/agent inspection client. Its Zig service uses
`transit-client`; the browser and other API consumers use Board's generated
OpenAPI surface. [Inspection v1](../contracts/INSPECTION_V1.md) adds discovery and
retained-history reads with current authorization, bounded queries, and explicit
coverage. Board has no core/storage dependency. Its generated TypeScript models
and runtime validators form a Board SDK, not a complete Transit execution SDK.

## Language-neutral boundary

The [public protocol package](../packages/zig/transit-protocol/README.md) owns
wire types, generated schema, canonical signing rules, and shared fixtures.
That resource should support future SDK generation without coupling callers to
kernel internals. A schema alone is insufficient: clients must also preserve
signing, ownership, uncertain-operation, and lifetime semantics.

Both current application examples are Zig:
[counter](../examples/counter/README.md) and [byte log](../examples/byte-log/README.md).
They run against the same node; the [caller proof](../tests/README.md#independent-caller-evidence)
checks that separation without introducing another application language.
