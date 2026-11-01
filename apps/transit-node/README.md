# transit-node

The Transit authority executable composes [transit-core](../../packages/zig/transit-core/README.md),
the configured [local](../../packages/zig/transit-backend-local/README.md) or
[Ursula](../../packages/zig/transit-backend-ursula/README.md) storage backend, signed
HTTP ingress and a trusted clock. It validates and commits protocol operations;
application handlers run in callers.

The installed `transit server` also co-hosts the
[SQL host](../../packages/zig/transit-sql-host/README.md) inside its local node.
SQL sessions and PostgreSQL/MySQL listeners use typed local calls into the same
Catalog, Table and native owners. Those calls share the HTTP admission lanes,
signature and current-policy checks, and final disclosure fences. The installation
supervisor controls SQL activation and joined replacement through a private
same-user lifecycle socket; stopping SQL leaves the database owner running.
The configuration service retains its separate installation owner. Explicit
standalone SQL gateway placement continues to use the public HTTP data APIs.

## Build and run

From the repository root in `nix develop`:

```sh
just build::debug apps
zig-out/bin/transit-node CONFIG.json
```

Use the [persistent launchers](../../launchers/README.md), [examples](../../examples/README.md)
or [Kubernetes runbook](../../deploy/reference/README.md) for a complete setup.
The [configuration guide](docs/growing.md) owns fields, operation budgets and
maintenance. [Operations](docs/operations.md) explains bootstrap, clocks and
diagnostics. `profile` is `native_v1`, including when omitted.

## Service boundaries

| Surface | Meaning |
| --- | --- |
| `POST /v1/command` | Signed mutation or reconciliation of an accepted receipt |
| `POST /v1/query` | Signed process, delivery, inspection, resource and snapshot reads |
| `POST /v1/payload` | Authenticated standalone byte publication, original verification and reads on the local owner |
| `POST /table/v1` | Signed direct Table operations when the local `table` owner is configured |
| `GET /health` | Refresh storage and report role readiness |

The [service contract](../../contracts/SERVICE_V1.md) owns envelopes, signature
domains, errors and transport bounds. The [native contract](../../contracts/TRANSIT_V1.md)
owns paged operations, authorization and exact retry. Current grants apply to
reads and receipt recovery; resource associations do not grant access.
Incompatible histories and saved operations reject under the
[hard-cutover policy](../../docs/handbook/reference/versioning.md).

The listener allows 16 connections, four ordinary requests, four notification
waits and two reserved control requests, with 64 sequential exchanges per
connection. Each admitted request owns an execution lane with its own engine,
provider state and bounded caches. Immutable reads and preparation overlap;
conditional journal append serializes accepted successors. A competing
publication can return `Conflict`; uncertain outcomes still require the original
request identity. This does not create independent write shards or establish
per-principal fairness.

Typed Stream and Queue waits use these same dedicated wait lanes and share
64 active registrations, further bounded per declared object/partition. They
register before checking readiness, park without catalog/object locks, and
recheck current authorization after appends or policy changes. Queue waits also
wake at the next delayed visibility deadline and recheck trusted time and FIFO
eligibility. One deadline bounds each wait to at most 1000 milliseconds before
its final check. Timeout accepts no read or claim; accepted retries retain their
original finite cut or selection, including empty outcomes.

Request deadlines cancel and join active work, release its admission lane and
close the connection. A lost reply leaves any accepted mutation unresolved;
callers retain its original signed identity for recovery.

A read whose final authority cut races a publication may repeat the same signed
selector at most eight times. Each attempt rechecks signature, current rights and
source identity; sustained contention still returns `Conflict`. Expired cuts,
revocation and other rejections return immediately. A mutation that loses an
ordinary publication CAS can likewise reprepare the exact signed identity and
body at most eight times, revalidating every current grant, generation, sequence
and expected resource revision. Transport/storage uncertainty returns to the
caller without an implicit retry. Hosts use `Client.contended` to distinguish an ordinary conflict
from expiry, fencing or a conflicting request identity, while retaining exact
pending commands through their own bounded scheduling policy.

With Ursula storage, run `--maintain` separately for authorized lifetime,
collection and checkpoint work. With local storage, the `maintenance` setting
runs lifecycle scans, accepted-floor trimming and configured automatic Table, Stream and Queue
flushing and archiving/checkpointing, Table/Stream compaction and Queue lease expiry inside the node's exclusive owner;
a separate `--maintain` process rejects. Native/direct immutable-object collection
resumes accepted progress under current maintenance privilege and trusted epoch/time
fences. Retained roots continue to own their objects. The local launcher selects this backend. Configured Table operations
use the separate direct Table owner; native process, KV and Document state retain
their paged native commit boundary. The
[courier](../transit-delivery/README.md) delivers committed outputs via
the public client. The [runtime controller](../transit-runtime-controller/README.md)
reconciles physical placement through Substrate. Workers need neither Ursula
credentials nor provider access.

`LocalCatalogPolicy` connects the internal direct catalog component to the same
native role graph, credential checks and resource lifetime fence. It verifies
the original caller's signed request context and the registered domain bindings;
it supplies no new grant store. `LocalCatalogRunner` resumes explicit CREATE execution through the
existing native registration ledger. It prepares each native step, checks the
original caller again, then commits only against that checked native head.
Inspection does not run this helper. `just test::local-catalog` exercises this
composition with real signed native changes and local disk storage.

`LocalTableService` dispatches the [signed direct Table contract](../../contracts/DIRECT_TABLE_V1.md)
inside that owner. The composition test drives declaration admission/execution,
binary row writes, retained reads and release through both serialized envelopes
and typed local dispatch, including caller-owned results after request scratch ends.
The dispatcher checks current rights after buffering the response; a concurrent
revocation suppresses disclosure. The local `table` setting exposes this dispatcher
at `/table/v1`. The local launcher configures this owner for its default Tables;
the shared SQL session, captured queries and direct catalog SDK adapters use
the same signed direct operations. The [catalog caller guide](../../packages/zig/transit-catalog/README.md)
describes the typed operations and host boundary; the [SDK reference](../../docs/handbook/reference/sdks.md)
owns language coverage.

`LocalTableHost` validates the complete catalog history before readiness. It
retains up to ten ordinary and two reserved control workspaces, each containing
one Catalog, at most one Table owner, one Stream partition owner and one Queue
partition owner. The owners retain verified immutable
index pages and owned declarations. Every acquisition checks the current log
frontier; a changed frontier validates the saved boundary and every newer
record before serving the request. A different Table replaces only the volatile
workspace, preserving durable pins, receipts and pending work. Stream payload
actions share the object's lock with catalog DDL and recheck native grants.
They use the [Stream payload contract](../../contracts/DIRECT_TABLE_V1.md#stream-payload-and-consumer-progress),
including finite reads and explicit group settlement. Cursor authentication uses
a private key derived from the registrar seed; replacing that seed invalidates
old cursor authentication but preserves accepted work.

Queue payload actions use the same object lock, current native grants and
trusted UTC interval source. They expose enqueue, original claims, bounded
payload/status pages and explicit fenced settlements through the
[Queue action contract](../../contracts/DIRECT_TABLE_V1.md#queue-payloads-claims-and-settlements).
Claim pages need current read and acquire rights even after acceptance. Queue
owners share the resident budgets below; they retain neither request proofs nor
time callbacks. Native maintenance expires at most one accepted lease per Queue
unit under trusted time and expires opted-in, fully terminal payload prefixes.
The native transaction API composes Queue ACK, enqueue and explicit paired DLQ
transfer with Table/KV state and Stream progress. Automatic scheduling of blocked
DLQ transfers remains unfinished.

Retained owners and their private work share a 256 MiB ordinary allowance and a
separate 64 MiB control allowance, with per-owner limits of 128 MiB and 64 MiB,
respectively. Parsing and held responses keep their existing separate request
budgets. These bounds exclude provider caches, fixed owner metadata and I/O
buffers. Exhaustion returns `StorageQuota` or `ControlCapacity`. Optional work
diagnostics report `owner_memory` separately from `request_memory`, including
allocation attempts and retained/peak bytes; moving allocations into an owner
does not make them disappear from measurement.

Signed native authorization and final disclosure checks remain current. A failed
request destroys its borrowed workspace and clears its Table recovery hint.
Automatic maintenance and cold workspaces can reuse at most 64 validated Table
root/chain hints. Replacement joins all borrowers, destroys their caches and
repeats full recovery. See the
[catalog recovery guide](../../packages/zig/transit-catalog/docs/direct-catalog.md#bounds-and-remaining-integration)
for the immutable-history assumption and failure boundaries.

Stream and Queue maintenance visit one partition of a complete declaration at a time,
including retired declarations for archival and closure. Each catalog pass
freezes its highest object ID. Table, Stream and Queue work rotate within the same
`storage.maintenance.resident_bytes` budget. Each log kind retains at most one
workspace with incomplete recovery between turns, replaying at most 16 records.
Up to 64 disposable root/commitment hints per log kind avoid repeating validated history
when work switches partitions; their allocation shares the same budget. Reuse
verifies the accepted boundary, and newer checkpoints supersede old hints.
All are released on executor shutdown. A finite quiescent history can therefore
finish recovery without a resident limit on the partition population.

The existing flush and archive settings also enable Queue physical maintenance;
compact enables Stream key compaction. Queue timer-run merging and stale-event
cleanup run independently of this optional compaction setting. Log flushing seals one whole accepted batch, bounded by append limits,
instead of Table's partial-row or age thresholds. Archive units honor
`archive.work_frames`; key compaction uses at most 64 rows or the smaller
`compaction_rows` setting. Physical rewriting then inspects at most one accepted
batch per unit under the segment allocation budget, removing proven hidden rows
when at least half the original batch is hidden. Accepted fixed targets survive restart and become
idle after finite work. With native maintenance enabled, only a declaration's
positive retention age enables Stream expiry. Each expiry unit handles at most
one sealed batch under trusted clock bounds and consumer protection. Current
read pins and original receipts remain retained. Quota pressure grants no expiry.

Queue lease expiry is independent of payload retention. A unit considers the
earliest accepted deadline and requires the trusted lower time bound to reach
it. Retry backoff starts at that deadline, including after downtime. Retired
Queues can settle expired leases and archive accepted history. Empty active-lease
sets need no clock; unavailable time with active leases refuses expiry. Queue
expiry uses reserved control capacity and preserves original claims and payloads.
Queue scheduling maintenance uses the same reserve and publishes one resumable
physical transition per unit. Visibility and lease work alternate; merge steps
consume at most 1,024 input entries or the smaller declared `timer_steps` limit.
Initial sweep cleanup separately examines at most 256 buffered events. Frozen
merge inputs and progress survive restart, while current item/bitmap state
continues to govern claims. Scheduling cleanup needs no clock, also after DROP;
it neither expires payloads nor settles leases.

Command signatures do not encrypt traffic or authenticate response transport.
Use an authenticated TLS boundary outside a trusted private network, and keep
raw storage/provider APIs inaccessible to workloads. [Security](../../docs/handbook/reference/security.md)
owns these assumptions; the [proof ledger](../../docs/history/qualification/README.md) records executed
checks and their limits.
