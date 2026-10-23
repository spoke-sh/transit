# Direct catalog owner

`DirectCatalog` provides an internal lifecycle owner for Table definitions and
names. It accepts complete frozen DDL work into a control log, then publishes
the definition through the Table's acceptance log. The installed Table service
and SQL callers still use `TableCatalog`; this component has no public transport
or automatic native-object provisioning.

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
ownership of its explicitly registered target. Registration must already exist;
these callbacks cannot grant authority or manufacture a native identity.

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

## Bounds and remaining integration

Directories and operation indexes use immutable B-tree pages. The default cache
holds 16 pages; tests also use one. The default private index-work allowance is
64 MiB per operation. Canonical request objects are bounded to 4 MiB and control
records to 16 KiB. These limits bound one operation and resident work, not the
number of durable Tables or operations. All accepted history and objects remain
retained; this owner supplies no collector.

`apply` accepts already frozen row changes directly, with exact binding and
Table receipt checks. Durable pending/rejected/cancelled DML, schema lifecycle
beyond the initial namespace, native registration orchestration, dependency
RESTRICT, public SQL/typed adapters and service scheduling remain unfinished.
The [Table storage owner](../../transit-storage/docs/table-partitions.md) defines
row/DDL acceptance, rewrite and pin behavior. The
[data lifecycle contract](../../../../contracts/DATA_LIFECYCLE_V1.md#direct-catalog-publication-contract)
defines the publication boundary; the [proof ledger](../../../../tests/README.md)
records executed tests and their limits.
