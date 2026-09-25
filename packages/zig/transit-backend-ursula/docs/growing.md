# Growing authority persistence

Status: M10 development integration. `GrowingStore` implements the journal side
of [growing core](../../transit-core/docs/growing.md); `PackedPageStore` supplies
its immutable data. The node and Zig client have an
[explicit development profile](../../../../apps/transit-node/docs/growing.md);
launcher defaults and Station remain v2. A realm must explicitly select v3; automatic conversion or
mixed-profile writers are forbidden.

## Publication and ownership

Both stores borrow an Ursula client and configured authority journal. The growing
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
```

The ordinary proof runs 20 principals above the legacy identity range, 70 PIDs,
six resources and 64 retained 256-byte values with one decoded page slot. It
compares a captured half-written version with the completed resource, checks
process progress and pending outputs, and replays an exact retained receipt.
Competing publication after revocation, failure before append and lost response
after real append are explicit schedules. SIGKILL separates write, recover,
checkpoint and trim/recover phases. Missing required page storage and legacy
profile parsing fail; temporary clock samples are deterministic test inputs.

Artifacts `.cache/verification/growing-<hot|s3>-<rows>.json` record revision,
dirty state, binary hash, cache/data/catalog sizes, page requests, elapsed time,
client/provider memory and WAL file lengths. Optional cold storage uses the
[owned S3 fixture](pages.md#cold-tier-qualification) and records its resource
cost separately. The ordinary hot-only fixture is crash correctness evidence,
not provider memory qualification. Timeouts/errors stay inconclusive.

The page cache is bounded, but fanout, path-copy and protocol-operation request
amplification remain substantial. This is not millisecond execution evidence.
The node now composes a separate bounded maintenance process and qualifies its
snapshot-reply loss, trim timeout, current revocation and restart through
`just test::growing-service`. Framework handler/result paging,
quotas/control reserve, runtime bindings and migration tooling remain
M10 work. Old deployed v2 history stays on its explicit legacy path; rejection
of incompatible formats is not a completed migration facility.

Initial local Debug evidence (single runs, not a latency distribution):

| Retained rows | Provider tier | Transit page cache | Write and verification | Restart and verification | Client peak RSS on recovery | Ursula peak RSS on recovery |
| ---: | --- | ---: | ---: | ---: | ---: | ---: |
| 64 | Disk WAL, hot only | 8,532 bytes | 23.14 s | 2.36 s | 12,168 KiB | 61,052 KiB |
| 256 | Disk WAL and S3 | 8,532 bytes | 68.99 s | 7.49 s | 12,172 KiB | 73,928 KiB |

The 256-row run retained 984 catalog records before checkpoint, including work,
principals and retry/view evidence. It made 57,288 page requests during setup,
writing and verification; this is not a per-turn benchmark. MinIO peaked at
215,496 KiB during that recovery phase and stored about 11.3 MB of files. Both
runs passed checkpoint and post-trim restart. The unchanged client budget and
retained correctness establish this small growth path; request amplification,
provider growth at larger sizes and end-to-end execution latency remain open.
