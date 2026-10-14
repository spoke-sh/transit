# Account operation ledger

`Ledger` composes pure Station turns over one private KV resource per SQL
account. It supplies preparation, discovery, signed-step publication, receipt and
processed-input recording, cancellation requests and terminal summaries. It
performs no network sends. A host/coordinator must supply authenticated native
inputs, current committed reads, actual Table observations and dispatch only
committed `pendingStep` results. `Behavior`, `Control`, `Client` and `Coordinator`
supply the native adapter and scheduler described below; the deployment still
owns worker lifecycle, exact pending controls, key custody and socket admission.

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
account configuration, realm/resource, minimum resource revision and last ID.
Operation identities are retained and strictly increasing. Each page acquires
current authority and a fresh cut at or after the previous page's revision;
concurrent progress and new operations do not invalidate traversal. A changed
account or backward revision rejects. The sequence is not an atomic snapshot:
phases describe each page's cut, and later appends may require another listing.
`discover` reads the nonce index. These reads never reconcile or dispatch.
Retained history, unfinished uploads and ready work have separate durable indexes.
`indexed` visits at most one native page and returns the next unsettled upload or
ready operation. Its cursor is advisory and every acquisition checks current
state. Retained history adds no scan work to these scheduling lookups.
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

## Native adapter and coordinator

`Control.Command` encodes `GSQ1`, the mandatory current definition and one bounded
tagged command. Fields use declaration order and little-endian integers; optional
values have an exact zero/one presence byte. Parts contain an aligned u32 offset,
u8 length and 128 bytes with zero padding. All commands fit one Station cast.
Unknown tags, foreign definitions, invalid padding and trailing bytes reject.

`Behavior` supplies a GenServer handler and input guard. Initialize the private
owner with an operator input before accepting ingress. After initialization,
rejected commands commit an attributed `GSD1` disposition containing native input,
principal, payload fingerprint and bounded error name. Application mutations from
a rejected transition are discarded. Source read failure, allocation failure and
host cancellation propagate without committing an application rejection.

`Client.Prepared` freezes the full native request and signature, configuration
fingerprint and identity. Canonical saved JSON requires the current definition.
`submit` attempts those exact bytes; `progress` distinguishes pending inputs from
processed inputs with or without a rejection. It does not infer SQL completion.
One serialized caller owns each command principal and retains an uncertain
request before allocating another sequence.

`Coordinator.next` verifies the native generation/worker, observes one unfinished
upload and one active operation, and returns an idle, blocked, control or dispatch
action. It retains at most one complete typed intent and one step candidate.
The caller durably processes a control before asking for a successor. A replacement
can publish a completely staged step; an incomplete unpublished step is abandoned
and its partial bytes collected before another attempt. Published steps always
come from committed `pendingStep` reads and are never re-signed. `dispatch`
rechecks the fence and pending identity before attempting the saved Table send;
its returned receipt control still requires a separate ledger commit.

Finite intent reads prefetch at most eight publication chunks per native read
and reuse the existing bounded source cache. The account finishes a captured
native turn before acquiring an intent for the coordinator, so that separate
read work cannot consume the turn's read-view lifetime. Digest, publication and
identity checks still cover the complete intent; a failed page poisons the read.

Native processing, Table completion and current disclosure authority are checked
separately. The account runtime retries unavailable discovery and terminal reads
within the caller's original deadline, retaining the same nonce, intent and
operation. These reads never resubmit SQL or replace an accepted intent.
Cancellation selects the original DDL, DML or upload identity. A
rejected Table disposition blocks automatic progression until operator action;
reconcile can resume the original qualified work, without granting new rights.
