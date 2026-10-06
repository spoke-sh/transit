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
owned definitions in object-ID order. Its cursor binds scope and exact native
revision; current denial takes precedence over cursor use. Initializing/retired
objects advance the scan without appearing as live Tables. Release owned pages
and definitions with `deinit`. Resident work does not grow with catalog size.

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

Initialization, policy and dependency controls retain separate input outcomes.
SQL outcomes remain in their original catalog/Table receipts. Cancellation and
cleanup use those exact references, with no extra fifth receipt write. The module
is available for deployment composition; the existing configured native client
and console are not switched by adding the module.

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
