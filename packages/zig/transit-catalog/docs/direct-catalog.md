# Direct catalog owner

`DirectCatalog` provides an internal lifecycle owner for Table definitions and
names. It accepts complete frozen DDL work into a control log, then publishes
the definition through the Table's acceptance log. The local node exposes this
owner through its optional `table` setting and signed `/table/v1` route. The
default launcher and shared SQL runtime use this direct owner. Complete
captured-source and SDK migration remain unfinished. This owner has no automatic
execution scheduler.

The [direct request contract](../../../../contracts/DIRECT_TABLE_V1.md) defines
signed declaration, row-operation and retained-read envelopes. Its node
dispatcher calls this owner with current native policy and rechecks disclosed
requirements after response buffering. The SQL coordinator dispatches exact
retained references through this same owner.

`DirectTableClient.signed` binds a typed action to the caller's current native
credential; `call` makes one owned HTTP exchange and validates the response
against that exact request. It checks result kind, operation attribution,
definition/schema identity, counts, cursor progress and binary page budgets.
It does not retry a mutation, renew a pin or settle work implicitly. This client
uses the configured local node route.

The `observe` action reads an exact current interpretation and optionally its
first bounded row page. It returns definition, data position, row count and
checked native authority references together. It requires current SELECT even
without rows. `DirectCatalog.observe` and `TablePartition.observeRows` write no
operation or pin; returned rows own their memory. A partial page has `more`,
without a continuation. Use a durable pin for a traversal spanning requests.
The [current-observation contract](../../../../contracts/DIRECT_TABLE_V1.md#current-observations)
defines budgets, rejection and disclosure checks.

`closeOriginalPin` explicitly reconciles an original acquisition or release with
an uncertain reply. Persist the decision to close before calling it, and retain
that record until success. It uses at most three exchanges: status, exact original
acquisition if needed, and release. A later frontier proves that an absent pin
cannot still be acquired; at the original frontier, acquisition plus release
establishes a terminal pin record. Current denial or unavailable storage leaves
cleanup pending. This operation does not decide whether work has finished or
whether a restart permits cleanup; the caller owns that lifecycle decision.

For explicitly delegated reads, the original caller prepares a
`DirectReadDelegation` naming one executor, exact Table definition/frontier and
pin owner. It acquires nothing. The executor sets that delegation on its
`DirectTableClient` and supplies its own key while preserving the original
connection. Only the bound pin's acquisition, recovery, reads, checks and release
are permitted. Both credentials and the original caller's current Table rights
are fenced by native authority. A worker credential supplies no missing source
permission. Retained delegation bytes are immutable recovery evidence; a revoked
caller proof cannot be replaced implicitly. See the
[delegated-read contract](../../../../contracts/DIRECT_TABLE_V1.md#delegated-retained-reads)
for exact scope and signing contexts. Captured-query integration must retain that
binding through its own admission and cleanup journal.

`DirectAuthorizationSql.compile` resolves role, membership, grant/revoke,
default-privilege and ownership statements through this direct catalog and the
native authorization client. It returns the shared `AuthorizationSql.Plan` for
explicit native preparation/publication. The caller's CONNECT, USAGE and Table
metadata rights govern name resolution; an administrator role alone does not
grant data discovery. Names become stable native object references before the
plan leaves the compiler. Every lookup must agree on the policy revision, and
publication retains that revision as its precondition. SET/RESET ROLE returns a
checked selection without changing a session.

Compilation admits no Table work and publishes no policy. It allows 128 service
or native read operations by default; `Limits.requests` changes this per-call
budget without limiting durable namespace count. Namespace traversal retains at
most one page and rejects a changed directory position. CREATE, RENAME and DROP
SCHEMA are rejected by this direct compiler until its namespace owner exposes
those lifecycle operations. The SQL console does not dispatch these
administrative statements.

`DirectTableProtocol.Ddl.digest` computes the same canonical intent digest used
by admission; decoded child values belong to the supplied request arena.
`DirectTableReader.open` inspects an existing durable pin and owns its original
schema. Keep the pin handle separately while opening: a failed inspection does
not release the pin. `next` checks every page against the exact retained
interpretation, accepted/logical-change positions and total row count, then
decodes all rows under that original schema. It checks strictly increasing row
identities across pages and binds the continuation to the last returned identity.
Failed requests or decodes leave
the cursor unchanged. Returned batches own their values independently of the
reader. Completion requires exact source consumption; it establishes no completed
query result or consistent cut across independently retained Tables.

`readAfter` seeks an ordered suffix on the retained identity index without
changing sequential coverage. `readKey` performs a collision-checked lookup with
the retained schema's physical storage key and returns one owned row or absence.
For keyed Tables, encode the complete key with `Collation.encodePrimaryKeySortKey`;
keyless Tables use the canonical row identity. The reader validates exact source
attribution and the returned row's actual key. Neither operation advances `next`'s
cursor or establishes complete Table consumption.

Before disclosing a result computed from cached rows, call the reader's `check`
to recheck current rights and source attribution. Reading beyond the end also
rechecks rights before returning no batch. The reader remains bound to its
original connection and principal. `release` explicitly releases the original
pin and can be repeated after an uncertain reply; `deinit` frees only local
memory. There is no implicit renewal, replacement cut or remote cleanup.

## Identity, admission and publication

`DirectTableProtocol.Statement` binds a complete typed Fuze UPDATE/DELETE plan
to an immutable definition and a required data frontier. `admit_statement` uses
the same Table admission, outcome and cancellation directories as concrete row
batches. Execution selects privately under the action privilege, preserving row
identity and committing one complete successor. It never loads the whole Table
into the caller or requests SELECT on its behalf. INSERT uses `Rows` with exact
operation-derived identities and a point/bulk ingestion choice. The
[wire contract](../../../../contracts/DIRECT_TABLE_V1.md) defines binary payloads,
digest binding, collation restrictions and statement work limits.

`preview` performs read-only DDL checks through the same policy and expectation
rules as admission. It reports current independently observed directory/Table
positions, conflicts and metadata/validation/rewrite work, with the proposed
schema fingerprint. It does not claim the operation identity, stage an intent,
reserve a name, provision native authority or publish a declaration. Existing
identity claims must still match. Row-dependent constraints and final permission
checks remain execution work; preview cannot promise their later success.

The configuration fixes one catalog, branch one, its native authorization
profile and an exclusive control partition. Each reserved Table receives a
distinct partition above that control partition. The service must reserve this
partition range for this catalog. Multiple catalog allocators cannot share it.
The control and data log/object handles must address the same physical namespace;
separate handles classify quota use, rather than create independent storage.

An operation binds the original principal, operation ID, object, definition/data
expectations and canonical intent. `OperationBinding` prevents reuse against a
different target. `admit` stores the complete request and its name reservation
before returning an admitted record. That record publishes no Table. `perform`
uses the retained request; it never resolves the current name again.

A name resolves only when the target's accepted, non-retired declaration contains
that namespace and name. CREATE, RENAME and DROP therefore become visible at
their Table acceptance record, without a second catalog visibility decision.
Cancelled CREATE reservations free the name but retain the allocated object
identity. Recreating the name requires another object and partition.

CREATE freezes the requested owner role, without requiring a native registration
ID in the user's intent. Admission reserves the object and partition first.
`registration` inspects the required native action and the policy revision checked
for the original caller. The service registrar submits it through existing signed
native administration. `AuthorizationClient.registrationAt` preserves that
checked revision; it refuses to prepare work under a later policy basis. Native
BEGIN and candidate publication enforce the policy precondition.

`attachRegistration` verifies the accepted native binding and records the Table's
initial declaration under the reserved partition. This advances CREATE from
`admitted` to `ready`; both are pending states. Neither records a successful
Table outcome. A lost attachment reply recovers that same declaration. Cancelling
before registration still records a terminal operation and frees the name. A
native object already created by interrupted work remains retained; cancellation
does not silently retire an independently accepted native identity.

The node's internal `LocalCatalogRunner` composes these operations with the
public native registration helper. An explicit run performs a bounded number
of native steps and then attaches and accepts the Table when ready. It rechecks
the original caller after preparing each native candidate, including resource
retirement. Native publication compares that candidate's original authority
position; the runner does not reprepare behind the check. Lost replies resume
through the native registration ledger. The local node calls it for explicit
execution requests; no background scheduler invokes it.

`status` inspects actual Table evidence before returning a pending catalog phase.
After a lost reply, it returns the original accepted definition and result even
if the Table has since changed or retired. `cancel` returns committed evidence
when cancellation is too late. `settle` explicitly removes completed work from
the pending directory; it does not publish the Table or change its outcome.
Inspection alone performs none of these transitions.

`assertName` owns conditional outcomes that require no Table mutation. The
binding freezes either an exact existing definition for CREATE IF NOT EXISTS or
an absent name for DROP IF EXISTS, with a commitment to the complete proposed
declaration. Its `inspect` command admits no work. `accept` serializes the final
condition check and catalog record, returning unchanged or rejected; `cancel`
records cancellation only if no prior terminal outcome exists. Every outcome
retains its catalog position and current native authorization requirements.
This path never advances a Table frontier. A later rename, drop or name reuse
does not redirect retries. A condition that changes before acceptance rejects
instead of switching to a Table mutation.

Known constraint or expectation failures can become durable rejection records.
Storage failure and uncertain append do not prove rejection. The owner recovers
accepted history before further work and rejects a terminal operation that
reappears as pending. Missing admitted intent is unavailable evidence: the owner
does not replace it with a new request or infer cancellation.

## Authorization and concurrency

`inspectNamespace` returns current namespace metadata under CONNECT/USAGE.
`checkAccess` validates current action rights against an exact Table definition
without provisioning, admission, a read pin or raw resource access. The signed
client exposes it as `require` and returns the verified native subject. This
supports preparing an UPDATE without granting SELECT on its private selection.
`DirectTableBinding` retains immutable interpretation and caller scope; ordinary
row progress leaves it valid, while alteration, retirement and replacement do
not silently change its target. A retained binding carries no permission.

The service supplies independently allocated guards backed by current native
authority. Guards verify the configured database/schema/Table registrations,
CONNECT, USAGE and the requested privilege or ownership. CREATE also requires
ownership of a registered target and the ability to select the frozen owner
role. Registration is a separate native operation after admission; these
callbacks cannot grant authority or manufacture a native identity.

The caller serializes catalog directory, DDL and admission methods. It also
serializes each Table owner and coordinates row admission with pending DDL.
Independent row operations publish their own partition records without a
catalog-root update. No distributed writer or cross-owner transaction contract
is implemented here. Use request-bound signed subjects at a transport boundary;
the injected policy in the component tests is not a native authorization proof.

`list` reads at most eight directory entries per call. It checks each included
Table and rechecks their combined rights before returning metadata. Filtered
pages can be empty and still have a continuation. Its directory position and
Table positions are independent observations, not a consistent catalog snapshot.
Retained Table snapshots use the storage owner's separate durable-pin operations.

`pinRows`, `pinState`, `snapshotDefinition`, `readRow`, `scanRows` and `releaseRows` expose those
operations through the same native policy owner. A pin belongs to its original
principal; its handle does not grant access. Each read requires current CONNECT,
USAGE and SELECT and retains its original schema after Table alteration or
retirement. Row pages return owned values under separate row/byte limits and
recheck authorization after buffering. Explicit release uses reserved control
capacity. Pin status observes the original acquisition without creating another
snapshot. The direct HTTP dispatcher calls these methods.

`check_set` validates up to sixteen access/snapshot requests under one final
current authorization check. The local dispatcher excludes definition/data
mutations while checking that set. It exposes no rows and establishes no common
data frontier. Relational reads use it before disclosing results, including
empty inputs. `namespaces` traverses the paged schema directory, filtering current
USAGE rights and rechecking every returned schema together before disclosure.

## Bounds and remaining integration

`DirectTablePreparedDml.prepare` and `bind` use current public metadata and
action rights. Binding returns a `DirectTableIntent` that independently owns
the typed payload, original connection and exact operation expectations.
`DirectTableIntent.fromDml` also lowers an already typed Fuze plan without I/O.
Save its complete bytes before admission; `restore` validates those bytes
without resolving a name or executing work. `admit` and `operation` keep
admission, execution, inspection and cancellation explicit. Template destruction
does not invalidate bound work, and restoring work does not renew its basis.

`DirectTableIntent.stage` stores that work directly and returns a small immutable
reference for an orchestrator's control ledger. Staging leaves operation and
Table state unchanged. `Reference.admit` verifies current rights and the retained
bytes before calling the ordinary acceptance owner. `DirectTableIntentStore` is
the internal content verifier; it supplies no authorization by itself. References
cannot fetch payloads or replace unavailable bytes with freshly compiled work.

Directories and operation indexes use immutable B-tree pages. The default cache
holds 16 pages; tests also use one. The default private index-work allowance is
64 MiB per operation. Canonical request objects are bounded to 4 MiB and control
records to 16 KiB. These limits bound one operation and resident work, not the
number of durable Tables or operations. All accepted history and objects remain
retained; this owner supplies no collector.

`admitRows`, `performRows`, `rowStatus` and `cancelRows` use the Table's durable
operation records under current native rights. `applyRows` composes admission
and execution for callers that want both. The request includes the original
stored declaration and concrete rows; execution never re-resolves its name.
Row admission blocks while DDL is pending; DDL admission rejects while the Table
has pending row work. Neither row admission nor its outcome changes the catalog
directory root. Terminal row controls use the configured control quota handles.

Schema lifecycle beyond the initial namespace, dependency RESTRICT, captured
queries, language SDK adapters and automatic service scheduling remain unfinished.
The [Table storage owner](../../transit-storage/docs/table-partitions.md) defines
row/DDL acceptance, rewrite and pin behavior. The
[data lifecycle contract](../../../../contracts/DATA_LIFECYCLE_V1.md#direct-catalog-publication-contract)
defines the publication boundary; the [proof ledger](../../../../tests/README.md)
records executed tests and their limits.

## Retained logical history

`DirectCatalog.retainHistory` acquires an exact-frontier history lease. Its
`history` pages enumerate accepted logical operations under a fixed upper bound,
including no-op statements. Each entry retains the original receipt, definition,
logical-change frontier and complete WAL-record commitment. Budgets limit physical
frames visited, so empty pages can advance over pin, flush and admission records.
`historyDefinition` and `scanHistory` reopen the selected cut under current rights.

The signed service exposes `retain_history`, `history_start`, `history`,
`history_source` and `history_scan`. A delegated caller must explicitly sign
`history` retention; an ordinary snapshot grant cannot follow successors. The
initial lease still binds the exact original definition/frontier and pin owner.
The service verifies both that initial scope and each requested historical point.
It follows object identity through definition changes; clients inspect the
returned schema and retirement flag before continuing their computations.

`DirectTableReader.openHistoryStart` opens the original cut, and `openHistory`
opens a saved `Historical` point. Both use the ordinary bounded `next`, `readAfter`
and `check` methods. Historical cursors bind the lease, frontier and acceptance
record digest; a cursor from another revision rejects. Historical key lookup is
unsupported. Local destruction releases only local memory. Explicit `release`
closes the whole history lease; `closeOriginalHistory` reconciles uncertain
acquisition/closure without choosing another cut. A delegated cleanup proof
permits only original acquisition, status and release, never history disclosure.
These methods supply retention and source traversal; maintained-query scheduling
and publication remain separate owners.
