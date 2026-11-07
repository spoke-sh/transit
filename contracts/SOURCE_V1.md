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

Every raw record access and buffered, repeated or terminal reader response must
check current destination Stream and capture-disclosure rights. Generic record
reads cannot bypass them. Source-control rights alone disclose no raw body.
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
