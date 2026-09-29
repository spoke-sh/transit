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
the implemented journal/checkpoint layout, adapter operations, cold-store setup
and qualifications. Changing providers requires evidence for those guarantees.
