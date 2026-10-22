# Streams and delivery

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
