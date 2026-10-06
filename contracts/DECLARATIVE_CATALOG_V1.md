# Declarative catalog v1

`transit-catalog` owns named state definitions above Station. Its supplied Zig
helper creates an empty Table and publishes its definition, name binding and
operation receipt in one resource turn. Native authority still validates current
grants, ownership, fencing and atomic commit. This is an explicit application
integration API with shared Zig/C ABI/native-port callers and an explicit
`catalog` role in `transit-query-host`. The explicit
[catalog CLI](../apps/transit-cli/docs/catalog.md) composes the same caller.
Python exposes [typed sync/async catalog callers](../packages/python/transit-station/docs/catalog.md),
TypeScript exposes [typed promise methods](../packages/ts/transit-station-sdk/docs/catalog.md),
Rust exposes [typed blocking methods](../packages/rust/transit-station-sdk/docs/CATALOG.md),
Ruby exposes [typed synchronous methods](../packages/ruby/transit-station/docs/CATALOG.md),
C exposes [owned handles and inline values](../packages/c/transit-station/docs/CATALOG.md),
C++ exposes [typed move-only callers](../packages/cpp/transit-station-sdk/docs/CATALOG.md),
Java exposes [typed futures](../packages/java/transit-station-sdk/docs/CATALOG.md),
.NET exposes [typed tasks](../packages/dotnet/transit-station-sdk/docs/CATALOG.md),
Erlang exposes [typed records](../packages/beam/transit-station-sdk/docs/catalog.md),
and Elixir exposes [typed structs](../packages/beam/transit-station-elixir/docs/catalog.md).
SQL query transports expose no catalog administration route.

The implementation supports the two-column Table profile. KV/Document definitions
compile [offline](STATE_DECLARATION_V1.md) but have no catalog creation operation.
Connection/source/sink definitions, dependency-bearing objects, replacement,
removal and maintenance are outside the current helper. Neither Station process
name resolution nor the authority's storage index is this declaration catalog.

## Identity and ownership

A catalog scope is `(realm, resource, catalog)`. `resource`, configured realm, owner PID,
administrator principal and accepted input positions use native IDs in
`1..2^53-1`. Policy/receipt principals can also be native root principal zero.
Catalog IDs, object IDs, operation IDs and definition/policy revisions are
independent uint64 values; nonzero is required. A physical Table ID is a nonzero
uint32. No numeric identity is derived by truncating another identity.

Configuration freezes scope, realm, owner PID and administrator. Replacement
workers use the same configuration with a fresh native fence. Names use Fuze's
owned sixteen-byte ASCII identifier rules. Unquoted SQL names fold to lowercase;
quoted names preserve case. A name binding refers to an immutable object/revision
and definition digest. The definition retains the original name, physical Table
binding, schema, publishing principal, operation and accepted input position.

The first definition revision is one. Column identities `key = 1` and `value = 2`
are scoped by object identity; they are independent of column names and the
physical Table ID. This does not implement schema migration, rename, branches or
historical SQL. Exact definition metadata can be inspected by object/revision
under current inspection policy. Definition and receipt records have no implicit
expiry or cleanup. Creation refuses reuse of an existing object identity.

## Initialization and policy

`Catalog.initialize(turn)` requires an external input from the configured
administrator and a turn for the configured realm, PID and resource. Two private
writes install immutable configuration and revision-one administrator policy with
create/inspect rights. A duplicate checks configuration and existing policy,
writes nothing and cannot restore revoked rights. Foreign configuration or a
missing/foreign stored contract definition rejects.
Before first initialization, one ordered committed page proves the catalog key
namespace empty. Orphan catalog records reject adoption; initialization therefore
requires a page reader. It rejects private writes in its own catalog namespace;
unrelated framework setup may share the turn. The explicit committed source
excludes those private writes from the orphan check. Physical
Tables elsewhere in the resource do not become catalog objects implicitly.

`setPolicy(turn, expected_revision, policy)` is administrator-only. The target
policy is scope/principal qualified, and its revision must be exactly
`expected_revision + 1` without overflow. Absent policy has revision zero. An
identical retry writes nothing; a different current revision rejects. `create`
and `inspect` rights are independent. They are application policy, not native
resource grants, send rights or execution ownership. Process-origin inputs do
not impersonate external principals. Every public read and creation invocation
checks configuration and current applicable policy before returning stored data.

## Conditional Table creation

`Model.CreateTable.compile(scope, operation, object, table, sql)` uses Fuze's
shared declaration compiler and explicit Table capability adapter. It requires
exactly two columns, an explicit `INT64 NOT NULL` key and an explicitly nullable
value of type `INT64`, `BOOL`, `UTF8` or `BINARY`. Typed callers receive the same
schema validation. The canonical request owns scope, operation, object, physical
Table ID, normalized name and complete schema. SQL text/comments are not saved
command identity.

`Catalog.createTable(turn, request)` requires current create policy for the
authenticated external principal. The operation identity is
`(scope, principal, operation)`. The first accepted request freezes all request
fields. An exact duplicate returns its original receipt without writing; altered
intent rejects with `CatalogIdentityConflict`. Authorization is rechecked before
that recovery response.

Creation requires an absent name, absent revision-one object definition and an
absent physical Table descriptor. It never adopts an existing Table, including
one with identical schema. Conflicts are checked in that order and record one
terminal receipt: `name_conflict`, `object_conflict` or `table_conflict`. Retrying
that identity cannot acquire a name or ID that later becomes available. Missing
or malformed referenced metadata is an integrity error, not absence.
After those checks, one ordered page at the same captured revision proves the
physical Table row prefix empty. Orphan rows reject with
`CatalogSourceAlreadyPopulated`; an absent descriptor does not authorize their
adoption. New creation therefore needs a page reader and no preceding private
mutations. This page can cross the prefix just like metadata listing below.

A successful private proposal contains exactly four writes:

1. The existing Station Table descriptor for an empty Table.
2. Immutable catalog definition revision one.
3. Name binding to that object/revision and exact definition digest.
4. The original request and `applied` receipt with principal/input attribution.

These share the native commit decision with input progress. No new resource,
writer, principal, grant, query policy or mutation policy is implicitly created.
Application query/writer integration remains explicit. Initialization needs a
separate turn; it cannot consume extra slots in the creation turn. Any error
restores the incoming private proposal.
Station's sticky read error still prevents committing after a caught read failure.
Infrastructure errors do not become successful or terminal conflict receipts.

The receipt reflects application by the owner, not transport admission. Before
commit it is only a private proposal. Native callers must preserve exact signed
send/commit identity across uncertain responses. The private helper alone does
not implement worker dispatch or native receipt reconciliation; the shared caller
below owns signed sends.

## Signed Zig caller

`Client` borrows the public native transport and owns a connection and signing
key. The connection binds realm/resource/catalog scope, owner PID and caller
principal. The supplied catalog host accepts initialization, creation and policy
commands; a custom application must explicitly dispatch those commands to the
same owning helpers. The caller does not provision or start that application.

`describe()` reads configuration and the caller's policy in one current native
batch. It checks the active resource's writer and exact scope before returning
metadata. At least one catalog right is required. `prepareCreate(request)` adds
the original operation receipt to that same bounded batch, requires current
create policy and refuses changed intent under an existing operation ID. It then
reads the principal sequence and signs one Station cast without submitting it.
Concurrent handles sharing a principal must coordinate their native sequences.
The owner independently rechecks current create policy when applying the input.

`prepareInitialize(configuration)` requires the exact connection scope, owner
and caller as administrator. One current batch checks the active native writer
and any existing configuration. Absent configuration permits preparation only;
the host still checks authorization and refuses orphan state. Exact repeated
initialization never resets policy. `preparePolicy(change)` reads configuration
and the target policy together, requires the configured administrator and checks
the expected revision. An already equal target policy permits an exact application
duplicate. A different current revision rejects preparation. The host independently
checks the conditional transition when processing the input.

Administrator control does not require catalog create/inspect rights. An
administrator can restore a revoked application policy while retaining the
required native read/send grants. This grants no exception to current result
inspection policy. All preparation methods sign but do not submit, reserve a
sequence, acquire a retained view or promise that a later input will apply.

`Prepared` owns version one, the mandatory current contract definition, the
complete connection and signed native send. `save` writes canonical JSON;
`restore` accepts complete canonical input of at most 8192 bytes, validates both
required definitions, frame/command structure and scope, and returns owned
fields. Missing/foreign definitions, altered connection binding, unknown fields
and noncanonical bytes reject. The record contains no private key. Saved bytes
remain opaque recovery material to foreign languages; full-width application
identities must not pass through an inexact JSON-number conversion.
`command()` returns the typed initialization, creation or policy command;
`request()` returns a creation request and rejects controls. Existing creation
commands keep their exact encoded and saved bytes.

`submit(prepared)` validates the connection, complete command and signature
before transport access, then attempts the exact signed send once. It performs
no metadata acquisition, re-signing or automatic retry. Preserve the original
prepared value across uncertainty and caller replacement. A native receipt
establishes admission only. `observe(prepared, input)` checks current native
process inspection and the exact pending input where present; `processed` does
not promise that the catalog object was published. Supply the input position
from that exact send's receipt.

`status(original_request)` reads configuration, current inspect policy and the
operation receipt in one native batch. It checks all original request fields and
principal before disclosing an outcome. Missing status remains `null`, including
before application; it is not a successful or rejected publication. Create and
inspect rights are independent. Native resource grants apply to every batch, and
application inspection denial prevents this API from returning earlier receipts.
These application checks do not remove rights granted directly by native policy.
Only protocol feature support is cached; permissions and resource revisions are
never reused across acquisitions. No retained snapshot or implicit input is
created by metadata or status reads.

`inputDisposition(prepared, input)` reads a supplied behavior's disposition for
that original control or creation send under current inspect rights. It verifies the exact
scope, external principal, input position and complete frame fingerprint. A
missing disposition is not a successful creation: successful creation uses its
operation receipt instead. Preserve each send's original prepared value and
native receipt position separately from its application operation ID.

## Neutral caller values

`Bridge` exposes the signed caller through shared typed `Action` and `Result`
values. The connection contains `scope`, `owner` and `principal`; scope contains
`realm`, `resource` and `catalog`. Native identities and resource revisions are
safe-integer JSON numbers. Catalog IDs, object/operation IDs, policy revisions
and expected revisions are canonical unsigned decimal strings, retaining the
full u64 range. Signs, leading zeroes, whitespace and overflow reject. Native
identity bounds still apply. Schema names are exactly two strings and
`value_type` is `int64`, `boolean`, `utf8` or `binary`.

| Action | Input and result |
| --- | --- |
| `capabilities` | Local supported operations, current definition and saved-command/Table bounds; no authority lookup |
| `compile` | SQL, operation/object strings and physical Table ID; returns the typed request plus canonical `q` record hex; offline, with no policy or admission claim |
| `describe` | Current configuration, caller policy and resource revision |
| `lookup` | Exact name string; returns optional definition with current binding and live Table schema checks |
| `definition` | Object and definition revision decimal strings; returns optional immutable definition |
| `list` | Null for a fresh listing or a complete continuation cursor; returns one current-authorized page |
| `prepare_initialize` | Exact configuration; returns the owned opaque prepared string |
| `prepare_create` | Complete typed original request; returns the owned opaque prepared string |
| `prepare_policy` | Expected revision string and complete target policy; returns the owned opaque prepared string |
| `submit` | Original prepared string; returns native admission receipt |
| `observe` | Original prepared string and native input position; returns pending/processed |
| `input_disposition` | Original prepared string and native input position; returns optional current-authorized control/rejection disposition |
| `status` | Complete typed creation request; returns optional original operation receipt under current inspection policy |

Typed creation requests contain scope, operation, object, Table ID, normalized
name and schema. Receipts retain that complete request, external principal,
native input position and original outcome. Dispositions retain scope, source
classification, external principal where applicable, native input, the 32-byte
frame digest as hex and the original outcome. Null results remain absent; they
are not interpreted as success. Prepared strings retain their canonical bytes
without foreign JSON decoding/re-encoding or loss of full-width fields.

All native conversion validates the existing owning model. Decoded native values
own their bounded fields; returned strings belong to the supplied result
allocator. The shared protocol JSON codec checks reflected wire shapes. The
bridge performs no independent signing, authorization or recovery transition and
creates no host task or resource. The
[catalog caller ABI and native port](../packages/zig/transit-station-bindings/docs/catalog.md)
expose these values through explicit handles, owned result buffers and exact
uncertain-dispatch recovery. Idiomatic language routes remain separate.

## Supplied catalog behavior and host

`Behavior.interface()` and `guard()` compose the private catalog with Station's
GenServer. The supplied `transit-query-host` `catalog` role takes the exact
`Model.Configuration`; its realm and owner must match the host's activation and
its resource must match the required association. Native provisioning, grants
and ownership are explicit prerequisites. Configuration files grant no authority.

Before exposing untrusted ingress, prepare, save and explicitly submit
`Client.prepareInitialize(configuration)` from the configured administrator.
Its Station cast contains `Model.Command{ .initialize = configuration }`,
encoded with `encode()`.
Its payload is the canonical `c` configuration record. Initial publication has
four atomic writes: Station's framework descriptor, catalog configuration,
administrator create/inspect policy and an input-bound `initialized` disposition.
The committed source checks the catalog namespace while excluding the private
framework descriptor. Neither initialization nor Table creation exceeds the
ordinary four-mutation turn. A manual catalog lacking the framework descriptor
is not adopted by this behavior.

Duplicate initialization records a disposition for the new input without
resetting configuration or policy. Existing configuration is checked on every
dispatch. Replacement OS workers require fresh native ownership and a fresh
activation marker, using the same immutable catalog configuration. The host's
startup log establishes activation only; the durable initialization disposition
establishes catalog readiness. The catalog role allocates no Arrow workspace or
query-source adapter.

`Model.Command.create_table` carries the existing `q` request bytes used by the
signed creation client. Success records the original four-write operation
receipt. `Model.Command.set_policy` uses tag `g` with an expected revision and
complete next policy. Only the configured administrator can issue controls.
Policy publication and its `policy_applied` input disposition commit together;
an exact duplicate needs only the disposition write. A stale expected revision
records `stale_policy` without changing policy. These typed controls do not
implement SQL `GRANT/REVOKE` or change native grants.

After initialization, the input guard records malformed frames, incompatible
commands, non-external origins and unauthorized controls as bounded dispositions
before other framework dispatch. Creation denial, changed application identity
and stale policy controls also record dispositions. Their outcomes do not replace
or rewrite the original operation receipt. An input rejected before catalog
acceptance does not reserve its application operation ID. A new signed input can
retry creation after policy changes; its earlier input disposition stays intact.
Before initialization, unexpected input stops execution without consuming it;
initialize through trusted provisioning before admitting other callers.

Infrastructure/read failures and corrupt stored state do not become successful
or rejected application results. Read errors poison the turn; other unclassified
errors stop the supplied host with the input unconsumed. Lost native receipts
remain exact pending commands until reconciled. A restarted worker cannot reuse
an old activation or regenerate an uncertain command under its previous fence.
Dispositions have no implicit expiry. Their source classification distinguishes
external callers from process/effect input; only external input carries a
principal attribution. Native input history retains the complete source evidence.

## Inspection and bounded pages

`receipt` reads the current principal's original operation result; `definition`
reads exact object/revision metadata; `lookup` resolves a normalized name.
Inspection needs current inspect policy and the enclosing native read authority.
Lookup verifies the binding digest, scope, object/revision and original name, then
checks the live Table schema. A current name cannot silently reinterpret old
definition metadata. Point lookups read only catalog records and Table descriptors.

`list(turn, cursor)` performs one committed native page scan in the catalog's name
prefix and resolves at most eight definitions. Its owned cursor binds scope,
resource revision and last normalized name. A changed resource revision requires
restarting; pages from different cuts are not concatenated. Authorization is
checked before cursor use, including after revocation. Private mutations in the
turn reject a committed page scan. Entries are strictly ordered, a non-null next
cursor must match the last scanned key, and holes/malformed records reject.
An empty final page is possible when the next native page leaves the name prefix.
Native pages can cross that prefix and contain other framework keys or Table
rows. The helper stops at the boundary without decoding or returning those values;
the supplied native reader must be authorized for its actual page reads. This
interface returns metadata only but does not promise zero row-byte I/O during a
boundary page scan.

The signed Zig `Client.lookup(name)`, `definition(object, revision)` and
`list(cursor)` use the same deterministic `Inspection` validator. Each call
begins with a current configuration/policy batch and verifies the active native
resource writer. Subsequent point/page reads require that exact current resource
revision and current native grants. No retained view, admission or permission
cache is created. A cursor is a local continuation value, not a bearer grant;
catalog inspection authorization precedes continuation validation. Native
ABI/port actions, explicit CLI commands, Python sync/async, TypeScript promise
and Rust blocking methods expose the same reads. Other language SDK metadata
mappings remain separate from their creation/control methods.
Signed listing fetches definition records in one bounded batch and their Table
descriptors in a second batch. Both require the same current revision and native
grants. The second batch replaces the first after definitions are validated and
copied into the owned page; no metadata observation survives the call.

Shared neutral conversion types represent object/revision/operation IDs as
canonical decimal strings. `Bridge.Definition` retains scope, name, typed Table
source and creation attribution. `Bridge.Cursor` requires the current contract
definition, scope, native resource revision and last normalized name; decoding
cannot default a missing compatibility field. `Bridge.Page` owns eight optional
entries and an optional cursor. Conversion rejects holes, non-increasing names,
mixed scopes and continuation that does not match the last entry and revision.
The neutral `definition` result contains an optional `Bridge.Definition`; the
`page` result contains `Bridge.Page`. Missing records return null after current
authorization. Exact-definition reads do not revalidate the current live Table.
Changed cursor scope/revision or referenced definition/Table metadata returns a
conflict through the native ABI/port. A caller must not combine pages across
resource revisions or silently restart a failed continuation.

`Bridge.Receipt` and `Bridge.Disposition` each include a mandatory shared
`diagnostic`. Receipt projections identify the original operation, scope, name,
object, Table, native input and applied/rejected outcome. Input projections
identify their native input and payload commitment separately from a creation
receipt. The ABI, native port, CLI and all SDK status models retain these owned
values. They are disclosed only after current native and catalog read checks;
they never substitute a later catalog observation for a saved outcome or imply
that CREATE TABLE can be cancelled. Missing diagnostics in these neutral values
are incompatible with the current contract definition.

Resident work holds one native page, at most eight definitions, a configuration/
policy batch and at most one eight-key dependent batch. Private-turn sources use
their existing bounded point reads for definitions and Table descriptors. Durable names, definitions and
receipts live in paged KV state with no fixed total-cardinality array. Native
deployment quotas still govern accepted storage. Quota pressure does not authorize
expiry, silent truncation, adoption or loss of accepted receipts.

## Binary records

Every encoded value starts with ASCII `TCA1`, one tag byte, and the mandatory
32 decoded bytes of the current native contract definition. Decode checks this
header before reading the body, consumes complete input and validates the result.
Missing/truncated headers, foreign definitions, unknown tags, invalid enum/bool
values and trailing bytes reject. There is no fallback decoder or defaulted
persisted definition. This additive owner changes no existing native/ABI format.

Bodies use the public `Model` field order below. Integers are little-endian in
their stated width; booleans are one byte, zero or one. `scope` is realm u64,
resource u64, then catalog u64. A name is length u8 followed by those ASCII bytes. A schema is
length u8 followed by the existing `TBL1` descriptor; Table nullability and column
identities retain the fixed Table profile. Arrays have no host padding.

| Tag | Body fields, in order |
| --- | --- |
| `c` | Configuration: scope, owner u64, administrator u64 |
| `p` | Policy: scope, principal u64, revision u64, inspect bool, create bool |
| `q` | CreateTable request: scope, operation u64, object u64, table u32, name, schema |
| `d` | Definition: scope, object u64, revision u64, name, source tag u8 (`1` Table), Table ID u32, schema, principal u64, operation u64, input u64 |
| `n` | Binding: scope, object u64, revision u64, digest 32 bytes |
| `o` | Receipt: CreateTable body without an inner header, principal u64, input u64, outcome u8 (`1` applied, `2` name conflict, `3` object conflict, `4` Table conflict) |
| `g` | Policy control: expected revision u64, then the Policy body without an inner header |
| `e` | Input disposition: scope, origin u8 (`1` external, `2` process, `3` effect), principal u64 (zero for non-external input), input u64, frame digest 32 bytes, outcome u8 (`1` initialized, `2` policy applied, `3` invalid command, `4` denied, `5` identity conflict, `6` stale policy) |

The definition digest is SHA-256 of UTF-8
`transit.catalog.definition.v1` plus NUL plus the complete encoded `d` record.
Keys are `00 43` (NUL, `C`), catalog u64 big-endian and a tag byte. Name keys
append normalized name bytes without a length; other keys append two big-endian
u64 fields: configuration `(0,0)`, policy `(principal,0)`, definition
`(object,revision)`, receipt `(principal,operation)`, disposition `(input,0)`.
Policy-control commands are not stored as `g` keys. The disposition digest is
SHA-256 of UTF-8 `transit.catalog.input.v1` plus NUL plus the complete Station
frame bytes. A policy-control payload is 87 bytes and a disposition is 111 bytes.
Records also contain their
scope, so copying a record across resources/catalogs cannot change its meaning.
The maximum request is 138 bytes, definition 163 bytes and receipt 155 bytes,
within the existing 256-byte value and Station cast bounds. A name key is at most
27 bytes; no bound is increased.

The [independent fixtures](../packages/zig/transit-catalog/src/fixtures/catalog-v1.json)
pin exact layouts and full-width application IDs. Component and native evidence
are recorded separately in the [proof ledger](../tests/README.md); an in-memory
schedule does not establish disk recovery or native fencing.

## SQL console composition

The console's optional `writes.catalog` selects this client using the console's
transport and credential. CREATE TABLE validates the two-column adapter, assigns
operation/object/Table identities once, prepares the command and persists it
before submission. Admission, processed input and the attributed catalog outcome
remain separate. `.status` observes; `.resume` reconciles the original command.
There is no creation cancellation or implicit query/mutation policy. SHOW TABLES
and DESCRIBE use the bounded current-authorized inspection client. Console
configuration and private recovery are defined in the
[console guide](../apps/transit-cli/docs/console.md#writing-tables-and-catalogs).

## General Table metadata records

`TableMetadata` and `TableMetadataStore` provide immutable metadata for the
general Table schema representation. These are codec/storage helpers, not live
catalog name publication or a second signed-client compatibility profile.
The enclosing owner must stage the exact definition before publishing its
binding/outcome. The signed catalog methods above retain their separate admission
contracts until their coordinated current-definition cutover.

`TCM1` records contain the magic, mandatory raw shared definition (32 bytes),
scope (realm/resource/catalog:u64le), object:u64le, metadata revision:u64le,
name length:u8 and exact UTF-8 bytes, schema reference (record ID:u64le,
format:u32le, length:u32le, digest:32 bytes), full schema fingerprint:32 bytes,
principal:u64le, operation:u64le and admission input:u64le. Names have 1–255 bytes,
valid UTF-8 and no NUL. The maximum record size is 436 bytes. Trailing/truncated
data, foreign definitions, invalid names/IDs and invalid schema formats reject.
The schema record is an immutable `FTS1` within that object's Table namespace.
Loading it verifies its exact object and complete schema fingerprint; no newer
live schema substitutes for the recorded reference.

Metadata revisions, schema revisions and native resource revisions are distinct.
A name-only revision can share the schema reference. Principal/operation/admission
input identify the originating work and remain fixed while staging. They do not
assert that this metadata is live or that its admission input published a name.
The operation outcome separately records final publication. Returned names own
their bytes; loaded schemas have explicit allocator ownership.

Hashed name-index keys contain `00 43`, catalog:u64be, tag `N`, name digest prefix:13 bytes
and object:u64be. The digest is SHA-256 of `transit.catalog.name.v1\0` and exact
normalized name bytes. Its first 13 bytes select a bucket within the native
32-byte key limit. Equal prefixes retain distinct object-suffixed entries.
Resolution must compare stored names after checking scope and definition; hashes
are never equality proof. This key does not impose name-order listing semantics.

Metadata storage uses Publication domain 9 and namespace object. A 68-byte
manifest at tag `d`, ID/index zero contains `TCB1`, raw shared definition, scope
and object:u64le. Initialization verifies an existing exact manifest/quota or
proves the namespace empty before creating them. Orphans and scope drift reject.
The budget permits one staged record of at most 436 bytes; no total historical
record limit is imposed. Both initialization writes share the ordinary native
turn limit and roll back together on failure.

Records of at most 256 encoded bytes live directly under tag `i`, ID metadata
revision, index zero. Larger records use Publication's `r`/`c` records with format
`0x54434d01`. An exact reference commits format, length and Publication digest;
its length selects the representation. Changes at the same immutable revision
reject even when the new bytes would use a different representation. Published
large records obey the existing committed-cursor rule and staging quota release.
No storage helper publishes names, grants rights or performs physical historical
cleanup. The [component guide](../packages/zig/transit-catalog/docs/table-metadata.md)
defines ownership and the current integration boundary.

The general namespace's fixed control records use the same mandatory-definition
`TCA1` envelope and little-endian reflected field order. They have these tags:
`C` configuration (scope, owner, administrator, Table Publication limits);
`P` policy (scope, principal, revision, eight booleans in inspect/create/read/
insert/update/delete/alter/drop order); `O` current object; `R` DDL operation;
`N` name binding (scope, object); and `B` dependency (scope, object, dependency ID,
owner PID, kind). Fixed records remain within native 256-byte values: configuration
93 bytes, policy 85, object 182, operation 224 and dependency 86.

Object state distinguishes initializing, live and retired. It retains the current
metadata reference, monotonic next revision and exact pending principal/operation/
revision/digest. A cancelled initialization may leave a retired identity without
a live definition. Pending metadata revisions cannot be reused or assigned to
retired objects. DDL operation state separately distinguishes preparing,
delegated schema work, applied, unchanged, rejected and cancelled, retaining
scope, identities, request digest, metadata reference, delegated Table digest and
original admission/completion inputs. These records supply bounded composition;
their codecs alone do not authorize a lifecycle transition or establish that a
metadata candidate was accepted.

`TableCatalog` checks current configuration and applicable scoped policy for each
namespace call. Mutation controls additionally check authenticated external
origin, realm, configured PID/resource and administrator where required. Metadata
inspection is independent of data read/write and schema rights. Native authority
remains separately required. `lookup` resolves hash buckets by exact names and
validates the live head/schema. `list` scans at most one native object-record page,
returning at most eight owned definitions in object-ID order; its cursor binds
scope, native revision and last scanned object. A caller releases owned schemas
and pages explicitly. Partial native pages with continuations are not EOF.

Explicit dependency kinds are query source=1, writer=2, watch=3, maintained
relation=4 and history=5. The first four restrict removal; historical references
remain distinct from live-name admission and cleanup. Administrator registration
and exact-identity removal do not manufacture source grants or configure workers.
The `J` index uses the same object/dependency IDs and bytes as restricting `B`
records; both change atomically. History has no `J` entry. One native index page
and the matching original record expose an attributed blocker under current
inspect policy, without scanning history. These helper checks are not native lifecycle/DDL admission
until the enclosing owner wires its final Table/name/outcome publication.

The general `TableDdlRequest` helper fingerprints a length-delimited name and
exact scope/principal/operation/object/expected-metadata-revision, action tag and
action payload under `transit.catalog.ddl.v1\0` and the current definition.
CREATE contributes its schema fingerprint and IF NOT EXISTS flag; ALTER contributes
both original and successor schema fingerprints; RENAME contributes its exact new
name; DROP contributes IF EXISTS. Object-bound requests never re-resolve a saved
object by a reused name. An absent optional DROP remains bound to absence.

General DDL admission requires current inspect plus the action-specific right
and an authenticated matching external principal. A pending object reserves a
monotonic metadata revision and prevents new dependency installation. CREATE
publishes head, object, name binding and original operation in four writes.
RENAME deletes/installs bindings and publishes object/outcome in four writes.
DROP first checks explicit RESTRICT dependencies, then retires head/object,
deletes the name and publishes its outcome in four writes. Accepted historical
bytes and original operation receipts survive removal of the live name.

ALTER first reserves the object, then the Table head through `TableAlter`. Before
metadata staging it records the exact candidate reference; before driving the
rewrite it records a delegated operation with the immutable metadata reference
and Table request digest. Final publication consists of the three Table writes
(head, terminal Table receipt and progress deletion) plus the catalog object
update. Rejection/cancellation clears the object reservation in that same fourth
write. Catalog status derives a delegated terminal outcome from its retained
Table receipt; no fifth write or independent success marker is required. Early
cancellation before delegation first closes an admitted Table operation, then
closes the catalog reservation in a subsequent bounded decision.

Published metadata is historical evidence only when its original operation
matches scope/object/reference/admission input and was applied, including an
applied delegated Table receipt. Cleanup requires a closed unaccepted candidate,
checks its consumed revision against the current object, and leaves accepted
history, permanent identities and receipts intact. It uses bounded Publication
collection to release candidate staging quota. A cleanup call does not authorize
physical reclamation of accepted data or substitute for native read/commit grants.

## General typed command body

`TableCommand` supplies a pure command codec; the native enclosing owner still
performs authentication, current authorization, accepted-metadata resolution,
staging and fenced commit. Header inspection alone never admits work.

`TCQ1` uses a fixed 141-byte header: magic, raw shared definition (32 bytes),
realm/resource/catalog (u64 each), owner/principal/operation/object (u64 each),
metadata reference (id:u64, format:u32, length:u32, digest:32 bytes), and kind:u8.
Integers are little-endian. Kind codes are CREATE=1, ALTER=2, RENAME=3, DROP=4,
INSERT=5, UPDATE=6, DELETE=7. Only CREATE or DROP bound to absence uses an exactly
zero metadata reference; only the latter has object=0. Other commands bind an
accepted immutable metadata record. Missing/foreign definitions reject before
metadata or schema-dependent decoding. The envelope limit is the 141-byte header
plus the FDM1 envelope limit, 65,536 schema bytes and 512 bytes of bounded framing.

CREATE adds a u8-length UTF-8 name, IF NOT EXISTS:u8, then length:u32 and FTS1.
RENAME adds its new u8-length name. DROP adds IF EXISTS:u8; absent DROP also adds
the original u8-length name. Booleans are exactly 0 or 1. Bound RENAME/DROP names
come from the referenced metadata; a replacement live name is not consulted.

ALTER adds one explicit change tag: ADD=1, DROP=2, RENAME COLUMN=3, DEFAULT=4,
NULLABILITY=5, TYPE=6. ADD contains a u8-length name, u16-length FTY1 descriptor,
nullable:u8, character limit:u32 (zero means absent), default presence:u8 and,
when present, length:u32 plus bound cell bytes. DROP contains column ID:u64.
RENAME COLUMN contains column ID:u64 and the new u8-length name. DEFAULT contains
column ID:u64, presence:u8 and an optional length-prefixed bound cell under the
original column type. NULLABILITY contains column ID:u64 and nullable:u8. TYPE
contains column ID:u64, a u16-length descriptor and character limit:u32. The owner
rederives the pure transition; the caller cannot assert that no rewrite is needed.

DML uses the complete FDM1 payload under the exact original schema. The header's
kind must agree with its action. Decoding verifies metadata scope/object/revision/
commitment, original name and full schema fingerprint before interpreting typed
values. All decoded data is owned and released explicitly. Invalid lengths,
states, tags, values, trailing bytes and changed bindings reject before execution.

`commandBasis` resolves accepted historical metadata and its original schema
under current inspect and, for execution, action permission. A DROP followed by
name reuse cannot redirect a saved body to the replacement object.

## General command staging

`TableUpload` stages TCQ1 in Publication domain 4 with a caller-chosen nonzero
resource-global namespace and record ID 1. A namespace is never adopted from
orphan bytes or another principal/catalog. Its fixed quota admits one body of at
most the TCQ1 envelope limit; native resource quotas remain separately enforced.
This helper does not install the native behavior or caller transport by itself.

The retained `TCU1` status is 239 bytes: magic, complete TCQ1 header, namespace:u64,
body spec (format:u32, length:u32, digest:32), phase:u8, received:u32,
admission input:u64, application digest:32 and application route:u8. Integers are
little-endian. Phase codes are uploading=1, sealed=2, ready=3, cancelled=4.
Routes are unbound=0, catalog DDL=1, point DML=2, finite DML=3. Unbound digests
are exactly zero. Ready requires the entire body and its recomputed application
binding. The status key uses catalog tag `U`, namespace and zero revision; tag
`u` stores at most one 128-byte half-chunk.

Parts have contiguous offsets divisible by 128 and exactly the smaller of 128
or the remaining body length. Exact duplicates compare the retained half or
completed chunk; changed duplicates reject. Two parts compose each ordinary
256-byte Publication chunk. Completing a chunk uses at most four writes;
begin and seal use three. Seal publishes bytes without applying SQL. A later
committed read checks full body commitment, header and authorized schema, then
persists the recomputed application binding in a separate one-write decision.
This leaves all four native mutation slots available to subsequent SQL work.

`executeUploaded` admits or continues only the exact ready body retained from an
authenticated external upload. Process-origin admission requires the configured
owner PID and the committed upload binding; it never rewrites the original
principal. Current rights are rechecked. Terminal application receipts are read
before loading body bytes, so late continuations remain resolvable after body
collection. Cancellation of an unadmitted upload closes only transport; admitted
work uses its original catalog/Table coordinator. Collection requires cancelled
unadmitted transport or a terminal application receipt and preserves permanent
upload identity, body commitment, application reference and SQL receipts.

## General native owner controls

`TableControl` uses current-definition `TCA1` records within ordinary Station
cast frames. Command tags are initialize=`I`, conditional policy=`P`, dependency
registration/removal=`D`, cancel/cleanup DDL=`X`/`Y`, cancel/cleanup DML=`M`/`N`,
begin/part/seal upload=`B`/`A`/`S`, drive upload=`V`, and cancel/collect upload=
`K`/`G`. All control payloads fit the 243-byte Station frame payload limit.
Initialization contains the full general configuration. Policy contains expected
revision:u64 and policy. Dependency contains the dependency and present:boolean.
DDL controls contain scope, principal:u64, operation:u64 and digest:32; DML
controls contain scope and the complete TableWrite reference.

Upload begin contains the complete 141-byte TCQ1 header, namespace:u64 and body
spec. Other upload controls contain scope and namespace:u64. A part appends
offset:u32, length:u8 and 128 bytes, with mandatory zero padding beyond length.
Control integers use little-endian and booleans are exactly 0 or 1. No control
uses its supplied principal as authentication.

`TableBehavior` supplies GenServer guard, initializer and handler hooks. It accepts
inline TCQ1 bodies directly, schedules the exact body to itself while work is
pending, and routes larger bodies through their retained upload namespace. Seal
schedules binding; committed binding schedules execution. Successful point
publication adds neither an extra catalog receipt nor a fifth native write.
The first initializer, including the GenServer descriptor, uses four writes.
No per-Table process, resource or grant is created.

The owner records bounded input dispositions for malformed, denied, conflicting,
stale-policy and blocked inputs. Disposition tag `E` contains scope, origin:u8,
external principal:u64 (zero otherwise), input:u64, payload fingerprint:32 and
outcome:u8. Outcome codes are initialized=1, policy applied=2, dependency applied=
3, invalid command=4, denied=5, identity conflict=6, stale policy=7, blocked=8.
These records never substitute for a Table or DDL outcome. Denial stops automatic
continuations and preserves admitted work for explicit exact resume/cancel.
Native read failures and corrupted published evidence reject the private proposal;
they are not acknowledged as malformed user inputs. This behavior module still
requires deployment/caller integration before replacing the configured runtime.

## Saved typed intent

`TableIntent` owns an exact offline recovery record, separate from each signed
native send. `TCI1` contains magic, mandatory raw current definition (32 bytes),
upload namespace:u64, metadata length:u16, original schema length:u32 and command
length:u32, followed by those three byte sequences. Integers are little-endian.
The 54-byte prefix is followed by at most 436 metadata bytes, 65,536 schema bytes
and the bounded TCQ1 body. A nonzero namespace is retained even for an inline
command so its identity does not depend on a later transport choice.

Bound commands save the exact TCM1 metadata. ALTER and DML also save the original
FTS1 schema; CREATE already carries its schema and RENAME/DROP require no redundant
schema. Restoration verifies lengths, current definitions, exact metadata and
schema commitments, full typed intent, and canonical re-encoding. It derives the
original application digest and point/finite route without network access, SQL
recompilation or name lookup. Saved schemas never confer authority or replace the
owner's accepted-metadata check.

`matches` checks that a saved native payload belongs to the intent: the exact
inline body, matching upload header/spec/namespace, exact part offset/bytes, or
the original DDL/DML cancellation/cleanup reference. Signature authentication and
native send sequence recovery remain the signed client's responsibility. Neither
restoration nor a matching transport step establishes application admission.

`TableClient` is the signed general caller. `Prepared` retains mandatory current
definition, format version 1, exact connection and original signed native send.
Canonical JSON restoration is bounded to 8,192 bytes and owns every field. Submit
verifies the connection and signature and makes one transport attempt; it does
not look up a name, re-sign or retry. A separate TCI1 intent retains large bodies.
The caller persists both intent and each pending Prepared before sending it.

`next` checks current authorization and original outcomes, then prepares one
inline send or upload step. It returns running while automatic owner execution
is pending, terminal evidence when complete, or transport cancellation without
inventing an SQL receipt. `prepareResume` explicitly schedules the same body or
ready upload after a pause. It refuses an incomplete or cancelled upload.
Initialization/policy/dependency and exact cancellation/cleanup controls use the
same signed transport and current scoped owner checks.

`observe` checks the exact admitted input and owner mailbox progress. `progress`
then acquires its input disposition, original application outcome and upload
status at one current authorized resource cut. A terminal SQL result by itself
does not prove that a particular native send was processed. `waitObserve` and
`waitProgress` retain only a scheduling cursor for the exact signature/input,
use bounded change notification, and fall back to a fresh read after bounded
capacity backoff. They cache no permission or completion claim. Metadata lookup
and object-ordered listing return owned schemas/pages requiring explicit release.
