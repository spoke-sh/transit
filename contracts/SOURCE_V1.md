# HTTP source ingestion v1

Status: durable CONNECTION/SOURCE declarations, bounded inspection, retirement
and restricted DROP through the typed Catalog and native cohosted SQL service.
HTTP scheduling, capture and activation remain uninstalled; their execution gates
below are requirements for a later slice.
Migration files reject connector declarations before admission; reviewed
dependency plans and migration step recovery for these objects are not installed.

The public [CREATE SOURCE reference](../docs/handbook/reference/sql/create-source.md)
owns syntax and capability labels. [`Source.zig`](../packages/zig/transit-protocol/src/Source.zig)
owns neutral types and deterministic transitions;
[`SourceSql.zig`](../packages/zig/transit-sql/src/SourceSql.zig) owns typed parsing.
[`SourceBinding.zig`](../packages/zig/transit-catalog/src/SourceBinding.zig) checks
an explicitly supplied destination schema and policy without catalog lookup.
Neither performs network I/O, grants privileges, retains data or proves a worker's
honesty.

## Declaration and identity

SOURCE owns ingestion into an explicitly named, existing Stream. Its name is
not a query relation. A SELECT or metadata read must never dispatch a request.
CONNECTION stores an HTTP origin; the executor separately binds an authorized
transport route and TLS hostname. An origin does not enable DNS or proxy access.

The first profile is HTTP GET, branch one, one catalog, one single-partition
Stream and one pending poll per source. The source freezes its own definition,
the connection and destination definitions, an explicitly provisioned executor,
the five HTTP options and seven stable destination column IDs. Definitions use
the shared current-v1 identifier with no missing-field defaults or fallback.
Incompatible persisted integration follows the repository's current-v1 cutover.
The mandatory CONNECTION/SOURCE authority domains and Catalog root changes use
the current-v1 hard cutover; old installations and requests reject before use.

Resolve names only during declaration binding. Reject replaced definitions,
different scopes, duplicate/zero column IDs, a non-Stream target, partition
routing, compaction, missing or additional columns and defaults. The schema
has these non-null fields, matched by name independently of physical order:

| Field | Logical type | Meaning |
| --- | --- | --- |
| `capture_id` | UUID | Unique original poll identity |
| `source_sequence` | UINT64 | Monotonic source-local sequence, starting at one |
| `observed_at` | TIMESTAMPTZ | UTC capture completion instant |
| `http_status` | INTEGER | Final status, 200 through 599 |
| `body_ref` | BINARY | Opaque retained capture descriptor |
| `body_bytes` | UINT64 | Decoded HTTP body length |
| `body_sha256` | BINARY | Exactly 32 bytes, SHA-256 of that body |

`Capture.observed_at_ms` stores whole milliseconds since Unix epoch. Row
publication converts that value with checked arithmetic to the logical UTC
timestamp representation. A civil `TIMESTAMP` is not an observation instant.

HTTP origin values are at most 2,048 ASCII bytes and exclude credentials, query,
fragment and non-root paths. Paths are at most 8,192 ASCII bytes in origin-form,
begin with one slash, retain exact escaped bytes,
and exclude fragments, backslashes, controls and malformed percent escapes.
They cannot override the connection's authority. Secret/header/request-body
options are outside this initial profile. Durations are positive unsigned
integers with `ms`, `s`, `m`, `h` or `d`, converted to milliseconds with checked
arithmetic. Byte budgets are positive integer literals. Deployment limits apply
in addition to declaration budgets; declaration validation grants no capacity.

## Immutable declaration artifacts

[`SourceDeclaration`](../packages/zig/transit-catalog/src/SourceDeclaration.zig)
defines a dedicated connector artifact, separate from relational view schemas.
Canonical bytes have an eight-byte `TSOURCE1` prefix, the 32-byte current contract
definition, and canonical JSON. The payload contains object/revision, original
namespace/name, native authorization reference, owner and either an HTTP origin
or the exact source binding. Its own digest is excluded. SHA-256 of the complete
canonical bytes supplies both the immutable content commitment and definition
digest. Artifact and saved request encodings are each bounded to 64 KiB.

[`DirectSource`](../packages/zig/transit-catalog/src/DirectSource.zig) separates
that immutable declaration from control epoch and dropped state. A saved request
binds the original operation, exact expected definition, namespace/name, payload
commitment and, for control or source DROP, expected epoch. RETIRE increments the
control epoch without changing definition identity. DROP retains the immutable
identity and original receipt. Reusing a name cannot reinterpret that receipt.
The declaration-only typed profile rejects AUTHORIZE, ACTIVATE, SUSPEND and
RESUME before admission at both the Catalog and SQL boundaries.

A reservation commits the saved request's content reference before staging its
bytes. Only an applied operation can carry a resulting declaration. Source
publication and DROP carry their two dependency changes in the same control
record. The destination writer key is its stable object identity; the value
retains its exact definition and original source operation. Control metadata
reports unsupported execution, `never_run` and absent poll/publication positions.
It must not synthesize an authorization or executor failure.

## Publication, controls and authority

CREATE is a recoverable original operation. Reserve ownership before staging
bytes, protect exact connection/destination dependencies before publication,
and reject competing registered source writers. Creating a source neither
creates its destination nor grants control, append, secret or disclosure rights.
Ordinary Stream append rights remain separate; applications restrict them when
exclusive ingestion is required.

The neutral execution transition table below remains the future activation
contract. The installed declaration profile implements only published-to-retired.
Each accepted transition increments an
overflow-checked epoch, fencing earlier execution ownership:

| Current state | Permitted command | Next state |
| --- | --- | --- |
| Published | AUTHORIZE | Authorized |
| Authorized | ACTIVATE | Active |
| Active | SUSPEND | Suspended |
| Suspended | RESUME | Active |
| Any non-retired state | RETIRE | Retired |

A repeated client token observes its original outcome; it does not apply the
transition again. A new ACTIVATE token against Active is an invalid transition.
Retirement is permanent. Authorization is an observed lifecycle step, never a
cached grant. Recheck current control, executor, connector, secret and destination
authority at admission, immediately before send and at publication.

SUSPEND fences new admission/unstarted dispatch and new output publication.
In-flight work can retain terminal evidence. RESUME resolves that original work
under current rights before admitting another poll. RETIRE records the unfinished
work's disposition and prevents future publication; it cannot cancel an external
request already sent or discard its evidence. Control-versus-output races are
ordered by the common transaction decision. A committed output remains committed.

## Original attempt and polling

Each poll has an independent UUID, positive sequence, exact source definition,
original operation, admitted control epoch and due time. Sequence allocation and
the frozen Queue intent share one durable decision. Persist `dispatching` before
external I/O. Redelivery, process replacement and timeout never move an original
attempt back to `scheduled`.

| State | Permitted successor |
| --- | --- |
| Scheduled | Dispatching, Retired |
| Dispatching | Captured, Incomplete, Unknown |
| Captured | Published, Retired |
| Unknown | Captured through verified original-capture reconciliation, Closed unknown |
| Incomplete, Closed unknown, Published, Retired | None |

Transport completion can establish Captured only from the original dispatched
attempt. Recovery of Unknown may recover an already sealed original capture
through `reconcileCapture`; the owner must verify retained completion evidence
before accepting that transition. It cannot synthesize success or resend. Its
authoritative closure uses the existing bounded reconciliation policy; absent
authority or storage keeps it unresolved. A response after closure remains
diagnostic evidence, not a new publication.

Fixed-delay scheduling admits the first poll at accepted activation time. After
terminal settlement, the next due time is that settlement time plus the interval.
An unresolved or retained-unpublished poll blocks successors. There is no catch-up
burst after downtime. Trusted time comes from the host outside deterministic
transitions; a backwards terminal time or arithmetic overflow rejects. A later
poll is a new observation, not recovery of a lost response or proof that every
upstream revision was observed.

## Capture and atomic output

Reuse the [HTTP framing and completion rules](STATION_HTTP_V1.md#captured-records).
There is one remote attempt, no redirects, automatic retries, conditional cache,
pagination or application decoding. Complete non-2xx responses retain their
actual status. Empty responses are explicit, with SHA-256 of the empty byte
sequence. A 304 does not inherit an older body. Truncated, malformed, oversized
or otherwise incomplete responses do not produce complete-body rows.

`Capture.requirePoll` checks exact source/connection/destination definitions,
original operation, UUID, sequence, observed time and body budget. Type validation
alone does not establish complete framing, retained bytes or an accepted commit.

Body bytes live outside the Stream row, in bounded chunks with a paged manifest
that binds order, lengths, digests and terminal coverage. Owned staging precedes
each write. A 4 MiB body must not require a 4 MiB mailbox frame, row or scratch
allocation. Charge encoding and manifest overhead separately. A binary reference
or content hash is not a retention pin.

The common output decision attaches the verified capture root, appends exactly
one envelope, records its Stream position and checkpoints/settles the original
work. Recovery after a lost response returns that original position. It never
appends again. The [direct transaction contract](DIRECT_TABLE_V1.md#signed-transaction-action)
owns decision evidence and abort cleanup.

Station capture finalization and direct publication are presently different
decisions. An adapter must retain the original capture hold while copying verified
permitted bytes into destination-owned staging, durably record each handoff phase,
and release the hold only after the direct decision is authoritative. A qualified
direct capture owner can replace that handoff, but neither a temporary URL nor
unretained provider bytes can implement it.

## Disclosure, lifetime and qualification

### Owned capture representation

`SourceCapture.Evidence` binds a captured original poll, exact CONNECTION and
destination definitions, the seven stable column IDs, original effect attempt,
sealed exchange commitment, terminal coverage commitment and verifier definition.
It distinguishes the whole-body digest from the manifest digest. Empty bodies
have zero bytes and SHA-256 of the empty sequence. Shape validation establishes
neither HTTP completeness nor execution authority. Admission requires a trusted
host verifier of that exact original and current source-disclosure/destination
append rights; an executor field or caller-supplied captured state is insufficient.

`SourceCapture.Reference` identifies the candidate by its original token digest,
exact destination definition and retained manifest commitment. Its canonical JSON
encoding is bounded to 4 KiB. It contains no body, page inventory, credentials or
provider URL. A copy continues to identify the original publication; appending a
lookalike BINARY value does not create an attachment. Resolution must establish
the authoritative common decision and exact Stream position before disclosure.

The storage integration uses sequential 64 KiB chunks and a paged ordered
inventory, retaining offsets, lengths and SHA-256 commitments. Reserve before
creation; seal only after verifying complete ordered coverage. A missing page is
an error, including for an expected empty body. Metadata and transport encoding
are charged separately from raw bytes; the 16 KiB Catalog WAL limit is unchanged.
These types are the representation contract; they do not install capture mutation
or reader routes by themselves.

### Protected capture publication

The component owner saves `DirectSourcePublication` (SCP1) in the candidate before
admitting its original transaction. It freezes the candidate reference, exact
destination, transaction token, begin, append and settlement operations, and
budgets. `capturePublish` registers it; `captureAdvance` performs bounded original
transaction steps. The host serializes database publication and collection and
supplies the original verifier and current disclosure policy. Neither operation
is an installed mutation route.

The `source_capture` transaction purpose prevents generic begin, statement,
savepoint and settlement calls from operating that transaction. The owner encodes
the seven columns from the verified evidence and accepts exactly one append.
Every transaction publication rechecks source disclosure and destination append
rights. Internal source pins require append authority for this protected purpose;
they do not grant the importer destination READ. Existing transaction common-cut,
preparation, decision and cleanup rules still apply.

`StreamQueue.Append.capture` binds the original capture reference and transaction
identity. Ordinary Stream mutation routes reject a non-null attachment. The
accepted Stream batch directory supplies its exact offset; permanent operation
and producer receipts retain attribution but do not independently retain the body.
Current batches, retained read bases and unresolved transaction roots retain the
manifest and chunk inventory. Candidate ownership ends only after a verified
decision and complete participant cleanup: commit transfers it to the Stream;
abort permits collection. Lost replies resolve the saved original, never a new
transaction or offset. Generic record routes reject SCC1, SCM1 and SCP1.

Published capture reads require current destination Stream READ, database CONNECT
and schema USAGE. Private candidates additionally require their original owner.
SOURCE inspection/control, CONNECTION use and Stream metadata inspection grant no
body access. The importer independently needs source disclosure and destination
append rights. Buffered, repeated, empty and terminal responses recheck policy.
Retention protects availability, never grants permission.

The handoff holds the already sealed original exchange, verifies it once to
freeze body metadata, reserves the destination, then replays it again in bounded
chunks. Both passes and recovery are charged. It releases the original hold only
after the destination decision is authoritative. An uncertain hold, commit or
release remains attached to the same original identity. The common decision must
attach the graph and exactly one envelope; receipt metadata survives later
authorized payload release. Unrelated committed transaction records retain their
existing lifetime. Activation remains gated by the execution proofs below.

Every published raw read and buffered, repeated or terminal reader response checks
current destination Stream READ with database CONNECT and schema USAGE. Private
candidate work additionally checks the importing owner and upstream disclosure
authority. Generic record reads cannot bypass these checks. Source-control rights
alone disclose no raw body.
Inspection reports definitions, desired state, observed blocking reason, epoch,
pending original attempt, last settlement and last complete publication separately.
It performs no dispatch, cleanup or implicit read of response bodies.

Capture reachability must survive restart, Stream retention and retained readers.
Unlimited retention is default. Retirement, quota pressure and storage outage
do not authorize expiry. Eligibility, logical release and physical collection
are separate owner decisions.

Activation remains unavailable until executable proofs cover exact declaration
binding and dependencies; current-policy revocation at every boundary; paged
4 MiB/empty/corrupt/incomplete captures; original-attempt fencing and unknown
closure; common output/checkpoint decisions; restart/lost replies at all handoff
steps; control/publication races; bounded memory and retention; and the installed
SQL journey. Parser, schema and deterministic-model tests establish only their
own boundaries.

## Published capture reader

The native `capture_read` action resolves an accepted protected publication before
serving bytes. `inspect` returns provenance independently of payload availability.
`open` acquires an original Stream pin over the exact envelope offset;
`inspect_open` observes that original, and `cancel_open` irreversibly closes an
unaccepted original or returns its accepted pin. `close` releases only that pin
using a separately saved operation. Lost replies never authorize another identity.

Continuations bind the current definition, connection, effective role, publication,
read receipt and aligned body offset with the installed Stream authority's private
HMAC key. Each `next` returns at most 65,536 raw bytes, encoded for transport, and
an explicit completion flag. The last data page is terminal when its coverage is
known; empty captures and repeated terminal reads return empty terminal pages.
The shared reader verifies the whole-body SHA-256 before reporting completion.
Output bytes are owned independently of subsequent scratch reuse.

Current destination READ, database CONNECT and schema USAGE are checked after
buffering, including repeated and empty terminal requests. Producer or connector
credentials are unnecessary. A failed shared reader cannot splice a resumed prefix.
Its saved originals remain available for explicit close even after a read failure.
Explicit Stream age expiry rejects new pins below the retained boundary with
`LogRangeExpired`; existing pins retain the attachment graph. Releasing the final
pin permits collection only after other recovery roots release it. SOURCE or
CONNECTION retirement/drop does not remove destination-owned bytes. Original
publication metadata remains attributable after payload collection.

## Sealed HTTP handoff component

`transit-source-import` composes above HTTP/Exchange and the data client. It accepts
only an explicitly host-verified complete finite original, never live network
work. SHI1 freezes the exact declarations, poll/attempt, Exchange descriptor and
reference, consumer token/holder, verifier, candidate, output transaction originals
and budgets. SOR1 reserves that input before acquiring a consumer hold. SHP1
progress uses the reserved CPR1 owner and the paged original-token directory.
The original caller hold is independent and is never disposed by this adapter.

The first replay uses HTTP's current-authorized coverage validator to derive
status, body length/digest and the HTC1 terminal commitment. A second complete
replay copies sequential 64 KiB chunks and must reproduce that exact evidence.
The exchange commitment is SHA-256 of the canonical EXD1 descriptor, retained
with its exact reference in SHI1. The trusted host checks the original authenticated
effect/attempt and terminal outcome separately; a complete descriptor alone is
insufficient. Neither replay can dispatch or resolve credentials.

Each step advances one durable phase or at most 256 Exchange parts. The transcript
limit is 8 MiB/65,536 members, body limit 4 MiB, and adapter scratch limit 2 MiB.
Each importer reserves 16 MiB of the shared 64 MiB capture admission budget,
including nested candidate/verifier headroom, before accepting active work.
Every pass, including a restarted pass, charges its entire transcript byte/part
bound before reading. Source-candidate verification separately charges its own
work. Exhaustion preserves the original and control capacity for observation and
closure. No accepted identity or charged work is reset by restart.

The protected Stream transaction supplies the authoritative destination outcome.
Only after the journal retains that outcome may the adapter release its original
Exchange dependency; an uncertain release is retried with the same token/holder.
Cancellation closes private storage or settles the original transaction. A frozen
plan with no transaction reservation may be permanently fenced closed under the
serialized owner; it retains the plan without inventing a transaction decision.
A saved transaction binding requires ordinary recovery. Revocation, missing
observations and timeouts never establish an abort. This component supplies no
installed mutation route, SQL import verb or SOURCE activation.
