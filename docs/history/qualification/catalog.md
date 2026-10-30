# Catalog and data lifecycles: qualification history

[Archive index](README.md) · [Tests](../../../tests/README.md)

Direct Table ownership, identities, declarations, dependencies, publication and named resources.

These records preserve their original dates, sources, failures and limits. They
do not define current interfaces or qualify later changes. Commands and then-open
work describe their recorded source; use the [task reference](../../../tasks/README.md)
and [test index](../../../tests/README.md) for current navigation.

## Bounded FIFO affinity cache — 2026-10-30

On dirty parent `d2d54bb67`, the Queue owner adds a disposable full-canonical-key
cache bound to each immutable FIFO key root. Focused checks pass forced hash
collisions, changed roots, oversized-key fallback, bounded saturation, a pinned
reader across replacement, stale handles after reuse and permanent generation
exhaustion. Four concurrent readers each perform 20,000 lookups while one writer
performs 20,000 publications and periodic invalidation. Every hit must match its
requested root and full key; completion releases every pin. This exercises the
cache's reader/writer protocol, not concurrent Queue publication.

The cache checks pass in `/var/tmp/transit-queue-affinity-third.log`; selected
Queue private-memory and malformed-replay checks pass in
`/var/tmp/transit-queue-affinity-owner-memory.log`. The expanded memory-provider
retained graph passes in `/var/tmp/transit-queue-affinity-graph.log`, including
300-byte canonical keys that bypass the cache. All 50 fast checks pass in
`/var/tmp/transit-queue-affinity-fast.log`. Initial compile failures in the tests
were corrected before these successful executions.

Disk reopen/warm-hit allocation checks, the native shared-memory ceiling and
installed-service regression have not yet run for this change. The preceding
timer-integration native result below does not qualify this additional cache.

## Queue foundation clean core failure — 2026-10-30

The committed-source core lane at pre-rebase
`52e8d40a89426db6546a611b71b6c01c60544aba` fails in the installed Station
transport-retry fixture. The assertion at `tests/runtime/station/station.py:187`
requires exactly two identical audit/reply turn request bodies. The captured
run reports request timeouts and connection closures, then reaches that failed
assertion; it does not record the body count or their digests, so the failing
conjunct and cause are not established. The test completed domain progress but
this does not waive its retry assertion. No deadline or semantic check was relaxed.

Earlier lane phases, including `check::core`, properties, delivery/resource
simulations, package checks, SDK/runtime-boundary checks and client ABI checks,
passed. The lane as a whole failed and later phases did not execute. Raw output
is `/var/tmp/transit-queue-clean-core-52e8d40a8.log`; the failed fresh checkout and
artifacts are retained at `/var/tmp/transit-ci-n7fndw1z`. This run predates the
rebase and accepted timer integration. Isolated reproduction and final-candidate
clean qualification remain open; concurrent disk work is an observation, not
an established explanation of the failure.

An isolated rerun with those same built binaries and diagnostic-only driver
changes passes the exact two-identical-bodies assertion, then fails later while
uploading a query. Its ledger head is a delayed `UQN1` self-wake at position 298;
the new query has namespace 299. The fixture pumps only the requester and leaves
that earlier ledger input unprocessed. Its 200-ms quiet check cannot exclude
later courier delivery. This second failure is recorded in
`/var/tmp/transit-queue-station-isolated.log`; it does not explain the first
retry-count failure.

The corrected driver advances an observed non-query head, then stops at the
exact requester resource and query namespace before capture. It also leaves a
valid non-query predecessor deliberately, so this progression is exercised on
every run. No assertion or deadline is weakened. Against the same original
binaries, the complete Station run passes the exact retry assertion, captured
query policy/native-grant revocation, worker/node recovery, framework services
and lifetime checks. The driver SHA-256 is
`65bc06531418948a29d9fcc7db37683582bc0b52c04846a189afa70ce9415fb7`;
raw output is `/var/tmp/transit-queue-station-exact-head.log`. This is an isolated
fixture regression, not a completed clean core lane or qualification of later
Queue code.

## Accepted Queue timer schedules — 2026-10-30

On dirty parent `e387a41ca`, accepted Queue roots replace per-event visibility
and deadline indexes with bounded delta buffers, paged pending chunks and sorted
time runs. Scheduling maintenance records its kind, input budget and complete
successor in the Queue WAL; recovery rederives it without provider writes.

The disk fixture enqueues 512 rows, freezes visibility maintenance, claims all
rows in two original selections, then ACKs and NACKs while both timer kinds have
unfinished merges and partial output. Publication revocation leaves the accepted
root unchanged. A lost accepted reply requires recovery; disk reopen reproduces
the exact root without object writes. Maintenance finishes after retirement with
no clock, preserves 510 acquired rows and the one delayed row, and becomes idle
without writes. Sealing, archival, checkpointing and actual WAL trimming preserve
the original claims and payload pages. Declaration-mismatch rejection passes.
The focused run passes in `/var/tmp/transit-queue-schedule-owner-large.log`.

The expanded retained-graph fixture covers a pending chunk, a two-input merge,
partial output and a frozen item/bitmap basis distinct from current Queue state.
Isolated scheduling traversal marks every input/output chunk and frozen basis;
full traversal then permits actual deletion of unreferenced candidates. Cold
recovery and subsequent merge completion preserve original claims, full FIFO
keys and historical blocked destinations. This memory-provider graph fixture
passes in `/var/tmp/transit-queue-schedule-graph-large-second.log`; disk recovery
is the separate fixture above. Documentation checks pass in
`/var/tmp/transit-queue-schedule-docs.log`.

A conservative reflected-schema bound permits full-width integers, populated
references, both complete merge states and the largest action variant within
22,050 of the existing 32,768 metadata bytes. A structurally valid scheduling
record with a forged sweep basis is rejected by replay without advancing state
or writing provider objects. Both pass in
`/var/tmp/transit-queue-schedule-replay-bound.log`. All 50 fast checks pass in
`/var/tmp/transit-queue-schedule-accepted-fast.log`; all 18 contract checks pass
in `/var/tmp/transit-queue-schedule-accepted-contracts.log`. Native maintenance
and collection regressions were still running when the storage slice was committed.

The native log-privilege/maintenance regression subsequently passes in
`/var/tmp/transit-queue-schedule-native.log`, against the timer-integration source
committed as `b74fee887` (before later affinity work). Stream maintenance completes
157 units with a 7,010,576-byte peak; Queue physical maintenance completes 223
units with a 19,215,663-byte peak, below the unchanged shared 32-MiB limit. Clock
refusal permits preceding physical timer cleanup but no lease settlement;
trusted lower-bound expiry, reserved control capacity, restart and original
claim payloads after trimming pass. The native Table/Stream collection regression
also passes in `/var/tmp/transit-queue-schedule-native-collection.log`: 11 physical
collection passes retain pins and original outcomes while reclaiming obsolete
allocations, including restart and trimmed-history cases. That native fixture
does not exercise Queue merge closure; the expanded Queue graph fixture above
owns that coverage. A new installed timer-integration run remains open.

Initial fixture attempts refused undersized payload/tail buffers and exhausted
the previous smaller graph traversal allowance. Those test bounds were adjusted
for the added population; runtime row limits, metadata size and maintenance
resident budgets were not increased. These component checks do not establish
installed scheduling behavior, final clean qualification or completion of Queue
affinity, terminal payload cleanup or atomic DLQ transfer.

## Final Queue delta persistence — 2026-10-30

On dirty parent `b97f41a18`, the disk scheduling fixture persists 100 private
appends as one final active buffer. From that retained root, another 158 appends
seal a chunk and leave a two-entry delta. Two cold private derivations produce
the same root without underlying writes. Selecting final buffer names then
persists exactly three additional objects: the sealed chunk, its directory page
and the final delta. Disk reopen verifies the earlier and later roots, confirms
the earlier accepted buffer is retained, and finds no intermediate delta object.

The selected candidate-object and scheduling tests pass in
`/var/tmp/transit-queue-buffer-persistence.log`. All 50 fast checks pass in
`/var/tmp/transit-queue-buffer-persistence-fast.log`. The ordinary `persist`
operation continues to select every candidate object; its existing paged-root
and bounded-reuse checks pass in the same selected test run. The new selection
does not delete provider objects or grant physical collection authority.

This qualifies private scheduling composition and persistence, not an accepted
Queue WAL transition. The Queue owner has not yet adopted the new scheduling
roots or final-buffer selection. No new installed or clean-lane result is claimed.

## Queue scheduling rebase qualification — 2026-10-30

At `1766f70a706443ca59c81bd83c72d150c0aba8dc`, the feature branch is rebased
onto `54e176fd0` using author-date committer dates. Main's non-Table rejection
fixes supersede the earlier fixture-only commit, which is dropped. The rebase
also includes main's batched immutable-object publication and historical-catalog
changes without replacing the branch's current-v1 definition.

All selected Queue tests, Stream partition tests, tree-store and disk-object
tests pass in `/var/tmp/transit-queue-schedule-rebased-storage.log`. All 50 fast
checks pass in `/var/tmp/transit-queue-schedule-rebased-fast.log`, and all 18
contract checks pass in `/var/tmp/transit-queue-schedule-rebased-contracts.log`.
These are workspace regressions at the committed rebased source. They are not
installed-service reruns or clean-lane qualification of that revision. The
separate clean core run still targets pre-rebase `52e8d40a8` and remains open.

## Private Queue scheduling roots — 2026-10-30

On dirty parent `11881ca08`, `QueueSchedule` passes a disk schedule that seals
three pending chunks (including duplicate events and a far-future time bucket),
retains a partial active buffer, and completes 78 bounded maintenance units.
Seventeen input entries bound each merge step. A one-page cache and repeated
disk reopen preserve reads during unfinished merges, two final run levels and
the original pre-maintenance root. Appending while a merge has private output
preserves its frozen inputs and makes the new event separately readable.
Unchanged completed maintenance performs no object writes.

A separate schedule seals one delta into 256 distinct pending time buckets.
After clearing its one-page cache, a six-unit read budget finds a later bucket
without scanning the preceding pending prefix. A failed partial seal preserves
the complete earlier active buffer. Negative cases refuse an undersized read
budget, inconsistent pending counts, malformed active metadata, wrong ownership,
zero maintenance budget and missing chunk bytes. Budget refusal does not return
an empty result or publish a private candidate.

Focused scheduling and timer checks pass in
`/var/tmp/transit-queue-schedule-final.log`; the first disk schedule also passes
in `/var/tmp/transit-queue-schedule-first.log`. All 48 fast checks pass in
`/var/tmp/transit-queue-schedule-fast.log`, and all 18 contract checks pass in
`/var/tmp/transit-queue-schedule-contracts.log`. The diagnostic inventory records
the reviewed private storage owner and refusal cases.

These checks cover private composition with a deterministic fixture filter.
Real frozen Queue filtering is covered separately above the storage boundary in
the preceding merge record. Accepted Queue scheduling roots, batched buffer
persistence, native maintenance, retained graph integration and their WAL fault
schedules remain open. The separate core lane at `52e8d40a8` is still running;
it does not qualify these later helpers or the newly fetched `origin/main`.

## Resumable private Queue timer merges — 2026-10-30

The two-run merge and frozen Queue-state filter pass workspace checks on dirty
parent `52e8d40a8`. A disk schedule merges 2,000 input entries in 55 steps capped
at 37 entries each, retaining 1,200 distinct selected events and accounting for
800 duplicate/filtered entries. It uses a one-page cache, serializes scalar
progress between steps, and reopens disk storage every eleven steps. Both an
earlier output prefix and the completed output retain their exact ordered rows.
Separate cases split duplicates across one-entry steps and prove empty filtered
and empty-input completion.

Private candidate replay derives identical roots with cold scratch and then
passes a sealed backing-allocation check after warmup, without underlying object
writes. This allocator claim covers merge scratch, not provider allocations.
Explicit persistence makes the derived output reachable. Index-budget and filter
failures preserve the old progress; missing directory entries, wrong ownership,
invalid counters, zero work budgets and missing saved-position fields refuse.
Frozen real Queue roots separately preserve earlier matches after disk reopen,
ACK, expiry and renewal. Older epochs and blocked retries filter out; future
epochs and inconsistent item/bitmap state refuse instead of disappearing.

Evidence: `/var/tmp/transit-queue-time-merge-integrated.log` passes all selected
Queue/Stream partition, timer and Queue-index tests;
`/var/tmp/transit-queue-time-merge-final.log` repeats the affected merge/index
checks after making saved progress fields mandatory. All 48 fast checks pass in
`/var/tmp/transit-queue-time-merge-fast-final.log`, and all 18 contract checks
pass in `/var/tmp/transit-queue-time-merge-contracts.log`. The first compile failed
because the test referenced an unexported helper; its corrected direct import
passes. The first fast run required recording the reviewed diagnostic inventory.

These are private storage/transition checks, not accepted timer-run scheduling,
WAL merge publication, retained graph integration or a new clean-lane result.
The isolated core lane at committed `52e8d40a8` is still in progress when this
record is written and does not include this merge implementation.

## Paged Queue timer-run directories — 2026-10-30

`QueueTimeDirectory` passes its focused disk schedule on dirty parent `6cc0f57ec`.
Forty-nine `.tseg` chunks contain 3,136 ordered events, exceeding both the physical
chunk bound and the one-page cache. Cold reopen verifies every event under the
current root and an earlier 21-chunk root. Exclusive lookup finds both containing
and following chunks. Private index-budget refusal leaves the staged next chunk
outside the selected root, and overlap refuses before publication.

Directory audit completion requires actual exhaustion after contiguous counts.
Negative cases cover wrong owner/bucket, reduced total rows, a missing first
entry, an extra entry beyond declared bounds and foreign descriptor definitions.
Failures preserve the preceding audit cursor and do not mark it complete.
Chunk bodies are separately loaded and verified in the disk schedule; directory
audit alone does not qualify their contents.

Evidence is `/var/tmp/transit-queue-time-directory-first.log`. All 48 fast checks
and all 18 contract checks pass in
`/var/tmp/transit-queue-time-directory-fast.log` and
`/var/tmp/transit-queue-time-directory-contracts.log`. These are workspace checks
for private run directories, not accepted Queue schedule publication, merge
recovery, retained graph integration or a clean lane.

## Queue pending timer buffers — 2026-10-30

The `QueueTimeBuffer` codec passes focused checks on dirty parent `1d62204ed`.
A 256-entry buffer accepts reverse-order insertion across time buckets, refuses
overflow and duplication without eviction, and survives disk reopen with exact
copied scalar output. The encoded bound is 6,272 bytes. A 128-entry buffer seals
into four sorted `.tseg` chunks and reconstructs the same event sequence.
Negative cases reject foreign owner/kind/definition, invalid lease metadata,
corruption, missing objects, reserved bytes, duplicate ordering, truncation and
insufficient output. Clearing permits explicit reuse but an empty buffer cannot
be staged as a nonempty artifact.

Focused buffer/run checks pass in `/var/tmp/transit-queue-time-buffer-final.log`;
all 48 fast checks pass in `/var/tmp/transit-queue-time-buffer-fast.log`, and all
18 contract checks pass in `/var/tmp/transit-queue-time-buffer-contracts.log`.
This is codec composition, not an accepted Queue transition. Pending directories,
publication, merge progress, collection and proof of removing per-item timer
index rewrites remain integration work. No new clean lane is claimed.

## Bounded Queue time-run codec — 2026-10-30

The physical `QueueTimeRun` codec passes focused storage checks on dirty parent
`dc8a70400`. A 1,024-entry sorted chunk spans multiple row groups, preserves
full-width scalar metadata across disk reopen, and verifies its exact descriptor
and physical identities. It encodes to 100,608 bytes and peaks at 592,088 bytes
of codec allocation under an explicit 4 MiB budget. Five repeated loads reuse
a warmed scratch arena with a sealed backing allocator; this excludes provider
I/O allocations and is not a claim about whole-Queue steady-state allocation.

Negative cases reject duplicate/reordered entries, mixed buckets, a changed
partition or object, mismatched kind or bounds, missing objects, corrupted payload
bytes, foreign descriptor definitions, nonzero reserved bytes, truncation and
insufficient output. The largest unsigned deadline and epoch round-trip exactly.
Retained scalar output survives scratch disposal and later loads.

Evidence is `/var/tmp/transit-queue-time-run-final.log`. All 48 fast checks pass
in `/var/tmp/transit-queue-time-run-fast.log`; all 18 contract checks pass in
`/var/tmp/transit-queue-time-run-contracts.log`. These workspace checks cover the
codec, not accepted Queue publication, run directories, resumable merge,
stale-entry filtering, retained run collection or a new clean lane. Runtime
scheduling still uses the previously qualified paged directories and caches.

## Bounded Queue visibility wheel — 2026-10-30

`a90c1f1bc490953e2fc9b0d7e41f186b29f81fad` adds the eight-level radix wheel
and its bounded eligibility prefix to real claim selection. Standalone checks
cover every level through the largest unsigned millisecond value, one-unit
resumable cascades, cancellation/reuse, backward-time refusal and permanently
retired generations. A 3,000-step finite reference compares interleaved insert,
cancel, clear and clock-jump outcomes. The first standalone compile rejected an
untyped left-shift operand; the corrected fixed-width operand passes.

The disk Queue schedule uses one cached entry with two eligible heads and a
one-unit declared timer budget. A cursor beyond that prefix finds the other head
through durable storage. Incomplete cascading also finds due work through the
directory. Twenty warm future-head observations perform no object range reads
and pass the sealed backing allocator. Original empty claims, uncertain claim
acceptance and cold replay remain exact. All Queue/Stream partition tests pass in
`/var/tmp/transit-queue-wheel-integration-final.log`; all 48 fast checks pass in
`/var/tmp/transit-queue-wheel-fast.log`. Initial standalone failure/success logs
are `/var/tmp/transit-queue-wheel-first.log` and
`/var/tmp/transit-queue-wheel-second.log`.

The ReleaseSafe native schedule passes with 157 Stream units and 220 physical
Queue units. Peak private allocations are 6,867,364 and 18,317,753 bytes,
respectively, under the shared 32 MiB budget. Its log is
`/var/tmp/transit-queue-wheel-native.log`, compiled from dirty parent `a8aa8331c`
with the code subsequently committed as `a90c1f1bc`.

The installed Queue schedule passes on that committed revision with `dirty:
false`: 280 signed HTTP calls, three uncertain replies and 60 expiry probes.
Retirement, expiry while flushing is disabled, later physical tiering and repeated
SIGKILL/restarts preserve original claims and payloads. Evidence is
`/var/tmp/transit-queue-wheel-installed.log`; the successful private installation
`/var/tmp/transit-table-queues-2daltg0t` was removed by the harness. SHA-256 values:

- Node: `28fd08936a0d94c7f47bdf9d218c08999c6f94f32b0a832adb4948b81f6d0488`.
- Caller: `4524956758305051c2c49c2aadc6dc6b9e6753518974d6d4241935d799e336ce`.

The wheel owns only visibility/retry wakeups. Exact lease expiry remains with
the separate fenced heap and durable transition. These workspace checks do not
qualify time-bucketed immutable runs, lock-free affinity, terminal cleanup, DLQ
transfer, mixed transactions, whole-claim zero allocation or new clean lanes.

## Historical Queue destination closure — 2026-10-30

The exact-definition resolver and retained graph extension pass focused storage
and catalog checks on dirty parent `140be1469`. The graph fixture exhausts
leases through NACK and expiry, then traverses the item directory in isolation.
It retains the original DLQ definition and that definition's own destination,
without a source declaration or catalog root masking either edge. A separately
staged later retirement is not substituted. Full traversal, actual removal of
unmarked objects and owner reopen preserve original claims, blocked destinations
and payloads. The fixture uses the memory object provider; the declaration
resolver separately runs across disk reopen.

Negative cases reject missing bytes, changed object/revision attribution, a
retired target, a Stream target, foreign contract bytes and truncated bounds.
Each graph step emits at most three children. Logs are
`/var/tmp/transit-queue-destination-storage-final.log` and
`/var/tmp/transit-queue-destination-graph-final.log`. All 48 fast checks pass in
`/var/tmp/transit-queue-destination-fast.log`. The ReleaseSafe native direct-data
collection regression also passes in
`/var/tmp/transit-queue-destination-native-collection.log`; that existing disk
schedule verifies the collector integration, not a DLQ payload transfer.

These are workspace checks with existing caches. They establish historical
definition retention and refusal, not current destination append authority,
terminal source reclamation, atomic transfer or clean-lane qualification.

## Bounded active-lease cache — 2026-10-30

`140be1469` adds the exact-lease heap and binds each cached prefix to its durable
deadline-directory root. The storage test uses a one-entry cache with two active
leases, then a larger cache with a one-entry declared refill budget. Renewal
invalidates the old deadline; expiry, an uncertain publication, cold recovery,
retirement, physical sealing and WAL trim preserve original claims. Twenty warm
idle checks make no new object range reads and pass a sealed backing allocator.
Current authority denial and unavailable time still refuse on that warm path.

The focused heap and all Queue/Stream partition tests pass, as do all 48 fast
checks. The ReleaseSafe native `log privileges` schedule passes with 157 Stream
maintenance units and 220 physical Queue units; measured peak private allocation
is 6,867,364 and 17,799,533 bytes respectively under the shared 32 MiB budget.
Its log is `/var/tmp/transit-queue-heap-native.log`, compiled from dirty parent
`5bf910f71` with the code subsequently committed as `140be1469`.
The storage log is `/var/tmp/transit-queue-lease-heap-final.log`; a repeat of the
same focused command also returns zero. Fast-check timings are retained in this
worktree's `.cache/checks/fast.json`.

The no-allocation claim covers a retained storage owner after warmup. The native
driver disposes ready workspaces between units and therefore discards this cache.
These checks do not establish allocation-free background maintenance, a timing
wheel, time-bucketed runs or lock-free FIFO affinity. They are workspace checks,
not new clean-lane qualification.

## Automatic local Queue maintenance — 2026-10-30

`9c1c5f0169737ecca5a6981a251d5ada2b30a0f1` shares bounded catalog maintenance
between Tables, Streams and Queues. Each log kind retains at most one recovering
workspace and 64 disposable root hints under the existing 32 MiB aggregate
budget. Queue units seal accepted batches, archive/checkpoint/trim physical WAL
and expire one earliest accepted lease under current native maintenance rights.
Expiry does not grant payload retention permission.

The native disk schedule passes with two Queue partitions alongside existing
Streams. Forty separate appends exceed the 16-record replay unit. Missing time
refuses expiry; an interval spanning the deadline leaves the two current leases
acquired; moving its lower bound to the deadline expires them under ordinary
quota exhaustion. Backoff remains anchored to the accepted deadline. Disposal
releases all private bytes; cold reopen after actual WAL trimming retains original
claims and payloads. The ReleaseSafe run records 220 physical Queue work units
and 17,789,221 peak private bytes; the Stream arm records 157 units and 6,867,356
peak bytes. These measurements exclude provider caches and whole-process memory.

The first combined native run exposed an old fixture ordering that left an active
Queue with no trusted clock during the Stream arm. It correctly refused with
`QueueTimeUnavailable`; the fixture now separates those phases. A subsequent
review found that sealing after expiry had recorded retirement reused a fresh
operation cut and refused `LogDeclarationConflict`. The expanded disk test
reproduced that failure, then passed with a retained-data cut for physical
sealing. Fresh claims still refuse. Archive, checkpoint, WAL trim and cold reopen
preserve the original selection after this ordering.

Successful component logs are `/var/tmp/transit-queue-maintenance-catalog.log`,
`/var/tmp/transit-queue-retired-flush-final.log` (all Queue/Stream partition tests)
and `/var/tmp/transit-queue-maintenance-fast-final.log` (48 checks).
`/var/tmp/transit-queue-maintenance-native-final.log` is the ReleaseSafe native
schedule on dirty parent `c3613ee70`, before the subsequent retired-flush fix;
`/var/tmp/transit-queue-maintenance-native-second.log` is its Debug run.
The preserved initial clock failure is
`/var/tmp/transit-queue-maintenance-native-first.log`; the deliberate retirement
regression failure is `/var/tmp/transit-queue-retired-flush-red.log`.

The final installed Queue schedule passes on committed `9c1c5f016` with
`dirty: false`: 280 signed HTTP calls, three uncertain replies and 60 expiry
probes. It retires the Queue, kills/restarts the node, recovers the original
operations, and enables expiry with physical flushing disabled. Both original
leases become available while the ACKed row stays ACKed. Only then does it enable
sealing/archive work; one segment contains all three rows. A further restart
preserves original outcomes, payloads and saved request bytes. Evidence is
`/var/tmp/transit-queue-maintenance-installed-final.log`. The private successful
installation `/var/tmp/transit-table-queues-93o98aua` was removed by the harness.

The combined installed Table/Stream maintenance gate also passes on that same
committed revision and binaries. It verifies 258 original Table rows, 48 concurrent
writes, pressure on ordinary request admission, reserved original-outcome recovery,
archive/checkpoint convergence and retained cuts across restart. Two Stream
partitions compact 16 rows to two visible rows after seven probes while original
reads still return all 16. Evidence is
`/var/tmp/transit-log-maintenance-combined-installed.log`.

Both installed runs record SHA-256 values:

- Node: `ceefc1f6a58b3727fcfdf2cbd3b9438957d947b4e6106884bc66547860676d2d`.
- Caller: `c9aca2bfbf4675d6b09143f870cef8d4f665f2335658c9270bb2329e5eaf8f56`.

These are committed-source workspace checks with existing build caches, not
isolated clean lanes. They do not qualify a hierarchical timing wheel, bounded
lock-free affinity, far-future runs, terminal payload cleanup, DLQ transfer or
mixed transactions. The earlier Stream clean-core result does not qualify these
later Queue changes.

## Signed Queue service, typed recovery and installed restart — 2026-10-30

`46e5e4da1` adds the signed Queue action and shared typed client. The focused
native policy schedule passes with real native registration and grants: lost
enqueue, claim and ACK replies retain original identity; renewal fences the old
receipt; NACK preserves requested visibility; an originally empty claim stays
empty after visibility advances. Owned decoded pages survive later calls, and
expired-but-unreassigned work reports acquired/expired without authorizing
settlement. A revocation after serialization suppresses terminal-page disclosure.
The host-lock check confirms Queue payloads and declaration edits select the same
object stripe. Independent Python signing vectors bind the complete Queue claim;
saved work rejects missing/foreign definitions.

The installed ReleaseSafe schedule passes 25 signed HTTP calls on physical local
storage. It selects offsets 0 and 2 from two FIFO keys, leaving offset 1 blocked
behind its head; after ACK it selects that successor. The proxy corrupts accepted
enqueue, claim and ACK replies, and the caller preserves unknown outcomes and
inspects the original operations. DROP followed by node SIGKILL/restart preserves
the original saved bytes, producer receipt, claim, ACK and payload pages. Fresh
claims on the retired declaration refuse. The caller issues no actor data command.
The standard direct-service gate now includes this isolated Queue schedule.

Installed evidence is `/var/tmp/transit-queue-installed-http-final.log`, with
private runtime files in `/var/tmp/transit-table-queues-wba_3w0q`. It records dirty
parent `88b41d089018e0e246c623a507bb94922b64b3f0` and binary SHA-256 values:

- Node: `205ca0086d1a2263453cf7a47d075660a8cc64a9826775e1ab07168011b781d2`.
- Caller: `9f1c98c175f125230ebb8769e0c9d789114dd1f32bc0cd693f2f3ed5c463a1d6`.

Other successful logs are `/var/tmp/transit-queue-native-policy.log`,
`/var/tmp/transit-queue-host-lock.log`, `/var/tmp/transit-queue-native-catalog.log`,
`/var/tmp/transit-queue-catalog-full.log` (full catalog suite),
`/var/tmp/transit-queue-data-client-final.log`,
`/var/tmp/transit-queue-native-fast.log` (48 checks),
`/var/tmp/transit-queue-native-contracts.log` (18 checks) and
`/var/tmp/transit-queue-native-docs.log`. The first installed build failed on an
incorrect fixture URL field; the corrected fixture uses the public client's
`url` field. That failed build remains `/var/tmp/transit-queue-installed-http.log`.

This qualifies standalone signed operations. It does not qualify automatic
Queue expiry scheduling, timing-wheel/affinity behavior, terminal cleanup, DLQ
transfer, mixed transactions or a final committed-source clean lane. The earlier
Stream clean-core result does not extend to this Queue change.

The subsequent default direct-service gate also passes on committed
`056be8a68a24e75f4447d540b1938042c20afd86`: 2,055 Table/Stream HTTP calls followed
by the isolated 25-call Queue schedule. The latter records `dirty: false` and
the same binary hashes above. The log is
`/var/tmp/transit-queue-direct-service-regression.log`; this is a committed-source
workspace run, not an isolated clean lane with empty build caches.

## Queue catalog composition and shared identity — 2026-10-30

The Queue catalog composition passes its disk test, the original Stream
composition regression, Queue reservation tests and all 48 fast checks
(`/var/tmp/transit-direct-queue-catalog-final.log` and
`/var/tmp/transit-direct-queue-catalog-fast.log`). Claims require both read and
acquire rights; original claim inspection and payload pages cannot bypass
revoked acquire rights. Settlement requires its separate privilege. Revocation
on the final disclosure check frees already copied page output.

Enqueue retries, original claim payloads and ACK outcomes survive compatible
ALTER, DROP, closing the remaining accepted lease, full disk reopen and loss of
the trusted clock. One-record recovery returns explicit incomplete progress.
Retired declarations reject fresh claims. The response validator rejects omitted
rows and incorrect byte totals. Disk reservations reject changed claim limits,
duration, partition, definition, settlement action or extension deadline and
exclude Table/Stream use of the same operation identity. Cached owners retain
neither request scratch nor the request's clock capability.

This qualifies internal catalog composition with injected current-policy guards.
It does not qualify native signed Queue dispatch, installed HTTP, automatic
expiry scheduling, DLQ transfer or mixed transactions.

## Original Queue claim pages and observed leases — 2026-10-30

`0ff275765` passes the Queue and Stream storage regression, the protocol package
suite, the retained Queue graph schedule, all 48 fast checks and all 18 contract
checks. Claim pages retain caller-owned original rows across scratch reuse,
later appends and multiple payload batches with one tail slot. Row and byte
budgets preserve exact selection ordinals and distinguish a final data page
from an empty terminal page. Too-small byte budgets advance no cursor.

Current observations distinguish live, expired, unavailable and fenced original
leases without substituting another holder's claim. Tests expire and reassign
work, observe with no clock, reject forged receipts, and revoke authorization
after buffering and on terminal or originally empty reads. Disk reopening after
retirement preserves ACKed original payloads. The collector schedule deletes
unmarked candidates, checkpoints and trims the WAL, then reads the original
ACKed payload through its frozen selection and archive coverage.

Executed logs are `/var/tmp/transit-queue-claim-pages-final.log`,
`/var/tmp/transit-queue-claim-pages-collection.log`,
`/var/tmp/transit-queue-read-contract-final.log`,
`/var/tmp/transit-queue-read-storage-regression-confirmed.log`,
`/var/tmp/transit-queue-read-fast.log` and
`/var/tmp/transit-queue-read-contracts.log`. The first protocol invocation used
an unsupported test-filter option; the full package invocation passed. These
checks qualify storage reads and neutral observation shapes, not installed Queue
admission, automatic scheduling, DLQ transfer or common transactions. A page's
observed lease status does not authorize a later settlement.

## Clean core qualification of the Stream maintenance slice — 2026-10-30

Committed source `f5c7cc0861d5b45b13d37d1c0d6e01438b8d40d7` passes
`just ci clean --lane core` in a fresh checkout with no inherited workspace
build outputs. All 28 tasks complete successfully in 5,293.93 seconds, including
native component/storage collection checks, 43 standalone packages, Zig SDK and
runtime distribution boundaries, client ABI, Station, disk recovery, service,
authorization, runtime upgrade, caller, inspection and state schedules.

The execution log is `/var/tmp/transit-stream-clean-core-sparse.log`. Completion,
source, toolchain and per-task evidence are retained in
`/var/tmp/transit-m6-qualification-65f9eba22/.cache/ci/clean/f5c7cc0861d5-transit-ci-isdi8jnl/`;
`core.meta.json` records `dirty: false`, `completed: true` and 28 results.
The shared definition is
`342c874ab8c989576b91b8cde9c8d5f0023ac6a51f0435b04963203d38c41b3d`.

This qualifies the committed Stream maintenance/rewrite slice and its corrected
derived fixtures. It does not qualify the later Queue implementation, all other
clean lanes, or complete Milestone 6. The earlier failed clean attempts remain
failure evidence; they are not reclassified by this successful run.

## Fenced Queue settlements and bounded expiry — 2026-10-30

`ac52c941d` passes the combined Queue and Stream partition suites, the focused
Queue retained-graph schedule and all 48 fast checks. ACK, NACK and renewal
publish their original outcomes with complete Queue successors. Disk tests lose
renewal and ACK replies, recover without object writes, fence the old renewal
receipt, ACK through cold sealed payload placement, advance exactly one FIFO
head and retain retry backoff and attempt/epoch increments. Compatible retired
declarations can settle already accepted work; new claims refuse. Accepted
settlements remain recoverable after retirement, expiry and restart with no
available clock, while current authorization still governs disclosure.

Publication rejects an interval spanning expiry and a definitely expired lease.
One-step expiry ignores the superseded renewal deadline, loses an accepted
expiry reply and recovers it from disk. Each step advances exactly one WAL record
even after a large clock jump. Backoff remains anchored to the accepted deadline;
exhausted work stays available but blocked, with no terminal or DLQ claim. Backward
and unavailable time refuse new expiry work.

Review found that Queue control candidates also needed to load and verify the
complete immutable declaration. Claims, settlements and expiry now reject
structurally valid metadata with a fabricated revision before acceptance. The
regression keeps the original root and WAL frontier unchanged. The collection
schedule adds ACK, NACK and expiry before sealing, checkpointing and trimming;
after reclaiming private objects, it preserves original selection directories,
the remaining FIFO heads and available/acquired/acked bitmap sets.

Executed logs are `/var/tmp/transit-queue-settlement-declarations-final.log`,
`/var/tmp/transit-queue-settlement-collection-final.log` and
`/var/tmp/transit-queue-settlement-fast-final.log`. Earlier focused settlement
and expiry runs also passed. These are storage-owner checks, not installed Queue
admission, automatic timer-wheel/affinity scheduling, current lease inspection,
DLQ transfer or mixed transaction qualification.

## Durable original Queue claims — 2026-10-30

`d1bc4cb83` adds accepted claims to the shared Queue WAL owner. The disk test
loses a claim reply, reconstructs the exact selection without object writes,
preserves empty-claim retries after more work becomes eligible, and reopens with
authoritative time unavailable. Original leases, acquired state, deadlines and
attempts remain unchanged. A delayed FIFO head excludes its successor while an
unrelated key is claimed. Competing owners must recover the newer accepted root
before selecting work.

Publication refuses unavailable time, an interval spanning lease expiry and a
definitely expired lease. Active-capacity pressure and backward time accept no
empty outcome. A canonical selection artifact containing an ineligible FIFO
successor is rejected during replay even though its format and WAL envelope
validate. The first capacity fixture specified `claim_rows > active_leases`,
which correctly failed declaration validation; the corrected fixture uses the
existing declaration invariant and passes its time/capacity assertions.

The Queue graph schedule now claims sixteen distinct 300-byte keys, appends
later input, seals payloads, checkpoints and trims the WAL. After deleting
unmarked objects it reopens the accepted state and original claim, with all
sixteen acquired bits, remaining available bits and FIFO heads intact. The
original selection's earlier batch directory remains marked independently of
the current directory.

Logs are `/var/tmp/transit-queue-partition-claims-final.log` (the invalid
capacity-fixture attempt), `/var/tmp/transit-queue-claim-time-stream-regression.log`
(corrected capacity test and full Stream partition regression),
`/var/tmp/transit-queue-claim-refusals.log` (competing-owner and forged-selection
checks), `/var/tmp/transit-queue-claim-collection.log` and
`/var/tmp/transit-queue-claims-fast.log` (48 checks passed). These storage checks
do not qualify installed Queue operations, current lease inspection, settlement,
expiry scheduling, timing wheels, DLQ transfer or common transactions.

## Atomic Queue enqueue and retained scheduling state — 2026-10-30

`b72cec81e` passes the pinned-shell Queue partition suite and the catalog's
focused Queue graph test. Twelve accepted batches span thirty-six offsets with
one resident index page and one tail slot. The disk schedule loses an append
reply, recovers its exact producer outcome, reopens every handle and replays one
record per step without object writes. FIFO links and availability bits survive
sealing, archive/checkpoint, WAL trimming and a second disk reopen. Original
producer retries remain exact and current authorization still applies.

Candidate-object quota pressure and authorization revoked before publication
leave the WAL frontier and accepted root unchanged. A validly encoded record
with a false scheduling count rejects during full candidate reconstruction,
without writing objects or establishing readiness. The retained-graph test uses
twenty-four distinct 300-byte collation-aware keys, limits each graph step to at
most three child jobs, deletes unmarked candidate objects and then recovers the
same accepted root without writes. All live FIFO heads and bitmap states remain
readable after collection.

Logs are `/var/tmp/transit-queue-partition-enqueue-complete.log`,
`/var/tmp/transit-queue-partition-collection.log` and
`/var/tmp/transit-queue-owner-fast.log` (48 checks passed). The first enqueue-test
compile exposed a shadowed helper name; the corrected test is included in the
successful source. The Stream partition regression also passes with the new
mandatory Queue root field. Earlier `5e35943dc` separately passes four private
candidate-overlay tests, including zero allocations after initialization, full
key collision resolution, exact rederivation and retry after a lost object reply
(`/var/tmp/transit-queue-candidate-objects-final.log`).

These checks qualify storage enqueue and its reachability edges. They do not
establish durable claim/settlement publication, installed Queue admission,
timing-wheel/affinity scheduling, DLQ transfer or mixed transactions. The graph
conservatively refuses collection of a recorded DLQ block until historical
destination dependency closure is implemented.

## Queue index and original-selection candidates — 2026-10-30

`fcb583b66` and `aefa35c4c` pass the pinned-shell Queue item, index and selection
suites. Disk-backed candidate indexes use one resident page, span forty offsets,
and preserve earlier roots. The schedules cover collation-equivalent FIFO keys,
delayed heads, unrelated-key claims, multiple claims from one batch, head
advancement across batches, disjoint bitmap audits, exact terminal counts,
expiry backoff and staging-budget refusal. Foreign claim targets reject.

Pure transitions check renewal fencing, expired-but-unreassigned refusal,
uncertain clock intervals, checked deadline/counter overflow and exhausted work
remaining blocked. A DLQ block retains its exact destination definition across
later policy edits. Selection artifacts reopen with original leases and placement
metadata, reject changed row selections under an original receipt, and reject
duplicates, truncation, foreign/missing definitions and alternate JSON array
shapes. Empty claims have no selection artifact.

The first selection test exceeded its 64 KiB parsing scratch buffer while the
shared JSON parser built a dynamic tree before typed decoding. The final reader
decodes fixed fields and checks the public encoder's canonical bytes; the same
scratch bound now passes. Its combined Queue test executable SHA-256 is
`bbacc5c7961f68ab4cedc3c6a4cf2cd3b8b1388b75fa1a82e46c6f19858a305f`.
Logs are `/var/tmp/transit-queue-index-fenced.log`,
`/var/tmp/transit-queue-selection.log` (failed),
`/var/tmp/transit-queue-candidates-final.log` and
`/var/tmp/transit-queue-selection-fast.log` (all 48 fast checks passed).

These are candidate/index/format checks. They establish neither accepted Queue
WAL transitions nor installed claims, timer-wheel/affinity scheduling, DLQ
transfer or mixed transaction execution. The shared log-owner refactor
`a66ac8042` separately passes the Stream partition suite; Queue instantiation
still rejects until its state joins publication and recovery.

## Automatic local Stream maintenance — 2026-10-30

The installed signed-caller schedule committed as `5aeca56fe` passes in
ReleaseSafe. With maintenance disabled, two partitions expose eight original
rows each. Enabling the background scheduler converges after seven observations
to one row per partition, at original offset seven. Every observation also
checks all sixteen rows through the old read pins and recovers unchanged
producer receipts from saved append bytes. SIGKILL and fresh-process restart
preserve both views and the original outcomes. Temporary observation pins close
explicitly. The existing Table maintenance target now runs the Table and Stream
schedules sequentially; this focused invocation executed only the Stream arm.

The node and caller SHA-256 values are
`c08b5d219f3c5ff76058afb2db94852f353c36cd3b2f7c865bd6be11235a1672` and
`5e0296045d029d60629913ca75066dc0ed127017b64037fe5a8fdf23d82d80b6`.
The log is `/var/tmp/transit-stream-installed-maintenance-final.log` and records
the working source at `77d5f858b`, exact toolchain and numeric node observations.
An earlier compile attempt failed on a shadowed fixture declaration; the caller
was corrected before this successful execution. These results establish public
visibility and caller recovery, not physical reclamation, full clean-lane
qualification or Queue execution. Physical reclamation is covered separately
below.

The sparse-rewrite extension committed as `91575f785` passes the same native
disk schedule, now including sparse placements in both partitions and cold reads
of their original row ordinals. It completes **205 units** with **20,271,578 peak
private allocated bytes** inside the unchanged 32 MiB budget. All accepted
rewrite, compaction and archive targets settle. Its executable SHA-256 is
`61b98ca8c201c484e6b88d1ccb51584d6c188cdabd55d3f7067303e93ff5d3d3`;
the log is `/var/tmp/transit-stream-sparse-native-maintenance.log`.

The focused storage suite also passes sparse and empty placement reconstruction,
complete/sparse cache coexistence, original identity conflicts, omission checks
against exact visibility, lost start/rewrite replies, disk reopen, fixed upper
bounds despite later input, old read pins and repeated compaction across empty
placements. Retirement cancels unpublished rewrite progress. A replay negative
control stages a valid sparse segment with an altered surviving value; recovery
rejects it and keeps the owner unready. Work-budget refusal leaves the accepted
root unchanged. Logs are `/var/tmp/transit-stream-sparse-storage-final.log` and
`/var/tmp/transit-stream-sparse-restart.log`. All 48 fast checks and all 18 contract
checks pass after regenerating the reviewed diagnostic inventory. This evidence
does not establish installed-loop, clean-lane or Queue execution qualification.

The first extended ReleaseSafe collection run passed two of its three disk
schedules but failed the new rewrite/retention schedule. It exposed a missing
edge: read pins retained old segment objects without retaining the segment
directory pages needed to locate them after placement changed. `087160eeb`
adds a bounded directory walk, and the focused Debug disk schedule passes with
an explicit old-directory assertion. Its five collection passes take
75/672/673/722/1,106 steps and reclaim 3/295/233/271/510 allocations. Old complete
placements remain while a read pin or recovery baseline requires them; release
plus a later checkpoint permits reclamation, after which a cold read of the
current sparse placement and original append receipt still succeeds. The test
uses an explicit trusted fixture guard; signed policy is qualified separately.
The successful executable SHA-256 is
`2ec8c23662fa87f112e1cb3d9cbce272e86b003f93bf54744f07e42f0f042f9b`.
Logs are `/var/tmp/transit-stream-sparse-native-collection.log` (failed) and
`/var/tmp/transit-stream-sparse-collection-directory.log` (passed). The focused
ReleaseSafe rerun also passes with the same five collection counts; its log is
`/var/tmp/transit-stream-sparse-collection-directory-safe.log` and its executable
SHA-256 is `26f9a27ff043ab999a3c0ff863c3c04866b48a02bc0893a052c5dd073ad2fe4c`.

The working implementation subsequently committed as `1a9c87274`, including
the recovery-prefix change `f87b54771`, passes the native `log privileges`
schedule on local disk. It drives the real catalog and shared maintenance
executor through **195 units**, with **20,268,442 peak private allocated bytes**
inside a 32 MiB budget. The setup accepts and releases 130 reads, creating a
history longer than one replay budget without an unbounded active-pin set.
Executor replacement discards its caches and hints; later units resume accepted
work, finish both partitions, and become idle. Original finite reads remain
usable after compaction, archive, checkpoint and physical WAL trim.

The same schedule changes retention through the signed catalog. Missing trusted
time refuses expiry without advancing the data log. With an authoritative
interval, timed eligible history expires using the control reserve after
ordinary quota is filled. The other partition's previously untimed data remains
retained. Current native authorization still gates final disclosure.

The first combined native attempt was stopped incomplete after diagnosing
repeated full recovery between archive units. It is not a pass. The final
executor keeps at most 64 same-process prefix hints, verifies their accepted
boundaries, and replays at most 16 frames per turn. Storage disk controls reject
altered hint roots and commitments, recheck current permission, and prefer newer
accepted checkpoints after WAL trim. Catalog traversal tests cover every
partition in a fixed object pass, later high-ID creation, Queue/private skips,
and denial before returning a selection or definition.

The native test executable's SHA-256 is
`0b5a9aded0daea2e1f5fd846fb111dad1f5f9db7d1518e046942b3281530a73d`.
Logs are `/var/tmp/transit-stream-maintenance-native-hints.log`,
`/var/tmp/transit-stream-maintenance-hints.log` and
`/var/tmp/transit-stream-maintenance-catalog.log`. The workspace fast check
passes all 48 checks. These executions do not establish a committed-source clean
lane, installed background-loop qualification, sparse physical payload
rewriting, or Queue execution.

## Retained Stream maintenance targets — 2026-10-30

The storage change `b30758a87` passes the pinned-shell Stream partition and log
read suites. New disk cases lose archive replies with archive and compaction
targets active, reopen the providers, admit later input outside the original
cuts, and run bounded units until both become idle. WAL trim and another reopen
preserve original append receipts and earlier pinned visibility. Every unit
publishes at most one record. Further idle calls accept none. A separate replay
control rejects a locally well-formed root that invents archive completion.
Retirement closes only an unpublished compaction candidate.

The committed-source core attempt at that revision stopped in the fast query
fixture check: the shared definition had changed but the independently hashed
Table descriptor fingerprint had not been regenerated. `107e9bc9e` regenerates
that fingerprint and its query-policy reference with the Python owner. The
subsequent workspace fast check passes all 48 checks. This is not a completed
clean-core result. The failed clean checkout and phase evidence remain at
`/var/tmp/transit-ci-5j06uv3u`.

Logs are `/var/tmp/transit-stream-maintenance-storage.log`,
`/var/tmp/transit-stream-maintenance-all-storage.log`,
`/var/tmp/transit-stream-clean-core.log` and
`/var/tmp/transit-stream-maintenance-fast.log`. These results qualify storage
transitions and fixture reconciliation; they do not yet qualify the automatic
native scheduler or sparse physical payload rewriting.

A second clean-core attempt at `938a54a06` passed fast checks but failed five
independent fixture generators and their embedded consumers: named relational
records, reactive signatures, worker handoff, application signatures and unified
query commitments still contained hashes derived from the previous shared
definition. `65f9eba22` regenerates those seven fixture files with their existing
owners. The complete workspace `test-fixtures` target then passes, including 143
shared native/port codec cases. The known-failed clean run's remaining native
tests were stopped; it is failed and incomplete, not a clean pass. Evidence is
`/var/tmp/transit-stream-clean-core-final.log`,
`/var/tmp/transit-stream-cutover-all-fixtures.log` and the retained checkout
`/var/tmp/transit-ci-6lf9kpq1/src`.

## Bounded Stream consume waits and main integration — 2026-10-30

The bounded-wait implementation `4caf380fa` is rebased on `a4e695de6`, including
the gateway dispatch changes and Document storage graph. Shared Document
fixtures were regenerated under the branch definition in `0681f887e`.

The pinned-shell `zig build test-direct-table-service -Doptimize=ReleaseSafe -- tables`
passes **2,055 typed HTTP calls**. The real shared caller supplies the signed
wait's exact scheduling header, receives timeout without a read receipt, and
recovers an existing consume's original cut. The proxy separately proves that
a missing or mismatched wait hint rejects before execution. Existing retained
Table/Stream reads, original mutation recovery, restart, current authorization,
and reserved-control checks also pass. The first HTTP run caught header access
after body parsing; the successful run includes parsing the scalar hint before
the header lifetime ends.

| Executable | SHA-256 |
| --- | --- |
| `transit-node` | `0499350075099b83e70503db71a004e37c3283e5fcac7fb5579610428c2e1b9a` |
| `transit-direct-table-proof` | `18704ee273ad0e41ff2e43eeb6f67114f48be9877a341ad75d5b7ff44cd2b875` |

Catalog disk tests cover pending waits without operation reservations, timeout,
readiness at the final deadline check, immutable empty-read retries, per-object
waiter capacity and group generation/checkpoint refusals. The concurrent native
host test observes an actual parked condition waiter before append, cancellation
or revocation publication. Appends proceed without the parked reader's object
lock, cancellation joins and releases the ticket, and published revocation
prevents disclosure. Policy preparation happens before the bounded wait; its
publication is the tested race. Independent signing fixtures cover the wait
duration and the unchanged underlying consume intent. Cancellation preserves
the original identity as unknown work.

The rebased protocol suite, selected catalog Document/Stream tests, native
catalog wait tests, all 18 contract checks, and documentation links pass.
The preceding native collection run also passes all three disk schedules after
correcting the expected expired-range error; the error remains distinct from
missing recovery history. Logs include
`/var/tmp/transit-stream-wait-http-rebased.log`,
`/var/tmp/transit-stream-wait-native-rebased.log`,
`/var/tmp/transit-stream-rebase-catalog.log`,
`/var/tmp/transit-stream-rebase-contracts.log` and
`/var/tmp/transit-stream-bounds-collection-fixed.log`.

These executions do not constitute a full nightly or committed-source clean
lane result. Automatic Stream maintenance, sparse physical payload rewriting,
Queue execution, mixed-kind transactions and SQL Stream operations remain
outside this evidence. The [public Stream contract](../../../contracts/DIRECT_TABLE_V1.md#stream-payload-and-consumer-progress)
owns supported behavior and limits.

## Signed Stream payload and consumer operations — 2026-10-30

The work committed as `3a596ba31` composes `DirectStream` with the local signed
catalog endpoint and shared `Catalog.callStream`. The owning
[payload contract](../../../contracts/DIRECT_TABLE_V1.md#stream-payload-and-consumer-progress)
defines current behavior, budgets and grants.

The pinned-shell `zig build test-direct-table-service -Doptimize=ReleaseSafe -- tables`
passed **2,052 typed HTTP calls** on local disk. The Stream caller saves original
append/read work before sending it, recovers deliberately corrupted append,
consume, offset and release responses, reads bounded pages, and settles a group
only with complete authenticated coverage. After node replacement, the original
append returns the same range and a saved read cursor returns its original
schema and offsets despite later RENAME and ALTER. The existing Table pressure,
reserved-control, CRUD/DDL, retained-history, projection, collation, restart and
authorization-lifetime schedules also pass.

| Executable | SHA-256 |
| --- | --- |
| `transit-node` | `2420ed443b598d3a83f31dbe2509c639f306f52f9e43d414d135153a51d1eca9` |
| `transit-direct-table-proof` | `b051f2b34a91656e84b022ce4c704410314ae84c53b8c126b1907a6a10616596` |

The HTTP binaries were built from the uncommitted implementation before the
final enum-order/schema cleanup and explicit fresh-read `LogRangeExpired`
classification. The final source separately passes the native catalog selection
`log privileges`, `log lifecycle publication`, `shared refusals`; the storage
`stream partition expiry` tests; the shared data-client tests; and all 18
`check-contracts` checks. Independent signing fixtures and catalog composition
tests cover required definitions, full-width identities, exact intent hashes,
buffer ownership and original work after declaration edits. The native
composition test revokes permission after response serialization and suppresses
the buffered page.

Logs are `/var/tmp/transit-stream-native-service.log`,
`/var/tmp/transit-stream-service-final.log`,
`/var/tmp/transit-stream-range-expiry-test.log` and
`/var/tmp/transit-stream-contract-check.log`. Documentation link and site checks
also pass. These are local executions, not committed-source clean CI or a full
nightly result. They do not qualify blocking waits, automatic Stream maintenance,
uncertain deployed-clock intervals, Queue execution, mixed-kind transactions,
SQL Stream verbs or provider power loss.

## Direct dispatcher stack isolation — 2026-10-30

Hosted PR #256 qualification found an installed Board query provisioning crash.
The same failure reproduces locally: debug `DirectTableDispatch.apply` reserves
3,895,600 bytes for all action branches, and its nested native authorization
read exhausts the default worker stack. The crash occurs at `PageStore.load`'s
stack probe; it is not a page checksum or authority rejection.

The implementation committed as `7c4beeed0` specializes one action per function
frame. The measured x86-64 debug dispatcher frame is 1,010,544 bytes and the
largest specialized frame is 264,400 bytes. Worker stack capacity is unchanged.
The pinned-shell `just transit-board::query-test` passes provisioning, unavailable
submit/next replies, bounded capacity recovery and generated query-client checks.
The catalog selection `zig build test -Dtest-filter='direct dispatch'
-Dtest-filter='direct Table protocol' -Dtest-filter='direct catalog log'` also
passes. Both commands ran before the implementation commit; final clean-CI
qualification is separate. The installed log is
`/var/tmp/transit-stream-board-stack-check.log`; these compiler-specific frame
measurements do not establish a portable whole-server stack bound.

## Typed Stream and Queue catalog lifecycle — 2026-10-29

Source `58197ac42` implements the typed declaration lifecycle on the local native
owner. The current contract definition is
`bc4336065f662f6b20815669d660ac9a0f3ff3d0af462c8790ac297ce464f73e`.
The [public lifecycle contract](../../../contracts/DIRECT_TABLE_V1.md#stream-and-queue-lifecycle)
and [Streams reference](../../handbook/reference/streams.md#declarative-streams-and-queues)
own current behavior and limits.

The pinned-shell `zig build test-direct-table-service -Doptimize=ReleaseSafe -- tables`
passed **2,031 typed HTTP calls** against a disk-backed local node. The public
`transit-data-client.Catalog.callLog` caller saved original work before admission,
created a two-partition Stream, discovered its pending operation, recovered both
corrupted admission/publication responses, renamed it, changed retention,
created/dropped a Queue and recovered the original Stream receipt after node
replacement. Lookup schemas survived subsequent requests and client destruction.
The same run retained the existing Table CRUD/DDL, pressure/control-reserve,
retained history, collation, projection, restart and authorization assertions.
The proxy observed no database actor commands; native changes were authorization
operations, with the existing explicit unrelated-process denial fixture separate.

The executed ReleaseSafe binary SHA-256 values were:

| Binary | SHA-256 |
| --- | --- |
| `transit-node` | `99c40ba11a191404d2ae61185092d3f1832d6586a104f5fddef1da62de99f3a0` |
| `transit-direct-table-proof` | `8a486235bacd1fcd3409a9f7921f462bf9b4770a02ba031f019250eaf4943823` |

The first HTTP run failed during initialization with `NativeFenceRequired`:
the storage helper tried to install a fence instead of using the native owner's
publication guard. Commit `e5e8beaeb` corrected that boundary without weakening
append epoch or empty-partition checks. The repeated HTTP run above passed.

Other executed checks passed:

- Full `transit-catalog` package tests, followed by focused `catalog log` and
  `direct log` checks after pending discovery and independent signing fixtures.
  These cover actual disk reopen, lost catalog publication, unchanged allocation,
  shared-name conflicts, immutable routing, nineteen declarations with one
  resident index page, cancellation, revoked metadata and exact DLQ definition/
  schema dependencies. The graph walk retains declarations, original intents
  and initialized partitions through retirement.
- `zig build test-local-catalog -Dlocal-catalog-filter='log privileges'` exercises
  actual native registration and signed dispatch. Ownership transfer after
  buffering denies lookup, listing and original receipts; subsequent listings
  filter the inaccessible object. Separate grants exercise all five log actions.
- Focused storage `log initialization` tests verify missing dependencies, stale
  writers, post-buffer revocation and original genesis recovery. The independent
  data-client package tests and TypeScript Station type check passed.
- `zig build check-contracts` passed all eighteen gates after regeneration;
  independent signed log intent fixtures include full-width operation IDs and
  saved-work missing/foreign-definition rejection. Documentation validation
  checked 8,270 local links across 682 files.

These runs qualify declaration publication and its local recovery boundary.
They do not qualify payload append/consume/claim, timers, generalized transactions,
SQL Stream/Queue verbs, distributed provider behavior or power-loss durability.
Queue dependency removal remains conservatively refused pending its closure
owner. Combined committed-source CI, installed language migration and later
milestone gates require their own executions.

## Finite retained Table count ranges — 2026-10-26

The pinned-shell `just test::table-count-ranges` passes the focused query suite
and signed HTTP service schedule. The query run executes **13/13 tests**;
the final combined command reuses that successful unit result. Independent
selection masks cover signed interval boundaries, intersected/repeated bounds,
empty intervals, UTF-8 prefixes and embedded zero bytes. Other cases check owned
literal bytes, signed floating zero, a key outside the first column, unsupported
collations/physical bounds, and fallback for general/order-sensitive plans.

The [service schedule](../../../tests/query/tables/direct_table_count_ranges.zig) uses the real local node
with one resident authority page. A 17-row bulk-written Table has different key
and identity orders. Each selected interval is compared with a forced full scan
of the same pin and an independent expected count. Intervals span zero, one,
eight, nine and seventeen rows, including nonempty final pages. A narrow count
uses **eight** charged credential/direct exchanges; its full scan uses **twelve**
and fails under the eight-exchange budget. These counts include query opening
and final disclosure, exclude pin acquisition, and are not latency or disk-byte
measurements. Prepared intervals use ten exchanges for the one-page cases.

The original pin excludes later bulk and point writes. A fresh pin counts both
segment-backed and unflushed WAL rows. NULL parameters keep scan semantics;
request exhaustion cannot publish a prefix count. Row LIMIT selection and SUM's
intermediate overflow retain identity order. Revocation after local computation
denies both matching and empty counts, and repeated completion checks current
rights. Cancellation after buffering and released pins fail without completion;
the latter retains the HTTP `Conflict`/native `QueryExpired` classification.

Initial service fixture assertions needed budget for a second terminal check
and the public HTTP release-error classification; both were corrected without
changing runtime semantics. The first repository check also detected a work-item
WI1 fixture left on the preceding shared definition. Its owning generator and a
stale Board example are corrected separately in `0c716599`; the independent
fixture check passes. Documentation links, verification catalog, diagnostic
inventory and mappings pass. The corrected repository run and committed-HEAD
clean qualification remain separate pending gates. This increment changes no
wire/stored definition and does not qualify general inequality pushdown, encoded
predicate execution, compaction or an installed latency improvement.

## Direct catalog growth and retained rows — 2026-10-24

`just test::direct-table-service growth` passes 366 public typed calls with 139
Tables and 139 rows retained before catalog growth. Ordered metadata traverses
eight-entry pages; row reads use seven-row batches. The native owner uses one
resident page and the direct catalog/Table indexes retain their default
16-page caches. The fixture does not collect either durable sequence in memory.
After node SIGKILL and disk restart, every name and row remains readable under
the original saved pin and exact source basis, followed by explicit pin cleanup.
The data path issues no native actor data commands. This qualifies local disk
growth and recovery, not cold-provider placement or total process RSS.

## Direct catalog diagnostic boundaries — 2026-10-24

`just test::diagnostic-errors` and `just test::diagnostic-outcomes` pass after
moving catalog caller projections to the direct host boundary. The checks cover
16 compiler-inferred boundaries, nine unknown-cause projections and 3,479
projections across 29 declared outcome surfaces, with semantic drift mutations
rejected. Direct caller cases include the reviewed shared and direct-only causes.
An attempted mutation retains its original catalog operation identity and asks
for status inspection; later transport, decoding or permission failures cannot
establish rejection or suggest replaying an unrelated native send. These are
projection checks; public recovery evidence is recorded separately.

## Direct Table selected-role boundary — 2026-10-24

`nix develop --command just test::direct-table-service authorization` passes
against the public direct owner. A login with a set-only membership cannot
discover the Table until it explicitly selects that role. The selected caller
can pin and read the row, but cannot open the native lifetime resource or inspect
an unrelated native process. Revoking role selection denies metadata, reopening
the retained pin and pin release. Restoring selection permits the original cut
and its cleanup; clearing selection still denies access.

An initial fixture attempt failed because its root administrator tried to read
a native resource without a read grant. The corrected fixture creates a known
unrelated process through the public control operation and checks the Table
caller's denial directly. The expanded full Table schedule passes 1,374 typed
calls, including this check. Its first final audit rejected the fixture's explicit
process creation; the corrected audit retains the original restriction on native
data commands and separately requires exactly that one setup spawn. These runs
do not rerun all language SDKs or the older authorization suite.

The expanded authorization schedule also passes SQL-issued CONNECT/USAGE and
future-only default Table grants through the current direct catalog resolver and
native publication owner. A SELECT-only reader sees only the later Table in
paged listings, cannot discover the earlier Table or prepare DELETE/DROP, and
retains its original cut through explicit SELECT revocation/restoration. Removing
the default affects a subsequent registration without removing the existing
grant. Root creates the login credential; the database owner publishes every SQL
policy change against its original observed revision. This replaces the older
mediated fixture's default-grant and filtered-metadata coverage.

## Direct prepared Table lifetime — 2026-10-24

`nix develop --command just test::direct-table-service prepared` passes against
the public direct owner. The same SELECT, INSERT and MySQL UPDATE preparations
survive successive data changes. Preparation and DML binding leave the Table
frontier unchanged and the new operation unadmitted. Explicit execution preserves
Unicode and SQL-like text as values, full-width unsigned values, nullable updates
and bound-NULL comparisons. Fresh SELECTs use independent explicit pins.

Current ownership removal denies the old preparation; restoring it permits a
fresh read. ALTER and DROP/recreate invalidate the unchanged prepared objects,
including when their selected column types still match. The complete direct
Table schedule also passes with 1,361 typed calls, including this slice and its
separate recovery faults. These passes do not replace the whole older typed-Table
schedule.

## Unified direct Table recovery and closure — 2026-10-24

`nix develop .#serving --command just test::unified-query -Doptimize=ReleaseSafe
-Dunified-source=table` passes in 53.99 seconds. Its catalog uses the local direct
owner, independently of native source/requester progress. Native ABI and port
callers agree on SQL inspection and pure parameter compilation. Explicit capture
authorization is saved separately from that unsigned description. The schedule
recovers the original signed upload and six complete Arrow segments containing
41 exact UTF-8 rows (15,120 bytes) after source/requester/node replacement. Current
revocation suppresses reads; restoring access preserves the original result.
Every acquired Table pin is released, and reopening it returns the public
`QueryExpired` rejection. Eight resident native pages are configured.

Adding `-Dunified-counts=true -Dunified-lifecycle=true` passes in 137.03 seconds.
It recovers a partial COUNT accumulator after replacement, refuses partial
results, preserves exact lost-reply retries and recorded budget/policy failure
diagnostics, and checks cancellation, current source/request authorization,
cleanup and released-pin refusal. New finite queries use distinct explicit pin
operations; retries retain their already authorized bundles. The independent
fault decoder follows the current `UQJ1` retention tags and `UQC1` typed source
positions. Read/candidate-preparation retries are bounded to explicit capacity
or stale-cut refusals; signed submissions never enter that retry helper.

These Table schedules deliberately leave point rows unflushed and verify that
no `.tseg` exists. They qualify WAL-only recovery, not automatic flushing or
physical garbage collection. Their unused Ursula/MinIO fixture does not establish
cold Table persistence. The shared-fixture KV regression also passes in 38.94
seconds over disk Ursula, with 41 rows and six segments. Optional Table Board,
installed-SDK and finite-expiry schedules, and the remaining older catalog/SQL
fixtures, are not qualified by these commands.

## Installed Work items direct lifecycle — 2026-10-24

`nix develop -c just test::server-applications` passes on frozen source
`cde2f0848` with separately built ReleaseSafe consumer binaries and frozen local
runtime artifacts. The local installation migrates **19 rows in 19 row steps**,
retains **21 receipts**, reaches worker generation **9**, preserves exact earlier
receipts after replacement and restart, and checks current access and logical
identities. The full schedule takes **390.194 seconds**; manager RSS peaks at
**52,432,896 bytes** and installation checkpoints at **3,037 bytes**.

The earlier installed attempt remains failed: migration step 22 exhausted
recovery with ConnectionRefused after the manager's node restart budget was
exhausted. The successful run uses a fresh owned installation and completes the
original schedule without increasing its retry or timeout budgets. Its retained
directory is `/var/tmp/transit-server-proof-szi0g_8x`; the failed directory is
`/var/tmp/transit-server-proof-pbcvzasf`. This is local application installation
evidence, not Kubernetes/Substrate placement or a final SDK cutover check.

## Shared direct preview — 2026-10-24

`just test::direct-table-callers` passes **124 typed HTTP calls** through the
real local node. The host previews loaded DDL, bulk rows, predicate statements
and conditional names without admission. Repeated previews preserve positions;
operation inspection remains unobserved. A competing INSERT invalidates the
saved predicate's data frontier, ALTER invalidates the saved row definition,
and DROP reports an object conflict. Conditional previews distinguish the
original existing definition from its later absence. Exact original receipts
remain independently recoverable.

The complete catalog package suite and `just test::local-catalog` pass.
Disk-backed component assertions verify unchanged object-put counts, catalog
roots and Table log tails, absent identity claims and current denial during
preview. Native policy checks reject revoked Table ownership and an independently
revoked acceptance prerequisite. Response tests reject changed identities,
invented success against a changed frontier, altered schema fingerprints and
inconsistent stale reasons. The first expanded package run failed because the
new test used a change frontier equal to its saved frontier; the corrected
fixture uses a strictly later change and the complete rerun passes.

Reflected host/native schemas, independent full-width preview values,
diagnostic mappings/inventory and documentation links pass. The initial contract
regeneration caught a shadowed local variable; it is corrected. These additive
preview operations leave stored formats and the current definition unchanged.
The focused caller task does not itself inject faults or replace nodes. The
complete `just test::direct-table-service` regression also passes **1213 typed
HTTP calls**, including lost replies, retained history, current revocation and
three restarts. Final integrated/clean-checkout gates remain separate.

## Shared direct Table DDL preparation — 2026-10-24

Under current-v1 definition
`1f0a0d9a10df7cb89783f6106fb0881a56c29ad7135167b97325ba1d56750029`,
SQL and typed callers use `DirectTablePreparedDdl` for CREATE, ALTER, RENAME,
DROP and conditional name assertions. This is a shared compiler refactor; it
does not change stored intent or receipt formats.

`just test::direct-table-service` passes **1121 typed HTTP calls** using the
pinned ReleaseSafe profile. The added schedule binds CREATE operation 509 to
object 1509, releases its preparation template, restores the complete saved
intent, and checks that staging has not admitted it. After acceptance it adds a
typed default, rejects an older prepared DROP, renames and drops the Table, then
recovers the unchanged original CREATE receipt. Existing CRUD/DDL, conditional
name evidence, SQL, retained reads, history, revocation and three node-restart
checks also pass. The first expanded run stopped because its stale-binding
assertion expected `TableDefinitionChanged`; this action's HTTP client reports
`Conflict`. The corrected assertion retains rejection and the complete rerun
passes.

The SQL package suite, diagnostic mappings/inventory, Zig formatting and
documentation links pass. This supplies shared preparation for caller migration;
it does not qualify the remaining actor Table SDK/ABI paths. Final integrated
repository and clean-checkout checks remain delivery gates.

## Obsolete named metadata owner removal — 2026-10-24

The supplied-resource-ID `DeclarativeCatalog` implementation is removed. Its
Table name-collision, lifecycle and dependency fallbacks are removed with it.
The retained Table dependency/redaction regression uses actual Table definitions;
named KV/Document allocation, initialization and dependency coverage belongs to
the direct owner and the executed schedules below. Caller-supplied computation
completion remains a rejected action. Removing that metadata helper does not
finish migration of the remaining actor Table callers.

Shared current-v1 definition
`1f0a0d9a10df7cb89783f6106fb0881a56c29ad7135167b97325ba1d56750029`
replaces the stored interpretation; old artifacts are not adopted or reset.
Schemas, host resources and independent signing fixtures are regenerated.
The complete catalog package tests, diagnostic mappings/inventory,
`just contract::check`, documentation links and the complete handbook check pass
in the pinned Nix shell. The first contract-check attempt reached the generated
host-type check and failed because this fresh worktree lacked installed frontend
dependencies. After `just transit-board::install`, the complete contract and
handbook rerun passes, including types, nine content tests and production build.

This records component and format qualification for the removal. Public named
resource/query fault schedules below retain their exact earlier source definitions;
full-repository and clean-checkout qualification remain separate delivery gates.

## Named resource dependency authority and retirement — 2026-10-24

Under shared current-v1 definition
`77272670307dae08e50482d54527d048999215b933dc5c078e20ab06fe50bbde`,
`zig build test-direct-named-resources` passes **107 typed catalog HTTP calls**
with eight withheld resource-stage replies, four withheld dependency replies and
eleven abrupt node replacements in the pinned Nix shell. Separate caller processes
preserve the saved declaration and registration/removal bindings. Real initialized
KV and Document objects serve as both sources and dependents. Both graph directions,
source native-read denial, independent metadata inspection, DROP RESTRICT, exact
registration/removal recovery and no resurrection from an old receipt pass before
the existing typed data, rename and retirement checks.

Focused catalog checks cover both resource kinds, exact allocated dependent
definitions before publication, wrong-kind rejection, unsupported source mutation
masks, dependent metadata denial/redaction, lost registration acknowledgement,
rename without edge retargeting, retained edges after consumer retirement and
explicit cleanup without source data access. An initial test left the intentional
lost-reply flag enabled for subsequent mutations; the corrected fixture scopes
that fault to registration. It is not counted as passing evidence.

The cutover regenerates schemas, binding declarations and independent signing
fixtures because named dependency authority no longer refers to the catalog's
backing native resource. `just contract::check` and the complete catalog package
tests pass. The existing Table
dependency HTTP regression also passes **30 typed calls**, two withheld replies
and abrupt node replacement, preserving exact receipts, metadata revocation,
redacted blockers and DROP/name replacement. Diagnostic inventory/mapping checks
and documentation links pass. This qualifies explicit same-catalog named-resource registration,
not atomic resource/dependency publication, automatic reconciliation, cross-catalog
named resources, query publication integration or distributed placement. Full
repository and clean-checkout qualification remain required before delivery.

## Named native resource allocation and initialization — 2026-10-24

Under shared current-v1 definition
`c9953eefbeb433c169967c999da0fe0b356e55372a9e055af6a737acee9470bf`,
`zig build test-direct-named-resources` passes **71 typed catalog HTTP calls** in
the pinned Nix shell. The public caller saves two declarations before admission.
An independent proxy withholds valid observation evidence for all eight accepted
CREATE stage replies by corrupting their context; nine abrupt node replacements
separate allocation and initialization stages. Saved bindings remain byte-identical.
This is an executed local native-disk schedule, not a Compose or Reference run.

The proof uses actual original-caller native allocation, explicit metadata and
native data permissions, public Station turns and current public readers. It
checks inert preview, hidden pending names, one prepared allocation per principal,
allocation accepted before a denied attachment, exact native receipt recovery,
KV initialization and all three Document initialization stages. Typed KV
put/get/delete, actual Document change staging/acceptance and current read denial
after revocation pass. Metadata rename and logical DROP preserve the initial
marker, original completion receipt and independently readable native data.
The final resource listing excludes the retired catalog bindings.

The existing direct Table HTTP regression also passes **1090 typed calls** under
this definition, including full CRUD/DDL, retained reads/history, namespace and
conditional-name recovery, original-caller delegation, cleanup and three restarts.

Focused catalog tests pass shared Table/name/operation conflicts, disk recovery
after each lost stage acknowledgement, allocation-reservation recovery and
release, final publication-fence denial, malformed wire response rejection,
independent Python/OpenSSL intent/digest vectors and **25 live definitions plus
11 cancelled claims with a one-page resident cache**. Filtered empty listing
pages preserve continuation; native and metadata rights remain distinct.
Framework tests pass discarded proposals between initialization steps, no
adoption of populated or anonymous data, exact markers, typed value/key bounds,
owned decoding, permission loss, partial-KV-marker rejection and preservation of
private proposals on failure.

Earlier integration attempts failed on reused fixture identities, missing native
inspection/worker grants and absent clock configuration. They also exposed two
implementation defects: simultaneous declarations froze the same caller sequence,
and the emptiness scan rejected GenServer's private framework descriptor. The
durable allocation index and explicit committed scan now have regression checks;
private user mutations cannot hide populated data. Those failed attempts are not
counted as passing evidence.

The coordinated current-v1 cutover regenerates schemas, public bindings and
independent signing fixtures. `just contract::check`, the complete catalog package
tests, `zig build test-local-catalog`, focused framework initialization tests and
documentation link checks pass against this definition. Diagnostic inventory/mapping checks pass; this
records their declared scope and does not establish new diagnostic projections.
This proof does not integrate named consumers with exact dependency registration,
retire the remaining actor catalog implementation, expose executable KV/Document
console SQL, establish automatic reconciliation, qualify arbitrary application
writers or prove distributed transactions.

The full `just check` run at `7378460bd` passed core, contract, native/package,
CLI and Board stages, then failed the handbook ownership test because this
Internals account included a repository command. The command now belongs to the
proof ledger. With only documentation wording changed, the complete
`just transit-docs::check` rerun passes formatting, types, all nine content tests
and the production build. This records the initial failure and corrected stage
separately; clean-checkout qualification is still required before delivery.

## Direct definition dependencies and restricted retirement — 2026-10-24

Under shared current-v1 definition
`876f2437cc73bd0a2822fd49a77e8ede1e3c8fcfa0fd747851ee49aa8e0e5ac1`,
`just test::direct-dependencies` passes **30 typed HTTP calls** in the pinned Nix
shell. The independent proxy corrupts the first accepted registration and removal
replies; each is followed by an abrupt node kill and separate caller recovery.
Saved bindings remain byte-identical. Original terminal receipts, altered-intent
rejection, both graph directions, current metadata denial and restoration, and
generic RESTRICT with a redacted blocker pass. A rejected DROP stays rejected
after removal; a separate DROP and same-name creation preserve the old identity.
Replaying the original registration does not restore the removed edge.

The focused catalog tests pass disk recovery, revocation at the publication fence, cancel
tombstones, no-op receipts, source DDL exclusion, rename/stale-definition handling,
and **41 edges with a one-page resident cache**. Four-edge scans omit inaccessible
records, advance past filtered records and reject changed observation
cursors without writing during inspection. Independent Python/OpenSSL signing
and big-endian digest fixtures cover full-width identifiers. Client validation
rejects substituted objects, duplicate edges, mixed positions and authority modes.

`zig build test-local-catalog -Doptimize=ReleaseSafe` passes real native grants,
denial after acceptance/response buffering, exact receipt recovery, metadata-only
inspection and explicit orphan cleanup. Native resource retirement alone retains
metadata grants; the test separately revokes them, then requires realm ADMIN and
source ownership for cleanup. No dependent data grant is inferred.

`just contract::check`, diagnostic inventory/mapping checks and documentation
links pass after coordinated schema, binding and signing-fixture regeneration.
The first contract run lacked installed frontend dependencies in the isolated
worktree; the locked install and complete rerun pass. Earlier HTTP attempts had
incorrect fixture expectations for a typed DROP rejection and tried to inject a
successful-reply fault into a denied removal. Those failed attempts are not
evidence of success; the final fixture preserves both distinctions.

This qualifies explicit registration and inspection. It does not publish or
activate named KV, Document or query consumers, retain their data, integrate
their publication owners automatically, or qualify Table garbage collection.
The catalog format requires both graph indices and the new definition; prior
artifacts reject rather than acquiring an empty graph through a default.

The existing `just test::direct-table-service` regression also passes **1090
typed calls**: point/bulk rows with a real `.tseg`, full CRUD/DDL, SQL namespace
and conditional-name recovery, retained joins and history, original-caller read
delegation, explicit pin cleanup and three restarts. It does not acquire
dependency registrations implicitly.

The full `just check` run at committed revision `6d64dbd5c` passes, including
the unit suites, generated contracts and independent fixtures, frontend checks,
and handbook tests and build. This result covers the dependency registry and
the existing application changes at that revision; subsequent named-resource
implementation requires its own qualification. The final clean-checkout gate
has not yet run for this implementation branch.

## Station ledger over the direct Table owner — 2026-10-24

The shared current-v1 definition is
`40ebbb4d9c928daa573cfaf38cafe3361c7fb972bfcd314d64f9dc665e75e547`.
In the pinned Nix shell, `zig build test-station` passes the ledger, service and
lifetime schedules against the native local owner. The ledger saves its exact
catalog/branch/object binding and rejects missing or previous definitions and
replacement-object configurations before consuming the original input.

Creation and row changes use immutable direct intents. A native dispatch record
precedes direct admission; the original Table receipt precedes a separate native
audit/reply commit. The schedule refuses initialization once, loses an accepted
direct admission reply, expires a native view and loses or holds native terminal
receipts. Exact retries, changed policy bases, abrupt node/worker replacement,
stale-generation rejection and the final 7 + 5 - 2 = 10 result pass. Native audit
publication uses two writes and does not carry Table rows or publish a Table head.

The requester saves its caller-signed capture grant and original cut before
upload. Independent Arrow decoding, replacement of both query hosts, explicit
query-policy denial and native SELECT revocation before publication pass. The
executor uses its login identity; the saved requester grant supplies the data
role. Registry/rebind routing, late-result timeout closure, scoped supervision
and blocked-handler control remain in the passing suite. Opted-in expiry uses
maintenance inside the owning node, permanently reclaims native progress and
rejects a later worker. This does not establish physical Table reclamation.

Earlier runs failed on missing domain lifetime bindings, ordinary privileges
mistakenly inferred from ownership, a root-input SEND requirement, an executor
carrying the requester's selected role and external maintenance opening an
exclusively owned local directory. The final schedule corrects those compositions
without relaxing the owning checks.

`just launchers::local::test-station` also passes with ReleaseSafe installed
artifacts: registry/call/Arrow exchanges, same-PID recovery, credential rotation,
all three worker upgrades, Board provenance and persistent stop/start. Its
courier fault refuses 293 reads, replaces the courier in **30.385 seconds** and
completes the query within the separate recovery window (**15.937 seconds**).
These are observed test times, not latency guarantees. The initial launcher
attempt failed because its temporary bootstrap listener satisfied the manager's
health probe before provisioning completed. Bootstrap now completes before the
manager starts. The successful installed run precedes the additional realm and
executor startup-rejection checks. The subsequent native suite passes those
additional checks too. `just launchers::compose::test-station` passes the same
registry, direct mutation, captured query, same-PID replacement, three-worker
upgrade, Board inspection and retained stop/start workflow in real containers.
`just launchers::reference::test-station` subsequently passes the same workflow
in an owned Kind/Substrate cluster, including forced ledger pod deletion, fresh
worker activation, three-worker upgrades and retained stop/start. The full
`just check` run passes after the independently signed/hashed fixtures are
regenerated through their owners. Earlier fixture failures remain failures.
The check starts at the Station migration commit; the subsequent reference
bootstrap corrections also pass chart checks, 15 ownership/recovery checks and
documentation links. These results do not qualify the unfinished shared
dependency and named-resource work or replace final committed-HEAD validation.

## Named publication recovery with current credentials — 2026-10-24

Under the `b840e71b` current-v1 definition, both focused direct-service schedules
pass in the pinned Nix shell:

```sh
just test::direct-named-query
zig build test-direct-captured-query -Doptimize=ReleaseSafe --summary all -- --maintained-only
```

Each schedule covers a self-join and two independent Tables. The fixture saves
each exact native naming/policy proposal to a synced private file before dispatch.
For each worker, the proxy loses the first accepted `NRD1` publication reply and
`NRP1` authorization reply and abruptly replaces the node. Eight injected reply
losses across the two schedules then rotate the corresponding worker key and
generation before reconstructing its host.

The initial attempt to recover by resubmitting the retired signature correctly
failed. The final fixture verifies that denial, then uses the existing current-
credential receipt query for the exact original request. The proxy independently
compares the returned receipt with the original accepted response and verifies
that the saved proposal bytes never change. Altered request content rejects with
`ConflictingRetry`; the prior worker generation cannot resume. The fixture retires
each saved proposal only after observing its receipt.

Publication and authorization leave execution absent until explicit activation.
Captured output, original named attribution after later publication and current
disclosure denial/restoration pass. The maintained schedule also passes node
restart during acquisition and physical history traversal, backfill, complete
successor revisions/deltas, original lease cleanup and retirement. Its complete
run takes approximately **10 minutes**. Current keys authorize recovery; they do
not replace the original caller's query grants or source cuts.

Documentation links and the site check pass, including nine tests and its build.
These schedules qualify naming/policy reply recovery. They do not close shared
dependency registration, migration of the older actor fixtures, broader activation
and failure fault schedules, or final committed-HEAD/installed qualification.

## Direct Table change-reader checkpoints — 2026-10-24

The shared current-v1 definition is
`b840e71bde2e36fc2c83d773e3bb13bbf9c44c15d3d46b955beed1f8fda84a00`.
`TableChangeReader` now traverses an explicitly acquired direct history lease.
Its mandatory versioned position binds the original connection, object, lease
and exact logical history record. It replaces the actor Table journal reader;
local closure does not release or reacquire the durable lease.

In the pinned Nix shell, `just test::direct-table-service` passes **1090** typed
HTTP calls. The fixture saves the position to disk, rejects missing/foreign
definitions and altered record commitments, and reopens it after process/node
replacement. Writes accepted during paused backfill leave its original rows
unchanged. Two replays verify eight complete transactions: a no-op, insert,
delete, update, delete, column addition, rename and DROP. Insert/delete cursors
advance independently in the before/after sources; the first implementation
incorrectly shared one cursor and failed the owner's source-membership check.
The corrected run passes without weakening that check.

The schedule also verifies incomplete-transaction checkpoint rejection,
allocation failure without cursor advancement, request exhaustion, cancellation,
current denial/restoration, original schemas after name reuse and rejection after
explicit lease closure. Row changes retain the original acceptance receipt and
both source bases; physical-only pages create no logical transaction. The old
actor change-reader fixture is removed; other actor Table consumers still need
migration.

Query package tests pass **152/152** and native protocol tests **51/51**. Generated
contracts/bindings, diagnostic inventory, Board contracts and documentation links
pass. The documentation site passes nine tests and its production build. Query
unit and site runs precede the final independent-cursor correction and proof
prose; the HTTP run includes that correction. The repository-wide check began
before this cutover and cannot establish final committed-HEAD qualification.
Shared dependency registration, named resource provisioning and the remaining
caller/installed gates stay open.

## Membership additions preserve inactive paths — 2026-10-24

Installed Work items provisioning exposed `AuthorizationDependencies` while
adding a new membership with INHERIT false and SET true. Administration treated
every explicit false option as a removal and reconciled unrelated inactive
delegation paths. It now runs removal closure only when a previously published,
enabled option actually changes from true to false.

In the pinned Nix shell, `zig build test -Doptimize=ReleaseSafe` in
`packages/zig/transit-core` passes **123/123** tests. The new case disables an
unrelated grantor, creates and repeats the SET-only membership, checks that it
confers no inherited authority, then re-enables the grantor and observes its
unchanged delegated grant. A separate repeated-membership reduction still
rejects dependent ADMIN authority with RESTRICT and preserves publication.
Installed application recovery and full repository checks remain separate gates.

## Optimistic current Table reads — 2026-10-23

The current shared definition is
`dec0151b4f9d664f75113d65fd43b3ba9a47f07ffb28fdda7e4b91b3d369bb60`;
the preceding namespace definition rejects. `read_current` supplies a point
lookup or bounded ordered suffix under an exact definition and original logical
data basis. Generated schemas, binding resources and signing fixtures use this
definition, including an independent Python/OpenSSL full-width seek request.

In the pinned Nix shell, the storage package's
`zig build test -Doptimize=ReleaseSafe -Dtest-filter="current Table" --summary all`
passes **4/4** tests. The added schedules traverse 33 mixed WAL/segment rows with
a one-page resident cache and disk reopen between pages, preserving order through
no-op acceptance, pin/release and flush. They check row ownership after owner
destruction, invalid/future/wrong-partition bases, invalid seeks, byte limits,
logical-change rejection, DROP and authorization failure after buffering a hit,
absence, rows or an empty suffix. Reads preserve log roots and object put counts.
This is focused storage evidence; the earlier full storage and catalog attempts
were stopped before the final definition/fixtures and are not counted as passed.

`zig build test-local-catalog --summary all` passes **2/2** Debug tests. Its new
signed native cases recheck current Table ownership after complete response
buffering for a hit, absence, a row page and an empty suffix, and reject retained
delegation used for a current read. The existing CRUD, history, namespace and
original-input prerequisite schedules also pass. The protocol package passes
**51/51** ReleaseSafe tests, including rejection of the replaced definition.
`just contract::check transit-board::contract` passes after regeneration.

The catalog package passes **132/132** ReleaseSafe tests. New response checks
reject stale logical bases, wrong definitions/partitions, mismatched point keys,
repeated identities, forged continuations and invalid counts/byte budgets.
`just test::direct-table-service` passes **627** typed HTTP calls, including a
64 KiB current point read, ordered continuation, empty suffix, stale-basis
rejection and current revocation/restoration after node restart. The existing
CRUD/DDL, namespace, history, delegation, lost-reply and three-restart schedules
also pass. Diagnostic inventory/mappings and `just transit-docs::check` pass,
including **9** documentation tests and the static site build.

These reads do not migrate Work items, retain a source after mutation, establish
cross-Table atomic reads or qualify distributed locking and physical collection.
Full `just check` and committed-HEAD `just ci-clean` remain outstanding.

## Direct namespace lifecycle — 2026-10-23

The current shared definition is
`e8677230beea38e3f824c3413009a123a2386f7c6c7a1cfcaa7efe51e8486c78`;
the preceding definition rejects. Namespace bindings, permanent identity
claims, name reservations, paged DROP progress and resulting schema records
publish through the direct catalog WAL. In the pinned Nix shell, protocol tests
pass **51/51** and catalog tests pass **130/130** in ReleaseSafe. The added
catalog schedules cover disk reopen, lost admission/publication replies, exact
retry after rename/DROP/name reuse, cross-kind identity conflict, cancellation,
current denial, pending/live Table RESTRICT, retained snapshots after namespace
retirement and multi-page dependency progress with a one-page resident cache.

`zig build test-local-catalog --summary all` passes **2/2** Debug tests. Its signed
native namespace schedule checks real registration, database/schema ownership
loss before execution, response withholding after accepted publication, native
reopen, fresh caller credentials and exact original outcomes after retirement.
This composes the real local service and native policy; it does not exercise an
HTTP transport or concurrent browser callers.

`just test::direct-table-service` passes **618** real typed HTTP calls. Its
namespace additions compile CREATE/RENAME/DROP SQL through the direct typed
compiler, provision actual native schema authority, create a Table in that
namespace, reject DROP while it is live and preserve its retained snapshot after
Table and namespace retirement. A proxy withholds usable publication evidence
by damaging the response context; the caller recovers the exact saved namespace
binding. Original CREATE/RENAME/DROP outcomes and the original empty Table cut
survive OS-process restarts and namespace name replacement. The broader existing
CRUD, history, delegation, quota and three-restart schedule also passes. This
qualifies the typed SQL compiler and request path, not interactive console
administrative submission or application setup migration.

`just contract::check transit-board::contract`, diagnostic inventory/mappings and
`just transit-docs::check` pass after regeneration, including nine documentation
tests and the documentation build. These focused checks do not establish full
repository qualification: the earlier `just check` reached unit tests and
exposed stale mediated SDK switches and the unmigrated Work items Table source.
That run was stopped after those failures; its remaining long-running unit
suite and later checks are not counted as passed. The SDK switches are fixed
in the separate evidence record below. Work items remains open.

## Changed Table inspection diagnostics — 2026-10-23

Board maps the native `TableDefinitionChanged` cause to
`inspection.observation_changed`, with an explicit fresh-observation action and
no mutation outcome or fabricated completion. Its API package passes **13/13**
Debug tests. `just test::diagnostic-outcomes` passes **3,411** projections across
**29** declared surfaces, including the added reviewed native case. The broader
`just check` run first exposed this missing case and stopped at that gate;
later repository checks were not executed in that run.

## Direct mutation authorization prerequisites — 2026-10-23

Direct mutation bindings retain an optional native guard through admission,
staging, acceptance and recovery under definition
`9454a601d54b923917307ccca9c9c70235378f011aa17a8073013eb0ddfa2c56`.
The replaced definition rejects. In the pinned Nix shell, ReleaseSafe package
tests pass for protocol (**51/51**), catalog (**127/127**), local backend
(**10/10**) and serving (**52/52**). `just contract::check` and
`just transit-board::contract` pass with regenerated neutral schemas, language
resources and independent signing/saved-intent fixtures.
Diagnostic inventory/mappings and `just transit-docs::check` also pass, including
**9** documentation tests and the site build.

`zig build test-local-catalog --summary all` passes **2/2** Debug tests against
real native authorization and disk-backed local storage. The new schedule binds
an accepted native input from a separate caller, denies CREATE and row execution
after its privilege is revoked, and permits exact inspection and cancellation.
Restoring the privilege resumes the original pending work. The worker's own
Table rights remain necessary. A fresh worker key executes the unchanged
binding; reopening native history preserves that binding. Rotating the original
caller's credential blocks the pending mutation while exact cancellation and
inspection of an earlier committed receipt remain available. Removing the saved
condition conflicts. The local-backend race also revokes the additional subject
after private bulk staging and proves that no Table acceptance or row prefix
was published before exact recovery under restored rights.

`just test::direct-table-service` passes its **562** typed HTTP calls, existing
CRUD/DDL, retained reads, lost replies, revocation and restart schedules under
the new definition. The additional accepted-input condition is exercised by the
native dispatcher test, not a separate HTTP fault schedule. Work-items migration,
application-policy dispatch eligibility and atomicity between native control
progress and Table acceptance remain separate work.

Before this change, rebasing onto `origin/main` at `4df1ccc8` preserved responsive
console completion. The query package's ReleaseSafe suite passed **148/148**,
`just test::console-history` passed, and the diagnostic inventory was regenerated
and checked. Those runs used the preceding definition; they are rebase evidence,
not full-repository qualification of this mutation change.

## Named definition fixtures with direct Table grants — 2026-10-23

Under definition
`18d5e193251f177dbf700e9601a6dede6e98e48d9c2c744049ffacc1b0601ca8`,
`zig build test -Doptimize=ReleaseSafe --summary all` in
`packages/zig/transit-station-app` passes all 45 tests. Named definition tests use
offline direct Table interpretations and signed snapshot/history grants with a
computation resource independent of the Table catalog. A bounded HTTP peer
injects executor identity and read-only source-authority responses; it accepts no
pin acquisition or mutation. Publication/authorization retries, quota rollback,
captured/maintained activation, old policy denial and 67 retained revisions pass.
These are transition and transport composition checks, not native authority or
Table durability evidence. Independent named-record fixtures and diagnostic
mapping/inventory checks also pass. Work-item and older installed relational
fixtures still require migration; the full repository check remains outstanding.

## Read-only current Table observations — 2026-10-23

`nix develop --command zig build test-direct-table-service
-Doptimize=ReleaseSafe --summary all` passes 526 typed HTTP exchanges under
definition `38fb0433e2dbce32b39167abb988460d09b813d8f2de519e78fbb8ca732b40e8`.
The new `observe` request returns an empty current Table without advancing its
acceptance position. After disk restart it returns metadata, a one-row prefix
containing the original 64 KiB value, and a complete two-row page at the same
current position. Revocation denies the observation and restored rights permit
it. After DROP and name reuse the old interpretation rejects, while the existing
retained-source tests continue to read their original cuts. This run also retains
the earlier CRUD/DDL, three-restart, history, lost-reply and cleanup assertions.

Focused storage tests pass 4/4 for retained/current pages, including mixed WAL
and segment storage, owned variable-length cells, byte budgets, final denial
after buffering and empty completion. Current observations leave the root,
log position, object writes and pin state unchanged. The catalog selection
passes 33/33 tests (`direct`, `current observations`, `borrowed Table` filters).
Injected catalog policy checks final denial and unchanged persistent state;
response checks reject unrelated interpretations, altered authority references,
false coverage, byte-count changes and duplicate identities. Retained-query and
borrowed grants reject the current-observation action.

The direct contract generation/check, verification catalog, documentation's nine
tests and production site build pass. This adds a public read-only observation
primitive; reactive watch integration and full repository checks remain pending.

## Retained direct Table pages and predicates — 2026-10-23

`nix develop --command zig build test-direct-captured-query
-Doptimize=ReleaseSafe -- --source-pages-only` passes against the private
persistent node. Retained pages keep wide/nested values and the original
interpretation after ALTER, DROP and name reuse. The predicate schedule compares
84 combinations of column, comparison and signed boundary against full logical
predicate evaluation over 43 keys, including both `INT64` extremes and a nullable
non-key column. Complete primary-key equality uses one point page for hits and
absence; other comparisons use bounded scans. A disjunction containing a key
comparison preserves rows outside that atom. Current Table permission denial
rejects both point and scan reads.

These public schedules replace the actor-store Table adapter fixtures. The
source-page phase has a finite 600-second test deadline for the expanded HTTP
schedule; it establishes result equivalence, not a latency target. KV and
Document adapter checks retain their native resource fixtures.

## Direct Table history retention — 2026-10-23

The storage ReleaseSafe `Table history retention` filter passes two tests after
replacing the shared current-v1 definition. The disk-backed owner recovers a
history lease after a lost reply and restart, retains the original cut and exact
logical successors, preserves no-op acceptances across flush and later writes,
and rejects cross-revision cursors, mismatched record commitments, current denial
and reads after explicit release. An ordinary snapshot pin remains independent.

`nix develop --command zig build test-local-catalog -Doptimize=ReleaseSafe`
passes both native catalog tests under the new definition. Signed direct-service
requests distinguish snapshot grants from history grants, reject attempts to
change the kind of an existing lease, recover exact acquisitions, and reopen a
saved no-op revision. Table-rights revocation after response serialization denies
both buffered historical rows and an empty history page. These tests use the
real local policy/storage owner but call service dispatch in process.

The native/binding/logical/Table/configuration/SQL-session/Board generators pass.
Independent fixtures for native requests, physical schemas/storage, Table sources,
worker handoff, unified queries, relational plans/records/exchanges, named results,
Documents, applications/signatures, reactive reads and column codecs regenerate
successfully. The direct grant now has a mandatory retention kind; immutable
snapshot metadata also requires that kind. Missing or foreign definitions retain
the current hard-cutover rejection behavior. The full catalog ReleaseSafe suite
also passes 123 tests under this definition, including historical reader cursor
isolation and ordinary retained-reader allocation failures. Documentation passes
its ownership tests, strict types and production build; local link checking passes
5,506 links across 559 files.

The expanded `nix develop --command zig build test-direct-table-service
-Doptimize=ReleaseSafe` schedule passes 518 signed Table requests against a private
node. The unprivileged executor retains the original history grant through a
corrupted acquisition reply and restart, reads the original two-row cut one row
per page, and records a no-op DELETE as a separate logical acceptance. A later
restart preserves the exact saved point. After the existing CRUD/DDL schedule,
history includes schema changes and retirement of the original Table, while the
original and no-op cuts still read their original rows. Same-name recreation
does not enter that history. A corrupted release reply and another restart
recover the terminal lease state; further history reads and reacquisition reject.
This qualifies the public retention/read protocol, not the maintained-query
coordinator, which still requires migration.

The query `direct history records` ReleaseSafe filter passes eleven selected
and imported tests. The new 246-byte source record preserves maximum-width
Table coordinates, the original lease/authority/interpretation and distinct
no-op acceptance commitments in one native metadata value. Every truncated
prefix, a foreign definition and a noncanonical retention tag reject. The
`direct Table preparation` filter also passes eleven tests, including correct
local errors for missing capture/snapshot input without turning an already
sent command into a known rejection. The diagnostic mapping gate passes with
those two caller codes shared by Board inspection.

The complete public `test-direct-captured-query` regression also passes after
this definition replacement: original-cut single-source recovery, wide/nested
Fuze/Arrow pages, composite-key hit/absence, shared-alias and independent-Table
relational capture, released-pin result disclosure, revocation/restoration and
fresh terminal cleanup after credential rotation. The earlier ten-language
installed-package run below predates the retention-kind addition; its rerun
under the new definition remains pending. Full query-package and repository
checks remain incomplete while the older consumers are migrated.

## Catalog prefix reuse — 2026-10-26

The [retained records](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/catalog-prefix-2026-10-26/report.json)
include source-patch attribution, task logs and the failed hosted baseline.
Hosted run `40278906228` passes nineteen growth tasks at `e4b4955cb`, then
`test::catalog` fails when its 139-resource writer reaches the unchanged
5,400-second deadline. Progress reaches resource 129; later resource operations
take about nine to ten seconds and load thousands of pages. The request owner
constructs a new catalog and replays its entire history for every request.
The failed lane does not qualify the remaining tasks.

At `14c7175e3` plus the catalog-prefix change, the pinned compiler's catalog
command `zig build test -Dtest-filter='direct catalog recovery'` passes six
tests. A disk-backed schedule uses one resident index page and nineteen catalog
records. Full recovery makes 28 log reads including referenced operations;
reuse makes one boundary read after destroying the original request allocator.
An accepted append with a lost acknowledgement forbids exporting newer state;
recovery from the old prefix reads the boundary and new record, preserves the
original admission and makes its exact retry append nothing. A replacement
performs full recovery and observes the same state.

Negative cases reject a changed root/hash/configuration, shortened history,
missing current index root and a terminal operation reopened by an invalid
successor. `just test::local-catalog` also passes the signed disk-backed native
composition with prefix reuse, including credential changes and revocation after
response buffering. The complete catalog package passes **75/75** Debug tests
(five minutes, reported MaxRSS 53 MiB). `just test::node-concurrency` passes
overlapping provider reads and signed commits, current revocation and concurrent
exact retries with one receipt. The unchanged `just test::direct-table-service
resource-growth` completes in **926.14 seconds**, including local compilation.
It provisions and initializes 139 native KV/Document objects, reads every typed
value before and after SIGKILL/restart, traverses eight-entry directory pages and
recovers the original first receipt through 1,437 typed catalog calls. Native
and catalog cache budgets, workload and phase deadlines are unchanged.

These checks establish selected recovery and authorization cases and a count of
catalog log API reads. The local and hosted runs have different machines and
build/cache conditions; their elapsed times are not a matched speedup measurement.
They do not measure physical I/O, qualify initial recovery performance, or make
the failed hosted lane a pass.
The mechanism assumes immutable accepted history within one exclusive live
owner; it adds no persisted format, checkpoint, grant cache or collection right.
The first repository check rejects stale diagnostic inventory after adding the
internal recovery methods. The regenerated inventory retains the existing error
names and public mappings; the complete check and clean qualification remain
pending at this checkpoint.

## Scoped direct Table read delegation — 2026-10-23

The direct request definition is
`d5cad2104285ea53f190c0c090bb3ab40db2f6555970d251bfa5361b2ffaf964`.
The catalog package's focused ReleaseSafe run with `-Dtest-filter='direct Table'`
and `-Dtest-filter='direct read delegation'` passes. Independent Python/OpenSSL
fixtures verify both caller and executor signatures, the exact definition/data
frontier, pin owner and purpose commitment. Tampered scope, executor, frontier,
caller role, action and missing mandatory delegation fields reject.

`just test::direct-table-service` passes 460 typed HTTP calls. An executor with
no database or Table grants acquires and reads only its caller-delegated pin.
A corrupted acquisition reply leaves the original grant for exact recovery after
restart. The same pin returns its two original rows, including a 64 KiB payload,
after UPDATE/DELETE, ALTER, rename, DROP, name reuse and another restart. Current
permission revocation denies reads. Discovery, other objects/pin owners and
delegation chaining reject. A corrupted release reply is reconciled after a
third restart; the released pin cannot reopen.

`zig build test-local-catalog -Doptimize=ReleaseSafe` also passes. Its real native
policy fixture changes the executor credential, caller credential and Table
ownership after rows are buffered but before the final response check. Each
change suppresses disclosure. A fresh executor proof resumes with the retained
caller grant; even restoring the caller's original key cannot revive its stale
credential epoch. The executor's own direct CONNECT check remains denied.

The Fuze ReleaseSafe suite, `just contract::check`, diagnostic mappings, inferred
error boundaries and 3,387 outcome projections pass. The collation diagnostic
mapping now includes explicit unsupported-profile rejection. Source inventory
records 577 production owners and 4,729 owner/error pairs; that inventory alone
does not certify public mappings. Documentation links also pass.

This proof covers the direct read capability and its native policy owner.
Captured-query admission/cleanup, result evidence and language SDK migration
remain separate work. No physical Table collector is exercised or implemented.

## Installed direct lifecycle, rollback and capacity — 2026-10-23

`just test::server-faults` passes the complete server lifecycle (361.57 seconds)
and bootstrap/gateway/rollback faults (45.28 seconds) in the pinned Nix shell.
The lost-caller and lost-status fixtures now refuse direct Table execution
through the private forwarding boundary. The run preserves exact operation
recovery, configuration history, revocation, deliberately dropped Tables,
process replacement, transport reuse and bounded shutdown. Removing mandatory
direct bootstrap fields rejects the retained installation without rewriting it.
Restoring an older private native-store snapshot is refused against the recorded
recovery position.

`just test::server-capacity` also passes (30.08 seconds). Its private ext4 volume
reaches actual `ENOSPC` after direct admission. Observation and shutdown remain
finite; after space is released and the manager restarts, the same operation
finishes with matched/changed counts of one and exactly one row. The container
uses private executable copies with the pinned Nix ELF interpreter. This run
does not qualify application capacity, SDKs, captured-query migration or
automatic Table flushing.

## Installed direct Table bootstrap — 2026-10-23

`just test::server-direct-tables` passes in the pinned Nix development shell.
The real installed CLI, local node, query host and SQL gateway run in a private
temporary installation. The proof checks the dedicated registrar and saved
initial intent, a signed read through the forwarding gateway, and rejection of
an ordinary Table read mislabeled as control traffic. SQL INSERT, UPDATE, SELECT,
CREATE, ADD COLUMN, RENAME, DROP and conditional DDL succeed while the fixture's
query source worker is stopped. An abrupt manager restart preserves rows and
the original bootstrap reference. DELETE and deliberate DROP survive another
restart without recreating the default Table; same-name CREATE remains usable.

This run does not qualify captured-query migration, language SDK adapters,
automatic point flushing, storage exhaustion or the broader installed SQL fault
suite. The older tests that block actor Table execution need failure injection
at the new direct boundary before they can qualify that boundary.

## Frontend dependency installation during builds — 2026-10-23

In the pinned Nix development shell, `just build release-safe` passes starting
without root `node_modules` or a project-local Vite+ installation. The
build installs the frozen workspace dependencies before compiling and embedding
Board. Existing Zig and package download caches remain available; this is not a
fully cold toolchain build.

`zig build transit-board transit-serving-example transit-work-items-gateway
-Doptimize=safe --summary all` also passes. Its build summary records one Vite+
install step shared by all three asset builds. Package manifests and the lockfile
remain unchanged. Prebuilt Board assets retain their separate offline Nix path;
this check does not rebuild the Nix package.

`just check` passes, including native units, CLI checks, generated contracts,
frontend formatting/types/tests and the documentation production build.

## Table definition acceptance and retained interpretation — 2026-10-22

After rebasing on `origin/main` at `adb18139`, `zig build test` passes all 43
storage package cases and all 10 local-backend package cases in the pinned Nix
shell. `just contract::check` passes after regenerating the shared current
identifier, schemas, language bindings and independent signing/byte fixtures.
The complete `nix develop --command just check` also passes, including the root
unit suite, 558 CLI diagnostic cases, the rebased external-editor proof, frontend
checks and the documentation production build. Its existing reactive-client lint
warning and benchmark SQLite resource warnings remain warnings, not failed gates.

The added storage cases cover:

- An accepted CREATE, RENAME, ALTER and DROP through the typed storage owner,
  lost DDL replies, exact retry after actual disk reopen, and altered retry
  content rejection. Rename changes the full definition while preserving the
  row schema and WAL row references. Recovery loads persisted metadata instead
  of substituting the opening template.
- Accepted DML retried under its original schema after ALTER and DROP. Durable
  pins acquired before and after rename retain their one-column schema after
  the live schema gains a column; authorized release survives restart.
- A 1,028-row ALTER through a one-page index cache, producing two replacement
  segments. A final injected authorization denial publishes no successor or
  receipt; the authorized retry publishes all rows in one acceptance record.
- A collation change that would merge `A` and `a` rejects without publishing
  either the schema or rewritten rows. This is a duplicate-key safety case,
  not independent qualification of all declared collation profiles.
- Missing declaration objects, a foreign definition with a recomputed valid
  content hash, and roots missing mandatory interpretation fields reject.
  Failed recovery preserves accepted WAL and blocks further reads.
- Allocation-failure enumeration leaves both the old metadata and accepted
  root unchanged on pre-commit failure; successful acceptance needs no
  subsequent allocation to install the new declaration.

The subsequent catalog and storage package suites pass after adding immutable
catalog-wide operation binding and exact accepted-definition observation. A
real disk reopen preserves the full original binding; attempts to retarget the
operation to another object or branch, or change its intent, conflict. An
independent full-width key oracle and corrupted/foreign claim bytes exercise
the storage boundary. Another 129 operation claims require no resident catalog
directory. `observeEvidence` returns a rename's original revision after the
same Table has subsequently been altered and dropped. These claims reserve
identity only; they do not establish durable operation admission or completion.

These are storage and native-adapter proofs. They do not establish catalog name
publication, durable pending/rejected/cancelled operations, installed direct SQL,
physical collection or named KV/Document/computation execution. The storage
owner retains all WAL and immutable objects. The full definition revision is
separate from row-schema revision in its new persisted format; prior formats
are rejected by the coordinated shared-definition cutover.

## Direct catalog reservations and Table publication — 2026-10-22

The pinned `zig build test` catalog package suite passes with seven added direct
catalog cases. Tests use the actual local log/object owners and an injected
policy callback. They establish:

- A durable name reservation remains invisible before Table acceptance; lost
  admission and Table replies preserve exact retry. Restart between admission
  and RENAME execution retains the old visible name until acceptance.
- DROP and same-name recreation select a new object/partition. Earlier operation
  inspection returns its original resulting definition. Late cancellation does
  not undo accepted work, and delayed settlement does not remove a later
  operation's pending entry.
- Cancelled reservations release names without reusing their object identities;
  competing names reject durably. An admitted ALTER blocks conflicting row work.
  Final injected denial preserves both admission and the accepted Table head.
- A required-column ALTER rejects against an existing row, preserving the entire
  prior Table root. Retry and cancellation cannot resume that rejected work.
- Missing admitted intent fails closed. A final listing guard denial returns no
  metadata page. A deliberately invalid accepted transition from cancelled to
  admitted fails recovery and leaves the offending log intact.
- Real disk reopen and paged listing of 129 Tables and operations work with a
  one-page index cache. Listing records independent Table positions and makes no
  catalog write. Direct row mutation also leaves the control-log head unchanged.

These are internal component proofs. They do not establish signed native
registration, concurrent service coordination, public typed/SQL execution,
durable DML admission, dependency RESTRICT or schema DDL beyond initialization.
The installed actor path remains active. Physical collection is absent, and
cross-Table listing is not a consistent catalog snapshot.

`nix develop --command just test::local-catalog` also passes the node composition
test against the real local native owner. Signed native administration registers
the database, schema and Table domains/objects. A caller with domain ownership
and no raw resource access admits CREATE. Transferring Table ownership before
publication denies execution; transferring it back permits exact completion.
Later ownership removal denies both definition and original outcome disclosure.
Restoring ownership recovers that outcome; retiring the resource then denies it
despite retained Table grants. The request adapter rejects a changed request
digest and a forged signature. This test does not exercise an HTTP Table route
or automatic registration orchestration.

The subsequent catalog suite passes eight direct-catalog cases after separating
CREATE admission from native registration. A disk reopen preserves a reservation
with no native object; cancellation stays terminal, and attachment of the later
binding preserves the reserved object/partition through a lost reply. The
local-native composition also passes with registration performed after catalog
admission: stale checked policy rejects native BEGIN, exact repeated BEGIN
recovers one native change, and lost attachment remains pending until Table
acceptance. The client and protocol package suites, `just contract::check` and
the diagnostic error/outcome checks pass after coordinated regeneration.

That change replaced stored CREATE intent's supplied native ID with a selected owner
role and added the retained `ready` phase. It selected the shared definition
derived from `transit.native.v1.catalog-provisioning.2026-10-22`; the preceding
definition remains an explicit rejection case. The service registration loop
and public direct Table route are still absent.

## Durable Table row admission and outcomes — 2026-10-22

The subsequent `just test::local-catalog` run also passes explicit node-owned
CREATE progression through `LocalCatalogRunner`. A one-step request leaves the
operation admitted; a lost native append acknowledgement survives engine/catalog
reopen and resumes to one published Table. Repeating execution returns the same
outcome without another native commit. Zero work budgets reject, and execution
of an unknown operation publishes nothing. Retiring the backing resource after
native preparation denies the registrar commit, without creating a Table binding.
This qualifies the internal runner and current-caller fence; HTTP dispatch and
installed SQL integration remain separate gates. The full `just check` passed
at `75045174` before this runner addition, in a detached worktree with locked
frontend dependencies installed.

The pinned storage package suite passes **52/52 tests** after adding frozen
binary row intents, mandatory operation/pending roots, terminal controls and
matched/changed outcome counts. The additional cases establish:

- Lost admission and row-commit replies survive actual disk reopen. Inspection
  does not execute work, and late cancellation returns the original commit.
- Revoked access denies execution and observation. Regrant permits the exact
  admitted work; a changed row basis produces durable rejection. Control progress
  and read pins do not invalidate the admitted logical basis.
- A late duplicate-key failure publishes no row prefix. Cancellation remains
  terminal across replay. Definition changes reject while row work is pending.
- Point and bulk UPDATE atomically exchange primary keys while retaining row
  identities; destination collisions and replacement identities reject. Outcomes
  survive replay, including canonical no-op matches without changed row bytes.
- Disk-backed pending work reaches 129 operations with one resident index page.
  Missing frozen work cannot execute. A forged cancelled-to-admitted transition
  fails recovery and leaves the owner unavailable.
- Frozen typed rows preserve supported finite floating-point bits, reject an
  incompatible definition even under a recomputed object hash, and enforce the
  admitted action's change shape.

`just test::local-catalog` also passes with real signed native ownership changes
around row admission and execution. It verifies that revocation denies both
execution and cancellation, exhausted ordinary storage leaves work admitted,
and explicit cancellation succeeds through reserved control capacity. Regrant
permits another exact operation; resource retirement denies its result. Row
operations leave the catalog directory root unchanged.

These are component and native composition checks. Installed Table SQL still
uses the actor path; public transport, SQL lowering, concurrent service
coordination and automatic recovery scheduling remain unqualified here.
The stored-format cutover uses the shared definition derived from
`transit.native.v1.table-operation-admission.2026-10-22`, with the prior definition
retained as an explicit rejection case. No older root defaults missing operation
directories or outcome counts.

After regeneration, the catalog suite passes **100/100 tests**, including the
new DML/DDL coordination and lost-reply case. The local backend passes **10/10**,
including rejection of a supplied object digest that does not match its bytes
before quota reservation or object publication. `just contract::check`, the
native catalog composition and diagnostic mapping/error/outcome checks pass with
the new definition. Installed qualification is still separate.

## Prepared SELECT over retained direct Tables — 2026-10-23

Query `zig build test --summary all` passes **141/141** tests in the pinned Linux
Nix shell (135 main and six spill checks; MaxRSS 65/46 MiB). The new binding case
distinguishes the complete selected caller/namespace identity from the separately
captured data fingerprint and rejects changed connections and definitions.

`just test::direct-table-service` passes **221 typed HTTP calls**, including
read-only SELECT preparation, numbered typed parameters, binary and NULL
projection, a NULL predicate, request-budget exhaustion, wrong parameter count
and released-pin refusal. Failed openings leave the caller's original pin usable;
three parameter bindings use that same explicit source. Existing mutation,
saved-intent, schema lifecycle, revocation and two-restart proofs also pass.
Diagnostic error/outcome checks and documentation links pass.

These tests qualify the typed retained-source interface. They do not establish
automatic pin acquisition/recovery in SQL sessions, relational source integration
or the installed gateway cutover.

## Direct preparation rights and immutable bindings — 2026-10-23

In the pinned Linux Nix shell, catalog `zig build test --summary all` passes
**110/110** cases (one minute, MaxRSS 66 MiB). Read-only namespace and exact
definition checks leave the catalog root, Table WAL frontier and object count
unchanged, including stale definitions and late denial.

`just test::local-catalog` passes with real local native authority. An UPDATE-only
caller can check UPDATE and execute private selection while a SELECT check
rejects. Returned native subject attribution agrees with the caller; changing a
lookup's authorization reference breaks its complete declaration commitment.

`just test::direct-table-service` passes **146 typed HTTP calls** across two
service restarts. A retained preparation binding survives a row update, rejects
ALTER, and cannot follow DROP/name reuse, including after restart. Namespace
inspection and current verified role checks use the public signed path. The
existing CRUD/DDL, predicate, retained-pin and revocation cases also pass.

`just contract::check`, diagnostic error/outcome checks and documentation links
pass after regenerating the shared definition and fixtures. These checks do not
establish installed prepared SQL or the default launcher's Table cutover.

## Direct Table preview — 2026-10-23

The catalog suite passes **109/109 tests** with read-only DDL preview. Repeated
preview leaves the catalog root, Table frontier, immutable-object put count and
operation-identity claims unchanged. It reports name, definition and logical-data
conflicts, classifies ADD COLUMN as a rewrite, rejects reuse of an existing
operation identity and denies disclosure at the final policy check. Response
validation rejects changed proposal fingerprints, bindings, contradictory
conflict/work fields and an operation result substituted for preview.

`just test::direct-table-service test::local-catalog` passes. The HTTP proof now
contains **92 typed calls**, with preview followed by `not_observed` operation
inspection before ALTER, RENAME, DROP and replacement CREATE admission. Its
two-restart, retained-source and current-revocation cases still pass. The native
composition checks pass alongside the network caller.

The shared current-v1 definition is derived from
`transit.native.v1.direct-table-preview.2026-10-23`. Generated schemas, binding
resources and independent signing fixtures were replaced together; the previous
definition remains an explicit rejection case. `just contract::check`, diagnostic
error/outcome checks and documentation links pass. Preview checks schema rules
and expectations, not every existing row's constraints or future execution
success. Dependency RESTRICT and installed SQL integration remain unfinished.

## Direct Table CRUD/DDL recovery — 2026-10-23

`just test::direct-table-service` passes **84 typed HTTP calls** through the
configured local owner. In addition to CREATE/INSERT/read, it changes a primary
key through point UPDATE, bulk-deletes another row, rewrites the remaining row
through ADD COLUMN, renames and drops the Table, and recreates its former name
with a distinct object. Accepted matched/changed/live counts are checked.

Two actual node restarts preserve all original operation outcomes. Re-executing
the original UPDATE after DROP returns that original commit and leaves the
replacement Table empty. One-row pages from retained pins still expose both the
original two-column data and the rewritten three-column data, including stable
row identity and a NULL added column. An empty replacement snapshot completes
explicitly. Pins are released after recovery. No Table work uses actor sends.

The direct schema/signing contract and documentation checks also pass. This run
covers these concrete CRUD/DDL cases, not every ALTER form or a concurrent HTTP
schedule. Preview, dependency RESTRICT, default-launcher/SQL integration,
automatic flushing and collector races remain unqualified.

## Direct Table HTTP owner and typed caller — 2026-10-22

`nix develop --command just test::direct-table-service` passes against a temporary
disk-backed local node. The independent Zig caller uses the signed public native
and `DirectTableClient` APIs. Its 18 typed calls cover CREATE admission/execution,
a 64 KiB point row, bulk INSERT, retained snapshot inspection, bounded scan and
release. The proof observes a real `.tseg` object from the bulk commit and no
actor send or turn commands for Table work.

The proxy corrupts a successful execution reply's request context. The caller
rejects that envelope and recovers the exact committed operation through
inspection. After an actual node restart, both original outcomes remain exact;
a pin acquired while the first row was unflushed still returns its original
64 KiB binary value and one-row source. Later live data contains two rows.
Ownership revocation denies both retained reads and outcome inspection; regrant
permits explicit release. An execution request cannot use the reserved control
lane hint. The owner shares native authority, storage quotas and process locking.

The existing `zig build test-local-native-service -Doptimize=ReleaseSafe` proof
also passes signed paged reads/turns, invalid replies, exact retry after restart,
current revocation and in-owner maintenance after adding the direct route.
Diagnostic error/outcome projections, the verification catalog and documentation
links pass. These runs do not replace the final committed clean-suite check.

This proves the configured local HTTP path. The default launcher and installed
SQL still use the actor Table implementation. Complete CRUD/DDL over this route,
concurrent request schedules, automatic point-row flushing, incremental recovery
and physical collection are separate unfinished work. Every request currently
replays its relevant catalog/Table history with bounded resident memory.

## Table authorization service isolation

The scoped changeset cutover uses definition
`3f918c9828cf632c52018e094e23cf4384d2c2fe288009aeea4c9aef1b696bb3`.
Its [CLI/ABI/host report](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/authorization-changesets-2026-10-14.json)
records **10.941 s** on dirty `6ab83ad0`. The expanded administration proof adds
two-intent partial publication, an unread second-begin reply recovered after a
node/store restart, repeated terminal observation, signed-document tamper
rejection, out-of-scope rejection, explicit membership removal and preservation
of unrelated grants. A policy change between completed and unprepared intents
rejects the remainder while keeping the earlier outcome visible and the recovery
file unchanged. The proof includes two node/store restarts in total and exercises
changesets through both the C ABI and host port. It does not establish atomic
multi-action publication or mixed data/provisioning transactions.

The focused client run passes **26/26 tests**, including scope/overlap validation
and owned restoration of signed documents. The repository unit task also passes
after the cutover. Semantic mappings pass all 11 declared
boundaries, with 16 authorization caller classifications. The first generation
attempt rejected missing sequence bounds on the new host collections; explicit
32-entry field bounds were added and regeneration passes. The first expanded
integration invocation used an incomplete grant-inspection query; after adding
its required grantee, both the rerun and current-definition run pass.

The schema and administration cutover uses definition
`3dccf1d571d3e126c9b2d0c4f5f7fe474b3b69ec93bfbcd169808ccb2e9b990a`.
The [CLI/ABI/host report](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/authorization-cli-schema-2026-10-14.json)
records `just test::authorization-cli` passing in **4.094 s** on dirty `56dec28c`.
It checks read-only preparation, private non-replacing artifacts, exact retries
across one node/store restart, bounded checkpointed apply, receipt recovery,
stale proposal preservation, foreign/missing definition rejection and the same
saved record across the installed CLI, C ABI and host port. This establishes
the shared administration boundary, not ergonomic language SDK support.

The [schema Table report](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/authorization-tables-schema-2026-10-14.json)
records the expanded `just test::authorization-tables` passing in **253.639 s**
on the same dirty revision. In addition to restricted-reader isolation and the
existing restart/revocation schedule, it checks CLI/service agreement on SQL
plans, schema creation/rename/drop/name reuse, rejection of nonempty DROP and
default SELECT grants affecting only subsequently created Tables. The direct
catalog CLI fixture receives an explicit native inspection grant; the restricted
reader receives neither that grant nor raw-resource rights. These timings
include setup and do not measure query latency.

The selected authorization syntax also passes the SQL grammar task with **99
documentation examples**, 174 SELECT ASTs, 33 relational ASTs, 32 syntax
exclusions, 14 extensions and no ANTLR diagnostics. The diagnostic grammar task
passes **410 public cases** and **594 grammar obligations**, and the mapping
check covers 11 public boundaries. The focused client run passes **24/24 tests**,
including post-submit ABI allocation failure preserving an unknown outcome.
The repository `just test::unit` task and the current-definition
[native restart proof](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/authorization-native-schema-2026-10-14.json)
also pass. Changesets, remaining subject transports, adapters, SDK workflows and
clean CI remain separate delivery gates.

The [serving authorization report](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/authorization-serving-2026-10-14.json)
records `just test::authorization-serving` passing in **445.170 s** on dirty
`ff45edb6`, retaining the definition and six executable hashes. An ordinary LOGIN
caller selects a NOLOGIN role through SET-only membership. It prepares and
submits controls, reads a private snapshot, and cannot inspect native processes
or backing resources. Tampered roles and missing definitions reject. Credential
rotation invalidates the old read proof while the exact old control remains
recoverable. Membership revocation terminates SSE with `denied`; Table SELECT
revocation terminates WebSocket with `denied`. Restarts preserve denial, and
session-status reads omit the Table declaration. The preceding Table schema,
defaults, finite joins, CLI recovery and node/store restart checks also pass.
This is the explicitly configured insecure-HTTP development profile, not TLS,
installed-client or durable refresh qualification. One snapshot takes **5.012 s**;
the gateway's resident size sampled afterward is **50,827,264 bytes**, not a peak
or throughput guarantee.

The associated core run passes **110/110**, and serving passes **50/50** tests.
The repository test task passes all **85 steps**; its latest run executes
**125 tests**, with remaining steps cached. Earlier executions in this group
cover fresh captured-result disclosure by a separately authorized recovery
caller, unchanged execution attribution, missing/misbound proof rejection and
subsequent denial. These are injected-store result checks; native durable-query
qualification remains open. The Flight gateway compiles, the reactive browser
suite passes **36/36**, and the shared HTTP proof passes framing, capacity,
deadlines and joined shutdown. Full checks, native proof-bootstrap migration,
installed SDKs and committed-source clean CI remain separate gates.

The subsequent retained-reader changes pass all **85 repository unit steps**,
executing **326 tests** with remaining tasks cached on dirty `eab791f2`.
The checks bind maintained-result disclosure to the requested revision, mode,
predecessor, original bundle and budget, and reject mixed selected roles in a
relational read. Resumed Table history now checks the original object's current
SELECT privilege. The first ReleaseSafe disk run exposed that missing check;
its rerun and maintained-query qualification remain separate from these unit
results.

The [application authorization report](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/authorization-work-items-2026-10-14.json)
records `just test::server-applications` passing in **937.687 s** on dirty
`ea0a1ec6`, under definition `d70f7dc0…`. Explicit operator provisioning persists
14 authorization changes before submission and verifies exact repeat recovery.
Catalog initialization retains its native profile; application restarts do not
regrant Table permissions. The installed workflow passes worker replacement,
worker loss, installation restart and all **19 row migration steps**, with
**21 receipts** and installation generation **9**. Sampled manager RSS peaks at
**45,662,208 bytes** and checkpoints at **3,038 bytes** in this schedule. The
report retains the five executable hashes. The root unit/build check passes
**142/142 steps**; its latest run executes **11 tests**, with other steps cached.
The added regression leaves registration-blocked input unresolved for the host
handshake, instead of committing an application failure.

The [native Table report](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/authorization-native-tables-2026-10-14.json)
records `just test::typed-tables --cold` passing in **698.059 s** on the same
source/definition. It covers lost send/turn replies, exact CLI recovery, all
**28 logical descriptors**, prepared parameters, held-snapshot renewal,
current SELECT denial, retained history and captured relational results across
checkpoint restart. Buffered vector results and noncontributing join sources
remain authorization-bound. Cancellation accepts either durable cancellation
or a write already committed before cancellation. Installed SDKs, maintained
relations, physical exchange and SQL wire gateways are not exercised by this run.

The subsequent [maintained Table report](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/authorization-maintained-2026-10-14.json)
records `just test::typed-tables --cold --maintained` passing in **3,448.170 s**
on dirty `791f6216` with the earlier definition retained in the report. Its
maintained schedule takes **2,686.078 s**, publishes **26 revisions** (eight
changing and 17 no-op successors), executes **1,739 maintained turns** and retains
**183,707 bytes** of relation state. Ongoing input reaches a nine-head-revision
backlog and drains it; observed publication lags are **335.591–899.007 s**, with
**900.060 s** catch-up after the final input. These local costs are not latency
guarantees. Exact delta retry, delayed backfill, disk restart, current denial,
schema failure and drop/name-reuse failure all pass. The surrounding Table suite
also completes, totaling 2,505 turns while retaining the four-write/256-byte
native bounds. Installed callers and physical exchanges remain separate checks.

The exchange authorization report (archived)
records `just test::relational-exchanges` passing in **645.972 s** on dirty
`65bd94f4`, definition `c7446846…34cccd`. Its one-worker/one-partition and
three-worker/seven-partition layouts retain the original signed assignment
through every handoff phase. Exact acceptance retry, producer loss, node/store
restart, missing/corrupt checkpoints, unavailable/truncated/corrupt reads,
current native-reader denial, stale credentials and source-owner expiry pass.
The schedule commits 672 turns with at most four mutations and 256-byte values.
This run does not claim a separate SELECT-revocation injection at every exchange
phase; executable hashes were not captured for this invocation.

The public-query restart proof passes on dirty `a96989f7` with
`just test::public-query` using ReleaseSafe. It exercises actual CLI/source
hosts, 41 exact INT64/NULL rows, frozen retry, fenced crash recovery, busy
admission, schema rejection, incomplete-result refusal, cancellation and current
read denial. The preceding Debug run reached its 300-second observation deadline
while the worker was progressing; that run remains failed. The proof now uses
the same optimized checked profile as the other native disk schedules and still
requires complete results before success.

The Station authorization report (archived)
records the ReleaseSafe Station integration suite and actual local launcher
passing on dirty `ca76ae7a`, definition `c7446846…34cccd`. The ledger uses explicit
LOGIN roles, SET-only data-role membership and native database/schema/Table
grants. SELECT revocation between capture and publication denies the saved
query while raw worker reads remain granted. Table/audit/reply publication,
exact receipt retry, worker/store recovery, registry, supervision and lifetime
checks pass. The local launcher also passes three-worker upgrades, credential
rotation, Board inspection and stop/start; its courier recovery observes a
30.294 s replacement and 19.010 s query completion. These are local observations,
not latency guarantees. Compose/reference execution and the final clean-source
check remain separate; executable hashes and total elapsed times were not captured.

The [reactive authorization report](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/authorization-reactive-2026-10-14.json)
records the TLS/reactive refresh schedule passing in **162.64 s** on dirty
`ca76ae7a`, definition `c7446846…34cccd`. It exercises two same-principal views,
exact lost-follow retry, fair bounded admission, worker replacement and full-width
identities. Removing raw resource READ preserves mediated refresh; removing native
Table SELECT denies refresh and new admission. Retained denial diagnostics stay
stable after restoration, and pause/close controls remain available. Executable
hashes and overall build time were not captured.

The [final-definition capacity report](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/authorization-reactive-capacity-2026-10-15.json)
records two clean `f7e5dc98` refresh attempts failing at the same native
maintenance send with explicit `HttpCapacity`. The fixture now retries the
identical serialized command within its existing ten-second window. Explicit
capacity assertions and other rejections remain visible; runtime admission,
deadlines and protocol semantics do not change. Five regression cases pass,
including two that fail against the old fixture. The complete corrected TLS
refresh preflight passes in **234.683 s**, with a **210.62 s** runtime schedule,
on `f7e5dc98` plus the recorded fixture changes. The deterministic cases exercise
capacity retries; the full runtime run does not record an additional retry.
The same report retains the first installed-application inspection failure and
the unchanged fresh lifecycle passing in **1,237.070 s**. That successful rerun
does not establish the earlier unavailable response's cause. Final committed
clean-source qualification remains separate.

The serving lease-maintenance report (archived)
retains a clean `6ecf24fa` attempt whose post-revocation snapshot returns
`reactive.session_expired` instead of the expected access denial. The fixture now
renews its unchanged **28-second** lease around credential, membership and SELECT
revocation, including an independent renewal after SELECT is removed. The
complete serving proof passes in **499.140 s** on that source plus the recorded
fixture correction. Its eight renewals retain **22,461–24,315 ms** of lease time
on return; snapshots, SSE/WebSocket denial and gateway recovery pass. The complete
TLS refresh task also passes in **398.894 s**, with a **159.12 s** runtime schedule
and one actual native-capacity response recovered through an exact command retry.
These fixture measurements do not establish latency guarantees. Expiry remains
an independent lifecycle outcome, and final committed-source checks are separate.

The [Flight authorization report](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/authorization-flight-2026-10-14.json)
records the real TLS PyArrow and ADBC C/Python suite passing with original-subject
query bundles and role-bound tickets. Its 41-row finite statement/retry schedule
takes **84.70 s**; schema, exact int64/null rows, empty results, counts, aliases,
sum, compiler diagnostics and retained overflow diagnostics after gateway
replacement pass. Current disclosure denial passes. This is the configured
infrastructure-reader profile, with native source/request resource access;
selected-role ticket mismatch is a unit check and the fault/load schedule remains
separate. Executable hashes and source/definition are in the report.

The [final-definition Flight fault report](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/authorization-flight-faults-2026-10-15.json)
records `just test::flight-faults` passing on dirty `24f2ba92` with definition
`67f02f8b…2a15e`. Revoking native Table SELECT after a returned batch denies the
remaining result while raw resource reads stay granted. Pooled authentication,
ticket tamper/scope/expiry, concurrent admission, control reserve, slow HTTP/2
output, malformed frames and Board metadata redaction pass. The same complete
result remains readable after gateway/worker/node/store restart; exact retry and
permanent source retirement also pass. The report retains executable hashes,
finite-statement timing and the sampled gateway RSS. The first runs exposed an
obsolete SQL syntax expectation and transient native capacity immediately after
restart. Recovery now retries only UNAVAILABLE for the same retained reference,
within 180 seconds, discarding any failed partial read.

The [installed general Table report](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/authorization-catalog-sdks-2026-10-14.json)
records all ten SDKs plus Python async completing Table creation, nested typed
mutation, schema change, deletion, name reuse and saved original-outcome recovery
in the native cold-storage schedule. It passes in **1,359.385 s**, with 1,190 turns,
359 sends, at most four mutations and 256-byte values. The enclosing CLI, prepared
parameter and captured-query restart checks also pass. This run uses the explicit
infrastructure-reader profile and the source/definition recorded in the report;
restricted mediation remains a separate schedule.

The subsequent [restricted SDK report](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/authorization-restricted-sdks-2026-10-15.json)
records all ten installed SDKs plus Python async passing in **683.248 s** on
dirty `24f2ba92`, definition `67f02f8b…2a15e`. The caller selects a NOLOGIN data
role through SET-only membership, has scoped native SEND and cannot read the
backing resource. Each caller creates a Table, mutates nested typed values,
changes its schema, deletes/drops, reuses the name and recovers the original
saved outcome after handle replacement. Revoking database CONNECT then returns
the SDK's access-denied category, not a generic failed transport. Per-caller
schedules take **41.885–52.981 s**. The surrounding CLI/schema/defaults,
credential rotation, two service restarts and authority/disk restart checks pass.

The first attempts found a .NET test-consumer integer type mismatch and a
policy-revision conflict while registering a replacement Table. The shared
caller now retries only that mediated, unsubmitted read conflict within its
existing bounded retry budget, repeating authorization without changing saved
work or policy preconditions. The complete rerun passes with strict denial
assertions in every language. Runtime executable and log hashes are in the
report. This is the explicit loopback service profile, not optional SQL listener
packaging. `just bindings::authorization` builds the packages and runs this
schedule in the ordinary bindings lane; native CLI/ABI/host administration also
runs in the ordinary core lane.

The [final-definition administration report](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/authorization-administration-2026-10-15.json)
records `just test::authorization-cli` passing in **10.965 s** on dirty
`c740b001`, definition `67f02f8b…2a15e`. CLI, C ABI and host-port preparation,
bounded apply, scoped changeset partial recovery and explicit removal pass across
two authority/store restarts. Foreign/missing definitions reject, and stale saved
records remain unchanged. The report retains the four executable/library hashes.

The [installed Unified Table report](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/authorization-unified-sdks-2026-10-14.json)
records all ten SDKs plus native ABI, local port and Python async callers passing
the signed native workflow in **699.08 s**, using the `d1b3aff0` implementation
with uncommitted integration changes and the definition recorded in the report.
All thirteen callers agree on Boolean/SQL inspection and parameter compilation.
The schedule retains the original signed bundle through exact upload retry and
worker/node/disk-store restart, then verifies **41 rows, six segments and 15,120
Arrow bytes**, current result denial and released source pins. All ten installed
codec suites also pass. This is the explicit infrastructure-reader query profile;
restricted-user SDK mediation and the full installed administration workflow
remain separate gates. The report preserves executable and log hashes.

The query package's full `zig build test --summary all` passes **134/134 tests**
after the original-role and exchange-assignment changes. The new injected test
rejects altered caller/epoch/role, worker PID, layout, quota, query and source
basis, and distinguishes local context checks from signature verification.
The native catalog query tests also verify recovery under a separately authorized
reader without changing the original bundle. These checks do not establish the
disk-backed physical exchange schedule; that integration gate remains separate.

The SQL gateway package passes **20/20 tests** after retaining schema and selected
role in account bindings and operations, separating private readers from SQL
callers, and binding verifiers to native login identity/epoch. The ledger test
rejects a correctly signed step that changes the accepted role, and retains the
same pending bytes across coordinator fencing. Regenerated contracts and all ten
SDK package builds pass for definition
`c7446846aac6473237f91be61e004180fd8386136217c4cd09160b382e34cccd`.
Earlier TLS integration attempts exposed missing service inspection, a short
detached-write observation window and a driver ping before the intended revoked
PREPARE check. Those attempts remain failed; the complete rerun is a separate
gate from these package checks.

The TypeScript catalog migration passes `just bindings::node-check` on dirty
`48b25956`: formatting, lint, both package type checks, four client-port tests
and **67/67 Station tests**. Public catalog values now carry native bindings,
selected role/schema and authenticated-subject observations; the removed local
policy API is absent. Boundary tests reject foreign callers, audiences, selected
roles and schema namespaces, and preserve owned context bytes. This is Node
adapter validation, not an installed Node or all-language authorization proof.

The corresponding Rust catalog migration passes locked source `cargo test`
in the bindings shell with `TRANSIT_LIBRARY_DIR` pointing to the local native
artifact directory: **15/15 tests**, on dirty `ea0a1ec6`. It checks current subject
and selected-schema rejection, explicit native bindings and the 444-byte metadata
bound. The adapter exposes direct infrastructure reads and explicit mediated
reads separately, through the same shared implementation. No installed Rust
native workflow is claimed by this source-only run.

Ruby's catalog value/transport suite also passes against the source libraries
in the bindings shell on dirty `d7ff7ce5`. It covers the new native bindings,
immutable subject context, foreign principal/audience/selected-role rejection,
filtered schema namespaces, generated response validation, large frames and
uncertain receipts. The installed-gem grant/use/revoke workflow is still a
separate gate; these checks use injected replies and owned local child processes.

The .NET catalog migration builds four fresh NuGet packages and passes the
isolated installed consumer's value, generated-schema, metadata/history,
recursive-budget, uncertain-receipt and native read cancellation/join checks
on dirty `8e9de56f`. Subject decoding checks principal, selected role, audience
and epoch; namespace mismatch rejects returned metadata. This validates the
installed adapter boundary, not a live grant/use/revoke database workflow.

The Java catalog migration builds four fresh JARs with `javac --release 21
-Xlint:all -Werror` and passes the isolated installed schema/value/port suite
on dirty `363ea976`. The added checks bind descriptions to the selected role,
principal, audience and credential epoch, and reject a foreign metadata namespace.
Existing owned-value, large-frame, uncertain-receipt and joined-cancellation
checks pass with the matching native host. Live role/grant and mediated Table
use through installed Java remains separately unexecuted.

The C/C++ catalog migration builds fresh pkg-config artifacts and passes the
isolated C11/C++17 consumer checks on dirty `791f6216`. The forwarding native
boundary covers **56 cases**, including authenticated-subject mismatch,
credential epoch, explicit native profile validation, schema filtering, the
444-byte metadata bound, historical identity and retained uncertain receipts.
The package checks also pass handler Table ownership and saved-recovery checks.
These injected-reply and local ownership checks do not qualify installed live
role/grant workflows.

The C boundary rerun on dirty `a96989f7` passes the same **56 cases** with
positive description/definition fixtures independently validated against the
generated catalog-result JSON Schema. Subject context uses the native fixed
byte array representation, including UTF-8-shaped bytes; authorization revision
zero remains valid. This corrects the adapter decoder and strengthens the earlier
injected-reply evidence without claiming live grant qualification.

The Erlang/Elixir catalog migration builds eight fresh BEAM archives and passes
both isolated installed catalog consumers on dirty `a96989f7`. The checks cover
native authority profiles, selected role/schema, authenticated subject matching,
metadata/history, full-width operation identities, large frames, uncertain
receipts and joined waiter loss. Schema namespaces use native integers while
operation namespaces retain their full-width decimal encoding. The removed local
policy API is absent. These injected-reply and owned-port checks complete the
catalog adapter migration matrix; live SDK grant/use/revoke remains a separate gate.

All ten freshly packaged query SDKs pass `python3 -B tests/sdk_unified.py`
in the bindings shell on dirty `42592985`. Isolated installations check the
three source encodings, nine Boolean programs, six scalar types, five cell
states, 128-column bounds, nested values, full-width integers, malformed input
and owned Arrow results. The initial Node attempts exposed a missing namespace
in the consumer and a missing public export for the documented `decodeArrow`;
the passing rerun includes both corrections.

Each SDK now exposes explicit authorization of a locally prepared Table bundle,
through the shared Zig signer, and optional selected roles on query connections.
Sealing precedes persistence/fingerprinting; retained accepted bytes are never
re-signed. SQL compilation already supplies a sealed bundle. The installed codec
run validates values and compiled APIs, not live sealing or native recovery;
the combined signed-authority schedule remains a separate gate. The bundle bound
is 25,255 bytes, including its original-subject proof.

The [relational service report](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/authorization-tables-relational-service-2026-10-14.json)
records the expanded disk proof passing in **310.795 s** on dirty `f01c1064`.
It uses explicit INT64 join keys, grants the second source, observes a successful
join and complete empty join, then revokes that source and denies both queries.
The private spill directory contains no surviving files. The actual catalog CLI
returns a complete permitted query through mediation and rejects the forbidden
empty join. The preceding write/recovery, key rotation and restart checks also
pass. This proves the configured finite service profile, not durable-query,
gateway-session or installed-SDK qualification.
The root test task also passes (321 executed tests, with remaining tasks cached),
as do the 130-test query package, service-schema drift check and declared
diagnostic mappings.

The [mediated recovery report](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/authorization-tables-mediated-recovery-2026-10-14.json)
records `just test::authorization-tables` passing in **288.766 s** on dirty
`7ab3475c`, with the current-definition identifier and all five executable hashes.
Restricted CLI callers have no native process inspection or raw-resource reads.
They compile, sign, submit and recover INSERT/DELETE through the private service;
exact receipt lookup survives key rotation, fabricated input positions fail,
and subsequent SELECT revocation denies saved progress disclosure. Two service
restarts and one authority/store restart preserve the boundary. This extends
the earlier schema/defaults proof; it does not qualify SQL gateway sessions or
the ergonomic language SDKs.

The associated root run passes **1,138/1,138 tests**; focused client, catalog,
query, Station ABI and gateway runs pass **29/29**, **83/83**, **130/130**,
**21/21** and **20/20** respectively. Owned HTTP tests cover nested response
lifetime, bounded serialization before dispatch, response overflow and timeout
cleanup. Native tests verify exact send receipts under scoped process inspection
and deny other destinations and administrative requests. Regenerated service
schema and 11 declared diagnostic mapping boundaries pass. These are focused
checks, not complete installed-workflow or clean-source CI evidence.

`just test::authorization-tables` runs the actual node, signing CLI, catalog
worker, courier and Table service over disk-backed Ursula. The
[retained report](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/authorization-tables-2026-10-14.json)
records a passing 2026-10-14 run in **114.449 s**, on dirty `7eed560a`, under
shared definition `3e49cab638f15a788cc7a47a378b1956f80ed47e5366d64134cb22f3cd332b51`.
It records the four executable hashes. The fixture provisions roles, bindings,
grants and data through public signed operations; it does not edit private state.

Two real Tables share one resource. A restricted reader queries its granted
Table, sees only that Table in metadata, and cannot read the other Table's schema
or rows. Native resource, entry, batched-entry and snapshot acquisition are
denied. INSERT and CREATE preparation are denied. Altered request actions and
caller identities fail authentication. Credential rotation rejects the old proof
while preserving role grants. Two service restarts and one node/store SIGKILL
cycle preserve data and the final SELECT revocation without reprovisioning.

The focused protocol/core run passes **40/40** and **103/103** tests after the
cutover. The catalog run passes **80/80** tests, including per-object visibility
and exact unsigned-candidate signing. Independent subject-signature vectors now
include a context whose bytes are valid UTF-8, requiring JSON arrays throughout.

This closes the initial shared-resource service-isolation gate. It does not
qualify durable/maintained query propagation, all retained-result/recovery routes,
SQL administration, database adapters or installed SDK workflows. Their migration
is in progress; the broader repository unit run still has query-subject failures.
The full check and committed-HEAD clean suite have not passed this slice. Durations
include provisioning and are not query latency or throughput measurements.

## Original caller proofs in durable Table queries

On 2026-10-14, `nix develop -c zsh -c 'cd packages/zig/transit-query &&
zig build test --summary all'` passes **129/129 tests** on dirty `e3abdf88`,
under shared definition
`38d50a6745f3bafd7e25f1e8300af4fd054818a0a7b90426786b1294fd06b727`.
The proof binds canonical query bytes, coordinator, requester PID and request
resource. Tests reject absent proofs, modified queries and routes, invalid
signatures, changed credential epochs and changed roles before source retention.
Captured and maintained transitions retain the original signed request across
recomputation and release; current Table revocation still blocks result pages
and empty completion. The shared in-memory authority now verifies fixture
signatures instead of accepting a signed principal field alone.

These are package tests with injected authorization/storage, not a new native
disk or installed-service proof. The first repository unit run after the format
change passes 1101/1116 tests and fails 15 old consumer fixtures in Board,
Station applications and Serving. After migration, focused runs pass **13/13 Board API**, **45/45 Station
application** and **48/48 Serving** tests. The Serving run also exposed an
earlier Table-not-found failure boundary; its diagnostic now preserves the
actual missing Table witness. The CLI, query host and Table service build. Protocol adapters, original-subject watch/refresh transport,
installed workflows and the full check/clean-source run remain separate gates.

After the fixture and witness corrections, `nix develop -c just test::unit`
passes on the same dirty source. `just test::authorization-tables` also passes
again in **120.834 s** with the new definition. Its
[separate retained report](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/authorization-tables-query-subject-2026-10-14.json)
records the executable hashes and the same two-service/one-authority-store
restart schedule. This rechecks the actual restricted Table boundary after the
subject-reader refactor; it does not turn the injected durable-query cases into
native durable-query or installed-adapter evidence.

## Complete Table history and snapshot tail

The Table history slice replaces the shared definition with
`e8e13924650d3c8a21f2613e192a941b0c5530bcc03aa88a6b4374a9df44f024`
(SHA-256 of `transit.native.v1.complete-table-history.2026-10-12`). Stored Table
semantics now require an immutable predecessor for each head replacement.
Independent Python record fixtures and OpenSSL native signing vectors are
regenerated with contracts and enabled binding resources.

The first native `just test::typed-tables` run passes in 235.349 seconds, with
720 turns, 225 sends, maximum four mutations and 256-byte native values. It
freezes a snapshot while later insert/update/no-op/delete work commits, then
replays every consecutive transaction with paired values and stable identities.
Repeated complete cursors return the same transactions. Current catalog denial
rejects a held tail; DROP and name reuse preserve the original object's tail;
node and disk-store restart recover that same retired history. Existing captured
relational recovery, console/bridge/CLI and the 28-descriptor Table matrix pass.
No SDK language or growth option was selected. This aggregate runtime includes
more work than the earlier 631-turn schedule and is not a mutation latency
comparison or a maintained catch-up benchmark.

Station and catalog focused suites pass after fixing fixture entry timestamps
and explicit staging expectations. The broader root suite initially reports
1035/1041 passing: one stale native digest, four work-item fixtures using current
resource revisions for old entries, and a real no-page mutation failure when an
application reserves two terminal writes. The latter now reserves a durable
nonempty ID interval and stages completion without consuming the original
operation. Initial `just check` attempts stop at a stale SDK signing digest and
then the reviewed diagnostic inventory; neither is a complete passing check.
The final native rerun also passes in 234.919 seconds with the same 720 turns and
225 sends, including rejection of missing/foreign saved-position definitions.
The final `just check` passes after moving repository-tool reproduction commands
to this proof ledger: root unit and example tests, diagnostic contracts, binding
resources, real CLI checks, TypeScript/frontend suites and documentation build.
The schema-pair allocation-failure and every-history-coordinate checks are part
of that passing run. Local raw logs are
`.cache/relational-intake/native-table-history-final.log` and
`.cache/relational-intake/check-table-history-final.log`.

The measured native rerun passes in 229.817 seconds. Its four Table mutations
(insert, changed update, unchanged update, delete) take 16 native turns and add
10 predecessor records in 2.987 seconds. The delayed tail covers all 10 head
transactions and three paired changes in 0.230 seconds. Across the entire
schedule, 123 distinct accepted predecessor values total 26,455 bytes, with a
241-byte maximum; exact accepted retries are deduplicated in these measurements.
These are one local run's logical value bytes and elapsed observations, excluding
keys, indexes, storage amplification and physical disk usage. The raw result is
`.cache/relational-intake/native-table-history-measured.log`. Sustained-input
maintenance and committed-HEAD clean qualification remain separate gates.

## Conditional declarative catalog

The additive `transit-catalog` package composes Fuze's declaration compiler with
Station's existing two-column Table and four-mutation turn. It publishes the
Table descriptor, immutable definition, name binding and attributed receipt at
one commit. It is an explicit Zig integration API; the initial helper proofs do
not establish a supplied catalog host, signed caller, SQL administrative endpoint
or CLI/SDK route. The signed caller's separate evidence is recorded below.
Native/ABI definitions and existing stored formats
are unchanged. The [contract](../../../contracts/DECLARATIVE_CATALOG_V1.md) owns the
current profile; `SQL-CATALOG-01` maps its proof obligations.

Executed in the pinned bindings shell on development source based on `ef3053af`:

- Standalone `transit-catalog` `zig build test` passes ten component tests.
  Independent Python fixtures pin every record kind, key and definition digest.
  Tests cover full-width application IDs, mandatory definition checks, orphan
  namespace/row refusal, exact application retries, changed intent, three terminal
  conflicts, separate conditional policies, changed scope/schema/digest, private
  rollback and poisoned reads at every point-read boundary. A successful new
  creation performs seven private point-read callbacks, one bounded row-prefix
  page check and four writes. A private mutation before creation rejects the
  committed page check; a page-read failure poisons the turn.
- A dynamic-map component store holds 257 objects and lists them in 33 pages,
  each with at most eight definitions. Changed revisions, revoked inspection,
  private writes and malformed page shapes reject. This is bounded helper
  evidence, not native disk growth or performance evidence.
- Full `just check` passes, including package/unit and generated contract checks,
  frontend checks/tests and the production documentation build. This run preceded
  registration of the native proof and the following evidence documentation.
- Final `just check-core` passes after the orphan-row check. The independent
  `just test::sql` oracle also passes, including 182 declaration cases and the
  existing SELECT, unified-source and mutation schedules. Inventory/docs checks
  cover 52 invariants, 52 classified bounds, 12 SDK scenarios and 4509 links
  across 474 files.
- `TMPDIR=/var/tmp just test::catalog` passes against the real native authority
  and disk-backed Ursula. It loses one accepted caller-send receipt and one
  owner-commit receipt, restarts node/storage separately at both boundaries, and
  recovers the original frozen signed requests and exact receipts. An independent
  Python oracle checks all four stored records at one resource revision. Input
  progress, no-write application duplicates and terminal name conflicts agree.
  Changed native retry, stale ownership, revoked write authority and revoked
  reads reject; restoring write permission permits the same unaccepted request.

The final native schedule takes **2.406 seconds** with **155 reads**, **6 accepted turn
responses**, **8 resident authority pages**, at most **4 mutations** and **127
value bytes** for this fixture. Component maximum-name fixtures separately check
138-byte requests, 163-byte definitions and 155-byte receipts. The native timing
includes provisioning/recovery and is not a service latency or throughput result.
The report `.cache/verification/catalog/native.json` records source/dirty status,
counts and frozen binary hashes:

| Binary        | SHA-256                                                            |
| ------------- | ------------------------------------------------------------------ |
| Node          | `5329fb4df7e1435d79bb3145e43330011f1cbdd6e44165d380a46ca51bd36f26` |
| Catalog proof | `ac649f3e3410924cb1e03c58da4e1c975f8e209b6e3907f21fc280955be1f7a9` |

Logs are `/tmp/transit-sql-catalog-orphan-components.log`,
`/tmp/transit-sql-catalog-check.log`, `/tmp/transit-sql-catalog-final-checks.log`
and `/tmp/transit-sql-catalog-orphan-native-check.log`.
The native proof is registered in the growth lane. It creates two applied Tables;
it does not establish native catalog growth, host power-loss recovery or installed
caller compatibility. Native page scans may cross the catalog prefix; the helper
does not decode or return those other values, but cannot promise zero row-byte
I/O at the boundary. Current proofs do not qualify the remaining declaration,
dependency, lifecycle, maintained-query or effect systems.

At committed `97378a8e`, **`just ci-clean --lane core` passes all 18 tasks**
without inherited workspace build outputs in **702.52 seconds**. Independent
package builds take 139.81 seconds, Station 148.66 seconds and disk storage
213.72 seconds, including the 129.21-second readiness write. Completion metadata
and per-task results are retained under
`.cache/ci/clean/97378a8e43a2-transit-ci-twnd5sz1/`; the log is
`/tmp/transit-sql-catalog-ci-clean.log`. The following evidence-only commit changes
no production code. This is a clean core-lane pass plus the focused native/SQL
proofs above, not a complete clean-suite or administrative-surface qualification.

### Shared signed catalog caller

The additive `transit-catalog.Client` now prepares owned signed creation commands,
restores exact saved bytes, submits explicitly and separates admission/input
processing from original-request status. Description and status use bounded
current native metadata batches; they retain no snapshot or permission cache.
This does not enable a supplied host, neutral ABI, CLI or language SDK route.

On development source based on `97378a8e`, both new caller component tests pass
alongside the ten helper tests. They verify full-width identities, owned restored
bytes, canonical complete input, missing/foreign nested definitions and local
connection/signature rejection before transport. Full `just check` passes,
including 52 invariants, 53 classified bounds, 12 SDK scenarios, 4509 local links,
frontend checks/tests and the production documentation build.

The expanded `just test::catalog` schedule uses the shared caller for preparation,
saved-command restore, submission, observation and status. It preserves the exact
prepared bytes after caller/node/store replacement, returns pending/null before
application and processed/applied afterward, retains the original attributed
receipt on an application duplicate and rejects changed operation intent. Current
catalog inspection revocation hides old status while native reads still work;
revoked create policy blocks preparation while inspection remains available.
Native read revocation also prevents status disclosure. The earlier atomicity,
conflict, owner fencing and lost native receipt cases remain in the schedule.

The run passes in **3.310 seconds**, with **227 reads**, **9 accepted turn
responses**, eight resident pages, four mutations and 127-byte maximum fixture
values. It adds policy and observation operations, so its duration is not an
equivalent-workload comparison with the helper-only run. The proof binary SHA-256
is `a81fbd9cb9662196c91df512d4a6740e334e0dd7b7a85730ba9ac28c9ba6a82d`;
the node hash is unchanged. Logs are `/tmp/transit-sql-catalog-client-components.log`,
`/tmp/transit-sql-catalog-client-native.log` and
`/tmp/transit-sql-catalog-client-check.log`. This development evidence does not
extend the preceding committed clean checkpoint to the caller changes.

At committed `149bbe41`, **`just ci-clean --lane core` passes all 18 tasks**
for the signed caller in **717.91 seconds**. Package checks take 141.36 seconds,
Station 146.71 seconds and disk storage 229.67 seconds. Exact revision,
completion and per-task evidence are retained under
`.cache/ci/clean/149bbe41f0a0-transit-ci-l0fprhu0/`; the log is
`/tmp/transit-sql-catalog-client-ci-clean.log`. The following evidence-only commit
changes no production source. This qualifies the core lane and the focused caller
schedule above, not a full clean suite or a supplied catalog host.

### Supplied catalog host and explicit committed sources

The `catalog` role in the supplied `transit-query-host` now runs the shared
catalog behavior through GenServer. Initial framework/configuration/policy/input
disposition publication fits one four-mutation turn. Creation keeps its original
operation receipt; policy controls and rejected inputs retain separate attributed
dispositions. No neutral administrative ABI or CLI/language SDK route is implied.

`Turn.committed()` supplies the initialization composition's explicit read-only
captured source. A new Station component test proves private inserts, updates and
deletes stay out of both its point reads and pages, its view binding cannot change,
reader failures poison the original proposal, and ordinary Table/Turn pages still
reject after private mutations. The standalone Station tests pass. Catalog
components pass 17 tests, including independent policy-command/disposition bytes,
three-write helper composition, four-write behavior initialization, whole-proposal
rollback, process/effect-origin rejection, stale controls, manual-catalog adoption
refusal and poison at every behavior point-read boundary. Those private-store
tests do not independently establish native authority or durability.

On development source based on `bea9ed2f`, the expanded **`just test::catalog`
passes against the actual supplied host** and disk-backed Ursula. It loses the
host's initialization and creation commit receipts separately, holds exact retries,
kills the worker, restarts node/storage, and recovers each original signed commit
and receipt. Independent Python bytes verify the complete four-record initial
publication at one resource revision. Reusing the old activation rejects;
replacement workers run under fresh ownership. Duplicate initialization leaves
policy unchanged. A revoked create policy causes a recorded denial even for a
raw signed input that bypasses caller preparation. A later authorized input can
apply the same operation while the original input disposition remains unchanged.
Current native read denial also protects the signed caller's disposition API.
The earlier manual-owner and signed-caller schedules still run in the same proof.

The schedule takes **6.712 seconds**, with **512 reads**, **18 accepted turn
responses**, one lost caller receipt, three lost owner receipts, eight resident
authority pages, four mutations and a 127-byte maximum fixture value. It creates
four applied Tables across two resources. The read count includes host polling
and proof inspection; this expanded schedule is not an equivalent-workload
latency comparison or a native catalog growth/power-loss proof. The catalog role
allocates neither the query host's 4 MiB Arrow workspace nor its 1 MiB source
adapter. ReleaseSafe binary hashes are:

| Binary        | SHA-256                                                            |
| ------------- | ------------------------------------------------------------------ |
| Node          | `5329fb4df7e1435d79bb3145e43330011f1cbdd6e44165d380a46ca51bd36f26` |
| Catalog proof | `7a1070c7f73412109396917041bfb136c0cde0b99a6c154dc496f78194db810e` |
| Supplied host | `85aab2f0bd50c9e37f2cca4367dbb5fa028137a962ddd96526554fdbaf4a1c0d` |

The first native attempt failed in a fixture metadata read with
`StaleStateResource`: policy publication advanced the resource between acquiring
its revision and reading a disposition. The fixture now uses the shared atomic
metadata-batch API, preserving stale-cut rejection. Failure and corrected logs
are `/tmp/transit-sql-catalog-host-native.log` and
`/tmp/transit-sql-catalog-host-native-batches.log`. Full `just check` also passes,
including package/contract checks, frontend checks/tests and the documentation
build (`/tmp/transit-sql-catalog-host-check.log`). The real `just test::station`
regression also passes, covering Tables, exact retries, policy changes, captured
Arrow replies, worker/store recovery, fencing, registry, supervision and lifetime
(`/tmp/transit-sql-catalog-host-station.log`). Final independent SQL, documentation
and inventory checks pass: 182 declaration cases, 31 mutation cases, 4513 local
links across 474 files, 52 invariants, 53 classified bounds and 12 SDK scenarios
(`/tmp/transit-sql-catalog-host-final-checks.log`). The final component run also
passes after expanding read-failure injection across initialization, creation and
policy controls (`/tmp/transit-sql-catalog-host-poison-final.log`).
No existing native/ABI definition or
stored record layout changes; commands/dispositions and the explicit source are
additive, and existing creation requests keep their exact bytes.

At committed `fefb42c3`, **`just ci-clean --lane core` passes all 18 tasks**
for the supplied host and explicit committed source in **727.49 seconds**.
Independent package builds take 142.97 seconds, Station 148.36 seconds and disk
storage 230.44 seconds. The readiness write takes 147.48 seconds. Exact revision,
completion and per-task results are retained under
`.cache/ci/clean/fefb42c33b92-transit-ci-2j8mr2ji/`; the log is
`/tmp/transit-sql-catalog-host-ci-clean.log`. The following evidence-only commit
changes no production source. This is a clean core-lane pass plus the focused
host proof above, not a full clean suite or administrative CLI/SDK qualification.

### Signed initialization and policy controls

The shared catalog caller now prepares initialization and conditional policy
commands, using the same owned `Prepared` envelope, exact submission, input
observation and current-policy disposition reads as creation. Initialization
checks its connection/configuration binding; policy preparation reads the exact
configuration and target policy in one current native batch. The configured
administrator can restore application rights after self-revocation, while
disposition inspection remains denied until the restoration applies. Existing
creation bytes, native/ABI definitions and stored record layouts are unchanged.

On development source based on `3dea7fad`, standalone catalog tests pass **18
named component cases** (19 including the root import test). The saved-command
matrix now covers initialization, creation and full-width policy revisions,
owned restoration, missing/foreign definitions, altered identities and canonical
input. Invalid administrator/owner/scope and policy revisions reject before
transport. Full **`just check` passes**, including generated contracts, frontend
checks/tests and the production documentation build; later proof/documentation
edits receive their focused checks.

The final **`just test::catalog` passes in 9.918 seconds**, with **776 reads**,
**25 accepted turn responses**, two lost caller receipts and three lost owner
receipts. It restores a saved initialization send after caller/node/store
replacement, then preserves the supplied host's initialization/creation recovery
schedule. Two controls prepared at the same policy revision queue before the host
starts: the second records `stale_policy` after the first changes policy. Separate
target principals, absent-policy creation, exact policy duplicates and stale
preparation checks pass. Self-revocation denies creation and disposition reads;
duplicate initialization cannot restore those rights, but an explicit next policy
can. Four Tables, eight resident authority pages, four mutations and the fixture's
127-byte maximum value remain unchanged. The added controls, restart and polling
make this an expanded recovery schedule, not an equivalent-workload speed result.

The first control run returned `CatalogDenied` when the fixture attempted result
inspection before restoration had been processed. The fixture now waits for
explicit input observation before acquiring a newly authorized disposition;
the caller's current-policy rejection is preserved. The ordered run passes, then
the final run above adds independent target-principal cases. Logs are
`/tmp/transit-sql-catalog-controls-components.log`,
`/tmp/transit-sql-catalog-controls-check.log`,
`/tmp/transit-sql-catalog-controls-native.log` (failed),
`/tmp/transit-sql-catalog-controls-native-ordered.log` and
`/tmp/transit-sql-catalog-controls-native-targets.log` (final pass).
The proof binary SHA-256 is
`3d7ac8adf5b9a0d4d782b40c48bfbd3d26529f3c6bf882595cca550dfa3c798e`;
node and host hashes match the supplied-host entry above. This development result
does not extend that earlier clean checkpoint or qualify neutral administrative
bindings, CLI/SDK routes or general SQL grants.

At committed `98ddd4cb`, **`just ci-clean --lane core` passes all 18 tasks**
for signed administrative controls in **702.27 seconds**. Independent package
builds take 140.97 seconds, Station 149.08 seconds and disk storage 211.88 seconds.
Completion and per-task evidence are retained under
`.cache/ci/clean/98ddd4cbad77-transit-ci-cjfwraqj/`; the log is
`/tmp/transit-sql-catalog-controls-ci-clean.log`. This qualifies that committed
control caller and core lane, not the subsequent neutral bridge or native ABI.

### Neutral catalog caller values

The shared `Bridge.Action`/`Result` now covers offline creation compilation,
description, signed initialization/creation/policy preparation, exact submission,
observation and separate application/disposition reads. Full-width IDs and policy
revisions cross JSON as canonical decimal strings; native counters remain bounded
numbers and saved commands remain opaque. It delegates remote behavior to the
existing signed client and defines no new native/stored format.

Standalone catalog tests pass **21 total tests** including the root import test
on development source based on `98ddd4cb`. Two new bridge cases compare typed
neutral values with independently generated Python records, preserve owned names
and full-width values after source mutation, and reject numeric application IDs,
quoted native IDs, malformed decimal strings, changed scope and invalid saved
commands before transport. The local compile/capabilities cases use no transport.
The generated fixture owner is `tests/catalog_contract.py`; component output is
`/tmp/transit-sql-catalog-bridge-components.log`. Native ABI/port and idiomatic
language reachability are not established by these component tests.

### Catalog C ABI and native port

The additive `station_catalog_create/call/destroy` exports and `catalog_client`
port profile use the neutral bridge and shared signed client. Catalog calls
validate local recovery before dispatch and preserve `uncertain` after a valid
submission has begun. One operation per handle, bounded I/O, joined destruction,
key wiping and independently owned result buffers follow the existing binding
contract. Three new generated schemas and the optional catalog host profile are
propagated to every generated language resource. Comparing parsed ABI contracts
with the preceding revision shows no existing export-signature, status, definition
or existing schema change outside additive `HostConfig`/`HostRequest` fields.

On development source based on `d7b99144`, standalone binding tests pass **12
tests**, including the new catalog output-ownership, overlap, malformed recovery,
signature rejection and uncertain transport case. Full **`just check` passes**,
including contract generation/drift, native units, frontend checks/tests and the
production documentation build. `just bindings::node-check` passes its strict
TypeScript checks and 17 tests. Logs are
`/tmp/transit-sql-catalog-abi-components.log`,
`/tmp/transit-sql-catalog-abi-generate.log`,
`/tmp/transit-sql-catalog-abi-check.log` and
`/tmp/transit-sql-catalog-abi-node-check.log`.

The expanded **`just test::catalog` passes in 13.799 seconds**, with **1075
reads**, **33 accepted turn responses**, four lost caller receipts and three lost
owner receipts. Both a real C ABI handle and native-port child compile the same
independently encoded creation record, apply typed initialization/policy controls,
recover an unchanged saved send after caller/node/store replacement and preserve
the original creation outcome. The port is killed during uncertainty. Mixed
profiles, catalog calls on a query profile, numeric full-width IDs and quoted
native numbers reject. Current application inspection and native-read revocation
each hide earlier outcomes through both transports. Explicit port shutdown joins
cleanup. Earlier manual/shared-Zig and supplied-host cases remain in the schedule.

This run creates six Tables across two resources with eight resident authority
pages, four mutations and a 132-byte maximum fixture value. Its expanded work and
polling count do not establish an equivalent-workload speedup, catalog growth or
power-loss guarantee. The report remains `.cache/verification/catalog/native.json`;
the log is `/tmp/transit-sql-catalog-abi-native.log`. ReleaseSafe binary hashes:

| Binary        | SHA-256                                                            |
| ------------- | ------------------------------------------------------------------ |
| Node          | `5329fb4df7e1435d79bb3145e43330011f1cbdd6e44165d380a46ca51bd36f26` |
| Catalog proof | `3d7ac8adf5b9a0d4d782b40c48bfbd3d26529f3c6bf882595cca550dfa3c798e` |
| Catalog host  | `85aab2f0bd50c9e37f2cca4367dbb5fa028137a962ddd96526554fdbaf4a1c0d` |
| Native port   | `37b44139c09058e863d63c07a3cc78aa7edb803fb48b4ed2eafe384a8df68091` |
| Station ABI   | `98c76da16161abae1ab0fb1f91a9d2613f720b6acabb8e81c729fc9b3c7585f1` |

`just bindings::native` also passes the existing native/port local-codec,
gated-control, scoped-page, capture, exact host/disk recovery, current-policy,
Arrow query and materialization schedules
(`/tmp/transit-sql-catalog-abi-regression.log`). All eight language-package build
recipes pass, covering Python, TypeScript, Rust, Ruby, C/C++, Java, .NET and
Erlang/Elixir against the regenerated resources
(`/tmp/transit-sql-catalog-abi-sdk-builds.log`). These are package builds, not
installed catalog SDK qualification. Final docs/inventory/format checks pass
4521 local links across 475 files, 52 invariants, 53 classified bounds and 12 SDK
scenarios (`/tmp/transit-sql-catalog-abi-final-checks.log`).

Committed-HEAD **`just ci-clean --lane core` passes all 18 tasks at `2ecf2457`**
with no inherited workspace build outputs, in **701.65 seconds**. Independent
packages take 141.20 s, Station 147.35 s and disk storage 213.40 s. Evidence is
`.cache/ci/clean/2ecf24572ae5-transit-ci-62kkqyq2/core.json` and
`core.meta.json`; the full log is `/tmp/transit-sql-catalog-abi-ci-clean.log`.
The following evidence-only commit changes no production code. This is a clean
core lane plus the focused native/port schedule above; it does not qualify
idiomatic catalog SDKs, a catalog CLI or a complete clean suite.

### Explicit catalog CLI

`transit catalog` now uses the shared neutral bridge and signed caller. Offline
compilation accepts a scope-only connection without loading a key or contacting
an endpoint. Initialization, creation and conditional policy preparation require
new private saved artifacts; submission restores those exact commands. Typed
compiled fields must agree with current-definition canonical bytes. Input
processing, control/rejection dispositions and original creation outcomes remain
separate. The extracted private-file writer also preserves mutation CLI behavior.

On development source based on `8054f127`, the expanded **`just test::catalog`
passes in 15.439 seconds**, with **1204 reads**, **36 accepted turn responses**,
**five lost caller receipts** and **three lost owner receipts**. The added CLI
case uses its own 0600 output files again after caller/node/store replacement,
recovers the exact admission receipt and original creation result, then rejects
status disclosure after catalog inspection and native read revocation. The
schedule exercises seven applied Tables across two resources; maximum mutations
remain **four**, maximum fixture value **132 bytes** within the 256-byte bound,
and the authority uses **eight resident pages**. This enlarged recovery schedule
includes provisioning and polling; it is not a latency comparison, native catalog
growth proof or host power-loss guarantee.

The report is `.cache/verification/catalog/native.json`, with source revision,
dirty status and frozen executable hashes. The log is
`/tmp/transit-sql-catalog-cli-native.log`. ReleaseSafe node, proof and catalog-host
hashes match the preceding ABI schedule. Updated caller hashes are:

| Artifact        | SHA-256                                                            |
| --------------- | ------------------------------------------------------------------ |
| Native port     | `4bc5ed8c56b5302379c6c597ecd55d7bfecf89c86ffb4e03c63e864edf754622` |
| Station library | `3d668634629fe306a9628ea11b50ebd790783686a333e8e87a37980eb9083b93` |
| CLI             | `2a53d92f5383f3a3b9002531262272437fc6eaff900a1b145a9c02a6d4222572` |

The real CLI diagnostics now cover **346 cases**, including JSON/YAML offline
compilation, full-width IDs, file privacy/non-replacement, malformed and foreign
artifacts before key loading, invalid options and offline help. This extends
caller evidence; idiomatic catalog SDKs and native catalog growth remain.

Full **`just check` passes**, including generated contracts, 346 diagnostics,
4534 local links across 476 files, the verification inventory, frontend tests
and the documentation build (`/tmp/transit-sql-catalog-cli-check.log`). The
existing native/port/CLI **`just test::table-mutation` passes in 23.776 seconds**,
including exact saved-file recovery after the writer extraction: 1664 reads,
48 accepted turn responses, four lost caller receipts and one lost owner receipt,
four mutations, 256-byte values and eight resident pages. Its frozen CLI/library
hashes match this catalog run; its log is
`/tmp/transit-sql-catalog-cli-mutation-regression.log`. These are development
checks and focused proofs; committed-HEAD clean validation follows separately.

Committed-HEAD **`just ci-clean --lane core` passes all 18 tasks at `e107fe7d`**
without inherited workspace build outputs, in **710.32 seconds**.
Evidence is `.cache/ci/clean/e107fe7df44b-transit-ci-48en01yu/core.json` and
`core.meta.json`; the full log is `/tmp/transit-sql-catalog-cli-ci-clean.log`.
The following evidence-only commit changes no production code. This qualifies
the CLI core lane and focused recovery above, not idiomatic catalog SDKs or a
complete clean suite.

### Python catalog callers

The typed Python `catalog.Client` and `AsyncClient` compose the shared catalog
ABI. Immutable owned values retain full-width application IDs, current native
bounds and exact opaque prepared bytes. Both callers separate admission, input
processing, control/rejection dispositions and original creation receipts.
Cancellation of an await leaves the native worker owned; close joins cleanup.

On development source based on `e107fe7d`, strict mypy passes **22 source files**,
matching Python wheels build, and **`just test::catalog --sdk python` passes in
22.855 seconds**, including **1.859 seconds** of isolated package installation.
The script copies and hashes four wheels into the fixture, installs without
checkout imports, and uses both public synchronous and asynchronous APIs.
Initialization and conditional policy controls precede full-width creation;
lost admission recovery replaces caller/node/store and restores original saved
commands. Original-request status, current catalog-policy denial and current
native denial pass through every caller.

The combined schedule performs **1515 reads**, **42 accepted turn responses**,
**seven lost caller receipts** and **three lost owner receipts**. It creates nine
applied Tables across two resources, with **four mutations**, **133-byte maximum
fixture values** and **eight resident authority pages**. These times include
installation, provisioning and recovery; they do not establish latency targets,
equivalent-workload speedups, native catalog growth or host power-loss recovery.
All six frozen executable hashes match the preceding CLI schedule. The package
hashes in `.cache/verification/catalog/native.json` are:

| Wheel                    | SHA-256                                                            |
| ------------------------ | ------------------------------------------------------------------ |
| `transit-station`        | `7bd67ecab612be7df8204b181d2c1a5cdb37288c09d0da3fab6b3fbed3e23da5` |
| `transit-native-station` | `5380949f2c664d9418734f2f348fe37a304763fda1de9b4b341fe975d95ef022` |
| `transit-client`         | `be974f85e6ba910846dad633b5cdbb390e619a88bccbbefea72a83f865a48cc7` |
| `transit-native-client`  | `72ee6e0924bb4f9479fe630450dcefddd5f6d450d9489429f38a9b45b1252ba3` |

The installed value test independently checks byte/name ownership, canonical
full-width response strings and numeric types, malformed success responses and
injected response allocation failure preserving submission uncertainty. A blocked
adapter verifies cancelled-await overlap rejection and joined destruction. Those
injected cases establish Python ownership/error behavior, not authority outcomes;
the real disk schedule establishes exact admitted-command recovery separately.

Full **`just check` passes**, including generated resources, 346 CLI diagnostics,
4544 local links across 477 files, 52 invariants, 53 classified bounds, 13 SDK
scenarios, frontend checks and documentation build. Logs are
`/tmp/transit-sql-catalog-python-final-native.log` and
`/tmp/transit-sql-catalog-python-check.log`. The focused
`just bindings::catalog-python` recipe builds and runs this installed schedule;
`bindings::python-test` also includes it. Other nine idiomatic catalog SDKs and
committed-HEAD clean qualification for this Python increment remain separate.

Committed-HEAD **`just ci-clean --lane core` passes all 18 tasks at `70919367`**
without inherited workspace build outputs, in **706.64 seconds**.
Evidence is `.cache/ci/clean/70919367bbec-transit-ci-cian9wcj/core.json` and
`core.meta.json`; the full log is `/tmp/transit-sql-catalog-python-ci-clean.log`.
The following evidence-only commit changes no production code. This qualifies
the core lane plus the installed Python schedule above, not a complete clean
suite or the other nine catalog SDKs.

### TypeScript catalog caller

The public TypeScript `catalog.Client` uses the existing owned native port and
shared generated catalog request/result schemas. Frozen typed declarations and
controls retain full-width `bigint` identities; canonical byte getters return
copies and prepared text stays opaque. The client distinguishes original creation
receipts from input dispositions and preserves uncertain submissions, including
malformed successful native responses. Status decoding checks the complete
original request. No shared protocol definition changes.

On development source based on `70919367`, **`just bindings::node-check` passes
28 tests**, including 11 new catalog value/port-boundary cases and existing
mutation/runner ownership tests. Cases cover mutable input copies, native-number
versus bigint boundaries, invalid revisions, unknown observations, malformed
admission receipts and missing/foreign native definitions. Generated schemas
validate the real port path; injected hosts do not establish authority outcomes.

The final combined **`just test::catalog --sdk python --sdk node` passes in
29.190 seconds**, including **4.662 seconds** of isolated package installation.
It uses frozen, hashed Python wheels and TypeScript tarballs outside the checkout.
The new TypeScript caller prepares initialization/policy controls, compiles and
creates a full-width request, loses its admission response, replaces caller/node/
store and recovers the same saved command and original receipt. Current catalog
and native disclosure revocation still hide earlier results. Python sync/async
callers pass in the same schedule.

The schedule records **1863 reads**, **45 accepted turn responses**, **eight lost
caller receipts** and **three lost owner receipts**, with ten applied Tables over
two resources. Bounds remain **four mutations**, **133-byte maximum fixture values**
and **eight resident authority pages**. Installation and expanded recovery work
are included; the interval is not an equivalent-workload speedup, latency target,
native growth proof or host power-loss guarantee. The six frozen executable hashes
and four Python wheel hashes match the preceding Python schedule. TypeScript
package hashes in `.cache/verification/catalog/native.json` are:

| Tarball                  | SHA-256                                                            |
| ------------------------ | ------------------------------------------------------------------ |
| `transit-station`        | `1ddd05e7a8da2f506c658dc3b72dfac2ebfee377e5effcbed6a9fe98fb63aa56` |
| `transit-native-station` | `f738de57b1c4912b0787c37a0e42303fb4230f41c80db1a88ce16ae0145171b5` |
| `transit-client`         | `263043a2da762afd3771dbfd8d6c411a8195ba017ba877ffeca0dae385bb901e` |
| `transit-native-client`  | `815e315a33426f171954cd5763d87e1c39fe0e7001889ea1d8d859f96cd25f0d` |

The packaged catalog guide and README also match the working sources. Logs are
`/tmp/transit-sql-catalog-node-check.log`,
`/tmp/transit-sql-catalog-node-final-native.log` and
`/tmp/transit-sql-catalog-node-final-format.log`.

Full **`just check` passes**, including generated contracts, 346 CLI diagnostics,
4551 local links across 478 files, 52 invariants, 53 classified bounds, 13 SDK
scenarios, frontend checks and documentation build
(`/tmp/transit-sql-catalog-node-full-check.log`). The focused
`bindings::catalog-node` recipe and regular `bindings::node-sdk-test` include
installed catalog recovery. These are development and focused checks; the other
eight catalog SDKs remain.

Committed-HEAD **`just ci-clean --lane core` passes all 18 tasks at
`6ba60509162e57d3c0c6bfbe17ce9da0e768e788` in 718.92 s**. The clone inherits
no workspace build outputs. Completion and per-task timings are recorded in
`.cache/ci/clean/6ba60509162e-transit-ci-lpweqipr/core.meta.json` and `core.json`;
the log is `/tmp/transit-sql-catalog-node-ci-clean.log`. This qualifies the core
lane plus the focused TypeScript/Python schedule, not a full clean suite or
the remaining catalog SDKs. The following commit records evidence only.

### Rust catalog caller

The public `transit_station_sdk::catalog::Client` uses the shared generated ABI
on one owned blocking worker. Typed declarations and controls own full-width
`u64` identities and their strings; prepared commands are borrowed unchanged by
submission. Response adapters check exact field sets, canonical decimal IDs,
bounds and original-request status matching. A malformed success receipt or
failure of an admitted worker job remains `UnknownOutcome`; definite native
rejections keep their category, status and code. Shared Zig retains signing,
policy, publication and recovery semantics. No definition or native binary
changes in this increment.

Executed on development source based on `c904ae08` in the pinned bindings shell:

- Full **`just check` passes**, including generated contracts, 346 CLI diagnostic
  cases, 4558 local links across 479 files, 52 invariants, 53 classified bounds,
  13 SDK scenarios, frontend checks and documentation build. The log is
  `/tmp/transit-sql-catalog-rust-full-check.log`.
- Rust formatting and verification inventory checks pass. Three component
  tests pass both in source and from the installed crate: owned maximum-width
  values/strict decoding, malformed successful receipt uncertainty, and an
  injected worker panic after admission that preserves recovery. Definite
  errors remain unchanged. An initial source invocation without embedded native
  artifacts failed in native-package build scripts; the documented `TRANSIT_LIBRARY_DIR`
  development override passes. Installed tests remove that override and use
  the packaged libraries.
- Final **`just test::catalog --sdk python --sdk node --sdk rust` passes in
  46.173 s**, including 20.142 s isolated installation. The Rust consumer builds
  from copied, hashed crates outside the checkout with pinned registry checksums
  and no Arrow dependency. Compiler rejection checks prevent overlapping
  mutable caller borrows and reuse after consuming `close`. Extracted sources
  and build outputs are removed before running the packaged native consumer.
- The shared disk schedule exercises Rust initialization, conditional policy,
  full-width creation and exact saved-command recovery after lost admission and
  caller/node/store replacement. Original outcomes match independent records;
  current catalog and native denial still hide them. Python sync/async and
  TypeScript repeat the same schedule. It records **1994 reads, 48 accepted turn
  responses, nine lost caller replies and three lost owner replies**, with at
  most four mutations, 133-byte values and eight resident authority pages.
  Eleven applied Tables across two resources do not establish native catalog
  growth or host power-loss recovery. The interval includes provisioning,
  compilation and recovery; it is not an SDK latency comparison.

Final Rust crate SHA-256 values:

| Artifact                 | SHA-256                                                            |
| ------------------------ | ------------------------------------------------------------------ |
| `transit-station-sdk`    | `cdfb35189dc89b59893380339d3f0efd05708ddee04444812c156d05252ee600` |
| `transit-native-station` | `8c26d46b678cc8714e6444b84052ac502a54a03c2d552d5bd819f6a42f8cb34d` |
| `transit-client`         | `5f546a83afe1eba98b7c8504d4fca550ccb383a4c2bfa4df0affd2bd3399a57f` |
| `transit-native-client`  | `6d83bab01c95822a9daf8db22bf59c46a88e55c31a56b1560a69792e55275c42` |

All six executables/libraries, four Python wheels and four TypeScript tarballs
match the preceding TypeScript schedule. Packaged Rust sources, README and catalog
guide match the working files. Logs are
`/tmp/transit-sql-catalog-rust-worker-native.log`,
`/tmp/transit-sql-catalog-rust-worker-test.log` and
`/tmp/transit-sql-catalog-rust-final-format.log`; the initial source artifact failure
is retained in `/tmp/transit-sql-catalog-rust-components.log`.
`bindings::catalog-rust` and regular `bindings::rust-sdk-test` include installed
catalog recovery. These development and focused passes cover Rust; the other
seven catalog SDKs remain.

Committed-HEAD **`just ci-clean --lane core` passes all 18 tasks at
`f77fcc29dd6eeb0c98670d4f4f3b1212129bb55a` in 710.42 s**. The clone inherits
no workspace build outputs. Completion and per-task timings are recorded in
`.cache/ci/clean/f77fcc29dd6e-transit-ci-2wn0hfvk/core.meta.json` and `core.json`;
the log is `/tmp/transit-sql-catalog-rust-ci-clean.log`. This qualifies the core
lane plus the focused Python/TypeScript/Rust schedule, not a full clean suite
or the remaining catalog SDKs. The following commit records evidence only.

### Ruby catalog caller

The public `Transit::Station::Catalog::Client` uses the existing owned worker
and native port. Frozen typed declarations, controls and copied recovery strings
retain full-width integers. Generated request/response schemas validate the port;
public adapters validate canonical IDs, exact result fields and original-request
status matching. `Catalog::Uncertain` retains the original prepared object after
unconfirmed submission, malformed success or allocation failure. Definite native
rejections preserve their category, status and code. The Zig definition and
native binaries are unchanged.

Executed on development source based on `f77fcc29` in the pinned bindings shell:

- Full **`just check` passes**, including generated contracts, 346 CLI diagnostic
  cases, 4565 local links across 480 files, 52 invariants, 53 classified bounds,
  13 SDK scenarios, frontend checks and documentation build. Ruby source/fixture
  syntax and the final verification inventory also pass.
- Installed gems pass owned/frozen value checks, maximum-width identities,
  malformed successful receipts, unchanged definite denial and original-request
  matching. An injected allocation failure retains uncertainty. Real owned child
  processes exercise generated response validation and child loss. A separately
  injected blocked operation keeps the worker busy after its waiting thread is
  killed, and explicit close joins active work and child cleanup.
- Final **`just test::catalog --sdk python --sdk node --sdk rust --sdk ruby`
  passes in 54.910 s**, including 24.273 s isolated package installation. Each
  artifact is copied and hashed outside the checkout. The Ruby consumer verifies
  it loaded the installed gem; its native host uses the installed matching gem.
  It prepares initialization and conditional policy, compiles full-width creation,
  recovers exact saved submission after lost admission and caller/node/store
  replacement, observes the original result, then checks current catalog/native
  denial. Python sync/async, TypeScript and Rust repeat the shared schedule.
- The report records **2151 reads, 51 accepted turn responses, ten lost caller
  replies and three lost owner replies**, with at most four mutations, 133-byte
  values and eight resident authority pages. Twelve applied Tables across two
  resources do not establish native growth or host power-loss recovery. The
  interval includes installation, provisioning and recovery, and is not an SDK
  latency comparison.

Final Ruby gem SHA-256 values:

| Artifact                 | SHA-256                                                            |
| ------------------------ | ------------------------------------------------------------------ |
| `transit-station`        | `2e43bc199d383643280deb893d0101b6d6abd7c88bcd1072bc145d9dd5181424` |
| `transit-native-station` | `4653bccd2758a788ec99f0df17407ca772942b3e1a8513d84eb41306ef1a2570` |
| `transit-client`         | `e627518b495c150e8661d233e4b8856c806b9bc239b13d6396b6fc6b82953725` |
| `transit-native-client`  | `71894ce4dba5fe70942c1b8ad2fb5bdf36c3c72cb8e5d0133fb888b38d8f52fc` |

All six native executables/libraries and the Python, TypeScript and Rust artifacts
match the preceding Rust schedule. The packaged Ruby README, catalog guide and
sources match the working files. Logs are
`/tmp/transit-sql-catalog-ruby-full-check.log`,
`/tmp/transit-sql-catalog-ruby-final-native.log` and
`/tmp/transit-sql-catalog-ruby-syntax.log`. `bindings::catalog-ruby` and regular
`bindings::ruby-sdk-test` include the installed schedule. Committed-HEAD
`just ci-clean --lane core` subsequently passes all 18 tasks at `eb25b6fd` in
707.48 s. Evidence is `.cache/ci/clean/eb25b6fd4a66-transit-ci-t_rx2nl0/` and
`/tmp/transit-sql-catalog-ruby-ci-clean.log`. This predates the PR #33 rebase and
does not qualify its expanded 22-task core lane. The other six catalog SDKs remain.

### C and C++ catalog callers

`transit/catalog.h` adds typed C11 catalog values and explicit owned handles;
`transit/catalog.hpp` adds C++17 owned values, optional outcomes and move-only
callers/commands. Both use the existing bounded C worker and shared Zig catalog
ABI. No protocol/schema definition changes. Saved bytes remain borrowed unchanged
on submission; malformed successful receipts and post-dispatch result-copy
failure retain uncertainty through the existing native result boundary. Metadata
and status outputs publish only after complete parsing; failures clear C outputs.

Executed on development source based on `08fd00a6` (with evidence-only
`12c892e9` subsequently recording the simulation checkpoint), in the pinned
bindings shell:

- `just bindings::c-build` builds independent C/C++ packages and example binaries.
  Installed consumers are compiled as C11/C++17 with warnings treated as errors,
  using only copied archives and their pkg-config dependencies. Source fixtures
  are removed before execution. All six selected archives are hashed. C++
  compiler checks reject copies of `Client`, `Compiled` and `Prepared`.
- Value checks cover maximum-width catalog/operation/object/Table IDs, owned
  request/canonical/saved data after the source changes, oversized/empty commands,
  unterminated C names, unsupported schema types and access after moving an owner.
  Prepared and compiled owners remain readable after native close. C failure
  outputs clear before return; exact borrowed commands survive uncertain sends.
- `just test::catalog --sdk c --sdk cpp` passes in **21.896 s**, including
  **6.669 s** installation: **1452 reads, 42 accepted turn responses, seven lost
  caller receipts and three lost owner receipts**. The installed callers prepare
  initialization/policy, compile creation, recover original admission and result
  after caller/node/store replacement and preserve current catalog/native denial.
  Nine Tables across two resources do not establish native growth. Bounds remain
  four mutations, 133-byte values and eight resident authority pages.
- The existing `just test::table-mutation --sdk c --sdk cpp` regression passes in
  **27.884 s**, including **4.341 s** installation, 2028 reads, 56 turn responses
  and seven lost receipts. The same C library handles saved UPDATE recovery,
  caller replacement and current denial. This interval includes native/port/CLI
  cases and provisioning; it is not a C-versus-C++ latency comparison.
- Full `just check` passes, including generated contracts, unit/CLI checks,
  frontend tests and the documentation build. Final ownership/doc checks pass
  56 invariants, 53 bounds, 13 SDK scenarios and 4596 local links across 482 files.

An initial installed C++ fixture failed compilation on aggregate initializer
warnings and use of C fields as accessor methods. The fixture was corrected;
that failed attempt is not recovery evidence. Logs are
`/tmp/transit-sql-catalog-cpp-native.log`,
`/tmp/transit-sql-catalog-cpp-native-rerun.log`,
`/tmp/transit-sql-catalog-cpp-native-fixed.log`,
`/tmp/transit-sql-catalog-cpp-final-native.log` and
`/tmp/transit-sql-catalog-cpp-full-check.log`. The final report is copied to
`/tmp/transit-sql-catalog-cpp-final-native.json`. Native binary hashes match the
rebased four-language report below. Final SDK archive SHA-256 values:

| Archive                                              | SHA-256                                                            |
| ---------------------------------------------------- | ------------------------------------------------------------------ |
| `transit-client-c-0.2.0-linux-x86_64.tar.gz`         | `90c820a934d5a0d2a8aea65e70a6f1ec28dd5f0044c351f80bc156cbdcd3d4a0` |
| `transit-client-cpp-0.2.0.tar.gz`                    | `24b3d7944ae2899f914dce09edfbbb00744579d3e76dceaee973f23f7dd86f99` |
| `transit-native-client-c-0.2.0-linux-x86_64.tar.gz`  | `a435721d4ee2561818adde127a0a098f4d49daf69176c192f305294a83f5857e` |
| `transit-native-station-c-0.2.0-linux-x86_64.tar.gz` | `fbd4acaf89f0e8d6aaf4b5819a3c1af4162594cf9a9a2fa5b6ab532bcbf3690f` |
| `transit-station-c-0.2.0-linux-x86_64.tar.gz`        | `84594774cd5c7de7efd4b94ba9d2be35b6e3d21c90792a8d00aa62ca70a346fd` |
| `transit-station-cpp-0.2.0.tar.gz`                   | `04be1174bd6ccd8137de0972027ec10a092a885291bc874a58dfeb6bbb5ce152` |

`bindings::catalog-c` owns this focused installed schedule; the regular C SDK
regression also includes it. Committed-HEAD `just ci-clean --lane core` passes
all **22 tasks at `4ecef2ff` in 737.81 s**, from an isolated clone without inherited
build outputs. Evidence is `.cache/ci/clean/4ecef2ffe5f1-transit-ci-78lwlq08/` and
`/tmp/transit-sql-catalog-cpp-ci-clean.log`. This is the expanded core lane plus
focused installed catalog/mutation proofs, not the full clean suite. The four
Java/.NET/Erlang/Elixir catalog callers remain. No catalog-specific host
cancellation or allocator-fault injection is claimed by these C/C++ fixtures.

### Java catalog caller

`io.transit.sdk.station.Catalog` exposes immutable typed values and bounded
futures through the existing Java worker/native port. Positive `BigInteger`
identities retain the full uint64 range; copied lists/`Bytes` retain ownership.
The generated host request/response schemas and strict adapter result fields
validate boundaries. Signing, policy and exact recovery stay in shared Zig.
Successful receipt decoding failures remain `UNKNOWN_OUTCOME`; original prepared
commands stay immutable. Definite native error categories/status/codes remain.

Executed on development source based on `4ecef2ff`, with the evidence-only
`cb23fd69` published during the final run, in the pinned bindings shell:

- `just bindings::java-build` compiles Java 21 JARs/examples with all warnings
  treated as errors. The installed catalog proof copies and hashes four Transit
  JARs plus pinned Gson, compiles outside the checkout and removes Java sources
  before execution. The normal recovery consumer uses its packaged native host.
- Installed value checks cover maximum-width identities, immutable/copied
  declarations and recovery data, malformed/extra-field successful receipts,
  original-request matching, noncanonical decimal values and an injected result
  allocation error. Definite access denial preserves the original exception.
- A separate actual port wrapper uses the installed native artifact for
  handshakes, joins that helper, then injects child loss, malformed replies,
  definite denial and a blocked successful submission. Cancelling its Java
  future preserves `BUSY`; close waits until the explicit release and joins the
  port and worker threads. This checks the owned process and host scheduling,
  not remote cancellation or recovery under general heap exhaustion.
- Focused `just test::catalog --sdk java` passes in **17.126 s**, including
  **2.470 s** installation, 1459 reads, 39 accepted turn responses, six lost
  caller receipts and three lost owner receipts.
- The final **seven-language** schedule (`just test::catalog --sdk python --sdk
node --sdk rust --sdk ruby --sdk c --sdk cpp --sdk java`) passes in **73.578 s**,
  including **33.900 s** installation. It records **2655 reads, 60 accepted turn
  responses, thirteen lost caller receipts and three lost owner receipts**.
  Every selected caller recovers the original operation after caller/node/store
  replacement and preserves current catalog/native denial. Python includes both
  synchronous and asynchronous callers. Fifteen Tables across two resources do
  not establish native catalog growth. Bounds remain four mutations, 134-byte
  observed values and eight resident authority pages. Timings include package
  installation and recovery; they are not cross-language latency comparisons.
- Full `just check` passes: unit/generated-contract/CLI checks, frontend checks
  and documentation build. Final direct checks pass 4603 links across 483 files,
  56 invariants, 53 bounds and 13 SDK scenarios.
- The existing `just test::table-mutation --sdk java` regression passes in
  **22.624 s**, including **0.856 s** installation, 1879 reads, 52 turn responses
  and six lost receipts. Installed Java retains exact UPDATE recovery through
  the same bridge; native/port/CLI mutation cases also pass. The log is
  `/tmp/transit-sql-catalog-java-mutation-regression.log`.

The initial fixture compilation exposed deprecated Gson construction and missing
optional annotation metadata under `-Werror`; it now uses the existing supported
Gson entry point and the real submission conversion helper for injected failure.
A subsequent port-fixture cleanup assertion failed because its handshake
subprocess had not been joined before the wrapper could be killed. Joining that
helper before admitting faults fixes the fixture. Neither failed attempt counts
as executed recovery proof. Logs are
`/tmp/transit-sql-catalog-java-native.log`,
`/tmp/transit-sql-catalog-java-native-fixed.log`,
`/tmp/transit-sql-catalog-java-native-joined.log`,
`/tmp/transit-sql-catalog-java-all-native.log` and
`/tmp/transit-sql-catalog-java-full-check.log`. Reports are copied to
`/tmp/transit-sql-catalog-java-native.json` and
`/tmp/transit-sql-catalog-java-all-native.json`; both retain exact SDK/native
hashes. Native binary hashes match the rebased report below. Final Java artifacts:

| JAR                                | SHA-256                                                            |
| ---------------------------------- | ------------------------------------------------------------------ |
| `transit-client-0.2.0.jar`         | `8775ebc5cdb52de401f426f03d7d9496c15307089be60884685e078edd5ed89f` |
| `transit-native-client-0.2.0.jar`  | `66132be7fb9bec1018bdc867a1165593db00b0f41fae70330f8025c8489c52ae` |
| `transit-station-sdk-0.2.0.jar`    | `b966c9f485827ce4e1d19046b26031a9c2813d98381d11361e21120a4595fb26` |
| `transit-native-station-0.2.0.jar` | `70c1cc5e8f6612fb84c89cd64eedb5e024932a4588d3ed76627d902f9687b7d6` |
| `gson-2.12.1.jar`                  | `ebee13d5fb7477cd7f1cc010e0c356df8ca80709715248da97f79e35ccb4fbec` |

`bindings::catalog-java` owns the focused installed schedule; the regular Java
SDK regression also includes it. These are development and focused passes.
Committed `66d0a97e` passes `just ci-clean --lane core`: all **22 tasks**
complete in **742.17 s** without inherited build outputs, including the new
resource, scheduler, domain and Vortex simulation tasks. Evidence is under
`.cache/ci/clean/66d0a97e4044-transit-ci-137qp_eh/` (`core.json` and
`core.meta.json`); the log is `/tmp/transit-sql-catalog-java-ci-clean.log`.
This is the expanded core lane and focused installed checks above, not the
full clean suite. .NET/Erlang/Elixir catalog callers remain. The following
commit records this evidence only.

### .NET catalog caller

`Transit.Station.Sdk.Catalog` exposes immutable typed records and bounded tasks
through the existing .NET worker and generated native C ABI. Positive `ulong`
identities retain the full uint64 range. Copied name lists and `Bytes` retain
ownership; schema equality compares names by value so decoded original requests
can be checked against independently reconstructed callers. Generated action and
result schemas plus strict adapter fields validate boundaries. Shared Zig owns
signing, current policy and exact recovery. Successful receipt decoding failure
remains `UnknownOutcome`; explicit native rejection retains its category/code.

Executed in the pinned bindings shell on development source based on `66d0a97e`:

- `just bindings::catalog-dotnet` builds four NuGets and installs exact package
  versions from an isolated local feed. The consumer compiles with warnings as
  errors, then runs after removing its source and package cache. Package hashes
  are retained in the native report.
- Installed checks cover copied immutable declarations/prepared bytes, maximum
  identities, original-request equality, noncanonical decimal strings and
  malformed/extra-field successful receipt uncertainty. Decoder fault inputs
  use the installed assembly through reflection; they are not forged native
  ABI outputs or allocator-failure injection.
- A local TCP peer blocks an actual native catalog HTTP read. A previously
  cancelled token admits no request. Cancelling the admitted wait preserves
  `Busy`; disposal remains pending until the peer releases the read, then joins
  the owned worker. Post-disposal calls fail `Closed`. This tests read
  cancellation and local ownership, not cancellation of admitted mutations.
- The focused native catalog schedule passes in **17.031 s**, including
  **3.035 s** installation: **1395 reads, 39 turn responses, six lost caller
  receipts and three lost owner receipts**. The installed .NET caller recovers
  its original creation after caller/node/store replacement and respects current
  catalog/native disclosure denial. The native ABI, port and CLI cases also
  pass. Eight Tables across two resources do not establish native catalog growth.
  Bounds remain four mutations, 133-byte observed values and eight resident
  authority pages. This timing includes installation and recovery, not a
  cross-language latency comparison.
- The existing `just test::table-mutation --sdk dotnet` regression passes in
  **24.302 s**, including **2.543 s** installation, 1849 reads, 52 turn responses
  and six lost receipts. Exact UPDATE recovery and current denial remain intact
  through the shared bridge.

The first installed fixture supplied managed numeric nodes directly to the
wire-result decoder, which correctly rejected their differing runtime types.
The fixture now serializes and parses JSON before decoder checks. The first
full check also found the new task absent from the suite inventory; the task and
invariant inventories now agree. Those attempts are failures, not proof passes.
Logs are `/tmp/transit-sql-catalog-dotnet-build.log`,
`/tmp/transit-sql-catalog-dotnet-native.log` (initial fixture failure),
`/tmp/transit-sql-catalog-dotnet-native-fixed.log`,
`/tmp/transit-sql-catalog-dotnet-mutation-regression.log`,
`/tmp/transit-sql-catalog-dotnet-full-check.log` (inventory failure) and
`/tmp/transit-sql-catalog-dotnet-full-check-fixed.log`. The focused report is
copied to `/tmp/transit-sql-catalog-dotnet-native.json`; native hashes match the
rebased report below. Installed package hashes:

| NuGet                                | SHA-256                                                            |
| ------------------------------------ | ------------------------------------------------------------------ |
| `Transit.Client.0.2.0.nupkg`         | `9c1c8db6507b0a76e43fd17b3504c7d44c6cad7495e3ba09dd453820f970eb2a` |
| `Transit.Native.Client.0.2.0.nupkg`  | `9b906b7103a2fe0c27612a8bdda09fd6cf84ba6d8dc0612aca1d08d9cdc6d445` |
| `Transit.Station.Sdk.0.2.0.nupkg`    | `56576b6978e2fae0a340e7e6e6dbad314c761db4411809de4676e5c18066fc5b` |
| `Transit.Native.Station.0.2.0.nupkg` | `b034cd99a5fbefc2b0c2227fec50a100e1e06be86d5190efbaeeeb61acaafdd6` |

`bindings::catalog-dotnet` owns the focused installed schedule; the regular .NET
SDK regression also includes it. Full `just check` passes unit/generated-contract
and CLI checks, frontend checks and the documentation build. Final direct checks
cover 4609 links across 484 files, 56 invariants, 53 bounds and 13 SDK scenarios.
Committed `7ec2e0e1` passes `just ci-clean --lane core`: all **22 tasks**
complete in **758.12 s** without inherited build outputs, including the new
simulation tasks. Evidence is under
`.cache/ci/clean/7ec2e0e11b24-transit-ci-v67ub5ds/` (`core.json` and
`core.meta.json`); the log is `/tmp/transit-sql-catalog-dotnet-ci-clean.log`.
This is the expanded core lane plus the focused checks above, not the full clean
suite. Erlang/Elixir catalog callers remain. The following commit records only
this clean evidence.

### Erlang/Elixir catalog callers and combined installed schedule

`transit_catalog` and `Transit.Station.Sdk.Catalog` expose immutable records and
structs through the existing BEAM worker/native port. Full-width identities,
fixed allowed atoms, generated boundary schemas and exact original-request
matching preserve the shared catalog contract. Signing, authorization and
recovery remain in Zig. An uncertain submit returns the original prepared value;
native rejection retains its category, status and code. `close` joins admitted
work after a waiting process dies.

Executed in the pinned bindings shell on development source based on `7ec2e0e1`:

- `just bindings::beam-build` compiles OTP applications and real examples with
  warnings as errors. The focused installed schedule copies/hashes four Erlang
  artifacts and six Elixir artifacts, compiles consumers outside the checkout,
  removes consumer source files and uses the installed native host. Elixir
  formatting checks pass.
- Installed value checks compile maximum-width catalog/operation/object/Table
  IDs and reject invalid integers and saved bytes. Real owned ports use native
  handshakes, join that helper, then inject malformed replies, child loss,
  explicit denial and a blocked successful submit. Uncertainty retains the
  identical prepared record/struct. Killing the waiting process retains `busy`;
  close waits for explicit release, and the child is gone after cleanup. The
  Java fixture is renamed `catalog_port_host.py` for shared use and handles
  explicit shutdown. Java's installed fault checks pass with the shared fixture.
  These cases do not prove general allocator exhaustion or remote cancellation.
- The focused Erlang/Elixir catalog schedule passes in **21.772 s**, including
  **5.334 s** installation: 1574 reads, 42 turn responses, seven lost caller
  receipts and three lost owner receipts. It creates nine Tables. The final
  combined run below uses rebuilt artifacts including the published guides.
- **All ten SDKs** pass the combined catalog schedule in **108.574 s**, including
  **43.699 s** installation: **4095 reads, 69 turn responses, sixteen lost caller
  receipts and three lost owner receipts**. Python includes both sync and async
  callers. Every selected caller recovers its original creation after
  caller/node/store replacement and respects current catalog/native disclosure
  denial. The native ABI, native port and CLI cases also pass. Eighteen Tables
  across two resources do not establish native catalog growth. Bounds remain
  four mutations, 134-byte observed values and eight resident authority pages.
  These local timings include installation and recovery while independent
  repository/regression checks run; they are not cross-language latency rankings.
- The existing Erlang/Elixir mutation regression passes in **28.509 s**, including
  **2.159 s** installation, 2127 reads, 56 turn responses and seven lost receipts.
  Exact UPDATE recovery and current denial remain intact through the shared port.
- Full `just check` passes unit/generated-contract and CLI checks, frontend
  checks and the documentation build. Direct checks cover 4625 links across 486
  files, 56 invariants, 53 bounds and 13 SDK scenarios. The SDK proof inventory
  now records C/C++/Java/.NET/BEAM ownership evidence and its distinct limits.

The initial combined run stopped during Rust's compile-rejection assertion while
`/tmp` was under disk pressure; the captured output reports Ursula disk pressure,
but the assertion did not preserve compiler stderr. The concurrent full check
failed copying the CLI binary with `ENOSPC`. Both attempts remain failed. The
Rust fixture now includes compiler exit/stderr on an unexpected result. Repeating
both checks with `TMPDIR=/var/tmp` passes; no deployment quotas or resident bounds
were raised. The failure does not establish a Rust ownership regression or a
catalog recovery pass.

Logs are `/tmp/transit-sql-catalog-beam-build.log`,
`/tmp/transit-sql-catalog-beam-final-build.log`,
`/tmp/transit-sql-catalog-beam-native.log`,
`/tmp/transit-sql-catalog-beam-mutation-regression.log`,
`/tmp/transit-sql-catalog-all-ten-native.log` (failed),
`/tmp/transit-sql-catalog-all-ten-native-var.log`,
`/tmp/transit-sql-catalog-beam-full-check.log` (failed) and
`/tmp/transit-sql-catalog-beam-full-check-var.log`. Reports are copied to
`/tmp/transit-sql-catalog-beam-native.json` and
`/tmp/transit-sql-catalog-all-ten-native.json`. The combined report retains all
selected package hashes; earlier eight SDK identities and native binary hashes
match the recorded checkpoints above/below. Final BEAM artifacts:

| OTP artifact                          | SHA-256                                                            |
| ------------------------------------- | ------------------------------------------------------------------ |
| `transit_native_client-0.2.0.tar.gz`  | `c4436c6ec88f4e0a838e88c0214521cced7d527a1bca8343a2eb43c5e0712529` |
| `transit_client-0.2.0.tar.gz`         | `7ef15b4c716177372dc39dcca2230ef2878e118bdf430176ce86e8e15a26e0aa` |
| `transit_native_station-0.2.0.tar.gz` | `8e8aba003040a0924bc78b3383fcee833f3652ccf115f76c7a48de35b799c6d2` |
| `transit_station_sdk-0.2.0.tar.gz`    | `b60cb4c0eee515d4d8af515d23843a0fb54525e03d2fdb30668fc5d0a386493e` |
| `transit_client_elixir-0.2.0.tar.gz`  | `adc379bfc22a4027c5caf26bc2c03062981b2a4cc50500bc50d32d413a830b36` |
| `transit_station_elixir-0.2.0.tar.gz` | `5a72442a18d3527740e4571f07ae0438c7a464b7c04f97b4d97298aa30de564d` |

`bindings::catalog-beam` owns the focused installed schedule; the regular BEAM
SDK regression also includes it. All ten SDKs expose this catalog profile;
native catalog growth/paged callers and broader declaration operations remain.

Committed-HEAD `TMPDIR=/var/tmp nix develop --option eval-cache false .#bindings
--command just ci-clean --lane core` passes all **22 tasks** at `3c11f9c3` in
**1371.72 s** without inherited workspace outputs. The completion and task timing
records are `.cache/ci/clean/3c11f9c3c3ed-transit-ci-ble3b_wo/core.meta.json`
and `core.json`; the log is `/tmp/transit-sql-catalog-beam-ci-clean.log`.
Concurrent workloads make this unpaired duration unsuitable for a performance
regression claim. This is the expanded core lane, not a full clean suite. The
following evidence-only commit records the result; signed metadata work remains
separate from this checkpoint.

### Signed catalog metadata

The Zig signed caller shares `Inspection` validation with the private-turn
catalog helper for name lookup, exact definition reads and eight-entry pages.
Each call acquires current configuration/policy and checks the native writer;
subsequent reads enforce the same resource revision. Current inspection rights
precede cursor checks. Create-only conflict checks remain independent of inspect
permission. No saved view, admission or authorization cache is introduced.
Neutral ABI/port, CLI and language SDK metadata mappings remain separate work.

On development source based on `3c11f9c3`, pinned Zig
`0.17.0-dev.2267+48abf1a34` passes root unit/fixture checks, the small real native
schedule and full `just check`. The native schedule takes **42.936 s** with
1391 reads, 36 accepted turn responses, five lost caller replies and three lost
owner replies. It checks five named definitions in the supplied host resource,
seven applied Tables across both resources, point/list agreement and current
catalog/native disclosure denial. Bounds remain four mutations, 132-byte observed
values and eight resident authority pages. This small schedule is not a growth
proof. Its report is `/tmp/transit-sql-catalog-metadata-native-fixed.json` and log
`/tmp/transit-sql-catalog-metadata-native-fixed.log`.

The native contract definition is unchanged. Binary SHA-256 identities:

| Binary         | SHA-256                                                            |
| -------------- | ------------------------------------------------------------------ |
| node           | `6f27157343edbf4311ceaeba4444566c9ce91a761ce2f6b647a2e0667d393e8c` |
| catalog proof  | `19da6d30e2d6c792c285bf35bc1f3faf93f4c0ef92f6f78b82d6784ec06d5aa2` |
| catalog host   | `9545df46010fede16ed61231e508942b1b744c6285cfb0673656e3d034d6f1c6` |
| native port    | `4a31f186752ff355011f6952c59965baffd9c9efc1799347a47b24d7b219b993` |
| native library | `34ae38b64593862311010b9d478324fc3a8103cc52a018677fcc0c46d854d398` |
| CLI            | `f66e7b11526f1e14006f6a43721f806af1f61916e360229d096ca7ae63991325` |

Eight component seeds pass **40 package schedules / 1264 events** with identical
replay in **13.719 s**, including the shared inspection code. The log and report
are `/tmp/transit-sql-catalog-metadata-domain.log` and
`/tmp/transit-sql-catalog-metadata-domain.json`. At committed `6464b125`, all **nine
compiling component mutants** are detected by executed assertions, including
removing inspection authorization or the cursor revision guard from `Inspection`.
The log and copied report are `/tmp/transit-sql-catalog-metadata-mutants.log` and
`/tmp/transit-sql-catalog-metadata-mutants.json`; detailed traces remain in
`.cache/verification/domain-simulation-mutations/`.

The 257-additional-Table disk run fails during creation-status polling with
`AuthorityTimeout`; the owner also reports an uncertain turn. It does not reach
the final listing/restart checks and remains failed. The log is
`/tmp/transit-sql-catalog-metadata-growth.log`; it does not retain an exact completed
creation count. The fixture now retains incomplete progress, operation counts and
metadata timings in `native.json`, including on failures. Bounds and timeouts are
unchanged. The larger schedule remains incomplete.

The subsequent `just test::catalog --grow 65` schedule passes in **292.798 s** on
development source based on `869f112e`, with the binary hashes above. It creates
65 additional Tables and lists **70 definitions across nine pages**, checks each
name lookup and exact object/revision against the listing, kills/restarts the
node and disk store, and repeats the complete listing. Actual committed growth
invalidates an old cursor; changed scope/revision and current native/catalog
revocation reject. There are 72 applied Tables across both resources, 6382 total
reads (3209 from the catalog caller), 101 accepted turn responses and the original
five caller/three owner receipt-loss cases. Bounds remain four mutations,
132-byte observed values and eight resident authority pages. This is the finite
default `test::catalog-growth` schedule; it does not complete the failed 257 case.
The report and log are `/tmp/transit-sql-catalog-metadata-growth-65.json` and
`/tmp/transit-sql-catalog-metadata-growth-65.log`.

The report separates caller reads from worker polling. Cold signed listing costs
**19 reads for eight definitions** and 15 for six; successful name lookup costs
five and exact definition lookup three. A missing name costs three. Measurements
cover 19 successful listing calls (including one during growth), 142 name
lookups and 142 definition reads across the two walks. Growth creation takes
211.962 s; cumulative 16/32/48/64-Table times are 27.904/71.741/134.220/206.188 s.
These shared-host measurements expose increasing creation cost and a bounded
point-read batching opportunity; they do not attribute the cost to a specific
subsystem or establish end-to-end latency targets.

The initial native metadata attempts fail converting a Zig JSON byte string as a
Python integer array; the corrected fixture passes the small schedule. A new
create-only unit assertion initially overflows its maximum-ID fixture; selecting
a distinct lower operation ID fixes the test. Failed logs are
`/tmp/transit-sql-catalog-metadata-native-initial.log`,
`/tmp/transit-sql-catalog-metadata-native.log` and
`/tmp/transit-sql-catalog-metadata-full-check.log`. The full rerun passes at
`/tmp/transit-sql-catalog-metadata-full-check-fixed.log` with 4625 documentation
links, 56 invariants, 53 classified bounds and 13 SDK scenarios. Neither fixture
failure establishes a successful production check.

### Batched signed catalog pages

The signed reader fetches the page's definition records and Table descriptors in
two dependent batches. Each requires the exact initial resource revision and
current native grants; the second replaces the first after definitions are copied
into the result. Private-turn callers retain ordinary point reads and sticky
failure behavior. Resident dependency storage holds at most eight keys/entries,
independently of retained catalog size.

On development source based on `55f360e3`, the same 65-additional-Table disk
schedule passes in **218.313 s**: 70 named definitions over nine pages, exact
point/list agreement, node/store restart, current denial, five caller and three
owner receipt-loss cases. It records 5981 total reads, 2958 caller reads and 101
accepted turn responses; bounds remain four mutations, 132-byte values and eight
resident pages. Source/dirty status and binary hashes are in
`/tmp/transit-sql-catalog-metadata-batch-growth.json`; the log is
`/tmp/transit-sql-catalog-metadata-batch-growth.log`.

All **19 successful list calls cost five signed reads**, including the two
six-entry final pages. Compared with the earlier matching growth schedule, a
full eight-definition page falls from **19 to five reads**; listing calls total
353 reads before and 95 after. The 142 name lookups retain their five-read
successful/three-read absent costs, and the 142 exact-definition calls retain
three reads each. Listing wall times total 6.972 s before and 3.258 s after, but
these shared-host runs are unpaired: only the measured request-count reduction
establishes the batching improvement. Total runtime and worker polling are not
used as a latency or throughput guarantee. The failed 257-Table attempt remains
incomplete.

Root unit checks pass, and eight seeded component runs pass **40 package
schedules / 1264 events** with identical replay in **13.732 s** after changing the
read order. Logs are `/tmp/transit-sql-catalog-metadata-batch-unit.log` and
`/tmp/transit-sql-catalog-metadata-batch-domain.log`; the domain report is copied
to `/tmp/transit-sql-catalog-metadata-batch-domain.json`.

A separate real native schedule pauses the first dependent definition batch
after initial policy/name reads, revokes the caller's native resource read grant,
then releases the batch. Listing fails with `AccessDenied`; restoring the grant
permits a fresh listing. This check passes in **43.676 s**, with 1428 total reads,
507 caller reads and 36 turn responses. It preserves the original five
caller/three owner receipt-loss cases, five listed definitions and the same
resident/write bounds. Every successful listing asserts a five-read budget.
The log and report are `/tmp/transit-sql-catalog-metadata-batch-revocation-fixed.log`
and `/tmp/transit-sql-catalog-metadata-batch-revocation.json`. The first attempt
does not compile because the new fixture gives an eight-bit permission field a
32-bit value; `/tmp/transit-sql-catalog-metadata-batch-revocation.log` retains that
failure. It is corrected without changing protocol fields or limits.

Final native binary hashes (the growth run uses the preceding helper hash
`cc3c0b7046c631bca1ed2fb96154b148127aac94b897d0cf2fa44bc188c5f941`):

| Binary         | SHA-256                                                            |
| -------------- | ------------------------------------------------------------------ |
| node           | `6f27157343edbf4311ceaeba4444566c9ce91a761ce2f6b647a2e0667d393e8c` |
| catalog proof  | `18a822862a38cc4a52a4edd0c5c42716a7795a2700ed4fc7d04c94ad637ffe6b` |
| catalog host   | `dc96313fc0d17aa038e34791c6ea7e2af527ee445172791555995fd27e9bc8eb` |
| native port    | `62442c92768565973e7879ad6e83328f3674add9406d560e1156447b80bad63d` |
| native library | `5fb61f939a4aacf5b5355196a5a78534689a7bdb160ce9e01a06746eeeceaad4` |
| CLI            | `f373d7886a3d0b696723441a974376834f6e0e86703ac76b6b74b618b98eea42` |

Full `just check` passes at `/tmp/transit-sql-catalog-metadata-batch-full-check.log`,
including unchanged generated contracts and 4625 documentation links. All nine
compiling component mutants are detected again at committed `8e728de3`, including
inspection authorization and cursor revision defects after batching. The log and
copied report are `/tmp/transit-sql-catalog-metadata-batch-mutants.log` and
`/tmp/transit-sql-catalog-metadata-batch-mutants.json`. Committed clean validation
passes separately at `8e728de3`: `just ci-clean --lane core` completes all
**22 tasks in 1146.58 s**, without inherited workspace build outputs. Evidence is
`.cache/ci/clean/8e728de3a8de-transit-ci-ykvwiuy3/core.{json,meta.json}`; the log is
`/tmp/transit-sql-catalog-metadata-batch-ci-clean.log`. This is the core lane,
not the complete clean suite or the subsequent ABI/CLI metadata work.

### Neutral catalog metadata values

Shared definition/cursor/page conversions match independently assembled metadata
and binary definition fixtures. Root unit checks verify full-width decimal
identities, owned text, mandatory current cursor definitions and rejection of
missing/foreign definitions, unsafe revisions, page holes, mixed scopes and
inconsistent continuation. The generated native/ABI/host contracts remain
unchanged: these conversion types alone expose no new executable actions.
The pinned-shell logs are `/tmp/transit-sql-catalog-neutral-metadata-unit.log`
and `/tmp/transit-sql-catalog-neutral-metadata-contracts.log`. Native ABI/port,
CLI and SDK metadata actions and installed-caller evidence remain.

Committed `55f360e3` also passes `just ci-clean --lane core`: **22 tasks in
1171.42 s**, including the seeded simulation checks. Evidence is
`.cache/ci/clean/55f360e39e73-transit-ci-q0dn3km_/core.{json,meta.json}` and
`/tmp/transit-sql-catalog-neutral-metadata-ci-clean.log`. It does not include
the later signed-read batching or metadata action additions.

### Catalog metadata through native ABI, port and CLI

The neutral bridge adds `lookup`, exact `definition` and `list` actions using
the shared signed client. Generated schemas/resources cover the new variants;
earlier action/result fields, handle layouts and saved commands are unchanged.
CLI list continuation consumes the original private saved page and checks its
complete structure before credential loading.

On development source based on `fdaa53f4`, `just test::catalog --grow 17` passes
in **48.402 s**. All three callers agree with Zig for **22 definitions over three
pages**, every point lookup and exact definition, and missing records. The walk
repeats after node/Ursula disk restart. A newly created Table invalidates an
original cursor on all surfaces, including a saved CLI page. Catalog and native
revocation deny all three metadata actions; the paused dependent-read revocation
case also remains. Existing creation/control recovery retains five lost caller
receipts and three lost owner receipts. Counts are 4201 total reads, 2193 caller
reads and 53 turn responses; bounds remain four mutations, 132-byte values and
eight resident pages.

All 21 successful neutral list calls stay within five signed reads: seven each
through ABI/port cost four with previously negotiated batch support, and seven
fresh CLI invocations cost five. The cached capability is not an authorization
cache. Every operation still fetches current configuration/policy and native
grants; these unpaired wall times establish no latency claim.
The report is `/tmp/transit-sql-catalog-metadata-abi-cli-native.json`; the log is
`/tmp/transit-sql-catalog-metadata-abi-cli-native-schema-fixed.log`.
The report retains source/dirty status and all six binary hashes. Node, proof and
catalog host hashes match the preceding batched-reader proof. Updated binaries:

| Binary         | SHA-256                                                            |
| -------------- | ------------------------------------------------------------------ |
| native port    | `f8329121706cfb35e41af77aaf96df35c1389d384849fa8d980f7055401bcb62` |
| native library | `fac060c74e3f679858543451b494c1e1ebf4a3e5d7d5312897759be140539060` |
| CLI            | `7f427823c886cbd629b3325aaccbf98de48fbbb3dee92dad2f33563b4d9a993c` |

Protocol/catalog unit tests and **399 real CLI diagnostic cases** pass at
`/tmp/transit-sql-catalog-metadata-ordinal-fix.log`. New cases check required
arguments, canonical IDs/names, saved-page holes, ordering/continuation scope and
revision, missing/foreign definitions and final-page refusal before credential
loading. The first CLI/native attempts expose a shared decoder defect: Zig's
generic enum parser accepts an all-zero string as ordinal zero. The shared
protocol shape validator now requires exact declared names; numeric aliases
reject even when nested in a page or action. Logs
`/tmp/transit-sql-catalog-metadata-abi-cli-expanded.log` and
`/tmp/transit-sql-catalog-metadata-abi-cli-native.log` retain those failures.
The following native attempt reaches metadata comparison but fails because its
fixture retains the native schema's `version` field in the neutral expectation;
`/tmp/transit-sql-catalog-metadata-abi-cli-native-fixed.log` records it. The
fixture now verifies version one and compares the declared neutral schema.
Full `just check` passes at
`/tmp/transit-sql-catalog-metadata-abi-cli-full-check.log`; final documentation
and verification inventory checks pass 4625 links across 486 files, 56
invariants, 53 bounds and 13 SDK scenarios at
`/tmp/transit-sql-catalog-metadata-abi-cli-docs.log`.

All ten rebuilt, installed SDKs pass their existing catalog creation/control and
recovery schedule against these additive schemas/actions: **126.508 s**, including
**47.718 s** installation, 4558 reads, 69 turn responses, sixteen lost caller
receipts and three lost owner receipts. It retains eighteen Tables across the two
resources, sixteen listed definitions, four mutations, 134-byte observed values
and eight resident pages. ABI/port/CLI also compare all sixteen definitions and
two pages in this run; language SDK metadata methods are not exercised by this
checkpoint. Source revision is `7fc92b33`; report/package hashes and log are
`/tmp/transit-sql-catalog-metadata-all-ten-regression.json` and
`/tmp/transit-sql-catalog-metadata-all-ten-regression.log`.

Committed `7fc92b33` passes `just ci-clean --lane core`: **all 22 tasks in
756.17 s**, including the shared protocol enum fix, generated contracts and
seeded simulations. Evidence is
`.cache/ci/clean/7fc92b33d25a-transit-ci-en_9c5gk/core.{json,meta.json}` and
`/tmp/transit-sql-catalog-metadata-abi-cli-ci-clean.log`. This validates the
ABI/CLI checkpoint independently of inherited build outputs; it does not include
the subsequent language metadata methods or establish a full clean-suite pass.

### Python catalog metadata

Python sync/async public methods return immutable definitions, Table sources,
cursors and dense page tuples. Strict decoding checks full-width identities,
requested scope/name/revision, continuation and page structure. Type checking
passes all 18 source files, and focused malformed-response/ownership checks pass
at `/tmp/transit-sql-catalog-python-metadata-values.log`. Missing/foreign cursor
definitions, holes, duplicate order, changed cuts, wrong identity and source
variants reject; copied name/entry collections remain independent and frozen.

Rebuilt installed wheels pass `just test::catalog --sdk python --grow 17` in
**72.256 s**, including **2.022 s** installation. Both public clients agree with
Zig/ABI/port/CLI on **24 definitions, three full pages and an empty final page**,
all exact/name reads and missing records before and after node/store disk
restart. Original cursors reject after creation, and both catalog/native
revocation deny each metadata method. Seven lost caller replies and three lost
owner replies retain the existing exact creation/control recovery checks.
Counts are 5839 reads, 3146 caller reads and 59 turn responses; bounds remain
four mutations, 133-byte observed values and eight resident pages. Each Python
client's seven successful populated list calls cost four signed reads and two
empty final pages cost two, using already negotiated native batch support.

The native report and installed-wheel hashes are
`/tmp/transit-sql-catalog-python-metadata-native.json`; the log is
`/tmp/transit-sql-catalog-python-metadata-native.log`. Source is development based
on `8c375486`; all six native binary hashes match the ABI/CLI metadata checkpoint.
This proves Python metadata mappings, not the remaining nine SDKs.

### TypeScript catalog metadata

TypeScript adds frozen definitions, Table sources, cursors and dense page arrays
over its existing native port. Generated schemas reject malformed wire shapes;
the public adapter checks requested identity, scope, ordering and continuation.
`vp check`, TypeScript compilation and **22 catalog tests** pass at
`/tmp/transit-sql-catalog-node-metadata-values.log`, including altered identities,
missing/foreign definitions, holes, duplicate order, changed cuts, unknown sources,
wide bigint values and owned collections. The earlier type check also passes at
`/tmp/transit-sql-catalog-node-metadata-types.log`.

Rebuilt TypeScript and Python installed packages pass the combined
`just test::catalog --sdk python --sdk node --grow 17` schedule in **89.568 s**,
including **7.015 s** installation. All six callers agree on **25 definitions
over four pages**, every point read and absence before/after node/store restart.
Original stale cursors and current catalog/native revocation reject. Eight lost
caller receipts and three lost owner receipts preserve creation/control recovery.
There are 6956 reads, 3634 caller reads and 62 turn responses, bounded to four
mutations, 133-byte values and eight resident pages. All nine successful TypeScript
list calls cost four signed reads with already negotiated batch support.

Report/package hashes and log are
`/tmp/transit-sql-catalog-python-node-metadata-native.json` and
`/tmp/transit-sql-catalog-python-node-metadata-native.log`. This is development
source based on `2ec18f51`, with unchanged native binary hashes. Other eight
language metadata mappings remain outside this evidence.

### Rust catalog metadata

Rust adds owned definitions, Table sources, dense page vectors and explicit
checked cursors through mutable blocking caller methods. Four catalog tests pass
at `/tmp/transit-sql-catalog-rust-metadata-unit-fixed.log`, including full-width
identity, independent cloned ownership, response matching and ten malformed-page
cases. The first source test at
`/tmp/transit-sql-catalog-rust-metadata-unit.log` fails before execution because
native artifacts are not selected; the rerun supplies the built library directory
explicitly. No package dependency or search fallback changes are made.

Rebuilt installed crates pass `just test::catalog --sdk rust --grow 17` in
**72.367 s**, including **16.278 s** installation. Their packaged unit tests and
compiler rejection of overlapping mutable callers/use after close pass. Rust
agrees with Zig/ABI/port/CLI for **23 definitions over three pages**, all point
reads and absence before/after node/store restart. Changed cursors and current
catalog/native denial reject, retaining six lost caller replies and three lost
owner replies in the existing creation/control recovery schedule. Counts are
4968 reads, 2629 caller reads and 56 turn responses; bounds remain four mutations,
133-byte values and eight resident pages. All seven successful Rust listings
cost four signed reads with already negotiated batch support.

Report/package hashes and log are
`/tmp/transit-sql-catalog-rust-metadata-native.json` and
`/tmp/transit-sql-catalog-rust-metadata-native.log`. Source is development based
on `9c6ca374`; native binary hashes are unchanged. Seven language metadata
mappings remain outside this evidence.

Committed `a65c4285` passes `just ci-clean --lane core`: **all 22 tasks in
891.07 s**, including the seeded resource, scheduler, component and external
fault suites. Completion metadata and every task exit code are retained at
`.cache/ci/clean/a65c4285c45d-transit-ci-_g1s7lbt/core.{json,meta.json}`;
the command log is `/tmp/transit-sql-catalog-three-sdk-metadata-ci-clean.log`.
The cumulative Python/TypeScript/Rust source passes full `just check`, including
the documentation build, at
`/tmp/transit-sql-catalog-three-sdk-metadata-full-check.log`. This is the expanded
clean core lane, not a full clean suite or evidence for the seven remaining
language metadata APIs. The following evidence-only commit records these results.

### Ruby catalog metadata

Ruby adds frozen definitions, Table sources, owned dense page arrays and mandatory
original cursors through the existing synchronous worker. Syntax checks pass at
`/tmp/transit-sql-catalog-ruby-metadata-syntax.log`. Installed value checks cover
full-width identity, copied/frozen strings and collections, nine malformed pages,
request identity, continuation cuts, empty final pages and absence. Existing
owned-port malformed/lost responses and cancelled waiting-thread cleanup remain
in the schedule.

Rebuilt installed gems pass `just test::catalog --sdk ruby --grow 17` in
**62.700 s**, including **4.971 s** installation. Ruby agrees with Zig/ABI/port/CLI
on **23 definitions over three pages**, point reads and absence before/after
disk-backed node/store restart. Stale cursors and current catalog/native denial
reject. The creation/control schedule retains six lost caller replies and three
lost owner replies. Counts are 4987 reads, 2638 caller reads and 56 turn responses;
bounds remain four mutations, 133-byte values and eight resident pages. Native
binary hashes remain those of the ABI/CLI metadata checkpoint.

The report/package hashes and log are
`/tmp/transit-sql-catalog-ruby-metadata-native.json` and
`/tmp/transit-sql-catalog-ruby-metadata-native.log`, from development source based
on `a65c4285`. Empty-final-page validation here is a value test, not an observed
final native page. This focused run does not qualify the six remaining metadata
SDKs or establish a latency comparison.

### C/C++ catalog metadata

C adds bounded inline definition, cursor and eight-entry page values through the
existing native worker; C++ exposes owned strings, vectors and optional values.
C output values clear on failure, and lookup/list accept their input name/cursor
from the same output value by copying it before clearing. Installed tests exercise
both alias cases, foreign/missing cursor definitions, retained metadata after
close and independent C++ copies. Existing compiler rejection of copied C++
client/recovery owners remains in the schedule. Known metadata shape, scope,
identity, ordering and continuation checks do not establish rejection of every
unknown JSON field by the C parser.

The first installed attempt fails in the fixture with `KeyError: next_hex`: its
inherited query adapter expects a hex query cursor on catalog pages. The corrected
catalog adapter decodes only saved command bytes and uses typed catalog cursors.
That failed attempt remains at
`/tmp/transit-sql-catalog-c-metadata-native-failed.json` and
`/tmp/transit-sql-catalog-c-metadata-native.log`; no production compatibility
fallback is added.

Rebuilt installed packages pass `just test::catalog --sdk c --sdk cpp --grow 17`
in **122.816 s**, including **6.856 s** installation. They agree with
Zig/ABI/port/CLI on **24 definitions, three full pages and an empty final page**,
point reads and absence before/after disk-backed node/store restart. Changed
cursors and current catalog/native denial reject; creation/control recovery
retains seven lost caller replies and three lost owner replies. Counts are
5976 reads, 3138 caller reads and 59 turn responses; bounds remain four mutations,
133-byte values and eight resident pages. Native binary hashes are unchanged.

Source is development based on `a65c4285`; package hashes/report are
`/tmp/transit-sql-catalog-c-metadata-native.json`, build log is
`/tmp/transit-sql-catalog-c-metadata-build.log`, and completed native log is
`/tmp/transit-sql-catalog-c-metadata-native-fixed.log`. Shared-host elapsed time is
not a paired latency comparison. Java/.NET/Erlang/Elixir metadata remains outside
this evidence.

### Java catalog metadata

Java adds immutable definitions, Table sources, copied dense page lists and
mandatory original cursors through the existing bounded-future worker. Installed
value checks cover full-width identities, retained immutable values, twelve
malformed-page cases, response identity, repeated/changed continuation cuts,
empty final pages and absence. Existing owned-port malformed/lost responses,
result-allocation failure and cancelled-future cleanup remain in the schedule.

The first installed attempt fails at fixture compilation: referencing Gson's
`JsonParser` exposes unavailable `InlineMe` annotation methods under `-Werror`.
Using the existing `Gson.fromJson` entry point fixes the fixture without changing
dependencies or suppressing warnings. That attempt is retained at
`/tmp/transit-sql-catalog-java-metadata-native.log`.

Rebuilt installed JARs pass `just test::catalog --sdk java --grow 17` in
**64.660 s**, including **2.735 s** installation. Java agrees with Zig/ABI/port/CLI
on **23 definitions over three pages**, point reads and absence before/after
disk-backed node/store restart. Stale cursors and current catalog/native denial
reject. The creation/control schedule retains six lost caller replies and three
lost owner replies. Counts are 5126 reads, 2634 caller reads and 56 turn responses;
bounds remain four mutations, 133-byte values and eight resident pages. All seven
successful Java listings cost four signed reads with negotiated batch support.

Source is development based on `dc2e2e10`; native binary hashes are unchanged.
Report/package hashes are `/tmp/transit-sql-catalog-java-metadata-native.json`;
logs are `/tmp/transit-sql-catalog-java-metadata-build.log` and
`/tmp/transit-sql-catalog-java-metadata-native-fixed.log`. This focused result does
not qualify .NET/Erlang/Elixir metadata or establish a latency comparison.

### .NET catalog metadata

.NET adds immutable definitions, Table sources, copied read-only page collections
and mandatory original cursors through the existing bounded-task worker. Installed
value checks cover full-width identities, retained immutable values, twelve
malformed-page cases, requested identity, repeated/changed continuation cuts,
empty final pages and absence. Existing actual native HTTP read cancellation,
pre-admission cancellation and disposal/join checks remain in the schedule.

The first installed attempt terminates with an unhandled `IncompatibleNative`
exception in its new value fixture: locally constructed `JsonValue<int>` counters
are not parsed neutral JSON numbers. Round-tripping the fixture through JSON
establishes the intended boundary. No production decoder is relaxed. The initial
failure is retained at `/tmp/transit-sql-catalog-dotnet-metadata-native.log`.

Rebuilt installed packages pass `just test::catalog --sdk dotnet --grow 17` in
**61.955 s**, including **4.816 s** installation. They agree with Zig/ABI/port/CLI
on **23 definitions over three pages**, point reads and absence before/after
disk-backed node/store restart. Stale cursors and current catalog/native denial
reject. The creation/control schedule retains six lost caller replies and three
lost owner replies. Counts are 5003 reads, 2629 caller reads and 56 turn responses;
bounds remain four mutations, 133-byte values and eight resident pages. All seven
successful .NET listings cost four signed reads with negotiated batch support.

Source is development based on `5dce22fa`; native binary hashes are unchanged.
Report/package hashes are `/tmp/transit-sql-catalog-dotnet-metadata-native.json`;
logs are `/tmp/transit-sql-catalog-dotnet-metadata-build.log` and
`/tmp/transit-sql-catalog-dotnet-metadata-native-fixed.log`. This focused result
does not qualify Erlang/Elixir metadata or establish a latency comparison.

### Erlang/Elixir catalog metadata

Erlang adds immutable definition, Table source, cursor and bounded dense page
records; Elixir maps them to mandatory-field structs through the same owned
worker. Each installed language exercises full-width values, requested identity,
absence, repeated/changed continuation cuts, twelve malformed-page cases and
empty pages through the actual port boundary. Missing/foreign cursor definitions
reject; external text never becomes a newly allocated atom. Existing uncertain
submission and waiting-process loss/join checks remain in the schedule.

The first installed attempt expects `incompatible_native` for every malformed
page. The existing port instead reports `read_failed` when a neutral reply fails
its generated schema before metadata decoding. The corrected test checks those
exact categories separately from semantic metadata failures. No transport error
mapping changes. The failed attempt remains at
`/tmp/transit-sql-catalog-beam-metadata-native.log`.

Rebuilt installed packages pass
`just test::catalog --sdk erlang --sdk elixir --grow 17` in **81.413 s**, including
**9.413 s** installation. Both agree with Zig/ABI/port/CLI on **24 definitions,
three full pages and an empty final page**, point reads and absence before/after
disk-backed node/store restart. Stale cursors and current catalog/native denial
reject. Creation/control recovery retains seven lost caller replies and three
lost owner replies. Counts are 6002 reads, 3144 caller reads and 59 turn responses;
bounds remain four mutations, 133-byte values and eight resident pages. Each
language makes seven populated listings at four signed reads and two empty final
listings at two signed reads with negotiated batch support.

Source is development based on `bbb6e11d`; native binary hashes are unchanged.
Report/package hashes are `/tmp/transit-sql-catalog-beam-metadata-native.json`;
logs are `/tmp/transit-sql-catalog-beam-metadata-build.log` and
`/tmp/transit-sql-catalog-beam-metadata-native-fixed.log`. All ten SDK metadata
APIs now have focused installed evidence. Cumulative full `just check` passes at
`/tmp/transit-sql-catalog-all-metadata-full-check.log`, including the documentation
build. The first combined command stops at argument parsing because splitting the
Ruby/C commits accidentally removed `c`/`cpp` from the runner's allowed options.
Those options are restored; the stopped attempt remains at
`/tmp/transit-sql-catalog-all-ten-metadata-native.log`. This record does not
establish a completed combined run or a clean-suite pass.

### Combined metadata cleanup investigation

The ten-language metadata schedule at committed `8e021cc6` completes its
functional assertions for **33 named definitions over five pages**, before/after
disk restart, with sixteen lost caller receipts and three lost owner receipts.
It remains **failed**: an installed caller closes stdout during final cleanup
without the expected close response, and the original diagnostic observes its
exit status before reaping. Counts are 15846 reads, 8560 caller reads and 86 turn
responses; bounds remain four mutations, 134-byte values and eight resident pages.
Elapsed time is 356.319 s, including 61.592 s installation. The failed report is
`/tmp/transit-sql-catalog-all-ten-metadata-native-failed.json`; the log is
`/tmp/transit-sql-catalog-all-ten-metadata-native-fixed.log`.

The fixture now joins an EOF child before reporting its exit code and annotates
catalog cleanup failures with the caller surface. Those diagnostics do not
change SDK behavior or turn an incomplete cleanup into success.

The same ten-language command with `--grow 17` passes on development source
based on `8e021cc6`, with those diagnostics and test-only growth timing, in
**393.676 s**, including 85.563 s installation. All fourteen metadata surfaces
agree on 33 definitions over five pages before/after disk restart, current
denial, sixteen lost caller replies and three lost owner replies; final cleanup
reports no failures. Counts are 16473 reads, 8565 caller reads and 86 turn
responses, with the same four-mutation, 134-byte-value and eight-resident-page
bounds. All six native binary hashes match the earlier focused runs. Report and
package hashes are `/tmp/transit-sql-catalog-all-ten-metadata-native-diagnostic.json`;
the log is `/tmp/transit-sql-catalog-all-ten-metadata-native-diagnostic.log`.
This successful rerun does not identify the earlier cleanup failure's cause or
erase that failed run. Surface and final-exit diagnostics remain in the fixture
for recurrence; no SDK runtime fix is claimed.

The clean core run at `8e021cc6` passes 21 of 22 tasks, then fails
`test::state`: its current-resource poll races the separate maintenance process
and receives HTTP 409 `Conflict`. The authority's final journal-tail check in
`growing_read.zig` deliberately rejects that changed observation; no mixed cut
is returned. The reclamation poll now discards exactly that conflict and reads
a fresh cut within its existing ten-second deadline. Denial, unexpected errors,
command retries and fixed-cut continuations are unchanged. The focused
`just test::state` rerun passes at `/tmp/transit-sql-pr27-state-maintenance.log`.
The failed clean report remains at
`/var/tmp/transit-ci-n4hi0a30/src/.cache/ci/core.json`; its log is
`/tmp/transit-sql-catalog-all-metadata-ci-clean.log`. It is not a clean-lane pass.

The next committed clean core attempt at `0621d2a1` fails the external Vortex
schedule after two rounds. Its third turn receives HTTP 503 `AuthorityTimeout`;
the proxy drops that response, and the supervisor incorrectly assumes acceptance
before killing the worker/node/store. The recorded history establishes a missing
test premise, not lost accepted work. Evidence remains under
`/var/tmp/transit-ci-l2btxgaw/src/.cache/verification/vortex/1790796726338078073-seed-1/`
and `/tmp/transit-sql-pr27-state-fixed-ci-clean.log`.

Response-loss/delay injection now waits for HTTP 200 acceptance, forwarding other
responses and retaining the armed fault within the existing supervisor deadline.
An independent loopback proxy check forces a 503 followed by acceptance for both
fault kinds and checks that only the accepted response triggers the fault. It
passes at `/tmp/transit-sql-pr27-vortex-proxy.log` and runs in `test::vortex`.
The real disk schedule `just test::vortex --seed 19 --rounds 12` passes in
**33.892 s** with joined cleanup after this correction; its report/history are
`.cache/verification/vortex/1790796842894520667-seed-19/` and its log is
`/tmp/transit-sql-pr27-vortex-acceptance.log`. Production admission, timeouts and
recovery assertions are unchanged. Neither prior failed clean attempt is a pass.

### Catalog growth attribution

`just test::catalog-growth` runs the disk-backed schedule with 65 additional
Tables; `just test::catalog --grow 257` selects the larger investigation. The
report at `.cache/verification/catalog/native.json` retains source revision,
dirty status, runner and native binary hashes, growth progress and failure state.
Copy it before another run overwrites it. No timeout, cache, turn or value limit
changes with this instrumentation.

The report separates `compile`, `prepare`, `admit` and `await_application` wall
time, calls, failures and caller reads. A failed phase retains its zero-based
growth index; a successful application clears it. An admitted send is not an
applied Table, and a failed status read does not establish rejection. A baseline
immediately before growth and cumulative samples every sixteen Tables (plus the
last Table) allow subtraction of setup work and comparison of successive blocks.
Cursor checks during growth remain outside the four timed phases.

The owned proxy groups upstream attempts by fixed caller/owner/administrator/
other roles and native operation. It records transport failures, HTTP errors,
cumulative elapsed nanoseconds and the maximum observed duration. Durations end
after the upstream body is read; they include queue/provider work and proxy
overhead, overlap across requests, and are not independent CPU measurements.
Deliberately blocked requests never reach upstream; lost-reply attempts count
even when the caller cannot observe the result. Counts describe attempts, not
unique durable commits. Metrics contain no request bodies or credential values.
Compare native request counts and phase costs at equivalent workload boundaries;
shared-host durations do not establish percentiles or throughput guarantees.
After stopping the node, the report also retains at most 64 distinct node/storage
error groups, with occurrence counts, first timestamps and maximum observed
durations. Further groups increment a dropped counter. These summaries preserve
errors that can fall outside the printed log tail, without retaining payloads,
credentials or user labels; they do not establish operation outcomes.

The first instrumented disk runs use runner SHA-256
`63fa35689262d5fce12b5a303fcf390f3812931cf9a64a6375e7e76e3eb47fbe`
and the same six native binaries, with eight resident authority pages. The
65-additional-Table run at committed `d681181d` passes in **233.028 s**, lists
70 named definitions in nine pages, and repeats the metadata checks after
node/store restart. Cleanup joins. Growth itself takes **112.669 s**:

| Phase             | Calls | Seconds | Caller reads |
| ----------------- | ----: | ------: | -----------: |
| Compile           |    65 |   0.010 |            0 |
| Prepare           |    65 |   1.923 |          130 |
| Admit             |    65 |  10.595 |            0 |
| Await application |    65 |  99.922 |         1089 |

Growth-only upstream observations include 65 owner turns (**41.125 s**), 845
owner entry reads (**38.810 s**) and 1170 caller entry reads (**89.375 s**).
These overlapping durations include serialized authority/provider work and
contention; they are not additive phase costs. Validation runs share the host.

The 257-additional-Table attempt at committed `05454efd` fails in **508.687 s**
after **138** additions apply. The next send is admitted, then index 138 remains
in `await_application` at the unchanged twenty-second progress deadline. Owner
turns repeatedly report `AuthorityUnavailable`. Cleanup joins, but the final
listing/restart checks are not reached and the pending operation's outcome is
not established. This attempt supplies failure attribution, not a larger-growth
pass. Both reports retain complete binary hashes and source identities; later
rebases preserve the runner's content.

Committed-head clean experience runs at `1c4d91e1` (source tree `3d38f5a7`,
matching the merged implementation) and `0dc49100` (tree `6216f338`, matching
the rebased attribution increment `c79c4307`) each pass six of seven tasks.
Board query inspection passes in **103.43 s** and **101.79 s** respectively.
Both fail `launchers::local::test-station` waiting for the requester Arrow reply,
after **275.54 s** and **277.76 s**. Private fixture logs and WALs are retained
for diagnosis. Neither is a clean experience pass; these runs do not supersede
the separate full `just check` passes or establish all clean-suite gates.

The corrected clean core run at `4927ba38` passes nineteen tasks, including
Vortex, Station and all disk storage phases. It then fails `test::callers` in
**17.63 s** when the courier-progress observation sees `AuthorityUnavailable`;
the last two core tasks are not reached. Node observations show a two-second
request deadline interrupting page staging and a queued observation. This is
not a clean-core pass or a demonstrated root cause of the earlier catalog failure.

### Balanced batch splits and larger catalog growth

The original binaries repeat the failure after exactly 138 applied additions
in **564.408 s** with the diagnostic runner. Cleanup joins and no storage-error
group is recorded; sixteen native attempts report `AuthorityUnavailable`.
The independent descending-key page regression fails with `PageDepthExceeded`:
batch splits pack one sibling full, so descending inserts repeatedly split the
left spine and reach the 32-level guard before 257 keys. Evenly distributing
entries and children across split pages fixes that insertion pattern without
changing page encodings, mutation budgets, resident limits or deadlines.

At committed `1483b330`, all **60** standalone core tests and full `just check`
pass. The new regression checks 257 descending keys in batches of one, four and
eight, retained roots, ordered scans and at most nine page loads per lookup.
`just test::resource-simulation --seeds 8` passes **798 traces / 15,496 events**
with identical replay in **437.762 s**. All six negative controls are detected.
Its binary SHA-256 is
`82db89402f28ae6b1d28b999392600c912870c2f67bae7f8d220ef659bfacda6`;
the two-page in-memory fault store does not establish physical disk durability.

`just test::catalog --grow 257` then passes in **397.642 s**, including **262
named definitions / 33 pages**, repeated metadata after node/store restart,
current denial, original lost-reply recovery and joined cleanup. It uses eight
resident authority pages, at most four turn mutations and 132-byte values.
Only the node binary differs from the original runs; its SHA-256 is
`214b0646e187cd12676c995d4b2badd0e4962631988df0946440039b32dfcd04`.
The five caller/host binary hashes remain equal. The report retains all hashes
and the diagnostic runner identity.

The 257 growth additions take **254.420 s**: compile **0.041 s**, prepare
**3.488 s**, admission **30.433 s**, application waiting **220.260 s**.
All growth phases succeed. There are 257 owner-turn attempts and 3341 owner-entry
reads (thirteen per Table), with no growth transport/HTTP errors. These shared-host
instrumented samples establish the completed workload, not a throughput ratio.
The existing roots of previously deep catalogs are not rebuilt; continuation
from an already exhausted height guard remains a separate recovery qualification.
Committed-head `just ci-clean --lane core` at `1483b330` passes all **22 tasks**
in **947.49 s**, including the caller-progress test that failed in the earlier
attempt. Its completion/timing records are retained under
`.cache/ci/clean/1483b330d7b9-transit-ci-lwcj_yf3/`. Subsequent changes only record
evidence in this ledger and the roadmap; their documentation links pass. This
is a clean core-lane pass, not an experience/bindings/complete-suite or hosted
CI pass. The earlier experience failures are not reclassified as successes.

### Resuming a depth-exhausted catalog

The optional `test::catalog --grow 257 --initial-node PATH` schedule starts
with an explicitly supplied pre-fix node binary. Its digest is recorded alongside
the target binary. At the known zero-based growth index 138, it requires two
`AuthorityUnavailable` responses to the exact same owner turn, then replaces
only the node binary across disk-store restart. The worker and its frozen turn
stay alive. Success requires that same turn's receipt and the originally admitted
SQL input, followed by continued growth and the normal metadata/restart/denial
checks. The SQL send is not resubmitted. No operation deadline is increased.

Failure joins owned services and retains the private fixture under
`.cache/verification/catalog/recovery-failures/`; it contains credentials and
must not be published. `node_recovery` records the initial digest, original turn
digest, input, observed failures, replacement and receipt state. Retained
configurations still name their original temporary paths; the fixture is
diagnostic evidence, not an automatically restorable launcher installation.

The native cold-store process is joined before its files move into the retained
fixture. `test::catalog` first checks this lifecycle with a disposable native
child and an injected unjoined child. The
cleanup control (archived)
reproduces the stale Docker cleanup path's `ColdStore.name` `AttributeError`;
the corrected path preserves both authority and cold files after normal cleanup
and refuses to remove unjoined cold state. This is fixture lifecycle evidence,
not MinIO or database durability qualification. Stop/kill timeouts and provider
disk reserves are unchanged.

At committed `c8e58460`, full checks pass in 220.788 seconds. The actual native
cold-catalog task passes in 143.566 seconds including compilation; its proof
runs for 14.867 seconds with 73 cold objects, an 8 MiB hot-store limit, six lost
caller receipts, three lost writer receipts and no cleanup failures. The clean
experience lane passes all seven tasks in 478.951 seconds including setup;
Station observes its original Arrow reply in 38.818 seconds before cleanup,
within the unchanged 60-second deadline. These are separate from the lifecycle
controls and do not complete the ordinary suite. Hosted run `36874212362` is
refused before test execution by the account billing/spending restriction.

With source based on `ef2cc97d` and the recovery runner under development, the
original node digest `1039c8de…328d6e07e` stalls after 138 additions. Replacing it
with the split-only node `214b0646…2dfcd04` still fails the unchanged progress
deadline in **416.073 s** total. Input **538** remains without an observed turn
receipt. The private fixture is retained; this is not successful recovery.
A separate current-v1 page fixture with a full spine and sparse siblings at
height 32 also fails `PageDepthExceeded` before local sibling merging. After
merging, all **61** core component tests pass, including 64 further inserts,
old-root preservation and refusal/lost-acknowledgement at every staging boundary
of the first repaired mutation. Disk qualification of that repair follows.

At `85009af5`, the repaired node `89e7f544…d65f0a19` resumes the exact original
turn: input **538** produces receipt **540**, with the worker and signed turn
unchanged across replacement. The full run still fails after **145** additions
in **477.296 s**. Ursula reports `ColdBackpressure` at its **64 MiB** hot-store
limit; this fixture has no cold tier. The node records 161 `page.stage`
`ServiceUnavailable` failures. Joined cleanup succeeds and the private fixture
is retained. This establishes receipt recovery, not full growth qualification.

`--cold` selects the existing owned S3 fixture with an **8 MiB** hot-store
limit and **8 MiB** cold cache. It requires actual persisted cold chunks and
records object count and file bytes. Use it with `--initial-node` for continued
growth beyond the hot-only fixture's capacity; operation deadlines, eight
authority cache pages and four application mutations remain unchanged. Failed
upgrade runs retain the stopped cold-store files with their private disk fixture.
The first cold run at `1f6dd4ee` fails on `AuthorityTimeout` before node
replacement. Its proxy-drain cleanup then fails, so the last report contains
only an earlier **112-addition / 263.393 s** sample; final progress and fixture
retention are not established. `b97406fe` makes cleanup continue through
authority/proxy shutdown and final reporting after a drain error, and retains
failed upgrade fixtures even when cleanup itself fails.

The retry at committed `b97406fe` passes in **1438.997 s**. It recovers original
input **538** as receipt **540** after two failures of the same signed turn,
then applies all **257** additions. All **262 definitions / 33 pages** pass
Zig, ABI, port and CLI metadata checks, a further node/store restart, current
denial and joined cleanup. The worker and original SQL input are preserved;
no send is resubmitted. The run retains eight authority cache pages, four
mutations and the unchanged operation deadlines. Its S3 fixture uses an **8 MiB**
hot limit and **8 MiB** cold cache, and holds **1125 persisted cold chunks** and
**142,532,884 filesystem bytes** including object-store metadata.

Growth takes **823.220 s**: compile **0.040 s**, prepare **15.111 s**, admit
**78.784 s**, and await application **729.043 s**. There are **4890** measured
metadata calls across the complete schedule. The only `AuthorityUnavailable`
responses recorded by the node are the two expected pre-replacement failures;
cleanup reports no failures. These shared-host durations are not a throughput
comparison with the fresh balanced-tree schedule. Earlier failed runs remain
failed, and their causes are not inferred from this retry's success.

The target node digest is `89e7f544…d65f0a19`, the initial node is
`1039c8de…328d6e07e`, and the runner is `f9329712…67ac8b82a`.
The full hashes, source identity and measurements are retained in
`/tmp/transit-sql-deep-catalog-recovery-cold-retry.json`; its matching `.log`
contains the executed command and completion output.

The same `85009af5` passes full `just check` and the eight-seed resource
simulation: **798 traces**, **15,496 events**, **1598 executions**, identical
replay and all six negative controls in **431.120 s**. Its committed-head clean
core attempt fails in the first task's CLI terminal cleanup after **81.49 s**;
the remaining 21 tasks do not run. Strict cleanup diagnostics expose exit 130
when cleanup sends Ctrl-C during command output. The fixture now queues editor
draft clearing and ordinary `.quit`, preserving explicit interrupt tests and
rethrowing unexpected exits/timeouts. The focused 399-case CLI diagnostic suite
passes with queued quit. Full `just check` also passes after the terminal cleanup
and diagnostic-path lifetime fixes.

Committed `1f6dd4ee` then passes all **22 clean-core tasks** in **1154.37 s**
and all **seven clean-experience tasks** in **501.07 s**. Core includes the
399-case CLI diagnostic suite, simulations, disk WAL/recovery, callers,
inspection and state. Station's disk readiness write takes **307.79 s** and the
complete storage task **481.35 s**; the experience Station replacement/restart
task takes **283.96 s**. Evidence is retained in
`.cache/ci/clean/1f6dd4eec3fd-transit-ci-58qo5jmn/` and
`.cache/ci/clean/1f6dd4eec3fd-transit-ci-mr8_g_9s/`. These are two lane passes,
not the complete CI inventory. The later catalog cleanup change affects only
the proof runner and remains under focused disk qualification.

The clean experience run at rebased `ef2cc97d` passes all **seven tasks** in
**433.89 s**, including Station's Arrow exchange, replacements and persistent
restart in **220.67 s**. This revision includes main's type/schema-discovery
documentation, with unchanged split-only runtime code. Evidence is retained in
`.cache/ci/clean/ef2cc97dc6b0-transit-ci-dl5e5q05/`. It does not retroactively pass
the earlier failures or qualify the subsequent sibling-merging change.

### Shared immutable paths for bounded point reads

`edb54a12` adds a bounded tree traversal for native `read_entries`. It retains
caller order and current native authority checks while sharing immutable paths
among the existing eight requested keys. Component fixtures cover absent and
repeated keys, invalid input before I/O, every selected page-load failure,
corruption and retained roots. The depth-32 eight-key fixture records **37 page
loads**, compared with **264** separate lookup loads. These counts are component
I/O evidence, not a native throughput result.

All **62 core component tests**, full `just check` and the eight-seed resource
simulation pass. The simulation records **798 traces / 15,496 events / 1598
executions**, identical replay and all six negative controls in **437.816 s**.
Committed-head `just ci-clean --lane core` passes all **22 tasks** in
**1060.07 s**. Evidence is retained under
`.cache/ci/clean/edb54a12a558-transit-ci-4bx7pg1w/`; this is one lane, not the
complete CI suite. Subsequent history changes and parent evidence documentation
do not change these runtime files.

The cold-tier legacy-root recovery schedule at the same clean source fails in
**1248.201 s**, after **213** additions, on `AuthorityTimeout` during the next
application-status read. The original input **538** recovered as receipt **540**
after node replacement, but the remaining growth and larger metadata/restart
phases did not complete. Joined cleanup succeeds and retains the private
fixture. This is not a full recovery-profile pass. Node diagnostics record two
additional ten-second `AuthorityUnavailable` requests and `ReadFailed` events
for page staging and journal tail; these observations do not establish the
timeout's cause. Operation deadlines and resident bounds are unchanged.

The runner is `f9329712…67ac8b82a`, the target node is
`fa29956b…fdf8f`, and the other five binaries match the completed sparse-sibling
baseline above. Source, full hashes, failed phase and retained fixture location
are recorded in `/tmp/transit-sql-shared-point-read-cold-recovery.json`, with its
matching `.log`. The private fixture includes credentials and must not be
published. PRs #40 and #41 are merged; merge status does not qualify this failed
schedule or establish a performance improvement under native cold storage.

### Shared reads for catalog mutation counts

The `perf/sql-catalog-mutation-reads` continuation starts from merged #41 at
`d5541301` in its own `transit-sql-catalog-mutation-reads` worktree. Catalog mutation
counting now uses the existing bounded `Tree.getMany` before staging the new
candidate. It validates all keys, values and duplicate keys before page I/O,
reads the original immutable cut, and updates the root and count together only
after successful staging. The eight-key bound and current v1 formats are unchanged.

The standalone core suite passes **64 tests**. An eight-operation fixture over
64 existing records mixes inserts, replacement, deletes and no-ops in unsorted
caller order. It records **45 page loads** with separate existence reads versus
**23** with shared traversal, including the same subsequent tree mutation in
both counts. Both produce the same immutable candidate root. Independent expected
values check all 130 addresses in the selected range and the retained old cut;
the new count is 65. Every observed read failure and staging failure/lost
acknowledgement preserves the original candidate root and count. Corrupt pages
reject; empty/no-op batches do not stage; malformed and oversized batches reject
before reads or writes. The log is
`/tmp/transit-sql-catalog-mutation-batch-unit-final.log`.

This is component I/O evidence, not a native latency improvement. The earlier
shared-point-read cold recovery failure remains open: a status observation times
out after 213 additions, while the original accepted turn has recovered. Its
retained node log shows the final read spending almost ten seconds waiting
behind an `open_view` write that also reaches its deadline. The batching change
reduces demonstrated repeated work; it does not by itself diagnose that provider
stall or qualify the full native recovery schedule. Full checks, resource-fault
simulation and native/committed-head clean evidence are recorded separately.

At committed `68794bd7`, full `just check` passes, including generated contracts,
CLI, frontend and documentation checks. The eight-seed resource simulation
passes **798 traces / 15,496 events / 1,598 executions**, with identical replay
in **450.845 s**. Its report records dirty source based on `d5541301`; the
production source was committed unchanged as `68794bd7`. Committed-head
`just ci-clean --lane core --work-root /var/tmp` passes all **22 tasks** in
**1254.78 s**, without inherited workspace build outputs. Evidence is retained
under `.cache/ci/clean/68794bd70102-transit-ci-w03ie6wa` and in
`/tmp/transit-sql-catalog-mutation-batch-resource-simulation.json`.

The native cold-recovery schedule at that same committed revision **fails after
149 applied additions / 944.550 s** on an application-status `AuthorityTimeout`.
Original input **538** recovers as receipt **540** without resubmission. Joined
cleanup succeeds. Eight authority pages, four mutations, the 8 MiB hot store
and 8 MiB cold cache remain the bounds. The full 257-addition continuation,
later metadata/restart and disclosure checks are unqualified for this candidate.
The record is `/tmp/transit-sql-catalog-mutation-batch-cold-recovery.json`; the
private failure fixture remains under
`.cache/verification/catalog/recovery-failures/1790809229338501922`.

Its final node events distinguish a turn reaching the ten-second deadline
(52 cache hits / 912 misses) from the following read spending **9.950 s**
waiting and **0.050 s** working before its own deadline. A later turn is logged
successful at position **573**, but the interrupted proof did not observe its
application status. Neither that log nor component page-load savings qualifies
the missing end-to-end assertions or establishes the storage stall's cause.
The complete native run remains failed; no deadline has been increased.

## Offline state declaration compiler

The additive Fuze `Declaration` API parses, validates and formats owned
`CREATE TABLE/KV/DOCUMENT` definitions. Its explicit `tableSchema` adapter accepts
only the existing two-column Table profile. This is offline compiler evidence;
it does not qualify a catalog, resource creation, grants, publication, language
SDK/CLI administration or wider Table storage. Existing native and ABI definitions
are unchanged. [The contract](../../../contracts/STATE_DECLARATION_V1.md) owns semantics;
`SQL-DECLARATION-01` and the per-definition bound are in the verification inventory.

Executed in the pinned bindings shell on the development source based on
`aba61401`:

- Full `just check` passes, including generated contracts, native/package tests,
  CLI diagnostics, frontend checks and the production documentation build. Final
  proof-inventory and documentation checks cover 51 invariants, 52 classified
  bounds, 12 SDK scenarios and 4498 local links across 472 files.
- Standalone `transit-fuze` `zig build test` passes, including five declaration
  tests for owned names, canonical padding, sparse/duplicate columns, whole-input
  rejection, formatting buffers and explicit Table capability checks.
- `just test::sql` passes **182 declaration cases**, including the complete
  four-type/three-nullability product for both Table columns. **156 Zig/ANTLR
  ASTs agree**, canonical formatting reparses in both implementations, and five
  compatible definitions match independently calculated existing Table schema
  fingerprints. Other cases reject at syntax, structural or capability boundaries.
  Existing SELECT/Arrow, unified-source and mutation oracles also pass.
- `just test::sql-benchmark --samples 7 --output
.cache/verification/sql/state-declaration-benchmark.json` records seven warmed
  ReleaseSafe processes with 10,000 compilations per case. The pinned compiler
  is `0.17.0-dev.2267+48abf1a34`; the probe SHA-256 is
  `83e09098bd4ac3877a8dec229b22936d70ac8fe0bcad9b2ee464799f77948ad9`.

| Offline declaration | Median ns/compile | Observed min–max |
| ------------------- | ----------------: | ---------------: |
| Two-column Table    |            296.92 |    284.35–317.55 |
| KV                  |            133.13 |    130.98–136.94 |
| Document            |            119.28 |    114.54–120.86 |
| Eight-column Table  |            632.59 |    612.16–636.75 |

The raw report identifies dirty source, platform and binary. This is a local
compiler baseline with no allocation, source I/O, authorization, publication or
transport work. It is not a before/after speedup or end-to-end latency claim.

At committed implementation `0bb8364c`, `just ci-clean --lane core` passes all
18 tasks without inherited workspace build outputs: foundation, properties,
simulation, codecs, tooling, packages, compute, client ABI, Station, disk storage,
service, runtime upgrade, callers, inspection and state. Package builds take
135.06 seconds, Station 150.09 seconds and storage 212.97 seconds, including the
129.00-second readiness write schedule. Completion, exact revision and timings
are retained under `.cache/ci/clean/0bb8364c2384-transit-ci-3clcw1pd/`.
The following evidence-only commit changes no production source. This is a
complete core-lane pass plus the focused SQL proof above, not a full clean-suite
or administrative-execution qualification.

## Stored-definition recovery correction

The former `LegacyAcceptedGrowthHistory` assertion instantiated the current
`adapter.Store` under a legacy variable name and incorrectly required it to reject
current history. The replacement writes separate foreign-definition and
missing-definition records to disposable disk journals, then requires exact
decoding errors before recovery can write pages or append authority. The checks
repeat after provider restart and checkpoint/trim of the valid journal.
At dirty source based on `a59e0d9c`, `just test::growing` passed write, recovery,
checkpoint and trimmed recovery (54.098, 3.859, 6.668 and 3.776 seconds). This fixes
that focused proof; a complete clean CI run remains separately required.

## M9 Station, bindings and Tables

The final implementation at `1462041` passed `just ci-clean` with no inherited
checkout build outputs. All target languages passed in that run. Embedded Board
passed its five Chromium checks; the Station local, Compose and Substrate
profiles passed their separate recovery/upgrade proofs. `just doctor` and
Actionlint also passed. This records local qualification, not a hosted CI speed
measurement or validation of other operating systems/architectures.

The Linux x86_64 profile uses the locked Zig 0.17 compiler, the pinned
`rupurt/zarrow` and `rupurt/zarrow-compute` forks, disk Ursula, and the real public
authority/courier. Framework logic remains in Zig; no language-specific server
route or second authoritative task/state store is introduced.

| Proof                                                                                                                     | Evidence                                                                                                                                                                                                                                                                                                                                                   |
| ------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `just test::station`                                                                                                      | Three behavior roles, two-Table atomic turns, exact retry after receipt loss, worker/store restart, source-authenticated calls/replies, captured Arrow publication/consumer restart, service-policy revocation, registry rebind with the original PID retained, timed waits/late-result closure, poison-head supervision and independent lifecycle control |
| `just test::station` lifetime schedule                                                                                    | Required PID-owned Table state survives recovery; suspension beyond a dependency is rejected; opted-in expiry permanently rejects activation and permits background reclamation, including after authority restart                                                                                                                                         |
| `just bindings::native`                                                                                                   | C/C++/Python real callers; shared ABI exact frozen request recovery after every handle is lost; failed-turn rollback, stale/revoked/retired callers, wide correlations, malformed native-port input, asynchronous cancellation and owned cleanup                                                                                                           |
| `just bindings::native` materialization schedule                                                                          | Duplicate source admission/commit, update/delete, physical checkpoint/trim, reinsertion in the tail, disk/node restart and an independent Arrow aggregate over only current rows                                                                                                                                                                           |
| `nix develop .#bindings --command just bindings::test`                                                                    | C, C++, Rust, Python, Node, Java, .NET, Erlang and Elixir each run service and requester roles across language pairs; fresh hosts resume captured results; exact `9007199254740993` values survive Arrow; managed/port tests cover bounded input, busy handles, host/caller loss, responsive schedulers and cancellation/cleanup                           |
| `just test::unit`, `just test::packages`, `just test::arrow`                                                              | Private batch rollback, capacity and schema checks, all admitted Arrow types/null/empty/overflow behavior, C Data/C Stream release ownership, exact source basis and no enabled rewrites, cancelled queries, maximum 672-byte captured reply, malformed/duplicate/missing fragments and no prefix completion                                               |
| `just transit-board::test`, `just transit-board::browser`                                                                 | Versioned framework metadata with source PID/resource/key/revisions; unknown versions fall back safely; no application-state decoder                                                                                                                                                                                                                       |
| `just launchers::local::test-station`, `just launchers::compose::test-station`, `just launchers::reference::test-station` | Same three-process scenario, scoped service roles, registry/call/Arrow exchange, Board provenance, worker recovery, compatible upgrades of all three workers with PIDs/state retained, no-op updates and persistent stop/start                                                                                                                             |

The reference proof additionally kills an actual Substrate worker pod, verifies
a fresh activation/key while retaining the Actor UID, and upgrades versioned
worker templates through the recorded protocol. It uses the shared Helm chart
with three separate PID-scoped runtime controllers and two framework controllers.
Failed launcher runs retain their own installation; successful ones remove only
their own application resources. The shared infrastructure is not destroyed.

The ordinary CI inventory includes the local Station proof and full language
matrix. Docker Compose and reference proofs require Docker/the provider fixture
and run in the opt-in reference workflow or as explicit qualification commands.
No hosted run-time improvement is
claimed from local measurements; the CI lanes report their individual task times.

Qualification is deliberately finite: four realm resources, 32 entries per
resource, four mutations/outputs per turn, one mutated resource and at most
672 captured IPC bytes. Execution pulls one synchronous batch into bounded
buffers; it has no queued pipeline or parallel in-flight operators. Slow remote
consumption is durable mailbox/result state, not a live Arrow task. No optimizer
rewrite is enabled. Unlimited retention is the default and does not evict old
waits/results when capacity fills. See the [Table guide](../../../packages/zig/transit-station/docs/tables.md).

Only Zig workers are qualified on Substrate. Client support does not establish
foreign-VM isolation, public SDK releases or non-Linux portability. Logical
supervisor retry also cannot guarantee fresh provider placement; the
[example runbook](../../../examples/station-ledger/docs/running.md#recovery-and-incremental-work)
records the required operator recovery when Substrate reuses an old pod.
Continuous queries, multi-resource transactions, SQL, Documents and remote
Flight/ADBC remain later milestones.

## Direct catalog hard cutover and retired owner — 2026-10-24

The general actor-backed Table catalog/service, its query-host role, mediation
schema and dedicated transport fixtures are removed. General caller, SQL and
query paths use the direct owner. Private Station Table helpers retain their
native-turn boundary. The shared definition is
`7eb140320f47f8c8c3dd96ee6f74a43e6daaf68c4ec4c3639e8b0fbc900aca8f`;
contracts, host/browser declarations and independent signing/encoded fixtures
are regenerated together. Earlier artifacts require their matching build; no
converter or automatic reset is supplied.

The seeded catalog schedule now drives direct admission, publication, conflict,
cancellation, current policy, paged inspection and original receipt recovery
through volatile log/object adapters. Its two-seed run produced ten identical
replayed domain schedules in 38.581 seconds before the final definition refresh.
This is component state-machine evidence, not disk durability. The four catalog
mutation probes now target these direct guards; their committed-source execution
remains pending at this checkpoint.

Current diagnostic checks pass 3,401 projections across 24 declared surfaces.
The inventory records 578 production owners, 4,605 owner/error pairs, 687 qualified
surfaces, 14 declared error sets and 4,769 error-return boundaries. Removed
projection families and 23 dormant causes belonged only to the retired owner.
The verification inventory passes 68 invariants, 68 classified bounds and 14 SDK
scenarios; documentation checks pass 5,993 local links across 577 files.

The first integrated check passed contract/binding checks, then found stale
independent Unified source/bundle digests after the definition replacement. Their
owning encoder regenerated those fixtures. That attempt is not a full-check pass;
combined repository, committed-source mutation and clean-checkout validation
remain required.

## Direct catalog mutation checks — 2026-10-24

`just test::domain-simulation-mutations` passes on committed source `b48875510`
from an isolated checkout. The unmodified baseline executes five domain schedules
with identical replay in 19.034 seconds. All nine compiling mutations are detected
by executed assertions: Document conflicts, checkpoint floors, exchange holds,
refresh generations, provider readiness, catalog CREATE policy, original Table
receipt positions, metadata inspection rights and directory continuation bases.

The earlier `fbaf0bff1` run stopped because the receipt mutation had invalid Zig
syntax. It is inconclusive, not a detected semantic regression. The corrected
probe compiles and fails the direct catalog schedule's original-receipt assertion.
Evidence is retained in
`.cache/verification/domain-simulation-mutations-b48875510/`, including baseline,
per-mutation logs, replay traces and `evidence.json`. These are component guards
over volatile adapters; physical recovery remains separately qualified.

## Public dependency graph growth and restart — 2026-10-24

`just test::direct-table-service dependency-growth` passes 577 typed calls with
139 retained dependency edges, one native resident page and the direct catalog's
16-page cache. The shared host boundary registers distinct captured-definition
identities under one explicitly authorized native metadata resource. Four-edge
forward pages and single-dependent reverse pages verify every identity and exact
interpretation without accumulating the graph. Strict digest order, a fixed
observation position and the exact identity range establish completeness.

After node SIGKILL and disk restart, both graph directions, the byte-identical
saved plan and original first receipt remain valid. Current metadata revocation
redacts all pages and denies receipt inspection while DROP RESTRICT still holds;
restored rights recover the same receipt. These are dependency metadata owners,
not 139 executed captured queries or a distributed-provider test.

The first attempt failed compilation because a cursor capture shadowed a
parameter. The next functional run passed but reported temporary fixture string
leaks. The corrected fixture owns those strings in a bounded preparation arena,
retains only native fixed-size evidence, and passes the full run without allocator
errors. The ordinary catalog task now includes this schedule and the separate
139-resource growth/restart schedule; the latter has no completed run at this
checkpoint.

## Public named resource growth and restart — 2026-10-25

`nix develop --command just test::direct-table-service resource-growth` passes
the complete ReleaseSafe schedule with 1,437 typed catalog calls. The phase
separation and caller diagnostics are recorded in `47e7ae729`; the retained run
log is `/var/tmp/transit-named-resource-growth-5.log`. The earlier failed and
interrupted attempts above remain unqualified.

The public host/caller path provisions and initializes 139 distinct resources:
70 KV resources and 69 Documents, each with its own native writer. Every object
passes typed data readback during setup. Publication remains absent until the
owning initialization completes; the fixture also checks the denied intermediate
allocation step before the required resource grants are supplied.

The fixture then reads the entire directory and every value before node
replacement, kills the actual node with SIGKILL, restarts it over the same local
native/direct storage, and repeats the complete readback. KV values equal
`durable named value`; Documents retain revision 1 and the integer value 42.
Directory traversal preserves exact object order, names and its original
position across bounded eight-entry pages. The original first operation's
inspection and exact retry both reproduce its complete receipt. Saved profile
and final declaration bytes remain unchanged across replacement.

The node retains eight native resident pages and sixteen direct catalog pages;
139 initialized objects exceed the direct cache's eight-entry leaf capacity.
That passing run used a 3,600-second aggregate setup budget; each complete readback had 900 seconds,
with the original per-request bounds unchanged. This is local process-recovery
and bounded-cache evidence, not a host-loss, distributed-writer or latency result.
Reference Follow and committed-HEAD clean-checkout qualification remain open.

## Neutral index contracts — 2026-10-25

The [index lifecycle contract](../../../contracts/INDEX_LIFECYCLE_V1.md) and protocol
`IndexLifecycle` module implement offline declaration commitments, exact
source/column/constraint bindings, build generations, maintenance observations
and conditional coverage publication. They add no installed index operation,
secondary structure, online build or planner eligibility decision.

With the pinned Nix shell, `just contract::generate`, `just contract::check` and
`zig build test` in `packages/zig/transit-protocol` pass. The new schema is
reflected from the public types. An independent Python SHA-256 fixture agrees
with Zig for ordinary and constraint-owned declarations, including full-width
identities. Existing generated request/ABI schemas and signing fixtures remain
unchanged; this additive descriptor family does not change an existing request
or stored format.

Six protocol tests cover declaration tampering, key order/NULL policy, source
interpretation and constraint changes, cross-branch/self dependencies, empty
and duplicate columns, the combined 128-column boundary, WAL-only bases and
incomplete checkpoint refusal, backward/cross-partition progress, exact old/new
query-cut mismatch, physically different checkpoints at the same logical cut,
snapshot consistency and immutable publication retries. Missing/foreign shared
definitions reject. Schema checks also reject unsupported key comparisons and
undeclared predicate/collation/encoding extensions.

These are deterministic contract checks. They do not prove that a claimed
index root exists, contains every visible row, is retained or is authorized.
The future catalog/query owner must establish those facts separately. Complete
build progress does not publish coverage or enable a query. The repository and
committed-checkout qualification review remains a separate gate.

## Installed lifecycle statement budgets — 2026-10-25

The final clean experience lane at `4dc0d3ba01497e4cac9929e0817ce4bc221fde92`
fails `test::server-direct-tables` after 174.99 seconds: namespace rename reports
`SqlOutcomeUnknown`, followed by expiry of the separate prepared session during
cleanup. Inspecting that retained installation after restart finds all ten
original operations terminal, including applied rename operation 483, and the
renamed schema. No SQL statement is resubmitted during that inspection.
An unchanged rerun also fails while observing an UPDATE. These attempts do not
count as passing the task or lane.

A diagnostic Unix-socket proxy using the same installed binaries observes an
INSERT invocation end after 30,162.491 ms; the execute response arrives after
30,304.430 ms with its original operation still uploading. The proxy run is
diagnostic evidence, not the unmodified integration proof. The console's default
30-second admission-discovery budget is shorter than this fixture's configured
120-second server command budget. The unknown outcome is correct; neither a
client deadline nor session expiry establishes rollback.

The lifecycle fixture now explicitly selects that same 120-second client budget
and a 180-second subprocess cap. During independent CLI statements it renews the
existing prepared peer's lease, preserving that peer and its original prepared
statement for the stale-definition assertion. Default client/server budgets,
expiry behavior, runtime implementation, request identities and retry semantics
are unchanged. This is a correctness schedule with explicit waits; the failures
remain evidence that these local operations can exceed the default client
budget. The separate session-lifetime proofs retain their short expiry bounds.
A complete committed-source rerun is still required for acceptance.

## Paged Table history observation — 2026-10-26

`nix develop --command just test::direct-table-service` passes with the existing
one-page native cache and unchanged 180-second lifecycle subprocess deadline.
The [baseline and corrected logs](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/table-history-pages-2026-10-26/report.json)
retain the preceding timeout during the second replay, after transaction four.
The reader now uses the owner's existing eight-frame history page to cross
physical maintenance. It consumes only the first logical acceptance and advances
to that acceptance's exact point, so later transactions in the page are reread
rather than skipped.

Both complete replays assert all eight original transaction receipts, no-ops,
paired rows under original schemas, definition changes and retirement. Charged
requests through the eighth transaction decrease from 300 to 210 per replay.
Partial delivery still cannot produce a checkpoint; allocation failure preserves
progress. Final checkpoints resume at the fixed upper bound. The complete proof
passes history/delegation closure, caller/node replacement, current revocation
and reserved-control denial, across 1,407 typed calls. Row ownership, request
budgets, cache size and authorization checks are unchanged. This is not a latency
benchmark or a complete clean growth-lane pass.

## Work-item command definition cutover — 2026-10-26

The clean core run at `e3cbe9cca` finds an old shared definition in the independent
WI1 command fixture: the Python drift check fails and the application unit suite
reports 12 passes and one failure. Regenerating with
`tests/work_items_contract.py --write` changes only that definition. The generator
check and `zig build test-work-items-unit -Doptimize=ReleaseSafe` then pass;
[recorded evidence](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/work-item-definition-2026-10-26/report.json)
preserves both failures. Contract generation/checking now includes this fixture,
so future definition changes regenerate it and detect drift before root unit
execution. Existing foreign/missing-definition rejection remains unchanged.

## Installed Table qualification and original outcomes — 2026-10-26

Committed-HEAD `nix develop --command just ci-clean --lane experience` at
`e550f4ed54ec4cd9a1c40cb4c568a64752861a16` passes five tasks, then fails
`test::server-direct-tables`: its post-restart DELETE/DROP batch exceeds the
unchanged 300-second console deadline during native authority unavailability
and node replacement. The [retained evidence](https://github.com/spoke-sh/transit/blob/a610ecd5dcff22f2d0177b61b905a8e985252c13/tests/verification/results/installed-table-closeout-2026-10-26/report.json)
includes the failed lane, manager logs and signed public inspection after
restarting the original installation with unchanged binaries. DELETE operation
647 is terminal and applied with one matched/changed row. Subsequent operation
695 remains uploading, dispatch-ineligible and without a terminal outcome.
The observation submits no replacement SQL, execution or cancellation.

Two fresh diagnostic installations pass the complete unchanged Table workload,
including CRUD/DDL, namespace lifecycle, stale preparation, RESTRICT, abrupt
restart and name reuse. The first uses the original binary bytes and completes
in 656.65 seconds. The second uses a node rebuilt with temporary WAL I/O failure
labels and completes in 508.48 seconds. Both retain node/gateway stderr through
explicit exec wrappers; their changed artifact paths make them diagnostics,
not installed-adjacency qualification. The source patch, binary hashes, scripts
and complete captures are retained. The branch's WAL source is unchanged.

Both captures contain deadline interruptions followed by continued native
progress, without `WalRecoveryRequired`. The tracing run produces no WAL I/O
failure label. These observations do not establish the original failure's exact
stage or cause, nor turn the failed clean lane into a pass. Timings are single
observations on a shared host, not latency measurements under matched conditions.
Final-candidate combined qualification remains open.

## Projected retained Table scans — 2026-10-26

Focused checks pass **21/21** Fuze projection/import tests, **2/2** storage
projection/import tests, **5/5** retained-reader/contract tests and **11/11**
direct-query tests. A separate physical-batch/LIMIT regression run passes
**39/39** tests. The disk fixture scans key columns from 16 KiB payload rows
with an 8 KiB decoder budget; a full-row scan rejects that budget. It preserves
17 identities across segment and WAL locators, rejects foreign column cursors,
survives cache changes and rechecks authority after buffering.

`just test::direct-table-service projection` passes through the signed local
disk owner. Seventeen bulk rows with 16 KiB payloads plus one WAL row fit into
1 KiB projected pages. A later write does not alter the retained 18-row source.
The proof checks owned rows across subsequent pages, primary-key inclusion,
column-bound cursor rejection, prepared ASCII_CI predicates, named duplicate
outputs, COUNT/SUM, keyless identity traversal, original plan/name attribution
on ordered SUM overflow, selected-prefix LIMIT, post-compute and repeated-terminal
revocation, and released-pin rejection. Wide fixture ingestion uses the typed
intent API; SQL scalar parameters retain their separate 220-byte bound.

Independent Python signing/cursor vectors and the generated direct contract
pass. Reader allocation-failure sweeps preserve cleanup and exact consumption.
Diagnostic error/outcome checks pass **3,411** projections across **24** declared
surfaces; mapping, verification-catalog and documentation checks pass. Projection
does not filter source rows, expire retained data or establish general encoded
predicate pushdown. WAL rows retain bounded full-record decoding; point and
count-range paths keep complete-row representations. The broader current-tree
check and committed clean lanes remain separate qualifications.

The broader `test::direct-table-service` run passes initial writes, disk restart,
retained delegation/history, pin-journal recovery, original receipts and
conditional names. Its later `lifecycle` caller exceeds the existing 180-second
phase deadline while the server continues returning successful name-assertion
responses. This run is failed; later phases did not execute. It overlapped the
owner benchmark and full checks, so a retry without that disk workload is needed
before attributing the timeout to either contention or a regression.

The retry after the disk-owner matrix finishes reaches the same lifecycle
history phase and again exceeds 180 seconds. The timeout remains unresolved;
it cannot be attributed solely to that benchmark. The repository `just check`
launched with the projection changes completes successfully, including contracts,
root units, frontend checks and the documentation production build. That run
predates the encoded decision/owner changes below and is not their final
committed-source clean qualification.

## Encoded retained Table filtering — 2026-10-26

`just test::table-filtering` passes **39/39** TSEG tests and **4/4** selected
storage tests (filtering, projection and imports). A real-disk fixture interleaves
two segments whose key order reverses identity order, plus a retained WAL row.
It verifies matching-row limits, empty nonterminal pages, exact examined counts,
per-row source offsets, changed-plan/cross-projection cursor rejection, final
revocation and owned outputs. Deletion and reopen preserve different current and
retained results; released pins reject. Projection avoids 16 KiB payload columns
with an 8 KiB output decoder budget.

Independent binary/ASCII_CI/CP037 masks exercise bitpacked keys, dictionary text
and NULL. Repeated pages reuse one group's decisions; changing the plan forces
reevaluation. Byte-bound continuations preserve the unreturned match. A one-byte
predicate budget refuses work without changing the accepted root. Exhaustive
allocation failures cover reopening, dictionaries, cached decisions and result
ownership. They exposed and now guard cleanup of a partially built decision
cache and the predicate codec's outcome allocation after dictionary failure.
The codec frees that allocation on error even when its output allocator is not
an arena.

Five-state segment fixtures retain each physical row's first semantic failure
without disclosing it prematurely; requested-page corruption still rejects.
Diagnostic mapping/error/outcome checks pass **3,411** projections across **24**
declared surfaces. This storage operation supplies no wire protocol, SQL
aggregate/LIMIT owner or authority for the plan's external source basis. Filtered
service integration and final clean qualification remain separate work.

## Rebased retained Table service qualification — 2026-10-26

At `acbc873be`, after rebasing onto `310a3f25e`, the complete
`just test::direct-table-service` run passes **1,944 typed calls**. Both retained
history replays complete all eight transactions and final checkpoints, using
**210 charged requests** per replay through the eighth transaction. Main's
physical history paging fix combines with request-local metadata recovery reuse;
this run resolves the earlier broad lifecycle timeout without changing the
180-second limit. Recovery, retained source closure, prepared lifetimes,
count-range controls, collations, projected/filtered SQL, delegated closure and
authorization lifetime all pass. This precedes the buffered segment change below.

The final signed local metadata regression also passes **3/3** tests, including
original-grant denial before malformed successor inspection. Contract reflection,
independent signing/work-item fixtures, diagnostic inventory, verification catalog
and documentation links pass after the rebase. The pre-rebase clean core run was
interrupted to incorporate main's toolchain fixes; it is not a completed lane.
Final committed-HEAD clean qualification remains open.


