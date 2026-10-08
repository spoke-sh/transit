# Queued Table example contract

The Table application uses one associated resource, a fixed four-column schema
and a bounded durable FIFO. `id` is an INT64 NOT NULL primary key; `value` is a
nullable INT64; `label` is UTF8 NOT NULL with default `example`; `tags` is a
non-null LIST of non-null INT64 with default `[1, 2]`. Their stable column IDs
are 1–4, the object and schema revision are 1, and the next column ID is 5.
Creation limits are explicit: 65,536 record bytes, 8,388,608 staging bytes and
1,024 staging records. These are operation quotas, not a total row limit.

The [Python](python/transit_sdk_examples/query.py),
[TypeScript](typescript/src/query.ts), [Java](java/src/io/transit/examples/Handlers.java),
[.NET](dotnet/Handlers.cs), [Rust](rust/src/lib.rs),
[Erlang](erlang/src/transit_example_table_service.erl), [Elixir](elixir/lib/handlers.ex),
[Ruby](ruby/lib/transit/sdk_examples.rb), [C](c/src/handlers.c) and
[C++](cpp/include/transit/sdk_examples.hpp) implementations execute this
contract. The [neutral fixtures](../../tests/verification/sdk-table-work-v1.json)
define application records independently of any host encoder. They do not assert
that every language's example has migrated or passed its runtime proof.

## Commands and progress

The query application format adds `Advance` (tag 5), `NotReady` (6), `Update`
(7) and `Delete` (8) to the [shared query messages](README.md#query-messages-v1).
Advance and NotReady have no body. Update uses Insert's exact signed-key and
nullable signed-value body. Delete carries only an eight-byte signed key.
Initialize/Insert/Update/Delete are casts accepted by the Table service. Advance
is a recorded self cast; its authenticated process origin must equal the service.
Rows is a query call. The requester accepts Start casts and NotReady replies.

Every incoming mutation is recorded in the FIFO before execution. A missing
queue initializes empty; an invalid existing queue record fails. The first DML
command also records an initial schema entry if needed. New incoming commands
append behind the current head; they do not attempt to complete that operation.
The original admitted input position is the DML operation ID in principal
namespace zero. Every later step uses that same input and command with the
schema fixed by this application format. A fresh send is a fresh operation;
unknown sends/commits require the SDK's original signed-request recovery.

An Advance input executes one bounded creation or mutation step. Building work
records another self output. A terminal receipt permits queue completion only
when enough writes remain: three for outcome/node/metadata, plus one for the
initial query policy. Otherwise a self output commits with the terminal Table
step, and a later turn observes the same receipt before finishing bookkeeping.
Creation is likewise resumable. Framework admission, a committed continuation,
Table domain completion and the application outcome record are distinct events.

Each enqueue uses at most three KV writes. Completion uses at most four. A native
Table step can use the full four-write budget; application completion may then
occur in a later turn. Only one FIFO head advances, and neither a process restart
nor a discarded private turn changes its original identity. Pending work remains
durable independently of resident memory. The service deletes a work node only
when it records that input's terminal outcome and advances the queue atomically.
Completed outcome records have unlimited retention unless the application
explicitly adds a retention policy.

Rows returns NotReady while creation or queued work remains. That response does
not block the continuations behind it. Once the queue is ready and empty, Rows
starts a finite query projecting all four columns. The requester verifies the
NotReady reply's saved correlation and peer, records it, and permits a later
explicit Start. It does not retry automatically. Successful result callbacks
consume original owned IPC; their external effects still require application
idempotency because callbacks run before commitment.

## Application records

All integer fields below are unsigned little-endian, except the signed values
inside the original query command. Exact length, version, tags and ranges are
validated on both encode and decode. These application formats are separate from
Transit wire schemas. Changing the pinned schema or interpretation of queued
work requires an application-format cutover; accepted work must not be rebound
to a different schema or given another operation ID.

| Record | Bytes | Fields after the four-byte prefix |
| --- | --- | --- |
| Queue, `TQM` + byte 1 | 21 | head u64, tail u64, ready byte (0 or 1) |
| Work, `TQW` + byte 1 | 17, 25, 26 or 34 | next u64, original query command |
| Outcome, `TQO` + byte 1 | 38 | state byte, admitted u64, completed u64, matched u64, changed u64, rejection byte |

Queue metadata uses application key `table.queue`. Work and outcome keys are
`table.work.` or `table.done.` followed by the identity as exactly 16 lowercase
hex digits. They are at most 27 bytes. Input IDs are positive safe counters.
Identity `18446744073709551615` is reserved for the automatic initial schema work;
it is never a DML operation ID. A next pointer is zero or a positive safe input
counter; head and tail are both zero for an empty queue. Except for that reserved
initial head, links increase in admitted input order. A ready queue cannot have
the reserved initial head. Tail always identifies a node with next zero.

Outcome states are 0 (creation applied), 1 (DML applied), 2 (rejected) and 3
(cancelled). Admitted/completed are positive safe counters and completion is no
earlier than admission. Counts use full u64, exist only for DML applied, and
changed does not exceed matched; their encoded fields are zero otherwise.
Rejection codes are 0 none, 1 row_exists, 2 row_identity_exists,
3 null_not_allowed, 4 missing_required_field, 5 character_limit_exceeded,
6 overflow and 7 inexact. Only rejected outcomes carry a nonzero rejection.
This compact application record does not copy the Table owner's full witness.
