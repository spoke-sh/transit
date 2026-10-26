# Native authority integration

`transit_core.Engine(Journal, PageStore)` implements the single native v1
authority. The [wire contract](../../../../contracts/TRANSIT_V1.md) defines signed
operations and paged reads. Node, Station, launchers and language clients share
this definition; incompatible histories and peers are rejected.

The implemented internal transitions include bootstrap, root-authorized principal
grant/revocation, process creation, ownership, mailbox admission and termination;
resource creation/grants/associations, captured view open/close, bounded state
turns, turn permits and resource retirement/expiry; ordered outbox delivery,
effect dispatch/observation/closure and process expiry.
Signed bounded reads cover capabilities, process/resource/view metadata, current
or captured entries, associations and outboxes. They use the
[typed immutable catalog](pages.md#typed-catalog). Principal sequence,
exact-retry receipt, process metadata and accepted mailbox entry become visible
through one conditional journal append of a new root. A prepared candidate can
leave unreachable pages; it cannot advance a live process or disclose acceptance.

The `resource_read_access` capability adds a signed `read_access` observation.
Unlike metadata-only `resource`, it requires current inspect and read rights,
PID association scope and an active usable resource; it returns only metadata.
Its successful authority-tail check is the authorization point, not a reusable
grant. Core tests cover separate PID scope, read-only revocation with metadata
still readable, signature tampering, raced authority and resource retirement.

Principals use full-width value keys. Credentials bind stable roles; a separate
paginated policy root owns memberships, objects and grants. Direct-native
credential replacement retires its private role without scanning resources.
Named roles retain privileges across explicit credential rotation. Receipts are independently
addressed by principal and sequence; retry does not scan the history or evict an
older receipt. Authentication/current command permission precedes retry lookup.
Mailbox keys combine PID and per-process ordinal; input bytes and source evidence
remain retained after progress, with no resident queue proportional to backlog.

The journal entry carries the previous root and a complete constant-size head,
including a genesis fingerprint. Opening/refreshing reads the latest published
head and materializes records on demand. It relies on the trusted journal's
conditional append/record-coordinate contract; page identity checks protect
referenced content. Recovery never stages pages or runs application code.
The [Ursula integration](../../transit-backend-ursula/docs/growing.md) supplies
real conditional journal/page persistence. Each published record is a complete
root checkpoint. `allow_history_trim` in genesis is explicit application/realm
opt-in, defaulting to false. An administrative `checkpoint` records a monotonic
floor that retains its own complete publication. Maintenance verifies that intent
and a separately published root snapshot before trimming the earlier journal.
It never trims the page journal. All mailbox entries, receipts, views, outputs
and application values remain in the catalog, including old captured roots.
This is protocol-history compaction, not permission to expire or reclaim values.
Recovery reads the latest retained complete head and uses its genesis fingerprint;
it never guesses a root from page or snapshot listings.

State turns stage bounded mutations alongside process progress, output/effect
intents, closed views and retry evidence. Current resource grants are required
when disclosing a retained state receipt, including receipts whose views closed
long ago. Current graph grants apply independently of the captured resource
catalog. Views retain one catalog root, not copies of resource data.
Resource entry counts obey the public integer encoding range. A batch that would
exceed it publishes neither mutations, progress nor view closure; an atomic key
replacement at that range boundary remains valid. This is an encoding limit,
separate from resident memory or a deployment quota.

Required associations have their own index, separate from optional associations.
Dependency validation walks lifetime-owner dependencies with a visited set, so
self-owned state and cycles do not recurse forever. Genesis declares operational
budgets: 16 required resources per PID and 64 visited owner PIDs by default, each
configurable up to 4,096. These bound one validation graph, not total principals,
processes, resources or retained records. Association admission validates the
candidate graph before publication; exceeding the budget rejects the operation.
Association validation freezes an owner's required dependency topology
while another live PID requires its owned state. Otherwise a locally valid new
edge could push an existing borrower's previously accepted graph over its budget.
Borrowers must detach healthy dependencies or retire before that topology changes;
the indexed check rejects with `DependencyInUse`. Optional associations do not
add lifetime edges. Capabilities report this restriction and the configured graph budgets.
An expired/retired required dependency cannot be removed or rebound to revive
the PID. Its durable dependency evidence fences execution even before terminal
process metadata is materialized. Process lists expose recorded metadata; an
individual process read checks execution eligibility before disclosing its head
input. Inspection preserves that distinction.
Explicit resource retirement refuses active required
users; known finite expiry can close the dependency. Physical page deletion is
not implemented or authorized.

Entry reads use a caller-owned view or an explicit current resource revision.
Reads reauthorize every page and bound results to eight records. Current-resource
reads cannot silently switch revisions; captured reads keep an immutable version
while still enforcing current ownership, grants, dependencies and deadline.
Catalog continuation requires the original authority position. Filtered resource
and association pages may be empty with more scanning available; only a null
cursor means completion. Association cursors use indexed revision IDs instead of
hidden names. A final tail check rejects concurrent changes during disclosure.
Named association lookup reads one indexed key without requiring a catalog cut.
It checks PID scope and current target inspection permission; missing and hidden
associations both return null. A later grant, revocation or removal is observed
on the next lookup rather than retained in a session cache.

The additive [retained-version contract](../../../../contracts/READ_VERSIONS_V1.md)
stores a view's pre-turn catalog root under a PID/input/slot identity in the same
publication as mutations, progress and outputs. It survives view closure and
worker replacement, with bounded point/page/discovery reads. Later proposals
declare retained read dependencies for current grant, association, generation
and lifetime validation. Release keeps terminal metadata; reads cannot reopen it.
No whole resource is copied into a resident view. These roots cover a shared
catalog, however, so retention can keep unrelated physical pages alive. This
profile retains all immutable pages, including unreachable staging; it authorizes
no page garbage collection. Finite journal admission and physical-reserve proofs
do not supply selective byte accounting or automatic physical provisioning.

## Delivery and settlement

Outboxes retain stable identities and payloads. A separate pending-route index
finds the first unresolved output for a source/destination pair using one bounded
scan. Other routes can advance independently. Delivery needs the caller's current
delivery capability and destination scope; its current send permission determines
admission versus a recorded denial. Destination admission, provenance and source
resolution share one publication. An uncertain acknowledgement is retried under
the same principal sequence, without a second admission.

Delivery stages the output disposition and removal of its three pending indexes
in one bounded catalog batch. An admitted delivery includes its mailbox entry
and destination counter. The caller sequence and exact-retry receipt complete
the same batch of at most eight keys. Shared tree paths are copied once within
the batch; the existing conditional journal append publishes the decision.
A staging failure or lost page acknowledgement leaves the previous published
root authoritative, including its admission count, pending indexes and retry
identity.

Termination/known expiry fences pending work without scanning the whole backlog.
The PID's terminal fact is immediate authority; individual pending output/effect
records can still show their prior recorded phase until bounded reconciliation
materializes their disposition. Delivery cancels a terminal source's pending
output. The administrative `cancel_effect` operation cancels only a never-authorized
intent whose caller is terminal. Required-dependency expiry can also justify
explicit process expiry. No timer is needed to reject a known-expired operation.

Dispatch records one executor, attempt and reconciliation budget before I/O.
Finite callers require a finite reconciliation deadline. Observation consumes the
recorded budget; terminal result or budget exhaustion closes it, and deadline
closure rejects late observations. Previously authorized attempts can settle
after caller termination, retaining outcomes without admitting new caller work.
An executor can abandon its attempt; an administrator with effect permission
can close an orphaned attempt. Closure is local protocol evidence, not remote
cancellation. A finite process's previously issued turn permit can settle before
its settlement deadline, but cannot issue fresh outputs/effects after its work
cutoff. Ownership changes fence the old activation without renewing that permit.

The [node](../../../../apps/transit-node/docs/growing.md) exposes
signed commands, bounded queries and a separate maintenance process.
`growing.Maintenance` visits one record from a bounded catalog page per step,
rotating six families with separate finite-pass cursors. It suggests known
process/resource expiry, terminal-source dispositions, timed effect closure
and opted-in catalog/payload cleanup;
it neither stages pages nor publishes authority. Cursor loss repeats inspection,
not execution. Every signed suggestion is revalidated against current state/time.
Clock failure does not prevent terminal-source cancellation or dependency expiry
already established by recorded retirement. Unknown external attempts retain
their own settlement contract. The current scan revisits retained process/resource
metadata, so full sweep cost grows with cardinality; deadline indexes and measured
sweep-lag objectives remain scale work.

Managed creation, initialization, finite suspension/resumption, runtime binding
intents/observations, workload upgrades and fresh worker activation use the same
paged process records and conditional authority publication. The runtime
controller reconciles recorded intent through a provider; provider state never
grants execution ownership. Root-authorized principal creation rejects existing
identities. Conditional worker rotation changes the key and generation while
preserving the principal sequence and current resource permissions.

The `scoped_retry` capability permits a current PID administrator to clear a
reported handler failure using its observed generation and failed input ID.
Retry preserves the input, state revision and consumption cursor, advances the
generation and leaves ownership empty. Current lifetimes/dependencies are checked
before publication. Blocked process point reads disclose metadata without the
head payload; this does not assert that it remains executable. Fresh ownership
and an ordinary turn are required to consume the input. A runtime-bound retry additionally requires confirmed provider stop before a
fresh restart intent can be accepted.

## Verification boundaries

Core unit checks use injected journals, pages and time. Disk, HTTP, runtime and
Station schedules exercise their actual component boundaries; the
[proof ledger](../../../../docs/history/qualification/README.md) records execution and limits. A passed
in-memory transition check alone does not establish disk durability, service
availability, provider behavior or a latency guarantee.

### Immutable control metadata cache

The engine shares a 16-record resident cache for principal, process, resource,
grant and dependency/association records. Verified bytes and exact absence are
keyed by the complete immutable catalog root. A changed root clears the cache;
private candidate roots cannot authorize a read against another root. Data-entry
reads do not occupy these slots. All ordinary validation and final authority
barriers remain in place. The cache does not bound retained metadata cardinality
or keep resources alive, and it grants no permission of its own.

### Compatible catalog mutations

A candidate batches the mailbox/process pair, caller sequence/receipt pair,
view record/indexes, output indexes and effect indexes. Row changes and their
resource metadata share a bounded batch. This reduces repeated tree path copies
within one atomic operation. All input validation, current authorization and
revision checks precede authoritative publication; staged pages are not accepted
work. The existing conditional journal append publishes the complete candidate
or leaves the previous root authoritative. Collection cardinality and retention
are unchanged.
