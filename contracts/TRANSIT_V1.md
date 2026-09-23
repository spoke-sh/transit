# Transit v1 experimental protocol profile

Status: executable M1 authority proof, not a stable public API or complete M1.
The owning requirements remain in [TRANSIT.md](../docs/TRANSIT.md) and
[SECURITY.md](../docs/SECURITY.md).

## Encoding and identity

The journal contains one JSON object per Ursula record. The first is
`{"genesis":{"version":1,"realm":42,"root_key":[...]}}`; `root_key` is exactly
32 public-key bytes. A deployment supplies the expected genesis out of band;
recovery rejects any mismatch. Only explicit bootstrap creates a journal.

Subsequent entries wrap `operation`, whose fields are `version`, `position`,
`policy_revision`, and `request`. Positions start at one, match the physical JSON
record ordinal in this adapter, and remain explicit protocol fields. The portable
engine does not interpret an Ursula byte cursor. A PID is `(realm, spawn position)`.
Retired process entries are preserved and never reallocated.

Requests contain these fields in this canonical order:

```json
{"version":1,"realm":42,"principal":0,"sequence":1,"command":{"send":{"pid":3,"value":7}}}
```

The command is a one-key tagged object. The exact types and variants live in
`packages/zig/transit/src/root.zig`; unknown fields/variants are rejected by the
typed parser. Realm, journal position, and request sequence are restricted to
JavaScript's exact integer range. State and input are signed 64-bit integers;
future TypeScript consumers must use lossless integer parsing for those values.
This experiment's scalar state is not the final general payload contract.

## Authentication and authorization

An ingress envelope adds a 64-byte `signature` to `request`. Ed25519 signs
SHA-256 of `rey.transit.request.v1` followed by a NUL byte and the typed canonical
JSON request. The pinned Zig encoder emits all declared fields in declaration
order; JSON whitespace/object order on ingress is not signed directly. There
are no floats or arbitrary maps. Cross-language implementations must match the
golden fixture test before interoperability is claimed.

The deployment's root public key is principal zero. Only root can change grants.
Other grants bind a public key, permission bits, and optional PID restriction.
Ownership additionally binds execution to a principal and generation. Key
replacement preserves request sequence and cannot reset deduplication. Service
keys have explicit durable revocation, with no token lifetime or federation in
this slice. Private keys and request signatures are not journal records.

Requests, grants, and ownership transitions share a single realm journal.
Preparing a transition validates current history; accepting it conditionally
appends at exactly that tail. A racing revocation or ownership change makes the
prepared append fail. Historical replay applies recorded decisions and the
compiled reducer; it does not require retired credentials to become valid again.
The core accepts no direct effect executor or OS I/O interface.

Each principal submits serially increasing request sequences. The most recent
accepted request retains its digest and receipt in state. Older receipts are
resolved by scanning retained history; unlimited is the default. An identical
retry returns its receipt only under current authorization; conflicting content
fails. A deployment may explicitly choose `retry_policy: "last_per_principal"`
in genesis; older requests then return `RetryHorizonExceeded`, never fresh
admission. Concurrent producers need distinct principals.

## Execution and limits

The engine accepts one reviewed, compiled reducer at workload version one. The
counter fixture uses checked addition; the authority recomputes the result from
the next journal input and rejects skipping or forged results. An arithmetic
failure leaves the head pending for explicit operator action. This does not
establish isolation or determinism for arbitrary native code.

Mailbox bodies remain in storage. State holds counts and a scan position;
the Ursula adapter caches at most 16 records. This trades scanning cost for a
small, provable recovery mechanism. A deployment is currently limited to 16
principals, 64 lifetime process identities, and 128 lifetime effect identities;
reaching those quotas fails
before admission. Scaling those catalogs requires a later persistent index.

## Effect intents and observations

A reducer returns proposed state and an optional scalar effect intent. The turn
commits both atomically, after recomputation and an additional effect grant
check. An intent's identity is its originating turn position. `dispatch` records
one attempt, identified by the dispatch position and authenticated executor.
Dispatch competes with revocation and termination through the same journal CAS.
Only the recorded executor, under its current grant, can submit an observation.

An authorized attempt is potentially in flight. A null result records an unknown
outcome; neither restart nor ownership loss authorizes another attempt. This
profile has no retry operation. A known scalar result admits exactly one ordered
mailbox input when the caller is live. After termination it updates reconciliation
evidence only. Termination cancels pending, unattempted intents while preserving
authorized/unknown attempts. Replay updates these records without invoking I/O.

These are protocol tests, not an isolated connector executor. The current
effect grant combines intent, dispatch, and observation rights; it has PID scope
but no destination or secret scope. Those distinctions and a synthetic executor
behind a proved capability boundary remain required before service deployment.

## Checkpoint and trim

History remains unlimited by default. Trimming requires both an explicit finite
retry policy in genesis and `allow_trim: true` on every process. Root commits a
checkpoint intent only when every input has completed or has been explicitly
cancelled by process termination. Cancellation counts remain separate from
consumption; termination never pretends that unread messages ran.

The checkpoint preserves genesis, grants, deduplication floors/receipts, PIDs,
ownership, state, input progress, effect intents, and attempt evidence, with a
content checksum. The adapter
publishes and reads it back before advancing Ursula retention. Recovery can
start from this essential checkpoint and a bounded retained tail; a corrupt or
missing required checkpoint stops recovery. Publishing, killing the server,
resuming trim, and killing it again are exercised by `just test-storage`. An
unknown effect survives these boundaries; a late observation after caller
termination cannot revive the PID or advance its application state.

This first reclamation profile refuses to trim a live pending mailbox. Keeping
pending input in separate retained segments, physical capacity reservation, and
general dependency pins remain M1 work. Whole-journal deletion is not exposed.

Finite deadlines are rejected as `UnsupportedDeadline`: pre-append clock checks
alone cannot enforce expiry on a paused/delayed commit. Control capacity
reservation, isolated effect execution, cross-process outboxes, network ingress, and
Kubernetes/Substrate runtime reconciliation remain unimplemented gates.
Do not advertise M1 completion or deploy this experiment as a service.
