# Transit v2 experimental protocol profile

Status: implemented and verified bounded M1 profile, not a stable public API.
The owning requirements remain in [TRANSIT.md](../docs/TRANSIT.md) and
[SECURITY.md](../docs/SECURITY.md).

## Encoding and identity

The journal contains one JSON object per Ursula record. The first is
`{"genesis":{"version":2,"realm":42,"root_key":[...]}}`; `root_key` is exactly
32 public-key bytes. A deployment supplies the expected genesis out of band;
recovery rejects any mismatch. Only explicit bootstrap creates a journal.

Subsequent entries wrap `operation`, whose fields are `version`, `position`,
`policy_revision`, `request`, authority `time`, and derived `admission`. Replay
recomputes admission and rejects mismatches; a denied delivery or evidence-only
observation is not a mailbox input. Positions start at one, match the physical JSON
record ordinal in this adapter, and remain explicit protocol fields. The portable
engine does not interpret an Ursula byte cursor. A PID is `(realm, spawn position)`.
Retired process entries are preserved and never reallocated.

Requests contain these fields in this canonical order:

```json
{"version":2,"realm":42,"principal":0,"sequence":1,"command":{"send":{"pid":3,"value":"37"}}}
```

The command is a one-key tagged object. The exact types and variants live in
[`transit-protocol`](../packages/zig/transit-protocol/src/root.zig); unknown
fields/variants are rejected by the typed parser. The generated
[JSON Schema](transit-v2.schema.json) includes field order, defaults, integer
ranges, routes, permissions and signing metadata for future binding generators.
Realm, journal position and request sequence are restricted to JavaScript's exact
integer range; other control integers require lossless handling over their stated
ranges. State, input, output and effect data are opaque values of at most 256
bytes, encoded as even-length lowercase hex strings. Empty bytes encode as `""`.
Application formats and schema versions belong to callers. This is a bounded
inline profile; general large-payload references are not implemented.

v2 changes requests, signatures, histories, checkpoints and HTTP routes. v1 is
rejected, including during recovery; there is no automatic migration. Use a fresh
development realm for v2 and preserve old data separately if it matters.

## Authentication and authorization

An ingress envelope adds a 64-byte `signature` to `request`. Ed25519 signs
SHA-256 of `rey.transit.request.v2` followed by a NUL byte and the typed canonical
JSON request. The pinned Zig encoder emits all declared fields in declaration
order; JSON whitespace/object order on ingress is not signed directly. There
are no floats or arbitrary maps. Cross-language implementations must match the
golden fixtures before interoperability is claimed. Committed
[request vectors](../packages/zig/transit-protocol/src/fixtures/requests-v2.json) contain
canonical bytes, SHA-256 digests, Ed25519 signatures and a public test seed.
Zig checks them in `just test::unit`; Python independently checks JSON encoding and
hashes, then compares CLI signatures, in `just test::service`. The maximum signed
64-bit sample input is decimal application text inside an opaque byte value.
The shared [sequence trace](../packages/zig/transit-protocol/src/fixtures/sequences-v2.json)
covers scoped PIDs, duplicate admission/spawn, stale ownership, invalid input
order/state revisions, dispatch/closure, permanent retirement and a caller-reported
blocked input. Zig reopens the authority after every accepted or rejected step.
The trace supplies application commits, including an effect for input 9; the
authority applies recorded state without running a fixture workload.

The deployment's root public key is principal zero. Only root can change grants.
Other grants bind a public key, permission bits, and optional PID restriction.
Ownership additionally binds execution to a principal and generation. Key
replacement preserves request sequence and cannot reset deduplication. Service
keys have explicit durable revocation, with no token lifetime or federation in
this slice. Private keys and request signatures are not journal records.

Requests, grants, and ownership transitions share a single realm journal.
Preparing a transition validates current history; accepting it conditionally
appends at exactly that tail. A racing revocation or ownership change makes the
prepared append fail. Historical replay validates protocol transitions and applies recorded application
state; it neither runs application code nor requires retired credentials to become
valid again.
The core accepts no direct effect executor or OS I/O interface.

Each principal submits serially increasing request sequences. The most recent
accepted request retains its digest and receipt in state. Older receipts are
resolved by scanning retained history; unlimited is the default. An identical
retry returns its receipt only under current authorization; conflicting content
fails. A deployment may explicitly choose `retry_policy: "last_per_principal"`
in genesis; older requests then return `RetryHorizonExceeded`, never fresh
admission. Concurrent producers need distinct principals.

## Execution and limits

The engine has no application callback or workload dispatch table. A caller reads
its ordered input and committed state, computes a result, then submits a turn.
Transit validates current permission, ownership generation, next input position,
`expected_revision`, lifetime/permit and output/effect authority before one atomic
append. State revision starts at zero and becomes the successful turn position.
A spawn supplies opaque `initial_state` and a nonzero application `code` tag; the
node never interprets that tag as executable code. Runtime workload digests and
activation evidence remain separate controls.

A failure is an authenticated caller report, submitted as `turn.failed=true` with
byte-identical state and no outputs/effects. Transit validates that structure,
not whether application computation truly failed. Acceptance records
`Process.failure` with the input and record position, fences the activation, and
leaves the input unconsumed. Admissions, turns and activations then fail with
`BlockedProcess`; runtime reconciliation stops the Actor rather than replacing
it indefinitely. Explicit termination or opted-in expiry cancels the outstanding
input; M1 provides no automatic retry or same-PID reset for a reported
failure. Failure evidence survives replay and checkpointing. The sample counter
uses checked addition in the worker. Application tests establish its arithmetic;
Transit establishes protocol legality, not honest or deterministic computation.
Two distinct Zig applications exercise the same unchanged node through
[`transit-client`](../docs/CLIENT.md).

Mailbox bodies remain in storage. State holds counts and a scan position;
the Ursula adapter caches at most 16 records. This trades scanning cost for a
small, provable recovery mechanism. A deployment is currently limited to 16
principals, 64 lifetime process identities, 128 lifetime effect identities, and
256 lifetime output identities, and 16 standalone payload identities. Typed journal
entries are bounded by 8 KiB and checkpoints by 1 MiB. Reaching quotas fails
before admission. Scaling these catalogs requires a later persistent index.

## Runtime bindings and activation

Each process can pin a provider-neutral binding: runtime-instance identity,
resource digest, workload digest, provider incarnation, binding revision, and
current operation ID. `runtime_intent` records an operation and immediately
fences the prior owner by advancing its generation. `runtime_observe` records
ready/unknown/stopped evidence for that exact operation. Observations never
grant ownership, including after process retirement.

`activate` requires a ready binding and a pre-existing PID-scoped worker grant.
It atomically replaces that principal's public key and advances ownership,
recording the physical worker incarnation. Bound PIDs cannot use ordinary `own`.
The controller must verify the fresh public key against the current provider
worker before activation. Recovery preserves the process and provider resource;
stale keys, binding revisions, and generations remain fenced. Binding and key
evidence survive checkpoint/trim. Two PIDs cannot bind the same provider resource.

M1 pins one association/workload and requires a different physical worker
incarnation and fresh key for replacement. Migration, provider-resource
replacement, native-code upgrades, and reusing a pod for another activation are
rejected until their own recovery contracts exist. Unresolved provider operations
must reconcile before starting another. An operator's provider observations are
trusted input, not cryptographic proof of physical placement.

## Process outboxes

A turn can commit up to four opaque outputs to fixed destination PIDs, alongside
state and input progress. The authority validates the proposed array and requires
the producer's `publish` grant, scoped to the source PID. Each
output retains its source, originating turn, array index, payload, and stable
realm-scoped identity. A committed output does not guarantee destination admission.

In this single-realm profile, an administrative controller submits `deliver`
with the output identity, fixed destination PID, and proposed courier principal.
Transit checks that courier's current `send` grant and PID scope, plus destination
lifetime. Delivery records the policy revision and either one mailbox admission
or a terminal denied/expired/retired outcome in the same conditional append.
Revocation races fence a prepared delivery. This deliberately uses one authority
journal; it is not a cross-realm or multi-stream transaction implementation.

An unresolved earlier output blocks later outputs from the same source to the
same destination. Other destinations can progress independently, so fan-out can
partially succeed. A terminal disposition releases that route; a late retry
cannot subsequently admit the earlier output. Source termination/expiry cancels
only its still-pending outputs, preserving already admitted destinations.

Checkpoints retain pending payloads and resolved delivery evidence. The disk
proof removes the source turn, resumes partial fan-out after restart, and resolves
a lost acknowledgement without duplicate destination admission. Catalog capacity
refuses the entire source turn before committing any state or outputs.

## Effect intents and observations

A caller proposes state and an optional opaque effect intent. The turn commits
both atomically after protocol validation and an additional effect grant check. An intent's identity is its originating turn position. `dispatch` records
one attempt, identified by the dispatch position and authenticated executor.
Dispatch competes with revocation and termination through the same journal CAS.
Only the recorded executor, under its current grant, can submit an observation.

An authorized attempt is potentially in flight. A null result records an unknown
outcome; neither restart nor ownership loss authorizes another attempt. This
profile has no retry operation. A known opaque result admits exactly one ordered
mailbox input when the caller is live. After termination it updates reconciliation
evidence only. Termination cancels pending, unattempted intents while preserving
authorized/unknown attempts. Replay updates these records without invoking I/O.

`close_effect` irrevocably closes an authorized/unknown attempt as
`closed_unknown`. It binds PID, effect, and attempt; the current executor or a
controller with both effect and administrative rights may close it within its
PID scope. A known result instead closes as `observed`. `closed_at` records the
journal position of closure, not a wall-clock timestamp. Closure and observation
use the same CAS, so one wins; a losing proposal cannot overwrite that outcome.

New observations after either closure return `ReconciliationClosed`, including
unknown observations and otherwise valid late results. A same-identity retry of
an earlier accepted operation may return its historical receipt under current
permission and the retry policy; it does not admit anything again. A closed
unknown attempt does not deliver a fabricated failure message, cancel remote
work, or authorize a retry. The experimental caller must inspect its closure;
a typed framework notification is later work.

Dispatch records `reconcile_before_ms` (required for a finite caller) and a
`max_observations` budget from 1 through 16 (default 16). Every newly accepted observation spends
one unit; duplicates spend none. The last unknown observation closes the attempt
as unknown. A deadline closes result authorization independently of a background
timer. `State.nextMaintenance` rebuilds due expiry/closure commands by scanning
the bounded catalogs; a controller must sign and commit each command. It does
not invoke external I/O or invent a remote outcome.

An unlimited caller may omit the wall-clock bound and close explicitly or exhaust
the observation budget. That is not a finite reconciliation-time guarantee;
connectors must choose and record their required finite window before real I/O.
The test-only synthetic executor has real-I/O/closure proofs, but no production
connector is installed. The current effect grant combines intent, dispatch and
observation rights; destination and secret scopes remain connector work.

## Authority time and bounded settlement

Finite policies require an explicit `max_clock_error_ms` in genesis and a trusted
`Time.Source` attached to the engine. Requests cannot supply authority time.
The authority records its validation sample and uncertainty with each time-sensitive operation;
the sample must fit the configured error bound and cannot precede the durable
time high-water mark. A missing source, excessive uncertainty, or rollback
refuses time-dependent authorization. Replay uses recorded samples, never today's
clock. Supplying a time source is a trusted deployment responsibility, not proof
that an arbitrary host clock has the advertised UTC accuracy.
Reads, revocation, explicit retirement, and non-time-dependent control/maintenance
do not sample a clock, so a synchronization outage cannot disable those controls.

The acceptance-time boundary is trusted validation of the candidate at an exact
journal tail. Its append must still win CAS. A candidate validated before a
deadline can persist later if no competing transition intervened; this is not a
physical storage-write deadline. If closure or another operation wins first,
retry requires current history and a fresh sample. A response first validated
after its reconciliation deadline is refused even if maintenance is delayed.
Both the lower and upper UTC bounds must be before an authorization cutoff;
automatic expiry requires the lower bound to have reached the deadline. An
interval crossing a cutoff fails closed rather than guessing.

Finite spawn records `deadline_ms` (the work cutoff) and `settle_before_ms`
(the final settlement bound), with the latter no earlier than the former.
`begin_turn` durably authorizes the next input before the work cutoff. The
resulting permit must be named by `turn`; it survives ownership replacement,
while stale generations cannot commit. Only that turn may finish after the work
cutoff and before the settlement bound. The first profile allows state-only
settlement, not new effects or implicit response-handling continuations.

After the work cutoff, ordinary admission, new turns, and dispatch fail. Recovery
may transfer ownership only for the already recorded permit within settlement.
An effect outcome arriving after its finite caller's work cutoff remains
connector evidence; this profile has no preauthorized reply continuation.
`expire` records final PID retirement and unread-input disposition after the
settlement bound. Its durable evidence and the time high-water mark survive
checkpoint/trim. Unlimited lifetimes remain the default.

The time proofs use a controlled authority clock and real disk-backed Ursula.
A production synchronized clock source, periodic controller service, and reference
deployment are still required; these tests do not certify host UTC accuracy.

## Checkpoint and trim

History remains unlimited by default. Trimming requires both an explicit finite
retry policy in genesis and `allow_trim: true` on every process. Root commits a
checkpoint intent from a principal with a current realm-wide `admin` grant only
when every input has completed or has been explicitly
cancelled by process termination. Cancellation counts remain separate from
consumption; termination never pretends that unread messages ran.

The checkpoint preserves genesis, grants, deduplication floors/receipts, PIDs,
ownership, state, input progress, effect intents, and attempt evidence, with a
content checksum. The adapter
publishes and reads it back before advancing Ursula retention. Recovery can
start from this essential checkpoint and a bounded retained tail; a corrupt or
missing required checkpoint stops recovery. A running authority that falls behind
another maintainer's trim loads a validated newer checkpoint and catches up from
its retained tail; it never resets a missing range to empty history. Each refresh
attempt bounds this recovery to one checkpoint reload. Publishing, killing the server,
resuming trim, and killing it again are exercised by `just test::storage`. An
unknown effect survives these boundaries; a late observation after caller
termination cannot revive the PID or advance its application state.
Another fixture closes an unknown attempt while its caller is still running,
then proves that late results remain rejected after checkpoint, trim, and restart.

This first reclamation profile refuses to trim a live pending mailbox. Separate
pending-input segments and general dependency pins are not implemented.
Whole-journal deletion is not exposed.

Finite deadlines are rejected as `UnsupportedDeadline` unless the realm opts
into bounded authority time; a missing required source gives `ClockUnavailable`.
An optional immutable `admission_ceiling` closes new work at a configured journal
position while allowing bounded control and old-input completion. It is not
expiry and cannot cancel accepted work. The capacity flag survives checkpoint
and trim; the one post-ceiling checkpoint cannot be repeated with fresh request
identities. See the [capacity profile and physical proof](../docs/RETENTION.md#m1-bounded-capacity-profile)
for record/byte bounds, the tested reserve, and deployment limits. Defaults
remain unlimited. Dynamic capacity expansion is outside this experimental profile.

Synthetic effect I/O and Kubernetes/Substrate recovery/isolation now have their
own executable proofs. Basic immutable payload deletion is described below;
the [roadmap](../docs/ROADMAP.md) records the completed M1 evidence audit.
Cross-realm delivery is outside this slice.
The [experimental service](SERVICE_V2.md) hosts signed ingress and scoped views
for application callers, including the reference counter. Conformance is limited to the documented
profiles, topology and fault schedules; broader guarantees need new evidence.

## Standalone immutable payloads

`declare_payload` records PID, publisher, length (1–65,536 bytes), SHA-256 and
explicit `allow_delete` (default false). Its accepted position identifies the
payload; the realm has sixteen lifetime slots. `payload_ready`, `retire_payload`
and `payload_deleted` name that PID and payload ID. All require a current
PID-scoped administrative grant; only the original publisher may claim readiness.
PID views disclose metadata under current inspect permission, never raw body
access. Publication/deletion observations come from trusted storage code.

The Ursula adapter derives an unreused physical name from the authority journal
and payload ID, creates a closed stream atomically with its body, and verifies
the body hash. A fresh declaration authorizes one serialized creation attempt.
Recovery verifies it read-only; it must not retry PUT or infer non-execution from
404. Readiness cannot be claimed until verification succeeds. Owner termination
and `allow_delete=true` permit retirement; background maintenance confirms deletion
before recording its outcome. Tombstones survive outside the removed stream,
including checkpoint/trim and a lost DELETE acknowledgement.

This first contract supports standalone bytes and unlimited-lifetime owners.
Finite owners are rejected with `UnsupportedPayloadLifetime`. This inline profile has no protocol-recognized references from state, mailbox
or effect fields to these bytes; a general
payload read/upload API, reference graph and bounded finite upload reconciliation
remain outside M1. See [retention](../docs/RETENTION.md#m1-immutable-payload-deletion)
for recovery rules and the unresolved-creation limit.
