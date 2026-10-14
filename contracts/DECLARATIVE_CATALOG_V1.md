# Declarative catalog v1

The catalog owns general typed Table names, immutable schema metadata, DDL and
DML routing above Station. `TableCatalog`, `TableBehavior` and `TableClient`
implement one current contract. SQL, the console, the explicit catalog CLI,
the native ABI/port and enabled SDK callers share its typed intents and outcomes.
The [Table schema](TABLE_SCHEMA_V1.md), [data](TABLE_DATA_V1.md),
[DDL](TABLE_DDL_V1.md) and [DML](TABLE_DML_V1.md) contracts own their respective
value and transition semantics. Query owners use the accepted metadata commitment
specified in [catalog query ownership](CATALOG_QUERY_OWNER_V1.md).

## Identity and ownership

A scope is a native realm and resource plus a nonzero full-width catalog ID.
Object, column, row, operation, metadata revision and schema revision identities
are distinct. Names resolve objects; they do not grant authority. Renaming
preserves identity. Dropping and recreating a name never rebinds an accepted
operation, prepared plan or retained schema reference to the replacement.

The configured owner has a native PID, resource association and current execution
grant. CREATE allocates Table records within that resource; it creates no native
resource, process or grant. Durable collection sizes are independent of resident
pages and per-operation limits. All accepted histories and receipts have unlimited
retention unless an owning contract explicitly permits collection.

## Initialization and authorization

Configuration binds scope, worker PID, bootstrap principal, explicit Publication
limits and six native authorization identities: database/schema/Table domains,
database object, initial schema ID and its authorization object. Initialization
requires database ownership and exact native bindings. It rejects orphan state
and records configuration, the initial `public` schema, framework descriptor and
input disposition in one four-write decision. Repetition cannot restore grants.

Every operation requires database CONNECT and schema USAGE. CREATE additionally
requires schema CREATE. Table data operations require SELECT, INSERT, UPDATE or
DELETE; ALTER/DROP require native role ownership. Metadata is visible to an owner
or a role with an applicable Table privilege. Current checks use the original
subject's credential epoch and selected role, including continuations and final
native publication. A supplied principal number is not authentication. Native
process/resource capabilities remain separate requirements for infrastructure.
There is no catalog-local permission record or control. Dependency registrations
remain explicit catalog operations. See [authorization](AUTHORIZATION_V1.md).

Restricted readers use the trusted Table service with an independently signed
original subject. Its private raw-resource credentials are not caller rights.
Direct readers need explicit raw-resource authority; Table grants never imply it.

## Conditional Table creation

CREATE accepts the shared general schema, typed defaults and declared keys.
Omitted nullability is nullable; a primary key implies NOT NULL. Tables without
one use stable hidden row identities and preserve duplicates. CREATE reserves a
fresh permanent object identity, stages its schema/metadata and atomically
publishes head, object, name binding and original operation outcome. A failed or
cancelled candidate never becomes a partial live Table.

`IF NOT EXISTS` reports unchanged when a name already exists; it does not adopt
or verify equality with the existing schema. Name and object conflicts retain
the original outcome. ALTER, RENAME and DROP use the same coordinator and exact
saved identity; their bounded publication rules appear below.

## Signed Zig caller

`TableClient` prepares signed commands, submits one transport attempt, reads
metadata and recovers exact saved work. The caller persists both its `TableIntent`
and each `Prepared` send before submission. Admission, mailbox processing and
terminal Table execution are separate observations. An uncertain send is retried
with its exact signature and sequence. Accepted work is never recompiled or
re-signed against a newer schema to manufacture a successful retry.

Current inspection permission gates original status and cancellation. Execution
revocation pauses accepted work without deleting it. Explicit resume rechecks
the original principal's current action rights. Cancellation closes unpublished
work; it cannot undo an applied operation or claim physical erasure.

## Neutral caller values

`TableValues`, `TableTyped` and `TableBridge` own the shared neutral interface.
Full-width identities and counts use canonical decimal strings. Native counters
retain their native exact bounds. Recursive logical descriptors and cells preserve
typed values, NULL and defaults. Mandatory current definitions are validated on
schemas, references, saved intents and signed envelopes before execution.
The generated binding schemas supply the complete action/result structures.

## Supplied catalog behavior and host

`transit-query-host` composes the catalog role from `TableBehavior` and its exact
configuration. Provisioning, activation, native ownership and resource association
precede initialization. Each dispatch validates configuration and authenticated
origin. Continuations accept only the configured owner's native process input
and refer to already recorded external intent; supplied principal numbers never
become authentication.

Pending work records an exact self-message. The authorized delivery courier
moves it to the process input; a courier outage preserves that output and the
Table reservation. Infrastructure failures and corrupt retained evidence reject
the whole private proposal. Input dispositions describe malformed or denied
commands separately from original DDL/DML outcomes.

## Inspection and bounded pages

`lookup` validates current inspect policy, exact name, accepted metadata and live
head, returning an owned schema. `definition(object, revision)` reads an accepted
historical definition under current rights without attaching a current head.
Candidates without an applied original receipt are not accepted history.

`list` returns at most eight inline metadata/head summaries in object order.
Its cursor binds scope, exact native resource revision and last scanned object.
Retired or initializing objects advance the scan without appearing as live
Tables. Authorization precedes cursor use. A changed cut requires restarting the
listing; callers cannot concatenate pages from different cuts. Listing does not
acquire schemas or rows. Lookup and historical schema owners require `deinit`.

## Binary records

Catalog control records start with `TCA1`, their tag and the mandatory 32-byte
current shared definition. Integers are little-endian, booleans exactly 0/1,
and reflected records have no host padding. Decoding consumes the entire input;
foreign definitions, invalid enums, truncated fields and trailing bytes reject.
There is no fixed two-column decoder or parallel catalog profile.

Ordinary keys begin with `00 43`, catalog:u64be and a tag, followed by two u64be
identity fields. Hashed name keys and metadata Publication keys are specified
below. The disposition fingerprint is SHA-256 of
`transit.catalog.input.v1\0` and the complete Station input frame.
Independent [metadata and control fixtures](../packages/zig/transit-catalog/src/fixtures/table-metadata.json)
pin the current bytes. Executed evidence belongs in the
[proof ledger](../tests/README.md).

## SQL console composition

Within the configured catalog and current permissions, CREATE makes a Table
available to supported SELECT and DML through the existing owner. SHOW TABLES
and DESCRIBE use the shared inspection client. `.status` observes saved work,
`.resume` reconciles it, and `.cancel` requests original-operation cancellation.
The [console guide](../apps/transit-cli/docs/console.md#writing-tables-and-catalogs)
owns connection and recovery-file details.

## General Table metadata records

`TableMetadata` and `TableMetadataStore` provide immutable metadata for the
general Table schema representation. The catalog stages the exact definition before publishing its
binding and outcome; codecs alone do not establish acceptance.

`TCM1` records contain the magic, mandatory raw shared definition (32 bytes),
scope (realm/resource/catalog:u64le), object:u64le, schema namespace:u64le, metadata revision:u64le,
name length:u8 and exact UTF-8 bytes, schema reference (record ID:u64le,
format:u32le, length:u32le, digest:32 bytes), full schema fingerprint:32 bytes,
principal:u64le, operation:u64le and admission input:u64le. Names have 1–255 bytes,
valid UTF-8 and no NUL. The maximum record size is 444 bytes. Trailing/truncated
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
schema namespace:u64le followed by normalized name bytes. Its first 13 bytes select a bucket within the native
32-byte key limit. Equal prefixes retain distinct object-suffixed entries.
Resolution must compare stored names after checking scope and definition; hashes
are never equality proof. This key does not impose name-order listing semantics.

Metadata storage uses Publication domain 9 and namespace object. A 68-byte
manifest at tag `d`, ID/index zero contains `TCB1`, raw shared definition, scope
and object:u64le. Initialization verifies an existing exact manifest/quota or
proves the namespace empty before creating them. Orphans and scope drift reject.
The budget permits one staged record of at most 444 bytes; no total historical
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
`C` configuration (scope, owner, bootstrap principal, Table Publication limits,
authorization profile); `S` schema (scope, ID, authorization ID, length-prefixed
63-byte name storage, revision, retired flag); `O` current object, including
schema namespace and native authorization ID; `R` DDL operation;
`N` name binding (scope, object); and `B` dependency (scope, object, dependency ID,
owner PID, kind). Fixed records remain within native 256-byte values: configuration
141 bytes, object 198 and dependency 86. Operations occupy 233 bytes without a blocker
or 250 bytes with an attributed RESTRICT blocker.

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
returning at most eight inline metadata/head entries in object-ID order; its
cursor binds scope, native revision and last scanned object. Listing validates
each live identity without reading schema defaults or row data. Lookup returns an
owned schema that the caller releases explicitly. Partial native pages with
continuations are not EOF.

Explicit dependency kinds are query source=1, writer=2, watch=3, maintained
relation=4 and history=5. The first four restrict removal; historical references
remain distinct from live-name admission and cleanup. Administrator registration
and exact-identity removal do not manufacture source grants or configure workers.
The `J` index uses the same object/dependency IDs and bytes as restricting `B`
records; both change atomically. History has no `J` entry. One native index page
and the matching original record expose an attributed blocker under current
inspect policy, without scanning history. The enclosing owner includes this
check in the final Table/name/outcome publication.

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

`TCQ1` uses a fixed 149-byte header: magic, raw shared definition (32 bytes),
realm/resource/catalog (u64 each), owner/principal/operation/object/namespace (u64 each),
metadata reference (id:u64, format:u32, length:u32, digest:32 bytes), and kind:u8.
Integers are little-endian. Kind codes are CREATE=1, ALTER=2, RENAME=3, DROP=4,
INSERT=5, UPDATE=6, DELETE=7. Only CREATE or DROP bound to absence uses an exactly
zero metadata reference; only the latter has object=0. Other commands bind an
accepted immutable metadata record. Missing/foreign definitions reject before
metadata or schema-dependent decoding. The envelope limit is the 149-byte header
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

DML embeds the shared action/predicate payload from FDM1 under the exact original
schema. The enclosing metadata commitment supplies the full schema fingerprint
and original name, so their standalone FDM1 envelope is omitted. The header's
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

The retained `TCU1` status is 247 bytes: magic, complete TCQ1 header, namespace:u64,
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
cast frames. Command tags are initialize=`I`, dependency
registration/removal=`D`, cancel/cleanup DDL=`X`/`Y`, cancel/cleanup DML=`M`/`N`,
begin/part/seal upload=`B`/`A`/`S`, drive upload=`V`, and cancel/collect upload=
`K`/`G`. All control payloads fit the 243-byte Station frame payload limit.
Initialization contains the full general configuration. Dependency contains the dependency and present:boolean.
DDL controls contain scope, principal:u64, operation:u64 and digest:32; DML
controls contain scope and the complete TableWrite reference.

Upload begin contains the complete 149-byte TCQ1 header, namespace:u64 and body
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

Self-messages are recorded outputs and require the standard authorized native
delivery courier to become process inputs. GenServer does not deliver its own
outputs or manufacture a courier grant. Deployments run that existing delivery
service; pauses/outages preserve the pending output and original Table work.

The owner records bounded input dispositions for malformed, denied, conflicting,
stale-policy and blocked inputs. Disposition tag `E` contains scope, origin:u8,
external principal:u64 (zero otherwise), input:u64, payload fingerprint:32 and
outcome:u8. Outcome codes are initialized=1, policy applied=2, dependency applied=
3, invalid command=4, denied=5, identity conflict=6, stale policy=7, blocked=8.
These records never substitute for a Table or DDL outcome. Denial stops automatic
continuations and preserves admitted work for explicit exact resume/cancel.
Native read failures and corrupted published evidence reject the private proposal;
they are not acknowledged as malformed user inputs.

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
Initialization/dependency and exact cancellation/cleanup controls use the
same signed transport and current scoped owner checks.

`observe` checks the exact admitted input and owner mailbox progress. `progress`
then acquires its input disposition, original application outcome and upload
status at one current authorized resource cut. A terminal SQL result by itself
does not prove that a particular native send was processed. `waitObserve` and
`waitProgress` retain only a scheduling cursor for the exact signature/input,
use bounded change notification, and fall back to a fresh read after bounded
capacity backoff. They cache no permission or completion claim. Metadata lookup
returns an owned schema requiring explicit release. Object-ordered listing
returns an inline page of metadata/head entries without acquiring schema or rows.

## General neutral session values

`TableBridge.Action/Result` and `TableValues` define the general caller boundary
as typed Zig values. Its [component contract](../packages/zig/transit-catalog/docs/table-metadata.md#neutral-general-table-callers)
owns action semantics, allocation, framing budgets and exact recovery. The
native ABI/port and enabled SDK callers use these values through the shared
session; their generated schemas enforce the same boundary.

`compile` lowers SQL and `prepare` lowers a `TableTyped.Request` to the same TCI1
intent. Typed requests require the current definition, canonical decimal-string
operation and namespace, exact Table name and one action. CREATE carries the
[neutral schema](TABLE_SCHEMA_V1.md); ALTER/rename/DML carry an object, metadata
revision and schema fingerprint. DROP additionally permits an explicitly absent
basis with IF EXISTS. Column assignments and predicate atoms refer to stable
decimal-string column IDs and use shared logical cells/atoms. No neutral action
changes the storage, scalar comparison or schema conversion admission rules.

A saved intent is `{definition, bytes}` with mandatory current definition and
canonical lowercase hex TCI1. Its small reference is `{definition, digest}`,
where `digest` is lowercase SHA-256 of the domain bytes
`transit.catalog.saved-intent.v1\0` followed by the complete TCI1 bytes. This
commitment identifies local loaded content; it is neither authority nor a native
operation signature. The session retains at most one intent. Loading/replacing
it performs no remote mutation and cannot settle an uncertain prepared send.

`next`, `status`, explicit resume/control preparation and progress use that
reference. `submit` takes the original saved signed step independently of the
active intent. Returned native receipts, input observations/dispositions, upload
state and terminal SQL outcomes remain separate. Rejected/cancelled DML has no
successful row counts; applied DML returns exact matched/changed decimal strings.
Outcome diagnostics validate against the original loaded intent, preserving
original identities across ALTER, DROP and name reuse.
