# Direct Table request contract v1

`DirectTableProtocol` defines signed Table, Stream and Queue declaration, Table
row mutation, Stream append/consumer progress, Queue enqueue/claim/settlement,
operation inspection and retained-read requests. The node's internal `LocalTableService`
dispatches these requests through `DirectCatalog`, the partition storage owners and
native authorization. The local node's optional `table` setting serves
`POST /table/v1`; the local launcher configures that owner for its default Tables
and shared SQL runtime. Captured-source and SDK migration remain incomplete. The
[generated schema](direct-table-v1.schema.json) reflects the owning Zig types.

## Requests and authority

The `descriptor` action publishes and inspects versioned views, property-graph
mappings and foreign layouts through `DirectDefinition`. These metadata objects
share stable catalog identities, namespace/name claims and current native Table
permissions. Their original-operation outcomes and dependency replacements commit
atomically in the catalog log. They allocate no data partition. See
[catalog interpretations](CATALOG_DEFINITIONS_V1.md) for the exact publication,
historical selection and execution profiles.

The `branch` action and result use `DirectBranch.Request` and `DirectBranch.Result`
for named immutable single-Table branches. Creation, publication, cancellation,
source reads and paged scans share this endpoint and the typed local owner.
The [installed branch contract](BRANCH_V1.md#installed-immutable-table-branches)
defines original-token recovery, exact source cuts, current authorization,
retention and scope limits. General Table requests still target branch one;
branch scans carry their exact published head explicitly.

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
Table DDL/DML, Stream/Queue declarations, namespace changes, conditional name assertions, transaction begin
descriptors and external-owner records.

The first accepted binding wins. A concurrent or repeated bind with the same key
and fingerprint returns the original receipt, even if the proposal has a
different operation ID or snapshot basis. Dispatch only the returned reference.
A different fingerprint conflicts. The response is an optional receipt containing
the original binding, catalog `position` and mandatory nullable `coordination`;
successful `bind` always returns a
receipt. `lookup` returns null for absence and never admits or executes data.
Lookup requires current CONNECT; existing-reference disclosure also requires
current rights for the original operation, including on exact retries and
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
`DirectIntent.Reference`: Table, log declaration, conditional name, namespace change, transaction or external
owner. External records fix their connection, namespace, operation and immutable
`DirectRecord` content; the external owner establishes its domain outcome.

`DirectIntent.Reference.log` fixes the connection, namespace, Stream/Queue kind,
original `DataLifecycle.Binding` and account-scoped immutable `DirectRecord`.
Its `DirectLogIntent.Saved` body requires the current definition and complete
`DirectLogProtocol.Ddl`, including schema, policy, limits and proposed owner.
The format is `0x4c444c31`; canonical bytes, content digest and every reference
field must agree. The record account must equal the token account. Binding checks
current declaration rights and reserves the original operation in the control
store without admitting the declaration. Recovery loads that same body and uses
`admit_log` and `log_operation`; partial partition initialization resumes through
the declaration owner. Pending removal requires a complete, rejected or cancelled
owner observation. Retrying a token cannot substitute a changed declaration,
account, operation or name. Immutable staging records retain the existing saved
record lifetime and remain outside physical collection authority. The SQL
compiler accepts Stream/Queue declaration and named inspection syntax; workload
verbs have separate, unfinished execution contracts.

A transaction reference fixes the connection, selected namespace,
`Transaction.Begin` descriptor and mandatory `purpose`. Ordinary requests use
`interactive`. Missing purpose fields do not default to that value. Initial
acceptance checks the exact Catalog
observation, the complete paged selection of read-only Table/KV and partitioned
Stream/Queue descriptors and
configured limits. Admission accepts `explicit_objects`; it rejects the neutral
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

The internal exhausted-Queue transfer owner uses `purpose.queue_transfer`, an
immutable `DQP1` plan reference. It admits exactly two Queue participants and one
paired transfer statement. The plan fixes one account/token, the begin,
settlement, source transfer and destination append identities, exact exhausted
tuple and recorded destination. Admission reconstructs and verifies the payload
under current source administration, both participants' read rights and
destination append rights before one
catalog acceptance publishes the token, permanent source binding and pending
recovery index. The account's byte charge covers the plan and payload; ordinary
transaction reservations also apply. The retained storage graph includes those
definitions and payload before source pins or a workspace exist.

If the immutable begin reservation survives a failed catalog append, the
protected owner reuses its exact plan, token and selection even after unrelated
catalog publication. Both admission and replay verify that original reservation;
ordinary transactions still require the current catalog observation. A private
reservation alone is not acceptance or a retention pin. Missing pre-acceptance
artifacts refuse recovery rather than selecting new work under the old identity.

The source key excludes caller/account, policy revision and destination, so a
changed worker cannot create another attempt for the same exhausted item.
Generic token binding, transaction mutations and caller-record access cannot
create or modify this protected purpose. Internal advance uses the existing
workspace to save the exact request before execution and the existing decision
owner for commit/abort and cleanup. Only verified cleanup removes the pending
entry; the source binding survives either outcome. An abort cannot replace a
commit, and an aborted attempt does not authorize automatic fresh identities.
The library requires exclusive host serialization across admission and each
advance. The local node's optional `table.queue_transfers` worker uses these
operations under its separately configured database signer. Recovery scans the
paged pending index and advances one original transaction unit; discovery
retains one finite Queue sweep. A worker cannot adopt another signer's or
account's binding. The public wire surface exposes the existing transaction
inspection; protected transfer mutation remains internal to this owner.

The typed `transaction.begin` control accepts an ordered array of exact
`Transaction.Target` values for `explicit_objects`, bounded by 100,000 and the
requested participant limit. Each target includes the scoped object, kind and
an explicit nullable logical partition ordinal. Duplicate or unordered targets,
mixed kinds for one object and foreign scopes reject. Table and direct KV targets
support private mutations. Stream/Queue targets participate as retained read
dependencies and private log work with explicit partition ordinals, as specified
under [transactional log work](#transactional-stream-and-queue-work).
Document targets reject before token admission. Server-owned
`authorized_catalog_tables` discovery remains restricted to accessible Tables.

`DirectCatalog.Options.transaction_limits` caps each requested limit: defaults
are 16 MiB resident work, 1 GiB workspace, 100,000 participants, 100,000 statements
and 1,024 savepoints. These admission ceilings do not preallocate those resources;
the operation's token budget separately charges account capacity.
`transaction_account_limits` additionally caps aggregate pending transaction
reservations across login roles for a principal/account: count 128, resident
allowances 64 MiB, workspace allowances 4 GiB, participant and statement slots
400,000 each, and savepoint slots 4,096 by default. The account usage record
requires explicit `transactions` counters for all six dimensions. Begin
admission and those reservations share one catalog acceptance; failed admission
consumes neither. Exact token recovery does not repeat the charge or apply new
admission ceilings to old work. Pending transactions retain their reservation;
only transaction-owned settlement/cleanup can release it, never generic
caller progress or quota pressure. Earlier usage records missing counters reject.
A capacity or stale-Catalog refusal does not allocate a partition or accept a token. Generic
intent execution rejects transaction references with `TransactionOperationRequired`.
Generic progress updates reject transaction entries with
`TransactionOperationRequired`, including changes to the record, cancellation,
pending flag and exact repeats. Transaction-owned operations must preserve their
workspace and original decision; generic client bookkeeping cannot replace them.
The SQL session owner composes this admission interface through the durable caller-command boundary below.

The catalog component's common-cut acquisition publishes a `DirectRecord` with
format `0x54584331`. Its canonical JSON contains mandatory `definition`, `cut`
and `coordination`; its encoded size is at most 16 KiB. The neutral cut binds the
original begin, an immutable `sources` directory and its catalog acceptance
position. The coordination partition must match the original token receipt;
the cut position must equal the acquisition progress revision and follow begin
admission in that same catalog partition. Later workspace records preserve this
original acquisition position separately from their current progress revision.
No signed acquisition operation is exposed by this record format. The embedding
host must hold the catalog and all selected data owners' publication fence,
and the owner checks each selected kind's current READ rights under the publication policy epoch.
Each Stream/Queue source retains its original log root through a live
transaction pin. Incomplete acquisition reuses original pins only while their
definitions and logical frontiers remain unchanged; it cannot cross another
transaction's preparation barrier. A published cut retains its original basis
after later writes. Serializable completion revalidates every selected log
frontier; read-only completion can use the old cut. Cleanup releases those pins
through control capacity and preserves the original decision after lost replies.
`DirectCatalog.Options.logs` supplies the same bounded Stream/Queue owner
profiles used for standalone data operations. One temporary owner at a time,
including recovery and its caches, is charged to the transaction's resident limit.
This format is reserved: generic `record.stage` and `record.read` reject it with
`TransactionOperationRequired`. CONNECT-only caller-record access cannot disclose
server-owned cut evidence after a participant's read rights have been revoked.
HTTP maps `TransactionOperationRequired` to `400 InvalidRequest` and
`TransactionAccountCapacity` to `503 StorageQuota`. Transport errors alone do not
settle a previously uncertain token binding; inspect the original token.

Catalog-owned private workspaces use canonical JSON `DirectRecord` formats
`0x54585731` (head), `0x54585431` (private Table/KV state) and `0x54584f31`
(completed statement), each at most 32 KiB. All are reserved from generic record
stage/read. A head requires `definition`, original `acquired` evidence, catalog
`revision`, nullable `tables` and `statements` B-tree roots, `last_statement`,
nullable `pending` request and `charged_bytes`. Its revision equals the current
token progress; acquired evidence still binds the original receipt and cut.
No missing persisted field receives a current-state default.

A request binds `statement`, required workspace `basis` revision, exact Table `binding` and immutable DML `intent`
content. Table bulk INSERT/UPDATE/DELETE and direct KV put/remove batches without
prerequisite authority participate. `transaction.stage_kv` takes the original
typed KV mutation, basis and sequence; it validates the KV definition, value
codec and batch bounds before lowering to the shared immutable private intent.
Table staging cannot target a KV object. Both kinds share statement sequencing,
savepoints, retained pins, preparation barriers and the common decision. Current
KV READ and WRITE are checked separately from Table SELECT/DML privileges,
including before the decision and when returning original statement outcomes.
New admission requires the exact active workspace revision; stale work returns
`TransactionReadChanged` without consuming a sequence. Original pending/completed
requests retain their accepted basis and remain retryable. Statement sequences start at one, increase by one across Tables and are consumed
on admission. One pending request excludes a different statement until its
original evaluation is resolved. A completed record pairs the request with its
transaction-attributed provisional outcome or rejection. Private Table records
use `TableWorkspace.State`; they are not Table WAL acceptances. Directory keys
are nonzero Table IDs or statement sequences as eight big-endian bytes; values
are record length as eight little-endian bytes followed by its SHA-256 digest.

The catalog publishes completed outcome and private root in one token-progress
acceptance. Original operation claims distinguish transaction statements from
ordinary Table operations. Lost replies require original request recovery;
resource/storage failures can leave admitted statements pending. Current SELECT
and original DML permissions gate execution and repeated outcome disclosure.
The embedding host serializes all database publication throughout these component
calls. The signed `transaction` action exposes these controls; SQL session
syntax is a separate integration. The [component guide](../packages/zig/transit-catalog/docs/direct-catalog.md)
defines resident and cumulative staging charges and the remaining host boundaries.

The component coordinator stores reserved canonical `DirectRecord` format
`0x54585031`, at most 32 KiB. Mandatory fields are `definition`, catalog `revision`,
original decision-log `binding`, `abort_requested`, nullable original `workspace`,
nullable `preparations`, `prepared_after`, `preparation_complete`, nullable
`decision`, `cleanup_after` and `cleanup_complete`. Workspace absence permits
abort of incomplete acquisition, never commit. A frozen workspace cannot accept
another statement. Preparation/cleanup cursors refer to stable selected object IDs.
The original commit operation has a permanent transaction-attempt identity claim.
Journal acceptance and catalog progress remain distinct; recovery reads the actual
journal if its decision preceded a lost progress reply. Only complete participant
cleanup makes token progress terminal and releases the account reservation.
These component controls preserve the original operation through commit/abort
races; they do not expose a signed coordinator endpoint by themselves.

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
cleared. Table, log declaration, workload, name and namespace settlement requires
an actual terminal owner observation. External bookkeeping is not evidence of external completion.

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

`DirectWorkloadIntent` uses format `WLI1` (`0x574c4931`) for canonical JSON
containing mandatory current `definition`, `connection`, complete source
declaration/schema, native Stream/Queue mutation with its nullable payload, and
an explicit nullable `projection` (no missing-field default).
The source matches the exact original target; append/enqueue payload bytes,
row attribution, schema and partition routing are validated before staging.
The 4 MiB record ceiling includes base64 and metadata overhead. Restoring rejects
noncanonical bytes and missing/foreign definitions; it never resolves a new name.
When present, `projection` contains an ordered input layout and encoded Fuze
plan. Validation binds it to the exact native operation, source schema (including
collations), stable column IDs and selected metadata fields. The canonical body
owns the plan, aliases and literals independently of compiler buffers. Restoration
decodes the saved plan without reparsing SQL or resolving a current source name.
Malformed layouts, truncated encodings and foreign plan definitions refuse as
invalid requests; source mismatches remain conflicts. Allocation failure is
preserved separately and never establishes invalid caller data.
Current projections support application columns, partition and offset, plus
original lease epoch and attempt for claims. They cannot aggregate or impose a
result limit; native acquisition and coverage retain their own bounds. Predicates
are supported only for Stream consumption; claim filtering must precede lease
acquisition. The native result action returns raw original rows; the SQL service
evaluates the frozen projection through its shared original-result reader.
Its reference binds connection, namespace, canonical workload binding, original
stored declaration and the account-scoped record. The shared helper loads that
body before inspect/execute/cancel and checks the complete reference again.
`DirectIntent.Reference.workload` selects this body under a caller token. Binding
verifies the account and current original-operation rights, then reserves the
same global Stream/Queue operation identity used by native mutation and cancel.
It does not execute the work. Exact token retries return the first accepted
reference before loading a competing proposal; a changed fingerprint conflicts.
Catalog history retains the accepted body and original declaration. Its byte
reservation must cover the body plus 4096 bytes for the bounded reference and
512 bytes of token bookkeeping; `Reference.reservationBytes()` supplies that
minimum. Under-reservation rejects before acceptance. Native payload and retained
result storage remain subject to their separate owner quotas.

Clearing workload `pending` requires the normal host-owned partition reader to
return a matching success or durable closure for the original request. Bounded
recovery and absent receipts leave it pending. Unavailable native owners and
storage/authorization failures cannot supply completion. The service rechecks
current rights after buffering the outcome and at Catalog publication. A sticky
cancellation flag records caller intent only; it neither closes a workload nor
rolls back an accepted mutation. Native cancellation uses the saved request.
An exact repeated settled update returns the retained bookkeeping state without
re-executing the operation. SQL operation recovery and result reopening use this
shared owner. SQL workload text admission remains unavailable.

### Original workload result delivery

The signed read-only `workload_result` action opens and pages the original
accepted append/enqueue, consume or claim. `open` takes the complete workload
intent reference and explicit row/byte/scan budgets. It returns `opened` with
the original native success receipt, frozen source/schema, delivery limits and
initial position. A staged body or absent receipt is not an accepted result;
incomplete native recovery and missing outcomes return pending conflict. Durable
cancellation/refusal has no row result and remains inspectable through the
original native operation. The action never executes or cancels a mutation.

`page` carries that entire result reference and its saved delivery position.
It reopens the same owner receipt and selection before reading. Append/enqueue
rows come from the verified frozen payload and accepted offset range. Stream
pages retain the original cut and authenticated coverage; Queue pages traverse
the original claim and report current lease liveness. Refetch does not renew a
lease, ACK, advance a group or choose another selection. Output binds the original
schema and operation, exact row ordinals/offsets and next position. A complete
empty selection remains empty even after later appends. Source-history or
explicit read-release failures are visible; neither produces empty completion.

A page request also requires an explicit positive `rows` budget no greater
than the frozen delivery limit. Lowering it controls this page alone and cannot
change the original selection, source or retained reference.

One delivery page has at most 128 rows and 1 MiB of encoded row bytes, also within
the frozen source's read limits; Stream scan work is bounded to 65,536 examined
rows. A single row that exceeds the byte budget fails without advancing delivery.
Encoded row bytes exclude base64 and schema overhead. The workload's existing
4 MiB complete-body limit remains separate. Each read requires current
original-operation rights plus READ and rechecks disclosure after buffering,
including empty and repeated responses. Descriptors and cursor possession grant
no permission. The service uses its normal bounded native owners and preserves
verified replay progress when an original-result probe remains pending.

There is no new durable cursor or implicit close mutation. Local page/cursor
cleanup releases delivery buffers; explicit native read release remains a
separate saved operation and can make future delivery unavailable. Stream
`offsetWork` prepares a separate request from an exhausted authenticated read;
`offsetIntervalWork` takes an earlier issued cursor from that read and settles
only the traversed interval through the current cursor. Both preserve the
original group generation. Save that exact handoff before
dispatch; the native owner still authenticates it and checks current assignment
and settlement rights. A requested numeric offset or SQL output count cannot
replace it. SQL result reopening uses this native boundary; workload SQL text
admission and its finite-consumption handoff remain unavailable.

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

### Direct KV

`kv_declaration`, `kv_lookup`, `kv_list` and `kv` share the database connection,
current native policy graph and operation identity space. `DirectKVClient` and
`transit-data-client.Catalog.callKV` expose the same typed operations. These do
not execute SQL `CREATE KV`, nor accept a writer PID or Station state resource.

A mandatory `kind` in the persisted catalog intent distinguishes `table` and
`kv`. KV CREATE lowers its value specification to the exact two-column
`KVDeclaration` physical schema. Its DDL intent digest includes kind, namespace,
name and action in native field order, with fixed name-byte arrays encoded as
strings including zero padding, under `transit.catalog.ddl.intent.v1` and a zero
byte. The signed wire envelope encodes those arrays as JSON numbers. The ordinary catalog admission,
registration, partition publication and reconciliation stages apply. KV ALTER
is refused. Table row/read operations reject a KV interpretation;
similar column names never establish object kind.

`DirectKV.Mutation` contains a data-lifecycle binding and 1–1024 changes. A put
has a base64 byte key, a bound FVL1 value and an `absent`, `present` or `any`
expectation; remove has a byte key. The mutation uses binding action `insert`
and requires the exact expected definition. Its intent digest is SHA-256 of
`transit.kv.mutation.v1`, a zero byte, and canonical public JSON of the change
list. That list must fit 4 MiB. The shared operation binding is claimed only
after key and value decoding; current policy is checked before claim and again
at publication. Key, value and builder limits are defined by `KVPartition`.

One partition commit accepts the complete batch and outcome. `operation` returns
its original evidence, including after rename or retirement. Current inspection
rights still apply. A missing response does not establish rejection; callers
preserve and inspect the identical binding. Saved mutations require a mandatory
current definition, exact connection and digest, with no fallback decoding.

`get` returns interpretation, public source position, last logical-change position,
value specification, optional retained source, mandatory nullable `workspace`
and an optional encoded value.
Absence carries the same basis as presence. NULL remains a logical value.
`pin`, `pin_status` and `release` use the shared retained-snapshot owner identity.
A retained read verifies the exact handle and current rights before disclosure,
even after DROP; it never silently substitutes a new cut. Response validation
checks KV kind, exact schema fingerprint, object/source attribution and receipt
binding before the shared client decodes values into caller-owned output.

Catalog CONNECT/namespace USAGE remain mandatory. `KVAuthority` separates
INSPECT (metadata and receipts), READ (values and retained reads), WRITE (batch
mutations), and ownership (rename/DROP). CREATE requires namespace CREATE and
owner eligibility. Dependency registration uses KV source privileges and
separate dependent metadata authority. Transaction begin accepts explicit Table
and direct KV participants, plus Stream/Queue partitions with retained source
cuts and native private append/offset/ACK work described below.

A KV `get` may carry the envelope's original transaction context with an exact
active revision and no retained `source`. It reads the private workspace and
returns the same `Transaction.ReadView` evidence as Table private reads. Its
public source frontier remains separate from the virtual `private_position`.
The response must match the requested revision and carry a nonnull workspace;
ordinary KV reads require null. Stale revisions, pending work, current READ
denial and attempts to mutate or create/release pins through a read context
reject. Private state never enters the ordinary resident owner cache.

### Named native resources

`resource_preview`, `resource_operation`, `resource_lookup` and `resource_list`
share the direct catalog's object IDs, names, namespace ownership and operation
identity space. `DirectResourceClient` exposes these typed operations. They do
not add executable `CREATE DOCUMENT` SQL syntax; these operations declare
Documents. KV uses dedicated direct partition operations.

`DirectResource.Binding` contains the mandatory shared definition, complete
connection, operation, target object, nullable expected interpretation and
CREATE, RENAME or DROP action. CREATE has no expectation. RENAME/DROP bind an
exact definition revision and digest. CREATE freezes namespace/name, owner role,
an existing writer PID, explicit lifetime ownership, nullable deadline/history
policies and a Document specification containing its identity,
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
native resource writer and private Station turns. Document initialization reserves the exact initial
interpretation, runs `Document.Service.create`, verifies the empty accepted head,
then completes its marker in a later turn. Application associations, worker
ownership and current native data grants must already authorize those turns.
Neither a populated resource nor an existing anonymous Document is adopted implicitly.

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

### Stream and Queue lifecycle

`log_preview` and `log_admit` carry `DirectLogProtocol.Ddl`: a complete
`DataLifecycle.Binding`, `kind` (`stream` or `queue`), namespace, original name
and CREATE, ALTER, RENAME or DROP action. CREATE carries owner role, binary Fuze
schema, `StreamQueueDeclaration.Configuration` and required operation limits.
The schema has stable column/type/codec/collation identities and no Table primary
key. Routing, FIFO and compaction keys must identify nonnull supported key columns.
ALTER carries replacement configuration and limits; RENAME carries the new name.
Non-CREATE bindings require the exact current definition; `expected_data` is null.
The intent digest hashes `transit.catalog.log.intent.v1`, one zero byte, and
canonical `DirectLog.Intent` JSON. Identity claims share the catalog's original
principal/operation namespace with other direct work.

Preview returns the original binding, observation position, nullable current
definition and conflict reason without writing. Admission freezes the full
intent and records `admitted` or `rejected` with its reason. Accepted CREATE
reserves one contiguous physical partition identity range and the live name
privately. The returned `DirectLog.Operation` includes original binding, intent
content, kind, namespace, proposed name, optional CREATE owner, position, phase,
reason, partition range, initialized count and optional resulting definition.
Phases are `admitted`, `initializing`, `complete`, `rejected` and `cancelled`.
Rejections distinguish name conflict, object conflict, stale definition and
dependency. Repeating the original binding returns its original progress or
result; changing any frozen field conflicts.

`log_operation` carries that binding, `inspect`, `execute` or `cancel`, and a
step budget of 1–256. Inspect returns `not_observed` or the original operation.
Execution advances native permission registration or at most one private
partition initialization per step. A catalog completion record publishes the
declaration only after all exact genesis records have verified readback.
Cancellation retains the allocated range, initialized prefix and original
operation, releases its pending name reservation logically, and publishes no
declaration. An operation's terminal result remains unchanged after later edits.
Missing transport responses establish neither rejection nor cancellation.

The first ALTER profile permits retention, operation budgets and compatible
Queue scheduling/DLQ policies. Schema changes have no action representation.
Partition count/hash/routing key, FIFO mode/key and Stream compaction key cannot
change. Unsupported transitions reject before durable admission. RENAME and
policy changes produce a successor definition on the same object and original
partition range. The original revision-one initialization remains a recovery
dependency. DROP RESTRICT rejects retained dependents. Completed DROP retires
the live definition and hides its name, while retaining its definitions,
operations and storage dependencies. Name reuse requires a new object identity.

An optional DLQ binds a live Queue's exact definition in the same scope/branch,
with the same schema after object/revision normalization. Publication requires
current destination metadata and append privileges and revalidates the exact
definition. Source publication atomically adds both dependency index entries.
Later source changes retain historical edges; generic edge removal returns
`QueueDependencyRetained` until a Queue closure owner can establish safe removal.
These declarations do not themselves transfer or discard payloads.

`log_lookup {namespace,name}` returns null or the complete `DirectLog.Definition`
and binary schema. The client reconstructs and checks its immutable declaration
digest. `log_list {namespace,after}` scans at most eight durable object records
per call, returning up to eight live declarations, an optional exclusive object
continuation, and a catalog observation position. A filtered empty page may
carry a continuation. Each page is a current observation, not a retained snapshot.
The definition binds current and original stored declarations, catalog
properties, original initialization operation and first physical partition ID.

`log_pending {namespace,after}` scans at most eight entries from the shared pending
directory. It returns only this principal's authorized pending log operations,
with an exclusive object continuation and catalog position. It never resumes
work. Other callers' bindings and inaccessible entries are filtered; an empty
page can still carry continuation. Each returned binding can be inspected or
explicitly resumed without inventing an operation after caller replacement.

All lifecycle calls use current database/schema authority and separate native
Stream/Queue domains. CREATE additionally requires schema CREATE and eligibility
for the declared owner; ALTER/RENAME/DROP require ownership. Inspection requires
current metadata authority, including original receipts after retirement. Pending
CREATE inspection requires CREATE until its metadata object is registered.
Successful requirements are rechecked after response buffering. Execute/admit
are mutations; inspect/cancel use the existing control reserve classification.
Invalid policies and unsupported evolution return `InvalidRequest`; changed DLQ
definitions and retained dependency removal return `Conflict`. An error after a
mutation attempt still requires original-operation recovery.

`DirectLogClient` and `transit-data-client.Catalog.callLog` use these same signed
actions. Saved work includes mandatory shared definition, exact connection and
complete DDL; lookup schemas belong to the caller's output arena. No call retries
or chooses a replacement identity implicitly. Payload operations use the
separate signed actions below. SQL declarations and named inspection lower to
this lifecycle through `DirectLogPreparedDdl` and `DirectLogIntent`; the
[SQL reference](../docs/handbook/reference/sql/streaming.md#stream-and-queue-declarations)
defines supported syntax and policy defaults. Workload SQL verbs remain unavailable.

### Stream payload and consumer progress

The signed `stream` action carries `DirectStream.Request`: `observe`,
`mutate`, `operation`, `group`, `cursor`, `page` or `wait`. Every request binds a
logical partition and exact declaration. Mutations carry one
`DirectStreamMutation.Request` (`append`, `assign`, `consume`, `offset` or
`release`); only append carries binary `LogBatch` payload. The complete request
is covered by the ordinary signed catalog envelope. Queue partitions reject
this action. No Station turn or Table row operation participates.

Append returns its original allocated range and producer receipt. Consume
accepts a finite retained cut; subsequent appends cannot extend it. Cursor and
page requests carry the original read handle, authenticated coverage, and
explicit row, encoded-byte and scanned-row budgets. Pages include the original
source declaration and schema, ascending offsets, operation/ordinal identities,
tombstones, and encoded Fuze rows. Encoded-byte accounting includes the 13-byte
log row header. Empty filtered pages can be incomplete; only the returned
coverage establishes exhaustion. Each page is separately authorized, including
terminal empty pages. Group pages additionally require current acquire rights.

`wait` carries the complete `StreamRead.Request` and a 1–1000 millisecond
scheduling bound. Its accepted identity and intent are the underlying `consume`;
the wait duration is not part of durable work. An existing read returns its
original receipt immediately, even if its original cut was empty or its pin has
since been released. Fresh work waits until `from < next`, or an explicit
exclusive `until <= next`, before selecting one finite cut. Timestamp filters
do not change this readiness predicate. Group membership and the expected
checkpoint are checked on every attempt. No read or operation reservation is
accepted while the predicate remains false.

The host registers before checking, releases catalog/object locks before
parking, and rechecks current rights, declaration, retention and group state
after each notification. One monotonic deadline covers all wakeups. A final
authorized recheck accepts a ready read even if the wait deadline has elapsed;
otherwise `timed_out` reports the observed cut without accepting a read or
pinning that cut. This outcome does not prove rejection of a concurrent attempt
with the same identity. Cancellation releases the registration and propagates
through transport; it cannot undo acceptance or establish nonacceptance. A lost
or cancelled exchange still requires original-operation inspection.

HTTP waits require the exact `x-transit-wait: 0:MILLISECONDS` header matching
the signed body, and cannot carry a control hint. Missing, conflicting or
unsupported hints reject before execution. HTTP and typed local waits share
the four dedicated wait lanes, leaving ordinary/control capacity available.
The host bounds active Stream and Queue registrations to 64 in total and enforces the
current declaration's waiter limit per stable object/partition; a revision
change does not reset this count. Capacity refusal is `ControlCapacity`.

Consumer assignment uses an explicit generation and initial next offset.
Offset settlement requires the exact group generation, expected checkpoint and
authenticated complete read coverage. Reading, releasing a pin, closing a
client or losing a response never commits an offset. Original settlement and
release can finish after ALTER or DROP under current rights. Fresh appends and
reads require the current live definition.

Mutations reserve their full intent in the shared catalog operation namespace
before partition acceptance. Reservation alone is not acceptance. `operation`
inspects that exact work and returns its original receipt or null; it does not
execute it. Changed fields, including a different target partition or offset
cursor, conflict. Every attempt retains its original identity after an
uncertain response. Bounded recovery can instead return `recovering` with its
examined count and physical position; this result accepts no new mutation and
establishes no data coverage.

Observe requires metadata rights; append requires append rights; positional
reads and release require read rights; group consumption requires acquire;
offset settlement requires settle; assignment requires ownership. All checks
include the current database/schema scope and repeat after response buffering.
Operation inspection requires the original work's current rights. Inspection,
release, offset settlement and reassignment use the control reserve.

`DirectStreamClient` and `Catalog.callStream` use this action. Saved mutation
bytes include mandatory shared definition, full connection, exact work and
payload commitment. Returned schemas and decoded rows belong to the caller's
output arena. The service bounds append payloads to 1 MiB, pages to 4096 returned
and scanned rows and 4 MiB encoded data; declaration limits can be smaller.
Recovery examines at most 256 frames per request. The local service derives its
private cursor key from the registrar seed; replacement with the same seed
preserves cursors. Rotating the seed requires reacquiring authenticated cursors
for retained reads and does not alter accepted receipts. Timed new work requires
an authoritative UTC interval within the native genesis clock-error limit and a
nonregressing persisted upper floor. Append age starts at the interval's upper
bound; expiry requires a lower bound proving the age has elapsed. Original
receipt lookup does not require a clock.

Conflicting identities, producer/group generations or checkpoints return
`Conflict`; released/missing read pins return `QueryExpired`; an opted-in
expired source range returns `HistoryReclaimed`. Invalid payloads, cursors or
budgets or wait hints return `InvalidRequest`. Missing required recovery storage remains
unavailable. Any mutation transport failure still requires original-work
inspection; its error class cannot establish rejection.

### Queue payloads, claims and settlements

The signed `queue` action carries `DirectQueue.Request`: `observe`, `mutate`,
`operation`, `page` or `wait`. A mutation carries `DirectQueueMutation.Request`:
`enqueue` with a binary `LogBatch`, `claim`, `settle` with ACK, NACK or an
extension, or explicit original payload-read `release`. Stream partitions reject
this action. Each operation reserves its
full immutable intent in the same catalog namespace as Tables, Streams and
declarations before Queue WAL acceptance. The reservation alone is not acceptance.
Changing kind, partition, definition, payload, claim limits or lease intent under
that identity conflicts, including after a lost response.

Every action requires current database CONNECT and schema USAGE. `observe`
requires Queue inspect, enqueue requires append, claim and original claim-page
disclosure and payload-read release require read plus acquire; settlement
requires settle. Original
operation lookup applies the original work's privileges. Receipts and exact lease
fields grant no authority. Current rights are checked after buffering data and
again before response disclosure, including empty selections and terminal pages.
The host serializes each Queue with its declaration changes and supplies trusted
UTC intervals through the same local clock capability used by Streams.

Enqueue accepts at most 1 MiB per batch, additionally bounded by declaration
limits. A claim selects at most 256 rows in the current service, further bounded
by the requested count, declaration limits and active lease capacity. Exhaustion
refuses rather than recording a false empty result. An accepted empty claim stays
empty on retry. Nonempty selections, per-message epochs, deadlines and attempts
are accepted atomically; original inspection and open payload reads survive expiry,
compatible declaration changes, DROP and unavailable time.

`wait` carries the complete `Claim` and a 1–1000 millisecond scheduling bound.
Its durable intent is the underlying claim; changing the duration does not
change its operation identity. An accepted claim returns its original receipt
immediately under current read and acquire rights, including an empty original,
after DROP or without a clock. Fresh work uses the same bounded FIFO selection,
trusted-time checks, claim limits and lease capacity as an ordinary claim.
Pending visibility, leased heads and retry-exhausted heads do not constitute
available work merely because the append frontier advanced. Capacity, scheduling
budget or clock failures remain failures rather than empty success.

The host registers before checking and parks without retaining catalog/object
locks or a data-owner lane. Publication and policy notifications prompt a fresh
authorized check. The next accepted visibility timestamp supplies a bounded
timer wakeup; only a new trusted-time sample establishes eligibility. One
monotonic caller deadline covers all rechecks. A ready selection can be accepted
on the final check. Otherwise `timed_out` returns the observed partition cut,
without accepting an empty claim or pinning the cut. This does not prove
nonacceptance by another concurrent attempt with the same identity. A widening
clock interval cannot convert readiness into a newly accepted empty claim.

Queue waits share Stream waits' signed HTTP hint, four dedicated admission
lanes, aggregate registration limit and per-declaration waiter budget. They
cannot use reserved control admission. Cancellation releases the registration
but cannot undo acceptance; a missing or unvalidated reply still requires
inspection of the original claim. Save that underlying claim before dispatch.

`page` carries a `QueueRead.Cursor` containing the exact original claim receipt
and a selection ordinal, plus row and encoded-byte budgets. Pages allow at most
4096 rows and 4 MiB of encoded row data, with smaller owner/declaration limits
applied. Rows contain original lease identity, producer attribution, visibility
time and encoded typed values, plus the separately observed current lease state.
The source schema belongs to the original selection; `basis` records the current
metadata cut and optional trusted time. Cursor advancement equals the returned
row count, including a final data page; an already complete cursor returns an
empty terminal page. A too-large first row refuses without advancement. A cursor
selects original rows and is neither a consumption proof nor a live lease.

`release` freezes its own operation and the entire original claim receipt. It
closes that claim's retained payload reads without changing any lease. Later
pages, including empty terminal pages, refuse with `QueryExpired`; original
claim and release receipts remain inspectable under current rights. This explicit
mutation is separate from local result-buffer cleanup and does not require a
clock. See [claim-read closure](QUEUE_V1.md#explicit-original-payload-read-closure)
for its retention boundary.

`DirectQueueResponse` validates original receipt and schema attribution, row
identity, increasing selected offsets, cursor advancement, encoded-byte totals
and lease observations. `DirectQueueClient` and `Catalog.callQueue` return schema
and rows owned by the caller's output arena. Save the complete mutation with
`DirectQueueClient.save` before dispatch and use `load` for recovery. No call
automatically retries, collects pages, renews or settles a lease. Mutation-attempt
evidence remains uncertain after a missing or unvalidated response. Original
inspection uses reserved control admission; settlement and payload-read release
use it for both original inspection and mutation.

Lease/identity conflicts and expiry return `Conflict`; unavailable or uncertain
time returns `ClockUnavailable`, and regression returns `ClockRollback`. Active
lease or private candidate capacity returns `StorageQuota`. Invalid payloads,
claim limits, lease durations, page budgets or wait durations return `InvalidRequest`.
Wait capacity returns `ControlCapacity`. These
classes describe a failed attempt, not rejection of earlier accepted work.

This standalone operation profile does not enable SQL Queue verbs, common
transactions or DLQ transfer. Native maintenance processes lease expiry,
physical timer cleanup and opt-in terminal payload expiry in bounded accepted
steps. Original claim reads retain their payload dependencies until explicitly
closed. An expired lease observation alone neither releases the acquired bit
nor transfers its FIFO head. See [Queue v1](QUEUE_V1.md) for
lease, retry, original-selection and remaining composition contracts.

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

An edge binds a source Table, Stream, Queue or named KV/Document's exact `DataLifecycle.Definition`, a dependent's
kind (`kv`, `document`, `captured`, `maintained`, `stream`, `queue`, `table`) and exact definition, and a
mask of required logical actions. Generic registrations require a nonzero mask.
Table-owned staged foreign-key edges carry `foreign_key {constraint, column}`
and zero privileges: protection requires metadata authority and grants no row
access. Generic `dependency_operation` cannot register or remove these edges.
Table sources accept Table action masks;
direct KV sources use `KVAuthority` privileges; named Document sources accept
SELECT only, mapped to native INSPECT and READ.
Stream/Queue sources accept their own five-bit action masks; their dependents
use native metadata inspection or ownership. Queue DLQ publication registers its
edge atomically as described above and retains it against generic removal.
These actions describe required access and never grant it. Both objects use branch
one and the same realm. Named resource dependents belong to this catalog; captured
and maintained dependents use their separate owning native metadata resource.
Registration verifies a named resource dependent's actual kind and exact allocated
or published definition. It does not certify initialization, activation or current
data availability. A computation registration remains an explicit owner assertion;
the query publication adapter must establish its definition separately.
Registration protects a source from DROP. It does not retain a data
snapshot or change history. Document and computation owners register before
their separate publication; direct KV and log dependents bind an already
published definition. Owners remove edges after retirement or recovery of an
abandoned publication. These steps
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

Staged Table foreign keys are registered by the original admitted Table DDL.
Each bounded step atomically records one referenced-column edge in both graph
directions and advances `protected_columns`/`dependency_steps`. All required
edges precede child visibility. Parent DROP and changes to a protected column's
type, collation, physical encoding or membership reject with a generic dependency
reason; compatible renames preserve bindings. A saved target definition remains
unchanged by parent renames. Newly registered edges require the exact current
parent definition and metadata rights, rechecked at publication.

Table DDL with foreign keys records `requires_settlement`. After Table commit,
`finalizing {evidence, operation}` exposes that durable outcome while bounded
dependency cleanup remains pending. It is not a rejected or replayable new
operation. Settlement records a closure before scanning one reverse edge per
step; obsolete registrations are removed only against the original known Table
outcome. Cancelled unpublished declarations release their acquired protection.
Cleanup uses current child metadata authority and requires no parent grant.
The object remains pending until settlement; retrying/cancelling a committed
operation continues its original cleanup and cannot roll back the commit.
`committed` is returned once this required settlement completes.

`dependencies` selects `dependents` of a source object or `dependencies` of a
dependent object, with an explicit authority and nullable cursor. Each call scans
at most four edges; denied edges are omitted while scan progress advances.
An empty page with `next` is incomplete. The cursor binds selection, authority,
catalog position and the last scanned full index key. A changed catalog position
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
Document=2, captured=3, maintained=4, Stream=5, Queue=6, Table=7), dependent definition, and a big-endian
unsigned 64-bit privilege mask. Each 80-byte definition contains big-endian
unsigned 64-bit realm/resource/catalog/branch/object/revision, then its 32-byte
digest. Foreign-key digests append a big-endian u32 constraint ID and u64
referenced ColumnId to that body. Forward keys contain the source's big-endian
object ID, a one-byte kind (0 generic, 1 foreign key), the referenced big-endian
ColumnId for kind 1, then the digest (41 or 49 bytes respectively).
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

`DirectReadDelegation.encode` retains the original grant in a canonical 433-byte
`TRG1` record. It contains the four-byte magic, mandatory 32-byte current
definition, connection scope (realm/resource/catalog), branch, audience,
principal, role-present byte and role value, executor, object ID, definition
revision and 32-byte digest, partition and accepted frontier, pin operation, retention byte, selection byte,
32-byte purpose, credential epoch, 32-byte claim context and 64-byte signature,
in that order. All integers are unsigned 64-bit little-endian except the
one-byte role flag, retention tag (`snapshot = 0`, `history = 1`) and selection
tag (`exact = 1`, `current = 2`).
The signature is followed by a copy-present byte, 80 source-handle bytes,
a projection-present byte, and 40 target-definition bytes. An absent optional
value has a zero tag and zero-filled payload. A source handle contains its
realm/resource/catalog, principal, operation and content length as little-endian
u64s followed by its 32-byte digest. The projection contains a u64 revision and
32-byte digest; its object must equal the original source object. A copy grant
requires exact snapshot selection, a distinct destination owner, and the same
catalog scope. The source definition and accepted frontier are checked before
copy acceptance; retries verify the accepted copy even after source release.
A projection grant authorizes only preparation of that exact source/target pair
and projected scans of the query-owned copy. Discovery remains denied.

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
zero byte and the exact 433-byte original `TRG1` grant, including its original
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
For a copy grant, later live definitions/frontiers cannot prove acquisition
impossible. Closure retries the original copy and releases it, or requires a
qualified released-pin response that permanently excludes a delayed copy.

`DirectReadDelegation.Borrow` grants another executor read access to one existing
cut. Its `binding` contains, in order, an executor principal, a target
(`snapshot: Snapshot` or `history: Historical`) and a nonzero 32-byte purpose.
It also carries the original caller's 64-byte signature. The claim retains the
original grant's identity, role, audience and credential epoch; its context is
SHA-256 of `transit.table.borrowed-read.v1`, a zero byte, the exact original
433-byte `TRG1` grant and canonical JSON of the borrowed binding. Preparing this
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

The host `resources` action uses `DirectCatalogResources` for named Document
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

### Retained projection coverage

`projection_definitions` accepts `snapshot` and nullable `after` with the pin's
`source` content and last physical `after` schema revision. It returns the exact
pin, logical `TableDeclaration.Stored`, accepted position, total live rows, one
nullable `entry` and nullable `next`. Each entry carries the physical stored
definition, a separate `schema_revision`, its positive live locator count, and
up to 128 logical column mappings. A mapping identifies the same stable physical
ColumnId or the exact ADD-time definition and initial five-state tag. Default
payloads are not returned. The definition revision and schema revision are
distinct; a Table rename need not change the physical schema revision.

`projection_locations` accepts `snapshot` and a nullable original identity
cursor. It returns at most eight entries in strict row-identity order, with the
same envelope and a continuation bound to the last returned identity. An entry
carries the physical definition and schema revision plus either a WAL LSN,
offset, byte length and row digest, or a segment ID, row ordinal and immutable
content descriptor. These are retained locator references, not a successful
payload-availability or checksum verification. Missing/corrupt payloads retain
their ordinary errors when a read attempts to load them.

The first operation requires current metadata visibility on the original Table;
the second requires current SELECT. Both require the pin's original principal,
recheck current rights before disclosure, and reject released pins. No latest
lookup, pin acquisition, renewal, row decoding or mutation occurs. Reopening an
owner may read its recovery WAL; inspection does not open segment payloads. Delegated
read and active transaction overlays do not admit these operations. An empty
first page is complete only for a zero-row source. A continuation cannot change
its source; a caller must visit every page and account for the original total
before claiming complete inspection. Inspection completion does not complete a
query result or modify its initial observation evidence.

The shared host catalog's `projection` action supplies `definitions` and
`locations` inputs with an owned retention `snapshot` and nullable saved cursor.
It returns an owned page and cursor. Counts, schema/definition/column IDs,
positions and row identities retain full-width decimal strings; location cursor
identities and digests use canonical lower-case hex. Each call performs one
public read and leaves the retention lifecycle with its caller.

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


### Signed transaction action

`Action.transaction` carries `DirectTransactionRequest.Request`. `begin` requires
`key`, nonzero SHA-256 `fingerprint`, `operation`, `namespace`, `mode`, `selection`,
`limits` and token `budget`. Explicit selection IDs are strictly increasing;
`authorized_catalog_tables` is discovered and frozen by the owner. The original
account/token binding wins a race; matching fingerprints recover that accepted
begin without reselecting the catalog. A different fingerprint conflicts.

`acquire` and `inspect` carry the original key. `stage` carries `key`, required `basis` catalog revision, `sequence`
and native `work` (bulk rows or statement, never DDL), and returns a frozen private
statement request. `statement` carries `key`, that exact `request` and `execute`;
false admits, true evaluates or recovers the original result. A nullable outcome
means admitted/pending, never rejected. `settle` carries `key`, original commit
`operation`, `command` (`commit`/`abort`) and `steps` in 1–256. `advance` carries `key` and `steps`; it advances only an
accepted pending statement, savepoint rollback or existing attempt, leaving idle active work unchanged.
The first accepted attempt remains binding; an abort cannot replace an already committed decision.

Results are `begun`, `acquired`, `staged`, `statement` or `status`, matching the
request. Status requires catalog `revision`, `begin`, `acquired`, `last_statement`,
`pending_statement`, `last_control`, `pending_control`, `savepoints`, nullable `attempt`, `observation` and `cleanup_complete`.
Only actual journal evidence establishes a final decision. Cleanup completion
separately establishes publication/barrier and original-pin release. Inspection
and settlement use reserved control capacity; other calls use data capacity.
All transaction actions exclude database publication. Current scoped checks share
one writer/policy epoch, checked again before disclosing a buffered response.

The acquired result additionally requires nullable `catalog`: an immutable paged
directory of the selected Tables' namespace/name/definition bindings, frozen
under the cut's publication fence. It is null when no selected participant is a
Table. KV and log participants remain in the complete transaction source
directory. Historical acquisition can transfer this authenticated cut to its own
retention through the [historical catalog owner](HISTORICAL_CATALOG_V1.md).
A pending transfer defers original-pin cleanup; it does not undo a durable
decision or turn incomplete cleanup into transaction rejection.

### Transactional Stream and Queue work

Explicit transaction selections can combine Table/KV objects and declared
Stream/Queue partition ordinals. `transaction.stage_log` carries `key`, `basis`,
`sequence`, typed `work` and nullable binary `payload`. Work is `append` (Stream
or Queue), `stream_offset` (commit plus the exact owner-issued cursor), or
`queue_ack` (an ACK settlement with its original fenced lease), or `queue_transfer`
(one source disposition and its exact dead-letter destination append). Append
and transfer carry payload bytes. Staging validates schema-bound batches and cursor authentication,
retains immutable payload bytes and returns `staged_log`; it accepts no statement
and reserves no public offsets.

The returned request fixes `statement`, `basis`, original log `guard` and `work`.
Its statement digest binds the exact work, including offset cursor authentication;
the permanent operation reservation additionally binds the complete request.
`transaction.log_statement` carries `key`, that exact `request` and `execute`.
False accepts it into the shared pending slot; true evaluates or recovers the
original result. State and log statements share one consecutive sequence, pending
slot and savepoint stack. Different content at a consumed sequence conflicts.
The same operation cannot be accepted as a standalone mutation, including after
rollback or abort.

The `log_statement` result is nullable pending knowledge, a provisional action
summary (row count, next offset, or ACK offset and lease epoch), or a typed
evaluation rejection. A summary is not a public receipt. Workspace limits meter
payloads, immutable indexes and private segment staging; resident limits cover
the temporary owner and evaluation. Memory, storage and authorization refusal
leave already accepted work available for recovery or explicit abort.

One common transaction decision publishes surviving Table/KV mutations, appends
and settlements. Preparation retains exact action directories, original pins,
predecessors and successors behind each owner's barrier. Commit rechecks current
read and operation rights, verifies the prepared data graph and samples trusted
time after all potentially slow verification, immediately before the decision.
Expired or uncertain ACK leases and elapsed append retention windows refuse
commit. Recovery of an actual decision does not require the old clock sample or
cursor signing key and cannot change that decision because time has advanced.

Savepoint completion restores its saved log action directory together with state
roots. Consumed sequences, operation reservations and original provisional
outcomes remain retained. `transaction.log_outcome` observes those outcomes under
current rights after rollback or closure. Read-only Stream/Queue `operation`
lookup accepts the exact transactional work and returns only an actual public
owner receipt; pending, rolled-back and aborted appends or settlements have no
such receipt. This lookup never permits standalone mutation of a reserved ID.

`queue_transfer` selects both Queue partitions in the common cut. Its source is
either a live NACK lease or an exhausted item's exact offset, epoch, attempt and
recorded `not_before_ms`. A live NACK requires current source READ and SETTLE;
exhausted-item transfer requires READ and administrative ownership. Both require
current destination READ and APPEND, including during repeated outcome disclosure
and immediately before the common decision. The destination definition is the
source policy's exact configured DLQ for a live NACK, or the exhausted item's
already recorded destination. A later source policy edit cannot redirect that item.

The source and destination schemas must match after normalizing object/revision
identity. The source owner re-encodes the original logical row, preserving its
visibility timestamp, under the destination definition and operation; replacement
data or a changed timestamp rejects. Destination routing and append bounds still
apply. Temporary owners are opened sequentially within the existing resident
budget. Each operation receives a permanent reservation binding the whole request
and its own public observation digest; an interrupted pair reservation is repaired
only by retrying the exact request.

One statement publishes both private action directories and its provisional
summary together. The source `queue_terminal` action has ordinal one and its
destination `queue_transfer_append` mirror has ordinal two. They contain the same
complete transfer and statement. The decision owner checks both directions by
operation identity, rejecting a missing mirror, ordinary substitute append or
two sources sharing one destination append. Only that common decision can publish
the source's archived state, FIFO advancement and destination payload. Standalone
terminal WAL records reject during publication and replay. Savepoint rollback
removes both actions while preserving consumed identities and original outcomes.

Claim acquisition, retry NACK and lease extension remain standalone operations.
Automatic scheduling of blocked DLQ transfers, SQL Stream/Queue statements and
Station turn composition remain separate implementation gates.


### Transaction-scoped private reads

The signed request envelope carries nullable `transaction`, containing the original
client-token `key` and exact active workspace `revision`. The connection must match;
read delegation, borrowed grants and closure grants cannot accompany it. Supported
actions are `lookup`, `check`, `check_set`, `read_authority`, `pin`, `pin_status`,
`snapshot`, `read_key`, `scan`, `column_scan`, `filter_scan`, `key_range` and `release`.
Other actions return `UnsupportedTransactionRead`. Pending statements or a changed
revision refuse access before disclosure.

Names and definitions resolve through the accepted begin catalog root. Each Table
must belong to the acquired source directory, retain its original live pin and
pass current SELECT authorization. The private Table root includes accepted
provisional writes. `Definition.workspace` and `Source.workspace` contain a required
`Transaction.ReadView` for this request context and are null for ordinary reads.
The descriptor contains the common `cut`, workspace `revision`, `last_statement`,
original Table `source` guard and a `private` content commitment. Positions and
`changed_lsn` retain the original committed source frontier; private evaluator
positions never become public Table acceptance LSNs. Source fingerprints include
the complete workspace descriptor.

The private snapshot handle uses the original begin owner and the private content
commitment. It is valid only with the matching transaction context, grants no pin
of its own and cannot be replayed as an ordinary retained snapshot. `pin` and
`pin_status` expose that same handle; `release` closes no transaction-owned pin.
A private `DirectTableReader` closes locally; transaction cleanup releases the
original source pins. Later workspace publication, settlement or rollback
invalidates prior private cursors. Every request rechecks current authority, and a
policy-epoch change after response buffering withholds that response.

The foreign metadata profile has no private-context representation and refuses
private metadata with `UnsupportedTransactionRead`; it cannot silently present a
private root as committed data.


### Durable savepoint controls

`transaction.savepoint` carries the original `key`, exact `request` and `steps`
(1–256). The request fixes `transaction`, original `operation`, positive control
`sequence`, workspace `basis` revision and `action`: `create`, `rollback` or
`release`, each with a bounded name. Controls consume their own consecutive
sequence, independently of DML statement numbers. The admitted statement limit
also bounds total control sequences; active savepoint depth has its separate
savepoint limit. Names are case-sensitive native names. The most recent matching
name shadows earlier names. Releasing a name removes that savepoint and all newer
ones; rolling back removes newer savepoints and keeps the named one available.

The response preserves the original request and Catalog `accepted` position;
nullable `completed` reports restoration/control completion. Creation and release
publish their completed receipt with the stack update. Rollback first durably
accepts the exact request, then subsequent calls restore at most `steps` Table
roots. `advance` also resumes that accepted rollback. Old completed controls return
the original receipt; changed content under the same sequence or operation
conflicts. A stale new request fails before consuming a sequence.

While rollback is pending, new reads, statements, controls and commit refuse with
`TransactionControlPending`. The previous active roots stay intact until one
Catalog update publishes the complete restored directory. Full transaction abort
can close a pending rollback. Rollback preserves the original common cut, selected
read dependencies, consumed statement/control identities, outcomes, operation
claims and monotonic private segment frontiers. Previously returned counts remain
provisional observations of their original statement. They do not describe the
restored workspace or authorize retry as new work.

The workspace head requires `savepoints`, `savepoint_count`, `controls`,
`last_control` and `pending_control`. Savepoint stack records use reserved canonical
format `0x54585331`; completed control receipts use `0x54584331`. Both use the
existing 32 KiB direct-record bound. The stack is an immutable chain, and controls
use the paged sequence directory. Name lookup visits at most the admitted active
depth without retaining the chain in memory. Rollback candidates remain reachable
through the pending head; active savepoint roots remain reachable through the
stack. Release drops those dependencies, permitting later collection; neither
release nor rollback promises immediate physical deletion. Resident and cumulative
workspace limits apply, and a resource refusal leaves accepted rollback work
pending until recovery or explicit full abort.

Private read evidence also carries `private_position`, the virtual evaluator
frontier used to guard a subsequent private predicate mutation. It can advance
without any public WAL acceptance. The source guard and public accepted position
remain separate; only the common decision publishes private state.

## Durable transaction caller commands

`DirectIntent.Reference.transaction_call` freezes a caller command before native
child admission. It fixes the signed connection, namespace, outer operation and
one begin, statement, savepoint or settle command. Outer and child operation IDs
must differ. Its `DirectClientToken` binding owns original account/token recovery;
its 37,376-byte reservation covers the bounded command/result record. Generic
intent execution and progress settlement cannot complete this work.

The signed `transaction.call` operation advances at most the requested bounded
steps. Its control flag must match a settlement command. It preserves original
child identities through lost replies, native-owner completion and outer-result
publication. Partial decisions can be observed while cleanup remains pending;
only final cleanup closes the outer pending directory entry. Definitive
precondition refusals are durable typed results. Unavailable storage, authority
or quota does not manufacture rejection. `call_outcome` observes the exact result
under current authority; statement/savepoint outcome lookup likewise preserves
original results after rollback or parent closure. Retained catalog history keeps
frozen DML alive even before native child admission.

The caller's cancellation request is sticky observation/workflow state. It does
not replace the frozen command with abort, undo a decision or establish that a
remote reply was never accepted. Explicit settle commands retain the original
transaction attempt and the common decision owner. See [SQL sessions](SQL_SESSION_V1.md#table-transactions-and-recovery)
for attachment and uncertainty behavior.

## Selected historical catalogs

The [historical catalog contract](HISTORICAL_CATALOG_V1.md) owns selection,
original-operation acquisition, publication, current disclosure and bounded
release. It reuses `DataLifecycle.Snapshot` and the direct Table authority.
SQL `AS OF SNAPSHOT` binds that catalog before names and schemas; historical
SELECT observations carry its immutable identity and exact source evidence.
Metadata observations retain catalog attribution without claiming row execution.
An independent source vector is not an atomic cross-Table cut.
