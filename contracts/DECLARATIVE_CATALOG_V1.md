# Declarative catalog v1

`transit-catalog` owns named state definitions above Station. Its supplied Zig
helper creates an empty Table and publishes its definition, name binding and
operation receipt in one resource turn. Native authority still validates current
grants, ownership, fencing and atomic commit. This is an explicit application
integration API with shared Zig/C ABI/native-port callers and an explicit
`catalog` role in `transit-query-host`. The explicit
[catalog CLI](../apps/transit-cli/docs/catalog.md) composes the same caller.
SQL query transports and idiomatic language SDKs expose no catalog administration route.

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

Resident work holds one native page, at most eight definitions and bounded point
reads for those definitions and Table descriptors. Durable names, definitions and
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
