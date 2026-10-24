# Interactive relational callers

`RelationalBridge.Session` exposes the shared relational SQL compiler and
interactive executor through lossless JSON values. The Station query C ABI and
`unified_query` port action accept a `relational` action. Generated declarations
and validators come from these Zig types. An interactive handle owns one query;
it does not own a process, activate a worker or submit a durable job.

Configure `query_client.relational` with the mandatory current shared `definition`,
one or two `catalogs`, explicit `options` and a private `spill_directory`. Each
catalog contains `scope` (`realm`, `resource`, decimal-string `catalog`),
decimal-string `branch`, service `audience`, `principal` and nullable `role`.
This direct profile requires identical catalog connections and one credential;
its optional `service_url` selects the direct endpoint, defaulting to the native
authority URL. Multiple Tables have independent acceptance partitions within
that catalog. Mixed connections are rejected before opening the spill directory.
Configuration supplies routing, not permissions. A relational-only query handle
omits `connection`; when captured-query configuration is also supplied, its realm
and principal must agree.

Options require `consistency: independent_table_snapshots`, decimal-string
`resident_bytes`, `spill_bytes`, `result_bytes`, `output_rows`, `work_steps`,
`requests` and `spill_work`, plus numeric `source_pins` (one or two). These are the
same query budgets as the typed executor. One retained output row and bounded
JSON request/response buffers belong to the caller boundary, separately from the
executor's heap budget. The ABI admits at most 256 KiB per request; its result is
one row with at most 128 int64/uint64/null cells. Catalog descriptors and responses
remain independently bounded by their native contracts. The host requires the
[Station calling stack](../../transit-station-bindings/README.md).

A statement contains `sql`, `namespace` (default `1`) and `routes`: one configured catalog index per
`FROM`/`JOIN` target, in SQL order. `[0, 0]` explicitly resolves both targets in
catalog zero; a second configured route must identify the same direct connection. No SQL identifier
can select another endpoint, credential or undeclared catalog.

| Action                                       | Result and lifetime                                                                                                                                                   |
| -------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `capabilities`                               | Local implementation bounds; no authority observation                                                                                                                 |
| `explain: {sql, namespace, routes}`          | Current authorized metadata, proposed plan digest, output columns, complete saved source bindings and observed partition positions; no retained cuts or executed rows |
| `open: {id, statement, bindings, snapshots}` | Bind supplied original definitions and retained snapshots; return the interactive reference, schema and cuts without a complete-result claim                          |
| `page: {reference, ordinal}`                 | One stable row or the final empty completion page                                                                                                                     |
| `close: reference`                           | Discard local execution and private spill; durable pins remain until explicit catalog release                                                                         |

Save each source's exact binding and position from explanation. Use the catalog
retention interface to save an acquisition before dispatch, acquire that exact
cut and preserve the resulting snapshot. Repeated aliases of one Table use the
same snapshot. Acquisition, unknown-outcome recovery and release are separate
catalog operations; explanation and open do not acquire or release retention.

Opening verifies every supplied definition against its retained metadata and
checks current rights. The SQL target must match the supplied binding's name and
namespace. No live-name lookup replaces it. A fresh explicit query can therefore
use its original source after ALTER, DROP or name reuse. The saved name is the
caller's mapping; the retained metadata establishes the accepted interpretation
and schema. The result describes branch/object/partition positions with full-width
decimal strings, not an atomic cross-Table snapshot.

Choose a fresh nonzero 16-byte `id`, encoded as 32 lowercase hex characters.
Retain the exact open action until its response arrives. Repeating it on the
same active handle returns the same captured basis; another ID, statement, binding or snapshot
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
removes local spill; it performs no durable pin release. Losing the host expires its
interactive handles; an old reference on a replacement host rejects. It does not
resume or silently run SQL again. Use the separate
[captured](relational-capture.md) or [maintained](relational-maintenance.md) typed
owners for durable execution. Those lifetimes are not enabled by this interactive
foreign action; its capability response states that distinction explicitly.

`RelationalCaller` owns stable catalog-client addresses, their key copies, a
direct service transport, directory handle and session while borrowing the host's
native authority transport and I/O.
The host serializes operations and destroys the owner before those dependencies.
Its workspace `Request`/`Response` wraps shared query actions and a `describe`
operation. Responses allocate in a caller-owned response arena. Description
checks every configured catalog's current metadata rights and, if a query is
active, every source's current disclosure rights. It returns the active reference,
source cuts and current ordinal without advancing execution. This permits recovery
within the same host; it does not resume an earlier host's lost execution.

The Station ABI uses this owned client/session construction. The
[TypeScript](../../../../sdks/ts/transit-station-sdk/docs/relational.md) API accepts
immutable saved bindings and snapshots. The Python API uses the same source
contract. An older actor connection is not accepted by the current definition.

`RelationalWorkspace` adds explicit service ownership for the
[Board worksheet](../../../../apps/transit-board/docs/relational.md). Its open
accepts the explained source bindings and positions, journals original pin
requests before acquisition, and supplies the resulting snapshots to this same
session. A private, exclusive recovery directory holds at most one 32 KiB record.
After replacement it exposes interrupted ownership for explicit closure, without
resuming execution or choosing newer sources. Destruction performs no network
cleanup. `recover` takes the original query ID; it reconciles lost acquisition
and release replies and closes the exact original owners before admitting new
work. Caller connections and the mandatory shared definition bind the journal.
All workspace responses use a host-owned request/response arena.
