# Station exchange capture v1

Status: M15 implementation contract; connector qualification is still in progress.
This is a framework layout over growing KV and [publication v1](STATION_PUBLICATION_V1.md),
not a new kernel effect or a permission carried by a reference.

## Ownership and identity

An exchange is `(resource:u64, id:u64)`, with a nonzero application-assigned ID.
It owns that publication namespace exclusively. A fenced exchange writer owns
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
In growing v3, the immutable intent entry's revision and the same-turn effect ID
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

## Explicit followups

Root exchanges default to one attempt. `configureAttempts` can set an immutable
finite total budget while the root is still preparing. Every retry, redirect,
status query or remote cancellation consumes one slot; closure and restart never
refund it. `followup` requires a terminal captured or unknown parent and records
the original root/caller/input/deadline, parent, ordinal, reason and opaque
versioned adapter-policy decision. Policy references convey no authority.

Creating a child consumes four mutations: publication namespace, descriptor,
lineage and root budget. The child then stages its exact request and commits its
own effect intent. Matching duplicate creation consumes no slot; conflicting
identity, exhausted budget or partial private mutation fails atomically. The
common library cannot decide remote retry safety. HTTP/gRPC must validate the
actual endpoint contract, destinations, credentials and explicit decision before
calling this API. No automatic external retry is added.

Budget keys use tag `b`, ordinal zero; `EXB1` values contain limit/used:u32.
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
discover dependencies. Child exchanges with independent copied bodies need their
own holds; retaining parent evidence for later use requires an explicit token.

Retirement rejects outstanding effect obligations or caller/consumer holds, then
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
bound captures lacking control cannot retire. These are additive experimental
records, not a migration promise for prequalification snapshots.

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

M15 must qualify these contracts with HTTP and disk recovery before completion;
M16 must reuse the same corpus for its binary and directional records. This
contract alone is not evidence of network isolation, complete HTTP/gRPC capture,
SDK compatibility or remote exactly-once execution.
