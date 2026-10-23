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
action, nullable delegation and transport authorization proof. A null delegation
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
delegation, its context is the delegation digest; the response's separate
`context` still binds the complete transport request. The node checks all successfully
used requirements again after buffering the complete response. Denial at this
boundary suppresses the response, even if a mutation has already committed.
Recover that mutation through its original operation binding.

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

### Delegated retained reads

`DirectReadDelegation.encode` retains the original grant in a canonical 309-byte
`TRG1` record. It contains the four-byte magic, mandatory 32-byte current
definition, connection scope (realm/resource/catalog), branch, audience,
principal, role-present byte and role value, executor, object ID, definition
revision and 32-byte digest, partition and accepted frontier, pin operation,
32-byte purpose, credential epoch, 32-byte claim context and 64-byte signature,
in that order. All integers are unsigned 64-bit little-endian except the
one-byte role flag. An absent role has flag/value zero. Object and pin scope,
pin principal and repeated claim fields must match the connection; decoding
reconstructs only these constrained duplicates. Missing, foreign, truncated,
noncanonical or context-inconsistent records reject. Loading performs no
acquisition and does not establish current authorization or verify an unknown
signer's public key. The data owner still checks the original signature and
current caller/executor credentials on every request.

`DirectReadDelegation` contains a `binding` and original-caller `proof`. The binding
fields, in canonical order, are the current `definition`, original `connection`,
`executor` principal, exact `interpretation`, `expected` Table frontier, pin
`owner` operation and nonzero 32-byte `purpose` commitment. Its signing context is
SHA-256 of `transit.table.read-delegation.v1`, a zero byte and canonical JSON of
that binding. The purpose identifies application-owned immutable work; it does
not establish honest computation or enforce a SQL predicate. This grants read
scope over one complete Table cut, with no additional object privileges.

The executor signs the entire request, including that retained delegation, with
its own current credential and login role. The request connection continues to
identify the original caller and selected role. The owner authenticates both
identities under the same native fence, checks the caller's current
CONNECT/USAGE/SELECT requirements and repeats both checks before disclosure or
pin publication. The executor needs no raw catalog or Table grant. Changing or
revoking either credential prevents use of the affected proof. Accepted work
retains the original delegation; recovery cannot replace its caller signature
or credential epoch implicitly.

Delegation permits only `pin`, `pin_status`, `snapshot`, `scan`, `release` and
snapshot-only `check_set` for the bound object and pin owner. It permits no name
discovery, mutations, policy changes or further delegation. The first pin also
checks the exact definition and frontier. A stale acquisition rejects; it never
chooses newer data. An existing pin can be recovered after the current Table
evolves, provided its retained definition/frontier still match and current rights
allow disclosure. Release is terminal and requires current rights. Lost replies
use the same acquisition and the existing `pin_status` recovery rules below.

`DirectReadDelegation.prepare` signs this binding as the original caller without
acquiring a pin. A `DirectTableClient` with `delegation` set uses its key as the
named executor's key; it preserves the original connection and never signs as
that caller. Its response checks bind retained schemas and data frontiers to the
delegation. The `delegation` request field is mandatory even when null; the
replaced shared definition rejects previous envelopes without a fallback.

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

`pin` binds the original principal and exact expected Table frontier to a
durable read root. `snapshot` returns its retained interpretation, schema,
accepted frontier, logical-change frontier and row count. `scan` returns up to
eight owned rows under an explicit encoded-byte budget, with a cursor bound to
that retained root and its last returned canonical 20-byte row identity. Rows
are strictly increasing by identity, independent of their current physical
locators. It never substitutes the latest name or definition.
`release` records terminal pin release through reserved control capacity.
Current CONNECT/USAGE/SELECT rights apply to every operation, including release.

`pin_status` reads the original owner's handle, release state, current physical
frontier and Table retirement state. It acquires nothing. Absence at a later
frontier or after retirement proves the old exact-frontier acquisition cannot
subsequently succeed. Absence at the original frontier remains unresolved;
recovery may repeat only that original acquisition before releasing it.

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
