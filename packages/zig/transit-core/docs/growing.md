# Growing authority integration

Status: M10 in development. `transit_core.growing.Engine(Journal, PageStore)` is
not yet composed into the running node or public client. The [v3 contract](../../../../contracts/TRANSIT_V3.md)
owns proposed wire types; the existing v2 engine remains the deployed profile.

The implemented internal transitions include bootstrap, root-authorized principal
grant/revocation, process creation, ownership, mailbox admission and termination;
resource creation/grants/associations, captured view open/close, bounded state
turns, turn permits and resource retirement/expiry.
They use the [typed immutable catalog](pages.md#typed-catalog). Principal sequence,
exact-retry receipt, process metadata and accepted mailbox entry become visible
through one conditional journal append of a new root. A prepared candidate can
leave unreachable pages; it cannot advance a live process or disclose acceptance.

Principals use full-width value keys. Grants have an epoch for later resource-
grant invalidation without scanning all resources. Receipts are independently
addressed by principal and sequence; retry does not scan the history or evict an
older receipt. Authentication/current command permission precedes retry lookup.
Mailbox keys combine PID and per-process ordinal; input bytes and source evidence
remain retained after progress, with no resident queue proportional to backlog.

The journal entry carries the previous root and a complete constant-size head,
including a genesis fingerprint. Opening/refreshing reads the latest published
head and materializes records on demand. It relies on the trusted journal's
conditional append/record-coordinate contract; page identity checks protect
referenced content. Recovery never stages pages or runs application code.
Root-history checkpoint/trim and compatibility rejection still need composition
into this engine; the separate page proof is not that integration.

State turns stage bounded mutations alongside process progress, output/effect
intents, closed views and retry evidence. Current resource grants are required
when disclosing a retained state receipt, including receipts whose views closed
long ago. A grant epoch change invalidates old resource grants without scanning
the resource catalog. Views retain one catalog root, not copies of resource data.

Required associations have their own index, separate from optional associations.
Dependency validation walks lifetime-owner dependencies with a visited set, so
self-owned state and cycles do not recurse forever. Genesis declares operational
budgets: 16 required resources per PID and 64 visited owner PIDs by default, each
configurable up to 4,096. These bound one validation graph, not total principals,
processes, resources or retained records. Association admission validates the
candidate graph before publication; exceeding the budget rejects the operation.
This development profile also freezes an owner's required dependency topology
while another live PID requires its owned state. Otherwise a locally valid new
edge could push an existing borrower's previously accepted graph over its budget.
Borrowers must detach healthy dependencies or retire before that topology changes;
the indexed check rejects with `DependencyInUse`. Optional associations do not
add lifetime edges. This conservative restriction needs explicit capabilities
and client guidance before the profile is advertised.
An expired/retired required dependency cannot be removed or rebound to revive
the PID. Its durable dependency evidence fences execution even before terminal
process metadata is materialized. Inspection must expose that distinction when
the read service is added. Explicit resource retirement refuses active required
users; known finite expiry can close the dependency. Physical page deletion is
not implemented or authorized.

No running capability advertises these transitions. Delivery,
effect settlement, query services, terminal dependency materialization,
runtime/lifecycle extensions, quotas/control reserve, retained results and Station
remain integration work within M10. Unimplemented commands fail explicitly with
`UnsupportedGrowthCommand`. The module must not be selected by a launcher before
the complete advertised profile and its proofs are ready. Existing histories are
never silently upgraded or parsed as v3.

## Initial evidence

Core tests retain 20 principals with identities above 65,535 and 70 processes,
crossing both legacy catalog limits. They check retained mailbox provenance,
historical retry after a later sequence, recovery without page writes, competing
candidate fencing, revocation before publication/disclosure, failure before
append, lost accepted acknowledgements and permanent retirement. Additional
checks reject an older materialization root attached to a newer publication and
legacy genesis versions. Clock uncertainty, rollback and elapsed work deadlines
fail closed; clock failure does not disable revocation or termination. The injected
journal/page store is deterministic test infrastructure; these checks do not
qualify Ursula integration, complete M10 or demonstrate production throughput.

The state-turn proof exceeds four resources, 32 rows and four retained views.
It verifies that staged rows/progress are invisible before commit, rejected
outputs cannot publish row mutations, old roots remain readable internally, and
resource-right revocation prevents historical receipt disclosure. Required
resource expiry blocks reactivation through indirect ownership and cannot be
bypassed by detaching an association.
