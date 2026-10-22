# Public SDK design

Engineering background and historical design. Use [Caller and SDK semantics](../reference/callers.md)
for the current public explanation shared by users, developers and agents.
Consult this record for rationale and proposals; it does not extend a qualified profile.

Use the [language package index](../reference/sdks.md) for installation and native
APIs. This page explains the shared choices those SDKs preserve: durable identity,
owned values, scoped turns, scheduling and uncertainty.

Status: M11 shared public API contracts. The [Python](sdk/PYTHON.md) design is
implemented with typed raw/Station packages, executable counter/query examples,
clean wheel installation and focused lifecycle/data proofs. The
[TypeScript](sdk/TYPESCRIPT.md) design now has corresponding public raw/Station
packages, executable examples, clean tarballs and lifecycle/data proofs.
The [Rust](sdk/RUST.md) raw/Station APIs are implemented with clean crate
consumers, borrowed turns, panic/recovery and optional Arrow ownership proofs.
Ruby's independent raw/Station gems now have clean installation, scoped handlers,
recovery/ownership and original query IPC proofs. Independent
[C](../../sdks/c/transit-client/README.md)/[C++](../../sdks/cpp/transit-client/README.md)
raw clients and Station handlers now have installed artifacts and shared
recovery/ownership/Table/query proofs. Java's independent raw/Station JARs now
qualify bounded futures, typed scoped handlers, exact recovery, retained Tables
and owned query IPC. .NET's independent raw/Station NuGet packages qualify typed
handlers, exact recovery, cancelled awaits, joined native ownership, retained
Tables and owned IPC. Erlang/Elixir raw clients now qualify independent OTP
installation, tagged recovery and supervised caller-loss cleanup. Both BEAM
Station APIs also pass scoped handlers, recovery and Table/query ownership proofs.
The public interoperability ring qualifies every target in both roles; see the
[test guide](../../tests/README.md#public-sdk-interoperability) for its ten pairs and limits.
M11 owns delivery, including public interoperability. The
[M9 adapters](../../bindings/README.md) remain executable low-level interfaces.

The [caller model](CLIENT.md#idiomatic-language-sdks) owns shared guarantees.
This document owns cross-language API decisions; the language pages own native
shapes. Wire layouts remain in `contracts/`, implementation guides beside their
packages, and proof results in the [test guide](../../tests/README.md).
The later [HTTP caller boundary](CLIENT.md#http-connector-callers) links M15's
typed request, outcome and replay guides for each target. Its qualification is
separate from the M11 counter/Table/query baseline.

## Packages and authority

Raw Transit and Station have separate installable public packages. Raw Transit
owns references, credentials, signed operations, receipts, bounded reads and
recovery. M11's typed raw surface covers capability reads, prepared sends and
exact saved-mutation recovery. Broader administration/inspection remains at the
explicit low-level boundary; this is not a typed wrapper for every wire command.
Station adds messages, private turns, Tables and runners. Loading a
package performs no credential discovery, network I/O or worker startup.
Generated ABI/wire declarations stay internal or under an explicit raw interface.

Zig owns canonical encoding, signatures, response validation, sequencing,
framework state transitions, view dependencies and exact retry. Host SDKs own
types, application codecs, handler dispatch, scheduling and packaging. Application
codecs interpret payload bytes; they cannot supply authenticated origins or
replace a recorded reply destination. No SDK is a native-code sandbox.

| Concern | Design decision |
| --- | --- |
| Profile | Require explicit `growing_v3` or a separately supported legacy profile; no fallback or history conversion |
| Native compatibility | Check ABI and operation capabilities before preparing work; check authority capabilities through an explicit authorized read |
| Credentials | Explicit source supplied at open/preparation; no ambient discovery, import-time reads or credentials in diagnostics |
| References | Distinct realm-qualified process/resource types; a reference never grants access or ownership |
| Integers | Validated protocol counters through `2^53 - 1`; application u64 and correlations retain 64 bits |
| Bytes | Python `bytes`, TypeScript copied `Uint8Array`, Rust owned bytes; hex is confined to raw/generated boundaries |
| Mutation identity | Raw preparation takes an explicit principal sequence; the application coordinates a shared principal across handles |
| Backpressure | One active operation per handle and one handler per runner; overlap rejects, with no unbounded SDK queue |
| State growth | Point reads and bounded pages; no complete-resource load before dispatch and no implicit retention policy |

Local native support does not establish a running authority capability. Likewise,
raw v3 support does not establish a growing Station adapter. The implemented
[raw ABI](../../packages/zig/transit-client/docs/bindings.md) already supports v3
operations, capability probing, native operation metadata and opaque retry;
its standalone client port has no Station dependency. The explicit growing Station
ABI now adds gated/scoped turns, bounded KV/Table/retained-source access and
opted-in native query capture/delivery with complete manifests and owned segments;
legacy foreign entry points retain v2. Python and TypeScript use this boundary; the qualification
table below distinguishes shared prerequisites from language-specific work.

## Types, codecs and input dispatch

Each SDK provides `ProcessRef`, `ResourceRef`, `Activation`, `Sequence`,
`Correlation`, typed `Key<T>`, `Codec<T>`, receipt types and owned retry bytes.
`Activation` names the PID, principal and generation obtained by authorized
bootstrap; constructing one does not acquire ownership. Cross-realm destinations
are rejected before staging under the current single-realm profile.

A `Codec<T>` has a stable application type/version, an encoded size bound, and
strict encode/decode operations. The application contract specifies how those
identifiers are represented in its bytes; setting a host-side version property
alone cannot detect a mismatched payload. Do not invent a second generic Station
envelope. Shared application fixtures must precede executable language codecs.
Encoding validates host values too, including Python booleans masquerading as
integers, unsafe JavaScript numbers and overflow. Reject unsupported versions,
unknown tags, trailing/truncated data and oversize payloads before handler use.

The current `STN1` payload budget is 243 bytes; state values have a 256-byte
budget. Application keys contain 1–32 bytes and cannot start with zero. These are
operation/layout limits, not total collection limits. Use native capability
metadata and generated constants; do not maintain divergent wrapper constants.
The application codec may choose a smaller bound. `Key<T>` binds its bytes and
codec once. `find` returns an optional `Found<T>` wrapper, keeping a missing key
distinct from a present nullable value; `require` reports `MissingValue`.

The current growing proposal has four mutation and four output slots, shared
with descriptors, waits and other framework bookkeeping. Page reads return at
most eight entries. Expose remaining per-turn budgets without implying that the
application owns all slots or that total retained state has the same bound.

`Incoming<T>` distinguishes cast, call and authenticated reply, retaining input
position and origin separately from decoded application data. A message tag
called `reply` cannot manufacture a framework reply. Native Station validates
the recorded wait and peer before dispatch; duplicate/closed replies follow its
disposition rules without invoking the handler again. Application code may add
its own expected-peer/correlation check. Timeout, cancellation and query control
frames use shared framework dispatch, not the application message codec.

## Equivalent application and durable calls

All three designs use the same counter application: `Add(u64)`, `Read`,
`Total(u64)` and requester `Start`, under the shared application contract
`counter`, version 1. `TOTAL`, `REQUEST` and `OBSERVED` are typed u64 keys.
Counter initialization writes zero; addition checks overflow; a call carrying
`Read` replies with the current total. The requester handles `Start`, stages a
call, and stores its returned correlation in the same turn. A later authenticated
`Total` reply writes `OBSERVED`. A second `Start` is an explicit application error
for this single-request example. It must not silently issue another call.

The correlation is **derived by Station from the consumed input position**, as
specified by [Station v1](../../contracts/STATION_V1.md#messages-and-origins) and
shared by the [growing turn](../../packages/zig/transit-station/docs/growing.md).
`turn.call` returns it; no public convenience parameter selects a replacement
correlation. There is one call per input. Call identity includes the calling
process and correlation; the durable wait records the destination. The original
constant-correlation sketches are superseded by these designs.

Returning from `call`, or awaiting its local port request, only stages the wait
and output. It returns no remote future. After commitment, lose every handler
object and host, obtain fresh ownership, and resume the reply through a later
input. Initialization runs only while the committed descriptor is absent;
initialization and the first successful input share one proposal.

Call options explicitly select untimed waiting or an absolute deadline and timer
observer. Untimed calls require compatible unlimited lifetimes; native validation
rejects waits beyond process/resource bounds. The examples assume unlimited
lifetimes and select untimed waits. `cancel_call(correlation)` stages the native
wait closure and advisory peer message in a new turn. It does not cancel external
effects or retract accepted work. Waiting evidence remains retained by default.

## Raw operations and exact recovery

The first typed raw slice provides capability/process reads, `prepare_send`,
`recover_send`, and one-attempt dispatch. `PendingSend` owns the immutable native
operation, exposes read-only identity and exports opaque bytes. Preparation
validates/signs without submission; recovery validates that the frozen operation
is a supported send before assigning this type. Recovered sends need no signing
seed. A general `RecoveredMutation` is also needed for runner control/turn
requests; it must preserve their kind rather than masquerading as a send.

Other typed commands and paged reads follow the same boundary. Administrative
commands belong to an explicitly selected administrative surface. A runner does
not receive wider credentials just because its implementation shares a library.
Raw Transit can send arbitrary bytes; Station's cast encoder calls the shared
frame codec before passing bytes to that independent client.

| Observation | Meaning and next action |
| --- | --- |
| `AdmissionReceipt` | A send was admitted; no claim of processing or reply completion |
| `Committed` runner event | This input's state, progress and outputs have a confirmed turn receipt |
| Authenticated reply input | Recorded peer replied; its consumption still needs a turn commit |
| Unknown mutation outcome | Keep exact operation bytes and stop issuing replacement work |
| Definite rejection of an attempt | Preserve exact authority code; after earlier uncertainty, rejection does not prove the earlier attempt was never accepted |
| Failed read | No mutation receipt; invalidate dependent private work without inventing a durable handler-failure marker |
| Lost retry material | Fresh fenced ownership and committed-state reconciliation before recomputation |

For restart recovery: prepare, durably save the opaque export, then dispatch
once. On uncertainty keep that entry. In a fresh host, import it and dispatch the
same identity. Never rebuild signed JSON or allocate a new sequence to retry.
Record a confirmed receipt before retiring the saved entry. Exports contain no
signing seed but may contain payloads and need application data protections.
They prove neither acceptance nor current authorization.

Errors preserve phase, native status and exact authority code. Language mappings
must distinguish unsupported capability/version, invalid input, busy/closed
handles, authority rejection, stale ownership, retired process, unavailable
history, failed reads and uncertain mutations. Allocation/decoding failure after
possible acceptance remains uncertain. A rejection on a later revoked retry
cannot clear an earlier unknown outcome. No generic `retryable` flag authorizes
replacement operations.

## Runner lifecycle and persistence

`RunnerConfig` explicitly supplies the client/native configuration, activation,
association name, read-view deadline policy, finite transport deadline, idle poll
interval, and optional query context. Required options select a failure policy
and recovery mode; there is no implicit default that acknowledges bad input.

The shared machine drives bounded reads, native framework preprocessing, optional
initialization, one handler, proposal freeze and confirmed publication. Private
state helpers, retained-source handles and Table handles expire when their turn
ends. A handler cannot call `commit`, sign requests or extend a captured view.
Concurrent turn operations reject. Saved handler fields and tasks are temporary.

| Policy | Behavior |
| --- | --- |
| `Stop` | On decode/handler failure discard private work and stop; leave the input unconsumed without a failure marker |
| `BlockInput` | Discard private work, then freeze only the native failure proposal; report `Blocked` only after its receipt is confirmed |
| Read failure under either policy | Poison/discard the proposal and stop with the read error; never commit an application-failure marker from incomplete evidence |
| `PersistBeforeDispatch(store)` | Call the application store with exact frozen bytes before every mutation attempt can first be sent |
| `FenceOnRestart` | Keep exact bytes locally while alive; loss of the host requires fresh ownership and reconciliation |

The persistence gate covers permits, opening/closing views, handler commits,
failure proposals and internal framework/query turns. The callback runs outside
native locks with no opportunity for reentrant runner operations. It must finish
successfully before dispatch, and receives owned bytes plus native-validated
identity/purpose. A callback failure leaves the operation unsent and pauses the
runner. There is one unresolved mutation per runner; the store is application
storage, not another execution authority or a queue of runnable handlers.

After a confirmed receipt the store's confirmation callback may durably record
it and retire pending material. If that callback fails, stop and surface both
receipt and recovery material; do not turn a known commit into a rejection or
rerun its handler. Keeping a confirmed operation for exact receipt recovery is
safe. Recovery-store durability and protecting its contents are application
responsibilities, not implied by an in-memory callback returning successfully.

`run`/`next` exposes `Committed`, `Blocked` or `NeedsRecovery`. The last event
ends that run and retains the pending operation; no new handler follows it.
An explicit `reconcile` makes one attempt against those bytes. Native state
decides whether the runner can resume; a lost native host requires recovery of
saved mutations followed by fresh ownership, not reconstruction of private
turn pointers. I/O errors and store failures retain structured phase/evidence.

Local stop stops new dispatch. If observed before freeze, discard the active
private proposal. Once frozen, preserve it; once sent, reconcile or expose its
uncertainty. Close joins owned I/O and does not implicitly finish a handler or
acknowledge an input. Native deadlines bound I/O, not arbitrary user code: a
handler that never returns can prevent graceful shutdown. Document cooperative
handler requirements; killing a bridge/worker invokes the host-loss contract.
No timeout, future cancellation or destructor establishes remote cancellation.

Close/disposal is idempotent, and later use reports `Closed`. Release paths for
operations whose port has already exited must still release local ownership;
they cannot overwrite a dispatch uncertainty with a secondary cleanup error.

## Bounded state, Tables and Arrow

`state.page` and `table.page` return owned bounded pages and explicit cursors.
Only an absent cursor establishes completion; an empty page may still continue.
Turn-view scans exclude private mutations and stay on the same captured source.
They cannot silently renew an expired view or switch revisions. A typed Table
uses the shared schema/key codec and single-resource commit boundary.

`retain`, `open_version` and `release` stage or read through shared native rules.
Only the retained ID and an exported matching cursor may cross handlers; reopen
the source in each new turn. Persist application progress and a continuation
with the same commit. Do not serialize a host iterator or borrowed pointer.

Query integration is explicit. A verified `CompletedResult` carries peer/call
identity, source revisions, schema and complete-manifest evidence. Reading one
segment returns owned original IPC bytes and ordinal/digest metadata, under
current authorization. A segment is not the whole result, and separate IPC
streams cannot simply be concatenated. Expose bounded segment access rather
than a mandatory whole-result allocation. Reopening a durable result reference
revalidates access; local disposal neither acknowledges it nor releases sources.
Manifest metadata and returned bytes are owned; the reader itself remains scoped
to the authorized turn/source and must be reopened for later segment reads.

Optional PyArrow, JavaScript Arrow and Rust Arrow adapters are separate extras or
features. Their versions, integer precision, copy/borrow rules and release paths
need qualification before support is claimed. Core APIs expose IPC without them.
M13 adds a [public Table query client](../../packages/zig/transit-query/README.md)
and runnable growing host for Board and the shell. Its qualified development
profile does not establish production capacity or deployment automation.

## Implementation handoff and qualification

| Shared prerequisite | Required implementation/proof before public release |
| --- | --- |
| Growing Station ABI | Explicit C/port profile, full-width identities, bounded point/page reads, scoped turns and capability rejection implemented and qualified through every target public SDK |
| Dispatch gate | Native `prepare`/`dispatchPending` now separates every mutation, with owned confirmation and growing/legacy recovery evidence; all target persistence/confirmation callbacks and their shared fault proofs pass |
| Abort without failure | Native and foreign scoped `discard`/stop policy preserves earlier unresolved control operations and rejects dropping pending bytes; all target cancellation/stop/join ownership paths are qualified under their documented host rules |
| Typed operation metadata | Implemented native classification and canonical identity through C/port, with owned buffers; public typed operations must use it without decoding retry bytes |
| Reply and input metadata | Preserve authenticated origin, frame kind and native wait validation without application-supplied provenance |
| Application codecs | Shared [counter/query definition](../../examples/station-sdk/README.md) and [fixtures](../../tests/verification/sdk-codecs-v1.json) defined; all target implementations and the ten-edge public language ring pass |
| Growing data adapters | Native page/source/cursor validation and opt-in complete-result manifests/segments implemented; Python/PyArrow, TypeScript/Arrow JavaScript and Rust/Arrow Rust readers are qualified; Ruby, C/C++, Java, .NET, Erlang and Elixir own IPC independently decoded by PyArrow |

The public declarations should first compile/type-check against real packages;
then run the same service/requester against a disk-backed authority. Cover wide
integers, missing versus nullable values, malformed messages, duplicate `Start`,
overflow, initialization and fresh-worker reply recovery. Extend the existing
[shared scenario catalog](../../tests/verification/sdk.json), reusing its admission,
uncertainty, revocation, same-principal, cancellation and post-commit-allocation
obligations rather than creating competing language catalogs.

Add runner-specific failures: turn escape/overlap, failures at every persistence
gate, confirmation-store failure after acceptance, read poisoning, cooperative
shutdown and abrupt host loss. Finally install built artifacts and their explicit
native dependencies into clean consumers outside the repository. The [M11 evidence](../../tests/README.md#public-sdk-interoperability) records these
executed checks and their platform, adapter and cost limits.
