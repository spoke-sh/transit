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
The local node uses `genesis.max_clock_error_ms` as a fixed envelope around
trusted UTC for both bounds. A larger allowance makes timed visibility and
expiry more conservative. The kernel-reported error must remain within it;
changes to that reported error do not reset or relax accepted time floors.

Preview writes nothing. Admission freezes the original request and reserves its
name and partition identities. Bounded execution registers the permission object
and initializes partitions; the declaration becomes visible only when all of
that evidence is complete. Save the original request before admission and inspect
that identity after a lost reply. A pending or cancelled declaration is not a
published data source.

Database caller tokens can retain the complete declaration before its admission.
`DirectLogIntent` stages the original schema, policy and operation as an immutable
account-scoped record; Catalog accepts that reference under the caller's token
and current declaration rights. After a lost reply, recover the same token and
resume its recorded declaration. Token acceptance does not publish the object,
and a pending entry cannot be marked complete before the declaration owner has
recorded its terminal outcome. See the
[caller-token contract](../../../contracts/DIRECT_TABLE_V1.md#durable-client-token-bindings).

ALTER currently changes retention, operation limits and compatible scheduling
policy. Schema changes, repartitioning and changes to routing, keys or ordering
are refused before admission. RENAME preserves identity; DROP hides the name but
retains accepted operations, definitions and required storage. DLQ references
bind an existing compatible Queue definition, require current append rights and
protect it with DROP RESTRICT. Renaming never retargets an accepted reference.
Historical Queue dependency edges remain retained pending the Queue closure owner.

Lookup and listing recheck current metadata rights. Each bounded listing page
has its own catalog observation position; it is not an atomic data snapshot.
Payload operations use the separate typed calls below. SQL supports
[declarations, inspection, appends and positional consumption](sql/streaming.md#operations-and-sql-coverage).
Other workload verbs and transactional Station composition remain unavailable. The existing mailbox delivery
profile below remains separate.
See the [caller package](../../../packages/zig/transit-data-client/README.md) and
[exact lifecycle contract](../../../contracts/DIRECT_TABLE_V1.md#stream-and-queue-lifecycle).

Database callers can also save complete workload intents with
`DirectWorkloadIntent` and bind them through `DirectClientToken`. The saved body
includes the exact definition/schema, native request and payload, within a 4 MiB
canonical JSON bound including encoding overhead. Token acceptance reserves the
original operation identity and retains the body; it does not execute it.
Recovery loads the accepted reference and calls the same native operation owner.
Pending bookkeeping can settle only after that owner returns a matching success
or durable closure. Missing receipts, bounded recovery and a cancellation request
remain distinct from completion. Current operation rights are required for token
lookup and settlement as well as execution. SQL workload syntax and result
reopening are not enabled by this typed caller support.

The signed `workload_result` action can reopen original append/enqueue rows,
finite consumes and claims from a saved workload reference. It returns the
original receipt and source schema, then reads bounded pages using explicit
delivery positions. Refetching retains the same selection and does not renew
leases or repeat work. Current operation and READ rights are checked for each
disclosure. Closing local delivery buffers does not release a shared durable
read dependency or settle work; native read release is explicit. Grouped
consumption can prepare a saved authenticated offset handoff for either the
exhausted read or an interval between two issued cursors from that same read.
Both interval boundaries are authenticated; the larger read can remain partial. See the [delivery contract](../../../contracts/DIRECT_TABLE_V1.md#original-workload-result-delivery)
for budgets, empty results and unavailable retained history. SQL supports
[append and positional consumption](sql/streaming.md#consume-a-finite-stream-cut);
group consumption, waits, NACK and renewal retain their native interfaces.
SQL ACK binds an original binary claim receipt through the shared native
settlement owner.

## Cancelling original workload operations

Native Stream and Queue `cancel` requests use the exact saved mutation and its
original identity. If it already committed, Transit returns its original success
receipt. Otherwise Transit durably closes that identity and returns `closed`.
Later mutation, wait and lookup calls return the same closure. Cancellation never
undoes an accepted append, changes a consumer offset, releases a result or ACKs
or renews a claim. Current rights still apply.

Known producer fencing/receipt expiry and Queue lease fencing/expiry also return
a durable `closed` refusal when its record commits. Other errors, absent receipts
and lost replies remain unresolved; recover the original operation. Stopping a
local wait is separate from requesting durable cancellation. These are native
caller operations. SQL workload recovery uses these same original outcomes;
the [SQL profile](sql/streaming.md#operations-and-sql-coverage) defines admitted verbs.

## Queue payloads and leased work

`Catalog.callQueue` enqueues typed batches, claims a bounded original selection,
reads its payloads and explicitly settles each exact lease with ACK, NACK or an
extension. Save mutations with `DirectQueueClient.save` before dispatch. A lost
response requires inspection of that original work; retrying an accepted claim
never selects different messages. An accepted empty claim remains empty even
after more messages become eligible.

Use Queue `wait` with the same complete claim to wait up to 1000 milliseconds
for eligible work. The service rechecks FIFO order, leases, trusted visibility
time and current rights after a notification or delayed-item deadline. A timeout
reports an observed cut without accepting an empty claim. An already accepted
claim still returns its original selection, including an empty one. Save the
underlying claim before dispatch: stopping a local wait or a lost response cannot prove
it was unaccepted. Waits have separate bounded admission and do not hold data
locks while parked.

Enqueue requires current append rights. Claims, original claim inspection and
payload pages require read plus acquire; settlement requires settle. The service
checks grants after buffering, including empty and terminal pages. Returned rows
belong to the caller's output arena and preserve original payload/schema identity.
Their separately observed lease status can be live, expired, unavailable or
fenced. That observation does not authorize later execution: settlement checks
the exact current lease and trusted time again at publication.

Enqueue is bounded to 1 MiB per batch; claims select at most 256 rows and obey
smaller declaration and active-capacity limits. Read pages apply row and byte
budgets with a cursor over the original selection. The final data page can be
complete; reading a complete cursor returns an empty terminal page. Closing a
page or client performs no ACK or renewal. Original outcomes and open payload
reads remain recoverable after compatible policy edits, DROP or clock loss.

The explicit Queue `release` mutation closes one original claim's retained
payload reads. Save its new operation and exact claim receipt before dispatch;
it requires current read and acquire rights, including after DROP. Subsequent
payload pages return `QueryExpired`, while original claim and release outcomes
remain recoverable. It changes no lease and does not authorize physical deletion.
Use it only when that original selection no longer needs payload traversal;
closing a client result buffer does not issue this mutation.

With local native maintenance enabled, Queue payloads are sealed and archived
and expired leases are processed one accepted deadline at a time. Trusted time
must establish expiry; retry backoff starts at the accepted deadline, including
after restart. These transitions preserve original claims and do not expire
payload history. An expired lease can still appear acquired until bounded work
runs; an expired receipt cannot settle it. Visibility/retry and lease schedules
use paged time-bucketed storage with bounded resident caches. Native maintenance
also merges timer runs and removes stale scheduling entries through recorded,
resumable progress, including after DROP. This physical cleanup needs no clock
and changes no claim or payload lifetime. A scheduling-read budget refusal is
distinct from an empty claim.

An explicit `max_age_ms` retention policy also lets native maintenance expire one
sealed, fully terminal payload batch from the retained prefix per unit. The age
uses trusted append time. Available, acquired, delayed, retrying or blocked items
prevent expiry of their batch; later terminal batches wait behind that prefix.
ACK alone does not authorize expiry. Original claims keep their payloads through
this logical expiry until explicitly released; older replay cuts can retain them
longer. Current Queue observations report the advanced retained boundary, while
an open original claim can still return its older offsets. Physical collection
waits for all dependencies to close. See [retention](retention.md).

Explicit native transactions can move a live leased item or an exhausted blocked
item to its exact dead-letter destination. Source archival, FIFO advancement and
the destination append share one decision. The transfer preserves the original
logical row and visibility time, checks current rights on both Queues, and leaves
the source nonterminal if the destination cannot accept it. Exhausted items expose
their recorded destination and `blocked_after_ms`; later source policy changes
cannot redirect them. The internal catalog composition owner can retain one
protected transaction for an exhausted item, recover its original statement and
decision, and preserve its source binding after either commit or abort. It uses
the standard transaction workspace and decision log. The local node's optional
[`table.queue_transfers`](../../../apps/transit-node/docs/growing.md) identity
enables automatic discovery and recovery alongside native maintenance. It needs
separate current database grants. Destination keys use canonical declared
routing; unkeyed transfers use source ordinal modulo destination partition count.
Changing the worker or its account never reissues an already bound source.
The public wire surface supports original transaction inspection; protected
transfer mutations remain with the internal composition owner.

Typed transaction selection can retain Stream/Queue partition cuts as read
dependencies alongside Table/KV state. Serializable completion checks those
partitions' logical frontiers; read-only completion preserves the acquired cut
after later writes. Each observation requires current read access. Native
transaction work can append to Streams or Queues, commit an authenticated Stream
offset, ACK an original Queue lease, or transfer a dead-letter item together with
Table/KV state. The shared
statement sequence, savepoints and common decision preserve original identities
through uncertainty; provisional summaries do not establish public acceptance.
Lease and retention deadlines are checked immediately before the decision;
recovery preserves an already accepted decision after those deadlines. See
[transactional log work](../../../contracts/DIRECT_TABLE_V1.md#transactional-stream-and-queue-work).
SQL workload verbs, mixed log transaction SQL and Station turn composition remain
unavailable. [Declaration and named inspection SQL](sql/streaming.md#stream-and-queue-declarations)
uses the shared Catalog lifecycle.
See the [Queue action contract](../../../contracts/DIRECT_TABLE_V1.md#queue-payloads-claims-and-settlements)
for exact standalone limits and the [Queue contract](../../../contracts/QUEUE_V1.md)
for required composition guarantees.

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
separate settle operation using authenticated complete interval coverage and the expected
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
