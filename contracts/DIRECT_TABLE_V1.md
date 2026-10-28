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

### Durable client-token bindings

`client_token` supports `lookup` and `bind` through the signed direct route.
`DirectClientToken.Key` requires the current `definition`, exact `connection`, a
nonzero 32-byte `account` label and a 16-byte `token`. The identity is scoped by
catalog and authenticated principal, then account and token. Account is a
caller-managed deduplication namespace, not an authentication or permission
authority. Distinct native principals cannot read one another's bindings.
Changing the selected role, branch or audience cannot create a second binding
under the same key; an incompatible connection conflicts.

`bind` carries that key, a nonzero 32-byte request `fingerprint`, and one complete
`DirectIntent.Reference`. The caller commits to its entire original request,
including parameters and database selection. The database does not interpret or
certify that fingerprint's SQL meaning. It verifies the saved intent's immutable
bytes, checks current original-operation rights and claims that operation
identity before accepting the token in the catalog WAL. Token payloads support
Table DDL/DML, namespace changes, conditional name assertions, transaction begin
descriptors and external-owner records.

The first accepted binding wins. A concurrent or repeated bind with the same key
and fingerprint returns the original receipt, even if the proposal has a
different operation ID or snapshot basis. Dispatch only the returned reference.
A different fingerprint conflicts. The response is an optional receipt containing
the original binding, catalog `position` and mandatory nullable `coordination`;
successful `bind` always returns a
receipt. `lookup` returns null for absence and never admits or executes data.
Lookup requires current CONNECT; existing-reference disclosure also requires
current rights for the original Table operation, including on exact retries and
after response buffering.

Token acceptance is separate from data admission, execution and completion. Its
position is a catalog WAL position, not the Table commit position. Save the key
and fingerprint before attempting a bind. After a lost reply, explicitly look up
the key or repeat the binding attempt. Absence cannot rule out an in-flight
acceptance. Never dispatch a losing proposal, substitute a fresh token to resolve
uncertainty, or infer data success from a token receipt. Resume `admit_saved` and
`operation` using the recovered intent; their outcome and current authorization
remain authoritative.

The paged directory stores one immutable receipt per token. There is no expiry,
deletion or replacement operation. `DirectCatalog.Options.client_token_quota`
and the local node's `table.client_token_quota` limit accepted bindings per
catalog, defaulting to 1,000,000; zero is invalid. Exhaustion refuses new bindings
without deleting history. Existing lookups and retries remain available under
current rights. The quota is independent of resident pages and can be raised by
explicit deployment configuration. HTTP maps a fingerprint conflict to `Conflict`
and quota refusal to `StorageQuota`. Storage failure can leave acceptance unknown.

Catalog roots require the token directory and count fields. Earlier definitions
reject under the shared-v1 cutover without a default, converter or data reset.
SQL database sessions use these same public operations. The intent is a tagged
`DirectIntent.Reference`: Table, conditional name, namespace change, transaction or external
owner. External records fix their connection, namespace, operation and immutable
`DirectRecord` content; the external owner establishes its domain outcome.

A transaction reference fixes the connection, selected namespace and
`Transaction.Begin` descriptor. Initial acceptance checks the exact Catalog
observation, the complete paged selection of read-only Table descriptors and
configured limits. Admission accepts `explicit_tables`; it rejects the neutral
`authorized_catalog_tables` variant until server-owned catalog discovery supplies
that selection. Caller-supplied membership cannot certify complete authorized
catalog coverage. It atomically reserves the next unused partition with the
token receipt. `coordination` contains that partition only for a transaction;
other receipts require explicit null. A repeated token returns its original
partition. A begin operation cannot reserve another partition through a different
account or token. Table allocation shares the same monotonic partition frontier.
CONNECT authorizes saving and recovering this caller-supplied descriptor. The
descriptor grants no Table access and establishes no acquired cut, retained pin,
workspace or decision. Selection descriptors do not make nonexistent Tables
readable. Execution must independently acquire and authorize its complete cut.

`DirectCatalog.Options.transaction_limits` caps each requested limit: defaults
are 16 MiB resident work, 1 GiB workspace, 100,000 participants, 100,000 statements
and 1,024 savepoints. These admission ceilings do not preallocate those resources;
the operation's token budget separately charges account capacity. A capacity or
stale-Catalog refusal does not allocate a partition or accept a token. Generic
intent execution rejects transaction references with `TransactionOperationRequired`.
Generic progress updates reject transaction entries with
`TransactionOperationRequired`, including changes to the record, cancellation,
pending flag and exact repeats. Transaction-owned operations must preserve their
workspace and original decision; generic client bookkeeping cannot replace them.
The admission interface alone does not provide interactive SQL transactions.

The catalog component's common-cut acquisition publishes a `DirectRecord` with
format `0x54584331`. Its canonical JSON contains mandatory `definition`, `cut`
and `coordination`; its encoded size is at most 16 KiB. The neutral cut binds the
original begin, an immutable `sources` directory and its catalog acceptance
position. The coordination partition must match the original token receipt;
the cut position must equal the progress revision and follow begin admission in
that same catalog partition. No signed acquisition operation is exposed by this
record format. The embedding host must hold the catalog/Table publication fence,
and the owner checks current Table rights under the publication policy epoch.
This format is reserved: generic `record.stage` and `record.read` reject it with
`TransactionOperationRequired`. CONNECT-only caller-record access cannot disclose
server-owned cut evidence after a participant's read rights have been revoked.
HTTP maps `TransactionOperationRequired` to `400 InvalidRequest`.

Catalog recovery requires the explicit `coordination` field and validates its
allocation transition. Earlier receipts reject under the current-v1 definition;
there is no inferred partition or default. Retained Catalog history roots the
accepted selection's index pages, including those exceeding the resident cache.

`client_progress.inspect` selects a token; `operation` selects its immutable
Catalog acceptance ID within an exact account/connection scope. `list` returns
at most eight entries and an optional increasing numeric cursor, selecting all
or pending entries. The original receipt never changes. Each `Progress` has an
independent Catalog `revision`, `pending`, sticky `cancel` and optional immutable
record reference. `update` compares the expected revision. An exact repeated
update returns its existing state, including after a lost reply. A stale changed
update conflicts; settled work cannot become pending and cancellation cannot be
cleared. Table, name and namespace settlement requires an actual terminal owner
observation. External bookkeeping is not evidence of external completion.

`Binding.budget` declares account limits for operations, retained recovery bytes
and pending operations, plus this operation's byte reservation. Defaults are
1,000,000 operations, 4 GiB, 1024 pending and 4608 reserved bytes. Limits are fixed
by the first accepted account binding. The account directory aggregates across
roles in the primary token identity domain. Acceptance checks and charges it
atomically with the token; settlement releases only pending capacity. Catalog-wide
quota and data-owner limits remain separate. A changed budget profile conflicts;
no implicit quota increase, expiry or data reset occurs.

`record.stage` publishes a complete immutable opaque body, up to 4 MiB, under a
current-definition connection/account scope and nonzero format tag. Its reference
binds exact byte length and SHA-256. `record.read` verifies both. Current CONNECT
is required for staging and reading; these records never grant data or execution
rights. Accepted references and subsequent progress records retain complete
original work; a body alone does not establish token acceptance.

An optional signed request `lease` contains a token key and exact recovery
revision. Its scope/principal/audience must match the request. The local host
holds shared Catalog access through execution/disclosure; updates take exclusive
access. A missing or replaced lease record conflicts before the action executes.
The lease is a fence, not authorization. Current policy checks remain mandatory.

`commit_saved` accepts a complete staged Table DML reference and returns its
original row-operation state. INSERT/UPDATE/DELETE evaluate their frozen work and
publish state, indexes and outcome in one Table WAL append. There is no
intermediate Table admission record. Repeating the exact request returns the
original outcome; changed work conflicts. Token acceptance and recovery-index
settlement remain separate Catalog transitions. DDL is excluded from this action.

Catalog roots require all token, operation, pending and account directories and
counters. The shared definition rejects superseded layouts before execution;
there is no default compatibility field or fallback decoder.

### Named native resources

`resource_preview`, `resource_operation`, `resource_lookup` and `resource_list`
share the direct catalog's object IDs, names, namespace ownership and operation
identity space. `DirectResourceClient` exposes these typed operations. They do
not add executable `CREATE KV` or `CREATE DOCUMENT` SQL syntax.

`DirectResource.Binding` contains the mandatory shared definition, complete
connection, operation, target object, nullable expected interpretation and
CREATE, RENAME or DROP action. CREATE has no expectation. RENAME/DROP bind an
exact definition revision and digest. CREATE freezes namespace/name, owner role,
an existing writer PID, explicit lifetime ownership, nullable deadline/history
policies and a kind-specific specification. KV specifies a scalar logical type,
nullability, native byte keys and FVL1 values. Document specifies its identity,
type revision and publication limits. Null retention settings remain unlimited.
The service does not choose application behavior, grant data access or create a
writer process.

Preview is read-only. Admission reserves the shared name and permanently claims
the object identity without exposing a live definition. An operation records its
original binding, catalog WAL position, phase, reason, nullable native allocation,
nullable resulting definition and logical retirement. The phases are `admitted`,
`prepared`, `allocated`, `complete`, `rejected` and `cancelled`.

CREATE execution first registers the metadata permission object using the existing
catalog registrar. It then persists the original caller's next native sequence as
`prepared`, before any allocation dispatch. One prepared allocation per principal
can occupy this catalog's durable reservation index. A second preparation returns
Conflict until the first is reconciled or cancelled. This index does not reserve
the principal against independent native commands or another catalog authority.
A native sequence conflict must be reconciled; it never authorizes silently
choosing a replacement sequence.

The caller signs the exact frozen native `create_resource` request. The typed
client reads the prepared record before signing; an execution attempt uses at
most two catalog exchanges. The service checks current catalog CREATE/owner
eligibility and native ADMIN on the writer before submission. Registrar keys
never sign this allocation on the caller's behalf. Accepted native allocation
and its original receipt can outlive a denied or lost response. Attachment checks
the actual receipt, resource properties and current native INSPECT permission,
then records `allocated` and releases the sequence reservation. A submitted ID
is never allocation evidence.

Initialization belongs to `transit-station-app.NamedResource`, using the existing
native resource writer and private Station turns. KV initialization reserves and
completes its marker atomically. Document initialization reserves the exact initial
interpretation, runs `Document.Service.create`, verifies the empty accepted head,
then completes its marker in a later turn. Application associations, worker
ownership and current native data grants must already authorize those turns.
Neither a populated KV nor an existing anonymous Document is adopted implicitly.

Catalog completion verifies the actual current native resource lifetime and the
exact [initialization marker](DATA_LIFECYCLE_V1.md#native-resource-initialization)
under the same native fence as publication. Only then does lookup/list disclose
the named definition. This verifies accepted writer evidence, not honest
application computation. A completed catalog receipt describes that publication;
it is not a continuing guarantee that the resource remains available. Current
data reads independently check grants, retirement and expiry.

A definition's digest is SHA-256 of `transit.catalog.native-resource.v1`, one zero
byte and canonical public JSON of `DirectResource.Definition` in declared field
order. It includes the allocated resource, original caller/sequence, metadata
authority, immutable creation specification, name and revision. RENAME changes
the name/revision while retaining the initial marker identity. Logical DROP
retires the catalog binding and does not retire native data. Namespace DROP also
restricts pending or live named resources. Object IDs and original terminal
receipts never rebind when a name is reused.

Cancellation reconciles an already accepted allocation before recording its
resource ID for separate physical cleanup. It neither deletes data nor cancels
an independently submitted native request. Inspect/cancel use reserved control
admission. A failed execution attempt leaves its last accepted phase available;
transport failure is not rejection, cancellation or rollback. Missing initialization
returns the retained `allocated` state. Other current-authority, identity,
lifetime or storage failures remain explicit errors.

Listings scan at most eight directory entries per call and filter current
metadata rights. Empty filtered pages may carry a continuation. Each result has
its exact interpretation and publication position; the page has a catalog
observation position. A listing does not establish a multi-resource data cut or
permission to read values. Shared metadata permission registration reuses the
catalog's Table domain; native resource grants remain the data authority.

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

### Explicit definition dependencies

`dependency_operation` accepts a `DirectDependency.Binding` and `inspect`,
`accept` or `cancel`. The binding has mandatory current `definition`, exact
`connection`, unsigned 64-bit `operation`, `edge`, `action` (`register` or
`remove`) and `authority` (`dependent` or `catalog_administrator`). Its identity
shares the catalog/principal/operation claim with DDL, DML, namespace changes
and conditional name assertions. A reused identity must match the entire saved
binding, including authority. Transport credential replacement does not change it.

An edge binds a source Table or named KV/Document's exact `DataLifecycle.Definition`, a dependent's
kind (`kv`, `document`, `captured`, `maintained`) and exact definition, and a
nonzero mask of required logical actions. Table sources accept Table action masks;
named KV/Document sources accept SELECT only, mapped to native INSPECT and READ.
These actions describe required access and never grant it. Both objects use branch
one and the same realm. Named resource dependents belong to this catalog; captured
and maintained dependents use their separate owning native metadata resource.
Registration verifies a named resource dependent's actual kind and exact allocated
or published definition. It does not certify initialization, activation or current
data availability. A computation registration remains an explicit owner assertion;
the query publication adapter must establish its definition separately.
Registration protects a source from DROP. It does not retain a data
snapshot or change history. The dependent owner must register before publication
and remove after retirement or recovery of an abandoned publication. These steps
across owners are not atomic. Automatic registration by named resource and query
publication is not part of this operation.

Registration requires current database CONNECT and the dependent's metadata
authority: named resources require schema USAGE and object ownership; captured
and maintained definitions require native metadata WRITE. It never requires
native WRITE on the shared catalog backing resource. Source authority is schema
USAGE plus every declared Table action, or schema USAGE, metadata visibility and
the named resource's native INSPECT/READ. It requires an exact published source
definition and an exact allocated/published named dependent. Changed or retired
definitions and incorrect dependent kinds produce
`rejected/stale_definition`, and a pending source DDL operation produces
`rejected/source_busy`. Ordinary row mutations do not block registration.
Dependent mode removal and cancellation need CONNECT and the same metadata
mutation authority; inspection needs CONNECT and metadata inspect. They need no current source data
grant. Normal graph inspection requires source metadata visibility and dependent
metadata inspect, independently of data-read permission. All successful
requirements are rechecked after buffering before response disclosure.

Explicit administrator graph inspection requires native realm ADMIN and source
metadata visibility, and can expose retained registrations without dependent
resource rights. Administrator removal additionally requires current ownership
of the source object's metadata. It only removes the specified edge; it does not retire the
consumer, cancel work, delete data or release pins. Administrator registration
rejects. Native metadata rights may survive logical resource retirement; neither
those rights nor a dependency receipt establish that resource's usability.

Acceptance atomically publishes both graph directions and a terminal receipt in
one catalog WAL record. The response is `not_observed` or an `outcome` containing
the exact binding, catalog position, phase (`applied`, `rejected`, `cancelled`),
reason (`none`, `stale_definition`, `source_busy`) and `changed`. A no-op register
or removal is `applied` with `changed=false`. Cancellation of an unknown binding
records an exact tombstone. Cancellation or acceptance after a terminal receipt
returns that original receipt. In particular, retrying an old registration after
its removal does not restore the edge. A lost reply requires inspection of the
same binding; it does not establish rejection.

Table and named-resource DROP preview, admission and execution check explicitly registered edges
and report a generic dependency blocker without revealing its metadata. There
is no CASCADE or implicit expiry. ALTER and RENAME preserve exact registered
definitions and may leave a consumer stale; they do not rewrite it. Namespace
DROP checks live/pending Table and named-resource membership. Neither registry discovers
unregistered consumers or dependencies embedded in arbitrary payloads.

`dependencies` selects `dependents` of a source object or `dependencies` of a
dependent object, with an explicit authority and nullable cursor. Each call scans
at most four edges; denied edges are omitted while scan progress advances.
An empty page with `next` is incomplete. The cursor binds selection, authority,
catalog position and the last scanned edge digest. A changed catalog position
returns HTTP 409 (`CatalogObservationChanged`), requiring a fresh traversal;
pages from different observations cannot be joined into one complete graph.
Durable graph cardinality is independent of resident cache and page size.

`dependency_state` accepts one exact edge and returns that edge, the current
catalog position and a `present` boolean. It reads both indices under current
source and dependent metadata authority, rechecked before disclosure. It neither
registers an edge nor starts work. A missing edge is distinct from an immutable
successful registration receipt whose edge was subsequently removed. This bounded
point observation does not certify data availability or a cross-catalog snapshot.

The edge key digest is SHA-256 over `transit.catalog.dependency.v1` and a zero
byte, followed by 169 bytes: source definition, one-byte dependent kind (KV=1,
Document=2, captured=3, maintained=4), dependent definition, and a big-endian
unsigned 64-bit privilege mask. Each 80-byte definition contains big-endian
unsigned 64-bit realm/resource/catalog/branch/object/revision, then its 32-byte
digest. Forward keys prefix the digest with the source's big-endian object ID.
Reverse keys prefix it with SHA-256 over `transit.catalog.dependent.v1`, a zero
byte and the dependent's five big-endian object fields. Full edge records must
match when a key already exists. Persisted catalog roots require both graph
indices; old stored definitions reject rather than defaulting them to empty.

### Physical storage observations and fixed flush targets

`storage {object, pending_limit}` observes one Table under current database
CONNECT, schema USAGE and Table metadata-inspection authority. `pending_limit`
is 1–1,024. Its result identifies the current immutable interpretation,
exclusive acceptance position, logical-change frontier, live row count, bounded
pending WAL row count/encoded bytes/earliest position, archive frontier,
recovery-checkpoint frontier and logical history floor. Pending counts carry a
mandatory completeness flag; incomplete values are lower bounds. Row bytes are
neither filesystem usage nor retained historical bytes. Inspection stages no
objects, acquires no pin and starts no maintenance.

The result also carries the exclusive `next_segment` identity and mandatory
`maintenance` progress from that accepted Table root. `archive_source_lsn` and
`compaction_source_lsn` identify the source activity eligible for physical work;
`archived_source_lsn` and `compacted_source_lsn` identify completed activity.
Nullable `archive_target` and `compaction_target` preserve fixed in-progress
cuts, with their source position and respectively the exclusive WAL position or
segment identity. A compaction target's mandatory `after_segment` records inputs
deliberately retained by the selective pass; completion can leave dense or
oversized inputs unchanged. An archive target additionally identifies the checkpoint
position it requires once its archive is published. These fields follow the
[accepted maintenance invariants](TRANSIT_STORAGE_V1.md) and are validated by the
shared client. Equality of source and completed activity with a null target
means no outstanding work in that class at this observation. It does not prove
that archived WAL cleanup or object collection has completed, authorize history
expiry, or promise when the next unit will run. These observations expose no
filesystem path, object bytes or other Table's progress.

`flush {object, through}` requires the Table's existing ALTER/ownership authority
and executes at most one physical unit of 32 current WAL rows within the owner's
allocation and request deadline. `through` is an explicit
exclusive acceptance position in that Table's partition. Save the complete
target before dispatch. Its result repeats that exact target, supplies a fresh
storage observation and reports complete only when no current WAL row locator
is below the target. Later writes do not extend it; overwritten or deleted rows
cease to be current obligations. Old snapshots retain independent dependencies.
The target cannot name another partition or a future frontier. Retired Tables
refuse flush work.

This operation publishes physical coverage through the existing Table WAL; it
creates no logical mutation, request queue or separate operation receipt.
Automatic maintenance can satisfy the same target. After timeout, lost reply,
revocation at disclosure or restart, inspect current storage or repeat the
original target under current rights. Do not choose a new frontier to recover
the earlier attempt. One response may remain incomplete. A caller that wants
all units explicitly executed repeats that fixed target until completion.

These are signed direct actions with ordinary admission. Read delegations,
borrowed-read grants and reserved-control hints authorize neither operation.
The service rechecks current authority after buffering responses, including
empty storage observations and already-completed flush targets. Board may use
inspection through its read client; it receives no flush authority.

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
Consumers needing retained traversal must explicitly acquire a durable pin.
Retained-read delegations and borrowed-read grants do not authorize `observe`.

`read_current` supplies an optimistic point lookup or ordered suffix without a
retention owner. Its mandatory fields are `namespace`, exact `interpretation`,
original `expected` Table position and `selection`: a canonical encoded `key`,
or `rows` with a nullable stable row identity `after` and explicit limits. The
expected position must be nonzero. Suffix budgets are 1–8 rows and 1–8 MiB of
encoded rows. An absent cursor starts at the beginning; a supplied cursor must
identify a currently live row, and the result starts strictly after it.

Every read requires the same current CONNECT/USAGE/SELECT checks as `observe`.
The original position must belong to the current partition, be no later than
its accepted frontier, and be at or after its latest logical-change frontier.
Thus no-op acceptance, pins and physical flushes may advance the current root;
an intervening row change rejects with `TableDataChanged`, even if later writes
restore the same values. Definition changes and retirement reject with
`TableDefinitionChanged`. A request cannot substitute a newer expectation and
claim that it continues the original read.

The result includes the current definition/schema, position, logical-change
frontier, total row count and native read-authority references. A key selection
returns one encoded row or null; it proves only that key's presence or absence.
A row selection returns encoded rows, byte count and a nullable next row
identity. A continuation equals the last returned row and requires another
request with the original interpretation and expectation. An empty terminal
suffix proves exhaustion after its seek key, not prior coverage. A consumer
claiming complete traversal must start at null, consume strictly ordered pages,
retain the original row count and reject the whole traversal if any page fails
or the final consumed count differs. Transport EOF is not exhaustion.

The owner serializes each call with Table changes and checks current authority
after buffering, including absence and empty suffixes. The client checks exact
definition and logical-basis attribution, schema, key equality, ordered row
identities, continuation and budgets. These reads create no log record, pin or
publication; the descriptor preserves no data after a change. Retained-read,
closure and borrowed-read grants do not authorize `read_current`.

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

Snapshot delegation permits `pin`, `pin_status`, `snapshot`, `scan`, `read_key`, `key_range`,
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
serialization. A snapshot target permits only `snapshot`, `scan`, `read_key` and `key_range`
for that exact handle. A historical target permits only `history_source` and
`history_scan` for that exact lease, position and record commitment. Acquisition,
release, history traversal, discovery and mutation reject. Borrow and closure
cannot be combined. Releasing the coordinator's lease ends borrowed access;
borrowed reads neither retain it independently nor reopen it. The purpose binds
application-owned work, not verified computation.

## Declaration and row operations

`preview_rows` and `preview_statement` check a frozen mutation against the
original caller's current mutation and inspection rights, acceptance
prerequisites, exact definition, optional data frontier and pending DDL. They
return the original binding, independently observed directory/Table positions,
current stored interpretation, row count and `none`, `stale_definition`,
`stale_data` or `object_conflict`. They do not select matching rows or predict
matched/changed counts, duplicate-key success or a later commit. They stage no
payload, claim no identity and append no acceptance record. Existing identity
claims must match. Preview is current validation, not past receipt recovery.

`name_preview` checks the same original rights and condition as conditional
acceptance. It returns the original binding, catalog position, current matching
Table definition when present, and a `matches` boolean. An unavailable name
reservation or a different object kind also prevents an absent-name match.
Preview records no conditional outcome and cannot reserve the observed name.

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

`DirectTablePreparedDdl` shares CREATE, ALTER, RENAME and DROP preparation
between typed callers and SQL. Binding checks current action rights and the
original exact definition, then produces independent `DirectTableIntent` bytes
or a conditional name assertion. CREATE takes separate explicit operation and
new-object identities. A prepared template can be released after binding; the
saved work owns its schema/default bytes. Loading that work neither resolves a
name again nor admits it. Conditional no-ops retain the complete proposed SQL
text and dialect commitment, including clauses that are not installed.

`DirectTablePreparedDml` prepares INSERT, UPDATE and DELETE through Fuze's shared
typed template compiler. It checks the exact definition and requested mutation
right before and after compilation. Binding rechecks that identity, validates
typed parameters and returns independent `DirectTableIntent` bytes without
admission. Numbered Transit/PostgreSQL parameters and MySQL positional parameters
use the existing dialect rules. INSERT derives row identities from the new
operation; UPDATE/DELETE freeze the observed logical basis through its accepted
frontier. Parameter binding never becomes a recovery operation.

`DirectTableValues.Reference` and `PreparedBinding` are lossless host
representations of those direct caller identities. The reflected `HostReference`
and `HostPreparedBinding` schemas require their compatibility definition. Catalog,
branch, object, operation, definition revision, partition, LSN and content-byte
values use canonical unsigned decimal strings; native authorization identities
remain bounded JSON integers. Digests use 64 lowercase hexadecimal characters.
Conversion checks the original owning types and rejects changed interpretation
commitments. It does not resolve names, acquire rights or admit work. These value
contracts do not themselves expose a catalog ABI or migrate a language SDK.

`DirectTableBridge.Session` owns one loaded intent for serialized host calls.
Its `administration` actions compile namespace SQL into a complete saved
`NamespaceBinding`, preview that binding and explicitly inspect/admit/execute/
cancel it through `DirectNamespace`. The binding requires the current definition,
exact connection, full-width operation string, namespace identity, complete
expected namespace record and typed action. CREATE requires a new namespace ID;
RENAME/DROP require null for that compilation argument and freeze the resolved
original definition. Results retain original bindings, catalog positions,
admitted/applied/rejected/cancelled phases, reasons and resulting definitions.
These actions do not replace the handle's loaded Table work.

`compile_policy` resolves supported policy SQL through `DirectAuthorizationSql`.
Its plan binds the connection, originally selected role, current policy revision
and native action. `prepare_policy` checks that binding and calls the existing
native `AuthorizationChange.prepare`, returning its preview and exact signed
record without submission. Save that record and use the native authorization
change lifecycle for explicit submission, recovery and publication. The original
selected role and current selection eligibility remain authoritative. SET ROLE
compiles to a connection-selection plan; `prepare_policy` rejects it. Selecting
a new connection role is separate from publishing policy or namespace work.

The host `catalog` action dispatches `capabilities`, `describe`, `namespace`,
`namespaces` and `tables` to `DirectCatalogInspection`. Capabilities are local;
the other actions make one public catalog request each. Directory pages contain
eight optional slots and an optional continuation, including empty filtered pages
with continuation. Each cursor requires the current definition, exact connection,
selection, directory position and canonical decimal-string last-scanned ID.
A different selection/connection rejects before remote access; a changed returned
directory position rejects before disclosure. Table entries retain independent
interpretation/position pairs, not a common retained data cut. No inspection
provisions resources, admits work, changes policy or replaces the loaded intent.

Its reflected `HostAction`, `HostResult` and `HostSaved` schemas define lookup,
SQL compilation, loading, forgetting, staging, admission and operation control.
Compilation uses the shared DDL/DML preparation owners, explicit operation and
CREATE object identities, the selected dialect and point/bulk ingestion. This
compile action takes no SQL parameter values. A saved Table value carries the
current definition, namespace and lowercase hex of the complete `TDI1` bytes;
a conditional name assertion carries its complete binding.

The host `dependencies` action uses `DirectCatalogDependencies` for explicit
register/remove/inspect/cancel, exact current membership and bounded forward or
reverse pages. Every operation carries the complete definition-bound connection,
operation identity, source/dependent interpretations, privileges and cleanup
authority. Save that binding before dispatch. An old registration receipt does
not establish current membership after removal; use `state` for that observation.
Pages contain four optional edges. Continuations preserve the exact connection,
selection, authority, catalog position and edge digest. Changed selections reject
before signing; a changed catalog position rejects through the native owner.
All storage identities and positions use canonical decimal strings. The adapter
makes one public request per action and never publishes or retires a dependent,
acquires a data pin, replaces loaded work or retries an uncertain mutation.

The host `resources` action uses `DirectCatalogResources` for named KV/Document
preview, explicit operation control, lookup and eight-entry directory pages.
Save its complete definition-bound `Binding` before admission. Names use text;
storage IDs, revisions, Document identities and full-width staging byte budgets
use canonical decimal strings. Native authorization/resource IDs and allocation
sequences retain the native bounded integer representation. Returned operations
preserve the native phases, original allocation and resulting definition.
CREATE execution reuses `DirectResourceClient`: it may inspect the persisted
allocation before signing and executing that exact sequence, for at most two
catalog exchanges. It performs no automatic Station initialization or polling.
Resource cursors bind the connection, namespace selection and catalog position;
they cannot be substituted for Table-directory cursors. These actions leave the
session's loaded Table work unchanged. A lost response or output-allocation
failure requires recovery with the same saved binding.

The `prepare` action accepts `DirectTableTyped.Request`: a mandatory current
definition, namespace, operation identity, name and typed CREATE, ALTER, RENAME,
DROP or mutation. Existing objects require the complete `PreparedBinding`;
current lookup and action authorization must still agree with it. Missing
DROP IF EXISTS uses an explicit null basis and requires the name to remain
absent. CREATE carries the shared neutral schema, including its new object ID;
ALTER carries shared column identities, codecs, collations and logical defaults.
Typed conditional no-ops commit to the complete proposed typed request.

Typed INSERT accepts at most 1024 rows within the shared 4 MiB encoded mutation
budget and derives row identities from the explicit operation. Point/bulk
ingestion uses the same direct row owner as SQL. UPDATE/DELETE lower the shared
typed predicate/assignment plan and freeze the observed data frontier. These
requests never become actor mailbox frames. Host parsing has its own bounded
envelope; logical cell and storage admission limits still apply independently.
Preparation returns independently owned saved work and admits nothing.

The host `preview` action dispatches the loaded frozen work to its owning DDL,
row or conditional-name preview. Its discriminated result retains these distinct
observation bases and reasons; all full-width counters use decimal strings.

Loading performs no I/O and does not replace an existing loaded intent until
validation and output allocation succeed. Staging a Table returns its exact
direct reference; staging a conditional assertion only returns its binding.
Admission is separate. Inspection, bounded execution and cancellation accept the
complete recovery reference independently of the ephemeral session handle.
Conditional assertions have no execution phase: their execute request rejects.
Results retain the owning DDL/row/assertion state and reason; committed Table
outcomes include the exact resulting interpretation, position and decimal counts.
Transport or output-allocation failure can follow acceptance. Persist the saved
work and reference before dispatch; this bridge never recompiles or retries work
implicitly. Forgetting and session destruction release only local memory.
An optional `DirectTableClient.Attempt` records entry to a validated mutation's
transport after credential inspection and signing. It retains that evidence
across nested reads. Its failed-attempt projection is
`catalog.direct_outcome_unknown`, with the original operation identity when one
exists; service denial or conflict does not prove that the owner rejected the
operation before acceptance. A caller must reset the record for each invocation
and separately handle read/preparation failures when no mutation was attempted.
This shared caller implementation is not yet connected to the general catalog
ABI or language SDK entry points.

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
resolves the name again. Predicate text comparison uses the exact schema's
`none`, `utf8_binary`, `ascii_ci` or `ebcdic_cp037` collation. ICU rejects, and
CP037 literals outside U+0000–U+00FF reject before admission. The physical codec
does not select the comparison semantics.

The Table owner checks the action privilege, selects rows privately and publishes
the complete result once. Selection does not disclose rows or require SELECT.
A later logical change rejects the frozen basis. UPDATE stages replacement
segments in groups of at most 1024 rows and 4 MiB of encoded row work. DELETE
changes the row indexes. Limits cover total decoded visits and bytes across
passes, separately from index staging and deployment storage quotas. Exhaustion
or a destination collision records terminal rejection without publishing any
changed rows. Current authorization is checked again at the final commit.

`operation` carries the original binding and `inspect`, `execute` or `cancel`.
Inspection starts no work. INSERT/UPDATE/DELETE outcome inspection requires
current CONNECT, USAGE and the original action privilege. Disclosing that
mutation's terminal counts does not additionally require SELECT; row reads
retain their separate SELECT check. Execution resumes only admitted frozen work; CREATE
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

`column_scan` accepts `snapshot`, `columns`, nullable `after` and `limits` and
returns the same `page` envelope as `scan`. `columns` is a JSON array of 1–128
unsigned integer ordinals, each in 0–127, strictly increasing without duplicates.
They select columns by position in the retained schema and must include every
primary-key column. Ordinals outside that schema reject. This read representation
preserves each selected column's original ID, name, logical type, physical codec,
collation and constraints, plus the original object, revision, next-column floor
and primary-key declaration. FTR1 rows carry that projected layout fingerprint.
The response's interpretation, accepted/logical-change frontiers and `total_rows`
still describe the complete retained source. Every source row is visited in
identity order; projection does not filter rows or change coverage.

A projected cursor retains the canonical last-returned row identity. Its `source`
is a Content descriptor whose `bytes` is the length and `sha256` the SHA-256 of:
`transit.table.projected-cursor.v1` followed by a zero byte, the 32-byte shared
definition, retained pin-content length as little-endian u64, its 32-byte SHA-256,
the selected-column count as u8, then each ordinal as u8. A different column set,
pin or ordinary scan cursor rejects. Page/byte limits, final authorization and
pin checks match `scan`. The operation supports ordinary retained snapshots;
historical-lease scans retain their complete-row representation.

`filter_scan` accepts `snapshot`, a base64 canonical FQP1 `plan`, its 32-byte
logical `fingerprint`, nullable `after` and `limits`. Admission binds the decoded
plan to the complete retained source basis, logical schema and declared
collations, then verifies its fingerprint. This operation examines at most eight
live identity-index entries per call. Encoded segment decisions precede selected
column decoding; WAL rows use the same predicate semantics. Output columns are
the canonical union of the plan's projections, predicate columns and primary key.
The operation does not compute aggregates or apply the plan's overall LIMIT.
Callers enforce the remaining match limit through `limits.rows` and issue no
scan for LIMIT 0.

The `filtered_page` result contains the ordinary `page` metadata plus `examined`,
eight `offsets` and nullable `failure`. `examined` counts successfully consumed
source identities, including misses. Each returned row's offset is one-based
within that examined prefix; offsets increase strictly, do not exceed `examined`
and are zero in unused slots. Empty pages may carry a continuation. Its identity
is the last consumed source identity, which may follow the last returned row.
Its Content descriptor hashes `transit.table.filtered-cursor.v1` followed by a
zero byte, the shared definition bytes, retained pin-content length as
little-endian u64, its SHA-256, and the complete logical plan fingerprint.
The descriptor length is the preimage length. Other plans, pins and cursor kinds
reject.

A semantic `failure` names the next source identity, original column ordinal,
postfix predicate instruction and `type_error` or `conflict` outcome. That identity
is excluded from `examined`; failure cannot coexist with a continuation or imply
completion. The preceding rows remain available so an earlier aggregate error or
LIMIT can settle first. Structural, integrity and authorization failures reject
the call. A terminal page without failure establishes complete coverage only
when cumulative examined entries equal the retained `total_rows`. Current rights
and pin checks apply to selected, empty, failing and terminal pages. Filtered
scans support ordinary retained snapshots, including borrowed reads of that
exact snapshot; they do not authorize a new acquisition or history advancement.

`read_key` accepts one nonempty canonical storage key (base64, at most the
physical collation key bound). Its `point` result carries the same snapshot,
interpretation, accepted frontier, logical-change frontier and total row count,
plus one optional FTR1 row. The owner uses the retained primary-key index and
checks the decoded row's actual key against the requested bytes, rejecting a
hash collision. Keyless Tables use canonical row identities as storage keys.
The reader verifies attribution and key equality under the retained schema;
a hit or absence does not advance sequential scan coverage. Current rights and
the live pin are required even when no row matches.
`key_range` accepts `snapshot`, `interval`, nullable `after` and `limits`.
`interval.lower` and `interval.upper` are nullable bounds; each present bound
requires a nonempty base64 `key` of at most 4,096 decoded bytes and an `inclusive`
boolean. Keys are complete storage keys under the retained schema, not raw column
values. Reversed or excluded equal bounds return an empty interval. The owner
uses its paged full-key directory and validates decoded row keys before disclosure.

The `key_range` result carries the same source metadata as `point`, up to eight
FTR1 rows in strictly increasing storage-key order, `encoded_bytes` and nullable
`next`. Limits and the 8 MiB wire page maximum match `scan`; a first row exceeding
the budget fails. `total_rows` is the whole-source count, not interval cardinality.
Null `next` establishes interval exhaustion, including a nonempty final page.
Current authorization and pin validity apply to empty and nonempty intervals.

A key cursor contains `source` (exact retained content), `interval` (32-byte
fingerprint) and `after` (base64 complete last-returned key). The fingerprint is
SHA-256 over `transit.table.key-range.v1` followed by a zero byte, mandatory
32-byte shared definition, then lower and upper in that order. Each bound has a
one-byte tag: 0 absent, 1 inclusive or 2 exclusive. A present tag is followed by
a big-endian `u16` length and exact key bytes. Continuation rejects a different
source or interval, a key outside the interval or a key absent from its retained
directory. `DirectTableReader.readRange` owns decoded rows and the cursor, checks
order, bounds, original schema and metadata, and leaves sequential coverage
unchanged. It does not release the pin and rejects historical-lease range reads.

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

The typed change reader's saved JSON position has mandatory `version` (1),
`definition` (the current shared definition), `connection` and `source` fields.
`source` is the exact `Historical` object/point binding above. Missing or foreign
definitions reject; the former native resource/head cursor is not accepted.
The position grants no authority and acquires no retention. Delegated consumers
retain their original grant separately. Reopening uses the same live history
lease and revalidates its exact record under current rights. Each tail supplies
a fixed exclusive upper position independently of the saved checkpoint.

The reader emits a complete transaction boundary for every accepted logical
record, including no-ops, with its original receipt and before/after source
bases. Its physical scan cursor can advance across maintenance independently.
Paired row changes retain stable row identities and their original schema;
canonical equality preserves distinctions such as floating signed zero. Only a
complete snapshot or transaction permits a checkpoint. A partially consumed
transaction replays from its beginning. Local closure/destruction performs no
remote release; the caller explicitly closes its original acquisition when its
durable history requirement ends.

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
the [proof ledger](../docs/history/qualification/README.md) distinguishes codec and node composition
checks from installed service qualification.
