# Station exchange capture v1

Exchange defines the capture layout shared by the finite HTTP and RPC connectors.
This is a framework layout over growing KV and [publication v1](STATION_PUBLICATION_V1.md),
not a new kernel effect or a permission carried by a reference.

## Ownership and identity

An exchange is `(resource:u64, id:u64)`, with a nonzero application-assigned ID.
It owns that namespace exclusively in the exchange publication domain (6).
A fenced exchange writer owns
the resource; the caller PID/input and optional parent exchange are immutable
lineage. The executor has its own current dispatch/observation grants. A caller
must have an explicit resource grant to read the capture. Associations and
references do not grant access. Resource admission must cover the promised
caller/replay lifetime; the first profile uses independent, unlimited capture
resources, with explicit release after dependents no longer need them.

One exchange records one kernel effect/attempt. Redirects, explicit retries and
reconciliation requests create new exchanges with parent lineage and new effects.
The executor binds a real dispatch receipt before capture of remote observations.
Recovery cannot use that binding as permission to send again. Dispatch and
observation remain the existing kernel operations. Only the authenticated effect
origin can resolve a waiting caller; capture alone does not resolve an effect.

## Bounded capture and completion

The immutable descriptor records caller/input, protocol format, lineage, finite
capture budgets, a finite reconciliation deadline, attempt/executor, segment
count, byte count and a coverage commitment. States are preparing, ready, capturing,
complete, unknown and retired. Completion and unknown are terminal for capture;
retirement closes reads before member reclamation. No transition resets budgets
or reuses an ID. Captured prefixes do not imply a complete response.

The ready transition freezes exact request coverage and commits its kernel effect
intent in the same turn, retaining a copy of that intent and a caller replay
hold (three mutations). It forbids more request segments and repeated effect
creation. Binding checks the authorized effect's payload against that exact
coverage before moving to capturing. No state grants permission to resend.
In growing v1, the immutable intent entry's revision and the same-turn effect ID
are the publishing journal position. A public point read followed by an effect
page starting immediately before that position gives a bounded exact lookup;
the worker verifies the returned ID and payload. No history scan or second
effect index is needed, including after receipt loss or worker replacement.

Each segment has a nonzero adapter-defined kind, canonical Publication content,
and a monotonically increasing ordinal. At most one segment is staged at a time.
Its publication ID is ordinal + 1. The adapter bounds the buffer used to determine
length/digest before beginning a segment; loss before that commit remains a gap.
A begin reserves publication capacity and records the pending kind together.
A seal publishes the immutable bytes, writes one member and advances coverage in
one turn: two Publication mutations plus member and exchange descriptor, exactly
four mutations. No operation loads all members or bodies into memory.

Coverage is SHA-256 over a domain-separated chain of ordinal, kind, length and
Publication digest. The final descriptor fixes the segment count, bytes and
coverage chain, plus adapter terminal code. The adapter is responsible for proving
its protocol reached a terminal state and that the kinds/order cover the request
and response. The common library proves only the declared immutable coverage.
Empty bodies are explicit adapter records; no missing data is inferred empty.

Finishing capture and submitting the kernel observation are separate decisions.
If observation loses to closure, the sealed capture remains orphaned evidence;
it cannot be delivered as a successful outcome. Exact signed observation retry
recovers the original decision. A reference accepted by the kernel points to
already sealed capture. Cleanup first retires current exchange availability and
requires the owning application to discharge replay dependencies.

## Capture failure evidence

`closeUnknown(turn, failure)` atomically writes the descriptor and the first
failure record (two mutations). A later closure preserves that original record;
retirement and member cleanup retain it. Current-authorized `failure` reads
verify resource, exchange, writer, sealed prefix and any already-bound attempt
against the same descriptor cut. A terminal unknown capture without this record
is invalid history, not an implicit generic failure. The current contract-set
definition replaces the earlier stored semantics; old snapshots and peers are
rejected before execution.

Key tag `f`, ordinal zero, contains exactly 197 bytes: `EXF1`, resource:u64,
exchange:u64, owner:u64, principal:u64, input:u64, reason:u8, operation:u8,
origin_input:u64, kind:u32, member:u32, chunk:u32, requested_bytes:u32,
cause_length:u8, cause_truncated:u8, cause:[96]u8, phase:u8, effect:u64,
attempt:u64, segments:u32, bytes:u64. Integers are little endian; unused cause
bytes are zero. The cause is an owned UTF-8 error name with explicit truncation,
never request/response content, routing, credentials or secret references.
Reasons are caller_closed=1, controller_release=2, recovered_incomplete=3,
transport_failure=4, capture_failure=5 and preparation_failure=6. Capture operations are none=0,
callback=1, begin=2, append=3 and seal=4. Transport, capture and preparation failures carry an error name. Only capture
failures carry capture-operation context; preparation failures use origin_input
for the original accepted request input. Member and chunk
indices are zero based. Zero origin_input means no confirmed receipt identified
the failing capture operation. Input positions identify admission, not later turn
commit order, and may precede the attempt that was eventually closed.

The common worker admits the same bounded record as an authenticated private
Station cast, with the exact target resource/exchange and zero owner, principal,
input and retained-prefix fields. Its replay handler fills those fields from the
original closing turn. Worker replacement can therefore retain an admitted
failure even if its send receipt was lost; it does not need the previous process's
memory and does not dispatch external I/O. If the original cause never reached
admission, recovery explicitly records recovered_incomplete. Pending uncertain
native work must still reconcile before another input can be sent.

This witness closes capture only. Its diagnostic has outcome `not_applicable`;
it does not settle the native effect, prove remote failure, or permit a new send.
Native effect outcome and its original closure evidence remain independently
inspectable. The finite workers emit both nullable `capture_diagnostic` and
`effect_diagnostic` alongside their primary phase/outcome JSON. Diagnostic
construction failure cannot replace that primary result.

The shared client and Station HTTP/gRPC read boundaries accept a diagnostic
identity `{resource, exchange}` and kind `capture_failure` or `native_effect`.
Exchange IDs use canonical full-width decimal strings at the host boundary.
The result is `{diagnostic: Diagnostic | null}`. Protocol identity is checked
against the descriptor. Missing evidence is nullable only when the recorded
state permits absence; missing failure for an unknown capture and missing effect
for an existing intent are errors. The native effect is bound to the immutable
intent entry's committing revision, owner and exact payload. Effect paging uses
the authority position captured with the resource read; concurrent changes can
expire that cut. Capture permission is rechecked after independent effect reads.
Current resource inspection/read grants and, for native effects, connector-PID
inspection are required. Retired exchanges retain this evidence. Reads do not
create a replay cursor or perform mutations, credential resolution or external I/O.

## Accepted preparation failures

`closePreparation` closes an accepted exchange only while its descriptor is
preparing and its control has no intent. It atomically writes the descriptor,
EXF1 failure and original validation context in three mutations. A later close
preserves the first cause. Missing or inconsistent context is invalid history;
retirement retains both records. A closure after intent publication is refused.

Key tag `p`, ordinal zero, contains the 216-byte `EXP1` record. Its fields are
resource:u64, exchange:u64, original input:u64, reason:u8, check:u8,
field_length:u8, field_truncated:u8, field:[32]u8, cause_length:u8,
cause_truncated:u8, cause:[64]u8, then expected and actual scalars, each comprising
kind:u8, number:u64, length:u8, truncated:u8, text:[32]u8. Integers are little
endian. Reasons, checks, scalar tags, canonical padding and truncation follow the
[admission witness](CONNECTOR_ADMISSION_V1.md), with the busy reason and unrecorded check excluded,
and a required original cause. The input must match the descriptor's original
accepted input (the root request for a follow-up exchange). The immutable private worker input has this same layout and
binds resource, exchange and original input before admission.

After that failure input is admitted, replacement consumes its original evidence
even if configuration has changed. Publishing the saved route returns a
`not_dispatched` outcome; it does not return an input rejection. The independent
capture diagnostic is `exchange.preparation_failed`, stage `prepare`, with
outcome `not_applicable`, original cause, field, rule and permitted comparison
values. The native-effect diagnostic read returns null because no intent exists.
Known validation failures can close preparation. Allocation, storage, trust-file
I/O and unresolved authority failures propagate without creating terminal evidence.

## Explicit followups

Root exchanges default to one attempt. `configureAttempts` can set an immutable
finite total budget while the root is still preparing. Every retry, redirect,
status query or remote cancellation consumes one slot; closure and restart never
refund it. `followup` requires a terminal captured or unknown parent with a
settled kernel effect and records
the original root/caller/input/deadline, parent, ordinal, reason and opaque
versioned adapter-policy decision. Policy references convey no authority.

Creating a child consumes four mutations: publication namespace, descriptor,
lineage and root budget. The child then stages its exact request and commits its
own effect intent. Matching duplicate creation consumes no slot; conflicting
identity, exhausted budget or partial private mutation fails atomically. The
common library cannot decide remote retry safety. HTTP/gRPC must validate the
actual endpoint contract, destinations, credentials and explicit decision before
calling this API. No automatic external retry is added.

Budget keys use tag `b`, ordinal zero; `EXB2` values contain
limit/used/unsettled:u32. The unsettled count excludes the root and cannot exceed
used minus one. Allocation increments used and unsettled in the same mutation.
Terminal child settlement decrements unsettled exactly once; explicit abandonment
before intent decrements it on retirement. Neither operation refunds used slots.
While any child remains unsettled, retirement of all settled members in that
lineage is refused. This deliberately conservative hold protects ancestors'
request/policy evidence during child preparation and recovery, without scanning
or storing all descendants in memory. An abandoned child has no effect and cannot
admit descendants, so it can retire independently of other outstanding children.
The older EXB1 layout lacks these holds and is rejected. Existing EXB1 exchange
state requires a fresh installation; automatic migration is unsupported.
Child lineage keys use tag `l`, ordinal zero; `EXL1` values contain root:u64,
parent:u64, ordinal:u32, reason:u8 (retry=1, redirect=2, reconcile=3, cancel=4),
policy:u64 and policy_revision:u64. These additive records preserve existing
descriptor, member and frozen intent encodings.

`followupWithContext` adds immutable adapter-owned routing/context bytes to that
same allocation, without another mutation. Nonempty context uses `EXL2`: the
same 37 bytes of lineage fields after its magic, followed by context_length:u8
and exactly that many bytes (1–214). Empty context retains EXL1. Decoding rejects
trailing bytes, empty EXL2 and malformed lineage. Context contains no credentials
and confers no authority. A duplicate must match the original bytes exactly;
it cannot attach or replace context after allocation. Descendants preserve the
original root/caller/input/deadline across either encoding. `lineage` exposes
this bounded evidence through the caller-supplied authorized read surface.
The [independent lineage fixtures](../packages/zig/transit-exchange/src/lineage-fixtures.json)
fix full-width root/parent identities and binary context using Python `struct`.

## Reads and cleanup

Reads resolve current availability before reading a captured source. A retained
old root must not turn a retired exchange into an available one. The caller
provides a fresh current-authority reader for every bounded read; the native
cursor is trusted local state, not a bearer token. Each member verifies its
Publication digest; only the last verified member and final coverage commitment
establish complete replay. Unknown capture is inspectable as partial evidence,
but complete replay rejects it. Replay APIs have no transport or secret resolver.

`settle` records a terminal authenticated kernel effect read, checking the frozen
intent and bound effect/attempt/executor identity. Merely finishing capture cannot
discharge an effect obligation. If dispatch succeeded but the worker disappeared
before binding capture, unknown settlement recovers that effect/attempt/executor
from the authenticated terminal read, preserving the original deadline. It cannot
invent a response or authorize another send. Missing identities or a changed
deadline reject atomically. Caller replay remains held after settlement until
an authenticated acknowledgement or an explicit authorized disposal invokes
`releaseCaller`. Termination, quota pressure and elapsed time do not release it.

Additional consumers use permanent dependency tokens with an immutable holder
PID. Admission and release update one token and one count in the fenced writer's
turn; no operation loads all dependencies. Matching duplicates are inert, a
released token cannot be reacquired, and another holder cannot release it. The
adapter must authorize holders and compatible resource lifetimes before admission.
Tokens neither grant reads nor expire automatically. A service admitting a
reference must register its dependency before exposing it; opaque bytes do not
discover dependencies. Children protect ancestor evidence through the root budget
until settlement or abandonment; their own caller replay holds remain independent.
Other cross-service consumers still require explicit dependency tokens.

Retirement rejects outstanding effect obligations, unsettled descendants or
caller/consumer holds, then
preserves the final descriptor. Cleanup visits one publication at a
time and deletes at most two chunks per turn, preserving descriptors and terminal
IDs. A staging record is abandoned before cleanup. Historical protected roots
remain subject to resource rights and their own release; this is logical cleanup,
not physical erasure. Unlimited retention is the default; neither capacity nor
worker restart authorizes retirement.

Additive control values use key tag `c`, ordinal zero: `EXC1` contains dependents:u64,
disposition:u8 (no_intent=1, pending=2, observed=3, cancelled=4, closed_unknown=5),
caller:u8 (none=1, held=2, released=3), effect:u64. The frozen `EXI1` is retained at
tag `i`, ordinal zero. Dependency keys are `00 45` + exchange:u64 big endian +
`h` + token:u64 big endian; `EXH1` values contain holder:u64 and phase:u8
(held=1, released=2). Absent control means no published intent and no holds;
bound captures lacking control cannot retire. Snapshots without these records
cannot be migrated automatically.

## Encoding and proof boundary

The public `Client` uses ordinary current resource reads, not owner-only retained
execution versions. Each step obtains a fresh cut, checks complete current group
availability and the unchanged member commitment, then resumes verified chunk
progress. This permits unrelated resource growth without changing the result.
Mixed or missing immutable content fails its digest/coverage check; the cursor
cannot turn an expired grant or retired group into an accessible one.

All integers in values are little endian; keys use big endian identity/ordinal.
Values have magic/version prefixes, reject unknown tags, trailing bytes and
inconsistent counters. Public Zig types own the exact codecs and shared fixtures;
host APIs must reuse those codecs. Resource values remain at most 256 bytes and
turns at most four mutations. Configured per-exchange limits bound live work,
while resource quotas bound durable history independently of resident memory.

The [proof ledger](../docs/history/qualification/README.md) records HTTP disk recovery and the RPC
corpus for binary and directional records. This contract alone is not evidence
of network isolation, complete HTTP/gRPC capture,
SDK compatibility or remote exactly-once execution.
