# Native authority persistence

`Store` implements the journal side of [native core](../../transit-core/docs/growing.md);
`PackedPageStore` supplies immutable data. The [node](../../../../apps/transit-node/docs/growing.md),
Station and launchers use this single v1 definition. Automatic conversion and
mixed-definition writers are unsupported.

## Publication and ownership

Both stores borrow an Ursula client and configured authority journal. The journal
store owns one cached journal entry. It reads one verified record coordinate,
bounds encoded entries at 64 KiB and copies owned typed fields before releasing
the parse arena. The caller's upstream response ceiling also bounds transport
allocation. Page count is independent of that cache. Raw journal/page access is
privileged infrastructure, never a caller capability.

Preparation persists candidate pages; a conditional authority append publishes
the complete root together with input progress, resource changes, outputs and
retry evidence. Failure before append leaves the old root authoritative. A lost
append acknowledgement remains uncertain until current history supplies the
matching receipt. Staged pages cannot establish acceptance. Recovery loads the
latest published root and accesses records on demand, without handlers or effects.

## Root checkpoints and retention

Unlimited retention is the default. The application's explicit realm genesis
`allow_history_trim` opt-in permits an administrative `checkpoint` operation to
record a monotonic protocol-history floor. That operation publishes a complete
head like every other transition, and the floor keeps its own record or newer
complete heads in the authority journal. Missing latest history is an error,
never permission to resume from an older root.

`maintain` verifies that current history authorizes the requested floor. It
publishes and rereads a versioned, root-only snapshot, then advances Ursula
retention. Snapshot reads follow only the configured stream's opaque offset;
they never forward credentials to a returned URL. Repeating completed maintenance
does not republish snapshots or advance the authority. A crash between these
steps leaves either extra history or a recoverable complete root.

The retained head is the ordinary recovery basis; the snapshot independently
records the compaction basis. An idle authority catches up directly to the latest
head. Neither snapshot nor trim materializes every resource or copies every
captured view. Page records are never trimmed here, so retained views, receipts,
pending mailboxes/outboxes and application state remain addressable. This does
not authorize page garbage collection or implement selective payload expiry.

## Proof and limits

```sh
just test::growing
just test::growing --rows 256 --cold-s3
just test::growing --rows 256 --cache 16 --cold-s3
just test::scale
```

The ordinary proof runs 20 principals with full-width identities, 70 PIDs,
six resources and 64 retained 256-byte values with one decoded page slot. It
compares a captured half-written version with the completed resource, checks
process progress and pending outputs, and replays an exact retained receipt.
The final write also atomically retains its pre-write source version. Every
phase reads that version's 60 rows separately from the current 64 rows and the
open half-written turn view, including after physical authority-prefix trim.
Retained roots survive without copying resources into memory or retaining a
worker activation. Page garbage collection remains outside this proof.
Competing publication after revocation, failure before append and lost response
after real append are explicit schedules. SIGKILL separates write, recover,
checkpoint and trim/recover phases. Every phase rejects retained histories with
missing or foreign contract definitions before page access, preserving their
original bytes and the current authority. Missing required page storage also
fails; temporary clock samples are deterministic test inputs.

Artifacts `.cache/verification/growing-<hot|s3>-<rows>-<cache>.json` record revision,
dirty state, binary hash, cache/data/catalog sizes, page requests, elapsed time,
client/provider memory and WAL file lengths. Optional cold storage uses the
[owned S3 fixture](pages.md#verification-and-limits) and records its resource
cost separately. The ordinary hot-only fixture is crash correctness evidence,
not provider memory qualification. Timeouts/errors stay inconclusive.

The page cache is bounded, but fanout, path-copy and protocol-operation request
amplification remain substantial. This is not millisecond execution evidence.
The node composes a separate bounded maintenance process. Service schedules
exercise snapshot-reply loss, trim timeout, current revocation and restart;
Station and runtime controllers have their own integration checks. The
[proof ledger](../../../../docs/history/qualification/README.md) owns executed outcomes and their scope.
Incompatible deployed history fails closed; rejection does not convert old data.

The measurement driver also records per-operation and complete-turn nanoseconds,
nearest-rank p50/p95/p99, page hits/misses, attempted page payload bytes, orphan
staging bytes, allocated WAL blocks, process I/O counters, sampled stack mappings, root-open
time and checkpoint/trim time. Linux `write_bytes` counts process-attributed
storage I/O, not a device-level persistence or write-amplification proof.
A complete-turn sample includes admission, view acquisition, private preparation,
publication and intervening correctness reads; it is not just append latency.
Opening an engine is timed separately from full retained-data verification.
The control catalog now retains 69 associations, across multiple catalog pages.
All phases use the same configurable cache; the one-page default still retains
more application bytes than its decoded cache. Larger-cache comparison samples
need not exceed their cache. The fixture uses the checkout filesystem instead of
Nix's potentially tmpfs-backed temporary directory and reports its filesystem.

`just test::scale` owns the small repeated matrix in
[scale.json](../../../../tests/performance/scale/scale.json), including 64/256/1,024
rows at one page and 256 rows at 16 pages. It separately drives the public node
with 48 independent pre-signed sender requests, fixed offer intervals, bounded
workers and 16/256-byte payloads with uniform/hot-key updates. Queueing latency
includes time waiting in the generator's bounded queue; scheduling lag and that
queue are reported so a saturated generator cannot masquerade as node capacity.
Revocation runs during admission; retained receipts, ordered input drain, exact
row values and revocation are checked again through node/provider restart.
This is a finite single-authority experiment, not a production SLO. Samples remain
inconclusive until every assertion and cleanup completes. The test guide owns
recorded qualification results.
