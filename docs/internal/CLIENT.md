# Caller programming model

Engineering background and historical design. Use [Caller and SDK semantics](../reference/callers.md)
for the current public explanation shared by users, developers and agents.
Consult this record for rationale and proposals; it does not extend a qualified profile.

Use the public client when your application needs to send messages, execute
turns or recover an uncertain operation. Choose a [language SDK](../reference/sdks.md)
or follow the [separate application walkthrough](../guides/applications.md). This
page defines the semantics shared by those interfaces.

Status: experimental v2 Zig client and [M7 state-resource API](roadmap/M7.md)
implemented. [M9](roadmap/M9.md) adds the shared C ABI, generated signatures and
exact-request export/import, with [binding evidence](../../packages/zig/transit-client/docs/bindings.md).
[Station's adapters](../../bindings/README.md) expose the framework to M9's target languages.
[M11](roadmap/M11.md) provides qualified public SDKs over those low-level
bindings; their manual action/turn interfaces remain the current implementation.
General payload references and migration helpers remain
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
Station behaviors build on this client boundary. `Input` exposes position,
opaque value and a versioned authenticated origin. Applications match the expected
source process/output or effect attempt before accepting correlated replies;
external admission authenticates a principal, not a claimed process sender.
See the [public input contract](../../contracts/TRANSIT_V2.md).

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
belong to the [transit-client README](../../packages/zig/transit-client/README.md).

## Associated-state model

[State](STATE.md) provides named associations, versioned
resource reads, and proposed KV mutations. It must be usable by ordinary Transit
callers before Station exists. A turn commits mutations with input progress and
outputs; direct storage writes and independent mutable state stores cannot
substitute for that decision. References grant neither access nor implicit
retention, and reads must declare their revision and coverage.

M7 defines coexistence for inline-state callers and stored histories.
The implemented `transit-client` operations capture bounded read views and freeze
mutation proposals for exact retry. Station builds behavior ergonomics on
that public contract without importing core.

## Inspection clients

[Board](BOARD.md) is the operator/agent inspection client. Its Zig service uses
`transit-client`; the browser and other API consumers use Board's generated
OpenAPI surface. [Inspection v1](../../contracts/INSPECTION_V1.md) adds discovery and
retained-history reads with current authorization, bounded queries, and explicit
coverage. Board has no core/storage dependency. Its generated TypeScript models
and runtime validators form a Board SDK, not a complete Transit execution SDK.

## Language-neutral boundary

The [public protocol package](../../packages/zig/transit-protocol/README.md) owns
wire types, generated schema, canonical signing rules, and shared fixtures.
M9 makes client creation through bindings an explicit deliverable. A schema
alone is insufficient: clients must also preserve signing, ownership,
uncertain-operation, and lifetime semantics.

The binding architecture has three parts:

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

The [M11 SDK layer](#idiomatic-language-sdks) builds typed application APIs over
this boundary. Generated ABI/wire declarations remain separate from public
interfaces designed for each language.

Raw Transit clients do not acquire a Station dependency. Station bindings add
the same sequential behavior and Table interfaces above them. A host application
runs its own handler and submits a proposal; no language bridge moves application
execution into the authority. Host-language binding glue and examples are in
scope even though services and the shared framework remain Zig.

### M9 language targets

The shared ABI proof fixes the following integration routes. All targets must
ship a usable binding and example in M9; emitted type
declarations alone do not qualify one.

| Target | Binding route and host responsibility |
| --- | --- |
| C/C++ | Versioned C header/library; C++ ownership wrappers over the same ABI |
| Rust | Generated extern declarations and safe owned-handle wrappers |
| Python | Generated ABI resource drives `ctypes`, with explicit close/context management and async wrappers |
| Node.js | Generated TypeScript contracts and asynchronous native port adapter |
| Java | Closeable native port adapter and bounded asynchronous scheduling |
| .NET | Generated P/Invoke declarations, managed ownership and asynchronous wrappers |
| Elixir/Erlang | Shared OTP-compatible port bridge to the Zig implementation, with wrappers/examples for both languages; no blocking native work on BEAM schedulers |

Node, Java and BEAM share the versioned
[native port](../../apps/transit-station-host/README.md). This avoids three different
native-runtime ABI integrations while preserving a single framework implementation.
The cost is a child process and bounded local framing; the port has no durable
queue or scheduling authority. C/C++, Rust, Python and .NET use the C ABI directly.
The [binding inventory](../../bindings/README.md) records what is implemented and
qualified; selecting a route is not evidence that its adapter is complete.

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

PIDs, revisions and sequences preserve the protocol's admitted range, currently
bounded by its 53-bit counter ceiling. Arrow int64 values and Station u64
correlations use decimal strings at foreign JSON boundaries; JavaScript numbers
and signed host defaults cannot narrow them silently. A future wider protocol
range requires coordinated codecs and qualification, not just a larger Zig type.
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

[Arrow interoperability M22](roadmap/M22.md) adds Flight/Flight SQL access and
qualification with existing ADBC drivers. Those are Table query clients, distinct
from these process/behavior bindings. The shared Zig engine remains behind both
surfaces; neither an Arrow C interface nor an ADBC handle grants Transit rights.

Qualification uses shared signing/encoding fixtures, cross-language messages
and replies, exact retries after lost responses, host restart, stale activation,
revocation, finite lifetimes, malformed data and explicit buffer release. Include
integers beyond JavaScript's exact-number range and signed 64-bit range.
Every target must run a small GenServer/caller example and consume the same
Arrow result fixture; retain the Zig caller as the reference program.

The [counter](../../examples/counter/README.md), [byte log](../../examples/byte-log/README.md)
and [Station ledger](../../examples/station-ledger/README.md) remain Zig reference
applications. [Binding examples](../../examples/station-bindings/README.md) qualify
host-language callers against the same authority. The
[caller proof](../../tests/README.md#independent-caller-evidence) checks that the node
does not execute application handlers.

## Idiomatic language SDKs

Status: all target public SDKs are qualified in [M11](roadmap/M11.md).
The [SDK design](SDK.md) links concrete Python, TypeScript and Rust API proposals
for services/requesters, raw recovery, runner ownership and packaging. It records
the required shared native changes. Python, TypeScript, Rust, Ruby, C/C++, Java
and .NET now have qualified public raw and Station APIs with installed examples.
Java's JARs and .NET's NuGet packages add bounded asynchronous operations, joined
cleanup and typed scoped handlers. Erlang/Elixir also have independent raw OTP
clients with tagged recovery, supervised ownership and caller-loss/join proofs.
Their Station behaviours, scoped helpers and installed examples also pass the
shared authority schedule. The public interoperability ring qualifies each target
in both roles; the [test guide](../../tests/README.md#public-sdk-interoperability) records its limits.
M9 provides generated declarations and
owned host adapters with real interoperability and recovery evidence. Its public
surface still exposes JSON actions, raw status codes, hex values and manual
turn pumping. Preserve those low-level interfaces for conformance and advanced
use while making normal application code express domain operations directly.

The M11 public SDK targets are **C/C++, Rust, Python, Ruby, Node.js/TypeScript,
Java, .NET and Elixir/Erlang**. Python, TypeScript and Rust establish the first
equivalent API designs. Ruby uses the shared native port with pinned Ruby 3.4.9,
independent client/Station gems and qualified public handler/recovery/data proofs. The historical
[M9 target table](#m9-language-targets) and binding evidence retain their original
scope. [M11's language conventions](roadmap/M11.md#language-conventions) own the
public interface direction for the complete target list.

[M10](roadmap/M10.md) first qualifies the growing-state and verification foundation.
Public SDKs must distinguish working-set and operation budgets from explicit
deployment quotas. They must not encode the legacy total-key/catalog array sizes
as the application's state model. Qualify bounded reads, retained results and
shared-principal sequencing through M10's reusable conformance scenarios.

Generate ABI declarations, wire types, validators and shared fixtures from their
versioned owners. Design the public SDK separately for each language: native
types, errors, resource ownership, handlers and scheduling. The Zig client and
Station implementation retain signing, sequencing, request freezing, framework
transitions and query execution. Host dispatch and convenience APIs cannot add
independent retry, acceptance or recovery rules. Raw Transit remains usable
without depending on Station.

Typed process/resource references and versioned application codecs should make
payload encoding explicit without requiring callers to construct wire envelopes.
Validate decoded data at runtime; preserve full-width numbers and bytes through
the host's appropriate types. References and codecs never grant permission.
Separate caller operations, handler turn capabilities and administrative APIs so
convenience does not imply wider credentials or mutable access.

Define distinct results for admission, committed processing and reply completion.
A recoverable operation object owns exact frozen retry material and exposes
uncertainty without requiring application code to edit signed JSON. A receipt
describes a historical result; reading it still requires current rights. Typed
errors must preserve the existing rejection, uncertainty, fencing, revocation,
retirement and unavailable-history distinctions.

An operation object in worker memory is not durable retry evidence. Provide
opaque export/import for exact requests and document when callers must persist
them before dispatch. If retry material is lost, recover under fresh fenced
ownership and reconcile committed state before recomputing; never infer that
host loss means rejection. Retry exports may contain application data and need
the same access protections as the underlying request.

Language tasks, promises and futures only represent local execution. Durable
waiting state belongs to Station and must be resumable after worker loss.
Cancelling a local await does not retract accepted work; expose durable
cancellation separately under its advisory peer contract. Bound queued work,
native threads/ports and shutdown; hiding a native worker must not introduce
an unbounded application queue or block an event loop. The
[Station runner design](STATION.md#languages-and-bindings) defines the handler
lifetime within those constraints.

Results expose owned Arrow IPC bytes and source/completeness metadata. Optional
host Arrow adapters may add readers or native batches with explicit release
rules; garbage collection and local disposal do not retire durable results or
extend their access lifetime. Qualified adapters must preserve full-width values
and reject incomplete results; JSON rows cannot be the sole interface.

Build installable artifacts for the qualified Linux x86_64 runtime matrix and
test them from clean consumers outside this source tree. Package or resolve
compatible native dependencies explicitly, allow overrides, and report version
or missing-artifact errors clearly. Imports acquire no credentials and start no
work. Public registry publication, additional platforms and foreign worker
deployment qualification remain separate from SDK usability.

## Public Table query callers

M13 adds [transit-query](../../packages/zig/transit-query/README.md), a Zig facade
above the shared Station implementation, consumed by the
[interactive shell](../../apps/transit-cli/README.md) and Board's optional workspace.
It compiles M12 SQL against current authorized Table metadata, freezes signed
submission/cancellation identity and reads verified bounded result segments.
It owns no kernel authority, storage access or independent query semantics.
See the [public contract](../../contracts/PUBLIC_QUERY_V1.md) for admission,
uncertainty, current authorization and deployment limits.

## HTTP connector callers

M15's native bindings compose above Station and
[transit-station-http](../../packages/zig/transit-station-http/README.md). Language
SDKs own typed inputs, callback dispatch, local scheduling and returned bytes;
Zig owns canonical request metadata, publication identity, durable call framing
and replay validation. The [HTTP contract](../../contracts/STATION_HTTP_V1.md) fixes
the initial wire profile. Protocol semantics do not move into individual SDKs.

Preparation returns immutable metadata/body commitments without authority work.
Bounded staging advances through ordinary caller turns; the application supplies
continuation inputs and retains recoverable source bytes until publication.
Reconstruction after fresh ownership must preserve the same namespace, bytes,
endpoint revision and original budget. A successful call returns a correlation
that the application records with state. Authenticate the reply's fixed source
and that correlation before trusting a decoded outcome. Admission rejection,
observed response, closed unknown and not dispatched stay distinct.

Replay owns one bounded cursor per native runner, rechecks current resource
access and exposes provisional parts until validated completion. Returned bytes
are owned. A failed stream requires close/reopen; cancelled or lost local waits
cannot justify silently advancing past undisclosed bytes. BEAM APIs return a new
immutable reader token per read and reject stale tokens. Local disposal joins
owned work but does not release durable caller holds, authorize cleanup, refetch
HTTP data or promise remote cancellation.

Language usage and ownership live beside each SDK:

| Language | HTTP guide |
| --- | --- |
| Python | [Synchronous and asynchronous readers](../../packages/python/transit-station/docs/http.md) |
| TypeScript | [Async reply handlers and owned readers](../../packages/ts/transit-station-sdk/docs/http.md) |
| Rust | [Owned requests and borrowed readers](../../packages/rust/transit-station-sdk/docs/HTTP.md) |
| Ruby | [Frozen values and joined cleanup](../../packages/ruby/transit-station/docs/HTTP.md) |
| C | [Explicit handles and inline owned parts](../../packages/c/transit-station/docs/HTTP.md) |
| C++ | [Reply unions and RAII readers](../../packages/cpp/transit-station-sdk/docs/HTTP.md) |
| Java | [Immutable values and future ownership](../../packages/java/transit-station-sdk/docs/HTTP.md) |
| .NET | [Typed outcomes and cancellable task waits](../../packages/dotnet/transit-station-sdk/docs/HTTP.md) |
| Erlang | [Tagged records and reader tokens](../../packages/beam/transit-station-sdk/docs/http.md) |
| Elixir | [HTTP structs and immutable readers](../../packages/beam/transit-station-elixir/docs/http.md) |

The [M15 proof inventory](../../tests/README.md#m15-connector-work-in-progress)
distinguishes installed-consumer evidence from outstanding connector lifecycle,
deployment and hosted-cost qualification. The current finite worker admits one
root call per provisioned connector PID; its
[admission guide](../../apps/transit-station-http-worker/docs/admission.md) owns the
provisioning and lifetime limits.


## Declarative application host adapter

M23's `transit-station-app` owns complete program validation, native digest
preparation and bounded upload continuation. The TypeScript application adapter
owns browser signing, presentation and task scheduling. It does not reimplement
Station framing, native digest encoding, publication policy or the SQL parser.
One frozen submission and one separately retained reviewed plan survive route
changes; explicit exports support reload recovery without persisting a private
key. A new draft, definition generation or HTTP endpoint cannot settle an older
unknown outcome. Native admission remains distinct from application completion.
See the [operator guide](../../packages/ts/transit-application/docs/operator.md).

## Separately compiled application hosts

[M25](roadmap/M25.md) defines a language-neutral
[installation and bootstrap contract](../../contracts/APPLICATION_INSTALLATION_V1.md)
in `transit_client.Application`. Its first executable consumer is the separately
built [work-item package](../../examples/work-items/docs/local.md). The CLI accepts
application declarations and exports scoped caller connections; it does not
import application handlers. A worker receives public bindings, generates a
fresh ephemeral key, and completes the existing growing ownership handshake.
File delivery and process readiness do not confer native rights.

The public management client validates bounded results and owns decoded response
memory. A CLI mutation is frozen before dispatch; retry preserves its complete
signed identity. Installer, worker, domain operator and inspector are distinct
callers. Domain submissions and migration steps keep their own durable identity,
receipt and committed disposition. A returned installation status does not prove
a domain command completed. The neutral schema and independent signing fixture
are available now; this does not qualify additional language hosts or ABI wrappers.
