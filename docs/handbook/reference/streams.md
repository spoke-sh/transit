# Streams and delivery

## Declarative Streams and Queues

Typed callers can declare schema-bound Streams and Queues through
`transit-data-client.Catalog.callLog`. A declaration selects stable object and
column identities, partitioning, retention and bounded operation budgets. Queues
also declare ordering, leases, retry backoff and an optional exact-definition DLQ.
Retention defaults to unlimited. Current database CONNECT, schema USAGE/CREATE
and object ownership govern publication and administration; metadata inspection
uses separate Stream/Queue grants.

An age policy requires trusted UTC within the deployment's configured clock
uncertainty bound. Append records a conservative upper timestamp; expiry needs
a later lower bound proving the declared age has elapsed. Missing or regressing
time refuses fresh timed work while original receipts remain inspectable.

Preview writes nothing. Admission freezes the original request and reserves its
name and partition identities. Bounded execution registers the permission object
and initializes partitions; the declaration becomes visible only when all of
that evidence is complete. Save the original request before admission and inspect
that identity after a lost reply. A pending or cancelled declaration is not a
published data source.

ALTER currently changes retention, operation limits and compatible scheduling
policy. Schema changes, repartitioning and changes to routing, keys or ordering
are refused before admission. RENAME preserves identity; DROP hides the name but
retains accepted operations, definitions and required storage. DLQ references
bind an existing compatible Queue definition, require current append rights and
protect it with DROP RESTRICT. Renaming never retargets an accepted reference.
Historical Queue dependency edges remain retained pending the Queue closure owner.

Lookup and listing recheck current metadata rights. Each bounded listing page
has its own catalog observation position; it is not an atomic data snapshot.
Queue payload leasing, SQL verbs and Station composition are unavailable through
these operations. The existing mailbox delivery profile below remains separate.
See the [caller package](../../../packages/zig/transit-data-client/README.md) and
[exact lifecycle contract](../../../contracts/DIRECT_TABLE_V1.md#stream-and-queue-lifecycle).

## Stream payloads and consumer progress

`Catalog.callStream` appends schema-bound batches to one declared partition,
observes its accepted cut, reads finite retained ranges and manages consumer
progress. Save the exact mutation with `DirectStreamClient.save` before sending
it. After a lost response, inspect that original work under current rights.
An append receipt records its allocated offsets; a missing response is not
rejection. Payloads are limited to 1 MiB per append and may have smaller
declaration limits.

Consume accepts a read with a fixed upper cut. Read its cursor in bounded pages;
each page carries its pinned schema, offsets, original row identities and
coverage. Later appends do not extend the read. Returned cells belong to the
caller's output arena. Empty pages may cover filtered offsets without finishing
the read; use the explicit completion flag. Pages allow at most 4096 rows,
4096 examined offsets and 4 MiB encoded data, further bounded by the declaration.
Release the retained read explicitly when it is no longer needed.

Use `wait` with the same complete consume request to wait up to 1000 milliseconds
for an offset frontier before accepting the read. It returns either that finite
read's original receipt or `timed_out` with the observed cut and no accepted read.
An explicit upper offset waits for that frontier; an open upper bound waits for
an offset after `from`. A timestamp filter does not wait for a matching event.
If data is ready at the final check, the read can still be accepted. Retrying an
already accepted identity always returns its original cut. Cancellation or a
lost reply requires inspection of the original consume operation; it does not
roll back acceptance.

Consumer groups have explicit assignment generations and committed next
offsets. Group reads require current acquire rights; committing an offset is a
separate settle operation using authenticated complete coverage and the expected
checkpoint. Reading or closing a client never advances a group. A stale
generation or checkpoint conflicts. Retained reads and original operations
remain subject to current rights after ALTER or DROP.

The service rechecks authorization after buffering every response. Bounded
recovery can return incomplete progress before executing new work. Typed
positional and group reads remain finite after a wait. See the
[payload contract](../../../contracts/DIRECT_TABLE_V1.md#stream-payload-and-consumer-progress).

The local node's maintenance executor seals accepted batches, archives and
checkpoints history, trims covered WAL files and compacts declared keys when
those physical operations are enabled. Compaction preserves logical offsets and
tombstones; existing finite reads retain their earlier visibility and placements.
When at least half an append's rows are hidden, bounded rewriting removes those
payloads from the current placement. Physical cleanup waits for earlier read pins
and recovery dependencies to close. Unlimited retention is the default.
A positive declared retention age permits bounded expiry only after trusted time
and consumer progress allow it; read pins still retain their original data.
Maintenance resumes accepted targets after restart and rechecks current native
authority. See the [node's bounds and settings](../../../apps/transit-node/README.md).

## Mailbox delivery

A mailbox is an ordered durable sequence for a Transit PID. Logical backlog can
outlive its worker and exceed resident memory. Admission, operation sizes, physical
capacity and per-operation budgets still impose explicit limits.
Backpressure cannot silently drop an accepted input.

## Commit and transport are separate

An accepted turn records output content, destination and source provenance along
with state and input progress. A courier then delivers committed outbox work
through the public protocol. A crash between commit and delivery leaves pending
work; it does not undo the source turn or authorize a different destination.

The destination deduplicates the stable output identity. Retrying delivery cannot
admit the same output twice within its contract. This is not a universal
exactly-once promise for remote effects. Current destination policy still applies
before first acceptance; denied delivery must remain an explicit outcome or
blocked condition. Source commitment does not grant destination permission.

The courier needs its narrowly scoped delivery/send rights, not root credentials,
worker ownership, raw storage or mailbox-value access. Authority-derived origin
records distinguish external admission, another process's committed output and
an effect result. A payload's claimed sender cannot replace that evidence.

## Ordered reads and replay

Read bounded pages using the returned positions and explicit retained boundary.
A short response is not evidence that no later data exists unless the operation
says so. Reads and replay require current permission. A trimmed prefix is an
explicit gap, not a complete history whose first record happens to be later.

Recovery uses a validated checkpoint plus the required retained tail, including
pending inputs, outputs, ownership, dependencies and deduplication evidence.
Physical Ursula offsets are storage coordinates, not PIDs, domain sequence
numbers or permission tokens. A checkpoint cannot omit unfinished accepted work.

Application stream contracts may permit resynchronization from a current
snapshot. That does not permit a process mailbox to skip inputs required by its
recovery contract. A permanently expired PID cannot be revived by finding old
bytes. See [retention](retention.md) and [storage](storage.md).

## Flow control

Transport writes and TCP/HTTP2 credit only describe wire progress. They do not
establish durable application admission. Growing query result delivery uses
receiver-issued, authenticated segment credit with a fixed two-segment window;
the sender advances from credit it actually observed. Completion requires the
whole verified result, not a successful socket write.

See the [query flow-control contract](../../../contracts/STATION_QUERY_V1.md#flow-control)
for exact frame and recovery rules. This credit API belongs to query delivery.
Connector byte/message/concurrency budgets remain
independent of transport flow control and of retained-history size.

The [delivery executable](../../../apps/transit-delivery/README.md) documents courier
configuration; [native HTTP](../../../contracts/SERVICE_V1.md) and
[native protocol v1](../../../contracts/TRANSIT_V1.md) define admission and origins.
