# Station Tables and Arrow results

Status: the bounded [M9](roadmap/M9.md) Table/Fuze profile is implemented; the
[Table guide](../packages/zig/transit-station/docs/tables.md) owns exact type,
capacity and result-delivery limits. Broader transaction/query directions below
remain planned. [State](STATE.md) owns the underlying resource
contract; [Station](STATION.md) owns behaviors and remote request/reply.

[M10](roadmap/M10.md) selects growing durable Tables and paged access before
public SDKs. The M9 row/result ceilings remain enforced today; they must not
become permanent total-size semantics. Bound resident batches and atomic work
independently of total retained rows/results, following
[State](STATE.md#collection-size-and-working-memory).

## Programming model

A Table is a typed keyspace inside a durable resource, operated by its fenced
writer PID. Its identity includes the resource ID and a declared table/schema
identity. The durable descriptor fixes primary-key encoding, fields, nullability
and schema version. A name is a lookup aid; it cannot retarget an existing query
or retry. M9 uses explicitly initialized schemas and rejects incompatible ones;
automatic DDL, migration and schema inference are outside the profile.

Table rows remain committed KV data. Use a versioned compact row encoding that
fits the underlying value limit; Arrow is the required tabular result format,
not a requirement to put an entire IPC schema into every stored row. Namespaced
row, descriptor, correlation and result keys share the resource's capacity.
An Arrow row number is not a primary key. Distinguish absent rows, null fields,
empty values, deleted rows and unavailable history.

The proposed operation families are:

| Operation | M9 meaning |
| --- | --- |
| Insert | Require an absent primary key; an existing row is a conflict |
| Update | Require an existing row; validate a typed replacement/patch against its schema |
| Upsert | Explicitly insert or replace by primary key |
| Delete | Remove the current row under the captured resource revision; deleting an absent row is an explicit idempotent no-op |
| Get / scan | Return an Arrow result at a declared read basis, with bounded work and explicit completeness |
| Query | Apply a versioned structured plan to a finite snapshot; reject unsupported operators/types |
| Batch | Propose a bounded set of mutations within one resource and one turn |

Local helpers operate on the handler's captured resource view and proposed
mutations. Requests to another writer are ordinary correlated messages to its
PID, followed by a committed response. Durable admission, transaction commit,
reply delivery and result consumption remain distinct events.

The initial remote request describes table identity, expected schema, operation,
typed parameters, correlation, authorized reply destination and budgets. It
does not carry executable code. Prefer this shared structured contract first;
SQL can later compile to it in a caller/query worker. Choosing a SQL dialect,
planner, parameter rules or optimizer is not a prerequisite for Arrow results.
The Transit node never parses SQL or runs predicates/compute kernels.

## Transactions and visibility

The resource remains the transaction domain. Its writer computes a private
candidate from an exact view; the existing state-turn commit publishes the
mutations with input progress, correlation state and outgoing messages. Updates
and deletes do not mutate already published Arrow buffers in place.

| Scope | Guarantee / limit |
| --- | --- |
| One table | A supported batch is atomic under the resource revision and PID activation fence |
| Several logical tables in one resource | M9 can provide an atomic batch over their keyspaces, sharing one writer, grant/lifetime domain and resource revision |
| Several resources, even with one writer PID | M9 rejects atomic mutation; serial execution or a common realm journal does not add a multi-resource transaction API |
| Several writer PIDs / authorities | Messages coordinate separate commits; all-or-nothing visibility requires a separately designed protocol |

For example, two related records in different tables can change together when
both tables inhabit the same resource and the complete proposal fits the turn
budget. Moving either table to another resource changes that guarantee. Check
the whole batch before submission; never implement a too-large atomic batch as
several commits. Awaiting several successful requests is not a transaction.

Co-location also shares capacity, retention and coarse resource permissions.
Table key prefixes provide no kernel-enforced permission isolation. Do not
co-locate tables that require independent grants/lifetimes and claim otherwise.
Business constraints and Table schemas are trusted caller checks, like handler
computation; core validates the opaque resource protocol, not relational integrity.

Within a local transaction, define read-your-proposed-writes explicitly. Remote
read-only queries select a committed snapshot. M9 queries target one resource;
multiple reads of different resources do not establish a common snapshot, even
when the observations contain realm positions. A query result used to decide a
later write is an observation; its expected revision must still be validated.

## Materialization from durable streams

Keep three different streams explicit: a durable Transit message sequence,
the resulting table changelog, and a finite Arrow batch sequence returned by a
query. An Arrow stream does not supply durable offsets, delivery deduplication,
ownership or a transaction coordinator.

```text
authenticated input -> Station writer -> committed KV mutations + input progress
                                             |
                               captured revision -> Arrow batches -> compute
```

M9 supports a process consuming ordered stream-derived inputs and applying
insert/update/delete operations to its table. The same commit advances input
progress and the materialized data. Transit output identity covers courier
redelivery; a source that resends the same external event as a new admission
needs an application event ID and an explicitly budgeted deduplication policy.
For a direct external-stream consumer, its source identity and consumed position
must commit with the changes before acknowledging the source. Multiple source
streams establish per-source positions, not an invented global order.

The current KV index is reconstructed by core from accepted records/checkpoints.
Station obtains it through authorized client views and builds Arrow batches for
the selected revision. Any additional columnar cache is derived: label it with
resource/schema revision, rebuild or catch up before answering, and never serve
unqualified stale data as current. M9 need not maintain a separate persistent
columnar index. Rebuilding a cache does not rerun application handlers or submit
mutations. History trimming must leave a valid recovery checkpoint and tail.

Query the visible row set, not the concatenation of historical row versions.
Updating a key replaces its old contribution; deleting it removes that
contribution. In M9, finite queries recompute from the bounded current snapshot.
For an aggregate such as a minimum, a deletion can require examining remaining
rows; treating a delete as another positive input is incorrect.

Continuous materialized queries are a later capability. Their contract needs
before/after changes or equivalent retractions, source positions committed with
aggregate state, transaction boundaries across batches, and an atomic
snapshot-to-tail handoff. A slow consumer below the retained floor must receive
a gap/resnapshot outcome, not a silently complete result. Event-time windows,
watermarks, late-data policy, joins and spill require their own budgets and proofs.

## Arrow and compute integration

Build on `zarrow` for Arrow representation/IPC and `zarrow-compute` for selected
kernels. M9 pins the `rupurt/zarrow` and `rupurt/zarrow-compute` Zig 0.17 forks. This
review inspected source on 2026-09-24. The
[integration proof](../packages/zig/transit-fuze/docs/integration.md) now qualifies
the exact dependencies, IPC and C interfaces. The
[Station Table guide](../packages/zig/transit-station/docs/tables.md) owns the
implemented layout, capacity, query policy and captured-reply profile.

| Source reviewed | Finding and consequence |
| --- | --- |
| [rupurt/zarrow at 4276ac3](https://github.com/rupurt/zarrow/tree/4276ac30d63d1af159490b7dc70e15d749b8d01b) (`update-zig-0.17`) | The [manifest](https://github.com/rupurt/zarrow/blob/4276ac30d63d1af159490b7dc70e15d749b8d01b/build.zig.zon) and CI target `0.17.0-dev.2267+48abf1a34`; Transit now pins that same compiler. Qualify record batches, IPC and C Data/C Stream; a branch name is not a dependency pin. |
| [rupurt/zarrow-compute at def4d06](https://github.com/rupurt/zarrow-compute/tree/def4d0654b4d6cdc2f4a7e6ad4a5930301f3391a) | The Zig 0.17 upgrade is pinned by revision/hash. Fuze imports the upstream compute module with the same qualified full Arrow module used by IPC. The upstream compute tests run in the package check. |
| [Aggregate implementation](https://github.com/tylitianrui/zarrow-compute/blob/357fbf421c77785cd972fe5589918cb3bd39a92e/src/kernels/aggregate.zig) | Stateful row counting accumulates batches; this is not a durable incremental view with update/delete retractions. Station owns that distinction. |

Pin revisions and package hashes deliberately after testing. Do not downgrade
Transit or introduce a second client/compiler policy implicitly. Any compatibility
patches and selected upstream tests need recorded evidence with the eventual
owning package. Resolve zarrow-compute against this same qualified zarrow module;
the fork's compiler upgrade alone does not establish compute compatibility.
The compute library is not assumed to supply SQL, recovery,
authorization, a durable stream scheduler or transactional materialization.

[Fuze](FUZE.md) composes these dependencies in a Zig-native query engine,
inspired by DataFusion and Acero, with shared source, logical/physical plan and
operator/sink boundaries across state entities. M9 proves the bounded Table path,
finite execution and IPC; [M16](roadmap/M16.md) adds Flight, a bounded Flight SQL
frontend and ADBC interoperability over the same Table/query contract, following
[ARROW.md](ARROW.md).

M9 starts with a small published capability matrix: nullable booleans, signed
64-bit integers, UTF-8 strings and binary values; primary-key lookup, bounded
scan/projection/limit, supported predicates, and a small aggregate set such as
count and integer sum. Verify exact operator/type pairs instead of exposing an
upstream function name as a promise. Specify null behavior, overflow rejection,
key order and deterministic result ordering. More numeric/temporal types, decimal
arithmetic, nested types, user-selected sorting, grouping and joins need explicit extension.
Never silently convert unsupported decimals to floating point.

Run compute in the Station caller with explicit allocators and CPU/memory/output
budgets. Check deadline/cancellation between bounded batches; an uninterruptible
kernel needs a size bound. A worker crash or failed computation publishes no
partial transaction. Keep enough headroom for lifecycle/control progress.

## Arrow results and durable replies

Use Arrow record batches and [C Data](https://arrow.apache.org/docs/format/CDataInterface.html)
ownership for compatible in-process interchange. [C Stream](https://arrow.apache.org/docs/format/CStreamInterface.html)
is a pull interface inside one process, not a durable network transport.
Across processes, return an [Arrow IPC stream](https://arrow.apache.org/docs/format/Columnar.html#serialization-and-interprocess-communication-ipc)
with a schema and record batches. A single aggregate is still an Arrow result;
empty results preserve their schema. IPC does not promise zero-copy transport.
Mutation acknowledgements and protocol errors remain control messages; tabular
data uses Arrow rather than a parallel JSON-row format.

Every result also identifies query/correlation, exact resource and schema
revision, completeness, and applicable lifetime/coverage. Repeated execution
against a newer snapshot must have a new result identity. Return deterministic
primary-key order for the initial profile; do not let internal hash iteration
change page order or retry bytes.

The current 256-byte `Value` cannot hold ordinary Arrow results. M9 must prove
an explicit bounded reply-framing profile rather than enlarge fields silently
or smuggle a raw Ursula/object-store URL into a message. The proposed first
profile durably captures a small finite IPC result and its metadata in the
writer's resource, atomically with the query's consumed input. Subsequent turns
emit bounded outbox fragments and advance durable reply progress. Account for
all keys/bytes/mutations before accepting this result; oversized queries return
a recorded budget error. This is a small result protocol, not general blob storage.

Fragments carry result identity and ordinal; the completion manifest binds
schema, total bytes/batches and content integrity. IPC messages and Transit
fragments need not share boundaries. Receivers bound reassembly, check the
authenticated source and expected query, deduplicate fragments and require
verified completion. A partial stream is never a successful empty/short answer.
Malformed Arrow metadata and oversized buffers must be rejected before allocation.

Do not keep a worker-local iterator as the only continuation. M7 read views are
bound to one input/activation and cannot be carried into later turns. Finish
snapshot evaluation and commit the bounded result while that view remains valid;
then resume delivery from durable result state after a crash. If this cannot fit
the existing budgets, the integration gate must narrow the supported query or
explicitly scope a generic resource/retention extension before claiming support.

The waiting caller commits request/correlation, releases its turn, and processes
fragments through mailbox order. Result consumers acknowledge completion or
cancel through recorded operations. Closing an iterator, disconnecting, host GC,
or a local timeout alone does not cancel accepted work or erase pending output.
Define result work deadlines, late-fragment rejection, and explicit terminal
failure when either process can no longer receive. History retention remains
unlimited unless the application opts into removal; completion permits no
implicit deletion. Unlimited retention may eventually refuse new results when
bounded working capacity is full.

## Access, lifetimes and inspection

Direct Table reads inherit current resource permissions. A remote Table service
is an explicit data-sharing boundary: send permission to its PID is not permission
to query its data. Bind a versioned service access policy to authenticated origin,
allowed tables/operations and reply destination. Define grant/revocation ordering
in that service's durable sequence and recheck it before publishing further
result fragments. Payload sender claims and correlation alone authorize nothing.

Authorizing a copied result discloses those bytes to the destination mailbox;
source revocation/expiry cannot recall an already authorized copy. Record and
validate that disclosure/retention policy when accepting a query. Future reference
results would instead need current fetch grants and dependency pins. Arbitrary
IDs inside Arrow metadata acquire neither permissions nor retention protection.

The logical table shares its resource lifetime in M9. Row deletion, resource
expiry, query-work lifetime and retained result/history lifetime are distinct.
Preserve current rows across history compaction and retain deletion/revision
evidence against stale resurrection. A query cannot extend a required resource's
hard expiry; unavailable or expired snapshots produce explicit failures.

Board may show declared Table identity/schema version, writer PID, resource
revision, query progress, coverage and budget failures under current grants.
It must not interpret application column meanings, run arbitrary user queries,
or decode business values to infer a Table descriptor.

## M9 scope and later work

M9 delivers fixed schemas over bounded KV, typed mutations, co-located table
batches, stream-input materialization, finite snapshot computation and Arrow
results through the [language bindings](CLIENT.md#m9-language-targets). It must
measure the complete example against the [existing state limits](../contracts/STATE_V1.md#bounds-and-storage):
four resources, 32 live keys per resource, 32-byte keys, 256-byte values, four
distinct-key mutations per turn, eight entries per page and four active views.
Framework records, result buffers and two tables do not each receive a separate
allowance. The M9 entry gate records the supported schema/result maxima and
concurrent-query policy; these are not production-scale tables.

Full SQL, separate-resource transactions, continuous queries/retractions,
multi-source snapshot coordination, historical time travel, large results,
disk-scale indexes/spill, per-row TTL, migrations and writer transfer are outside
M9. When selected, give this work a new numbered milestone in the linear roadmap.
The selected remote interoperability work is [M16](roadmap/M16.md), including a
small read-only SQL subset; it does not promise full SQL, continuous queries or
broader transaction scope.
For transactions, first investigate a bounded multi-resource write/read-set
commit within one authority; cross-authority atomicity additionally needs durable
coordination, isolation, participant fencing, recovery and blocked-capacity
policy. Sagas/compensation remain an explicit alternative with partial visibility,
not an equivalent atomic guarantee.

[M9's acceptance criteria](roadmap/M9.md#exit-criteria) require crash/retry,
update/delete, Arrow interoperability, expiry/revocation and budget proofs before
these proposals can be described as supported behavior.
