# Direct catalog owner

`DirectCatalog` provides an internal lifecycle owner for Table definitions and
names. It accepts complete frozen DDL work into a control log, then publishes
the definition through the Table's acceptance log. The installed Table service
and SQL callers still use `TableCatalog`; this component has no public transport
or automatic service scheduling.

The [direct request contract](../../../../contracts/DIRECT_TABLE_V1.md) defines
signed declaration, row-operation and retained-read envelopes. Its node
dispatcher calls this owner with current native policy and rechecks disclosed
requirements after response buffering. Installed HTTP/SQL callers do not use
that dispatcher yet.

## Identity, admission and publication

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
through the native registration ledger. This runner is not yet connected to an
installed HTTP route or background scheduler.

`status` inspects actual Table evidence before returning a pending catalog phase.
After a lost reply, it returns the original accepted definition and result even
if the Table has since changed or retired. `cancel` returns committed evidence
when cancellation is too late. `settle` explicitly removes completed work from
the pending directory; it does not publish the Table or change its outcome.
Inspection alone performs none of these transitions.

Known constraint or expectation failures can become durable rejection records.
Storage failure and uncertain append do not prove rejection. The owner recovers
accepted history before further work and rejects a terminal operation that
reappears as pending. Missing admitted intent is unavailable evidence: the owner
does not replace it with a new request or infer cancellation.

## Authorization and concurrency

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

`pinRows`, `snapshotDefinition`, `scanRows` and `releaseRows` expose those
operations through the same native policy owner. A pin belongs to its original
principal; its handle does not grant access. Each read requires current CONNECT,
USAGE and SELECT and retains its original schema after Table alteration or
retirement. Row pages return owned values under separate row/byte limits and
recheck authorization after buffering. Explicit release uses reserved control
capacity. Installed HTTP and SQL adapters do not call these methods yet.

## Bounds and remaining integration

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

Schema lifecycle beyond the initial namespace, the service registration loop, dependency
RESTRICT, public SQL/typed adapters and service scheduling remain unfinished.
The [Table storage owner](../../transit-storage/docs/table-partitions.md) defines
row/DDL acceptance, rewrite and pin behavior. The
[data lifecycle contract](../../../../contracts/DATA_LIFECYCLE_V1.md#direct-catalog-publication-contract)
defines the publication boundary; the [proof ledger](../../../../tests/README.md)
records executed tests and their limits.
