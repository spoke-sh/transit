# General Table metadata

`TableMetadata` and `TableMetadataStore` encode and stage immutable general Table
definitions. They are component helpers; staging does not create a live name,
publish a Table, authorize a caller or widen the signed catalog client's separate
admission profile. The enclosing catalog owner supplies current policy and
atomically updates its live object/name bindings and original operation outcome.

`TableCatalog` supplies the general namespace's captured-source policy and
resolution helpers. Configuration binds realm/resource/catalog, owner,
administrator and explicit Table Publication limits. Initialization refuses orphan
state; repeating it cannot restore revoked rights. Inspect, create, data read,
insert, update, delete, alter and drop are independent policy fields. Conditional
administrator changes remain possible after revoking the administrator's own
inspection right, provided native authority still permits the control.

Read helpers receive the authenticated principal from their enclosing caller;
neither a supplied number nor a stored policy grants native source access.
`lookup` checks current inspect policy, resolves complete names and verifies the
live head against immutable metadata and schema. `list` returns at most eight
inline metadata/head entries in object-ID order, without acquiring schema
defaults or row data. Its cursor binds scope and exact native
revision; current denial takes precedence over cursor use. Initializing/retired
objects advance the scan without appearing as live Tables. Release lookup
definitions with `deinit`; listing pages have no heap owner. Resident work does
not grow with catalog size or schema defaults.

The explicit administrator dependency registry distinguishes durable query
sources, writers, watches and maintained relations from historical references.
`blockingDependency` reads one page of the blocking index and returns an
attributed RESTRICT blocker. Removing one requires the same original dependency
identity and owner. Historical references remain stored but do not keep a name
live. Blocking index entries change atomically with their dependency records, so
DROP does not scan the historical-reference collection. The registry
does not bind runtime applications automatically, dispatch effects or authorize
physical reclamation. Native routing must integrate these helpers before their
behavior becomes a signed caller guarantee.

`TableDdlRequest` binds exact scope, principal, operation, object, expected
metadata revision, name and typed action. `TableCatalog.step` checks both current
inspect and action rights and the authenticated external principal on every
proposal. CREATE reserves a never-reused object, stages its schema and publishes
the head/name/metadata/original receipt atomically. `IF NOT EXISTS` records an
unchanged outcome without adopting or altering the existing definition. A name
race records the winning object; changing the saved intent is an identity error.

ALTER reserves a metadata revision and delegates frozen-schema validation or
rewriting to `TableAlter`. Its final three Table writes and the catalog object
write share one native decision. The catalog operation refers to the retained
Table outcome rather than requiring a fifth terminal write. Readers see the
original metadata and schema until complete publication. Rejected rewrites retain
that original view and exact Table failure; no candidate row prefix becomes live.

RENAME stages new metadata while retaining the physical schema and stable object.
It changes both name bindings, the object and receipt together. DROP defaults to
RESTRICT, removes the live name and retires the head/object in the same decision.
Dependency installation is fenced during pending DDL. New objects may reuse a
dropped name; saved operations remain bound to their original object and outcome.
`IF EXISTS` prepared against absence cannot drop a subsequently created object.
Retained schema references remain readable under the caller's authorized source.

`status` requires current inspect permission and verifies the original digest.
`cancel` also requires that permission and the original authenticated principal;
it can close unfinished work after its execution right is revoked. Cancellation
during early ALTER admission may require two bounded decisions. `cleanup` removes
only bytes of rejected/cancelled candidates whose retained receipts prove they
never became live; it releases staging quota and preserves ID floors and terminal
receipts. It does not reclaim accepted history or promise physical erasure after
DROP. `historical` verifies the original applied catalog/Table outcome before
accepting published metadata as a historical definition.

`TableClient.definition(object, revision)` and `TableCatalog.definition` return
owned `HistoricalDefinition` metadata and schema for an exact accepted revision.
They do not attach the current head or assert that the object remains live.
Current native grants and catalog inspection policy gate each acquisition, even
after DROP or name reuse. An absent object/revision or a known unfinished,
rejected or cancelled candidate returns null. Private Publication completion is
insufficient: the original catalog receipt, or applied delegated Table receipt,
must name the exact metadata commitment and admitted input. Missing original
acceptance evidence, conflicting inline/chunked records and incompatible/corrupt
retained definitions return errors. Schema and metadata revisions remain distinct
across rename and DROP. Call `deinit` on the owned historical result.

`TableDmlRequest` binds the complete typed plan to its original catalog scope,
name and immutable metadata reference. Routing uses `TableWrite` for one inserted
row or an exact conjunction containing every primary-key equality and no extra
predicate. Other selected finite statements use `TableStatement`. The catalog
recomputes the enclosing-owner binding from the complete request, including
predicates; switching routes or changing metadata/intent at an occupied operation
rejects. The ordinary small-row insert retains its four-write publication path.

`mutate` requires current inspect and action-specific permission. Pending DDL
fences new DML; a pending Table write fences new DDL. Exact terminal receipts are
returned before consulting a possibly renamed, altered or retired live schema.
`mutationStatus`, `cancelMutation` and `cleanupMutation` verify original ownership
and current inspect permission; execution revocation does not erase accepted
work. `readDefinition` separately requires current read permission and exact
metadata, returning the original live schema during pending evolution. Its
caller must retain the native cut for subsequent row reads.

`mutationReceipt`, `cancelMutationReference` and `cleanupMutationReference` use
the saved exact Table reference without retransmitting original rows. They check
catalog/object ownership, principal, resource and current inspect permission.
The retained receipt records whether its owner is point DML, a finite statement
or ALTER. Direct DML controls reject ALTER references, preserving the catalog's
schema/name decision and reservation cleanup. Typed-request controls also verify
that the recorded route matches the complete original plan.

`continueDdl` and `continueMutation` accept only native process input from the
configured owner, referring to an already recorded exact operation. They cannot
admit a first operation or reinterpret process input as an external principal.
Every continuation rechecks the original principal's current policy. Denial
leaves the accepted work and reservation intact; scheduling, input dispositions
and explicit resume/cancel remain responsibilities of the enclosing native host.

`TableCommand` supplies a typed DDL/DML body for that host. Its 141-byte header
checks the current shared definition and exact scope, owner, principal, operation,
object and immutable metadata reference before schema-dependent decoding. Header
inspection is allocation-free and does not admit work. The host checks current
native/catalog authority and resolves accepted metadata before supplying a basis.
CREATE carries its schema; ALTER carries an explicit change against its original
schema; DML uses FDM1 against that same immutable basis. RENAME and DROP need only
metadata. Typed callers and SQL compilation use the same request models.

Decoded commands own their variable-width values and descriptors. DML retains
its separate schema/value owners; DDL uses one parent arena. Release the command
with `deinit`. Small point commands fit ordinary Station frames; larger bodies
require the enclosing host's bounded Publication transport. Encoding does not
send a command, schedule a continuation or add native caller support by itself.

`commandBasis` resolves the accepted original metadata/schema under current
permission, including after DROP and name reuse. `TableUpload` supplies bounded
Publication staging for larger bodies. It accepts contiguous 128-byte parts,
verifies exact duplicates, and refuses namespace adoption. Publication and
application binding occupy separate committed turns before SQL execution.
`executeUploaded` verifies the retained external intent before admitting an owner
self-message; ordinary continuations still cannot manufacture a first operation.

Upload identity and the exact application reference survive body collection.
Current inspect permission gates recovery; action permission gates execution.
Cancelling unadmitted transport does not claim an SQL outcome. Once admitted,
cancellation uses the original coordinator. Collection requires closure and
never deletes its receipt. Each staging/collection turn stays within four native
writes. These helpers still require native behavior/client wiring and do not
change the console's supported syntax by themselves.

`TableBehavior` supplies the general owner hooks for a Station GenServer. It
accepts small typed commands in one cast frame and handles larger uploads through
`TableControl`. A pending operation schedules one exact durable self-message;
completion schedules none. The owner checks recorded intent and current policy
on every continuation. Denied work gets an input disposition and pauses without
losing its reservation. Explicit exact resume can continue after rights are
restored. Native evidence failures reject the entire private proposal.

Self-messages require Transit's existing authorized delivery courier, just like
other process outputs. A courier outage preserves the pending output and Table
reservation; GenServer does not grant itself delivery authority or bypass native
routing. Deployments must run the delivery service alongside the Table owner.

Initialization, policy and dependency controls retain separate input outcomes.
SQL outcomes remain in their original catalog/Table receipts. Cancellation and
cleanup use those exact references, with no extra fifth receipt write. The module
is available for deployment composition; the existing configured native client
and console are not switched by adding the module.

`TableIntent` owns exact bytes for offline recovery: the typed command, upload
identity, accepted metadata and original schema where required. It validates the
complete canonical record and derives the original operation reference without
looking up a live name. Small commands use a small encoding workspace; larger
ones use a bounded temporary buffer and retain only their actual saved length.
Release each restored intent with `deinit`. `matches` ties a saved native send to
the same command or exact upload/control step. Signed-send persistence and native
authority remain distinct from this offline intent record.

`TableClient` provides signed preparation/submission, owned metadata reads and
exact recovery over these general owner hooks. Save the TCI1 intent and each
`Prepared` send before submission. Retry an uncertain send with its original
signature and sequence; `next` is for a reconciled successor step. It distinguishes
running SQL, terminal SQL and cancellation of unadmitted transport. `prepareResume`
explicitly schedules paused original work. Typed controls expose cancellation,
candidate/body cleanup and conditional policy/dependency changes.

`TableDiagnostic.status` projects original saved intent and durable execution
evidence. Rejected primary keys include the key columns, bounded escaped values
and exact input ordinal or immutable source row identity. Failed ALTER validation
includes the failing column, value, expected type and applicable Unicode limit.
Previews longer than 64 bytes carry explicit truncation. The renderer never
rereads a current row to guess the cause of an earlier failure.

Catalog inspection permission gates all outcome access. Stored-row identity and
value additionally require current read permission; denied fields are explicitly
withheld while the rejected outcome and schema facts remain inspectable. INSERT
evidence uses the caller's original input and remains inspectable without read
permission. A projected withheld witness cannot overwrite the durable witness.
Restoring permission reveals the original evidence, including after DROP and
reuse of the name. Native grants remain independently required for every read.

`progress` checks native mailbox processing before reading application and input
outcomes at one authorized cut. The notification variants retain only an exact
input scheduling cursor and preserve bounded capacity backoff. They do not cache
authorization. This general caller is not yet the console/ABI's configured path;
those consumers require a coordinated current-definition cutover.

`compile` turns SQL into the same owned intent used by typed callers. CREATE
requires an explicit fresh object identity and compiles without a metadata read;
the owner still checks authorization, conflicts and readiness at execution.
DML and bound ALTER/DROP resolve the original schema through current catalog
inspection. Optional absent DROP stays bound to absence. Operation and upload
identities remain caller-owned; recovery uses the saved intent instead of calling
`compile` again.

A record owns scope, full-width object and metadata revision, exact name,
immutable Table schema reference and complete schema fingerprint, principal,
original operation and admission input. The metadata revision is independent of
the schema revision: a Table rename preserves its schema, while a column change
can replace both. Admission input remains stable through staging; it is not the
later native input that commits the live binding.

Names contain 1–255 UTF-8 bytes without NUL. The type owns those bytes and compares
them exactly. SQL normalizes unquoted names before construction; this codec does
not case-fold typed names or invent Unicode normalization. A 32-byte binding key
contains catalog identity, a 13-byte SHA-256 prefix and the full object identity.
Prefix equality is only a lookup bucket. Resolution must read the corresponding
immutable metadata and compare actual names, retaining every colliding object.

Records are at most 436 bytes because they refer to the complete schema rather
than embedding it. `readSchema` verifies the referenced bytes, object and full
fingerprint at the supplied source cut, returning allocator-owned schema values.
It does not consult a newer Table head or reinterpret historical metadata.
The caller must release the returned value with `deinit`.

`TableMetadataStore` uses the dedicated catalog Publication domain and object
namespace. A mandatory manifest binds current definition and exact scope/object.
Initialization refuses orphan state and cannot adopt another catalog's namespace.
One active metadata record may be staged, within the fixed per-record budget;
historical record count is independent of resident work.

Encoded records of at most 256 bytes use one inline native value. Longer records
use the ordinary resumable Publication phases and chunk budget. The supplied
reference's length selects representation; there is no fallback decoder. Repeated
staging must provide exactly the same bytes at a revision. Both readers verify the
complete commitment. Large reads require a committed Publication cursor and reject
opening a just-published private descriptor. No helper weakens current source
authorization, captured-turn fencing or the four-mutation limit.

The [catalog contract](../../../../contracts/DECLARATIVE_CATALOG_V1.md#general-table-metadata-records)
specifies bytes and keys. Native binding/lifecycle integration and disk evidence
remain separate from these codec and captured-turn storage helpers.

## Neutral general Table callers

`TableValues`, `TableTyped` and `TableBridge` provide general Table values and a
shared caller session for foreign interfaces. These Zig helpers do not themselves
change the separately exposed ABI/port or language SDK profiles.

Schemas use `TableSchemaJson`: mandatory current definition, canonical decimal
identities, recursive logical descriptors and lossless typed defaults. Metadata,
policy revisions, row counts, operation/upload IDs and staging-byte quotas retain
full u64 values as decimal strings; native counters retain native numeric bounds.
Lookup owns its metadata, head summary and schema. Listing owns at most eight
metadata/head summaries, with no row or schema-default acquisition. A continuation
can scan past retired objects; its last object need not appear in the live page.

Typed requests explicitly supply the current definition, operation/upload identity,
Table name and action. CREATE includes a complete schema; other actions bind the
selected object, metadata revision and schema fingerprint. A stale basis rejects
before producing a new intent. Column references are stable IDs. INSERT supplies
one assignment list per row; omitted fields, DEFAULT and explicit NULL use the
shared schema rules. UPDATE uses the same assignments, and UPDATE/DELETE accept
at most 64 shared postfix Boolean instructions over scalar comparisons and state
tests. Typed ALTER uses the shared evolution forms and exact conversions. Typed
requests and SQL produce the same canonical intent; neither grants execution rights.

One `TableBridge.Session` retains one immutable intent. `compile` or typed
`prepare` returns its summary and saved TCI1 bytes as lowercase hex. `load` checks
those exact saved bytes and connection without a network read, name resolution,
SQL compilation or signature change. The summary's reference commits the complete
TCI1 record, including upload namespace. References require the current definition
and a 64-character lowercase digest. Results belong to the supplied result arena;
the intent belongs to the session allocator. Failed preparation, validation or
result allocation leaves the previous intent loaded. Replacing, forgetting or
destroying a handle has no remote cancellation effect.

Persist the saved intent before any submission. `next` returns a prepared signed
step, running state, the original terminal outcome or a cancelled-upload state.
Persist each prepared step before `submit`; an uncertain step is reconciled by
submitting those same bytes, never by requesting another step. `status` is a
current-authorized observation and cannot settle an unknown send. `progress` and
`wait_progress` retain the distinction between native input processing, input
disposition, SQL outcome and upload status. Recovery calls carry the small intent
reference rather than retransmitting the full immutable command. After handle
replacement, explicitly load the persisted intent again. A missing or different
loaded intent rejects; it never resolves a new Table by name.

Initialization, conditional policy and dependency controls remain explicit signed
preparation operations. Resume, operation cancellation, unaccepted-candidate
cleanup, upload cancellation and upload collection refer to the loaded original
intent and use the native owner's current gates. Cleanup is not DROP or physical
erasure. Terminal DML counts and diagnostics come from the retained outcome;
control dispositions have separate diagnostics and cannot impersonate SQL success.

Complete neutral actions have a 16 MiB encoded-byte bound, depth 96, at most
1,048,576 JSON tokens and 256 fields per object. The binary schema, row, intent,
1024-row statement and 8192-byte prepared-step limits still apply independently.
Large binary/nested values use logical cells, not SQL string construction. One
loaded intent bounds resident recovery state independently of Table cardinality.
