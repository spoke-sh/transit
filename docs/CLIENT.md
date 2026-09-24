# Caller programming model

Status: experimental v2 Zig client and [M7 state-resource API](roadmap/M7.md)
implemented. Station and the language bindings described below are planned for
[M9](roadmap/M9.md). General payload references and migration helpers remain
separate future work.

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
M9 makes client creation through bindings an explicit deliverable. A schema
alone is insufficient: clients must also preserve signing, ownership,
uncertain-operation, and lifetime semantics.

The proposed shared boundary has three parts:

1. Public Transit types and Station-owned message/behavior contracts generate
   language declarations, codecs, ABI declarations and shared fixtures from
   versioned definitions. Generation must fail on drift or unsupported types.
2. A Zig implementation exposes a versioned C ABI for the client and a separate
   Station surface above it. Opaque handles, fixed-width scalars, byte spans,
   explicit status codes and release operations cross that ABI; Zig allocator,
   slice, error-union and runtime internals do not.
3. Thin language adapters own host types, exceptions, scheduling and packaging.
   They share canonical signing, request freezing and session semantics through
   that implementation. Independently implemented wire clients remain possible
   only with the same conformance evidence.

Raw Transit clients do not acquire a Station dependency. Station bindings add
the same sequential behavior and Table interfaces above them. A host application
runs its own handler and submits a proposal; no language bridge moves application
execution into the authority. Host-language binding glue and examples are in
scope even though services and the shared framework remain Zig.

### M9 language targets

The following are proposed integration routes, to be fixed by the first ABI
proof. All targets must ship a usable binding and example in M9; emitted type
declarations alone do not qualify one.

| Target | Binding route and host responsibility |
| --- | --- |
| C/C++ | Versioned C header/library; C++ ownership wrappers over the same ABI |
| Rust | Generated extern declarations and safe owned-handle wrappers |
| Python | CFFI or a small extension over the ABI, with explicit close/context management and Arrow interoperability |
| Node.js | Generated TypeScript surface and Node-API adapter; asynchronous completion must not block the event loop |
| Java | Generated JNI adapter and closeable handles; select and pin the JDK baseline in the milestone |
| .NET | Generated P/Invoke declarations, managed ownership and asynchronous wrappers |
| Elixir/Erlang | Shared OTP-compatible port bridge to the Zig implementation, with wrappers/examples for both languages; no blocking native work on BEAM schedulers |

Select and pin runtime/tool versions and generator dependencies during
implementation. The first required execution matrix is Linux x86_64, matching
the qualified local service profile. Other platforms and public package-registry
distribution need explicit qualification; a successful binding build is not a
claim that every target runtime is deployment-ready. Node.js here is a server-side
client; the existing browser Board SDK remains a separate inspection API.

### Binding guarantees

Specify ABI/protocol version negotiation, buffer ownership, thread affinity,
one-in-flight-operation rules, and shutdown before emitting wrappers. Prefer
pollable completions or a host-owned pump to callbacks from arbitrary native
threads. Blocking work belongs on bounded runtime workers or the port bridge;
the bridge transports calls and is not an authoritative queue or state store.
Every runtime must release handles/batches exactly once and handle shutdown with
operations in flight. Exceptions or language unwinding must not cross the ABI.

PIDs, revisions and sequences preserve their full unsigned 64-bit wire range;
JavaScript numbers and signed host integer defaults cannot narrow it silently.
The client ABI freezes exact signed proposals. Station persists the durable
waiting state needed after host/bridge loss; an in-memory native handle is not
recovery evidence. Cancellation of a local await leaves an uncertain accepted
operation to reconcile under its original identity.

Bindings must expose distinctions between rejection, transport uncertainty,
historical receipt, revoked access, stale ownership, expiry and unavailable
history. Importing a module must not start network work or discover credentials
implicitly. Foreign runtimes do not relax the I/O or authorization boundaries.

For Table results, every target exposes a bounded Arrow IPC reader/byte stream;
native Arrow ownership adapters may additionally use C Data/C Stream where the
host supports them. Do not convert results into JSON rows as the sole API.
[The Table design](TABLES.md#arrow-results-and-durable-replies) defines framing,
result completeness, snapshots and cleanup independently of host-language
garbage collection.

[Arrow interoperability M12](roadmap/M12.md) adds Flight/Flight SQL access and
qualification with existing ADBC drivers. Those are Table query clients, distinct
from these process/behavior bindings. The shared Zig engine remains behind both
surfaces; neither an Arrow C interface nor an ADBC handle grants Transit rights.

Qualification uses shared signing/encoding fixtures, cross-language messages
and replies, exact retries after lost responses, host restart, stale activation,
revocation, finite lifetimes, malformed data and explicit buffer release. Include
integers beyond JavaScript's exact-number range and signed 64-bit range.
Every target must run a small GenServer/caller example and consume the same
Arrow result fixture; retain the Zig caller as the reference program.

Both currently implemented application examples are Zig:
[counter](../examples/counter/README.md) and [byte log](../examples/byte-log/README.md).
They run against the same node; the [caller proof](../tests/README.md#independent-caller-evidence)
checks that separation without introducing another application language.
