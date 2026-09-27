# Validation and milestone evidence

## M18 work in progress

Fuze's first four unified-model tests and the independent Python fixture check
pass. They bind the same plan to KV/Table/Document source-kind evidence, preserve
missing/null/type-error/value/conflict distinctions and ordered assignment IDs,
reject type/schema/projection mismatches, and round-trip full-width integers,
negative zero, binary, Unicode and a 537-byte plan. Every strict prefix of the
canonical plans rejects, as do trailing bytes. This is pure model/codec evidence,
not source-adapter, durable execution or SDK qualification.

`just test::arrow` also passes the new nested IPC profile through independent
PyArrow: six primitive types, all five cell states, full-width conflict IDs,
Unicode, binary and negative zero. A six-column/five-row stream is **7072 bytes**;
the same empty schema is **6088 bytes**. Independent evaluation checks filter,
limit, count and sum over 70 input rows with every page width from one to eight,
including the exact 167-byte restart checkpoint. Component tests reject changed
source evidence, cancellation, invalid progress and cross-page checked overflow.
Arrow encoding uses a **4 MiB fixed workspace / 64 KiB output limit**; allocation
or output exhaustion fails without a result. This remains pure engine evidence;
it does not establish durable capture or current source authorization.

`Unified.Inspect` additionally passes independent PyArrow-produced streams,
including empty results, all six types and the five states. Thirteen adversarial
streams reject unknown states, wrong kinds, hidden values/alternatives, invalid
conflict cardinality/order/IDs, missing alternatives, NaN, oversized text, nested
nullability violations and a renamed schema. Owned decoded values survive
overwriting the Arrow workspace. The original Table v1 Arrow fixtures still pass.

The `transit-query` adapter component tests also pass canonical `UQS2` source
fixtures and explicit KV decoder checks. A 38-record prefix crosses multiple
pages with a typed malformed-value error; a 19-row Table retains its old cut
across a replacement. Document pages preserve missing/null/type-error/conflict,
read nested full-width values and Unicode text, expand twelve ordered list
items with stable identities, and reject text-budget exhaustion. Retained bytes
cannot bypass current read denial, a newer merge-window floor or retirement.
This in-memory evidence does not qualify durable query capture/result access.

V2 bundle fixtures independently bind all three sources, explicit work budgets
and larger plans to Publication references. Current reference reads reject
before/during/after-copy denial and retirement, including empty completion.
The source capture component schedule passes for KV (37 rows), Table (12 rows)
and accepted Document list expansion (12 rows) through actual `GrowingTurn`
retained-reader APIs backed by a test map. It checks discarded-proposal
recomputation, live-source updates after retention, original replies, complete
manifest/segment coverage, pin release, older continuations, policy denial,
explicit cancellation, budget failure and bounded cleanup after request denial.
Every private turn retains the existing four-mutation limit. `just check` passes
with these tests. This is in-memory state-machine evidence, not a signed service,
disk, worker/node recovery, public SDK or returned-prefix authorization proof.

The subsequent `UnifiedResult` component tests read actual captured manifests and
nested Arrow for all three sources, reject current source/request access denial
after a returned prefix, and verify complete ordered coverage. A KV schedule also
injects denial at the first, middle and final current-read boundary, changes the
policy after completion, and rejects a forged row cursor or original correlation.
Admission rejects a different Publication publisher before retaining a source.
`just check` passes; these use the same in-memory reader fixtures and do not
replace the remaining signed service/deployment schedules.

The v2 upload component fixture submits a 4 KiB predicate using at most 145-byte
command payloads, retries each part, rejects conflicting bytes/identities and
premature seal, and preserves one original call on duplicate submission. Partial
abandonment holds admission until bounded cleanup releases quota. Independent
Python fixtures cover every command and full-width namespace/status encoding.
Behavior cases qualify configured-principal ingress, malformed-command disposition,
restart-configuration refusal and original-route source closure after request
access denial. These are component checks; actual daemon/SDK qualification remains.

The shared native `QueryCodec` additionally passes **28 independent library/port
cases** in `tests/unified_codec.py`: the three canonical source/bundle fixtures,
schema/version/limit rejection, and PyArrow-produced empty/full nested streams
with all six primitive types and five states. Owned output preserves full-width
integers and conflict IDs, negative-zero bits, Unicode and binary. The standalone
binding unit tests and generated-schema checks pass. This is local codec evidence;
the language SDK and signed lifecycle schedules remain separate obligations.

The signed **KV and Table** daemon schedules now pass over disk Ursula with eight
resident authority pages: each returns **41 rows / six segments / 13,584 Arrow
bytes**, taking **371.42 seconds (KV)** and **416.99 seconds (Table)**, excluding
compilation. The finite KV request is 587 bytes. The actual requester,
source and courier recover a lost upload receipt using identical signed bytes;
the source is killed after committing an unpublished segment candidate. The node
and disk store then restart, stale activation reuse rejects, and freshly fenced
workers publish the complete original result. Independent PyArrow verifies every
row. Revocation after the first returned page denies continuation without moving
the cursor; restoration permits verification of complete coverage. The source pin
is released. `just check` also passes. This is local disk evidence with an
default 64 MiB hot-store fixture without cold offload, not a bounded growing-storage, SDK, Compose, Substrate or
hosted CI qualification. The Document schedule remains in progress.

The extended KV schedule also passes through the standalone query ABI and native
port in **430.97 seconds**, with the same 41 rows/six segments/13,584 bytes. A
native caller persists the prepared command before a lost upload response; a
restarted Zig caller resumes those exact bytes. Native and port readers survive
the service restart, reject access after the actual returned prefix, and alternate
pages over one verified cursor. Standalone ABI tests additionally reject invalid
local envelopes before dispatch and preserve uncertainty on a transport failure.
This qualifies the shared boundary, not the individual language SDK conveniences.

## M17 qualification

The standalone Station suite passes **42 tests in 538 ms** with **18 MiB test
process peak RSS**. Immutable-index cases cover 1024-key permutations, retained
roots, ordered continuation, corruption, failed path copying and current read
denial, including on a cache hit. Its fixed eight-node cache stores verified
bytes and reopens publication descriptors under current policy before use.
The Document package passes **18 tests in 1 second** with **17 MiB peak RSS**,
including concurrent merge permutations, Unicode text, private-turn recovery,
finite/unlimited checkpoints and reconstruction from a checkpoint plus accepted
tail. These RSS figures include the tests' in-memory reference stores.

`just test::document` passes over disk Ursula with an **8 MiB hot-store limit**.
The four phases take **609.631 seconds** excluding compilation. It kills the
actual worker three times during candidate/checkpoint publication, restarts the
node and store, rejects stale owners and recovers exact signed retries at change
acceptance, checkpoint publication, cleanup and node checkpoint boundaries.
Final acceptance still fits four mutations including framework state and emits
exactly one acceptance output. The final recovery uses **one resident authority
page**. Current-policy reads through a separate read-only principal preserve
exact old snapshots, enforce revocation after a returned prefix and reject
closed history, stale epochs and permanent retirement. Bounded cleanup retains
permanent ledgers. The run records 361 turns, 8,984 resource reads and 396 cold
objects / 35,169,506 bytes. This is a local measurement, not a hosted CI budget.

`just check` validates the independent Python-generated SDC1/SDR1 change and
reference fixtures, including full-width integers, negative zero, binary and
Unicode. The same fixtures pass through `station_document_codec` in the real native
library and port host, including invalid/truncated/canonical-identity checks.
`just bindings::generate` and `just bindings::build` pass, and `just check` checks
all generated declarations against the public Zig types. Public SDK and application-surface evidence appears below; the disk proof
alone does not establish those surfaces.

`just bindings::document-native` passes in **181.23 seconds** over disk Ursula.
It uses 140 bounded scoped turns through the real native library and port host,
replaces the host mid-upload with fresh ownership, refuses changed job content
without consuming private mutation budget, preserves old accepted values across
new resource cuts, and exposes conflicts/text through a separate read-only
principal. It rejects reads after prefix revocation and Document retirement.
The bridge's eight component tests pass in **15 ms / 8 MiB peak RSS**; `just check`
also passes after generated schema/native additions. Public SDK evidence follows
separately; no remote Document service protocol is claimed by this bridge proof.

`just bindings::document-python` passes the installed public Python API in
**224.26 seconds**, including clean wheel installation. Independent change/Unicode/
full-width/reference fixtures round-trip through public types. Its 139 scoped
turns cover an empty checkpoint, host replacement during upload, exact duplicates,
a disconnected peer edit, old accepted reads through a separate non-executing
principal, prefix revocation, conflict/text visibility, resynchronization and
permanent retirement. Asynchronous cancellation followed by runner close joins
native reads; escaped owner objects reject. Strict mypy passes all 20 public SDK
and example modules. The installed Node schedule also passes in **222.85 seconds**, including clean
tarball installation and the same 139-turn/read-only-consumer schedule. Additional
Node tests reject dropped Document operations after native completion; typed
construction copies inputs before awaiting and prepared byte getters return
copies. Vite+ formatting/lint and strict TypeScript pass.

`just bindings::document-ruby` and the installed Ruby consumer pass the same
schedule in **226.06 seconds** with clean gem installation. Frozen owned values
round-trip full-width integers, negative zero, binary and Unicode; invalid UTF-8
and escaped turn owners reject. Reads use the runner's serialized worker, and
close joins an outstanding read before destruction. `just check` passes after
the Ruby additions.

`just bindings::document-rust` and the installed Rust consumer pass in **253.21
seconds**, including clean crate compilation and the same 139-turn schedule.
Compiler rejection cases prevent a Document owner from escaping its turn and
prevent a reader from overlapping runner mutation. Full-width values, Unicode,
retained references and post-retirement reads use the shared fixtures. Threaded
reads are joined before disposal; arbitrary thread cancellation is not claimed.
Rust formatting and source checks pass.

The installed C11 and C++17 Document consumers pass in **225.84 seconds** and
**235.01 seconds**, respectively. C callbacks compile separately with the C11
compiler; C++ uses variant values and scoped RAII owners/readers. Both execute
139 committed turns, exact change/reference fixtures, host replacement, independent
reads, preserved conflicts/text, prefix revocation and permanent retirement.
Escaped owners reject, readers fail closed after runner destruction, and copied
results remain owned. Threaded reads are joined before disposal. The root
`just check` also passes after rebasing onto `origin/main` at `145c380`.

The installed Java 21 Document consumer passes in **244.38 seconds**, including
clean JAR installation and compilation with `-Xlint:all -Werror`. The 139-turn
schedule preserves full-width values, negative zero, immutable bytes, Unicode
scalar positions, exact older references and current read authority across host
loss. Invalid surrogates and expired owners reject. A cancelled read future is
followed by joined runner close, and later reader use fails closed. The generated
host schema validates native response shapes before typed materialization.

The installed .NET 8 Document consumer passes in **223.35 seconds**, including
clean NuGet restore and compilation with zero warnings. It executes the shared
139-turn authority/recovery schedule, verifies immutable operation/value buffers,
full-width numbers, Unicode scalar text, original references and conflict states.
Cancelling an admitted read followed by asynchronous disposal joins native work;
readers fail closed afterward. Invalid surrogate strings and escaped owners reject.

The installed Erlang and Elixir Document consumers pass in **220.99 seconds**
and **224.03 seconds**, respectively, completing this installed API schedule for
all ten M11 language targets. Both execute the same 139-turn recovery/authority
schedule, independent canonical fixtures, full-width values, Unicode text,
conflicts, retained references, prefix revocation and retirement. Immutable
records/structs use the shared Zig semantics; expired callback owners reject.
Reads use the existing serialized BEAM worker and close rejects later calls.
The test joins a separately spawned read before closing; it does not inject
native cancellation or claim BEAM process death cancels remote work.

The Document package now passes **25 tests in 1 second / 17 MiB peak RSS** after
adding authenticated remote calls. Independent Python fixtures cover SDQ1,
SDT1, SDO1 and SDW1, including full-width IDs and exact frame sizes. Seven new
component cases reject caller/replica impersonation, digest substitution, changed
policy, access loss after a verified chunk, retired publications and replacement
PIDs. They reconstruct every private step, preserve the original reply route,
atomically reject missing dependencies and roll back final acceptance when the
reply budget is exhausted. Caller tests preserve peer/correlation and reject
spoofed or conflicting outcomes. These in-memory component tests alone do not
qualify remote disk recovery or deployment. The root `just check` passed
after completion of all ten installed SDK APIs.

`just examples::document` (also `just test::document-remote`) passes the real
Zig writer and two independent editor binaries in **571.4 seconds** over disk
Ursula with an **8 MiB hot-store limit**. It verifies disconnected/reordered
structured and Unicode text edits, explicit conflicts/resolution, duplicates,
one writer SIGKILL during candidate publication, node/store restart, denied
request access followed by fresh-owner recovery, exact signed acceptance retry,
finite-window resynchronization and permanent retirement. The run records 421
writer turn attempts, a four-mutation maximum, 642 cold objects and 64,766,910
cold bytes. It also refuses reuse of a completed activation marker. Caller and
writer PID-scoped inspection requires optional cross-resource associations plus
separate read grants; the proof does not broaden them to realm execution rights.
The Document tasks are registered as focused verification; their hosted CI
cost has not been measured.

The Document component suite now passes **27 tests in 1 second / 17 MiB peak
RSS**. Bounded metadata pages count accepted registers, assignment IDs and
conflicts without returning application values. Tests cover an eight-record
boundary, exact older snapshots, invalid cursors, revocation between pages and
permanent retirement. A separate regression ensures explicit policy rejection
of an admitted job closes it without disclosing an accepted-state basis. These
metadata readers are the library handoff for Board. `just check` passes with the worker and these library additions.

`just examples::document-compose` passes in **208.78 seconds**, including cached
static builds, with two separately credentialed editors and a fenced writer.
It repeats the original caller after fresh ownership, resumes an unpublished
candidate after node/store loss, merges reversed structured/Unicode changes,
resolves conflicts, recognizes duplicates, resynchronizes after a finite checkpoint
window and refuses changes after retirement. The client network cannot connect
to Ursula, MinIO or external TCP. The run records **542 cold objects /
63,005,309 bytes**, using **8 MiB hot storage and 8 MiB cold cache**. The first
no-cold-tier attempt exhausted the 512 MiB Ursula container; raising that limit
was not the recovery. The chart now supports a separately created configuration
Secret without copying credentials into Helm values or ConfigMaps; its deployment
render/lint tests pass. The root `just check` also passes. These are local
measurements; they do not establish hosted CI cost.

`just transit-board::document-browser` passes the complete local two-editor
schedule in **596.76 seconds**, including its real Chromium test (**12.0 seconds**).
The generated API/model and UI show exact accepted identity/revisions, five
retained registers, one conflict and six assignments without application values.
The proof verifies a stale cut, an actual metadata continuation, denial of that
continuation after revocation, browser clearing, restored access, the finite
history floor and retirement metadata. It records **621 cold objects /
63,935,059 bytes** under the same 8 MiB hot limit, plus writer SIGKILL,
node/store restart and exact acceptance retry. Counts include retained text
character registers, not just application field names. Component API tests,
strict frontend checks and all nine frontend unit tests pass.

`just examples::document-reference` passes in **497.08 seconds**, including cached
builds. Two editors execute as independent Substrate/gVisor activations with
fresh public registrations and exact operator-recorded ownership. The trusted
writer runs in a separate confined Kubernetes pod. The schedule kills an editor
worker, recovers the original call, interrupts an unpublished candidate with
node/store loss, and completes conflict resolution, duplicate handling, finite
window resynchronization and retirement. It records **610 cold objects /
61,575,930 bytes**, with **8 MiB hot storage and 8 MiB cache**. Isolation probes
deny direct storage, provider/control APIs and external TCP while permitting
Transit. The proof owns and removes its namespace and atespace.

Two failed reference attempts exposed a replacement-order race and intermittent
five-second writer read timeouts at different operations. The successful schedule
holds replacements until Ursula is ready and addresses the trusted writer's
already-allowed fixed Service IP. This removes per-request writer DNS resolution;
it does not qualify arbitrary DNS failures or change client timeout budgets.
The manual restart used during diagnosis is excluded from the passing evidence.
This is cold restart against retained disk/object data, not disk-loss recovery,
automatic growing provider reconciliation or hosted CI qualification.

## M16 finite connector qualification

`just test::unit` runs the new RPC request codec against a Python-generated
GRQ1/GRB1 fixture with independent Publication digest computation. It covers
original protobuf bytes, Unicode, duplicate/binary metadata, empty messages,
full-width references and canonical parsing; it is not a durable RPC proof.

The shared `PublicationUpload` helper now stages HTTP's two immutable request
records with the same frozen identity and one bounded operation per turn.
Units cover partial upload, changed content/identity, occupied namespace refusal
and private-decision rollback. The unchanged HTTP worker corpus passed after
this extraction in **483.14 seconds**, with sixteen sends, eight applications,
two cancellation requests and 1,066 cold objects / 116,710,006 bytes under the
8 MiB hot limit. These local timings do not establish hosted CI cost.

HTTP and RPC now share authenticated admission/routing/disposal and the public
Transit worker driver. The unchanged HTTP recovery corpus passed after both
extractions in **491.58 seconds**, with sixteen sends, eight applications, two
cancellation requests and 1,025 cold objects / 114,036,242 bytes under 8 MiB hot
storage. This is the shared-component regression.

The installed C11 and C++17 RPC consumers additionally pass this shared SDK
schedule in **69.24** and **74.66 seconds** respectively, including isolated
installation/compilation. `just bindings::c-sdk-test` runs both protocol schedules.
C explicitly preserves status presence; C++ uses an optional status and move-only
readers. Both authenticate control replies and join a delayed replay read.

Java and .NET installed RPC schedules pass in **75.53** and **71.06 seconds**,
including clean JAR/NuGet consumer compilation. Both additionally execute the
independent status-zero/unknown/rejection/release fixtures and truncated-outcome
checks. Their public cancellation views invalidate the reader while runner close
joins underlying native work. These are local measurements, not hosted budgets.

Erlang and Elixir RPC schedules pass in **68.08** and **70.56 seconds**, including
clean OTP consumer setup. Both use the shared runner's bounded per-protocol token
state: stale copies cannot skip undisclosed parts, failed readers cannot resume,
and runner close joins work after killing its waiting process. Shared fixtures
preserve observed zero versus unknown and reject truncated replies. Every M11
language now qualifies the finite RPC caller/replay/disposal surface. The unchanged
Erlang and Elixir HTTP schedules pass with the shared reader in **68.26** and
**68.48 seconds**. `just check` also passes after all ten SDK extensions.

The Zig HTTP caller now uses the shared `Exchange.Caller` for bounded ticks,
request publication, durable correlation and authenticated reply storage. Its
unchanged local application/restart/replay proof passes in **27.05 seconds** with
exactly one network send. Protocol request/replay validators stay in the adapters.

The Zig RPC caller now passes local (**35.05 seconds**), fresh-key bootstrap
(**36.80 seconds**), Compose (**138.86 seconds**) and reference placement
(**364.86 seconds**) schedules, each with exactly one RPC and 54 response bytes.
The reference task completed owned-resource cleanup after caller worker loss,
fresh registration/ownership, node/store restart and replay with the peer stopped
and credential deleted. Caller/effect network and file isolation use the shared
[operator placement](../examples/exchange/README.md); the default installation is
untouched. HTTP regressions through the shared placement pass locally in **26.97**
and in Compose in **105.58 seconds**. Container timings include changed-image
preparation and concurrent proof load. These are local measurements, not hosted
CI budgets or automatic growing runtime binding/supervision evidence.

`just transit-board::grpc-browser` passes the real RPC capture/API/browser
schedule in **375.54 seconds** excluding compilation (the browser portion takes
**11.7 seconds**). It checks all four shapes, source-bound descriptor/member
metadata, status zero, half-close and directional counts, immutable inspection,
current read revocation and browser clearing. Generated and handwritten runtime
validators reject private fields, narrowed identities and inconsistent evidence.
The unchanged worker recovery tail retains nine sends/eight applications and
691 cold objects / 67,103,930 bytes under the 8 MiB hot limit. Board reports
protocol evidence only; it loads no protobuf bodies or credential/routing values.
`just check` passes with eight frontend boundary tests and generated contracts.

`just test::grpc-faults` passes in **184.48 seconds** excluding compilation.
It kills the actual worker during request preparation, immediately after dispatch
commits but before network I/O, after capture completion, and after observation
commits. Every recovery restarts node and disk store. Preparation resumes; an
authorized attempt with no recorded response closes unknown without sending;
complete/observed capture settles without another send. Current effect permission
is revoked while dispatch waits at ingress. A blocked peer does not prevent work
cutoff, explicit closure, forged-executor rejection, pending-effect cancellation
or permanent retirement. Five RPCs/five applications retain 349 cold objects /
34,224,103 bytes under the same 8 MiB hot bound. The test does not promise remote
cancellation after already authorized work.

`just bindings::grpc-faults` adds actual public caller schedules. The installed
Python consumer passes committed-reply worker loss and node/store restart before
delivery in **71.60 seconds**, then the ordinary read/disposal checks. Caller
retirement after dispatch passes in **58.22 seconds**: one authorized RPC finishes,
its result keeps the original retired destination across restart, a replacement
PID receives nothing, and explicit controller disposal reclaims the capture.
Neither case implicitly repeats the RPC. Other languages run the common SDK
ownership schedule; these two additional failure schedules use the Python caller
and the same shared Zig authority and framework implementation.

`just test::grpc-worker` separately passes in **344.45 seconds** excluding
compilation over disk Ursula and the actual Zig worker. All four shapes complete
and replay, then lose workers during partial durable response capture and recover
as closed unknown without another send after node/store restart. Exact signed
seal/dispatch/observation retries recover dropped receipts. Current endpoint/grant
changes, generation re-entry, replay prefix revocation and retired capture reject.
An explicit idempotent retry succeeds under the original budget; another attempt
is refused. Bounded cleanup preserves lineage until descendants release it. The
peer records nine sends and eight applications; the 8 MiB hot profile retains
697 cold objects / 63,978,080 bytes. This controller-driven proof does not qualify
public caller SDKs, deployment placement or every final-publication crash boundary.

`just bindings::native` also passes the RPC native/port fixture and growing
scoped upload/call/retry/disposal schedules, including host replacement mid-upload,
changed-reference refusal and unchanged mutation budgets after failure. Both
protocol readers use shared local ownership/copy-out logic, with allocation-failure
rollback units. The independent fixtures preserve empty/binary/Unicode messages,
duplicate metadata, full-width identities and observed `OK` versus unknown. This
qualifies the native bridge. Installed Python, Node, Ruby and Rust RPC callers
now pass the shared disk-backed schedule in **64.74**, **70.02**, **65.56** and
**96.56 seconds** respectively (including clean consumer setup). Each binds the
local descriptor, resumes upload after host replacement, sends binary/Unicode/
full-width protobuf plus an empty message, authenticates its reply, rejects replay
after prefix revocation, joins active reader work and disposes its durable hold
before/after cleanup. Typed retry refusal allocates no child or send. Each peer
records exactly one RPC. The unchanged Python and Node HTTP schedules pass through
the shared harness in **65.95** and **68.32 seconds**. The remaining language and placement proofs are recorded above; these local
timings do not establish hosted CI cost.

The final unchanged HTTP/Board browser regression passes in **505.30 seconds**,
with sixteen sends, eight applications, two cancellation requests and 1,028 cold
objects / 116,002,637 bytes under the original 8 MiB hot bound. `just check`
passes after RPC code generation and the expanded failure tasks. No expanded
hosted timing run is claimed; that budget work remains deferred.

`just test::grpc-codegen` regenerates the pinned descriptor's Zig helpers and
compiles/uses all four request shapes, exact descriptor identity and typed secret
references. Independent descriptor mutations reject missing types, truncation,
empty and oversized data without producing partial helper source. It is offline
construction evidence, separate from transport and dispatch qualification.

`just test::grpc-libraries` runs the selected pinned HTTP/2, HPACK, protobuf and
gRPC client suites. Compatibility changes and the intentionally excluded server
surface are recorded with source hashes in the [snapshot](../third_party/zig-libs/README.md).
`just test::grpc-transport` runs all four call shapes against grpcio 1.80.0 over
TLS, resolving all four methods from local protoc-generated descriptors and
preserving original protobuf bytes with binary/Unicode/full-width values,
duplicate/binary metadata and distinct trailers. Eight calls exercise complete,
non-OK, oversized, exhausted-budget and stalled results without retries.
Six independent h2 peer schedules add 64-byte request credit, 16-KiB response
credit, a response larger than its window before request credit is returned,
missing status, truncated/compressed frames and malformed/duplicate terminal
status. The same-frame END_STREAM regression rejects a false terminal head even
when later DATA and END_STREAM arrive in one read. This is transport evidence;
the same live callbacks now pass through the pure RPC capture/replay adapter,
including frozen policy, 4 KiB message parts and 256-byte replay reads. Units
reject changed digests, missing parts, false terminal counts, invalid metadata,
undeclared credentials and unsafe retry changes. Python-generated GRH1/GRM1/GRS1/
GRT1/GRO1/GRC1 fixtures fix the binary layouts independently. These sinks are
in-memory protocol probes; durable recovery, SDKs and deployment are qualified separately above.

`just test::tls-alpn` executes a real Zig client against six independent TLS
connections: TLS 1.2 and 1.3 each accept `h2` and reject absent or incompatible
selection before application bytes. Units reject unsolicited/duplicate selection,
unknown protocols and malformed vectors. The unchanged HTTP transport and
certificate-path corpus passes after this addition. HTTP/2 and gRPC streaming
are not established by this negotiation proof.

## M15 connector work in progress

The terminal-publication fault extension to `just test::http-worker` passes in
**499.61 seconds** excluding compilation. The executor is killed after kernel
observation commits but before the receipt/framework publication; fresh ownership
after node/store restart settles without another send. A second node/store
restart happens after the correlated output commits and before delivery. The
schedule still records sixteen sends, eight applications and two cancellation
requests, retaining 1,009 cold objects / 113,779,019 bytes. Endpoint hostname,
scheme, port and metadata-address changes reject before dispatch. The independent
transport proof now has **22 sends**, explicit SNI/Host assertions, a nonexistent
DNS name with a numeric pin, nonnumeric-address refusal and wrong-CA rejection.
Both uppercase and lowercase proxy variables are ignored. The non-CA intermediate
audit exposed a standard-library TLS weakness, now fixed by the pinned
[TLS adapter](../packages/zig/transit-tls/README.md). The transport task additionally
uses twelve independent TLS 1.2/1.3 handshakes: valid chains succeed, while non-CA
issuers, missing signing usage, excess path length, client-only purpose and
excluded DNS names fail before HTTP bytes. Standalone validator and TLS suites
pass, including malformed DER and the original forged-chain regression. These
are fixture-based qualification, not a general cryptographic audit.
With this transport, Compose passes in **98.79 seconds** and reference placement
in **301.22 seconds** before successful cleanup, under concurrent proof load and
with changed-image preparation. Each makes one remote send, replaces its caller,
restarts node/store and replays without the peer or credential.
The hardened disk schedule passes in **489.90 seconds** excluding compilation,
with sixteen sends, eight applications, two cancellations and 1,067 cold objects /
117,643,105 bytes. No retention or storage-limit increase was needed.

`just examples::http-reference` passes in **192.85 seconds** before successful
owned-resource cleanup. The actual gVisor caller admits a request, loses its
worker pod, registers a fresh in-memory key, receives explicit Transit ownership
and recovers the same saved call. The trusted connector pod makes one TLS request
under explicit egress rules; both roles' network probes reject raw storage and
provider/admin targets. Node/store pod restart, peer shutdown and credential
removal precede replay in another fresh caller. The task checks Actor/template/
worker attribution and keeps the existing default installation untouched.
This is finite operator placement, not automatic growing runtime binding or
supervision. See the [placement guide](../examples/station-http/docs/placement.md).
The accompanying local bootstrap and Compose regressions pass in **29.45** and
**86.48 seconds**, with changed-image preparation and concurrent proof load in
the latter. The reference task is in the external verification inventory.

The expanded `just test::http-worker` schedule passes in **493.33 seconds** excluding
compilation, with **sixteen sends, eight applications and two cancellation
requests**, retaining 1,074 cold objects / 116,719,300 object-store bytes under the
same 8 MiB hot bound. It kills the executor after a response chunk is durably
committed while its acknowledgement is withheld. The capture remains partial;
replay refuses. Fresh ownership after node/store restart closes unknown without
resending, then explicit retirement/cleanup reclaims the unsealed member too.
This extends the earlier schedules below; it does not add a hosted measurement.

`just examples::http` builds and executes the actual Zig caller and connector
against a disposable disk Ursula, growing authority and independent TLS peer.
The **26.81-second** local schedule checks caller replacement after publication
preserves the call, separately authorized outbox delivery, one remote send,
correlated receipt and binary/Unicode replay after node/store restart with the
peer stopped and credential removed. Its operator uses the real growing CLI;
workers receive scoped keys. This local task does not qualify OS egress isolation.
`just examples::http-compose` passes the same schedule in **19.40 seconds** with
cached static images, separate internal networks, read-only role mounts, resource
limits and no published ports. Its caller-network probe reaches Transit while
TCP access to the peer, Ursula and an external address fails. Node/store recovery
and replay run in the real containers. This is local Linux/Docker evidence, not
Substrate qualification.

`just examples::http-bootstrap` passes locally in **28.04 seconds**, replacing
the caller's key in memory for every invocation. The operator validates the public
registration, rotates only that PID's grants and records the exact expected
generation. Reissued resource grants preserve the saved call and replay after
restart. Pure client tests reject successor-generation adoption, wrong ownership,
blocked or retired processes. This prepares finite reference placement; it does
not prove provider attribution by itself.

The worker's bounded diagnostic integration passes the complete disk/S3 schedule
in **445.26 seconds** excluding compilation, with the same fifteen sends, seven
applications and two cancellation requests. Structured stderr excludes credentials,
raw targets, credential paths and authority URLs; stdout stays parseable JSON.
An observed recovery finishes while its debug stderr pipe is intentionally left
full and emits no fresh transport event. `just test::telemetry` also passes all
four off/drained/stalled/closed sink modes with 10,000 completions under one-CPU
affinity; metrics accumulate despite diagnostic loss. These are service-local
observations, not counters of unique durable transitions or remote applications.

`just test::unit` includes exchange segment/coverage, frozen effect intents,
identity conflicts, quota/rollback, terminal cleanup and old-source availability
checks. Ninety-six durable dependency tokens exercise admission, wrong-holder
release, duplicate disposal and permanent token retirement across turns. Capture
cannot retire before kernel settlement and explicit caller/consumer disposal.
The additive EXL2 lineage context is independently byte-fixtured and bounded at
214 bytes. Package and root unit checks prove its four-mutation allocation,
rollback with occupied capacity, immutable duplicate identity and preservation
of the original caller/input/deadline and attempt budget across EXL1/EXL2
descendants. HTTP service units also check authentication before request reads,
atomic child/reply-route allocation, read/mutation/output rollback, conflicting
correlations, unpublished/retired parents and exhausted total budgets.
`just test::http-transport` runs the real Zig transport against independent
Python HTTP/TLS peers: 22 single-send requests cover 16,387-byte binary chunked
bodies, trailers, header omissions, redirects, ambiguous framing, truncation,
capacity refusal, capture failure, lost responses and timeouts. TLS authenticates
the configured hostname while dialing its explicitly pinned IPv4 address.
Ambient proxy settings are ignored. Close-delimited TLS bodies are rejected
because the pinned transport relies on HTTP framing to detect truncation.

`just test::http-worker` runs the actual finite worker over disk Ursula and the
existing owned MinIO fixture; Docker is required. It loses
accepted segment-seal, dispatch and observation replies and checks exact retries;
SIGKILLs a preparing worker after a committed request chunk, restarts node/store,
and resumes under fresh ownership with matching bytes and the original deadline;
restarts node/store; replays a 1,027-byte response without another send; and kills
the worker after remote application. Fresh ownership closes that attempt unknown
without resending. Reusing an entered activation fails. Public body reads recheck
resource permission after an actual prefix. A separately requested idempotent
retry uses a new linked effect with the original key and request bytes. Changed
bodies and exhausted attempt budgets reject. The independent peer records three
remote requests but only two applications across those retry scenarios. Additional
explicit status, cancellation and captured same-authority redirect followups each
have separate effects, giving seven sends, three applications and one cancellation
request across those controller scenarios. Status/cancellation evidence leaves the original effect
closed unknown. Pure policy cases reject metadata/admin address changes,
cross-authority/changed redirects, undeclared action targets and policy changes.
The worker proof uses TLS and a versioned credential file. Changed numeric
destinations, wrong credential versions and header scopes reject before dispatch;
resolved credentials are absent from all durable mutations. Replay works after
removing the credential file.
Changed byte budgets, capture allowlists and CA bundle bytes also reject before
dispatch. Replay now uses the HTTP validator: required record order, complete
heads, original body counts, status and terminal timing/omission evidence must
agree with the verified exchange coverage. Shared binary fixtures independently
fix full-width identities, empty/binary member commitments and Unicode escaping;
strict replay reports a gap when requested data was redacted.
Explicit release retires availability before cleanup. The proof rejects replay
while uncollected bytes remain, restarts node/store during reclamation, and resumes
bounded cleanup to its durable end without another network attempt.
The public-admission extension publishes metadata/body in a separate caller's
resource and sends an authenticated Station call to the worker. The proof revokes
and restores request access, rejects changed method/target scope before dispatch,
and delivers one correlated observed reply. Capture is independently owned;
optional associations preserve PID-scoped read access without required caller
lifetime dependencies. After remote application, caller termination plus worker,
node and store replacement produces closed unknown with the original attempt.
The reply's outbox destination is retired; a replacement PID receives no input.
Public retry now uses a new call from that original application PID. Changed
scope/policy rejects before allocating a child. A revoked request-read grant stops
the activation without blocking the process or advancing the input; restoring
access and fresh ownership resumes the same call. Losing the committed EXL2
allocation receipt proves exact retry of child, route and root-budget consumption.
Fresh preparation resumes the child without another allocation or send, then
execution produces a new effect/attempt and correlated outcome. The independent
peer sees two sends and one application, while the parent remains closed unknown.
Public status/cancellation now publish separate empty-body requests from the
original caller. Public redirect publishes a new target only after observing a
complete 307; no implicit follow occurs. All preserve new correlations/effects
and leave the original effect unchanged. EXB2's unsettled-child count blocks parent
cleanup before and after node/store restart, then permits cleanup after all
children settle. Package tests additionally cover abandoned siblings, nested
descendants, duplicate settlement and mutation rollback without refunding slots.
The expanded proof passes in **458.34 seconds** excluding compilation, with
**fifteen sends, seven applications and two cancellation requests**. A prior run
hit the default hot-only 64 MiB store limit; the proof now uses M10's existing
8 MiB hot/S3 profile. This run persisted 967 cold objects and 103,195,312
object-store bytes without enabling retention or raising memory limits.
The combined 477.68-second worker/Board schedule also uses an independently owned
growing Registry service to bind the caller name, retire that caller and rebind
to its replacement. After node/store restart the new binding persists, but the
original HTTP outcome still has the retired destination and the replacement has
no input. Growing units retain 96 names while each operation uses three point
reads, exercise a principal above 255, tombstones, stale revisions and rollback.
`just test::station` and `just bindings::native` pass their legacy regressions.
Broader deployment qualification remains open.

`just transit-board::http-test` adds the real Board API to that disk/S3 worker
schedule; `just transit-board::http-browser` additionally exercises its embedded
UI. The latter passes bounded record paging, exact source alignment, no raw value
disclosure, unchanged durable authority position across inspection, stale-revision
refusal, and current read revocation including a previously valid continuation.
The actual generated JavaScript validator accepts service pages and rejects
numeric full-width exchange IDs. The real browser clears capture cards on live
revocation, resumes after access is restored, sends only GET requests, and leaves
no cookies or local/session storage. The complete worker/API/browser schedule
took 460.46 seconds excluding compilation, including 11.7 seconds of Chromium
execution, and retained 971 cold objects / 104,734,346 object-store bytes. This is
local evidence, not hosted CI qualification.
Deterministic projection/client units cover malformed versions, wrong writers,
private context omission, exact uint64 limits and source mismatches. HTTP timing,
omission and root endpoint policy inspection are now qualified by the selected
HTTP metadata route. The complete worker/API/browser schedule passes in
**477.68 seconds**, including **11.7 seconds** of Chromium execution, retaining
966 cold objects / 106,209,530 object-store bytes. The read adapter checks selected
record commitments without reading bodies; partial captures expose no invented
terminal data. Generated client fixtures reject unsafe numeric timing/policy IDs,
inconsistent member sources and private fields. Revocation clears the selected
metadata view. Telemetry assertions allow bounded event loss and loss reports.
`just transit-board::query-test` also passes against the changed growing router.

Public HTD1 disposal now releases only the authenticated original caller's hold.
The real worker's `poll` mode passes disposal without its credential file,
accepted-receipt loss with exact retry,
node/store restart, repeated disposal before and after cleanup, and an actual
replay prefix refusing continuation after retirement. Its HTK1 acknowledgement
retains the call's source/correlation. Release alone leaves replay available;
retirement and cleanup are separate controller operations. Package tests also
prove output-budget rollback and preservation of another consumer's dependency.

The same real capture exercises `station_growing_http_read`: one active reader,
owned bounded chunks, actual prefix revocation, sticky failure, explicit close,
stale reader IDs and reopening. Returned body bytes survive native destruction;
replay completes after deleting the request credential, without another send.
Native allocation enumeration proves an undisclosed part cannot advance a cursor
when response allocation fails. Shared HTTP codecs run independently constructed
admission/outcome fixtures through the native library and local-codec port.
Growing native actions reject unpublished or mismatched request references,
preserve duplicate chunks and publish the ordinary durable call through the
existing preparation/dispatch gate. `just bindings::native` includes these
checks alongside the existing Table/query and C/C++/Python interoperability proofs.
The shared native/port disposal codecs also consume the independent HTD1/HTK1
fixtures, preserving full-width exchange IDs and rejecting wrong/truncated frames.
The `http_release` scoped action rejects invalid identities without consuming
turn capacity, then emits the exact durable call without requiring a capture
read grant. The service retains holder authentication and current-policy checks.
Native/port codecs also consume the independently constructed HTU1 fixture. The
scoped `http_followup` capability preserves all 64 parent bits, validates the exact
published request in the current associated resource, and emits the ordinary
durable call under a new correlation. Invalid/unpublished/changed references
consume no turn capacity. The native suite passes these additions alongside
its existing ownership, exact-retry, Table/query and interoperability schedules.
The installed Python and TypeScript HTTP schedules now include all four typed followup reasons,
full-width parent identity, cross-realm/expired-turn refusal and authenticated
HTF1 rejection with the saved correlation. It reports no child allocation or
additional send for unsupported policy, and still passes durable disposal and
replay. Expanded local HTTP schedules took 63.21 and 70.91 seconds respectively;
TypeScript additionally refuses an invalid reason at runtime. Positive public retry
dispatch belongs to the independent Zig worker proof above.
Rust's typed followup method passes the same installed schedule in 95.12 seconds
including clean compilation; borrowed turn/request ownership remains enforced by
its existing compiler rejection checks.
Ruby passes all four followup symbols, runtime invalid-symbol/cross-realm/expired
turn refusal, authenticated rejection and its previous lifecycle checks in
65.47 seconds for the HTTP schedule.
Java's clean JAR consumer passes typed followups, saved correlations, cross-realm
and expired-turn rejection in 76.33 seconds, alongside all prior raw/Station
and asynchronous capture-reader checks.
.NET's clean NuGet consumer passes in 68.23 seconds for HTTP, including all four
followup reasons, invalid enum values, cross-realm/expired-turn refusal and
authenticated correlated rejection, with prior cancellation/join checks retained.
Erlang and Elixir pass in 65.19 and 68.23 seconds respectively, including all four
followup atoms, tagged invalid-reason/cross-realm/expired-turn errors, saved reply
correlations and the previous immutable-reader/owner-death/join schedules.
C and C++ pass in 62.92 and 70.08 seconds, including compiled C11 callbacks,
typed C++ handlers, full-width parent identity, saved correlation and defined
invalid-reason/cross-realm/expired-turn rejection. The initial C run exposed a
C++ invalid-enum load abort; the C input now uses a checked fixed-width integer.
All ten SDKs qualify followup submission and authenticated policy refusal.
The shared `http_stage` helper freezes namespace ownership and advances one
publication step per turn. Its disk/native proof replaces the host and owner
after a committed metadata prefix, rejects a changed endpoint revision without
consuming mutation budget, resumes to a validated call and rejects retired reuse.

`just bindings::python-test` additionally runs the installed Python HTTP API
through [the shared HTTP caller schedule](sdk_http_runner.py): a binary request
with duplicate headers, escaped Unicode target and credential references, fresh
ownership after a staging prefix, one correlated reply, prefix revocation and
reopening, owned replay after deleting credentials, and joined asynchronous
cancellation. Only one request reaches the independent TLS peer. The local
2026-09-26 expanded HTTP schedule took **52.98 seconds**, including clean wheel installation
and excluding compilation. The ordinary raw client, runner recovery and Arrow
consumer regressions also passed. Sticky replay errors report the current local
failure instead of inheriting a previous authority rejection.
The expanded schedule calls `release_http` from a scoped handler, authenticates
the correlated `HttpReleased` acknowledgement and repeats disposal after capture
cleanup. It runs without a transcript read grant or credential file and still
records only one remote request. Cross-realm and expired-turn calls reject;
independent acknowledgement fixtures preserve full-width exchange identities.
`just bindings::node-sdk-test` runs the same HTTP schedule through clean Node
tarballs, including runtime schema validation, owned request/getter bytes, native
HTTP reply dispatch and joining a delayed replay read during local stop/disposal.
The expanded 2026-09-26 local HTTP schedule took **55.73 seconds**, including
authenticated durable disposal before/after cleanup without transcript access
or credentials, with the existing client,
runner and Arrow regressions also passing. TypeScript handlers opt into the async
shared decoder through `handleHttpReply`; application codecs stay synchronous.
`just bindings::rust-sdk-test` qualifies the same binary caller/replay schedule
through installed source crates and embedded native libraries. The HTTP schedule
took **86.92 seconds** locally, including clean Rust/Arrow compilation and durable
disposal before/after cleanup without transcript permission or credentials. A compiler
rejection case proves a live HTTP reader's mutable borrow prevents another runner
operation; a delayed read finishes before the owned blocking task is joined.
The ordinary client/runner/Arrow regressions also passed.
`just bindings::ruby-sdk-test` also passes the shared HTTP schedule through clean
gems, with frozen owned strings, schema-validated port results and an interrupted
controller wait whose native read is joined during runner disposal. Its local
expanded HTTP schedule took **53.75 seconds** including gem installation and
authenticated durable disposal before/after cleanup with transcript reads revoked.
The existing
Ruby client and Station recovery/query schedule remained passing.
`just bindings::c-sdk-test` builds HTTP callbacks as C11 and a typed C++17
consumer against installed archives. The C and C++ HTTP schedules passed locally
in **57.72** and **60.78 seconds**, including clean consumer compilation, golden
request/outcome fixtures, staged upload recovery, prefix revocation, sticky
failure, copied parts and reader use after runner destruction. Both join a
delayed read during stop/disposal. Both also authenticate durable disposal with
transcript access revoked and repeat it after cleanup. C uses a separate HTK1
decoder and inline acknowledgement type, preserving its existing outcome layout;
C++ adds an explicit acknowledgement variant. The ordinary raw client and Station
schedules passed in the same task invocation. Host
allocation poisoning is implemented; fault-injected host allocation coverage
remains distinct from the native allocation proofs.
`just bindings::java-sdk-test` adds clean installed JAR HTTP callers to this
expanded schedule. It passed locally in **62.14 seconds**, including authenticated
durable disposal before/after cleanup without transcript access, immutable bytes, the
explicit application/outcome codec, prefix revocation and future cancellation
followed by joined cleanup. The independent raw client and Station recovery/query
regressions passed through their task commands as well. A cancelled read view
invalidates its local reader; native execution remains owned until disposal.
`just bindings::dotnet-sdk-test` passed the same installed NuGet HTTP schedule
in **60.17 seconds**, including authenticated durable disposal before/after cleanup
without transcript access, immutable copies, explicit typed outcomes,
revocation/reopening and cancelled task waits joined by runner disposal. Existing
raw client and Station recovery/query checks passed in the same invocation.
`just bindings::beam-sdk-test` installs both BEAM archives and exercises Erlang
records and Elixir structs. Both raw client and Station schedules passed; after
fixing a missing import in the new fixture loader, both Station and expanded
HTTP schedules passed through the task's harness in **54.45** and **55.47
seconds** for HTTP. Both authenticate durable disposal under revoked transcript
access and repeat it after cleanup. Immutable reader tokens reject stale cursor reuse; a killed waiting
process cannot silently skip a part, and disposal joins the admitted port job.
All ten SDKs now pass the HTTP fixtures, caller schedule and durable disposal
before/after cleanup without transcript access or credentials. The existing public
counter/query interoperability ring was rerun against these installed artifacts:
all ten edges passed in **255.78 seconds**, including clean consumer installation.

The 2026-09-26 Linux x86_64 worker run took **285.29 seconds**, excluding compilation.
This is local proof time, not a hosted CI or aggregate runner-minute measurement.
Machine output distinguishes sealed capture phase from the kernel outcome.

These checks passed locally on Linux x86_64 with the pinned compiler. They do not
yet qualify general public multi-call/followup APIs, managed secret providers,
every cross-service lifetime combination, all launchers
or hosted CI cost. Those remain explicit
[M15](../docs/roadmap/M15.md) exit obligations. The shared capture
[contract](../contracts/STATION_EXCHANGE_V1.md) distinguishes library coverage
from protocol completeness and effect-result acceptance.

## Test ownership

This directory owns conformance harnesses, fault injection, test-only executors,
and proof results. Application examples live under [examples](../examples/README.md);
tests launch those real binaries rather than a separate implementation of their
logic. The [conformance design](../docs/CONFORMANCE.md) owns the required adversarial
scenarios. Results below describe the recorded bounded milestone profiles, not
a claim that all commands are rerun on every documentation change.

## Running checks

`just check` includes `tests/reference_launcher_state.py`: isolated launcher
regressions cover missing infrastructure, replaced clusters/namespaces, original
identity recovery, interrupted namespace creation and explicit local cleanup
after cluster deletion. Docker failure cannot count as absence. These mocked
boundary checks supplement the real reference launcher proof; they do not claim
Kubernetes recovery or isolation by themselves.
The 2026-09-26 local repair also exercised fresh counter provisioning and a real
reference stop/start cycle: state remained 12, realm/PID/namespace/Actor stayed
fixed, and ownership advanced from generation 4 to 7 with a different worker.
That focused recovery check did not rerun the full reference isolation corpus.

M7 evidence is recorded in [the state proof](#m7-state-resources). The ordinary
suite includes the public state API and real resource-backed Zig caller.

M9 proofs include `just test::arrow` (independent PyArrow validation
of Fuze IPC, including nulls, empty results and wide integers) and
`just test::client-abi` (a generated C header, real authority calls, canonical
signatures, receipt loss, fresh-host retry, revocation and malformed input).
The [Fuze integration notes](../packages/zig/transit-fuze/docs/integration.md) and
[client binding guide](../packages/zig/transit-client/docs/bindings.md) record
their limits. `just test::station` launches the real Zig Station ledger/requester
and courier, proving private state/call commits, lost receipts, fresh ownership,
worker plus store recovery, authenticated replies, scoped registry/supervision,
timers, poison-input blocking and opted-in lifetime expiry/reclamation.
The [M9 evidence](#m9-station-bindings-and-tables) below distinguishes native
language qualification from reference worker qualification.

M11 extends `just test::client-abi` with the explicit growing raw-client boundary.
Its [shared fixtures](verification/sdk-operations-v1.json) pin v3 canonical bytes,
signatures and full-width IDs. The real disk proof checks principal 65,536,
node/provider restart, opaque retry in a fresh process, lost/malformed accepted
replies and revoked reads/receipt recovery. Allocation enumeration covers both
mutation profiles. `just check` and the complete `just bindings::test` matrix
passed after this extension.
The same raw-client task now also runs the independent
[client port](../apps/transit-client-host/README.md), including metadata identity,
profile/command classification, malformed canonical recovery and seedless retry
from a fresh process. Its executable imports no Station implementation. The raw
port and `station_codec_host.py` also verify explicit shutdown acknowledgements
and successful exit while stdin remains open. Station covers local-codec, raw,
legacy and query-enabled growing handles. Native cleanup precedes the response;
this lifecycle acknowledgement does not replace mutation receipts.

`just bindings::test` also runs the [growing Station ABI proof](station_growing_abi.py)
against disk-backed Ursula. It checks every mutation's preparation/dispatch gate,
41 Table rows through bounded pages, retained sources, stale scopes/cursors,
poisoned reads, explicit stop behavior, revocation, native port parity and exact
retry from a fresh process after caller/node/store loss. Native allocation-failure
enumeration preserves accepted receipts until the host can receive them. Both
`just check` and the complete existing language matrix pass with this boundary.
The companion [query ABI proof](station_query_abi.py) uses the native query
profile's bounded 64-page cache. It captures and delivers 41 rows in six IPC
segments, retries lost staging receipts, restarts workers/node/provider after a
seal, checks complete source metadata and decodes owned IPC with PyArrow after
native disposal. Port parity, disabled query access, stale scope and revocation
are covered by the shared `growing-query-abi` scenario. Public language adapters have separate qualification below.

`just bindings::python-test` builds Python wheels, installs only `transit-client`
and `transit-native-client` into an isolated consumer outside the source tree,
and exercises the public raw API against disk Ursula. It covers typed bounds,
copied mutable payloads, canonical classification, a dropped accepted receipt,
seedless retry in another process, host allocation failure after a receipt,
revoked historical retry, one-operation admission and responsive async close
after await cancellation. Strict typing covers the public client and native
artifact resolvers. A second isolated consumer installs Station and the example
package, then exercises the typed runner against a real disk node. It covers
persistence and confirmation failures for permit/open/commit, post-acceptance
host allocation, escaped/wrong-thread turns, strict ingress with stop/block
policies, a poisoned read caught by a handler, responsive cancellation during
an accepted commit, and exact seedless retry after killing the host and restarting
node/provider. Installed counter CLI roles preserve a full u64 reply across a
fresh requester activation. Table/query handlers prove 41 rows/six pages, retained
point reads after mutation, six original IPC segments after disposal, current
access revocation during a result read and process expiry. The optional PyArrow
23 adapter uses the pinned Nix consumer after the independent clean core install.
The shared `public-runner-lifecycle` scenario records comparable observations for
all targets. Qualification is Linux x86_64 with Nix-linked native wheels.

`just bindings::node-sdk-test` builds the independent Node client/native tarballs,
checks the strict public API and installs them outside the checkout using ordinary
package-manager overrides for unpublished local artifacts. No Station package or
manual native loader path is present. Python and Node run the same
[raw-client schedule](sdk_raw_client.py): copied input/export buffers, native
classification, a lost accepted response, seedless host restart, failed host
response parsing/allocation, current revocation, bounded overlap and responsive
close after a local await/abort. A second clean consumer installs Station and the
executable counter/query examples. Python and Node share the
[runner authority schedule](sdk_station_runner.py), including every mutation's
persistence/confirmation hooks, dropped accepted commits, exact seedless recovery
after host/node/store restart, stale/revoked/expired callers, poisoned reads,
41-row retained Tables and six original IPC segments. Node additionally checks
dropped, overlapping, escaped and foreign-context turn calls, callback reentry,
and responsive stop/join during an accepted commit. Its runner unit proof injects
a retained confirmation after host allocation failure; raw port-response failures
and native allocation enumeration retain their separate real boundary proofs.
The optional Apache Arrow JavaScript 21.2 adapter is installed only after the core
proof and preserves int64/null values after disposal and mutation of input copies.
The consumer selects the root manifest's pnpm version through `vp env exec` and
uses normal package-cache fallback; a different filesystem may have its own cache.
Strict checks compile both public examples. Linux x86_64/Nix-linked tarballs are
qualified.

`nix develop .#bindings --command just bindings::rust-sdk-test` builds the
independent raw Rust client and matching native crate. The external consumer
builds with the lockfile and ordinary Cargo patches for unpublished artifacts,
then deletes extracted crates and build outputs before running its installed
executable. The embedded library loads without a Cargo-cache or loader path.
It runs the same raw authority schedule, plus compile-fail checks for overlapping
mutable use, shared handles and use after consuming close. Its initial API is
blocking: `blocking-owner-disposal` abandons an application's receive, keeps
native work owned through explicit close, joins responsively and recovers the
same receipt. It does not claim an async executor adapter.

The Rust Station consumer installs five crates and builds core and optional
Arrow variants using the SDK lock. Registry versions/checksums remain unchanged;
the core dependency tree excludes Arrow. After deleting extracted sources and
builds, it runs `sdk_station_runner.py`, including both installed counter CLI
roles. Compiler rejection covers overlapping turn helpers, `Send`/lifetime escape
and a boolean passed to the u64 codec. The real schedule covers persistence errors
and panics at permit/open/commit gates, handler errors and panics under stop/block
policies, retained confirmation receipts, responsive stop/join during an accepted
commit, caught poisoned reads, exact seedless retry after disk/host restart,
fencing, retirement and revoked result access. Retained Tables span six pages;
six owned IPC streams preserve i64 extremes/nulls and complete source metadata.
The optional Arrow Rust 59 adapter decodes after runner disposal and its batches
survive mutating the SDK bytes; independent PyArrow verifies the same streams.
Rust does not inject an allocator failure into its own FFI wrapper; native retained
confirmation behavior is also covered by the shared ABI/Python proof.

`nix develop .#bindings --command just bindings::ruby-sdk-test` builds and installs
separate Ruby 3.4.9 client/native gems outside the checkout. Its raw schedule
qualifies owned binary strings, full principal bounds, native canonical kind
classification, lost receipts, seedless recovery and revoked historical retries.
Killing the controller thread during an accepted send leaves native work owned;
concurrent work rejects, close joins responsively and retains the known receipt.
Missing/incompatible host overrides and oversized, invalid-UTF-8, malformed-status
and truncated port replies fail with read/uncertainty distinctions. The client
has no Station dependency. Interrupted block acquisition waits for startup and
then joins both the Ruby worker and native child. The bindings CI lane includes
these public proofs.

The Ruby Station consumer installs five gems and invokes both documented counter
CLI roles. It runs the shared `sdk_station_runner.py` schedule with full-width
codec fixtures, all persistence/confirmation gates, reentrant-call rejection,
normal and non-StandardError handler failures under stop/block policy, expired
helpers and cross-thread/fiber access. Killing a waiting caller retains owned
native work through responsive close, including an accepted commit. Exact retry
survives host/node/disk loss without a seed, and fresh owners resume durable calls.
Poisoned reads, retirement, stale ownership and revoked result access retain their
meaning. Retained Tables span six pages, and original IPC buffers survive runner
close and mutation of returned copies. Independent PyArrow decodes all six
segments, including i64 extremes and nulls. Ruby has no selected native Arrow
adapter; the optional-adapter step is explicitly disabled for it, while the full
IPC/metadata/independent-consumer proof runs. Codec reentry is rejected, and a
caught state decoder failure aborts without committing or blocking the head even
under `block_input`.

`just bindings::c-sdk-test` builds versioned C SDK/native archives and C++ headers,
installs them into external prefixes and compiles separate C11 and C++17 callers
with standard pkg-config discovery. Consumers use installed rpaths and adjacent
native discovery without a library-path environment variable or Station library.
Both run the shared raw-client schedule: owned input/export bytes, metadata and
canonical-kind checks, lost accepted receipts, seedless recovery, revoked retry
and responsive joining of an owned blocking task after its controller stops
waiting. C also checks overlap/closed rejection; C++ checks move-only types and
distinct process/resource references. Missing libraries, incompatible native
versions and C SDK version mismatches fail explicitly. The implementation owns
one admitted job and an 8 MiB worker stack. Asynchronous POSIX thread cancellation
is not supported; the controller's local wait is the cancellation boundary.
This qualifies raw clients on pinned Zig/Linux x86_64 with the Nix runtime closure.

The same task installs C/C++ Station SDKs and the actual counter CLI/application
artifacts. A shared C++ conformance controller selects the direct C runner with
compiled C11 callbacks, then the public C++ runner with typed C++ handlers. Both
execute the full `sdk_station_runner.py` schedule: golden codec names/bytes and
u64/i64 extremes, persistence/confirmation failures for each mutation purpose,
callback reentry, exceptions and malformed input under stop/block policy, retained
scope rejection, responsive stop/join through an accepted commit, poisoned reads,
fencing/retirement/current access, and exact seedless recovery after host/node/disk
loss. Six-page Tables exercise retained point/page reads after mutation. Six
original IPC segments survive runner destruction and mutation of copies before
independent PyArrow decoding; no optional C/C++ Arrow adapter is selected. Installed
counter roles run as their actual C11/C++17 binaries. Compile failures reject copied
C++ runners and a boolean passed to a typed u64 state key. Native-version overrides
reject before codec/frame use. Allocation enumeration remains the shared native
proof; this C/C++ consumer does not inject a host allocator failure.

`nix develop .#bindings -c just bindings::java-sdk-test` builds independent Java
client/native JARs with POM dependency manifests and installs only those JARs plus
pinned Gson into an external consumer. Strict Java 21 compilation precedes the
shared raw authority schedule. The proof covers typed bounds, copied buffers,
native metadata, lost accepted responses, exact seedless recovery and revoked
retry. Cancelling both dispatch and a close-future view preserves owned work;
joined cleanup retains the accepted receipt while the controller remains
responsive. Missing/mismatched native JARs, ABI-version overrides, malformed
status, duplicate JSON members, invalid UTF-8, oversized lines and partial output
are rejected. No Station JAR is installed in the raw proof.
The Java artifacts require the Nix runtime closure; Maven resolution/publication,
portable Linux artifacts and JVM allocation-failure injection are not qualified.

The same task installs Java Station/native/example JARs and strictly compiles a
consumer outside the checkout. Its shared runner proof covers all mutation hooks,
exceptions and `Error` callbacks, reentrant/wrong-thread/expired scope rejection,
stop/cancel/join with retained commitment, malformed ingress, caught poisoned
reads, stale ownership, expiry, revoked access and exact recovery after host,
node and disk-provider restart. Both actual counter CLI roles run; full u64 values
survive restart. Typed compile failures reject boolean values for u64 KV keys and
int64 Tables. Six-page retained Tables and six owned IPC segments remain valid
after disposal and are independently decoded with PyArrow; no optional Java Arrow
adapter is selected. ABI/native-artifact and mismatched public-client versions
reject before handler work. Status validation uses each generated ABI's range,
including Station's stale/not-ready/budget statuses. Full-width values are exact
`BigInteger`/`long`, with no floating-point conversion at the public boundary.

`nix develop .#bindings -c just bindings::dotnet-sdk-test` packs independent
`Transit.Client` and `Transit.Native.Client` NuGet artifacts, restores them from
an isolated local feed into an external .NET 8 consumer, and deletes build source
and package caches before execution. No Station package is installed. The shared
raw schedule checks typed bounds, copied payload/export bytes, native metadata,
lost accepted responses, exact seedless recovery and revoked retry. Cancelled
dispatch/close awaits preserve owned native work and the accepted receipt while
the caller stays responsive. Missing artifacts, ABI mismatches and closed handles
reject explicitly; credential-read errors omit private paths. Native calls and
destruction use one owned 8 MiB thread. Portable Linux packages, NuGet.org
publication and CLR allocation-failure injection are not qualified.

The same task independently restores Station/native/example NuGet packages,
compiles typed consumers with warnings as errors, rejects mismatched state/Table
value types, and runs the shared runner schedule. Every mutation persistence and
confirmation hook fails once without rerunning the handler. Both handler failure
policies, expired/wrong-thread/reentrant scopes, poisoned reads, fencing, expiry,
revocation, cancellation/stop/join and exact seedless disk recovery are covered.
`async void` handlers and persistence hooks reject before activation work. The
installed counter executable resumes a durable requester; Table/query handlers
verify bounded pages, retained revisions, nullable signed extremes and complete
provenance. Six owned original IPC segments survive disposal and are decoded by
independent PyArrow; no optional .NET Arrow adapter is selected. Generated-schema
checks reject absent nullable fields, invalid cursors, fractions and oversized
exponents. Native package/ABI checks precede use; SDKs require exact 0.2.0 peers.

`nix develop .#bindings -c just bindings::beam-sdk-test` builds standard OTP
applications with separate Erlang core, Elixir wrapper and native dependencies.
External consumers install only these raw packages through `ERL_LIBS`; the Erlang
consumer compiles with warnings as errors and no Elixir/Station dependency.
Both languages pass the shared typed/raw schedule: native classification, exact
seedless retry, rejected non-send/noncanonical material, caller/task death during
accepted I/O, responsive joined cleanup with retained receipts, and revoked
retry. The admission proof distinguishes a dead unpublished reservation from an
active worker-owned job. Supervisor start/handle/close and parent termination
join native cleanup. Missing artifacts, native/package/SDK version mismatches,
malformed/duplicate/fractional/oversized/partial/invalid-UTF-8 responses and closed
handles reject. Boundaries use generated schemas and binary JSON keys. Native
shutdown acknowledgement precedes successful child exit; no cancellation is
inferred from local task death. Rebar/Mix registry resolution, Hex publication,
portable artifacts and BEAM allocation-failure injection are not qualified.
The public Station schedule also installs independent Station/native/example
applications and runs both language APIs through the shared authority schedule.
A common Erlang test controller drives adapters using the public Erlang records
and Elixir structs/behaviours; both real language counter CLIs run from installed
artifacts. It covers full-width codecs, all three mutation gates, retained
confirmation, callback throw/exit failures, scoped owner/reentry checks, sticky
read failures, caller kill/stop/join, exact seedless disk recovery, stale/revoked/
expired authority, retained Tables and six owned IPC segments after close.
Original segments are independently decoded with PyArrow; no BEAM Arrow adapter
is selected. Sources are removed after consumer compilation. The builder derives
application metadata from each `.app.src` or Mix manifest.

### Public SDK interoperability

`nix develop .#bindings -c just bindings::sdk-interop` builds all public artifacts,
installs clean external consumers and runs ten counter/query pairs. Every target
is both service and requester in this ring:

`Python → Node/TypeScript → Rust → Ruby → C → C++ → Java → .NET → Erlang → Elixir → Python`.

Each counter path uses the installed documented CLI and a direct authority base
URL with a trailing slash. Fault proxies also preserve the original HTTP request
target, so they cannot mask an incorrectly joined route. The requester exits after
recording its call, reacquires ownership and resumes through a recorded reply of
`18446744073709551615`. Table/query paths use the same public proof adapters around
installed example handlers, restart the requester, and expose original complete
IPC after closing both runners. Independent PyArrow checks three rows containing
null, `i64::MIN`, `i64::MAX` and `9007199254740993`, plus source/destination,
resource and byte-count metadata. The ring does not select optional host Arrow
adapters; those remain in the separate six-segment per-SDK schedules. It covers
ten edges, not all 100 ordered pairs, and does not repeat each fault for each pair.
`public-language-ring` in the [SDK catalog](verification/sdk.json) owns the exact
observations. M9's separate low-level matrix remains executable and passed again.

All artifacts below are version 0.2.0 on Linux x86_64 with their pinned Nix native
closure; the [runtime table](../bindings/README.md#qualification-tools) owns exact
compiler/runtime versions.

| Public target | Installed artifact | Optional host Arrow adapter |
| --- | --- | --- |
| Python | Separate client/Station/native wheels and examples wheel | PyArrow 23 |
| Node.js/TypeScript | Separate public/native npm tarballs and examples package | Arrow JavaScript 21.2 |
| Rust | Versioned crates with separate embedded-native crates and examples | Arrow Rust 59 |
| Ruby | Separate client/Station/native gems and examples gem | None |
| C/C++ | Independent pkg-config prefixes, headers/libraries and C11/C++17 binaries | None |
| Java | Independent client/Station/native/example JARs and POM manifests | None |
| .NET | Independent client/Station/native/example NuGet packages | None |
| Erlang/Elixir | Separate compiled OTP core/wrapper/native/example applications | None |

Public registry publication, Java Maven resolution, BEAM Hex/Rebar/Mix registry
resolution, portable native distributions and foreign Substrate workers are
not qualified. Package guides document current low-level escape hatches and
migration. These tests do not qualify arbitrary callback honesty or I/O isolation.

The [2026-09-26 local record](verification/results/m11-sdk-2026-09-26.json) measured
**3m58.7s** for clean consumer installation and the complete ring,
including 56.8s of installation/consumer compilation.
The authority ran on one CPU; provisioning used the same five-second deadline
as the authority and SDK defaults. The record includes per-pair timing, machine scope,
SDK source revision and proof-source hashes. It excludes artifact builds, other
SDK failure suites, setup and cache transfer, so it is not a full CI measurement.
The `bindings` lane now owns the per-SDK tasks and this public ring. M10's hosted
budgets remain unchanged; their old passing samples do not qualify M11's larger
inventory. New hosted cost measurement and runner optimization remain deferred.

### Local and clean verification

Enter `nix develop` and run `just transit-board::install` at the repository root. `just ci` runs the ordinary local
suite. Capacity and reference proofs have extra prerequisites and are separate.

`just check` includes Board contract/validator drift and frontend formatting,
lint, types and unit tests, even for changes made only to shared Zig types or
frontend Markdown. Regenerate deliberately with `just transit-board::generate`;
use `just fmt` to fix formatting.

Before pushing committed work, run `just ci-clean`. It refuses uncommitted source
changes, clones the exact HEAD into a temporary directory, installs the locked
frontend dependencies, and runs the same core/experience/bindings task inventory as hosted CI. It inherits the
Nix store and global compiler caches, but no checkout build outputs, launcher
state, dotenv file or `node_modules`. Successful runs remove the temporary clone;
timing/completion evidence survives under `.cache/ci/clean/`;
failed runs retain it for diagnosis and print its location. The local launcher proof must use its
selected artifacts; a binary left in the developer's `zig-out` cannot mask an
undeclared dependency. Compose explicitly builds a native caller for its
host-side stale-credential check. The browser proof remains a separate
`just transit-board::browser` step, as it is in hosted CI; neither command
qualifies the separate reference or physical-capacity profiles.

Use `just ci::complete` or `just ci-clean --complete` to include Chromium in the
same invocation after `just transit-board::browser-install`. `just test::unit`
only runs library/protocol tests; `just test::build` separately compiles the
application and probe entry points formerly hidden in that unit target. Core CI
runs both and retains standalone package checks.

| Evidence | What it proves |
| --- | --- |
| `just check`, `just test::packages` | Independent package composition; signed requests/current grants; one conditional successor; ordered input, invalid proposals and blocked failures; runtime fencing; bounded clocks, settlement, closure and outboxes; shared valid/invalid JSON traces and bounded view encoding |
| `just test::callers`, `just contract::check` | Runnable counter and byte-log examples use the same generic node; opaque bytes, state revisions, atomic outputs, denied effects, lost commit responses, ownership replacement and restart recovery; generated schema matches public types |
| `just test::storage` | Disk WAL SIGKILL/restart; competing authorities, lost receipts and revoked grants; 100 inputs beyond the 16-record window; checkpoint/trim with pending effect/outbox/control evidence; live authority catch-up; immutable payload deletion after a lost receipt; native long-poll/offset continuation |
| `just test::state` | Signed KV/association reads, current independent grants, immutable read views, exact retry, two Zig caller activations, disk recovery, and clock-independent opted-in background reclamation |
| `just test::service` | Real signed ingress/read revocation/key renewal, request deadlines and paused-worker fencing; Python/Zig wire vectors; actual-clock background expiry/trim; synthetic external I/O with paused dispatch, late results, unknown closure and no replay sends; background payload deletion preserving default-retention bytes |
| `just test::capacity` | Real ENOSPC on an owned ext4 image; release of preallocated control space; closed admissions, preserved/drained backlog, revocation/expiry/closure/checkpoint and restart; completed maintenance issues no further storage mutations |
| `just test::deployments` | Rendered/linted Transit Helm chart; explicit bootstrap, existing credential references, retained/reused PVCs, private services and network policies; unsupported values fail before deployment |
| `just launchers::reference::infra-up`, `just launchers::reference::images`, `just launchers::reference::test` | Real provider setup; controller crash after creation; backlog wakeup, killed worker and fresh activation; Ursula/authority pod restart; opted-in expiry; blocked overflow stops replacement; gVisor egress/credential bypass denials |
| `just test::runtime-upgrade`, `just launchers::reference::test-launcher` | Fenced same-PID workload changes, provider response loss, complete persistent reference startup, isolated service updates and state-preserving stop/start |

The capacity proof uses a finite allocation and a measured physical reserve;
online expansion and arbitrary write amplification are not promised. Retention
policies are immutable in M1. Checkpoint/trim requires quiescent or explicitly
cancelled mailboxes; pending effect/outbox metadata survives in the checkpoint.
Payload deletion is limited to closed standalone bytes with explicit opt-in and
an unlimited-lifetime owner. Unsupported finite body/dependency contracts fail
before admission. Full compaction, live dependency graphs and backup import
remain later work.

The trusted Linux time source reports synchronization/error bounds; acceptance
uses a validated sample at the compared journal tail, not physical append time.
An authorized external send may occur after closure; its result cannot reopen
Transit. Ursula cursors are cache tokens separate from read positions. The client
model is fixed and continuation verified; the server documentation mismatch is
tracked in [Ursula #317](https://github.com/tonbo-io/ursula/issues/317). This profile
uses verified record positions/offsets and never reuses physical names.
A rolled-back whole-store backup is not an authorized live restore.

Hosted CI runs `just ci::core`, `just ci::experience` and `just ci::bindings`
in parallel, then `just ci::browser` in the experience lane. Locally, `just ci`
loads the pinned bindings tools, runs all three sequentially and records timings
in `.cache/ci/`. The
[toolchain guide](../nix/README.md#ci-lanes) explains cache ownership and the
smaller experience shell. A weekly/on-demand dedicated runner workflow exposes the
reference and physical-capacity proofs. Local runs supply the current runtime
evidence. A passing hosted end-to-end timing and native validation on the other M0
platforms still require their own runners/runs.

Integration tests use Nix-provided Python, temporary directories, and loopback
ports with their own disk Ursula; they never use an existing deployment.
Toolchain smoke checks verify binary execution and first-use Vite+ setup, not
cluster conformance. See the [command reference](../tasks/README.md) for all tasks.

On Linux, `just test::service` limits the harness and its child processes to one
available CPU. This exercises deadline cancellation without spare async workers,
including slow ingress, stalled protocol responses and maintenance storage I/O.
The affinity change is confined to the test process tree; compilation and the
parent shell retain their existing CPU allocation.

The Station ABI portion of `just bindings::native` / `just bindings::test` also
runs on one CPU on Linux, restoring affinity before the remaining language
matrix. It exercises back-to-back exact raw-client retries and Station polling
with bounded native pools. Client unit tests inject unavailable concurrency at
either scheduling slot: transient contention recovers, persistent contention
hits the original deadline, and transport failure is never retried. Those
deterministic tests run in `just test::unit` and therefore `just check`.

The synthetic effect harness sets `NO_COLOR=1` for captured child logs so exact
error checks work under interactive and forced-color builds too. Its rejection
checks also verify the durable effect state, mailbox counts, and remote sends.

## Kubernetes tooling qualification

`just test::dev-environment` proves that the shell selects the checkout-local
reference config before creation and after removal, honors an explicit override
from a subdirectory, and leaves a personal config untouched.
`just test::kubectl-transit` runs the real Zig executable against a fake kubectl
boundary, without credentials or a cluster. It checks selectors, explicit context
and kubeconfig forwarding, native JSON, invalid flags, read failures, empty and
ambiguous resources, output bounds, a hanging child after both pipes close,
and SIGINT/SIGTERM cleanup for log following and Board forwarding.
The fake child publishes its readiness PID by atomic rename after installing
signal handlers, so the parent cannot mistake an empty file for readiness.
Discovery tests cover aligned columns across namespace lengths, exact
namespace/release selection, useful empty-selection diagnostics, and rejection
of control characters or oversized human-table fields without partial output.

The plugin's [runbook](../apps/kubectl-transit/README.md) and
[full plan](../docs/roadmap/M5.md) define its inspection-only scope.
Toolchain smoke checks verify Kind and both kubectl plugins offline.

`just launchers::reference::test-plugin` passed on Linux x86_64 against the
already-running owned Kind reference. It renders the real chart with overridden
names into a uniquely created namespace, uses an inert node Deployment plus a
CoreDNS HTTP health responder in place of Board, and verifies native discovery,
status/workload views, prefixed logs, configured origin, real port-forward traffic
and listener shutdown after interruption. The fixture proves Kubernetes wiring,
not Transit read authorization or execution. Cleanup verifies the namespace
UID before deleting only test resources. Existing reference workloads are not
restarted. Plain `kubectl get nodes` and packaged `kubectl ate get workers` also
succeeded through the environment's default reference kubeconfig.

`just check`, `just doctor`, the offline proofs and chart validation passed;
`nix flake check --all-systems --no-build` evaluated all configured systems. Native
macOS execution and complete reference recovery after these tooling changes
remain separate qualification; a successful inspection is not a recovery proof.

## Launcher qualification

Stable topology lives in root [process-compose.yaml](../process-compose.yaml),
[docker-compose.yaml](../docker-compose.yaml) and
[charts/transit](../charts/transit/README.md). Integration proofs consume these
files directly; generated private files contain only installation-specific
values, service configuration and provisioning material. The reference proof
installs/upgrades the chart, including its WorkerPool and optional Board and
maintenance resources. Provider setup and adversarial fault injection stay in
the harness.

`just launchers::local::test` and `just launchers::compose::test` exercise the
real launchers in uniquely named installations, with disk-backed Ursula and
the actual node, maintenance process, counter and Board. Both passed on Linux
x86_64. The native proof is part of `just ci`; Compose remains an explicit
Docker-dependent check. The proof checks:

- Direct Board access and the inspection-only upstream principal; private
  credential files and secret-free status/log output.
- Seed inputs admitted once, same-ID send retries returning the same receipt,
  conflicting retry rejection, and resumption after a lost operator receipt.
- Pending input surviving caller replacement, same PID with a fresh generation,
  and rejection of the old caller's actual credentials.
- Full stop/start with unchanged state, realm and keys; independent storage,
  node and Board restarts; no fresh bootstrap when established WAL is missing.
- Refusal to reset running resources, adopt an occupied port or running
  installation, or reactivate a permanently retired PID.
- Reconfigure an existing Board listener/public origin without resetting its
  realm or keys; probe through the correct Host header without public DNS.
  Remote HTTP requires explicit development opt-in; wrong Host/Origin still
  fails while direct reads succeed without a Board credential. Ursula/Transit keep loopback publication.
  Native Board must become ready in Process Compose and stay alive beyond the
  original 30-second probe-failure window.
- Local and Compose foreground startup stream service output and manager/container
  exits; a killed Board stays diagnosable across status calls. Other terminals can send and
  restart while `up` is attached. Ctrl-C, termination during startup, and failed
  recovery stop only the owned services and preserve the installation's data.
  Compose also checks detached startup and that a delayed foreground cleanup
  leaves a newer replacement stack running after another terminal's `down`/`up`.

Successful proofs stop/remove only their owned resources and delete their test
state. Failed proofs preserve private evidence for inspection after cleanup.
These tests establish development workflow behavior, not Substrate isolation,
clock accuracy, finite-capacity reserves, remote Docker support, or production
deployment safety. Compose uses ordinary bridges with loopback publication;
native code runs as the developer. See [launcher limits](../launchers/README.md).

Initial checks caught premature local readiness using a previous activation's
config, Docker internal networks suppressing host port publication, private build
output permissions preventing non-root execution, and a Board config mount
colliding with its executable path. Readiness now requires fresh worker config;
images place executable files under `/bin` with explicit executable permissions.

## Incremental development and workload upgrades

The local/Compose launcher proofs also build candidates without touching running
services, verify no-op updates and selected-version restart, interrupt an apply
and resume its saved target, replace Board alone, and update the counter without
replaying committed inputs. Foreground logs remain attached across replacement.
Native candidates use a different optimization build; image candidates add a
unique image label around the real executable. This proves deployment identity
and recovery mechanics, not compatibility of arbitrary edited application code.

Core tests exercise the public `runtime_upgrade` transition: scoped grants,
stale revisions/workloads, incompatible declared code/state revisions, retirement
and the work cutoff. Pending input/turn permits/effects survive the transition;
old owners and reused worker identities cannot activate or commit. Disk tests
checkpoint and trim with an unresolved upgrade, recover it, and reconcile
provider suspension after retirement without reviving execution. The optional
binding marker is omitted when absent to preserve existing checkpoint bytes.

`just test::runtime-upgrade` uses the real node/controller with a fake provider
CLI boundary. It rejects stale controllers and replacement Actor UIDs, then
simulates a completed template switch whose response is lost. A fresh controller
observes the target without switching it again. `--check` leaves protocol and
provider state unchanged. The Nix-packaged CLI extension separately tests
UID/template/suspension validation and version conflicts.

`just launchers::reference::test-launcher` uses a newly owned namespace on the
existing reference cluster. It provisions the complete stack, changes Board
without replacing the node/Ursula/maintenance/controller pods, removes an old
Board viewer-key Secret field while preserving its Transit seed, verifies direct
inspection without a viewer credential, admits input while
the Actor is suspended, and deploys a different counter image through the real
guarded Substrate API. PID and Actor UID remain stable; worker UID and activation
generation change. The queued input commits once. Authority restart and full
application stop/start preserve state, followed by owned-resource cleanup.

Qualification found that private build contexts could give the controller's Nix
store directory mode `0700`. Image assembly now sets directory/file permissions
explicitly, and controller readiness exercises the packaged provider CLI instead
of assuming a running container is functional. Reference cleanup verifies saved
template identities before deletion; Substrate refuses to delete a nonempty
atespace. Application `down` also waits for the prior worker to disappear before
another start may request a fresh activation.

The real reference upgrade and cleanup proof passed on 2026-09-24, alongside the
local suite, Compose launcher proof and focused protocol/provider/chart proofs
on Linux x86_64. These checks do not rerun or replace the separate
M1 capacity and adversarial isolation qualification. The persistent reference
launcher uses the default Kind CNI and does not claim the additional Board
firewall confinement supplied by that isolated proof.

## Service and reference evidence

`just test::service` exercises actual signed HTTP ingress, PID-scoped reads,
key rotation/revocation, slow-body deadlines, and paused/replacement workers
against disk-backed Ursula. Authority and storage restart preserve state and
revocations. This loopback proof does not establish deployment network isolation;
see the [service profile](../contracts/SERVICE_V2.md).

`just launchers::reference::test` runs the fixed counter via the pinned Substrate gVisor
runtime on an owned Kind cluster. A controller crash after Actor creation is
reconciled without a duplicate resource; killing the real worker preserves the
PID/Actor and rotates worker identity and ownership. Ursula and authority pod
restarts preserve state, and separate maintenance expires an opted-in process.
The sandbox probe first reaches Transit, then verifies denied raw Ursula
read/write/admin access, direct IP access, CONNECT tunnelling, and Substrate and
Kubernetes APIs. Host spoofing reaches only Transit's fixed NotFound handler.
Known credential/control mounts are absent or inaccessible. These claims cover
the configured fixed images, private trusted cluster network and pinned runtime;
they do not establish arbitrary native-handler determinism or protection against
privileged administrators. Public ingress TLS and broader runtime support remain
outside this reference slice.

## Failed application turns

Caller-reported counter overflow records a blocked head input and fences its
owner. Unit tests reject failure reports that change state or emit outputs;
signed-service tests preserve pending input across restart and permit explicit
termination. The counter worker also reports malformed application bytes as a
blocked failure. Transit does not verify the caller's arithmetic or failure claim.
Runtime reconciliation uses that durable failure to stop replacement; its cluster test also checks a
stable generation after shutdown. This bounds retries of the fixed reviewed
handler; arbitrary plugin execution and general Station restart policies remain
outside this profile.

## Capacity and deletion evidence

The [bounded capacity profile](../packages/zig/transit-core/docs/authority.md#finite-admission-and-control-capacity) has a
real ext4/ENOSPC proof in `just test::capacity`. Closed admissions survive restart;
accepted input is preserved, and releasing only a preallocated reserve enables
revocation, opted-in expiry, unknown closure, backlog completion and checkpoint/
trim. The recorded bounds and measured amplification apply to the specified
single-node fixture, not arbitrary disk writers, topologies or unlimited faults.

Immutable standalone payload tests add whole-stream deletion through the pinned
client. Owner/PID and current grants fence retirement; publication, explicit
deletion opt-in and permanent owner retirement are prerequisites. Disk restart
after DELETE but before outcome recording recovers from a tombstone in the
separate control checkpoint. Background service maintenance completes deletion
while preserving default-retention bytes. Late publication cannot reopen a
retired payload. This profile rejects finite owners and live dependencies;
unresolved creation cannot be mistaken for safe deletion or retried blindly.

## Authority, effects, and outbox evidence

Implemented evidence: `just test::unit` exercises request signatures, realm/PID grants,
key replacement, retry identity, ownership, stale state revisions, ordered input, and
retirement. `just test::storage` repeats competing transitions, revocation, lost
receipts, and replay across a real Ursula SIGKILL/restart, with a 100-message
backlog and a 16-record read window. Application logic is absent from the
authority and its replay path.
Further SIGKILL boundaries exercise checkpoint publication before trim, retried
trim, and recovery after prefix removal with new pending input in the tail.
Effect tests additionally prove intent validation, revocation racing dispatch,
authenticated observations, and one mailbox admission per result. Disk restart
and prefix removal preserve unknown attempts; late evidence after caller
termination cannot revive application execution. No external I/O is invoked.
The separate service proof now adds actual I/O through a trusted Zig synthetic
executor: successful result admission, pause after authorization, late response,
and executor death after remote acceptance. A fixture records exactly four
requests across these schedules; fresh executors and checkpoint/trim/restart
cause no additional sends. Closed attempts reject late outcomes, including when
the authorized executor starts its request after closure. This demonstrates the
external limit, not remote cancellation or a general HTTP connector.
Closure tests exercise both winners of the result/closure race, lost
acknowledgements, and unauthorized closure. Real disk restart and trim preserve
closed unknown outcomes and reject late observations even while the caller lives.
Outbox tests cover ordered routes, partial fan-out, denied/expired destinations,
revocation racing delivery, and cancellation of undelivered outputs. Disk restart
and prefix removal preserve pending payloads; a lost delivery receipt cannot
admit the same output twice. Replay verifies explicit admission metadata so
denied deliveries cannot masquerade as mailbox messages.
These are local single-node results, not the Kubernetes/Substrate isolation proof.

## Time and maintenance evidence

The time interface and finite-policy transitions now have executable proofs:
missing/uncertain time, rollback, delayed maintenance, permit recovery, deadline
closure, and observation-budget exhaustion. A disk-backed fixture settles a
preauthorized turn after its work cutoff, then expires its PID and trims history;
restart preserves both retirement and the time high-water mark. Time is controlled
in this fixture. `just test::service` additionally exercises Linux's synchronized
clock and a separate maintenance process: opted-in expiry, explicit cancellation
of unfinished input, checkpoint/trim while ingress remains live, and permanent
retirement after authority/storage restart. It requires the host clock to report
an error bound within two seconds; the fixture explicitly permits that bound
because a synchronized host can exceed one second between NTP polls. Controlled
clock tests retain exact rejection boundaries. Other platforms exercise explicit
retirement and cleanup without claiming a supported finite-time source.
The [deadline investigation](../packages/zig/transit-core/docs/authority.md#deadline-enforcement)
defines the tested acceptance-time and closure contract. A physical
storage-write cutoff at the earlier work deadline is no longer the target.

## Extending the proof

The M1 mechanisms above now have concrete implementations and adversarial
results. Extending them to general behaviors, connectors or another storage/
runtime profile requires preserving these contracts and adding its own evidence.
A failed proof requires revising the owning design, not relabeling a weaker
implementation as conformant. The client cursor-model bug and separate upstream
documentation mismatch are recorded in the [backend README](../packages/zig/transit-backend-ursula/docs/upstream.md#client-integration-surface). The corrected
client proof verifies offset-plus-cursor and record-plus-cursor continuation;
Transit's journal reads use record positions.

## Independent caller evidence

`just test::callers` launches the actual `example-counter` and `example-byte-log`
binaries, each importing only `transit-client`. Application-independent Zig
probes perform rejected proposals and state assertions; Python injects faults.
The counter is shared with the service and reference proofs. No test driver
executes a separate copy of application logic.
The same node binary accepts both, records opaque state and atomic outputs,
rejects stale revisions/skipped inputs/unauthorized effects, and recovers through
authority and disk Ursula restart. A proxy drops successful commit responses and
injects malformed unavailable responses on reads and commit retries;
retrying the identical pending request returns the original receipt. Replaced
activations fail locally and at signed ingress. Recovery verification does not
execute either application. `just contract::check` checks that the committed
binding schema exactly matches the public types; shared fixtures check signing.

## Physical capacity profile

The capacity proof requires Linux Docker with privileged-container support and
at least 2 GiB of free disk for its temporary regular image file. It uses pinned
Nix filesystem tools and the official Ursula image; it formats no host block
device. Its mount/loop device belongs to the owned container, which is removed
after the proof. It runs in the opt-in reference CI workflow, not hosted `just ci`.

`just test::capacity` proves the `N=256` profile against the pinned official
Ursula image on an owned 2 GiB ext4 filesystem, with a physically allocated
1 GiB reserve file. It fills only that filesystem, observes real `ENOSPC` and
Ursula's disk-pressure write rejection, and releases only the reserve. The filler
stays in place while Transit revokes a grant, expires an opted-in PID, closes an
unknown attempt, drains the unlimited PID's accepted backlog, and checkpoints
and trims. SIGKILL/restart preserves retirement, closure, and closed admissions.

The fixture uses 251 post-ceiling records. The v2 run grew WAL allocation by
176,128 bytes during control recovery; current measurements are emitted by the
recipe. The conservative bound
was 3,905 records (31,989,760 bytes plus a checkpoint) in M1;
the [M8 proof](#m8-runtime-readiness) records the current expanded bound. The 1 GiB physical reserve is
a tested envelope for this configuration/schedule, not a universal filesystem
or Ursula write-amplification guarantee. The fixture asserts control growth
stays below 128 MiB and free space remains above the 32 MiB resume threshold.
Keep one maintenance writer and bounded authority concurrency; unbounded crash
loops, unrelated disk writers, disk loss, other topologies and larger allocations
need separate qualification. An absent/exhausted reserve fails closed and needs
operator capacity recovery; it does not create expiry permission.

Completed maintenance now verifies the existing checkpoint/floor before writing.
After restart the adapter uses only GET/HEAD for that already completed intent;
it does not repeatedly publish or trim. Ursula can still change its internal WAL
during reads/recovery, so raw WAL equality is not a valid no-mutation assertion.
The fixture records adapter HTTP methods and stores measurements in the ignored
`.cache/capacity-evidence.json`.

The [core capacity contract](../packages/zig/transit-core/docs/authority.md#finite-admission-and-control-capacity)
defines the admission ceiling, permitted drain work, and accepted-record bound.

## Recording new evidence

Record tested pins, topology, failure boundary, authoritative operation point,
input schedule, and durable outcomes. A workflow definition is not evidence of
a remote run. The [reference runbook](../deploy/reference/README.md) records its
runner requirements and owned-resource cleanup. Keep synthetic endpoints, test
keys, transcripts, and private proof files out of Git.

Benchmarks record compiler/tool versions, hardware, dataset, concurrency,
durability settings, and p50/p95/p99 latency together with throughput and memory.
A failed proof requires revising the owning design, not weakening its label.

## Public inspection

`just test::inspection` checks scoped discovery, signed queries, fixed pages, cut
expiry, revocation, and disk recovery through the node and public client. Core
unit tests inject final-tail and trim races, test bounded sparse scans, and verify
that scoped outbox/history projections do not disclose hidden endpoints.

## Board qualification

`just transit-board::check` checks exact Zig/OpenAPI regeneration, generated TypeScript and
standalone validator drift, strict TypeScript, Vite+ formatting/lint and unit tests.
`just transit-board::test` runs Zig ingress tests and `tests/board.py` against disk-backed
Ursula. A copy of the Board binary runs alone in an empty directory with an empty
executable search path, serving embedded assets and the exact OpenAPI artifact.
An independent Python consumer follows process/output/effect evidence; generated
JS validators consume actual Zig responses and reject malformed identities/data.

The API proof checks current grants, scoped lists and edges, unsafe deployment
principals, missing API/asset routes, Host/Origin/forwarded-header rejection,
direct reads without viewer credentials, no cookies or session/mutation/proxy routes,
closed-unknown effects, blocked inputs, history cut/trim gaps and storage restart.
Core tests deterministically inject revocation/tail and physical-trim races.
Board projection tests reject mixed-resource pages before they could overflow
the 32-edge budget. Revoked Transit grants reject reads even with old Board
cookies or arbitrary bearer headers; these headers stay out of diagnostics.
The initial local load run (Linux x86_64, pinned tools) completed five control
writes during 25 refresh requests; the maximum observed latency was 43 ms.
Requests exceeding Board's 10 upstream reads/second admission rate were rejected.
A slow incomplete Board request also left the authority available. This is a
bounded reference measurement, not a throughput/fairness or latency guarantee.

`just transit-board::browser-install` and `just transit-board::browser` run pinned Chromium against
that same real binary/API. Checks cover direct access, typed runtime validation, nested
routes/lazy assets, arrivals/departures and uncertainty, keyboard focus through
polling, escaped opaque payloads and authorized state-resource views, denial clearing and connection retry,
and absence of Board cookies or browser storage. Axe checks the journey against WCAG A/AA;
this does not replace a full assistive-technology audit. Local screenshots/traces
remain ignored under `.cache/`. Remote TLS termination and identity federation
are outside this private/loopback profile.

The Kubernetes/Substrate run on 2026-09-23 passed using the pinned images/tools.
Board observed PID 1 at generation 2, then the same PID at generation 4 with a
new worker incarnation. After disk Ursula and node replacement it still exposed
state `1153`; it also exposed permanently expired PID 48. Retained history began
at position 52 after checkpoint/physical trim; inspection reported
`prefix_reclaimed`, and later PID 1 termination remained visible. This preserved
the existing M1 controller-crash, worker-recovery, expiry and gVisor isolation
proof. Local evidence is in ignored `.cache/reference/proof-d585cab0/evidence.json`;
its enclosing directory contains private disposable keys and must not be published.

Board ran as a non-root, read-only-filesystem pod without a service-account token,
using only a dedicated inspect grant. A second unprivileged container in that
pod's network namespace first reached Transit, then received transport denials
for raw Ursula service/pod/admin endpoints and actual Substrate/Kubernetes API
addresses. The default Kind CNI does not enforce NetworkPolicy: the owned proof
uses an init-container firewall, permitting Transit, DNS and loopback Board
port-forwarding. Production clusters need equivalent enforced egress policy;
the fixture is not a portable NetworkPolicy conformance claim. The cluster and
registry were removed through the ownership-checking teardown command.

Qualification caught and corrected three assumptions: HTTP header views cannot
be accessed after Zig's body reader changes state; Kubernetes port-forwarding
needs a loopback exception inside the confined pod; and Substrate's headless API
service must resolve to a ready EndpointSlice address for a valid denial probe.
The probe rejects DNS errors/timeouts as evidence of egress denial, so an invalid
target cannot produce a passing isolation result.

## Service instrumentation qualification

`just test::telemetry` tests the real bounded stderr writer on one CPU (Linux):
10,000 completions with logging disabled, drained, stalled and closed pipes.
Every completion reaches local metrics despite log drops; stdout remains JSON.
The initial debug build measured 0.12–0.42 seconds total per scenario, including
100 ms of deliberate wait and up to 200 ms flushing; emission was 9–74 ms.
These are measured proof results, not throughput targets or arbitrary I/O guarantees.

`just transit-board::test` also asserts fixed routes, request/timeout outcomes, ignored
public trace headers, quiet successful probes and credential/query redaction in
real service logs. See [telemetry](../packages/zig/telemetry/README.md) for limits.

`just test::observability` follows a real Board request through the public client
and node, checking distinct correlated spans, existing receipt retries, revoked
reads, duplicate/untrusted trace headers and absence of credentials/state.
No raw storage dependency is introduced into Board and no durable schema changes.

Storage/recovery spans are checked as children of the actual authority request.
The existing disk, service, maintenance and caller proofs run with instrumentation
active. Maintenance deadline checks inspect the structured error field. The
bootstrap proof separates stdout and stderr to verify the machine interface,
while the provider reader continues to identify bootstrap records in combined logs.
The stalled-writer proof shrinks its Linux pipe to 4 KiB and asserts the writer
is actually blocked before shutdown; it cannot pass merely by fitting all logs
into the OS buffer.

The observability proof also runs the real node on one CPU with unread stderr:
after filling its 4 KiB pipe, an incomplete HTTP request still hits the 800 ms
deadline, and a signed input plus exact retry still returns one durable receipt.
This qualifies control progress under diagnostic pressure, not just logger exit.
Replay and retries are observed as recovery or receipts; no metric claims they
are fresh commits. No protocol, signature, or durable-history schema changed.
The caller proxy proof drops a response after a real commit, then injects a
malformed 503. Both attempts remain `uncertain`; only the exact successful retry
reports `receipt`. Each attempt has a distinct span linked to the same proposal.
A focused invariant test preserves a known receipt when the response write fails
and checks that a new service instance resets its local counters.

`just launchers::local::test` and `just launchers::compose::test` passed with JSON
request records and saved per-service settings across restart. The native proof
checks visible foreground Board logs, manager-log rotation through three cycles,
two bounded backups and configured child-log rotation. Compose checks each
service's environment and Docker log budget. Native copy/truncate can lose
diagnostics and overshoot between checks; it is not a filesystem quota.

The Kubernetes/Substrate observability run passed the existing controller-crash,
worker replacement, disk Ursula/authority recovery, expiry and isolation proof.
It also checked JSON events from Board, Transit, maintenance and the controller,
and the effective kubelet rotation settings (5 MiB, three files). Evidence is
in ignored `.cache/reference/proof-7f71fb4c/evidence.json`; its enclosing directory
contains private test keys. Provider-owned log/snapshot stores and host proof
files are outside the CRI log budget.

Qualification exposed a packaging assumption: a Zig artifact reused from a
private launcher cache can have mode `0700`. Reference image assembly now sets
published executable modes explicitly to `0755`, so the non-root container user
can execute them. The controller-crash fixture now waits for the structured
`created` progress observation; continuous controller stdout is no longer used
as a diagnostic interface. `--once` retains its single machine-readable result.

## M7 state resources

The bounded [state v1 profile](../contracts/STATE_V1.md) is qualified through
`just ci`, `just transit-board::browser`, `just launchers::compose::test` and
`just launchers::reference::test-launcher` on x86_64 Linux (2026-09-24).
`just test::capacity` also passes with the expanded 3,917-record control reserve: real
ENOSPC, control progress, checkpoint/trim and disk restart. Focused
state, unit and disk proofs were rerun after final authorization/recovery fixes.

Coverage includes:

- Core adversarial tests: atomic mutations/input/outputs/effects; uncertain
  receipts and competing revisions; stale ownership; association CAS; writer
  exclusivity and shared snapshot reads; hidden metadata/value permissions;
  revocation before commits, reads and receipt disclosure; required/optional
  expiry; full read-view capacity and reserved retirement/reclamation progress.
- [state.zig](state.zig), included in `just test::storage`: real disk Ursula,
  competing conditional appends, abandoned private preparations, lost receipts,
  SIGKILL/restart, durable view recovery, checkpoint publication/trim, and 32 live
  keys beyond the eight-entry page and 16-record replay buffer. It preserves
  unchanged values, deletes/recreates a key, permanently retires required
  dependents and reclaims opted-in data. Receipt permissions survive checkpoint
  recovery even after their view-opening records are trimmed.
- [state_api.py](state_api.py), `just test::state`: the real HTTP/CLI boundary and
  counter executable; metadata/value grants, exact view revisions, pagination,
  changed cuts, state retention across two activations and unchanged legacy
  inline bytes. A clockless realm proves zero-age opted-in background cleanup
  and maintainer restart without rediscovering or resurrecting removed data.
- Board service/browser proofs: no application lens/configuration/API field;
  generic resource and association pages, explicit hex entry reads, independent
  disclosure permissions and filtered relationships. Existing effect, journey,
  stale-observation, safe-rendering and accessibility checks continue to pass.
- Local, Compose and reference launcher proofs: new installations provision a
  required KV resource; worker replacement, compatible same-PID upgrades, queued
  inputs, authority/storage recovery and stop/start preserve its data. Existing
  manifests retain inline-state behavior; this is not an automatic migration.

On the pinned x86_64 Linux Debug profile, fixed structure sizes are 158,560 bytes
for the complete catalog (four resources, four captured views and receipt rights),
364,848 bytes for core state, 17,224 bytes for one captured view, 7,800 bytes for
one public state page and 67,688 bytes for the Ursula replay store. These are
layout measurements, not total RSS or throughput claims. Parsing, candidate
copies and serialized I/O need additional bounded memory. Maximum record and
checkpoint tests retain the 8 KiB / 1 MiB limits.

The first larger catalog exhausted Debug stack frames in checkpoint verification.
The selected profile remains four resource identities / 32 live keys each;
large checkpoint fields now parse into allocated storage and the backend returns
an owned parsed checkpoint. The service and storage recovery proofs exercise
that path with default stack sizes. No stack-limit override hides the failure.
Simultaneous launcher builds also exposed shared frontend-output deletion;
embedded Board builds now use separate temporary output directories.

M7 does not prove an unbounded KV index, per-key TTL, writer transfer, multiple
resources in one transaction, online migration, arbitrary native determinism,
or global distributed transactions. History trimming still requires quiescent
or explicitly cancelled mailboxes and every resource's opt-in/minimum age.
Resource identity/tombstone evidence is retained permanently within the bounded
realm profile. Expiry can make data unavailable while unlimited history keeps
its bytes; it never promises erasure of external copies.

## M8 runtime readiness

M8 supplies the generic runtime prerequisites for Station. Qualification passed
on x86_64 Linux on 2026-09-24 with the pinned toolchain, including the full CI,
browser, physical-capacity, three-launcher and Substrate isolation suites. Focused
controller/caller checks and foundation checks were rerun after the recovery fixes.
Its contracts are
[authenticated inputs](../contracts/TRANSIT_V2.md),
[scoped delivery](../contracts/SERVICE_V2.md),
[catalog collection](../contracts/CATALOG_V1.md) and
[lifecycle controls](../contracts/LIFECYCLE_V1.md).

| Proof | Evidence and command |
| --- | --- |
| Authenticated origin | Core checks authority-derived external/process/effect envelopes, replay mutation rejection and retained origin after collection. Shared `inputs-v1.json` and canonical signed command fixtures are validated by `just check`. |
| Actual caller exchange | `just test::callers` runs the counter and byte-log executables with `transit-delivery`, drops/malforms acknowledgements, checks exact retries and restarts the courier. Scoped delivery reads expose counts/sequence, not application payload. Core tests cover destination scope, revocation and terminal denial. Delayed counter activation stays within the bootstrap log bound even at debug verbosity. |
| Sustained working catalogs | Unit and disk proofs allocate 257 outputs/effects and 65 process/resource identities while collecting eligible entries, exceeding the previous lifetime ceilings. Pending outputs, uncertain attempts, live dependencies and default unlimited retention remain protected; old IDs/results/owners cannot revive. |
| Lifecycle recovery | Core tests cover lost creation/resource acknowledgements, missing required associations, scoped administration, exact failed-input retry, stale generations, suspension bounds and provider-stop/activation fencing. `tests/readiness.zig` restarts during initialization, completes it after recovery, checkpoints a blocked input, retries that head and expires a suspended process after trim/recovery. |
| Disk/capacity | `just test::storage` runs readiness with disk Ursula, SIGKILL, checkpoint and prefix trim. `just test::capacity` fills an owned ext4 image: at admission ceiling 256, the reserve bound is **4385 records**, with control progress and restart verified. This replaces the pre-M8 reserve estimate for the current binary. |
| Deployment | `tests/readiness_client.zig` imports the public client only. Local, Compose and reference launcher tests run it against real services: queue an output while delivery is stopped, restart courier and node, reject an identical externally submitted forged reply, accept the process-origin reply and inspect generic Board evidence. The harness never delivers that output. Reference qualification also queues input
during a bounded logical suspension, confirms provider stop, replaces worker
capacity and resumes the same PID/Actor with a fresh activation. Automatic pool
recycling is outside the controller's current rights and this proof. |
| Inspection | Core history queries preserve retained events for collected PIDs without inventing mailbox disposition. Board exposes lifecycle actions, initialization/suspension bounds and a collection warning. Generated OpenAPI/validators, API tests and the real browser suite check the shared surface. |

Run `just ci`, `just transit-board::browser`, `just test::capacity`,
`just launchers::compose::test` and `just launchers::reference::test-launcher`.
The existing `just launchers::reference::images` / `just launchers::reference::test`
proof additionally checks controller/worker loss, persistent authority/storage
restart, expiry, poison-input shutdown and actual sandbox/Board bypass rejection.
Its diagnostic check covers every remaining signing seed after removal of Board
viewer keys. Pod readiness is distinct from host-forward availability; the Zig
readiness caller retries unavailable reads without treating them as progress.
Launcher qualification uses separately owned installations and retains failure
evidence; it must not upgrade a developer's existing live realm implicitly.

The measured disk-proof structures on x86_64 Linux are: state catalog 158560 bytes,
core state 433472 bytes, captured view 17224 bytes, state page 7800 bytes and backend
store 68968 bytes. These are type sizes, not total process RSS. Catalog capacities
remain 64 concurrent processes, 128 effects, 256 outputs, four resources, four
views and 16 principals. Collection is opt-in; unlimited default history can grow
on disk. Automatic collection conservatively waits for delivered inputs to be
consumed; explicit collection can prove a retained self-contained origin earlier.
Whole-realm checkpoints require quiescence. No production throughput, recovery-time,
HA, distributed retention or principal reclamation claim follows from these proofs.
Station owns durable wait/correlation layouts, child policies, timers,
lifecycle watches, restart budgets and versioned framework descriptors.

## M9 Station, bindings and Tables

The final implementation at `1462041` passed `just ci-clean` with no inherited
checkout build outputs. All target languages passed in that run. Embedded Board
passed its five Chromium checks; the Station local, Compose and Substrate
profiles passed their separate recovery/upgrade proofs. `just doctor` and
Actionlint also passed. This records local qualification, not a hosted CI speed
measurement or validation of other operating systems/architectures.

The Linux x86_64 profile uses the locked Zig 0.17 compiler, the pinned
`rupurt/zarrow` and `rupurt/zarrow-compute` forks, disk Ursula, and the real public
authority/courier. Framework logic remains in Zig; no language-specific server
route or second authoritative task/state store is introduced.

| Proof | Evidence |
| --- | --- |
| `just test::station` | Three behavior roles, two-Table atomic turns, exact retry after receipt loss, worker/store restart, source-authenticated calls/replies, captured Arrow publication/consumer restart, service-policy revocation, registry rebind with the original PID retained, timed waits/late-result closure, poison-head supervision and independent lifecycle control |
| `just test::station` lifetime schedule | Required PID-owned Table state survives recovery; suspension beyond a dependency is rejected; opted-in expiry permanently rejects activation and permits background reclamation, including after authority restart |
| `just bindings::native` | C/C++/Python real callers; shared ABI exact frozen request recovery after every handle is lost; failed-turn rollback, stale/revoked/retired callers, wide correlations, malformed native-port input, asynchronous cancellation and owned cleanup |
| `just bindings::native` materialization schedule | Duplicate source admission/commit, update/delete, physical checkpoint/trim, reinsertion in the tail, disk/node restart and an independent Arrow aggregate over only current rows |
| `nix develop .#bindings --command just bindings::test` | C, C++, Rust, Python, Node, Java, .NET, Erlang and Elixir each run service and requester roles across language pairs; fresh hosts resume captured results; exact `9007199254740993` values survive Arrow; managed/port tests cover bounded input, busy handles, host/caller loss, responsive schedulers and cancellation/cleanup |
| `just test::unit`, `just test::packages`, `just test::arrow` | Private batch rollback, capacity and schema checks, all admitted Arrow types/null/empty/overflow behavior, C Data/C Stream release ownership, exact source basis and no enabled rewrites, cancelled queries, maximum 672-byte captured reply, malformed/duplicate/missing fragments and no prefix completion |
| `just transit-board::test`, `just transit-board::browser` | Versioned framework metadata with source PID/resource/key/revisions; unknown versions fall back safely; no application-state decoder |
| `just launchers::local::test-station`, `just launchers::compose::test-station`, `just launchers::reference::test-station` | Same three-process scenario, scoped service roles, registry/call/Arrow exchange, Board provenance, worker recovery, compatible upgrades of all three workers with PIDs/state retained, no-op updates and persistent stop/start |

The reference proof additionally kills an actual Substrate worker pod, verifies
a fresh activation/key while retaining the Actor UID, and upgrades versioned
worker templates through the recorded protocol. It uses the shared Helm chart
with three separate PID-scoped runtime controllers and two framework controllers.
Failed launcher runs retain their own installation; successful ones remove only
their own application resources. The shared infrastructure is not destroyed.

The ordinary CI inventory includes the local Station proof and full language
matrix. Docker Compose and reference proofs require Docker/the provider fixture
and run in the opt-in reference workflow or as explicit qualification commands.
No hosted run-time improvement is
claimed from local measurements; the CI lanes report their individual task times.

Qualification is deliberately finite: four realm resources, 32 entries per
resource, four mutations/outputs per turn, one mutated resource and at most
672 captured IPC bytes. Execution pulls one synchronous batch into bounded
buffers; it has no queued pipeline or parallel in-flight operators. Slow remote
consumption is durable mailbox/result state, not a live Arrow task. No optimizer
rewrite is enabled. Unlimited retention is the default and does not evict old
waits/results when capacity fills. See the [Table guide](../packages/zig/transit-station/docs/tables.md).

Only Zig workers are qualified on Substrate. Client support does not establish
foreign-VM isolation, public SDK releases or non-Linux portability. Logical
supervisor retry also cannot guarantee fresh provider placement; the
[example runbook](../examples/station-ledger/docs/running.md#recovery-and-incremental-work)
records the required operator recovery when Substrate reuses an old pod.
Continuous queries, multi-resource transactions, SQL, Documents and remote
Flight/ADBC remain later milestones.

## M10 verification and scale foundations

The [2026-09-25 growth evidence](verification/results/m10-scale-2026-09-25.json)
records **14 passing samples**: two each at 64/256/1,024 rows with one resident
page, 256 rows with 16 pages, eight retained views, and two public-service offered
loads. All use real Ursula WAL plus pinned MinIO on the checkout's ext4 filesystem,
on a shared Linux x86_64 Threadripper 3960X host (48 logical CPUs, about 121 GiB
RAM), Zig `0.17.0-dev.2267+48abf1a34` and Ursula 0.5.1. Each sample records actual
binary hashes, revision/dirty state and timing boundaries. Six cases ran through
`just test::scale`; the added eight-view case ran twice separately before joining
the executable matrix. These are shared-host observations, not production SLOs.

| Rows / cache pages / retained views | Write plus verification, seconds | Turn p99, ms | Full recovery verification, seconds | Maximum authority-driver RSS, KiB |
| --- | ---: | ---: | ---: | ---: |
| 64 / 1 / 1 | 54.86–57.31 | 952–978 | 4.21–4.58 | 12,596 |
| 256 / 1 / 1 | 109.01–113.49 | 984–1,013 | 14.33–15.19 | 12,596 |
| 1,024 / 1 / 1 | 366.91–366.94 | 1,166–1,315 | 61.64–62.37 | 12,660 |
| 256 / 16 / 1 | 85.31–86.17 | 825–839 | 11.77–12.05 | 12,720 |
| 256 / 16 / 8 | 91.08–92.72 | 780–1,792 | 15.66–15.89 | 12,744 |

The one-page cache remains **8,532 bytes** while retained application values grow
from 16 to 256 KiB, alongside 70 PIDs, 21 principals, six resources and 69
associations. The eight-view driver also checks every retained association after
restart; its timing difference is not solely view-count cost. At 1,024 rows,
engine opening took 1.04–1.06s on first recovery; checkpoint publication took
107–109ms, separately from full verification. Recovery/trim created zero pages.
Ursula peaked around 95 MiB and MinIO around 327 MiB. Write/setup/verification
made 289,558 page requests and attempted 45.09 MB of immutable page payloads,
retaining about 47 MB in cold files. These costs expose substantial index/history
and request amplification despite the fixed authority cache.

Each offered-load run scheduled 48 independent signed requests, then verified
exact retries, control revocation, every drained row and restart digests. With
16-byte uniform updates, one generator worker and 100ms offer intervals, p99 was
3.28–3.42s and control latency 208–238ms. With 256-byte updates, 90% hot-key
selection, four workers and 1ms intervals, p99 was 9.11–9.73s and control latency
805–880ms. All requests were admitted; accepted backlog survived provider/node
loss. Generator queueing is included in latency and was substantial; these
finite bursts do not establish service capacity. Both load cases and all
four authority phases retain process/provider metrics and correctness evidence.
A preceding setup attempt timed out during severe host I/O contention and remains
inconclusive; it is not included in the passing sample count. Two repeats do not
establish stable performance-regression tolerances or cold-run tail guarantees.

`just test::arrow` also qualifies Fuze's incremental engine independently of
Station persistence. Python checks the typed plan fingerprint and 143-byte
progress format; PyArrow decodes variable-sized segments across 70 rows. The
text result totals 16,008 bytes in seven complete IPC segments. Global limits,
count/sum, nulls and exact integers agree across boundaries. Package/root unit
tests additionally reject changed basis/plan/order, signed intermediate overflow,
insufficient workspace/output and cancellation without publishing progress.
This does not qualify durable large-result staging, delivery or recovery; those
remain integration gates in the [incremental contract](../contracts/FUZE_STREAM_V1.md).

`just test::growing-query` (also part of `test::growing-service`) separately
qualifies durable **capture**. Real Zig callers retain a 41-row Table, stage
221-byte fragments, and recover through disk Ursula/node/caller replacement
first during staging, then after the first seal. The first recovery uses one
resident backend page; the remaining capture defaults to 64. Use
`just test::growing-query --finish-pages 1` to retain one page throughout both
recoveries. The proxy loses an accepted staging reply and a seal reply; exact
retry returns the original receipt without rerunning a handler. Each recovered
segment is decoded by independent PyArrow, and Python checks the ordered digest
chain: 41 rows, 9,984 bytes in six segments. The source is released with the final
seal and rejects later reads. The requester's wait is still waiting: capture is
not delivery or acknowledgement. In-memory tests add 70-row private capture,
changed staging, duplicate/future/forged continuation, policy revocation, sticky
read failure, explicit closure and corrupt/missing fragments.

Growing result **delivery** now has both in-memory and real disk/service
qualification. `query_growing_test.zig` drives two independent in-memory
`Store` fixtures as separate producer and receiver peers exchanging real
`QueryDelivery.dispatch` frames through an explicit message queue, matching
the wire protocol rather than calling capture and delivery in the same
process. One run publishes and independently decodes 41 rows across six
segments end to end, closing exactly once before acknowledgement despite a
duplicated fragment redelivery, a forged reply source, and a closed wait
staying closed against a late corrupted resend. A second, focused test rejects
out-of-order/conflicting/premature evidence (`UnorderedResultFragment`,
`ConflictingResultFragment`, `ConflictingResultIdentity`, `IncompleteResult`,
`InvalidArrowResult`) without ever closing the receiver's wait, and checks
cancellation mid-dispatch. `Inspect.segment`
(`packages/zig/transit-fuze/src/Inspect.zig`) independently validates every
received Arrow segment — bounded allocation, schema/row/cell bounds, UTF-8 and
nullability — before its fingerprint enters the chain; it is exercised
separately in `inspect_test.zig`.

`just test::growing-query` now adds `publish` and `deliver` phases to its
existing real disk Ursula/node proof, driving two separate `GenServer.Growing`
instances (sender and receiver) that each explicitly configure
`.query = .{ .workspace, .cancellation }` — the growing GenServer still
rejects these frames by default; nothing wires this in a production host yet.
The proxy loses an accepted publish reply and a receive reply in addition to
the existing stage/seal faults; exact retry recovers all four without
rerunning a handler or reopening released source rows. It also cancels the
sender mid-submit while an authority outcome is uncertain and confirms the
uncertain mutation is retained, not discarded. Independent PyArrow decodes
every segment the receiver durably stored and diffs it byte-for-byte against
the sender's own captured segment, and Python checks the received manifest's
basis/plan/chain/schema against the sender's. One run: 41 rows/9,984 bytes in
six segments; publish took 3.99s and deliver 69.36s on this one-CPU Debug
sample, on top of the existing 8.30s/10.24s/18.14s write/seal/recover. Six
segments against a two-segment credit window means the sender genuinely blocks
and resumes under real cross-process delay here, not just in the in-memory
proof below; these are finite shared-host proof timings, not service SLOs.

Receiver-issued credit (`GQG2`, [`contracts/STATION_QUERY_V2.md`](../contracts/STATION_QUERY_V2.md#flow-control))
is implemented, not just designed: the sender will not start a segment more
than `credit_window` (2) ordinals past the last credit it has observed, the
destination grants credit only for segments it has itself durably sealed, and
a regressing or forged grant is rejected rather than tolerated.
`query_growing_test.zig` qualifies this in-memory — a forged-peer grant is
rejected, a regressing grant errors, a repeated or post-completion grant is
inert, and the two-sided delivery proof asserts exactly one grant per sealed
segment (six, for six segments). [`Delivery.tla`](../tests/verification/models/Delivery.tla)
checks the same shape abstractly via `just test::model-delivery`; it is not
yet wired to a Zig trace replay the way `test::model` is for `Authority.tla`.
`just test::growing-query --finish-pages 1` retains one resident page through
the seal/recover phases instead of the 64-page default measured above; the
first recovery (after staging, before any seal) always uses one page and no
faults or assertions are removed either way. These are finite shared-host
proof timings, not service SLOs or hosted Nix/CI budgets.

The [verification guide](verification/README.md) owns the versioned inventory,
bound audit and generated transition harness. `just test::properties` checks the
real Zig authority against an independent mailbox/fencing/retry projection,
including replay after every step and bounded failure minimization. The initial
21-trace corpus/generation run passed 826 boundaries in 8.46 seconds on this host.
That measures the harness, not service throughput or exhaustive exploration.
The captured-view extension passed 39 saved/generated traces with 1,682
boundaries in 18.91 seconds on this host. It additionally compares atomic KV/input
publication, view release/expiry, clock rollback/uncertainty and current resource
rights. These finite in-memory schedules preserve the real disk and host checks.
The larger run passed 263 traces / 33,250 boundaries in 475.97 seconds. At
`ea62354`, all four compiling guard mutants were detected, with minimized
counterexamples retained by the mutation task.

The [shared SDK scenario contract](verification/sdk.json) now has executable
owners for admission/commit/reply distinctions, same-principal multi-handle
contention, host-loss retry, durable continuation, decode failure, local await
cancellation/disposal and response allocation after commitment.
`just test::client-abi` passed its disk-backed contention and boundary checks;
`just bindings::test` passed the shared host cases and continuation observations
through every existing language pair. Malformed framework input becomes durably
blocked without being consumed. Public M11 SDKs must reuse these scenarios
through their own interfaces; the current matrix qualifies low-level bindings.

M10 is qualified within the [recorded limits](verification/README.md).
CI separates library unit tests from
application/probe builds, avoid duplicate feature-push/PR runs, and select
runtime checks conservatively. Standalone package manifests are compile-checked
with `test::packages-build`; root unit tests own their shared runtime suites, and
`test::compute` separately owns the upstream compute tests. Focused
`test::packages` remains a complete standalone run. `tests/ci_runner.py` exercises actual Git rename/
delete selection, missing revisions, failure propagation and all combinations
of aggregate-gate results. Unknown/shared changes remain full; only foundational
prose-only PRs omit runtime lanes. Main, release tags and merge queues run full.

`just ci::complete` includes Chromium, and `just ci-clean --complete` uses that
inventory on committed HEAD. Each lane records required tasks, completion and
revision beside task timings; successful clean runs preserve these outside the
disposable checkout. Hosted CI budgets and growing-state qualification have
separate measured evidence below; local timings do not qualify massive scale.

The initial M10 model also passed 30,140 states with a four-transition journal
bound and replayed all four removed-guard counterexamples against Zig. The first
CI optimization commit (`b9dd595`) passed `just ci-clean --complete`, including
all language bindings and five Chromium checks; timing and completion metadata
survive under `.cache/ci/clean/b9dd595faade-transit-ci-7c3pzmzd/`.

`just test::pages` qualifies the immutable page primitive with disk-backed Ursula,
cold bounded caches, old roots, unpublished staging and root-only checkpoint/trim.
`just test::pages-cold` separately exercises the pinned S3-compatible cold tier
with owned Docker MinIO and measures both provider processes. The ordinary WAL
fixture disables that tier; it cannot establish bounded provider memory.
The [adapter guide](../packages/zig/transit-backend-ursula/docs/pages.md) describes
measurement fields and their limits. The launcher-default v2 authority retains
bounded catalogs; the explicit v3 authority uses these paged roots. Unit checks also compare randomly ordered updates
and deletion against an independent map and preserve old roots after lost staging
acknowledgements.

The initial [growing authority tests](../packages/zig/transit-core/docs/growing.md)
also cross the legacy process/principal catalogs and retain historical receipts
in immutable pages. They qualify the implemented control transitions against an
injected conditional journal, including lost acknowledgements and stale prepared
roots. State checks also publish rows, input progress and outputs together,
reject staged partial proposals and fence expired required dependencies. Signed
read checks cover bounded current/captured pages, current permissions, stale
ownership/cuts, expiry and hidden association filtering. These engine checks
use injected storage; delivery/settlement also have injected-storage checks.
Station integration has separate service evidence below. Launcher defaults
continue to use v2; each explicitly configured growing capability has its own
proof owner.

An explicit control reserve now has injected-storage evidence too
(`GROWTH-11`, [growing capacity](../packages/zig/transit-core/docs/authority.md#growing-profile-an-explicit-control-reserve-not-a-derived-one)):
past a configured ceiling, sends/spawns/grants/new resources/views/associations
and turns that would emit a new output or effect are refused before
acknowledgement, while ownership reassignment, revocation, retry, termination,
delivery, effect observation/closure, an opted-in checkpoint and output-free
turns keep draining and closing existing work through an explicit reserve band
— until even that is exhausted and every command is refused. A restarted
engine recovers the identical ceiling and reserve state. The signed
`capabilities` query now returns `admission_ceiling` and `control_reserve`
alongside every response's own `position`, checked at three points in the
same test (before, at the ceiling, and past the exhausted reserve) so a
caller can compute remaining headroom directly rather than discovering it by
provoking `AdmissionClosed`/`ControlCapacity`. This qualifies the admission
mechanism and its observability. The additional
[physical-capacity and service/Station proofs](#growing-physical-capacity)
qualify the finite deployment profile separately.


`just test::growing` runs the growing core against real Ursula and a single-page
Transit cache. It crosses legacy process/principal/resource/row bounds, stages
private candidates, rejects stale publication after revocation, injects failure
before append and response loss after real acceptance, and verifies retained
views/receipts/progress/outboxes across SIGKILL. Opted-in root checkpoint/trim
retains all that state and rejects an uncommitted retention intent. It finally
removes page storage in its disposable fixture to prove recovery fails closed.
The [adapter guide](../packages/zig/transit-backend-ursula/docs/growing.md) owns
measurement details and compatibility limits. This is authority/provider
qualification, not node/client/Station support or a scale SLO.


`just test::growing-service` runs an independent Zig caller using only
`transit-client` against the real v3 node, with disk Ursula on one CPU. It uses a
wide principal, six resources and 64 rows, reading individual captured keys and
bounded current pages. A malformed receipt after acceptance survives caller/node/
provider restart as the exact same signed request and receipt; current revocation
then denies both reads and that historical retry. The response validator also
rejects mixed realm/revision, page holes and invalid continuations while accepting
empty filtered catalog pages. No launcher, Station or foreign ABI changes profile
implicitly. Existing v2 ingress and observability proofs cover the shared loop.
The caller also inspects blocked metadata, uses a PID-scoped administrator to
retry the exact failed input and consumes it only after fresh ownership. Core
tests additionally race retry with revocation, recover a lost retry receipt,
reject stale repeated-failure generations, and preserve dependency expiry,
process deadlines and permanent retirement.

The [retained-version proof](../contracts/READ_VERSIONS_V1.md) adds an atomic
pre-write 60-row snapshot to the lost-reply turn. It reads current and retained
state after caller/node/provider restart, fences the old activation and explicitly
declares/releases the version from a replacement. Core checks cover missing
snapshot pages, filtered discovery, source expiry, release and grant changes
between reading and publication. The separate provider proof retains these roots
across actual checkpoint/trim/recovery; it preserves immutable page storage.

The task also runs two real [growing Station callers](growing_station.zig),
retaining 41 typed Table rows and completed calls without reclamation. A proxy
enforces point reads during handlers, corrupts a captured read and loses an
accepted turn reply. A swallowed read failure cannot publish its private work;
the accepted turn retries byte-for-byte without rerunning the handler. After
caller/node/provider restart, fresh ownership fences a prepared old turn and
recovers the unconsumed call without rerunning committed initialization. The
proof uses a bounded 64-page cache for exchange, one resident backend page
after restart, and explicit public-client delivery. It
does not qualify background courier, registries, supervision, runtime bindings
or foreign APIs. Separate growing-query and quota proofs below own those
implemented capabilities.
After restart, the writer also reads all 41 Table rows in six typed pages before
committing its completion count. Continuations cannot change view, resource,
Table or schema; unit cases cover extreme keys, a neighboring Table, caught scan
failure and exclusion of private writes. This is paged state access, not yet
large-result capture or whole-query execution.

Run just this scenario with `just test::growing-station`. It also retains the
earlier 40-row source, commits one scan page plus a self-continuation, and loses
caller/node/provider again. A replacement continues from durable progress across
new handler views, finishes the same source in six pages total, and releases it
with the final count. Retained reads automatically become proposal dependencies.
This is an application-managed scan; it does not implement the Arrow result gate.

The caller now drives M11's separate `prepare`/`dispatchPending` methods. It
checks that repeated preparation preserves frozen work, discard rejects a pending
mutation, and successful dispatch exposes the same input identity and a positive
receipt. Native units cover permit/view/turn preparation with no usable I/O
client, stop without a failure marker and read poisoning under stop policy.
`just test::unit`, this disk recovery proof and the legacy `just test::station`
service/recovery/lifetime proofs passed after the change. Foreign persistence
callbacks and public SDK runner qualification are still separate work.

The same service task runs growing maintenance on one CPU with owned proxy
faults: kill after an accepted snapshot loses its reply, then restart from the
recorded trim intent; loss of an accepted immutable-page reply before root
publication; timeout after accepted physical trim; current maintenance
revocation and later regrant; node/provider/worker restart. Terminal-source work
is disposed without delivering to the destination, independent state and an
unresolved authorized attempt survive, and retained output bytes stay readable.
Core checks separately cover clock loss/uncertainty, bounded finite scan passes
under continuing admission, current control authorization and revalidation of
stale scan suggestions. These are not sweep-latency or full-store guarantees.

### Growing physical capacity

`just test::growing-capacity` uses the same owned Docker/ext4 fixture as the
legacy capacity proof, with the real v3 authority and disk Ursula. The declared
profile has 96 admission positions and a 96-position control reserve. One decoded
page (8,532 bytes) serves 40 retained 256-byte rows, retained receipts, accepted
backlog, a finite process and an unresolved authorized effect. Applications have
not opted into row/result reclamation; root-history trimming is explicitly enabled.

The 2 GiB filesystem preallocates a 1 GiB reserve. Filling the remainder triggers
real ENOSPC and Ursula's WAL pressure gate. A control publication then fails while
the authority stays at position 96 and all data and permissions remain intact.
Only the reserve file is released; the filler remains throughout control work
and restart. Revocation, opted-in expiry, effect closure, complete backlog drain
and root checkpoint/trim finish at position 154. SIGKILL/restart preserves every
row, exact historical receipt, retirement and closure. Repeated maintenance and
verification issue only GET/HEAD requests and stage no pages.

One local Debug run took 29.43 s for setup, 0.95 s under pressure, 31.55 s for
control/drain/checkpoint and 1.42 s for recovery/verification. Control work added
1,310,720 allocated WAL bytes while using 58 of the 96 reserved positions. These
are one finite workload's measurements, not a worst-case allocation formula,
production reserve recommendation or host-power-loss proof. The node does not
provision physical headroom automatically. Evidence is written to
`.cache/growing-capacity-evidence.json`; the legacy task retains its own artifact.
The dedicated reference workflow runs both proofs and preserves their metadata.

`just test::growing-quota`, also included in `test::growing-service`, uses the real
node and Station on one CPU with one resident page, a 24-position ceiling and four
control positions. A previously captured output-free handler turn commits after
admission closes. Opening a view for the next input is refused, and the host
retains its exact signed proposal. Caller/node/provider replacement preserves
15 admitted inputs, one consumption and zero cancellations. The same request
still receives `AdmissionClosed`; authorized revocations exhaust the reserve,
after which a new control operation receives `ControlCapacity`. Current rights
still govern retry disclosure. Reads confirm the same retained data and backlog.

## M12 declarative interface readiness

`just test::sql` regenerates the ANTLR reference parser and runs the pinned
pglast/libpg_query differential corpus, then invokes the actual Zig public-package
consumer in [sql_driver.zig](sql_driver.zig). All 103 admitted SELECT statements
must have identical normalized ASTs across the three parsers. Fourteen are
unchanged PostgreSQL REL_17_5 regression statements; source provenance, hashes,
license and exact exclusions live in [the grammar contract](../contracts/sql/README.md).
Seventeen syntax exclusions and thirteen grammar-only administrative forms must
be rejected by the production parser. Twelve admitted SELECTs deliberately fail
schema/type/limit compilation; the other 91 compile to independently checked
`FZP1` bytes and execute through `Stream.step` over 70 rows in seven-row pages.
Plan and progress round trips precede continued execution. PyArrow independently
checks original result segments, column order, nulls and exact values against a
Python result oracle. Omitted limits must not truncate at 32 rows.

The SQL unit suite (ordinary `just check`, or standalone `zig build test` in
`packages/zig/transit-fuze`) covers manually constructed plan equivalence,
AST ownership after text destruction, invalid encodings/names, statement/literal/
comment bounds, integer extrema, trailing input, and 2,000 seeded arbitrary or
mutated statements. Actual compiled sum plans retain cross-page overflow,
source-revision fencing and cancellation; a limited input excludes later
row overflow. Tests do not claim unbounded fuzz coverage.

`just test::sql-grammar` is the focused reference-only check. Ordinary bindings CI
owns `test::sql` and `test::sql-rewrites`; generation always reruns, and a cache
hit cannot substitute old trees. The optional tools come from existing Nix pins.
No PostgreSQL server or ANTLR/Lean runtime enters Fuze. These local proof commands
are executable evidence; a hosted timing measurement for the expanded lane is
still deferred, as it was for M11.

This qualifies parsing → typed plan → bounded paged Arrow execution, not a
network query service or SQL DDL/writes. Current authorization, durable Station
publication, recovery and foreign SDK behavior retain their existing owners and
proofs. The parser does not change those boundaries. The Lean model's separate
assumptions and evidence are recorded in the grammar contract.

`just test::sql-rewrites` checks four complete Lean theorems. Filter reordering
and projection pruning print only `propext`; predicate pushdown with first-error
preservation and its downstream-consumer corollary print no axioms. The runner
requires all four names and rejects warnings, incomplete proofs and unexpected
axioms. This is specification evidence with explicit correspondence assumptions,
not implementation refinement or an enabled optimizer. False/generalized limit
and sum rewrites remain excluded, with reasons in the model.

## M13 public query access

`just test::public-query` builds and runs the actual `transit` shell and
`transit-query-host` source/requester/courier binaries against an isolated growing
node and disk Ursula. A separate provisioning caller creates a 41-row Table,
including nulls and integers beyond JavaScript's exact numeric range.

The current proof passes exact decoded typed rows across all six segments;
unsupported SQL without admission; a malformed/lost admission receipt and
byte-identical signed retry; worker SIGKILL after accepted staging followed by
fresh recorded ownership; rejection of reuse of the old activation; explicit
busy admission; schema mismatch rejection; incomplete result refusal; explicit
cancellation; source retirement clearing; and read revocation during incomplete
capture, after an actually received partial segment, and after complete disclosure.
An inspection-only principal cannot use another principal's requester binding.
Re-authorized reads select the original result without rerunning SQL.

The public client restarts an entire changed read at most three times, retaining
resource-cut consistency during final acknowledgement. This never retries query
execution or regenerates an uncertain mutation. Package tests also verify owned
schema-fenced request encoding, full-width cancellation identity and rejection
of a predicate that exceeds the existing frame budget.

`just transit-board::query-test` runs the actual growing Board binary and the
same real hosts against a separate disk-backed realm. It proves default query
disablement, distinct inspection/query principals, unsupported/malformed ingress
refusal before admission, exact frozen start/cancellation retries, incomplete
page refusal, current result authorization, source retirement and stable atlas
cuts. Widening the inspection grant is refused. Restoring it requires explicit
resource reauthorization because coarse grant replacement changes incarnation.
Actual source/plan/page responses pass the generated JavaScript validator; typed
int64 cells retain values beyond JavaScript's exact numeric range.

`just transit-board::query-browser` includes that API proof and drives Chromium
against the actual embedded UI. It selects a resource, changes emphasis/detail,
enters the workspace, switches Canvas/Browse before and after a single explicit
submission, and preserves an edited draft alongside the identified old result.
An externally recorded revocation clears schema, draft and result in the open
workspace; restoring access does not rerun SQL or recover an offline copy.
Source retirement clears it again with a distinct unavailable/expired message.
The proof checks no cookies/local/session storage and captures the atlas and
workspace screenshots. Frontend unit tests reject int64 overflow, wrong cell
types, row gaps, invented continuation and invalid Unicode.

Local Linux x86_64 qualification passed: `just check`, both real query proofs,
Board's legacy API proof and all five legacy browser scenarios, plus independent
`transit-board-api` package tests. CI owns the API and browser tasks in the
experience/browser lanes. These new lanes have not been remeasured on hosted
runners; M10's earlier cost evidence is not a claim about the expanded suite.

This is one Table, one query principal, one requester and one authority. It
qualifies process SIGKILL, not host power loss; the courier's bounded restart scan
has no latency guarantee over arbitrary retained history. It adds no automatic
production provisioning, larger-population atlas proof, per-human delegation or
reference-deployment query capacity guarantee. Complete-results-only row access
is intentional; partial progress is visible without disclosing partial rows.

## M14 immutable publication

`just test::publication` runs [real Zig Station callers](publication.zig) against
an isolated `growing_v3` authority and disk-backed Ursula. The
[Python harness](publication.py) verifies an independent SHA-256 fixture,
intercepts actual signed HTTP responses and SIGKILLs four workers at named
boundaries. It also kills the authority and restarts the owned store at each
boundary. Native memory and the harness manifest are not authoritative content.
The proof belongs to CI's growth lane; the ordinary build compiles its caller.

The schedule stages a 64 KiB binary record and an unpublished 513-byte record,
reserving bytes/slots before append. It rejects quota/oversize work, resumes
four remaining chunks with one resident authority page, and stops again with a
fully staged record and an unsent publication turn. After fresh ownership the
old signed turns are rejected. Publication, application head, acceptance marker
and output commit together; a revoked write attempt publishes none of them.
Lost append/publication/cleanup acknowledgements retry the exact signed bytes
and receive the same receipt. A distinct duplicate application command creates
no second acceptance output.

Forty-one additional 32-byte records remain published without requiring cleanup
or enlarging a snapshot. After another restart with one page, an actual returned
prefix is followed by read revocation; the failed read poisons the whole proposal.
An expired view cannot continue. Explicit retirement removes the current head;
explicit abandonment retains its staging reservation until cleanup completes.
Cleanup commits two chunk deletions at a time and is interrupted after progress.

A retained source protects the original 64 KiB body while current chunks are
removed. Its verification reader records the source identity and cursor progress
in KV, reads eight chunks per handler and resumes after worker/node/store loss.
Only the final verified chain sets the completion marker. Subsequent revocation
and explicit release deny retained reads. Authority history checkpointing is explicitly opted in; publication lifetimes
remain unlimited and no history trim is requested. A checkpoint is recorded
before each of the last two recovery boundaries. Final inspection checks empty staging
reservation, preserved acceptance evidence, retained smaller records and
permanent descriptors rejecting old IDs. This is logical current-KV cleanup;
it does not prove physical provider erasure or history trimming.

The package's `publication_test.zig` separately exercises invalid encodings,
full-width identities, empty bodies, identity/content conflicts, out-of-order
chunks, missing/corrupt content, mixed-source cursors, private-write rejection,
quota accounting, read-error poisoning and rollback when the four-mutation
budget fills partway through a helper. It includes 64 KiB streaming and a
historical-snapshot oracle. `just test::unit` runs these checks; the Station
package also builds/tests them using its own dependency manifest.

Capacity is explicit: chunks are 256 bytes, namespace values 32 bytes, descriptor
values 104 bytes, keys 23 bytes and cleanup at most two chunks. A 64 KiB record
uses 71,551 logical key/value bytes plus 55 bytes for its namespace; provider
indexes, authority history and retained roots add separate overhead. Record and
staging byte/count quotas are durable configuration. The u32 encoding ceiling
is not a qualification of arbitrary multi-gigabyte records. Total retained
record count does not size an array or whole-record buffer in the implementation.

Local Linux x86_64 qualification passed: `just check`, standalone Station
package tests, `just test::publication` and the existing `just test::growing-query`
regression. The [retained report](verification/results/m14-publication-2026-09-26.json)
records source hashes, sizes, workload and phase timings: staging 34.566s,
one-page sealing 4.781s, publication 18.878s, one-page cleanup/recovery 21.203s,
and completion 91.551s (170.979s total phase time, excluding build/provider startup).
The native descriptor/cursor/returned part occupy 104/144/416 bytes; these are
type sizes, not a process-RSS measurement. The one-page recovery phases are separated from ordinary
64-page preparation/completion. A preliminary whole-write one-page stress run
was interrupted for excessive repeated cache work; it is not passing evidence.
These proofs concern one authority on Linux x86_64 and process/store restart,
not host power loss, production throughput, CRDT convergence, language SDKs,
remote uploads, physical reclamation or deployment-launcher support. Hosted CI
feedback/cost for the additional task has not yet been measured.

The M17 Document package now runs eight component tests in `just check` and
`just test::packages`. They include all 24 permutations of four concurrent
changes with duplicate delivery, nested parent deletion/child edits, text anchor
deletion and concurrent insertion, explicit register conflicts/resolution,
missing/null/type errors, full-width values, Unicode and failed candidate writes.
An 80-change text schedule stores 640 scalar elements and more than 2,048 index
entries while traversal advances one bounded transition at a time. The standalone
suite passed in 1 s with 16 MiB process RSS (including the in-memory test store);
this is not a production resident-memory or disk-recovery measurement. Full
repository checks passed. Durable acceptance, checkpoint/compaction, SDK and
placement evidence remain pending.

M17's Document service component now passes 14 standalone tests (1 s, 16 MiB
process RSS including fixtures), and `just check` passes. The private-turn fixture
reconstructs every staged proposal, discards it before commit, and verifies that
only final acceptance changes the head. Three acceptance mutations leave room for
one framework mutation plus the success output. Other schedules cover original
revision recovery for duplicate changes, frozen request identity, rejected-node
cleanup, candidate quota exhaustion, exact older reads, logical retirement and
current read denial. The maximum synthetic head encodes to 252 bytes. Disk/node
failure, checkpoint/compaction and public SDK/placement proofs remain pending.

The Document checkpoint component extends the standalone suite to 16 tests,
passing in 1 s with 16 MiB fixture-process RSS. It reconstructs every checkpoint
staging proposal, preserves unlimited-history duplicates and deletion anchors,
and advances finite epoch/floor only in the final decision. Tests reject stale
epochs and recycled replica counters, verify accepted tail requests, preserve an
older checkpoint after new text edits, and reclaim rejected checkpoints or
accepted intervals after permanent retirement. Live accepted intervals remain
physically retained; no reachability collector is claimed. The root check passed;
disk recovery qualification is running separately.
