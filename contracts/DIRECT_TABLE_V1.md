# Direct Table request contract v1

`DirectTableProtocol` defines signed Table declaration, row mutation, operation
inspection and retained-read requests. The node's internal `LocalTableService`
dispatches these requests through `DirectCatalog`, the Table storage owner and
native authorization. The local node's optional `table` setting serves
`POST /table/v1`; the local launcher configures that owner for its default Tables
and shared SQL runtime. Captured-source and SDK migration remain incomplete. The
[generated schema](direct-table-v1.schema.json) reflects the owning Zig types.

## Requests and authority

A request contains the mandatory current shared definition, connection, nonce,
action, nullable delegation, nullable closure authorization, nullable borrowed-read
authorization and transport proof. A null delegation
uses the original caller's proof. The connection binds the existing
realm/resource/catalog, branch one, audience, principal and optional selected
role. Changing any request field changes its context digest. The request domain
is `transit.table.direct.request.v1` followed by a zero byte and canonical JSON
of `Request.Input` in declared field order. Fixed byte arrays remain JSON arrays;
unsigned identifiers preserve their full range. Consumers must use exact integer
parsing. The proof signs that context through the existing authorization claim
contract; it creates no new permission authority.

The node authenticates the original caller against its current native credential,
role graph and backing-resource lifetime. Catalog operations check the registered
database/schema/Table bindings and their current privileges. A response binds the
request context, checked policy revision and verified native subject (principal,
login role, effective role, credential epoch and audience). The client checks
that subject against the original connection and signed caller claim. With a
delegation, its context is the delegation digest, or the separately signed
closure or borrowed-read context when that authorization is supplied; the response's separate
`context` still binds the complete transport request. The node checks all successfully
used requirements again after buffering the complete response. Denial at this
boundary suppresses the response, even if a mutation has already committed.
Recover that mutation through its original operation binding.

A mutation binding may also retain a native authorization `prerequisite`.
Admission, DDL preview, CREATE registration and Table acceptance check this
condition in addition to the transport caller's independent Table privileges,
under the same native authority fence. The condition can name the original
accepted native input of application work. A replacement worker authenticates
with its current credential while retaining that original condition; it cannot
remove the condition or substitute a newer caller input or credential on retry.
Inspection, cancellation and final response disclosure use the current data
caller's rights without requiring that original subject to authorize a new
mutation. Failure of the condition does not establish rejection or rollback.
The [frozen-binding contract](DATA_LIFECYCLE_V1.md#frozen-intent-and-acceptance)
defines its identity and recovery semantics.

`DirectTableClient` checks response context and kind, exact operation bindings,
terminal phase consistency, resulting definition revisions, matched/changed
counts, schema fingerprints, listing order and page limits. It owns decoded
responses independently of transport buffers. It performs one exchange per call;
timeouts do not trigger implicit mutation retries. A page consumer still needs
the retained source's schema, exact metadata and complete-consumption checks.
`DirectTableReader` supplies those checks for one retained Table: it owns the
original schema, advances only after fully decoding a valid page and verifies
the complete row count. Its explicit `check` revalidates current rights before
disclosure from cached data. Local destruction does not release the durable pin.

### Namespace lifecycle

`namespace_preview` and `namespace_operation` use `DirectNamespace.Binding`:
the current definition, exact connection, operation identity, namespace identity,
nullable complete expected schema record, and CREATE (name/owner role), RENAME
(new name) or DROP action. CREATE requires a new identity and no expectation;
RENAME/DROP bind the original namespace record, including its native authority
reference and revision. Namespace IDs and revisions use native counter bounds;
operation identities retain their full unsigned 64-bit range. Names use the
existing 63-byte UTF-8 catalog name contract.

Preview checks current permissions, identity, expected definition and name
availability. It publishes nothing and does not certify DROP dependencies.
`namespace_operation` explicitly inspects, admits, executes or cancels the exact
binding. The response is `not_observed` or an operation with its catalog WAL
position, phase (`admitted`, `applied`, `rejected`, `cancelled`), reason, nullable
scan cursor and nullable resulting schema record. Only `applied` includes a
resulting schema. The catalog WAL is this operation's acceptance authority;
its position is not a Table data frontier or a consistent multi-Table snapshot.

CREATE requires database CONNECT/ownership and eligibility for its frozen owner
role. Native schema registration is a separate recoverable step. The service
rechecks the original caller before each registrar publication and validates
the resulting native binding and owner before catalog publication. Admission
reserves the name and permanently claims the namespace identity but does not
make it visible. A cancelled admission retains that identity claim and any
completed native registration; it does not silently reuse or delete them.

RENAME/DROP require current CONNECT and ownership of the original native schema.
An admitted namespace change fences new Table DDL admissions in that namespace.
DROP examines at most one eight-entry object directory page per execution,
retaining progress in the original operation. A live Table or an uncommitted
Table declaration blocks DROP with a generic `dependency` reason; the response
does not disclose the blocking object's metadata. Committed but unsettled Table
outcomes are not pending declarations. This scan covers catalog-owned Table
membership, not unregistered external consumers. Native registration execution
accepts a 1–256 step budget; it does not widen the dependency scan page.

RENAME preserves identity; DROP removes live namespace visibility and retains
its original native permission object. Retained Table snapshots, history,
receipts and result evidence still require current permissions against those
original native references. Logical namespace retirement neither releases pins
nor physically deletes retained data. Recreating a name requires another
namespace identity. Exact retries after rename, retirement or credential
replacement return the original outcome; changed bindings or cross-kind reuse
of an operation identity reject. Response disclosure is fenced after buffering.

### Current observations

`observe` accepts a namespace, exact interpretation (object, revision and digest)
and nullable row limits. It requires CONNECT, USAGE and SELECT, including for a
metadata-only request. It returns the current immutable definition/schema,
accepted Table position, last logical change position, total row count and the
native authority references checked for that read. A supplied row budget also
returns the first physical page, its encoded byte count and `more`. Limits are
1–8 rows and 1–16 MiB of encoded rows (default 8 rows and 4 MiB). An individual
row that cannot fit the byte budget rejects; there is no truncated row.

The Table owner serializes this observation with writes and definition changes;
all returned metadata and rows describe that one root. Current rights are
rechecked after buffering, including empty pages. A changed definition or retired
Table rejects with HTTP 409 and `TableDefinitionChanged`, after current source
authorization. A generic `Conflict` does not establish definition drift. The
response preserves exact row types and physical identity order;
the client validates row encodings, count, byte budget and ordered identities.

This operation writes no log record, pin, intent or publication. It returns no
continuation or durable snapshot handle. `more` means the bounded observation
does not contain the complete Table; a later observation can see another root.
Consumers needing resumable traversal must explicitly acquire a durable pin.
Retained-read delegations and borrowed-read grants do not authorize `observe`.

`read_authority` accepts a stable object identity and checks its current
CONNECT/USAGE/SELECT requirements. It returns only the corresponding native
authority references, including after Table DROP or name reuse. It returns no
schema, rows, position or pin and grants no future permission. This lets an
owner authorize disclosure of retained diagnostics without requiring the old
name or interpretation to remain live. Its response is fenced after buffering;
retained-read delegations and borrowed-read grants do not permit this action.

### Delegated retained reads

`DirectReadDelegation.encode` retains the original grant in a canonical 311-byte
`TRG1` record. It contains the four-byte magic, mandatory 32-byte current
definition, connection scope (realm/resource/catalog), branch, audience,
principal, role-present byte and role value, executor, object ID, definition
revision and 32-byte digest, partition and accepted frontier, pin operation, retention byte, selection byte,
32-byte purpose, credential epoch, 32-byte claim context and 64-byte signature,
in that order. All integers are unsigned 64-bit little-endian except the
one-byte role flag, retention tag (`snapshot = 0`, `history = 1`) and selection
tag (`exact = 1`, `current = 2`).
An absent role has flag/value zero. Object and pin scope,
pin principal and repeated claim fields must match the connection; decoding
reconstructs only these constrained duplicates. Missing, foreign, truncated,
noncanonical or context-inconsistent records reject. Loading performs no
acquisition and does not establish current authorization or verify an unknown
signer's public key. The data owner still checks the original signature and
current caller/executor credentials on every request.

`DirectReadDelegation` contains a `binding` and original-caller `proof`. The binding
fields, in canonical order, are the current `definition`, original `connection`,
`executor` principal, exact `interpretation`, `expected` Table frontier,
`selection`, pin `owner` operation, mandatory `retention` kind and nonzero 32-byte `purpose` commitment. Its signing context is
SHA-256 of `transit.table.read-delegation.v1`, a zero byte and canonical JSON of
that binding. The purpose identifies application-owned immutable work; it does
not establish honest computation or enforce a SQL predicate. This grants read
scope over one complete Table cut for `snapshot`, or that cut and the same
object’s future history for `history`, with no additional object privileges.

The executor signs the entire request, including that retained delegation, with
its own current credential and login role. The request connection continues to
identify the original caller and selected role. The owner authenticates both
identities under the same native fence, checks the caller's current
CONNECT/USAGE/SELECT requirements and repeats both checks before disclosure or
pin publication. The executor needs no raw catalog or Table grant. Changing or
revoking either credential prevents use of the affected proof. Accepted work
retains the original delegation; recovery cannot replace its caller signature
or credential epoch implicitly.

Snapshot delegation permits `pin`, `pin_status`, `snapshot`, `scan`, `read_key`,
`release` and snapshot-only `check_set` for the bound object and pin owner.
History delegation uses `retain_history` instead of `pin` and additionally
permits `history_start`, `history`, `history_source` and `history_scan` at or
after the original frontier. Its ordinary snapshot reads still address only
the original cut. A snapshot grant cannot follow future history or upgrade an
existing pin. Both the immutable lease kind and original cut must match the grant. It permits no name
discovery, mutations, policy changes or further delegation. The `exact` selection requires the supplied frontier. The `current` selection
is available only for delegated snapshot acquisition: the supplied frontier is
a lower bound in the same partition, and the first acquisition freezes the
current root under the exact signed interpretation. A stale interpretation
rejects. Neither selection may change its pin owner or selection on retry. An
existing pin recovers its original cut after mutation, restart or definition
changes; it never selects another root. Current rights still gate disclosure. Release is terminal and requires current rights. Lost replies
use the same acquisition and the existing `pin_status` recovery rules below.

`DirectReadDelegation.prepare` signs this binding as the original caller without
acquiring a pin. A `DirectTableClient` with `delegation` set uses its key as the
named executor's key; it preserves the original connection and never signs as
that caller. Its response checks bind retained schemas and data frontiers to the
delegation. The `delegation` request field is mandatory even when null; the
replaced shared definition rejects previous envelopes without a fallback.

An explicit `DirectReadDelegation.Closure` authorizes cleanup after the original
credential changes. Its context is SHA-256 of `transit.table.pin-closure.v1`, a
zero byte and the exact 311-byte original `TRG1` grant, including its original
signature. It carries a current credential epoch and a 64-byte signature; the
remaining claim fields come from that original grant. Its compact encoding is
little-endian uint64 epoch followed by the signature (72 bytes). The transport
request includes both the unchanged delegation and this closure authorization.
The owner checks the current closure proof and executor proof together. Only
`pin_status`, exact-original `pin`/`retain_history` reconciliation and
`release` are permitted.
Schema and row reads reject, and cleanup cannot replace execution authority or
choose a newer cut. Exact-original acquisition may be needed to create a terminal
release record for an uncertain request whose frontier has not advanced.

`DirectReadDelegation.Borrow` grants another executor read access to one existing
cut. Its `binding` contains, in order, an executor principal, a target
(`snapshot: Snapshot` or `history: Historical`) and a nonzero 32-byte purpose.
It also carries the original caller's 64-byte signature. The claim retains the
original grant's identity, role, audience and credential epoch; its context is
SHA-256 of `transit.table.borrowed-read.v1`, a zero byte, the exact original
311-byte `TRG1` grant and canonical JSON of the borrowed binding. Preparing this
proof after the caller's epoch changes rejects instead of renewing accepted work.

The request carries both the original delegation and `borrow`. The transport
proof belongs to the borrower's current credential. The owner authenticates the
borrowed caller proof and current executor together and fences disclosure after
serialization. A snapshot target permits only `snapshot`, `scan` and `read_key`
for that exact handle. A historical target permits only `history_source` and
`history_scan` for that exact lease, position and record commitment. Acquisition,
release, history traversal, discovery and mutation reject. Borrow and closure
cannot be combined. Releasing the coordinator's lease ends borrowed access;
borrowed reads neither retain it independently nor reopen it. The purpose binds
application-owned work, not verified computation.

## Declaration and row operations

`preview` checks a frozen DDL proposal against current rights, object/name
availability, definition/data expectations and schema-evolution rules. It returns
the exact binding, independently observed directory/Table positions, a reason,
and the proposed schema fingerprint and work classification when admissible.
It writes no operation claim, intent, reservation or native registration. A
preview grants no rights or reservation and does not scan rows to prove that a
tightened constraint will succeed. Execution rechecks the accepted source and
all row constraints. Inspect an existing operation for its past outcome; preview
evaluates the proposal against current state.

`name_assertion` records conditional DDL that requires no Table mutation. Its
binding fixes the current definition, full connection, operation, namespace,
name, action, expected definition and complete proposed declaration commitment.
`create_if_not_exists` requires an exact existing definition; `drop_if_exists`
requires an absent name. `inspect` is read-only. `accept` compares that frozen
condition under the directory lock and current policy, then records `unchanged`
or `rejected` with reason `condition_changed`. `cancel` records `cancelled` if
there is no earlier outcome. All three terminal states retain a catalog WAL
position; none is a Table mutation or advances its data frontier.

Exact retries return the original outcome, including after rename, retirement or
name reuse. A different binding under the same operation conflicts, including
reuse as a Table operation. Current CONNECT/USAGE is required; CREATE also needs
namespace CREATE and INSPECT on the original existing Table. A changed name's
replacement is inspected only with current rights. Final policy checks fence
publication and disclosure. A prepared condition and its commitment confer no
rights and reserve no name. Ordinary CREATE/DROP branches use the Table DDL
owner when a mutation is required.

`initialize` initializes the configured catalog under its native owner;
`describe`, `namespace`, `list` and `lookup` inspect current authorized definitions.
Namespace inspection requires current CONNECT/USAGE; an absent namespace returns
null after the database check. Lookup returns the native authorization reference
and validates the complete accepted declaration, including namespace and name.
Listing
is an independent directory/Table observation, with at most eight entries per
page. Empty filtered pages may still have a continuation. An `after` value is
the last visited object ID, not a retained snapshot or offset into returned rows.

`check` performs read-only action-specific authorization. Database and
CREATE SCHEMA checks have no namespace or target; schema and CREATE TABLE checks
carry a namespace; Table checks carry both a namespace and an exact definition.
The Table owner serializes these checks against definition changes and checks
current rights before disclosing a stale-definition conflict. A check admits no
work, creates no pin and grants no continuing permission.

`DirectTableBinding` retains an exact connection, namespace, name and immutable
declaration for preparation. Row changes do not invalidate it. Definition changes
reject validation, and DROP/name reuse cannot retarget it. Every use still needs
current action rights. This binding is neither a data snapshot nor a prepared
SQL execution artifact.

`DirectTablePreparedDml` prepares INSERT, UPDATE and DELETE through Fuze's shared
typed template compiler. It checks the exact definition and requested mutation
right before and after compilation. Binding rechecks that identity, validates
typed parameters and returns independent `DirectTableIntent` bytes without
admission. Numbered Transit/PostgreSQL parameters and MySQL positional parameters
use the existing dialect rules. INSERT derives row identities from the new
operation; UPDATE/DELETE freeze the observed logical basis through its accepted
frontier. Parameter binding never becomes a recovery operation.

Saved intents start with `TDI1`, the 32-byte current definition, then canonical
JSON of mandatory `definition`, `connection` and `work` fields in that order.
`work` is exactly one of `ddl`, `rows` or `statement`, carrying the corresponding
complete admission payload. The reflected `SavedIntent` schema describes that
JSON. The maximum is 36 bytes plus the 8 MiB request bound. Loading rejects
incompatible, missing, malformed, truncated and noncanonical envelopes, validates
the owning payload and intent digest, and performs no network operation. Saved
bytes contain neither SQL nor credentials. The connection retains the selected
role; credential rotation can supply a new proof for the same operation.

`admit` submits the saved work once. Explicit `operation` inspection, execution
and cancellation use its original binding. No helper automatically retries an
uncertain attempt, refreshes a data expectation or recompiles a saved statement.

`stage` sends a namespace and complete saved intent directly to the data owner.
The owner checks current action rights, validates the complete work and stores
its canonical bytes as an immutable `direct-intents/<sha256>.data` object under
data quota. The returned reference contains the mandatory definition, original
connection, namespace, operation binding and complete content length/hash.
Staging creates no operation claim, admission, reservation or Table WAL record.
Repeated identical staging returns the same reference. Its bytes remain private;
there is no public payload-fetch operation.

`admit_saved` checks current original-caller rights before loading that reference,
verifies its complete content and binding, then invokes the same DDL or row
admission owner. A staged reference is neither admission nor a capability.
Missing or corrupt work stays unavailable; the owner never reconstructs it from
SQL. Current revocation can prevent admission after successful staging. A control
ledger can retain this bounded reference while the full payload travels directly
to storage. Staged objects remain retained; no collector is implemented here.

`admit_ddl` freezes namespace, name, exact binding and CREATE/ALTER/RENAME/DROP
intent. CREATE carries the selected owner and binary FTS1 schema; ALTER uses
shared column IDs, types, codecs and collations. Optional defaults carry typed
FVL1 cells, preserving binary bytes and finite floating-point bit patterns.
The native intent digest and all actual schema/value constraints are checked
before catalog admission. Admission publishes no Table.

`admit_rows` freezes a complete batch of insert rows, replacements identified by
their original storage keys, or deletion keys. FTR1 rows include their stable
row identities. The request includes its exact immutable interpretation and FTS1
schema. It admits at most 1024 changes within the storage owner's 4 MiB framed
work bound. Decoding additionally bounds cumulative row/key payloads to 4 MiB;
that preliminary bound does not promise the complete framed work will fit.
INSERT, UPDATE and DELETE admit only their matching change shapes.
INSERT row identities use `origin = original_principal + 1`, the original
operation ID and the row's zero-based ordinal in the admitted batch.
`Rows.insertIdentity` constructs that identity. Admission rejects another
principal, operation or ordinal before claiming the operation or staging work.
UPDATE preserves each selected row's identity even when its primary key changes;
deleting and inserting a row assigns a new identity. Identity is scoped to the
Table, independent of the user-visible key, name and physical row location.

The row intent digest uses `transit.table.direct.rows.v1`, a zero byte and
canonical JSON of `interpretation`, `schema`, `changes`, `ingestion` in that
order. It covers the complete frozen work independently of transport nonce or
current credentials. Retrying an operation with changed work conflicts. DDL
uses the existing canonical native catalog intent digest. The storage owner
also retains and compares the complete immutable admitted payload.

`admit_statement` carries `binding`, the exact `interpretation`, FTS1 `schema`
and an FDM1 `plan` as canonical binary fields. It admits typed UPDATE or DELETE;
INSERT uses the concrete row operation. A data-frontier expectation is mandatory.
Its intent digest uses `transit.table.direct.statement.v1`, a zero byte and
canonical JSON of `interpretation`, `schema`, `plan` in that order. The retained
plan owns predicate and assignment values; execution never recompiles SQL or
resolves the name again. Predicate text comparison supports `none` and
`utf8_binary` column collations; other declared collations reject before admission.

The Table owner checks the action privilege, selects rows privately and publishes
the complete result once. Selection does not disclose rows or require SELECT.
A later logical change rejects the frozen basis. UPDATE stages replacement
segments in groups of at most 1024 rows and 4 MiB of encoded row work. DELETE
changes the row indexes. Limits cover total decoded visits and bytes across
passes, separately from index staging and deployment storage quotas. Exhaustion
or a destination collision records terminal rejection without publishing any
changed rows. Current authorization is checked again at the final commit.

`operation` carries the original binding and `inspect`, `execute` or `cancel`.
Inspection starts no work. Execution resumes only admitted frozen work; CREATE
uses the native registration ledger before Table publication. Its step limit
is 1–256 native registration attempts per call, not a total progress limit.
Unknown operations remain `not_observed`. Rejection and cancellation require
accepted terminal evidence. A lost transport or storage reply establishes
neither; late cancellation returns the original commit.

## Retained reads and binary payloads

A `snapshot` source includes mandatory `authority` references for the native
database, schema and Table objects used by its read checks. These are identifiers,
not cached permissions. `DirectReadAuthority.guard` constructs CONNECT, USAGE and
SELECT requirements under an independently bound subject. A durable computation
uses these exact objects in its native progress/result commit so a policy change
after reading rows can still reject publication. Result disclosure uses its own
current subject. The original executor proof and a fresh result-reader proof
remain distinct. The direct owner rechecks its observed rights before returning
the source; the publisher must separately submit the native guard.

`pin` binds the original principal and exact expected Table frontier to a
durable read root. `snapshot` returns its retained interpretation, schema,
accepted frontier, logical-change frontier and row count. `scan` returns up to
eight owned rows under an explicit encoded-byte budget, with a cursor bound to
that retained root and its last returned canonical 20-byte row identity. Rows
are strictly increasing by identity, independent of their current physical
locators. It never substitutes the latest name or definition.
`read_key` accepts one nonempty canonical storage key (base64, at most the
physical collation key bound). Its `point` result carries the same snapshot,
interpretation, accepted frontier, logical-change frontier and total row count,
plus one optional FTR1 row. The owner uses the retained primary-key index and
checks the decoded row's actual key against the requested bytes, rejecting a
hash collision. Keyless Tables use canonical row identities as storage keys.
The reader verifies attribution and key equality under the retained schema;
a hit or absence does not advance sequential scan coverage. Current rights and
the live pin are required even when no row matches.
`release` records terminal pin release through reserved control capacity.
Current CONNECT/USAGE/SELECT rights apply to every operation, including release.

`pin_status` reads the original owner's handle, release state, current immutable
interpretation, physical frontier and Table retirement state under the same
owner fence. It acquires nothing. Absence at a later frontier or after retirement
proves the old exact-frontier acquisition cannot subsequently succeed. For a
delegated current-frontier acquisition, a later data frontier alone proves
nothing: absence together with a strictly later definition revision proves the
original acquisition cannot succeed. Definition revisions never move backward
or get reused. An existing pin must still be recovered and released under its
original grant, even after ALTER. Other absent states remain unresolved; recovery
may repeat only the original acquisition before releasing it. A timeout, generic
conflict or denied observation supplies no closure evidence.

`retain_history` acquires a history lease with the same exact-frontier and
private-owner rules as `pin`. `history_start` returns its original `HistoryPoint`
and `Source`. A point contains the lease handle, partition/exclusive frontier
and complete acceptance-record SHA-256 commitment. `history_source` reopens
exactly that point. History follows stable object identity through definition
changes; it never resolves a replacement by name. Each returned source includes
its original schema and retirement flag, so a computation can enforce its
schema and lifetime contract.

`history` requires a live history lease, a starting physical position, a fixed
exclusive upper bound and a budget of 1–8 frames. It returns ordered logical
acceptances with their original receipts, stored interpretations, row counts,
logical-change frontiers and points. Accepted no-ops remain entries. Physical
flushes, pin transitions and operation admission may produce empty pages that
advance `next`; callers continue until `next == through`. Later writes cannot
expand that interval. `pin_status` supplies an observed upper bound independently
of the computation's saved progress. `history_scan` returns up to eight rows
under a historical point, using the ordinary byte budget and row format. Its
cursor commitment covers the complete point, so cursors cannot cross revisions.
Every history read checks current authority and the live lease, including an
empty result. Releasing the lease closes all its historical reads.
An explicit missing/trimmed required WAL interval returns HTTP 409 with
`HistoryReclaimed`; it never substitutes the current head or an empty page.
An I/O or storage-availability failure remains an unavailable attempt. The
Table owner does not currently perform physical history reclamation.

`check_set` accepts 1–16 tagged `access` or `snapshot` checks. Access checks use
the same exact-definition/action requirements as `check`; snapshot checks verify
the original live pin. The local owner excludes Table mutations during the set
and rechecks the union of successful requirements under one current native
policy revision after response buffering. Native guard capacity still bounds
the union. The `checked` result carries no rows or common source cut.

`namespaces` accepts an optional last-visited schema ID and returns at most eight
authorized live schemas, a continuation and directory position. Empty filtered
pages may continue. The position describes this directory observation and does
not establish a data snapshot.

Pages are transport batches over one source. Their row counts, source identity
and continuation do not by themselves certify a completed query result or a
consistent cut across Tables. A caller must retain the exact source and consume
its pages without silently reopening at a newer frontier.

`DirectTablePrepared` performs read-only SELECT preparation against the complete
current declaration and current read rights. Its fingerprint covers canonical
JSON of `definition`, `connection`, `namespace`, `name`, `interpretation`, prefixed
by `transit.table.direct.preparation.v1` and a zero byte. Data progress is absent
from that metadata identity. `DirectTableQuery.openPreparedRetained` separately
binds parameters to the retained source fingerprint after exact interpretation
and current-definition checks. It acquires or releases no pin. The caller keeps
the original acquisition request and handle through uncertain I/O, and must not
replace them implicitly on a failed query open.

Binary fields contain canonical padded RFC 4648 base64. Invalid alphabet,
padding or nonzero unused pad bits reject. Schemas and rows retain their Fuze
binary codecs; transport does not reinterpret them as JSON numbers or text.
The request limit is 8 MiB and the buffered response limit is 16 MiB. Direct
requests limit a page to eight rows and at most 8 MiB of encoded row bytes,
within the storage owner's separate 16 MiB bound. Individual binary fields
remain within 4 MiB. These bound one
request's work; durable Table/catalog cardinality has no corresponding limit.

`just contract::direct-table-check` verifies reflected envelopes and independent
Python signing vectors. The catalog package tests consume those same vectors;
the [proof ledger](../tests/README.md) distinguishes codec and node composition
checks from installed service qualification.
