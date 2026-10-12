# Interactive relational callers

`RelationalBridge.Session` exposes the shared relational SQL compiler and
interactive executor through lossless JSON values. The Station query C ABI and
`unified_query` port action accept a `relational` action. Generated declarations
and validators come from these Zig types. An interactive handle owns one query;
it does not own a process, activate a worker or submit a durable job.

Configure `query_client.relational` with one or two authorized `catalogs`, explicit
`options` and a `spill_directory` on the host. Each catalog contains `scope`
(`realm`, `resource`, decimal-string `catalog`), `owner` and `principal`. All
catalogs use the same realm, principal, endpoint and signing credential. The
configuration supplies routes, not permissions. A legacy `connection` is optional
for a relational-only handle; if supplied, its realm and principal must agree.

Options require `consistency: per_resource_snapshot_vector`, decimal-string
`resident_bytes`, `spill_bytes`, `result_bytes`, `output_rows`, `work_steps`,
`requests` and `spill_work`, plus numeric `source_pins` (one or two). These are the
same query budgets as the typed executor. One retained output row and bounded
JSON request/response buffers belong to the caller boundary, separately from the
executor's heap budget. The ABI admits at most 256 KiB per request; its result is
one row with at most 128 int64/uint64/null cells. Catalog descriptors and responses
remain independently bounded by their native contracts. The host requires the
[Station calling stack](../../transit-station-bindings/README.md).

A statement contains `sql` and `routes`: one configured catalog index per
`FROM`/`JOIN` target, in SQL order. `[0, 0]` explicitly resolves both targets in
catalog zero; `[0, 1]` resolves the right target in catalog one. No SQL identifier
can select another endpoint, credential or undeclared catalog.

| Action | Result and lifetime |
| --- | --- |
| `capabilities` | Local implementation bounds; no authority observation |
| `explain: {sql, routes}` | Current authorized metadata, proposed plan digest, output columns and source/schema identities; no data cuts or executed rows |
| `open: {id, statement}` | Captured reference, schema and explicit source cuts; no complete-result claim |
| `page: {reference, ordinal}` | One stable row or the final empty completion page |
| `close: reference` | Release source leases and private spill; discard the interactive execution |

Choose a fresh nonzero 16-byte `id`, encoded as 32 lowercase hex characters.
Retain the exact open action until its response arrives. Repeating it on the
same active handle returns the same captured basis; another ID or statement
rejects while a query is active. The reference carries the current shared
contract definition, caller ID, prepared plan digest and bound execution digest.
It is evidence, not authority. Full-width counters and values use canonical
decimal strings; digests and source row identities use lowercase hex. Group
identities contain the declared nullable signed keys in order. Pair identities
contain the original left identity and nullable right identity, in source order.

Start with ordinal `"0"`. Repeating the current ordinal returns the same row.
Advance by exactly one only after accepting that row. Earlier/skipped ordinals
reject; the handle retains one page, not an unbounded replay buffer. The final
page has `row: null` and `complete_coverage: true`. Its ordinal equals the number
of rows delivered. Every earlier page remains an incomplete prefix, including
when an error occurs later. Empty aggregates and grouped-empty input retain the
[relational semantics](../../../../contracts/RELATIONAL_V1.md).

Every page, including cached rows and final completion, checks current native
and catalog rights to every source. A denied noncontributing source still blocks
disclosure. A source error or quota failure cannot silently advance, truncate or
complete a result. The handle retains the original executor failure. Failure to
allocate/encode a response leaves the current native row available for retry at
its same ordinal. Close remains available without source payload permission;
a repeated close of the most recently closed reference succeeds. A closed ID
cannot immediately reopen a different snapshot on that handle.

Serialize operations and join them before destroying the ABI handle. Destruction
attempts lease cleanup and removes local spill. Losing the host expires its
interactive handles; an old reference on a replacement host rejects. It does not
resume or silently run SQL again. Use the separate
[captured](relational-capture.md) or [maintained](relational-maintenance.md) typed
owners for durable execution. Those lifetimes are not enabled by this interactive
foreign action; its capability response states that distinction explicitly.

`RelationalCaller` owns stable catalog-client addresses, their key copies, a
directory handle and the session while borrowing the host's transport and I/O.
The host serializes operations and destroys the owner before those dependencies.
Its workspace `Request`/`Response` wraps shared query actions and a `describe`
operation. Responses allocate in a caller-owned response arena. Description
checks every configured catalog's current metadata rights and, if a query is
active, every source's current disclosure rights. It returns the active reference,
source cuts and current ordinal without advancing execution. This permits recovery
within the same host; it does not resume an earlier host's lost execution.

The [Board worksheet](../../../../apps/transit-board/docs/relational.md) uses this
owner, with a 16 KiB HTTP request limit and one active query shared by its private
viewers. The Station ABI uses the same owned client/session construction. The
[TypeScript](../../../ts/transit-station-sdk/docs/relational.md) and
[Python](../../../python/transit-station/docs/relational.md) APIs expose interactive
calls with immutable values and exact integers.
