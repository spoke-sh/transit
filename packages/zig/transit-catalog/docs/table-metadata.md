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
`blockingDependency` scans bounded pages and returns an attributed RESTRICT
blocker. Removing one requires the same original dependency identity and owner.
Historical references remain stored but do not keep a name live. This registry
does not bind runtime applications automatically, dispatch effects or authorize
physical reclamation. Lifecycle transitions and native routing must integrate
these helpers before their behavior becomes a caller guarantee.

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
