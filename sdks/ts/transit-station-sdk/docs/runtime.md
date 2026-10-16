# Runtime, recovery and data

Each runner owns one native process and one admitted operation; requests have
bounded frames and finite native/outer deadlines. No background request queue
accumulates work. Native I/O runs outside Node. Handlers and recovery hooks run
on Node and must cooperate; synchronous CPU loops can delay stop and disposal.
The native executable retains the shared ABI's minimum 8 MiB stack budget.

`next()` advances bounded native preparation; `run()` owns its single consumer
until completion or disposal. `reconcile()` explicitly retries the current saved
mutation. Concurrent consumers and callback reentry fail with `Busy`. Returning
from `initialize` or `handle` only finishes private application work; commitment
is observed through a `committed` event with a native receipt.

Every turn operation validates its active async context and rejects overlap.
Await calls serially, including state writes. Operations dropped by a handler or
still active when it returns prevent successful finish; the runner invalidates
the scope and joins their work. Saved turns, Tables, readers and source handles
cannot be used after that scope. Native read failures poison the turn even when
application code catches them. `stop` discards private work; `block-input` records
the explicit failure marker without acknowledging the input. Decode runs before
initialization and uses the same failure policy.

Choose recovery explicitly. `fence-on-restart` requires fresh ownership after
host loss. `persist-before-dispatch` awaits `store.beforeDispatch(mutation)` before
**every** permit, view-open or commit attempt; persist `mutation.export()` and its
identity before returning. `store.confirmed(identity, receipt)` records the known
result. Hooks return `Promise<void>`. A failed first hook leaves work unsent; a
failed second hook retains the receipt and retries the hook without rerunning the
handler. `needs-recovery` retains exact bytes and stops handler dispatch. Recover
saved mutations with the independent raw client's `recoverMutation` and
`dispatchMutation`; do not allocate another sequence to replace uncertainty.

`stop()` and a `run({signal})` abort request local stop. A request already in flight
remains owned until its result or deadline. `close()` requests stop and joins work
before reaping the port. A receipt observed during this join remains in
`lastEvent`; cleanup never asserts rejection, acknowledgement or peer cancellation.
Use `turn.cancelCall` for explicit advisory durable cancellation. The promise
returned by `turn.call` only stages the call and returns its input-derived native
correlation. Store it in associated state and handle a later authenticated reply.

Protocol IDs are validated safe integers; application u64/i64 and correlations
use `bigint`. `Key<T>` fixes a codec and byte name. Codecs validate their own
versioned formats and bound encoded/decoded input. KV and Table pages preserve
opaque native continuation and source revision. Retained identities may be saved;
their scoped handles cannot. `turn.budgets()` reports native remaining capacity.

Opted-in query readers recheck access for each manifest/segment read. Manifests
include complete source/destination/basis/plan/chain/count evidence; segments own
original IPC bytes that survive runner disposal. Full results are never collected
implicitly. To decode one segment, install exactly `apache-arrow@21.2.0` and use
`toArrow` from `@transit/station/arrow`. The optional adapter uses Apache Arrow's
[IPC reader](https://arrow.apache.org/js/current/) with copied input buffers and
checks the native row count. It preserves int64 as `bigint`; converting it to
`number` is an application decision. The core package loads without Arrow.
