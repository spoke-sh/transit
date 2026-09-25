# Growing authority integration

Status: M10 in development. `transit_core.growing.Engine(Journal, PageStore)` is
not yet composed into the running node or public client. The [v3 contract](../../../../contracts/TRANSIT_V3.md)
owns proposed wire types; the existing v2 engine remains the deployed profile.

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
process metadata is materialized. Process lists expose recorded metadata; an
individual process read checks execution eligibility before disclosing its head
input. Inspection must preserve that distinction when the service is added.
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

## Delivery and settlement

Outboxes retain stable identities and payloads. A separate pending-route index
finds the first unresolved output for a source/destination pair using one bounded
scan. Other routes can advance independently. Delivery needs the caller's current
delivery capability and destination scope; its current send permission determines
admission versus a recorded denial. Destination admission, provenance and source
resolution share one publication. An uncertain acknowledgement is retried under
the same principal sequence, without a second admission.

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

No running capability advertises these transitions. Query/command transport,
background disposition and terminal dependency materialization,
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

Read checks traverse more than one catalog/entry page, compare a captured version
with later committed data, reject stale cuts, expired/uncertain views, changed
ownership, revoked grants, forged queries and missing pages. Filtered discovery
crosses an empty page without disclosing hidden associations and observes removal
without stale index entries. These are internal engine proofs, not HTTP/client
or provider qualification.

Delivery/settlement checks exercise independent routes, stale prepared delivery
after grant change, denied admissions, lost accepted delivery/outcome replies,
terminal source cancellation, post-termination outcome capture, finite budgets,
late rejection and permanent process expiry. Indexed effect inspection preserves
retired callers' evidence. These internal checks use injected storage, not the
real effect connector or service deployment.
