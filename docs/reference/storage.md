# Storage and recovery boundary

Ursula supplies durable storage through the Zig backend adapter. Transit owns
logical process/resource identities, accepted transitions, retained boundaries
and retirement. Physical streams, buckets and offsets are not an alternate
authority for execution or permissions.

## Durable history and derived state

The authority accepts conditional successors into its durable history. Recovery
reconstructs committed state and required protocol evidence from that history
and validated checkpoints. Index pages and caches accelerate access; evicting a
cache does not delete logical data.

The growing profile publishes immutable state roots and uses bounded resident
pages independently of retained cardinality. That does not provide horizontal
authority throughput: the current realm journal remains a serialization point.
Do not infer cluster scaling from a growing-data test.

The current growing authority reads the latest published catalog root and loads
its immutable index pages on demand. An ordinary read does not replay the entire
application history. Root snapshots provide a consistent basis; cache capacity,
page layout and the number of native reads determine its access cost. A storage
checkpoint does not cache a SQL answer or remove the durable steps of a captured
query. These distinctions also apply when Tables or Documents materialize
application history into current state.

The [performance reference](performance.md) quantifies current small-page read
and write amplification. Catalog reads stop at namespace boundaries. Bounded tree mutation batches copy
shared paths once, and the backend stages sibling immutable pages in groups.
Verified pages use a bounded LRU cache. A separate 16-record cache holds verified
immutable authority metadata so data scans cannot evict it. Its key includes the
complete catalog root; a root change invalidates the records. Native reads still
refresh authority and execute all current permission/lifetime checks. This cache
holds at most about 35 KiB of record bytes and is independent of the configured
page-cache slots. Every batch acknowledgement is checked
before the existing final authority commit; failed staging can leave retained
orphans but cannot publish a partial turn. Format-2 page locators remain compatible.
Application mutation quotas and durable payload publication bounds are unchanged.
The [workload model](workloads.md#architectural-priorities) distinguishes hot
keyed state, append-heavy history and analytical read structures; none bypass
the public authorization boundary.

Applications and Board use public clients, not backend journals or provider
credentials. The node composes the core and backend; core remains deterministic
and independent of Ursula/provider types. Pin the consuming backend's upstream
dependency rather than embedding storage implementation details into callers.

## Failure and maintenance

A timeout can follow a successful durable mutation. Retry/reconcile the original
identity; do not initialize a new realm because the provider is unreachable.
Ordinary recovery validates the current durable state. A rolled-back provider or
old snapshot is not safe evidence for live restart, because it may predate
revocation, retirement or an external effect.

Checkpoint publication precedes authorized prefix trimming. Logical tombstones
and retained identity floors prevent reuse/resurrection after physical cleanup.
Maintenance is bounded, fenced and resumable. An acknowledged provider delete
does not establish erasure from all backups or copied application data.

The local CLI profile composes disk Ursula with S3 cold storage. Provider budgets,
disk headroom and trusted clock assumptions are deployment responsibilities;
an in-memory store test does not establish WAL or host power-loss behavior.
See [retention](retention.md) and [deployment](deployment.md).

The [backend package](../../packages/zig/transit-backend-ursula/README.md) and
[storage mapping](../../packages/zig/transit-backend-ursula/docs/storage.md) own
the journal/checkpoint layout, adapter operations, cold-store setup and recovery
requirements. A replacement provider must satisfy those same requirements.
