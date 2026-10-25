# Relational query exchanges

The typed Zig interface exchanges bounded source-row segments under one growing
native authority. Producers and receiver have explicit PIDs/resources independent
of the Tables' catalog owners. Exchanged inputs use `RelationalHistory` with a
frozen direct Table vector. The coordinator retains the original leases. Each
producer saves an original-caller assignment proof and a read-only borrowed
grant for each exact source cut; `RelationalHistory.openExchange` uses the
producer's own credential and fences native publication under the original
caller's current rights. Borrowed access cannot acquire, advance or close a
lease. The
[wire contract](../../../../contracts/RELATIONAL_EXCHANGE_V1.md) defines exact
identities, routing and failure semantics.

1. Allocate a fresh exchange ID and select a positive logical partition count.
   Admit resident, retained-byte, inflight-byte and inflight-segment limits. Add
   exchange retention and operator-state allocations when budgeting the query.
2. Call `RelationalExchange.create` on the receiver. Call `register` once for
   each pair in partition/source order. Each pair names its logical producer PID
   and distinct producer resource. Registering a name grants no native access.
3. Call `createProducer` with the explicit receiver PID/resource and a cumulative
   producer quota. It creates a
   publication with domain `query_exchange`, namespace equal to the exchange ID,
   one staging record and record/staging bytes equal to
   `fuze.RelationalExchange.max_bytes`. Producers use current native grants and
   authorized Table source adapters. Allocate immutable publication record IDs
   in monotonically increasing order without reusing them across partitions.
4. Construct canonical `Segment` values with zero-based consecutive sequence
   numbers, at most four rows and an explicit terminal segment for each pair.
   `offer` stages a segment through repeated bounded turns, then records its
   eligibility and sends an authenticated notice atomically. Save exact pending
   native proposals before dispatch; settle them before fresh work after loss.
5. Dispatch authenticated notices to `receive`. `blocked` has not accepted work:
   retain the original bytes and retry the same notice after progress. `progress`
   reserves or continues one segment; call `advance` with that producer resource
   registered until durable acceptance is acknowledged. Do not pre-register
   unrelated producer resources: native checks all submitted resource views.
6. Schedule `consume` alongside receipt. Each turn indexes at most one row.
   Credit returns only after a whole segment is consumed. Acceptance duplicates
   do not return extra credit. Producers can retire acknowledged publications;
   the receiver retains its copy and exact deduplication evidence.
7. Use `RelationalExchange.Sources` with the existing finite executor after every
   partition consumes its terminal segment. Source order and first-error order
   are independent of placement, arrival or batch boundaries. The enclosing
   captured/maintained owner still owns checkpoint and result publication.

For a maintained activation, the authenticated host calls
`RelationalMaintenance.selectExchanges` with its exact request reference and
activation identity before `start`. After admission, `readBasis` exposes the
recorded successor vector for producer setup. When all partitions complete,
`attachExchange` validates and records that exchange and schedules computation.
The same checkpoints and atomic result/delta revisions apply. Every later
successor waits for its own attachment; an absent attachment returns `idle`
without changing the last complete result. The host explicitly supplies and
attaches each exchange. Incomplete coverage rejects with
`RelationalExchangePending`; an exchange for another source vector rejects with
`RelationalSourceChanged`. Neither rejection changes the native decision.
These controls do not implement an automatic scheduler.

`RelationalExchangeProducer` owns the scan cursor for a manual worker layout.
Its `create` takes the immutable receiver PID/resource, partition count, worker count/index, batch size, physical epoch
and producer quota, and also creates the producer publication. It assigns logical
channels by remainder modulo worker count. Repeated `step` calls read at most
eight source rows and stage at most four matching rows per attempt; the cursor
advances with eligibility only after publication. Different physical workers can
recover the same cursor and pending bytes after native ownership replacement.
Pass receiver-authenticated notices to `acknowledge` through a fresh own-resource
turn, and use `retry` for exact outstanding notices. Acknowledgement does not
return receiver credit. Neither operation redirects the frozen receiver PID.

For credential-changing replacement, the host can use the client's
[recorded manual handoff](../../transit-client/docs/worker-handoff.md). Bind
the handoff application field to the exact relational bound, checkpoint the
producer's whole application resource and revalidate all source rights and
history heads before activation. Pending notices keep their original bytes and
physical epoch. Fresh placement never rewrites an eligible segment.
The replacement validates the original delegated history cuts while execution
ownership is fenced, then uses the rotated worker credential with those same
borrow bindings. Rotation does not authorize a new cut or release a caller pin.

An empty partition requires a zero-row terminal segment. Missing or delayed
coverage produces `RelationalExchangePending`; silence is not completion.
Receiver `close` requires only its own current resource and keeps accepted work
and audit evidence. It remains available after source denial or exhausted data
budgets. No automatic expiry or physical collection occurs.

The [proof ledger](../../../../tests/README.md) separates current direct-source
checks from historical actor-store schedules. The earlier disk-backed exchange
host requires migration to direct sources before its recovery, placement and
capacity results qualify this contract. These typed primitives do not configure
automatic worker placement or a growing runtime controller. They do not enable
a new SQL, Board, Flight or SDK route by themselves.
