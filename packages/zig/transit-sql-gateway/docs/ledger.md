# Account operation ledger

`Ledger` composes pure Station turns over one private KV resource per SQL
account. It supplies preparation, discovery, signed-step publication, receipt and
processed-input recording, cancellation requests and terminal summaries. It
performs no network sends. A host/coordinator must supply authenticated native
inputs, current committed reads, actual Table observations and dispatch only
committed `pendingStep` results. The native transport/service integration is a
separate interface; these Zig methods do not create a running service.

## Identity and roles

Configuration fixes the realm, resource, owner PID, account fingerprint, Table
public key and 1–8 catalog bindings. Each binding fixes resource/catalog/owner.
Worker, ingress, operator control, coordinator and Table principals are distinct,
nonzero native IDs. The deployment provisions their current native grants.
The private ledger resource is separate from every configured catalog resource.
Neither account names nor database selection grant native or catalog access.

The worker claims and commits the ledger PID. Ingress may begin an operation and
upload its intent. The coordinator may admit a validated intent, select ready
work, publish signed steps and record observations. Every coordinator mutation
includes the expected native generation and checks the delivered owner/worker.
Operator control may request reconcile/cancel, increase quotas and reserve more
recovery space; it cannot publish steps or report receipts/outcomes.

Initialization accepts a fresh resource containing at most the Station server
descriptor. The stored configuration fingerprint rejects changed identity or
catalog mappings on reuse. Initial quotas are separate from this immutable
fingerprint: explicit operator capacity increases are retained in the head.
SQL password/verifier rotation is outside ledger identity; native key or scope
replacement cannot reinterpret a saved step.

## Preparation and discovery

`begin` allocates the operation ID from its native input position. A caller-owned
16-byte nonce indexes that ID, so a lost response can be discovered without a
previously delivered handle. Repeating the same nonce/binding returns the original
operation; a different binding rejects. SQL resubmission uses a new nonce and is
new work. The method reserves capacity before writing the operation and index.

The caller prepares a typed `TableIntent` with this operation/upload identity.
`beginIntent`, `intentPart` and `sealIntent` retain its exact bytes. Sealing alone
does not admit dispatch. `admitIntent` reads the complete published record,
restores and validates the canonical intent, verifies the frozen connection and
identity, and admits only CREATE/INSERT/UPDATE/DELETE. It stores a bounded binding
and adds the operation to the ready index. All helpers preserve native limits of
four mutations and 256-byte values per committed turn.

`list` returns at most one native page of eight operations. A cursor binds the
account configuration, realm/resource, captured resource revision and last ID.
Changed cuts reject; the caller must acquire another qualified page sequence.
`discover` reads the nonce index. These reads never reconcile or dispatch.
Retained history and the ready index are durable keys, not resident arrays.
`activate` chooses the oldest ready ID, with at most one active operation for the
account's dedicated Table principal.

## Exact sends and observations

`beginStep` and `stepPart` stage a bounded `SavedStep`. `publishStep` checks its
signature, original typed intent, exact byte range and the ledger's next principal
sequence before atomically publishing it and recording the pending pointer.
The intent binding is established by a full canonical/digest check once; step
validation reads at most the original inline command or one 128-byte command
part from immutable committed chunks. It reuses `TableIntent.Binding.matches`.

A private proposed publication cannot authorize dispatch. The coordinator must
read `pendingStep` from committed state after the native turn succeeds. On
uncertainty it retries that same signed request. No successor is admitted while
one step is pending. A replacement may finish the existing staged bytes, or
abandon an unpublished attempt and explicitly collect its bounded partial bytes.
Its permanent descriptor remains. Published pending steps cannot be abandoned,
re-signed or replaced through these operations.

`recordReceipt` separately records the actual native input and advances the
principal sequence. `recordProcessed` retains whether a Table input disposition
exists and, when present, its exact public encoding and commitment. Processing
without a disposition is not a SQL terminal outcome. A rejected disposition
blocks automatic progression until explicit reconciliation. The coordinator
must supply observed facts; native validation does not establish honest host
computation.

`Terminal.fromOutcome` copies attributed state, reason, input positions and
matched/changed counts from a validated native Table outcome. Upload cancellation
has a separate kind and no Table counts or fabricated completion input. Complete
records retain their identity and remain discoverable. Detailed witnesses stay
with the native owner; current Table authorization governs their retrieval and
all wire/control outcome disclosure. A cached ledger summary never substitutes
for that check.

## Cancellation, capacity and lifetime

Operator requests only record intent to reconcile or cancel. If no step was ever
published, the coordinator can cancel locally and remove ready work. An incomplete
intent is reported abandoned; an admitted operation reports cancellation before
dispatch. Once any step has been published, cancellation requires the original
qualified Table/upload control and observation. Socket loss, reset and inspection
do not invoke cancellation.

Quotas independently bound retained operation count, unsettled operations and
logical retained/reserved content. Pending quota defaults to 16 and is at most
1024. Total operation count has an explicit u64 deployment quota, not a resident
cardinality limit. The intent allocation limit is at most `TableIntent.max_bytes`.
A reservation is `intent_bytes + (ceil(intent_bytes/128) + 67)*1024 + 512`: it
covers the normal maximum upload and additional recovery controls. Each staged
step conservatively consumes 1024 bytes; operation metadata reserves 512 bytes.
These account budgets are not physical WAL/filesystem size guarantees.

New admissions cannot consume existing reservations. Terminal settlement releases
unused reservation while charging retained content; history is not removed.
Additional recovery attempts can request explicit capacity/reservation. Quota
pressure returns a capacity error and preserves pending bytes. There is no
history expiry, automatic accepted-work collection or quota-driven cancellation.
